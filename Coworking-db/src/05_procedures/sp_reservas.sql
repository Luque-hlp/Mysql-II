USE coworking_db;

DROP PROCEDURE IF EXISTS sp_verificar_disponibilidad;
DELIMITER $$
CREATE PROCEDURE sp_verificar_disponibilidad(
    IN  p_id_espacio INT,
    IN  p_inicio     DATETIME,
    IN  p_fin        DATETIME,
    OUT p_disponible BOOLEAN,
    OUT p_mensaje    VARCHAR(100)
)
BEGIN
    IF fn_espacio_disponible(p_id_espacio, p_inicio, p_fin) THEN
        SET p_disponible = TRUE;
        SET p_mensaje = 'Espacio disponible en el horario solicitado';
    ELSE
        SET p_disponible = FALSE;
        SET p_mensaje = 'El espacio no esta disponible: ocupado, en mantenimiento o inactivo';
    END IF;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_crear_reserva;
DELIMITER $$
CREATE PROCEDURE sp_crear_reserva(
    IN  p_id_usuario     INT,
    IN  p_id_espacio     INT,
    IN  p_inicio         DATETIME,
    IN  p_fin            DATETIME,
    IN  p_num_asistentes INT,
    OUT p_id_reserva     INT
)
BEGIN
    DECLARE v_capacidad INT;
    DECLARE v_monto     DECIMAL(10,2);

    -- Si cualquier INSERT/validacion falla, deshacer y relanzar el error
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF fn_usuario_en_mora(p_id_usuario) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El usuario tiene facturas en mora y no puede reservar';
    END IF;

    IF NOT fn_espacio_disponible(p_id_espacio, p_inicio, p_fin) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El espacio no esta disponible en ese horario';
    END IF;

    IF NOT fn_dentro_horario(p_id_espacio, p_inicio)
       OR NOT fn_dentro_horario(p_id_espacio, p_fin) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El horario solicitado esta fuera del horario de atencion';
    END IF;

    SELECT capacidad_maxima INTO v_capacidad
    FROM espacios WHERE id_espacio = p_id_espacio;

    IF p_num_asistentes > v_capacidad THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El numero de asistentes supera la capacidad del espacio';
    END IF;

    SET v_monto = fn_calcular_costo_reserva(p_id_espacio, p_inicio, p_fin);

    INSERT INTO reservas (id_usuario, id_espacio, fecha_hora_inicio,
                          fecha_hora_fin, num_asistentes, estado, monto_total)
    VALUES (p_id_usuario, p_id_espacio, p_inicio, p_fin,
            p_num_asistentes, 'Pendiente', v_monto);

    SET p_id_reserva = LAST_INSERT_ID();

    COMMIT;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_confirmar_reserva_con_pago;
DELIMITER $$
CREATE PROCEDURE sp_confirmar_reserva_con_pago(
    IN p_id_reserva    INT,
    IN p_id_metodo_pago INT
)
BEGIN
    DECLARE v_id_usuario INT;
    DECLARE v_monto      DECIMAL(10,2);
    DECLARE v_estado     VARCHAR(20);
    DECLARE v_id_factura INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT id_usuario, monto_total, estado
      INTO v_id_usuario, v_monto, v_estado
    FROM reservas WHERE id_reserva = p_id_reserva;

    IF v_id_usuario IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La reserva no existe';
    END IF;

    IF v_estado <> 'Pendiente' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Solo se pueden confirmar reservas pendientes';
    END IF;

    -- Factura de la reserva
    INSERT INTO facturas (numero_factura, id_usuario, id_reserva, tipo_origen,
                          subtotal, total, saldo_pendiente, estado,
                          fecha_emision, fecha_vencimiento)
    VALUES (fn_generar_numero_factura(), v_id_usuario, p_id_reserva, 'Reserva',
            v_monto, v_monto, v_monto, 'Pendiente',
            CURDATE(), DATE_ADD(CURDATE(), INTERVAL 15 DAY));

    SET v_id_factura = LAST_INSERT_ID();

    INSERT INTO detalle_factura (id_factura, concepto, tipo_concepto,
                                 id_referencia, cantidad, precio_unitario, subtotal)
    VALUES (v_id_factura, 'Reserva de espacio', 'Reserva',
            p_id_reserva, 1, v_monto, v_monto);

    -- Pago (el trigger de pagos ajustara el saldo y el estado de la factura)
    INSERT INTO pagos (id_factura, id_metodo_pago, monto, estado)
    VALUES (v_id_factura, p_id_metodo_pago, v_monto, 'Pagado');

    UPDATE reservas SET estado = 'Confirmada' WHERE id_reserva = p_id_reserva;

    COMMIT;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_cancelar_reserva;
DELIMITER $$
CREATE PROCEDURE sp_cancelar_reserva(
    IN p_id_reserva INT,
    IN p_motivo     VARCHAR(200)
)
BEGIN
    DECLARE v_estado   VARCHAR(20);
    DECLARE v_inicio   DATETIME;
    DECLARE v_monto    DECIMAL(10,2);
    DECLARE v_horas    INT;
    DECLARE v_pct      DECIMAL(5,2) DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT estado, fecha_hora_inicio, monto_total
      INTO v_estado, v_inicio, v_monto
    FROM reservas WHERE id_reserva = p_id_reserva;

    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La reserva no existe';
    END IF;

    IF v_estado IN ('Cancelada', 'Completada', 'No Show') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La reserva no se puede cancelar en su estado actual';
    END IF;

    -- Politica de reembolso segun antelacion
    SET v_horas = TIMESTAMPDIFF(HOUR, NOW(), v_inicio);
    IF v_horas >= 48 THEN
        SET v_pct = 100;
    ELSEIF v_horas >= 24 THEN
        SET v_pct = 50;
    ELSE
        SET v_pct = 0;
    END IF;

    UPDATE reservas
    SET estado = 'Cancelada', motivo_cancelacion = p_motivo
    WHERE id_reserva = p_id_reserva;

    IF v_pct > 0 THEN
        INSERT INTO reembolsos (id_reserva, monto, porcentaje, motivo)
        VALUES (p_id_reserva, ROUND(v_monto * v_pct / 100, 2), v_pct,
                CONCAT('Reembolso del ', v_pct, '% por cancelacion anticipada'));
    END IF;

    COMMIT;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_liberar_reservas_no_confirmadas;
DELIMITER $$
CREATE PROCEDURE sp_liberar_reservas_no_confirmadas(
    IN  p_horas     INT,
    OUT p_afectadas INT
)
BEGIN
    UPDATE reservas
    SET estado = 'Cancelada',
        motivo_cancelacion = CONCAT('Liberada automaticamente: sin confirmar tras ',
                                    p_horas, ' horas')
    WHERE estado = 'Pendiente'
      AND TIMESTAMPDIFF(HOUR, fecha_creacion, NOW()) > p_horas;

    SET p_afectadas = ROW_COUNT();
END $$
DELIMITER ;
USE coworking_db;

DROP PROCEDURE IF EXISTS sp_generar_factura_membresia;
DELIMITER $$
CREATE PROCEDURE sp_generar_factura_membresia(
    IN  p_id_membresia INT,
    OUT p_id_factura   INT
)
BEGIN
    DECLARE v_id_usuario INT;
    DECLARE v_id_tipo    INT;
    DECLARE v_precio     DECIMAL(10,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT id_usuario, id_tipo_membresia
      INTO v_id_usuario, v_id_tipo
    FROM membresias WHERE id_membresia = p_id_membresia;

    IF v_id_usuario IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La membresia no existe';
    END IF;

    SET v_precio = fn_precio_con_descuento(v_id_tipo, v_id_usuario);

    INSERT INTO facturas (numero_factura, id_usuario, id_membresia, tipo_origen,
                          subtotal, total, saldo_pendiente, estado,
                          fecha_emision, fecha_vencimiento)
    VALUES (fn_generar_numero_factura(), v_id_usuario, p_id_membresia, 'Membresia',
            v_precio, v_precio, v_precio, 'Pendiente',
            CURDATE(), DATE_ADD(CURDATE(), INTERVAL 15 DAY));

    SET p_id_factura = LAST_INSERT_ID();

    INSERT INTO detalle_factura (id_factura, concepto, tipo_concepto,
                                 id_referencia, cantidad, precio_unitario, subtotal)
    VALUES (p_id_factura, 'Membresia contratada', 'Membresia',
            p_id_membresia, 1, v_precio, v_precio);

    COMMIT;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_generar_factura_consolidada;
DELIMITER $$
CREATE PROCEDURE sp_generar_factura_consolidada(
    IN  p_id_empresa INT,
    OUT p_id_factura INT
)
BEGIN
    DECLARE v_id_usuario  INT;
    DECLARE v_id_tipo     INT;
    DECLARE v_precio      DECIMAL(10,2);
    DECLARE v_total       DECIMAL(12,2) DEFAULT 0;
    DECLARE v_primer_user INT;
    DECLARE v_fin         BOOLEAN DEFAULT FALSE;

    -- Un cursor es un puntero que recorre las filas de una consulta
    DECLARE cur CURSOR FOR
        SELECT u.id_usuario, m.id_tipo_membresia
        FROM usuarios u
        INNER JOIN membresias m ON m.id_usuario = u.id_usuario
        WHERE u.id_empresa = p_id_empresa
          AND m.estado = 'Activa';

    -- Cuando el cursor se queda sin filas, este handler pone v_fin = TRUE
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fin = TRUE;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM empresas WHERE id_empresa = p_id_empresa) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La empresa no existe';
    END IF;

    START TRANSACTION;

    -- Usuario titular de la factura (el primer empleado de la empresa)
    SELECT id_usuario INTO v_primer_user
    FROM usuarios WHERE id_empresa = p_id_empresa ORDER BY id_usuario LIMIT 1;

    -- Encabezado con total 0; se actualiza al final
    INSERT INTO facturas (numero_factura, id_usuario, id_empresa, tipo_origen,
                          subtotal, total, saldo_pendiente, estado,
                          fecha_emision, fecha_vencimiento)
    VALUES (fn_generar_numero_factura(), v_primer_user, p_id_empresa, 'Consolidada',
            0, 0, 0, 'Pendiente', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY));

    SET p_id_factura = LAST_INSERT_ID();

    OPEN cur;
    bucle: LOOP
        FETCH cur INTO v_id_usuario, v_id_tipo;
        IF v_fin THEN
            LEAVE bucle;
        END IF;

        SET v_precio = fn_precio_con_descuento(v_id_tipo, v_id_usuario);
        SET v_total  = v_total + v_precio;

        INSERT INTO detalle_factura (id_factura, concepto, tipo_concepto,
                                     id_referencia, cantidad, precio_unitario, subtotal)
        VALUES (p_id_factura,
                CONCAT('Membresia empleado ', v_id_usuario), 'Membresia',
                v_id_usuario, 1, v_precio, v_precio);
    END LOOP;
    CLOSE cur;

    -- Volcar el total acumulado al encabezado
    UPDATE facturas
    SET subtotal = v_total, total = v_total, saldo_pendiente = v_total
    WHERE id_factura = p_id_factura;

    COMMIT;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_aplicar_recargos_vencidas;
DELIMITER $$
CREATE PROCEDURE sp_aplicar_recargos_vencidas(
    OUT p_afectadas INT
)
BEGIN
    DECLARE v_id_factura INT;
    DECLARE v_recargo    DECIMAL(10,2);
    DECLARE v_fin        BOOLEAN DEFAULT FALSE;
    DECLARE v_contador   INT DEFAULT 0;

    DECLARE cur CURSOR FOR
        SELECT id_factura
        FROM facturas
        WHERE estado IN ('Pendiente', 'Parcial', 'Vencida')
          AND fecha_vencimiento < CURDATE()
          AND recargo = 0;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fin = TRUE;

    OPEN cur;
    bucle: LOOP
        FETCH cur INTO v_id_factura;
        IF v_fin THEN LEAVE bucle; END IF;

        SET v_recargo = fn_calcular_recargo_mora(v_id_factura);

        IF v_recargo > 0 THEN
            UPDATE facturas
            SET recargo = v_recargo,
                total   = subtotal + v_recargo,
                saldo_pendiente = saldo_pendiente + v_recargo,
                estado  = 'Vencida'
            WHERE id_factura = v_id_factura;

            INSERT INTO detalle_factura (id_factura, concepto, tipo_concepto,
                                         cantidad, precio_unitario, subtotal)
            VALUES (v_id_factura, 'Recargo por mora', 'Recargo',
                    1, v_recargo, v_recargo);

            SET v_contador = v_contador + 1;
        END IF;
    END LOOP;
    CLOSE cur;

    SET p_afectadas = v_contador;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_bloquear_servicios_morosos;
DELIMITER $$
CREATE PROCEDURE sp_bloquear_servicios_morosos(
    OUT p_afectados INT
)
BEGIN
    UPDATE servicios_contratados sc
    SET sc.estado = 'Bloqueado'
    WHERE sc.estado = 'Activo'
      AND fn_usuario_en_mora(sc.id_usuario) = TRUE;

    SET p_afectados = ROW_COUNT();
END $$
DELIMITER ;
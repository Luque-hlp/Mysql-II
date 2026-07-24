USE coworking_db;

DROP PROCEDURE IF EXISTS sp_registrar_entrada;
DELIMITER $$
CREATE PROCEDURE sp_registrar_entrada(
    IN  p_codigo  VARCHAR(60),
    OUT p_permitido BOOLEAN,
    OUT p_mensaje   VARCHAR(150)
)
BEGIN
    DECLARE v_id_usuario INT;
    DECLARE v_id_cred    INT;
    DECLARE v_tipo       VARCHAR(10);

    -- fn_credencial_valida devuelve 0 si el codigo no sirve
    SET v_id_usuario = fn_credencial_valida(p_codigo);

    IF v_id_usuario = 0 THEN
        SET p_permitido = FALSE;
        SET p_mensaje = 'Credencial invalida o inactiva';
        INSERT INTO accesos (id_usuario, tipo_credencial, codigo_presentado,
                             resultado, motivo_rechazo)
        VALUES (NULL, 'QR', p_codigo, 'Rechazado', p_mensaje);
        INSERT INTO log_accesos_rechazados (id_usuario, codigo_presentado,
                                            tipo_credencial, motivo)
        VALUES (NULL, p_codigo, 'QR', p_mensaje);

    ELSEIF NOT fn_membresia_activa(v_id_usuario) THEN
        SET p_permitido = FALSE;
        SET p_mensaje = 'Membresia vencida o inactiva';
        SELECT id_credencial, tipo INTO v_id_cred, v_tipo
        FROM credenciales WHERE codigo = p_codigo LIMIT 1;
        INSERT INTO accesos (id_usuario, id_credencial, tipo_credencial,
                             codigo_presentado, resultado, motivo_rechazo)
        VALUES (v_id_usuario, v_id_cred, v_tipo, p_codigo, 'Rechazado', p_mensaje);
        INSERT INTO log_accesos_rechazados (id_usuario, codigo_presentado,
                                            tipo_credencial, motivo)
        VALUES (v_id_usuario, p_codigo, v_tipo, p_mensaje);

    ELSE
        SELECT id_credencial, tipo INTO v_id_cred, v_tipo
        FROM credenciales WHERE codigo = p_codigo LIMIT 1;
        INSERT INTO accesos (id_usuario, id_credencial, tipo_credencial,
                             codigo_presentado, resultado)
        VALUES (v_id_usuario, v_id_cred, v_tipo, p_codigo, 'Permitido');
        SET p_permitido = TRUE;
        SET p_mensaje = 'Acceso permitido';
    END IF;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_registrar_salida;
DELIMITER $$
CREATE PROCEDURE sp_registrar_salida(
    IN  p_id_usuario INT,
    OUT p_mensaje    VARCHAR(150)
)
BEGIN
    DECLARE v_id_acceso INT;

    SELECT id_acceso INTO v_id_acceso
    FROM accesos
    WHERE id_usuario = p_id_usuario
      AND resultado  = 'Permitido'
      AND fecha_hora_salida IS NULL
    ORDER BY fecha_hora_entrada DESC
    LIMIT 1;

    IF v_id_acceso IS NULL THEN
        SET p_mensaje = 'El usuario no tiene una entrada abierta';
    ELSE
        UPDATE accesos
        SET fecha_hora_salida = NOW()
        WHERE id_acceso = v_id_acceso;
        SET p_mensaje = 'Salida registrada correctamente';
    END IF;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_reporte_diario_asistencias;
DELIMITER $$
CREATE PROCEDURE sp_reporte_diario_asistencias(
    IN  p_fecha         DATE,
    OUT p_total_ingresos INT,
    OUT p_usuarios_unicos INT,
    OUT p_rechazos       INT,
    OUT p_hora_pico      INT
)
BEGIN
    SELECT COUNT(*) INTO p_total_ingresos
    FROM accesos
    WHERE DATE(fecha_hora_entrada) = p_fecha AND resultado = 'Permitido';

    SELECT COUNT(DISTINCT id_usuario) INTO p_usuarios_unicos
    FROM accesos
    WHERE DATE(fecha_hora_entrada) = p_fecha AND resultado = 'Permitido';

    SELECT COUNT(*) INTO p_rechazos
    FROM accesos
    WHERE DATE(fecha_hora_entrada) = p_fecha AND resultado = 'Rechazado';

    SELECT HOUR(fecha_hora_entrada) INTO p_hora_pico
    FROM accesos
    WHERE DATE(fecha_hora_entrada) = p_fecha AND resultado = 'Permitido'
    GROUP BY HOUR(fecha_hora_entrada)
    ORDER BY COUNT(*) DESC
    LIMIT 1;
END $$
DELIMITER ;


-- ---------------------------------------------------------------------
-- 17. sp_marcar_no_show
--     Detecta reservas confirmadas cuya hora de fin ya paso y que NO
--     registraron ningun acceso del usuario ese dia. Las marca 'No Show'
--     y genera una penalizacion del 30% del monto.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_marcar_no_show;
DELIMITER $$
CREATE PROCEDURE sp_marcar_no_show(
    OUT p_afectadas INT
)
BEGIN
    DECLARE v_id_reserva INT;
    DECLARE v_id_usuario INT;
    DECLARE v_monto      DECIMAL(10,2);
    DECLARE v_fin        BOOLEAN DEFAULT FALSE;
    DECLARE v_contador   INT DEFAULT 0;

    DECLARE cur CURSOR FOR
        SELECT r.id_reserva, r.id_usuario, r.monto_total
        FROM reservas r
        WHERE r.estado = 'Confirmada'
          AND r.fecha_hora_fin < NOW()
          AND NOT EXISTS (
              SELECT 1 FROM accesos a
              WHERE a.id_usuario = r.id_usuario
                AND a.resultado = 'Permitido'
                AND DATE(a.fecha_hora_entrada) = DATE(r.fecha_hora_inicio)
          );

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fin = TRUE;

    OPEN cur;
    bucle: LOOP
        FETCH cur INTO v_id_reserva, v_id_usuario, v_monto;
        IF v_fin THEN LEAVE bucle; END IF;

        UPDATE reservas SET estado = 'No Show' WHERE id_reserva = v_id_reserva;

        INSERT INTO penalizaciones (id_reserva, id_usuario, monto, motivo)
        VALUES (v_id_reserva, v_id_usuario, ROUND(v_monto * 0.30, 2),
                'Penalizacion automatica por reserva confirmada sin asistencia');

        SET v_contador = v_contador + 1;
    END LOOP;
    CLOSE cur;

    SET p_afectadas = v_contador;
END $$
DELIMITER ;
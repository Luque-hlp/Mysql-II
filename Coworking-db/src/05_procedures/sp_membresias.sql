USE coworking_db;

DROP PROCEDURE IF EXISTS sp_registrar_membresia;
DELIMITER $$
CREATE PROCEDURE sp_registrar_membresia(
    IN  p_id_usuario        INT,
    IN  p_id_tipo_membresia INT,
    IN  p_fecha_inicio      DATE,
    OUT p_id_membresia      INT
)
BEGIN
    DECLARE v_fecha_fin DATE;

    -- Validaciones de negocio: si algo no cuadra, SIGNAL corta el proc
    -- y devuelve un mensaje entendible en vez de un error tecnico.
    IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id_usuario = p_id_usuario) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El usuario no existe';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM tipos_membresia
                   WHERE id_tipo_membresia = p_id_tipo_membresia) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El tipo de membresia no existe';
    END IF;

    SET v_fecha_fin = fn_calcular_fecha_fin(p_id_tipo_membresia, p_fecha_inicio);

    INSERT INTO membresias (id_usuario, id_tipo_membresia,
                            fecha_inicio, fecha_fin, estado)
    VALUES (p_id_usuario, p_id_tipo_membresia,
            p_fecha_inicio, v_fecha_fin, 'Activa');

    -- LAST_INSERT_ID() devuelve el id autogenerado en el INSERT anterior
    SET p_id_membresia = LAST_INSERT_ID();
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_renovar_membresia;
DELIMITER $$
CREATE PROCEDURE sp_renovar_membresia(
    IN  p_id_usuario   INT,
    OUT p_id_membresia INT
)
BEGIN
    DECLARE v_tipo        INT;
    DECLARE v_ultimo_fin  DATE;
    DECLARE v_nuevo_inicio DATE;
    DECLARE v_nuevo_fin   DATE;

    -- Tomar el tipo y la fecha de fin de la membresia mas reciente
    SELECT id_tipo_membresia, fecha_fin
      INTO v_tipo, v_ultimo_fin
    FROM membresias
    WHERE id_usuario = p_id_usuario
    ORDER BY fecha_fin DESC
    LIMIT 1;

    IF v_tipo IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El usuario no tiene membresias para renovar';
    END IF;

    -- Si la ultima ya vencio, la nueva arranca hoy; si sigue vigente,
    -- arranca al dia siguiente para no traslapar.
    IF v_ultimo_fin < CURDATE() THEN
        SET v_nuevo_inicio = CURDATE();
    ELSE
        SET v_nuevo_inicio = DATE_ADD(v_ultimo_fin, INTERVAL 1 DAY);
    END IF;

    SET v_nuevo_fin = fn_calcular_fecha_fin(v_tipo, v_nuevo_inicio);

    INSERT INTO membresias (id_usuario, id_tipo_membresia,
                            fecha_inicio, fecha_fin, estado)
    VALUES (p_id_usuario, v_tipo, v_nuevo_inicio, v_nuevo_fin, 'Activa');

    SET p_id_membresia = LAST_INSERT_ID();
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_actualizar_membresias_vencidas;
DELIMITER $$
CREATE PROCEDURE sp_actualizar_membresias_vencidas(
    OUT p_afectadas INT
)
BEGIN
    UPDATE membresias
    SET estado = 'Vencida'
    WHERE estado = 'Activa'
      AND fecha_fin < CURDATE();

    -- ROW_COUNT() = cuantas filas modifico el ultimo UPDATE
    SET p_afectadas = ROW_COUNT();
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_suspender_membresias_morosas;
DELIMITER $$
CREATE PROCEDURE sp_suspender_membresias_morosas(
    IN  p_dias      INT,
    OUT p_afectadas INT
)
BEGIN
    UPDATE membresias m
    SET m.estado = 'Suspendida'
    WHERE m.estado = 'Activa'
      AND m.id_usuario IN (
          SELECT f.id_usuario
          FROM facturas f
          WHERE f.estado IN ('Pendiente', 'Parcial', 'Vencida')
            AND DATEDIFF(CURDATE(), f.fecha_vencimiento) > p_dias
      );

    SET p_afectadas = ROW_COUNT();
END $$
DELIMITER ;
USE coworking_db;

DROP FUNCTION IF EXISTS fn_horas_reserva;
DELIMITER $$
CREATE FUNCTION fn_horas_reserva(
    p_inicio DATETIME,
    p_fin    DATETIME
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
NO SQL
BEGIN
    IF p_inicio IS NULL OR p_fin IS NULL OR p_fin <= p_inicio THEN
        RETURN 0;
    END IF;

    RETURN ROUND(TIMESTAMPDIFF(MINUTE, p_inicio, p_fin) / 60, 2);
END $$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_espacio_disponible;
DELIMITER $$
CREATE FUNCTION fn_espacio_disponible(
    p_id_espacio INT,
    p_inicio     DATETIME,
    p_fin        DATETIME
)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
    DECLARE v_estado      VARCHAR(20);
    DECLARE v_conflictos  INT DEFAULT 0;

    -- Un espacio en mantenimiento o inactivo nunca esta disponible
    SELECT estado INTO v_estado
    FROM espacios
    WHERE id_espacio = p_id_espacio;

    IF v_estado IS NULL OR v_estado <> 'Disponible' THEN
        RETURN FALSE;
    END IF;

    SELECT COUNT(*) INTO v_conflictos
    FROM reservas
    WHERE id_espacio        = p_id_espacio
      AND estado IN ('Pendiente', 'Confirmada', 'Completada')
      AND fecha_hora_inicio < p_fin
      AND fecha_hora_fin    > p_inicio;

    RETURN v_conflictos = 0;
END $$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_calcular_costo_reserva;
DELIMITER $$
CREATE FUNCTION fn_calcular_costo_reserva(
    p_id_espacio INT,
    p_inicio     DATETIME,
    p_fin        DATETIME
)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_precio_hora DECIMAL(10,2);
    DECLARE v_horas       DECIMAL(10,2);

    SELECT te.precio_hora INTO v_precio_hora
    FROM espacios e
    INNER JOIN tipos_espacio te ON te.id_tipo_espacio = e.id_tipo_espacio
    WHERE e.id_espacio = p_id_espacio;

    IF v_precio_hora IS NULL THEN
        RETURN 0;
    END IF;

    SET v_horas = fn_horas_reserva(p_inicio, p_fin);

    RETURN ROUND(v_precio_hora * v_horas, 2);
END $$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_total_reservas_usuario;
DELIMITER $$
CREATE FUNCTION fn_total_reservas_usuario(
    p_id_usuario INT,
    p_estado     VARCHAR(20)
)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_total INT DEFAULT 0;

    SELECT COUNT(*) INTO v_total
    FROM reservas
    WHERE id_usuario = p_id_usuario
      AND (p_estado IS NULL OR p_estado = '' OR estado = p_estado);

    RETURN v_total;
END $$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_dentro_horario;
DELIMITER $$
CREATE FUNCTION fn_dentro_horario(
    p_id_espacio  INT,
    p_fecha_hora  DATETIME
)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
    DECLARE v_total INT DEFAULT 0;

    SELECT COUNT(*) INTO v_total
    FROM horarios_espacio
    WHERE id_espacio = p_id_espacio
      AND dia_semana = DAYOFWEEK(p_fecha_hora)
      AND TIME(p_fecha_hora) BETWEEN hora_apertura AND hora_cierre;

    RETURN v_total > 0;
END $$
DELIMITER ;
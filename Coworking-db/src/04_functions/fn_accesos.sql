USE coworking_db;

DROP FUNCTION IF EXISTS fn_ultimo_acceso;
DELIMITER $$
CREATE FUNCTION fn_ultimo_acceso(p_id_usuario INT) --p_ es parametro
RETURNS DATETIME
READS SQL DATA
BEGIN
    DECLARE v_fecha DATETIME;

    SELECT MAX(fecha_hora_entrada) INTO v_fecha
    FROM accesos
    WHERE id_usuario = p_id_usuario
      AND resultado  = 'Permitido';

    RETURN v_fecha;
END $$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_usuario_dentro;
DELIMITER $$
CREATE FUNCTION fn_usuario_dentro(p_id_usuario INT)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
    DECLARE v_total INT DEFAULT 0;

    SELECT COUNT(*) INTO v_total
    FROM accesos
    WHERE id_usuario        = p_id_usuario
      AND resultado         = 'Permitido'
      AND fecha_hora_salida IS NULL;

    RETURN v_total > 0;
END $$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_horas_permanencia;
DELIMITER $$
CREATE FUNCTION fn_horas_permanencia(p_id_acceso INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_entrada DATETIME;
    DECLARE v_salida  DATETIME;

    SELECT fecha_hora_entrada, fecha_hora_salida
      INTO v_entrada, v_salida
    FROM accesos
    WHERE id_acceso = p_id_acceso;

    IF v_entrada IS NULL OR v_salida IS NULL THEN
        RETURN 0;
    END IF;

    RETURN ROUND(TIMESTAMPDIFF(MINUTE, v_entrada, v_salida) / 60, 2);
END $$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_credencial_valida;
DELIMITER $$
CREATE FUNCTION fn_credencial_valida(p_codigo VARCHAR(60))
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_id_usuario INT DEFAULT 0;

    SELECT COALESCE(c.id_usuario, 0) INTO v_id_usuario
    FROM credenciales c
    INNER JOIN usuarios u ON u.id_usuario = c.id_usuario
    WHERE c.codigo = p_codigo
      AND c.activa = TRUE
      AND u.estado = 'Activo'
    LIMIT 1;

    RETURN v_id_usuario;
END $$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_total_accesos_mes;
DELIMITER $$
CREATE FUNCTION fn_total_accesos_mes(
    p_id_usuario INT,
    p_mes        INT,
    p_anio       INT
)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_total INT DEFAULT 0;

    SELECT COUNT(*) INTO v_total
    FROM accesos
    WHERE id_usuario             = p_id_usuario
      AND resultado              = 'Permitido'
      AND MONTH(fecha_hora_entrada) = p_mes
      AND YEAR(fecha_hora_entrada)  = p_anio;

    RETURN v_total;
END $$
DELIMITER ;
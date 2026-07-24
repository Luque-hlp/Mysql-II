USE coworking_db;


DROP FUNCTION IF EXISTS fn_membresia_activa;
DELIMITER $$
CREATE FUNCTION fn_membresia_activa(p_id_usuario INT)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
    DECLARE v_total INT DEFAULT 0;

    SELECT COUNT(*) INTO v_total
    FROM membresias
    WHERE id_usuario = p_id_usuario
      AND estado     = 'Activa'
      AND CURDATE() BETWEEN fecha_inicio AND fecha_fin;

    RETURN v_total > 0;
END $$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_dias_restantes_membresia;
DELIMITER $$
CREATE FUNCTION fn_dias_restantes_membresia(p_id_usuario INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_fecha_fin DATE;

    SELECT MAX(fecha_fin) INTO v_fecha_fin
    FROM membresias
    WHERE id_usuario = p_id_usuario
      AND estado     = 'Activa'
      AND CURDATE() BETWEEN fecha_inicio AND fecha_fin;

    IF v_fecha_fin IS NULL THEN
        RETURN 0;
    END IF;

    RETURN DATEDIFF(v_fecha_fin, CURDATE());
END $$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_calcular_fecha_fin;
DELIMITER $$
CREATE FUNCTION fn_calcular_fecha_fin(
    p_id_tipo_membresia INT,
    p_fecha_inicio      DATE
)
RETURNS DATE
READS SQL DATA
BEGIN
    DECLARE v_duracion INT;

    SELECT duracion_dias INTO v_duracion
    FROM tipos_membresia
    WHERE id_tipo_membresia = p_id_tipo_membresia;

    IF v_duracion IS NULL THEN
        RETURN NULL;
    END IF;

    RETURN DATE_ADD(p_fecha_inicio, INTERVAL v_duracion DAY);
END $$
DELIMITER ;


DROP FUNCTION IF EXISTS fn_total_renovaciones;
DELIMITER $$
CREATE FUNCTION fn_total_renovaciones(p_id_usuario INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_total INT DEFAULT 0;

    SELECT COUNT(*) INTO v_total
    FROM membresias
    WHERE id_usuario = p_id_usuario
      AND estado <> 'Cancelada';

    RETURN GREATEST(v_total - 1, 0);
END $$
DELIMITER ;



DROP FUNCTION IF EXISTS fn_precio_con_descuento;
DELIMITER $$
CREATE FUNCTION fn_precio_con_descuento(
    p_id_tipo_membresia INT,
    p_id_usuario        INT
)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_precio    DECIMAL(10,2);
    DECLARE v_id_empresa INT;
    DECLARE v_descuento DECIMAL(5,2) DEFAULT 0;

    SELECT precio INTO v_precio
    FROM tipos_membresia
    WHERE id_tipo_membresia = p_id_tipo_membresia;

    IF v_precio IS NULL THEN
        RETURN 0;
    END IF;

    SELECT id_empresa INTO v_id_empresa
    FROM usuarios
    WHERE id_usuario = p_id_usuario;

    IF v_id_empresa IS NOT NULL THEN
        SET v_descuento = v_descuento + 10;
    END IF;

    IF fn_total_renovaciones(p_id_usuario) >= 10 THEN
        SET v_descuento = v_descuento + 5;
    END IF;

    RETURN ROUND(v_precio * (1 - v_descuento / 100), 2);
END $$
DELIMITER ;
-- =====================================================================
-- PROCEDIMIENTOS - CORPORATIVOS Y ADMINISTRACION  (18 a 20)
-- Proyecto: coworking_db
-- =====================================================================

USE coworking_db;

-- ---------------------------------------------------------------------
-- 18. sp_registrar_lote_empleados
--     Inserta varios empleados de una empresa de golpe y a cada uno le
--     asigna una membresia corporativa.
--
--     Los datos llegan en un solo texto separado por ';' entre empleados
--     y por ',' entre campos:
--        "1012,Ana,Diaz,ana@x.co;1013,Luis,Paz,luis@x.co"
--     Se recorre con un WHILE partiendo la cadena con SUBSTRING_INDEX.
--     Es la forma de pasar una lista a un procedimiento sin tablas
--     temporales.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_registrar_lote_empleados;
DELIMITER $$
CREATE PROCEDURE sp_registrar_lote_empleados(
    IN  p_id_empresa       INT,
    IN  p_id_tipo_membresia INT,
    IN  p_empleados        TEXT,   -- "ident,nombre,apellidos,email;ident,nombre,..."
    OUT p_insertados       INT
)
BEGIN
    DECLARE v_resto      TEXT;
    DECLARE v_empleado   TEXT;
    DECLARE v_ident      VARCHAR(20);
    DECLARE v_nombre     VARCHAR(60);
    DECLARE v_apellidos  VARCHAR(80);
    DECLARE v_email      VARCHAR(120);
    DECLARE v_id_usuario INT;
    DECLARE v_fecha_fin  DATE;
    DECLARE v_contador   INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM empresas WHERE id_empresa = p_id_empresa) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La empresa no existe';
    END IF;

    START TRANSACTION;

    SET v_resto = p_empleados;

    -- Mientras quede algo en la cadena, procesar el primer empleado
    WHILE CHAR_LENGTH(v_resto) > 0 DO
        -- Primer bloque antes del ';'
        SET v_empleado = SUBSTRING_INDEX(v_resto, ';', 1);

        -- Recortar el resto para la siguiente vuelta
        IF LOCATE(';', v_resto) > 0 THEN
            SET v_resto = SUBSTRING(v_resto, LOCATE(';', v_resto) + 1);
        ELSE
            SET v_resto = '';
        END IF;

        -- Partir el empleado en sus 4 campos
        SET v_ident     = TRIM(SUBSTRING_INDEX(v_empleado, ',', 1));
        SET v_nombre    = TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(v_empleado, ',', 2), ',', -1));
        SET v_apellidos = TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(v_empleado, ',', 3), ',', -1));
        SET v_email     = TRIM(SUBSTRING_INDEX(v_empleado, ',', -1));

        INSERT INTO usuarios (identificacion, nombre, apellidos,
                              fecha_nacimiento, email, id_empresa, estado)
        VALUES (v_ident, v_nombre, v_apellidos, '1990-01-01',
                v_email, p_id_empresa, 'Activo');

        SET v_id_usuario = LAST_INSERT_ID();
        SET v_fecha_fin  = fn_calcular_fecha_fin(p_id_tipo_membresia, CURDATE());

        INSERT INTO membresias (id_usuario, id_tipo_membresia,
                                fecha_inicio, fecha_fin, estado)
        VALUES (v_id_usuario, p_id_tipo_membresia, CURDATE(), v_fecha_fin, 'Activa');

        SET v_contador = v_contador + 1;
    END WHILE;

    COMMIT;
    SET p_insertados = v_contador;
END $$
DELIMITER ;


-- ---------------------------------------------------------------------
-- 19. sp_cancelar_reservas_por_baja
--     Cuando un usuario se da de baja, cancela todas sus reservas
--     futuras (pendientes o confirmadas). Deja las pasadas intactas
--     para no alterar el historico.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_cancelar_reservas_por_baja;
DELIMITER $$
CREATE PROCEDURE sp_cancelar_reservas_por_baja(
    IN  p_id_usuario INT,
    OUT p_afectadas  INT
)
BEGIN
    UPDATE reservas
    SET estado = 'Cancelada',
        motivo_cancelacion = 'Cancelacion automatica por baja del usuario'
    WHERE id_usuario = p_id_usuario
      AND estado IN ('Pendiente', 'Confirmada')
      AND fecha_hora_inicio > NOW();

    SET p_afectadas = ROW_COUNT();
END $$
DELIMITER ;


-- ---------------------------------------------------------------------
-- 20. sp_reporte_ingresos_mensuales
--     Ingresos por mes del ano indicado, con el ACUMULADO corriendo.
--
--     La suma acumulada usa una funcion de ventana:
--        SUM(...) OVER (ORDER BY mes)
--     que va sumando mes a mes sin necesidad de subconsultas.
--     Devuelve un result set (no OUT) porque son varias filas.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_reporte_ingresos_mensuales;
DELIMITER $$
CREATE PROCEDURE sp_reporte_ingresos_mensuales(
    IN p_anio INT
)
BEGIN
    SELECT
        MONTH(p.fecha_pago)                         AS mes,
        SUM(p.monto)                                AS ingresos_mes,
        SUM(SUM(p.monto)) OVER (ORDER BY MONTH(p.fecha_pago)) AS ingresos_acumulados
    FROM pagos p
    WHERE p.estado = 'Pagado'
      AND YEAR(p.fecha_pago) = p_anio
    GROUP BY MONTH(p.fecha_pago)
    ORDER BY mes;
END $$
DELIMITER ;
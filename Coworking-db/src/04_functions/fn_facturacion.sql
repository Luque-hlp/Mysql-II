USE coworking_db;

DROP FUNCTION IF EXISTS fn_saldo_pendiente_usuario;
DELIMITER $$
CREATE FUNCTION fn_saldo_pendiente_usuario(p_id_usuario INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_saldo DECIMAL(12,2) DEFAULT 0;

    SELECT COALESCE(SUM(saldo_pendiente), 0) INTO v_saldo
    FROM facturas
    WHERE id_usuario = p_id_usuario
      AND estado IN ('Pendiente', 'Parcial', 'Vencida');

    RETURN v_saldo;
END $$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_calcular_recargo_mora;
DELIMITER $$
CREATE FUNCTION fn_calcular_recargo_mora(p_id_factura INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_vencimiento DATE;
    DECLARE v_saldo       DECIMAL(12,2);
    DECLARE v_estado      VARCHAR(20);
    DECLARE v_dias_mora   INT;

    SELECT fecha_vencimiento, saldo_pendiente, estado
      INTO v_vencimiento, v_saldo, v_estado
    FROM facturas
    WHERE id_factura = p_id_factura;

    IF v_vencimiento IS NULL OR v_estado IN ('Pagada', 'Anulada') THEN
        RETURN 0;
    END IF;

    SET v_dias_mora = DATEDIFF(CURDATE(), v_vencimiento);

    IF v_dias_mora <= 0 THEN
        RETURN 0;
    END IF;

    RETURN ROUND(v_saldo * 0.05 * CEIL(v_dias_mora / 30), 2);
END $$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_total_pagado_factura;
DELIMITER $$
CREATE FUNCTION fn_total_pagado_factura(p_id_factura INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(12,2) DEFAULT 0;

    SELECT COALESCE(SUM(monto), 0) INTO v_total
    FROM pagos
    WHERE id_factura = p_id_factura
      AND estado     = 'Pagado';

    RETURN v_total;
END $$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_usuario_en_mora;
DELIMITER $$
CREATE FUNCTION fn_usuario_en_mora(p_id_usuario INT)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
    DECLARE v_total INT DEFAULT 0;

    SELECT COUNT(*) INTO v_total
    FROM facturas
    WHERE id_usuario        = p_id_usuario
      AND estado IN ('Pendiente', 'Parcial', 'Vencida')
      AND fecha_vencimiento < CURDATE();

    RETURN v_total > 0;
END $$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_generar_numero_factura;
DELIMITER $$
CREATE FUNCTION fn_generar_numero_factura()
RETURNS VARCHAR(20)
READS SQL DATA
BEGIN
    DECLARE v_año       INT;
    DECLARE v_consecutivo INT DEFAULT 0;

    SET v_año = YEAR(CURDATE());

    SELECT COALESCE(MAX(CAST(SUBSTRING_INDEX(numero_factura, '-', -1) AS UNSIGNED)), 0)
      INTO v_consecutivo
    FROM facturas
    WHERE numero_factura LIKE CONCAT('FAC-', v_anio, '-%');

    RETURN CONCAT('FAC-', v_anio, '-', LPAD(v_consecutivo + 1, 4, '0'));
END $$
DELIMITER ;
USE coworking_db;

DROP EVENT IF EXISTS ev_recordatorio_pago;
DELIMITER $$
CREATE EVENT ev_recordatorio_pago
ON SCHEDULE EVERY 3 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
COMMENT 'Recuerda cada 3 dias las facturas pendientes de pago'
DO
BEGIN
    INSERT INTO notificaciones (id_usuario, destinatario, asunto, mensaje)
    SELECT f.id_usuario, 'Usuario', 'Tienes un pago pendiente',
           CONCAT('Factura ', f.numero_factura, ' con saldo pendiente de ',
                  f.saldo_pendiente, '. Vence el ', f.fecha_vencimiento)
    FROM facturas f
    WHERE f.estado IN ('Pendiente', 'Parcial')
      AND f.saldo_pendiente > 0;
END $$
DELIMITER ;

DROP EVENT IF EXISTS ev_bloquear_servicios_mora;
DELIMITER $$
CREATE EVENT ev_bloquear_servicios_mora
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
COMMENT 'Bloquea servicios de usuarios con facturas vencidas'
DO
BEGIN
    CALL sp_bloquear_servicios_morosos(@n);
END $$
DELIMITER ;

DROP EVENT IF EXISTS ev_resumen_facturacion_mensual;
DELIMITER $$
CREATE EVENT ev_resumen_facturacion_mensual
ON SCHEDULE EVERY 1 MONTH
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
COMMENT 'Resumen mensual de facturacion para administracion'
DO
BEGIN
    DECLARE v_facturado DECIMAL(14,2);
    DECLARE v_recaudado DECIMAL(14,2);

    SELECT COALESCE(SUM(total), 0) INTO v_facturado
    FROM facturas
    WHERE estado <> 'Anulada'
      AND fecha_emision >= NOW() - INTERVAL 1 MONTH;

    SELECT COALESCE(SUM(monto), 0) INTO v_recaudado
    FROM pagos
    WHERE estado = 'Pagado'
      AND fecha_pago >= NOW() - INTERVAL 1 MONTH;

    INSERT INTO notificaciones (destinatario, asunto, mensaje)
    VALUES ('Administrador', 'Resumen de facturacion mensual',
            CONCAT('Ultimo mes -> Facturado: ', v_facturado,
                   ' | Recaudado: ', v_recaudado));
END $$
DELIMITER ;

DROP EVENT IF EXISTS ev_aplicar_recargos;
DELIMITER $$
CREATE EVENT ev_aplicar_recargos
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
COMMENT 'Aplica recargo por mora a facturas vencidas'
DO
BEGIN
    CALL sp_aplicar_recargos_vencidas(@n);
END $$
DELIMITER ;

DROP EVENT IF EXISTS ev_reporte_ingresos_contador;
DELIMITER $$
CREATE EVENT ev_reporte_ingresos_contador
ON SCHEDULE EVERY 1 MONTH
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
COMMENT 'Envia al contador los ingresos acumulados del anio'
DO
BEGIN
    DECLARE v_acumulado DECIMAL(14,2);

    SELECT COALESCE(SUM(monto), 0) INTO v_acumulado
    FROM pagos
    WHERE estado = 'Pagado'
      AND YEAR(fecha_pago) = YEAR(CURDATE());

    INSERT INTO notificaciones (destinatario, asunto, mensaje)
    VALUES ('Contador', 'Ingresos acumulados del anio',
            CONCAT('Ingresos acumulados en ', YEAR(CURDATE()), ': ', v_acumulado));
END $$
DELIMITER ;
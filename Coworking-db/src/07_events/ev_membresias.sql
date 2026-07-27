USE coworking_db;
SET GLOBAL event_scheduler = ON;

DROP EVENT IF EXISTS ev_membresias_vencidas;
DELIMITER $$
CREATE EVENT ev_membresias_vencidas
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
COMMENT 'Marca como Vencida las membresias cuya fecha_fin ya paso'
DO
BEGIN
    CALL sp_actualizar_membresias_vencidas(@n);
END $$
DELIMITER ;

DROP EVENT IF EXISTS ev_recordatorio_renovacion;
DELIMITER $$
CREATE EVENT ev_recordatorio_renovacion
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
COMMENT 'Avisa a los usuarios cuya membresia vence en 5 dias'
DO
BEGIN
    INSERT INTO notificaciones (id_usuario, destinatario, asunto, mensaje)
    SELECT m.id_usuario, 'Usuario', 'Tu membresia esta por vencer',
           CONCAT('Tu membresia vence el ', m.fecha_fin,
                  '. Renuevala para no perder el acceso.')
    FROM membresias m
    WHERE m.estado = 'Activa'
      AND m.fecha_fin = CURRENT_DATE + INTERVAL 5 DAY;
END $$
DELIMITER ;

DROP EVENT IF EXISTS ev_suspender_inactivas;
DELIMITER $$
CREATE EVENT ev_suspender_inactivas
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
COMMENT 'Suspende membresias de usuarios con mora mayor a 30 dias'
DO
BEGIN
    CALL sp_suspender_membresias_morosas(30, @n);
END $$
DELIMITER ;

DROP EVENT IF EXISTS ev_reporte_nuevas_membresias;
DELIMITER $$
CREATE EVENT ev_reporte_nuevas_membresias
ON SCHEDULE EVERY 1 WEEK
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
COMMENT 'Resumen semanal de nuevas membresias para el administrador'
DO
BEGIN
    DECLARE v_total INT;

    SELECT COUNT(*) INTO v_total
    FROM membresias
    WHERE fecha_registro >= NOW() - INTERVAL 7 DAY;

    INSERT INTO notificaciones (destinatario, asunto, mensaje)
    VALUES ('Administrador', 'Reporte semanal de membresias',
            CONCAT('En los ultimos 7 dias se registraron ', v_total,
                   ' nuevas membresias.'));
END $$
DELIMITER ;

DROP EVENT IF EXISTS ev_notificar_suspendidas;
DELIMITER $$
CREATE EVENT ev_notificar_suspendidas
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
COMMENT 'Informa a recepcion el total de membresias suspendidas'
DO
BEGIN
    DECLARE v_total INT;

    SELECT COUNT(*) INTO v_total
    FROM membresias WHERE estado = 'Suspendida';

    INSERT INTO notificaciones (destinatario, asunto, mensaje)
    VALUES ('Recepcion', 'Membresias suspendidas',
            CONCAT('Actualmente hay ', v_total,
                   ' membresias suspendidas que requieren gestion.'));
END $$
DELIMITER ;
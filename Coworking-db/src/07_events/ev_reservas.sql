USE coworking_db;

DROP EVENT IF EXISTS ev_cancelar_no_confirmadas;
DELIMITER $$
CREATE EVENT ev_cancelar_no_confirmadas
ON SCHEDULE EVERY 1 HOUR
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
COMMENT 'Libera reservas pendientes sin confirmar tras 2 horas'
DO
BEGIN
    CALL sp_liberar_reservas_no_confirmadas(2, @n);
END $$
DELIMITER ;

DROP EVENT IF EXISTS ev_recordatorio_reserva;
DELIMITER $$
CREATE EVENT ev_recordatorio_reserva
ON SCHEDULE EVERY 15 MINUTE
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
COMMENT 'Recuerda a los usuarios su reserva 1 hora antes'
DO
BEGIN
    INSERT INTO notificaciones (id_usuario, destinatario, asunto, mensaje)
    SELECT r.id_usuario, 'Usuario', 'Recordatorio de reserva',
           CONCAT('Tu reserva del espacio ', r.id_espacio,
                  ' comienza a las ', TIME(r.fecha_hora_inicio))
    FROM reservas r
    WHERE r.estado = 'Confirmada'
      AND r.fecha_hora_inicio BETWEEN NOW() AND NOW() + INTERVAL 1 HOUR;
END $$
DELIMITER ;

DROP EVENT IF EXISTS ev_eliminar_no_asistidas;
DELIMITER $$
CREATE EVENT ev_eliminar_no_asistidas
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
COMMENT 'Elimina reservas No Show con mas de 7 dias de antiguedad'
DO
BEGIN
    DELETE FROM reservas
    WHERE estado = 'No Show'
      AND fecha_hora_fin < NOW() - INTERVAL 7 DAY;
END $$
DELIMITER ;

DROP EVENT IF EXISTS ev_reporte_ocupacion;
DELIMITER $$
CREATE EVENT ev_reporte_ocupacion
ON SCHEDULE EVERY 1 WEEK
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
COMMENT 'Reporte semanal de ocupacion de espacios'
DO
BEGIN
    DECLARE v_total INT;

    SELECT COUNT(*) INTO v_total
    FROM reservas
    WHERE estado = 'Completada'
      AND fecha_hora_inicio >= NOW() - INTERVAL 7 DAY;

    INSERT INTO notificaciones (destinatario, asunto, mensaje)
    VALUES ('Administrador', 'Reporte semanal de ocupacion',
            CONCAT('En la ultima semana se completaron ', v_total,
                   ' reservas de espacios.'));
END $$
DELIMITER ;

DROP EVENT IF EXISTS ev_liberar_bloqueadas;
DELIMITER $$
CREATE EVENT ev_liberar_bloqueadas
ON SCHEDULE EVERY 15 MINUTE
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
COMMENT 'Marca No Show reservas no iniciadas tras 15 minutos'
DO
BEGIN
    UPDATE reservas r
    SET r.estado = 'No Show'
    WHERE r.estado = 'Confirmada'
      AND r.fecha_hora_inicio < NOW() - INTERVAL 15 MINUTE
      AND r.fecha_hora_inicio > NOW() - INTERVAL 1 DAY
      AND NOT EXISTS (
          SELECT 1 FROM accesos a
          WHERE a.id_usuario = r.id_usuario
            AND a.resultado = 'Permitido'
            AND DATE(a.fecha_hora_entrada) = DATE(r.fecha_hora_inicio)
      );
END $$
DELIMITER ;
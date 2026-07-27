USE coworking_db;

DROP EVENT IF EXISTS ev_eliminar_accesos_antiguos;
DELIMITER $$
CREATE EVENT ev_eliminar_accesos_antiguos
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
COMMENT 'Borra accesos con mas de 1 ano de antiguedad'
DO
BEGIN
    DELETE FROM accesos
    WHERE fecha_hora_entrada < NOW() - INTERVAL 1 YEAR;
END $$
DELIMITER ;

DROP EVENT IF EXISTS ev_reporte_diario_asistencias;
DELIMITER $$
CREATE EVENT ev_reporte_diario_asistencias
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
COMMENT 'Reporte diario de asistencias para el administrador'
DO
BEGIN
    DECLARE v_ingresos INT;
    DECLARE v_unicos   INT;
    DECLARE v_rechazos INT;
    DECLARE v_pico     INT;

    CALL sp_reporte_diario_asistencias(CURDATE() - INTERVAL 1 DAY,
                                       v_ingresos, v_unicos, v_rechazos, v_pico);

    INSERT INTO notificaciones (destinatario, asunto, mensaje)
    VALUES ('Administrador', 'Reporte diario de asistencias',
            CONCAT('Ayer -> Ingresos: ', COALESCE(v_ingresos,0),
                   ' | Usuarios unicos: ', COALESCE(v_unicos,0),
                   ' | Rechazos: ', COALESCE(v_rechazos,0),
                   ' | Hora pico: ', COALESCE(v_pico,0), 'h'));
END $$
DELIMITER ;

DROP EVENT IF EXISTS ev_reporte_usuarios_inactivos;
DELIMITER $$
CREATE EVENT ev_reporte_usuarios_inactivos
ON SCHEDULE EVERY 1 WEEK
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
COMMENT 'Reporte semanal de usuarios sin accesos recientes'
DO
BEGIN
    DECLARE v_total INT;

    SELECT COUNT(*) INTO v_total
    FROM usuarios u
    WHERE u.estado = 'Activo'
      AND NOT EXISTS (
          SELECT 1 FROM accesos a
          WHERE a.id_usuario = u.id_usuario
            AND a.resultado = 'Permitido'
            AND a.fecha_hora_entrada >= NOW() - INTERVAL 7 DAY
      );

    INSERT INTO notificaciones (destinatario, asunto, mensaje)
    VALUES ('Administrador', 'Usuarios inactivos esta semana',
            CONCAT(v_total, ' usuarios activos no ingresaron en los ultimos 7 dias.'));
END $$
DELIMITER ;

DROP EVENT IF EXISTS ev_alertar_fuera_horario;
DELIMITER $$
CREATE EVENT ev_alertar_fuera_horario
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
COMMENT 'Alerta accesos fuera del horario laboral'
DO
BEGIN
    DECLARE v_total INT;

    SELECT COUNT(*) INTO v_total
    FROM accesos
    WHERE resultado = 'Permitido'
      AND DATE(fecha_hora_entrada) = CURDATE() - INTERVAL 1 DAY
      AND (TIME(fecha_hora_entrada) < '07:00:00'
           OR TIME(fecha_hora_entrada) > '20:00:00');

    IF v_total > 0 THEN
        INSERT INTO notificaciones (destinatario, asunto, mensaje)
        VALUES ('Administrador', 'Accesos fuera de horario',
                CONCAT('Se detectaron ', v_total,
                       ' accesos fuera del horario laboral ayer.'));
    END IF;
END $$
DELIMITER ;

DROP EVENT IF EXISTS ev_top10_usuarios;
DELIMITER $$
CREATE EVENT ev_top10_usuarios
ON SCHEDULE EVERY 1 MONTH
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
COMMENT 'Top 10 usuarios mas frecuentes del mes'
DO
BEGIN
    DECLARE v_lista TEXT;

    SELECT GROUP_CONCAT(linea ORDER BY total DESC SEPARATOR ' | ')
      INTO v_lista
    FROM (
        SELECT CONCAT(u.nombre, ' ', u.apellidos, ' (', COUNT(*), ')') AS linea,
               COUNT(*) AS total
        FROM accesos a
        INNER JOIN usuarios u ON u.id_usuario = a.id_usuario
        WHERE a.resultado = 'Permitido'
          AND a.fecha_hora_entrada >= NOW() - INTERVAL 1 MONTH
        GROUP BY a.id_usuario
        ORDER BY total DESC
        LIMIT 10
    ) t;

    INSERT INTO notificaciones (destinatario, asunto, mensaje)
    VALUES ('Administrador', 'Top 10 usuarios del mes',
            COALESCE(v_lista, 'Sin accesos registrados en el ultimo mes'));
END $$
DELIMITER ;
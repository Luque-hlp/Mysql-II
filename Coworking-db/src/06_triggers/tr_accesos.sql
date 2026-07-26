USE coworking_db;

DROP TRIGGER IF EXISTS tr_acceso_estampar_entrada;
DELIMITER $$
CREATE TRIGGER tr_acceso_estampar_entrada
BEFORE INSERT ON accesos
FOR EACH ROW
BEGIN
    IF NEW.fecha_hora_entrada IS NULL THEN
        SET NEW.fecha_hora_entrada = NOW();
    END IF;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS tr_acceso_validar_membresia;
DELIMITER $$
CREATE TRIGGER tr_acceso_validar_membresia
BEFORE INSERT ON accesos
FOR EACH ROW
BEGIN
    IF NEW.resultado = 'Permitido'
       AND NEW.id_usuario IS NOT NULL
       AND NOT fn_membresia_activa(NEW.id_usuario) THEN
        SET NEW.resultado      = 'Rechazado';
        SET NEW.motivo_rechazo = 'Membresia vencida o inactiva';
    END IF;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS tr_acceso_actualizar_ultima_fecha;
DELIMITER $$
CREATE TRIGGER tr_acceso_actualizar_ultima_fecha
AFTER INSERT ON accesos
FOR EACH ROW
BEGIN
    IF NEW.resultado = 'Permitido' AND NEW.id_usuario IS NOT NULL THEN
        UPDATE usuarios
        SET ultima_fecha_acceso = NEW.fecha_hora_entrada
        WHERE id_usuario = NEW.id_usuario;
    END IF;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS tr_acceso_registrar_salida;
DELIMITER $$
CREATE TRIGGER tr_acceso_registrar_salida
AFTER UPDATE ON accesos
FOR EACH ROW
BEGIN
    IF OLD.fecha_hora_salida IS NULL
       AND NEW.fecha_hora_salida IS NOT NULL
       AND NEW.id_usuario IS NOT NULL THEN
        INSERT INTO notificaciones (id_usuario, destinatario, asunto, mensaje)
        VALUES (NEW.id_usuario, 'Administrador', 'Salida registrada',
                CONCAT('Se registro la salida del usuario ', NEW.id_usuario,
                       ' el ', NEW.fecha_hora_salida));
    END IF;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS tr_acceso_log_rechazado;
DELIMITER $$
CREATE TRIGGER tr_acceso_log_rechazado
AFTER INSERT ON accesos
FOR EACH ROW
BEGIN
    IF NEW.resultado = 'Rechazado' THEN
        INSERT INTO log_accesos_rechazados (id_usuario, codigo_presentado,
                                            tipo_credencial, motivo)
        VALUES (NEW.id_usuario, NEW.codigo_presentado, NEW.tipo_credencial,
                COALESCE(NEW.motivo_rechazo, 'Acceso rechazado'));
    END IF;
END $$
DELIMITER ;
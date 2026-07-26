USE coworking_db;

DROP TRIGGER IF EXISTS tr_membresia_before_insert;
DELIMITER $$
CREATE TRIGGER tr_membresia_before_insert
BEFORE INSERT ON membresias
FOR EACH ROW
BEGIN
    DECLARE v_duracion INT;

    IF NEW.fecha_fin IS NULL OR NEW.fecha_fin <= NEW.fecha_inicio THEN
        SELECT duracion_dias INTO v_duracion
        FROM tipos_membresia
        WHERE id_tipo_membresia = NEW.id_tipo_membresia;

        SET NEW.fecha_fin = DATE_ADD(NEW.fecha_inicio, INTERVAL v_duracion DAY);
    END IF;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS tr_membresia_activar_por_pago;
DELIMITER $$
CREATE TRIGGER tr_membresia_activar_por_pago
AFTER UPDATE ON facturas
FOR EACH ROW
BEGIN
    IF NEW.estado = 'Pagada' AND OLD.estado <> 'Pagada'
       AND NEW.id_membresia IS NOT NULL THEN
        UPDATE membresias
        SET estado = 'Activa'
        WHERE id_membresia = NEW.id_membresia
          AND estado <> 'Cancelada';
    END IF;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS tr_membresia_suspender_por_mora;
DELIMITER $$
CREATE TRIGGER tr_membresia_suspender_por_mora
AFTER UPDATE ON facturas
FOR EACH ROW
BEGIN
    IF NEW.estado = 'Vencida' AND OLD.estado <> 'Vencida'
       AND NEW.id_membresia IS NOT NULL THEN
        UPDATE membresias
        SET estado = 'Suspendida'
        WHERE id_membresia = NEW.id_membresia
          AND estado = 'Activa';
    END IF;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS tr_membresia_log_cambio_tipo;
DELIMITER $$
CREATE TRIGGER tr_membresia_log_cambio_tipo
AFTER UPDATE ON membresias
FOR EACH ROW
BEGIN
    IF NEW.id_tipo_membresia <> OLD.id_tipo_membresia THEN
        INSERT INTO log_membresias (id_membresia, id_usuario, campo_afectado,
                                    valor_anterior, valor_nuevo, usuario_sistema)
        VALUES (NEW.id_membresia, NEW.id_usuario, 'id_tipo_membresia',
                OLD.id_tipo_membresia, NEW.id_tipo_membresia, CURRENT_USER());
    END IF;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS tr_membresia_bloquear_delete;
DELIMITER $$
CREATE TRIGGER tr_membresia_bloquear_delete
BEFORE DELETE ON membresias
FOR EACH ROW
BEGIN
    DECLARE v_activas INT;

    SELECT COUNT(*) INTO v_activas
    FROM reservas
    WHERE id_usuario = OLD.id_usuario
      AND estado IN ('Pendiente', 'Confirmada')
      AND fecha_hora_inicio > NOW();

    IF v_activas > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede eliminar: el usuario tiene reservas activas';
    END IF;
END $$
DELIMITER ;
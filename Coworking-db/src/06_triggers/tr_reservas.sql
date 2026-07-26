USE coworking_db;

DROP TRIGGER IF EXISTS tr_reserva_validar_duplicada;
DELIMITER $$
CREATE TRIGGER tr_reserva_validar_duplicada
BEFORE INSERT ON reservas
FOR EACH ROW
BEGIN
    DECLARE v_conflictos INT;

    SELECT COUNT(*) INTO v_conflictos
    FROM reservas
    WHERE id_espacio        = NEW.id_espacio
      AND estado IN ('Pendiente', 'Confirmada', 'Completada')
      AND fecha_hora_inicio < NEW.fecha_hora_fin
      AND fecha_hora_fin    > NEW.fecha_hora_inicio;

    IF v_conflictos > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ya existe una reserva en ese espacio y horario';
    END IF;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS tr_reserva_estado_inicial;
DELIMITER $$
CREATE TRIGGER tr_reserva_estado_inicial
BEFORE INSERT ON reservas
FOR EACH ROW
BEGIN
    IF NEW.estado IS NULL OR NEW.estado = '' THEN
        SET NEW.estado = 'Pendiente';
    END IF;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS tr_reserva_confirmar_por_pago;
DELIMITER $$
CREATE TRIGGER tr_reserva_confirmar_por_pago
AFTER UPDATE ON facturas
FOR EACH ROW
BEGIN
    IF NEW.estado = 'Pagada' AND OLD.estado <> 'Pagada'
       AND NEW.id_reserva IS NOT NULL THEN
        UPDATE reservas
        SET estado = 'Confirmada'
        WHERE id_reserva = NEW.id_reserva
          AND estado = 'Pendiente';
    END IF;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS tr_reserva_cancelar_por_baja_membresia;
DELIMITER $$
CREATE TRIGGER tr_reserva_cancelar_por_baja_membresia
AFTER DELETE ON membresias
FOR EACH ROW
BEGIN
    UPDATE reservas
    SET estado = 'Cancelada',
        motivo_cancelacion = 'Cancelacion automatica por eliminacion de membresia'
    WHERE id_usuario = OLD.id_usuario
      AND estado IN ('Pendiente', 'Confirmada')
      AND fecha_hora_inicio > NOW();
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS tr_reserva_log_cancelacion;
DELIMITER $$
CREATE TRIGGER tr_reserva_log_cancelacion
AFTER UPDATE ON reservas
FOR EACH ROW
BEGIN
    IF NEW.estado = 'Cancelada' AND OLD.estado <> 'Cancelada' THEN
        INSERT INTO log_reservas_canceladas (id_reserva, id_usuario, id_espacio,
                                             estado_anterior, motivo, usuario_sistema)
        VALUES (NEW.id_reserva, NEW.id_usuario, NEW.id_espacio,
                OLD.estado, NEW.motivo_cancelacion, CURRENT_USER());
    END IF;
END $$
DELIMITER ;
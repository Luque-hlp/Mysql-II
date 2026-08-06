--lo unico que considere agregar fue la variable de fecha de inicio y fecha de vencimiento
DROP FUNCTION IF EXISTS fn_membresia_activa;
DELIMITER $$
CREATE FUNCTION fn_membresia_activa(p_id_usuario INT)-- creo la funcion membresia activa y utilizo el parametro del usuario como entero
RETURNS BOOLEAN -- quiero que retorne booleano
READS SQL DATA
BEGIN
    DECLARE v_total INT DEFAULT 0; -- declaro la variable total como entero 
    DECLARE fecha_inicio DATE; -- declaro la fecha inicio y la fecha de vencimiento
    DECLARE fecha_vencimiento DATE;

    SELECT COUNT(*) INTO v_total
    FROM membresias
    WHERE id_usuario = p_id_usuario
      AND estado = 'Activa'
      AND CURDATE() BETWEEN fecha_inicio AND fecha_fin;

    IF fecha_inicio >= fecha_vencimiento IS NULL OR v_total IN ('terminado', 'casi terminado') THEN
        RETURN v_total --si la fecha incio es mayor o igual a la fecha de vencimiento del lugar, se dara null o selecionara caducado o casi terminado
    END IF;

    RETURN v_total > 0;
END $$
DELIMITER ;

SELECT u.id_usuario, u.nombre, u.apellidos, --seleccion de la tabla usuarios, el usuario, nombre y apellido
       COUNT(DISTINCT r.id_reserva) AS reservas, -- hago un reconteo de las filas distintas de la tabla rembolsos, en este caso para distinguirlo, utilizando el nombre reserva
       COALESCE(SUM(DISTINCT f.total), 0) AS facturacion -- evalua todas las ileras de derecha a izquierda y suma el valor disntitivo de la tabla facturacion, en este caso la fila total. creando el alias facturacion
FROM usuarios u -- en usuarios
INNER JOIN reservas r  ON r.id_usuario = u.id_usuario --junto reservas con el usuario
INNER JOIN facturas f  ON f.id_usuario = u.id_usuario AND f.estado <> 'Anulada' -- junto facturas con el usuario y el estado de la factura, que da anulada
WHERE fn_membresia_activa(u.id_usuario) = TRUE --filtro la membresia activa, dentro del usuario, que da verdadero
GROUP BY u.id_usuario, u.nombre, u.apellidos --agrupo los usuarios, el nombre y el apellido
HAVING COUNT(DISTINCT r.id_reserva) > 5 -- hace un conteo distintivo de la reserva para 5 personas
   AND COALESCE(SUM(DISTINCT f.total), 0) > 500000 -- evalua todas las ileras de derecha a izquierda el valor distintivo del total de la facturaion y si es menor que 50000 da nulo
ORDER BY facturacion DESC;

DELIMITER $$
CREATE EVENT ev_automatico_backup --creo el evento automatico backup
ON SCHEDULE EVERY 1 DAY -- todos los dias
STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 2 HOUR) --empieza dando la fecha el intervalo del dia y el itervalo de las 2 horas
COMMENT 'Programado para las 2:00 a.m'--comenta que esta preparado par alas 2:00 de la mañana
DO

CREATE TABLE IF NOT EXISTS pagos_backup --si la tabla backup, no existe
TRUNCATE TABLE pagos_backup --borra todos los registros de la tabla si se llega a eliminar
INSERT INTO pagos_backup  SELECT * FROM pagos; -- se inserta dentro de pagos el evento, selecciona todo desde pagos.

END $$
DELIMITER ;

-- =====================================================================
-- CONSULTAS DQL - MODULO ESPACIOS Y RESERVAS  (21 a 40)
-- Proyecto: coworking_db
-- =====================================================================
USE coworking_db;

-- 21. Listar todos los espacios disponibles con su capacidad.
SELECT e.id_espacio, e.codigo, e.nombre, te.nombre AS tipo,
       e.capacidad_maxima, e.estado
FROM espacios e
INNER JOIN tipos_espacio te ON te.id_tipo_espacio = e.id_tipo_espacio
WHERE e.estado = 'Disponible'
ORDER BY e.capacidad_maxima DESC;

-- 22. Listar reservas activas en el dia actual.
SELECT r.id_reserva, u.nombre, u.apellidos, e.nombre AS espacio,
       r.fecha_hora_inicio, r.fecha_hora_fin, r.estado
FROM reservas r
INNER JOIN usuarios u ON u.id_usuario = r.id_usuario
INNER JOIN espacios e ON e.id_espacio = r.id_espacio
WHERE DATE(r.fecha_hora_inicio) = CURDATE()
  AND r.estado IN ('Pendiente', 'Confirmada')
ORDER BY r.fecha_hora_inicio;

-- 23. Mostrar reservas canceladas en el ultimo mes.
SELECT r.id_reserva, u.nombre, u.apellidos, e.nombre AS espacio,
       r.fecha_hora_inicio, r.motivo_cancelacion
FROM reservas r
INNER JOIN usuarios u ON u.id_usuario = r.id_usuario
INNER JOIN espacios e ON e.id_espacio = r.id_espacio
WHERE r.estado = 'Cancelada'
  AND r.fecha_creacion >= CURDATE() - INTERVAL 1 MONTH
ORDER BY r.fecha_hora_inicio DESC;

-- 24. Listar reservas de salas de reuniones en horario pico (9 am - 11 am).
SELECT r.id_reserva, u.nombre, e.nombre AS espacio, r.fecha_hora_inicio
FROM reservas r
INNER JOIN usuarios u ON u.id_usuario = r.id_usuario
INNER JOIN espacios e ON e.id_espacio = r.id_espacio
INNER JOIN tipos_espacio te ON te.id_tipo_espacio = e.id_tipo_espacio
WHERE te.nombre = 'Sala de reuniones'
  AND HOUR(r.fecha_hora_inicio) BETWEEN 9 AND 10
ORDER BY r.fecha_hora_inicio;

-- 25. Contar cuantas reservas se hacen por cada tipo de espacio.
SELECT te.nombre AS tipo_espacio, COUNT(r.id_reserva) AS total_reservas
FROM tipos_espacio te
LEFT JOIN espacios e ON e.id_tipo_espacio = te.id_tipo_espacio
LEFT JOIN reservas r ON r.id_espacio = e.id_espacio
GROUP BY te.id_tipo_espacio, te.nombre
ORDER BY total_reservas DESC;

-- 26. Mostrar el espacio mas reservado del ultimo mes.
SELECT e.id_espacio, e.nombre, COUNT(r.id_reserva) AS total
FROM espacios e
INNER JOIN reservas r ON r.id_espacio = e.id_espacio
WHERE r.fecha_hora_inicio >= CURDATE() - INTERVAL 1 MONTH
GROUP BY e.id_espacio, e.nombre
ORDER BY total DESC
LIMIT 1;

-- 27. Listar usuarios que mas han reservado salas privadas (oficinas privadas).
SELECT u.id_usuario, u.nombre, u.apellidos, COUNT(r.id_reserva) AS total
FROM usuarios u
INNER JOIN reservas r ON r.id_usuario = u.id_usuario
INNER JOIN espacios e ON e.id_espacio = r.id_espacio
INNER JOIN tipos_espacio te ON te.id_tipo_espacio = e.id_tipo_espacio
WHERE te.nombre = 'Oficina privada'
GROUP BY u.id_usuario, u.nombre, u.apellidos
ORDER BY total DESC
LIMIT 10;

-- 28. Mostrar reservas que exceden la capacidad maxima del espacio.
SELECT r.id_reserva, e.nombre AS espacio, e.capacidad_maxima,
       r.num_asistentes
FROM reservas r
INNER JOIN espacios e ON e.id_espacio = r.id_espacio
WHERE r.num_asistentes > e.capacidad_maxima
ORDER BY (r.num_asistentes - e.capacidad_maxima) DESC;

-- 29. Listar espacios que no se han reservado en la ultima semana.
SELECT e.id_espacio, e.nombre
FROM espacios e
WHERE NOT EXISTS (
    SELECT 1 FROM reservas r
    WHERE r.id_espacio = e.id_espacio
      AND r.fecha_hora_inicio >= CURDATE() - INTERVAL 7 DAY
)
ORDER BY e.id_espacio;

-- 30. Calcular la tasa de ocupacion promedio de cada espacio
--     (horas reservadas / horas disponibles aprox. en el ultimo mes).
SELECT e.id_espacio, e.nombre,
       COUNT(r.id_reserva) AS reservas,
       ROUND(SUM(TIMESTAMPDIFF(MINUTE, r.fecha_hora_inicio, r.fecha_hora_fin)) / 60, 1) AS horas_ocupadas
FROM espacios e
LEFT JOIN reservas r ON r.id_espacio = e.id_espacio
     AND r.estado IN ('Confirmada', 'Completada')
     AND r.fecha_hora_inicio >= CURDATE() - INTERVAL 1 MONTH
GROUP BY e.id_espacio, e.nombre
ORDER BY horas_ocupadas DESC;

-- 31. Mostrar reservas de mas de 8 horas.
SELECT r.id_reserva, u.nombre, e.nombre AS espacio,
       TIMESTAMPDIFF(HOUR, r.fecha_hora_inicio, r.fecha_hora_fin) AS horas
FROM reservas r
INNER JOIN usuarios u ON u.id_usuario = r.id_usuario
INNER JOIN espacios e ON e.id_espacio = r.id_espacio
WHERE TIMESTAMPDIFF(HOUR, r.fecha_hora_inicio, r.fecha_hora_fin) > 8
ORDER BY horas DESC;

-- 32. Identificar usuarios con mas de 20 reservas en total.
SELECT u.id_usuario, u.nombre, u.apellidos, COUNT(r.id_reserva) AS total
FROM usuarios u
INNER JOIN reservas r ON r.id_usuario = u.id_usuario
GROUP BY u.id_usuario, u.nombre, u.apellidos
HAVING COUNT(r.id_reserva) > 20
ORDER BY total DESC;

-- 33. Mostrar reservas realizadas por empresas con mas de 10 empleados.
SELECT e.nombre AS empresa, COUNT(r.id_reserva) AS total_reservas
FROM empresas e
INNER JOIN usuarios u ON u.id_empresa = e.id_empresa
INNER JOIN reservas r ON r.id_usuario = u.id_usuario
WHERE e.id_empresa IN (
    SELECT id_empresa FROM usuarios
    GROUP BY id_empresa HAVING COUNT(*) > 10
)
GROUP BY e.id_empresa, e.nombre
ORDER BY total_reservas DESC;

-- 34. Listar reservas que se solapan en horario (mismo espacio).
SELECT r1.id_reserva AS reserva_a, r2.id_reserva AS reserva_b,
       e.nombre AS espacio,
       r1.fecha_hora_inicio AS inicio_a, r2.fecha_hora_inicio AS inicio_b
FROM reservas r1
INNER JOIN reservas r2 ON r1.id_espacio = r2.id_espacio
     AND r1.id_reserva < r2.id_reserva
     AND r1.fecha_hora_inicio < r2.fecha_hora_fin
     AND r1.fecha_hora_fin    > r2.fecha_hora_inicio
INNER JOIN espacios e ON e.id_espacio = r1.id_espacio
WHERE r1.estado IN ('Pendiente','Confirmada','Completada')
  AND r2.estado IN ('Pendiente','Confirmada','Completada')
ORDER BY e.nombre;

-- 35. Listar reservas de fin de semana (sabado o domingo).
SELECT r.id_reserva, u.nombre, e.nombre AS espacio, r.fecha_hora_inicio,
       DAYNAME(r.fecha_hora_inicio) AS dia
FROM reservas r
INNER JOIN usuarios u ON u.id_usuario = r.id_usuario
INNER JOIN espacios e ON e.id_espacio = r.id_espacio
WHERE DAYOFWEEK(r.fecha_hora_inicio) IN (1, 7)
ORDER BY r.fecha_hora_inicio;

-- 36. Mostrar el porcentaje de ocupacion por cada tipo de espacio
--     (reservas del tipo sobre el total de reservas).
SELECT te.nombre AS tipo_espacio,
       COUNT(r.id_reserva) AS reservas,
       ROUND(100 * COUNT(r.id_reserva) /
             (SELECT COUNT(*) FROM reservas), 2) AS porcentaje
FROM tipos_espacio te
LEFT JOIN espacios e ON e.id_tipo_espacio = te.id_tipo_espacio
LEFT JOIN reservas r ON r.id_espacio = e.id_espacio
GROUP BY te.id_tipo_espacio, te.nombre
ORDER BY reservas DESC;

-- 37. Mostrar la duracion promedio de reservas por tipo de espacio.
SELECT te.nombre AS tipo_espacio,
       ROUND(AVG(TIMESTAMPDIFF(MINUTE, r.fecha_hora_inicio, r.fecha_hora_fin) / 60), 2) AS horas_promedio
FROM tipos_espacio te
INNER JOIN espacios e ON e.id_tipo_espacio = te.id_tipo_espacio
INNER JOIN reservas r ON r.id_espacio = e.id_espacio
GROUP BY te.id_tipo_espacio, te.nombre
ORDER BY horas_promedio DESC;

-- 38. Mostrar reservas con servicios adicionales incluidos.
SELECT DISTINCT r.id_reserva, u.nombre, e.nombre AS espacio,
       s.nombre AS servicio
FROM reservas r
INNER JOIN usuarios u ON u.id_usuario = r.id_usuario
INNER JOIN espacios e ON e.id_espacio = r.id_espacio
INNER JOIN servicios_contratados sc ON sc.id_reserva = r.id_reserva
INNER JOIN servicios s ON s.id_servicio = sc.id_servicio
ORDER BY r.id_reserva;

-- 39. Listar usuarios que reservaron sala de eventos en los ultimos 6 meses.
SELECT DISTINCT u.id_usuario, u.nombre, u.apellidos
FROM usuarios u
INNER JOIN reservas r ON r.id_usuario = u.id_usuario
INNER JOIN espacios e ON e.id_espacio = r.id_espacio
INNER JOIN tipos_espacio te ON te.id_tipo_espacio = e.id_tipo_espacio
WHERE te.nombre = 'Sala de eventos'
  AND r.fecha_hora_inicio >= CURDATE() - INTERVAL 6 MONTH
ORDER BY u.id_usuario;

-- 40. Identificar reservas realizadas y nunca asistidas (No Show).
SELECT r.id_reserva, u.nombre, u.apellidos, e.nombre AS espacio,
       r.fecha_hora_inicio
FROM reservas r
INNER JOIN usuarios u ON u.id_usuario = r.id_usuario
INNER JOIN espacios e ON e.id_espacio = r.id_espacio
WHERE r.estado = 'No Show'
ORDER BY r.fecha_hora_inicio DESC;
-- =====================================================================
-- CONSULTAS DQL - MODULO USUARIOS Y MEMBRESIAS  (1 a 20)
-- Proyecto: coworking_db
-- =====================================================================
USE coworking_db;
 
-- 1. Listar todos los usuarios con su informacion basica.
SELECT id_usuario, identificacion, nombre, apellidos, email, telefono, estado
FROM usuarios
ORDER BY id_usuario;

-- 2. Listar los usuarios con membresia activa.
SELECT DISTINCT u.id_usuario, u.nombre, u.apellidos, m.fecha_fin
FROM usuarios u
INNER JOIN membresias m ON m.id_usuario = u.id_usuario
WHERE m.estado = 'Activa'
  AND CURDATE() BETWEEN m.fecha_inicio AND m.fecha_fin
ORDER BY u.apellidos;

-- 3. Listar los usuarios cuya membresia esta vencida.
SELECT DISTINCT u.id_usuario, u.nombre, u.apellidos, m.fecha_fin
FROM usuarios u
INNER JOIN membresias m ON m.id_usuario = u.id_usuario
WHERE m.estado = 'Vencida'
ORDER BY m.fecha_fin DESC;

-- 4. Listar los usuarios con membresia suspendida.
SELECT DISTINCT u.id_usuario, u.nombre, u.apellidos
FROM usuarios u
INNER JOIN membresias m ON m.id_usuario = u.id_usuario
WHERE m.estado = 'Suspendida'
ORDER BY u.apellidos;

-- 5. Contar cuantos usuarios tienen cada tipo de membresia.
SELECT tm.nombre AS tipo_membresia, COUNT(DISTINCT m.id_usuario) AS total_usuarios
FROM tipos_membresia tm
LEFT JOIN membresias m ON m.id_tipo_membresia = tm.id_tipo_membresia
GROUP BY tm.id_tipo_membresia, tm.nombre
ORDER BY total_usuarios DESC;

-- 6. Mostrar el top 10 de usuarios con mas antiguedad en el coworking.
SELECT id_usuario, nombre, apellidos, fecha_registro,
       DATEDIFF(CURDATE(), fecha_registro) AS dias_antiguedad
FROM usuarios
ORDER BY fecha_registro ASC
LIMIT 10;

-- 7. Listar usuarios que pertenecen a una empresa especifica (ejemplo: empresa 1).
SELECT u.id_usuario, u.nombre, u.apellidos, e.nombre AS empresa
FROM usuarios u
INNER JOIN empresas e ON e.id_empresa = u.id_empresa
WHERE e.id_empresa = 1
ORDER BY u.apellidos;

-- 8. Contar cuantos usuarios estan asociados a cada empresa.
SELECT e.nombre AS empresa, COUNT(u.id_usuario) AS total_empleados
FROM empresas e
LEFT JOIN usuarios u ON u.id_empresa = e.id_empresa
GROUP BY e.id_empresa, e.nombre
ORDER BY total_empleados DESC;

-- 9. Mostrar usuarios que nunca han hecho una reserva.
SELECT u.id_usuario, u.nombre, u.apellidos
FROM usuarios u
WHERE NOT EXISTS (SELECT 1 FROM reservas r WHERE r.id_usuario = u.id_usuario)
ORDER BY u.id_usuario;

-- 10. Mostrar usuarios con mas de 5 reservas activas en el mes.
SELECT u.id_usuario, u.nombre, u.apellidos, COUNT(r.id_reserva) AS reservas_mes
FROM usuarios u
INNER JOIN reservas r ON r.id_usuario = u.id_usuario
WHERE r.estado IN ('Pendiente', 'Confirmada')
  AND MONTH(r.fecha_hora_inicio) = MONTH(CURDATE())
  AND YEAR(r.fecha_hora_inicio) = YEAR(CURDATE())
GROUP BY u.id_usuario, u.nombre, u.apellidos
HAVING COUNT(r.id_reserva) > 5
ORDER BY reservas_mes DESC;

-- 11. Calcular el promedio de edad de los usuarios.
SELECT ROUND(AVG(TIMESTAMPDIFF(YEAR, fecha_nacimiento, CURDATE())), 1) AS edad_promedio
FROM usuarios;

-- 12. Listar usuarios que han cambiado de membresia mas de 2 veces.
SELECT u.id_usuario, u.nombre, u.apellidos,
       COUNT(DISTINCT m.id_tipo_membresia) AS tipos_distintos
FROM usuarios u
INNER JOIN membresias m ON m.id_usuario = u.id_usuario
GROUP BY u.id_usuario, u.nombre, u.apellidos
HAVING COUNT(DISTINCT m.id_tipo_membresia) > 2
ORDER BY tipos_distintos DESC;

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
-- =====================================================================
-- CONSULTAS DQL - MODULO USUARIOS Y MEMBRESIAS  (1 a 20)
-- Proyecto: coworking_db
-- =====================================================================
USE coworking_db;
 
-- 1. Listar todos los usuarios con su informacion basica.
SELECT id_usuario, identificacion, nombre, apellidos, email, telefono, estado
FROM usuarios
ORDER BY id_usuario;
-- =====================================================================
-- CONSULTAS DQL - MODULO ACCESOS Y ASISTENCIAS  (61 a 80)
-- Proyecto: coworking_db
-- =====================================================================
USE coworking_db;

-- 61. Listar todos los accesos registrados hoy.
SELECT a.id_acceso, u.nombre, u.apellidos, a.fecha_hora_entrada, a.resultado
FROM accesos a
LEFT JOIN usuarios u ON u.id_usuario = a.id_usuario
WHERE DATE(a.fecha_hora_entrada) = CURDATE()
ORDER BY a.fecha_hora_entrada DESC;

-- 62. Mostrar usuarios con mas de 20 asistencias en el mes.
SELECT u.id_usuario, u.nombre, u.apellidos, COUNT(*) AS asistencias
FROM accesos a
INNER JOIN usuarios u ON u.id_usuario = a.id_usuario
WHERE a.resultado = 'Permitido'
  AND MONTH(a.fecha_hora_entrada) = MONTH(CURDATE())
  AND YEAR(a.fecha_hora_entrada) = YEAR(CURDATE())
GROUP BY u.id_usuario, u.nombre, u.apellidos
HAVING COUNT(*) > 20
ORDER BY asistencias DESC;

-- 63. Mostrar usuarios que no asistieron en la ultima semana.
SELECT u.id_usuario, u.nombre, u.apellidos
FROM usuarios u
WHERE u.estado = 'Activo'
  AND NOT EXISTS (
      SELECT 1 FROM accesos a
      WHERE a.id_usuario = u.id_usuario
        AND a.resultado = 'Permitido'
        AND a.fecha_hora_entrada >= CURDATE() - INTERVAL 7 DAY
  )
ORDER BY u.id_usuario;

-- 64. Calcular la asistencia promedio por dia de la semana.
SELECT DAYNAME(fecha_hora_entrada) AS dia,
       COUNT(*) AS total_accesos
FROM accesos
WHERE resultado = 'Permitido'
GROUP BY DAYOFWEEK(fecha_hora_entrada), DAYNAME(fecha_hora_entrada)
ORDER BY DAYOFWEEK(fecha_hora_entrada);

-- 65. Mostrar los 10 usuarios mas constantes (mas asistencias).
SELECT u.id_usuario, u.nombre, u.apellidos, COUNT(*) AS asistencias
FROM accesos a
INNER JOIN usuarios u ON u.id_usuario = a.id_usuario
WHERE a.resultado = 'Permitido'
GROUP BY u.id_usuario, u.nombre, u.apellidos
ORDER BY asistencias DESC
LIMIT 10;

-- 66. Mostrar accesos fuera del horario permitido (antes de 7 o despues de 20).
SELECT a.id_acceso, u.nombre, a.fecha_hora_entrada
FROM accesos a
LEFT JOIN usuarios u ON u.id_usuario = a.id_usuario
WHERE TIME(a.fecha_hora_entrada) < '07:00:00'
   OR TIME(a.fecha_hora_entrada) > '20:00:00'
ORDER BY a.fecha_hora_entrada DESC;

-- 67. Mostrar usuarios que accedieron sin membresia activa (rechazados).
SELECT a.id_acceso, u.nombre, a.motivo_rechazo, a.fecha_hora_entrada
FROM accesos a
INNER JOIN usuarios u ON u.id_usuario = a.id_usuario
WHERE a.resultado = 'Rechazado'
  AND a.motivo_rechazo LIKE '%embresia%'
ORDER BY a.fecha_hora_entrada DESC;

-- 68. Listar usuarios que solo acceden los fines de semana.
SELECT u.id_usuario, u.nombre, u.apellidos
FROM usuarios u
INNER JOIN accesos a ON a.id_usuario = u.id_usuario AND a.resultado = 'Permitido'
GROUP BY u.id_usuario, u.nombre, u.apellidos
HAVING SUM(CASE WHEN DAYOFWEEK(a.fecha_hora_entrada) IN (1,7) THEN 0 ELSE 1 END) = 0
ORDER BY u.id_usuario;

-- 69. Mostrar usuarios que accedieron mas de 2 veces en el mismo dia.
SELECT u.id_usuario, u.nombre, DATE(a.fecha_hora_entrada) AS dia, COUNT(*) AS veces
FROM accesos a
INNER JOIN usuarios u ON u.id_usuario = a.id_usuario
WHERE a.resultado = 'Permitido'
GROUP BY u.id_usuario, u.nombre, DATE(a.fecha_hora_entrada)
HAVING COUNT(*) > 2
ORDER BY veces DESC;

-- 70. Mostrar el total de accesos diarios en el ultimo mes.
SELECT DATE(fecha_hora_entrada) AS dia, COUNT(*) AS total
FROM accesos
WHERE resultado = 'Permitido'
  AND fecha_hora_entrada >= CURDATE() - INTERVAL 1 MONTH
GROUP BY DATE(fecha_hora_entrada)
ORDER BY dia DESC;

-- 71. Mostrar usuarios que han accedido pero no tienen reservas.
SELECT DISTINCT u.id_usuario, u.nombre, u.apellidos
FROM usuarios u
INNER JOIN accesos a ON a.id_usuario = u.id_usuario AND a.resultado = 'Permitido'
WHERE NOT EXISTS (SELECT 1 FROM reservas r WHERE r.id_usuario = u.id_usuario)
ORDER BY u.id_usuario;

-- 72. Mostrar los dias con mas concurrencia en el coworking.
SELECT DATE(fecha_hora_entrada) AS dia, COUNT(*) AS accesos
FROM accesos
WHERE resultado = 'Permitido'
GROUP BY DATE(fecha_hora_entrada)
ORDER BY accesos DESC
LIMIT 10;

-- 73. Mostrar usuarios que entraron pero no registraron salida.
SELECT a.id_acceso, u.nombre, a.fecha_hora_entrada
FROM accesos a
INNER JOIN usuarios u ON u.id_usuario = a.id_usuario
WHERE a.resultado = 'Permitido'
  AND a.fecha_hora_salida IS NULL
ORDER BY a.fecha_hora_entrada DESC;

-- 74. Mostrar accesos de usuarios con membresia vencida.
SELECT a.id_acceso, u.nombre, a.fecha_hora_entrada
FROM accesos a
INNER JOIN usuarios u ON u.id_usuario = a.id_usuario
WHERE EXISTS (
    SELECT 1 FROM membresias m
    WHERE m.id_usuario = u.id_usuario AND m.estado = 'Vencida'
)
AND NOT fn_membresia_activa(u.id_usuario)
ORDER BY a.fecha_hora_entrada DESC;

-- 75. Mostrar accesos de usuarios corporativos por empresa.
SELECT e.nombre AS empresa, COUNT(a.id_acceso) AS total_accesos
FROM accesos a
INNER JOIN usuarios u ON u.id_usuario = a.id_usuario
INNER JOIN empresas e ON e.id_empresa = u.id_empresa
WHERE a.resultado = 'Permitido'
GROUP BY e.id_empresa, e.nombre
ORDER BY total_accesos DESC;

-- 76. Mostrar clientes que nunca han usado el coworking a pesar de pagar membresia.
SELECT DISTINCT u.id_usuario, u.nombre, u.apellidos
FROM usuarios u
INNER JOIN membresias m ON m.id_usuario = u.id_usuario AND m.estado = 'Activa'
WHERE NOT EXISTS (
    SELECT 1 FROM accesos a
    WHERE a.id_usuario = u.id_usuario AND a.resultado = 'Permitido'
)
ORDER BY u.id_usuario;

-- 77. Mostrar accesos rechazados por intentos con QR invalido.
SELECT a.id_acceso, a.codigo_presentado, a.motivo_rechazo, a.fecha_hora_entrada
FROM accesos a
WHERE a.resultado = 'Rechazado'
  AND a.motivo_rechazo LIKE '%QR%'
ORDER BY a.fecha_hora_entrada DESC;

-- 78. Mostrar accesos promedio por usuario.
SELECT ROUND(AVG(total), 2) AS accesos_promedio
FROM (
    SELECT id_usuario, COUNT(*) AS total
    FROM accesos
    WHERE resultado = 'Permitido' AND id_usuario IS NOT NULL
    GROUP BY id_usuario
) t;

-- 79. Identificar usuarios que asisten mas en la manana (antes de las 12).
SELECT u.id_usuario, u.nombre, COUNT(*) AS accesos_manana
FROM accesos a
INNER JOIN usuarios u ON u.id_usuario = a.id_usuario
WHERE a.resultado = 'Permitido'
  AND HOUR(a.fecha_hora_entrada) < 12
GROUP BY u.id_usuario, u.nombre
ORDER BY accesos_manana DESC
LIMIT 10;

-- 80. Identificar usuarios que asisten mas en la noche (18 en adelante).
SELECT u.id_usuario, u.nombre, COUNT(*) AS accesos_noche
FROM accesos a
INNER JOIN usuarios u ON u.id_usuario = a.id_usuario
WHERE a.resultado = 'Permitido'
  AND HOUR(a.fecha_hora_entrada) >= 18
GROUP BY u.id_usuario, u.nombre
ORDER BY accesos_noche DESC
LIMIT 10;
-- =====================================================================
-- CONSULTAS DQL - AVANZADAS  (81 a 100)
-- Proyecto: coworking_db
-- Subconsultas, multiples joins, agregaciones y funciones de ventana.
-- =====================================================================
USE coworking_db;

-- 81. Usuarios con el mayor gasto acumulado (subconsulta con SUM).
SELECT u.id_usuario, u.nombre, u.apellidos,
       (SELECT COALESCE(SUM(p.monto), 0)
        FROM facturas f
        INNER JOIN pagos p ON p.id_factura = f.id_factura
        WHERE f.id_usuario = u.id_usuario AND p.estado = 'Pagado') AS gasto_total
FROM usuarios u
ORDER BY gasto_total DESC
LIMIT 10;

-- 82. Espacios mas ocupados considerando reservas confirmadas y asistencias reales.
SELECT e.id_espacio, e.nombre,
       COUNT(DISTINCT r.id_reserva) AS reservas_confirmadas
FROM espacios e
INNER JOIN reservas r ON r.id_espacio = e.id_espacio
     AND r.estado IN ('Confirmada', 'Completada')
GROUP BY e.id_espacio, e.nombre
ORDER BY reservas_confirmadas DESC
LIMIT 10;

-- 83. Promedio de ingresos por usuario usando subconsultas.
SELECT ROUND(
    (SELECT COALESCE(SUM(monto), 0) FROM pagos WHERE estado = 'Pagado')
    /
    (SELECT COUNT(*) FROM usuarios), 2) AS ingreso_promedio_por_usuario;

-- 84. Usuarios que tienen reservas activas Y facturas pendientes.
SELECT DISTINCT u.id_usuario, u.nombre, u.apellidos
FROM usuarios u
WHERE EXISTS (
        SELECT 1 FROM reservas r
        WHERE r.id_usuario = u.id_usuario
          AND r.estado IN ('Pendiente', 'Confirmada'))
  AND EXISTS (
        SELECT 1 FROM facturas f
        WHERE f.id_usuario = u.id_usuario
          AND f.estado IN ('Pendiente', 'Parcial', 'Vencida'))
ORDER BY u.id_usuario;

-- 85. Empresas cuyos empleados generan mas del 20% de los ingresos totales.
SELECT e.nombre AS empresa,
       SUM(p.monto) AS ingresos,
       ROUND(100 * SUM(p.monto) /
             (SELECT SUM(monto) FROM pagos WHERE estado = 'Pagado'), 2) AS porcentaje
FROM empresas e
INNER JOIN usuarios u ON u.id_empresa = e.id_empresa
INNER JOIN facturas f ON f.id_usuario = u.id_usuario
INNER JOIN pagos p ON p.id_factura = f.id_factura
WHERE p.estado = 'Pagado'
GROUP BY e.id_empresa, e.nombre
HAVING porcentaje > 20
ORDER BY porcentaje DESC;

-- 86. Top 5 de usuarios que mas usan servicios adicionales.
SELECT u.id_usuario, u.nombre, u.apellidos, COUNT(sc.id_servicio_contratado) AS servicios
FROM usuarios u
INNER JOIN servicios_contratados sc ON sc.id_usuario = u.id_usuario
GROUP BY u.id_usuario, u.nombre, u.apellidos
ORDER BY servicios DESC
LIMIT 5;

-- 87. Reservas que generaron facturas mayores al promedio.
SELECT f.numero_factura, f.id_reserva, f.total
FROM facturas f
WHERE f.tipo_origen = 'Reserva'
  AND f.total > (SELECT AVG(total) FROM facturas WHERE tipo_origen = 'Reserva')
ORDER BY f.total DESC;

-- 88. Porcentaje de ocupacion global del coworking por mes.
SELECT YEAR(r.fecha_hora_inicio) AS anio, MONTH(r.fecha_hora_inicio) AS mes,
       COUNT(*) AS reservas,
       ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM reservas), 2) AS porcentaje_del_total
FROM reservas r
GROUP BY YEAR(r.fecha_hora_inicio), MONTH(r.fecha_hora_inicio)
ORDER BY anio, mes;

-- 89. Usuarios con mas horas de reserva que el promedio del sistema.
SELECT u.id_usuario, u.nombre,
       ROUND(SUM(TIMESTAMPDIFF(MINUTE, r.fecha_hora_inicio, r.fecha_hora_fin)) / 60, 1) AS horas
FROM usuarios u
INNER JOIN reservas r ON r.id_usuario = u.id_usuario
GROUP BY u.id_usuario, u.nombre
HAVING horas > (
    SELECT AVG(horas_u) FROM (
        SELECT SUM(TIMESTAMPDIFF(MINUTE, fecha_hora_inicio, fecha_hora_fin)) / 60 AS horas_u
        FROM reservas GROUP BY id_usuario
    ) sub
)
ORDER BY horas DESC;

-- 90. Top 3 de salas mas usadas en el ultimo trimestre.
SELECT e.id_espacio, e.nombre, COUNT(*) AS usos
FROM reservas r
INNER JOIN espacios e ON e.id_espacio = r.id_espacio
WHERE r.fecha_hora_inicio >= CURDATE() - INTERVAL 3 MONTH
GROUP BY e.id_espacio, e.nombre
ORDER BY usos DESC
LIMIT 3;

-- 91. Ingresos promedio por tipo de membresia (agrupado con AVG).
SELECT tm.nombre AS tipo_membresia, ROUND(AVG(f.total), 2) AS factura_promedio
FROM tipos_membresia tm
INNER JOIN membresias m ON m.id_tipo_membresia = tm.id_tipo_membresia
INNER JOIN facturas f ON f.id_membresia = m.id_membresia
GROUP BY tm.id_tipo_membresia, tm.nombre
ORDER BY factura_promedio DESC;

-- 92. Usuarios que pagan solo con un metodo de pago (subconsulta).
SELECT u.id_usuario, u.nombre, u.apellidos,
       MIN(mp.nombre) AS unico_metodo
FROM usuarios u
INNER JOIN facturas f ON f.id_usuario = u.id_usuario
INNER JOIN pagos p ON p.id_factura = f.id_factura
INNER JOIN metodos_pago mp ON mp.id_metodo_pago = p.id_metodo_pago
WHERE p.estado = 'Pagado'
GROUP BY u.id_usuario, u.nombre, u.apellidos
HAVING COUNT(DISTINCT p.id_metodo_pago) = 1
ORDER BY u.id_usuario;

-- 93. Reservas canceladas por usuarios que nunca asistieron.
SELECT r.id_reserva, u.nombre, u.apellidos, r.motivo_cancelacion
FROM reservas r
INNER JOIN usuarios u ON u.id_usuario = r.id_usuario
WHERE r.estado = 'Cancelada'
  AND NOT EXISTS (
      SELECT 1 FROM accesos a
      WHERE a.id_usuario = u.id_usuario AND a.resultado = 'Permitido'
  )
ORDER BY r.id_reserva;

-- 94. Facturas con pagos parciales y su saldo pendiente.
SELECT f.numero_factura, f.total,
       fn_total_pagado_factura(f.id_factura) AS pagado,
       f.saldo_pendiente
FROM facturas f
WHERE f.estado = 'Parcial'
ORDER BY f.saldo_pendiente DESC;

-- 95. Facturacion total de cada empresa, ordenada de mayor a menor.
SELECT e.nombre AS empresa, COALESCE(SUM(f.total), 0) AS facturacion_total
FROM empresas e
LEFT JOIN usuarios u ON u.id_empresa = e.id_empresa
LEFT JOIN facturas f ON f.id_usuario = u.id_usuario AND f.estado <> 'Anulada'
GROUP BY e.id_empresa, e.nombre
ORDER BY facturacion_total DESC;

-- 96. Usuarios que superan en reservas al promedio de su empresa.
SELECT u.id_usuario, u.nombre, e.nombre AS empresa,
       COUNT(r.id_reserva) AS reservas
FROM usuarios u
INNER JOIN empresas e ON e.id_empresa = u.id_empresa
INNER JOIN reservas r ON r.id_usuario = u.id_usuario
INNER JOIN (
    -- promedio de reservas por empresa, precalculado
    SELECT u2.id_empresa, AVG(cnt) AS promedio_empresa
    FROM (
        SELECT u3.id_empresa, r3.id_usuario, COUNT(*) AS cnt
        FROM reservas r3
        INNER JOIN usuarios u3 ON u3.id_usuario = r3.id_usuario
        WHERE u3.id_empresa IS NOT NULL
        GROUP BY u3.id_empresa, r3.id_usuario
    ) u2
    GROUP BY u2.id_empresa
) prom ON prom.id_empresa = u.id_empresa
GROUP BY u.id_usuario, u.nombre, e.nombre, prom.promedio_empresa
HAVING COUNT(r.id_reserva) > prom.promedio_empresa
ORDER BY reservas DESC;

-- 97. Las 3 empresas con mas empleados activos en el coworking.
SELECT e.nombre AS empresa, COUNT(*) AS empleados_activos
FROM empresas e
INNER JOIN usuarios u ON u.id_empresa = e.id_empresa
WHERE u.estado = 'Activo'
GROUP BY e.id_empresa, e.nombre
ORDER BY empleados_activos DESC
LIMIT 3;

-- 98. Porcentaje de usuarios activos frente al total de registrados.
SELECT
    (SELECT COUNT(*) FROM usuarios WHERE estado = 'Activo') AS activos,
    (SELECT COUNT(*) FROM usuarios) AS total,
    ROUND(100 * (SELECT COUNT(*) FROM usuarios WHERE estado = 'Activo')
              / (SELECT COUNT(*) FROM usuarios), 2) AS porcentaje_activos;

-- 99. Ingresos mensuales acumulados con funcion de ventana (OVER).
SELECT mes,
       ingresos_mes,
       SUM(ingresos_mes) OVER (ORDER BY mes) AS ingresos_acumulados
FROM (
    SELECT MONTH(fecha_pago) AS mes, SUM(monto) AS ingresos_mes
    FROM pagos
    WHERE estado = 'Pagado' AND YEAR(fecha_pago) = YEAR(CURDATE())
    GROUP BY MONTH(fecha_pago)
) t
ORDER BY mes;

-- 100. Usuarios con mas de 10 reservas, mas de $500.000 en facturacion
--      y membresia activa (multiples joins).
SELECT u.id_usuario, u.nombre, u.apellidos,
       COUNT(DISTINCT r.id_reserva) AS reservas,
       COALESCE(SUM(DISTINCT f.total), 0) AS facturacion
FROM usuarios u
INNER JOIN reservas r  ON r.id_usuario = u.id_usuario
INNER JOIN facturas f  ON f.id_usuario = u.id_usuario AND f.estado <> 'Anulada'
WHERE fn_membresia_activa(u.id_usuario) = TRUE
GROUP BY u.id_usuario, u.nombre, u.apellidos
HAVING COUNT(DISTINCT r.id_reserva) > 10
   AND COALESCE(SUM(DISTINCT f.total), 0) > 500000
ORDER BY facturacion DESC;
-- =====================================================================
-- CONSULTAS DQL - MODULO PAGOS Y FACTURACION  (41 a 60)
-- Proyecto: coworking_db
-- =====================================================================
USE coworking_db;

-- 41. Listar todos los pagos realizados con metodo tarjeta.
SELECT p.id_pago, f.numero_factura, p.monto, p.fecha_pago
FROM pagos p
INNER JOIN metodos_pago mp ON mp.id_metodo_pago = p.id_metodo_pago
INNER JOIN facturas f ON f.id_factura = p.id_factura
WHERE mp.nombre = 'Tarjeta' AND p.estado = 'Pagado'
ORDER BY p.fecha_pago DESC;

-- 42. Listar pagos pendientes de usuarios (facturas con saldo).
SELECT u.id_usuario, u.nombre, f.numero_factura, f.saldo_pendiente
FROM facturas f
INNER JOIN usuarios u ON u.id_usuario = f.id_usuario
WHERE f.estado IN ('Pendiente', 'Parcial')
  AND f.saldo_pendiente > 0
ORDER BY f.saldo_pendiente DESC;

-- 43. Mostrar pagos cancelados en los ultimos 3 meses.
SELECT p.id_pago, f.numero_factura, p.monto, p.fecha_pago
FROM pagos p
INNER JOIN facturas f ON f.id_factura = p.id_factura
WHERE p.estado = 'Cancelado'
  AND p.fecha_pago >= CURDATE() - INTERVAL 3 MONTH
ORDER BY p.fecha_pago DESC;

-- 44. Listar facturas generadas por membresias.
SELECT f.numero_factura, u.nombre, f.total, f.estado, f.fecha_emision
FROM facturas f
INNER JOIN usuarios u ON u.id_usuario = f.id_usuario
WHERE f.tipo_origen = 'Membresia'
ORDER BY f.fecha_emision DESC;

-- 45. Listar facturas generadas por reservas.
SELECT f.numero_factura, u.nombre, f.total, f.estado, f.fecha_emision
FROM facturas f
INNER JOIN usuarios u ON u.id_usuario = f.id_usuario
WHERE f.tipo_origen = 'Reserva'
ORDER BY f.fecha_emision DESC;

-- 46. Mostrar el total de ingresos por membresias en el ultimo mes.
SELECT COALESCE(SUM(p.monto), 0) AS ingresos_membresias
FROM pagos p
INNER JOIN facturas f ON f.id_factura = p.id_factura
WHERE f.tipo_origen = 'Membresia'
  AND p.estado = 'Pagado'
  AND p.fecha_pago >= CURDATE() - INTERVAL 1 MONTH;

-- 47. Mostrar el total de ingresos por reservas en el ultimo mes.
SELECT COALESCE(SUM(p.monto), 0) AS ingresos_reservas
FROM pagos p
INNER JOIN facturas f ON f.id_factura = p.id_factura
WHERE f.tipo_origen = 'Reserva'
  AND p.estado = 'Pagado'
  AND p.fecha_pago >= CURDATE() - INTERVAL 1 MONTH;

-- 48. Mostrar el total de ingresos por servicios adicionales.
SELECT COALESCE(SUM(subtotal), 0) AS ingresos_servicios
FROM servicios_contratados
WHERE estado <> 'Bloqueado';

-- 49. Identificar usuarios que nunca han pagado con PayPal.
SELECT u.id_usuario, u.nombre, u.apellidos
FROM usuarios u
WHERE u.id_usuario NOT IN (
    SELECT DISTINCT f.id_usuario
    FROM facturas f
    INNER JOIN pagos p ON p.id_factura = f.id_factura
    INNER JOIN metodos_pago mp ON mp.id_metodo_pago = p.id_metodo_pago
    WHERE mp.nombre = 'PayPal'
)
ORDER BY u.id_usuario;

-- 50. Calcular el promedio de gasto por usuario.
SELECT ROUND(AVG(gasto), 2) AS gasto_promedio
FROM (
    SELECT f.id_usuario, SUM(p.monto) AS gasto
    FROM facturas f
    INNER JOIN pagos p ON p.id_factura = f.id_factura
    WHERE p.estado = 'Pagado'
    GROUP BY f.id_usuario
) t;

-- 51. Mostrar el top 5 de usuarios que mas han pagado en total.
SELECT u.id_usuario, u.nombre, u.apellidos, SUM(p.monto) AS total_pagado
FROM usuarios u
INNER JOIN facturas f ON f.id_usuario = u.id_usuario
INNER JOIN pagos p ON p.id_factura = f.id_factura
WHERE p.estado = 'Pagado'
GROUP BY u.id_usuario, u.nombre, u.apellidos
ORDER BY total_pagado DESC
LIMIT 5;

-- 52. Mostrar facturas con monto mayor a $1.000.000.
SELECT numero_factura, id_usuario, total, estado
FROM facturas
WHERE total > 1000000
ORDER BY total DESC;

-- 53. Listar pagos realizados despues de la fecha de vencimiento.
SELECT p.id_pago, f.numero_factura, f.fecha_vencimiento, p.fecha_pago
FROM pagos p
INNER JOIN facturas f ON f.id_factura = p.id_factura
WHERE DATE(p.fecha_pago) > f.fecha_vencimiento
  AND p.estado = 'Pagado'
ORDER BY p.fecha_pago DESC;

-- 54. Calcular el total recaudado en el anio actual.
SELECT COALESCE(SUM(monto), 0) AS recaudado_anio
FROM pagos
WHERE estado = 'Pagado' AND YEAR(fecha_pago) = YEAR(CURDATE());

-- 55. Mostrar facturas anuladas y su motivo.
SELECT numero_factura, id_usuario, total, motivo_anulacion
FROM facturas
WHERE estado = 'Anulada'
ORDER BY fecha_emision DESC;

-- 56. Mostrar usuarios con facturas pendientes mayores a $200.000.
SELECT u.id_usuario, u.nombre, f.numero_factura, f.saldo_pendiente
FROM facturas f
INNER JOIN usuarios u ON u.id_usuario = f.id_usuario
WHERE f.estado IN ('Pendiente', 'Parcial', 'Vencida')
  AND f.saldo_pendiente > 200000
ORDER BY f.saldo_pendiente DESC;

-- 57. Mostrar usuarios que han pagado mas de una vez el mismo servicio.
SELECT u.id_usuario, u.nombre, s.nombre AS servicio, COUNT(*) AS veces
FROM servicios_contratados sc
INNER JOIN usuarios u ON u.id_usuario = sc.id_usuario
INNER JOIN servicios s ON s.id_servicio = sc.id_servicio
GROUP BY u.id_usuario, u.nombre, s.id_servicio, s.nombre
HAVING COUNT(*) > 1
ORDER BY veces DESC;

-- 58. Listar ingresos por cada metodo de pago.
SELECT mp.nombre AS metodo, COALESCE(SUM(p.monto), 0) AS total
FROM metodos_pago mp
LEFT JOIN pagos p ON p.id_metodo_pago = mp.id_metodo_pago
     AND p.estado = 'Pagado'
GROUP BY mp.id_metodo_pago, mp.nombre
ORDER BY total DESC;

-- 59. Mostrar facturacion acumulada por empresa.
SELECT e.nombre AS empresa, COALESCE(SUM(f.total), 0) AS facturado
FROM empresas e
INNER JOIN usuarios u ON u.id_empresa = e.id_empresa
INNER JOIN facturas f ON f.id_usuario = u.id_usuario
WHERE f.estado <> 'Anulada'
GROUP BY e.id_empresa, e.nombre
ORDER BY facturado DESC;

-- 60. Mostrar ingresos netos por mes del ultimo anio.
SELECT YEAR(p.fecha_pago) AS anio, MONTH(p.fecha_pago) AS mes,
       SUM(p.monto) AS ingresos
FROM pagos p
WHERE p.estado = 'Pagado'
  AND p.fecha_pago >= CURDATE() - INTERVAL 1 YEAR
GROUP BY YEAR(p.fecha_pago), MONTH(p.fecha_pago)
ORDER BY anio, mes;
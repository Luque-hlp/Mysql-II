-- 1. Estructura (crea la base de datos y las 23 tablas)
SOURCE src/01_ddl/ddl.sql;
 
 -- 2. Funciones  (van ANTES que todo lo demas: procedimientos,
--    triggers y eventos las invocan)
SOURCE src/04_functions/fn_membresias.sql;
SOURCE src/04_functions/fn_reservas.sql;
SOURCE src/04_functions/fn_facturacion.sql;
SOURCE src/04_functions/fn_accesos.sql;
 
-- 3. Procedimientos almacenados
SOURCE src/05_procedures/sp_membresias.sql;
SOURCE src/05_procedures/sp_reservas.sql;
SOURCE src/05_procedures/sp_facturacion.sql;
SOURCE src/05_procedures/sp_accesos.sql;
SOURCE src/05_procedures/sp_corporativos.sql;
 
-- 4. Triggers
SOURCE src/06_triggers/tr_membresias.sql;
SOURCE src/06_triggers/tr_reservas.sql;
SOURCE src/06_triggers/tr_facturacion.sql;
SOURCE src/06_triggers/tr_accesos.sql;
 
-- 5. Eventos  (requieren event_scheduler activo)
SET GLOBAL event_scheduler = ON;
SOURCE src/07_events/ev_membresias.sql;
SOURCE src/07_events/ev_reservas.sql;
SOURCE src/07_events/ev_facturacion.sql;
SOURCE src/07_events/ev_accesos.sql;
 
-- 6. Roles y usuarios
SOURCE src/08_roles/roles.sql;
SOURCE src/08_roles/usuarios_permisos.sql;
 
-- 7. Datos de prueba AL FINAL: se cargan con los triggers ya activos,
--    de modo que los datos quedan validados por toda la logica.
SOURCE src/02_dml/dml.sql;
 
SELECT 'Instalacion completada correctamente' AS resultado;
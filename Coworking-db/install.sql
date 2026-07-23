--1. Estructura
SOURCE src/01_ddl/ddl.sql;

--2. Datos de prueba
SOURCE src/02_dml/dml.sql;

--3. Funciones
SOURCE src/04_functions/fn_membresias.sql;
SOURCE src/04_functions/fn_reservas.sql;
SOURCE src/04_functions/fn_facturacion.sql;
SOURCE src/04_functions/fn_accesos.sql;

--4. Procedimientos almacenados
SOURCE src/05_procedures/sp_membresias.sql;
SOURCE src/05_procedures/sp_reservas.sql;
SOURCE src/05_procedures/sp_facturacion.sql;
SOURCE src/05_procedures/sp_accesos.sql;
SOURCE src/05_procedures/sp_corporativos.sql;

--5. Triggers

SOURCE src/06_triggers/tr_membresias.sql;
SOURCE src/06_triggers/tr_reservas.sql;
SOURCE src/06_triggers/tr_facturacion.sql;
SOURCE src/06_triggers/tr_accesos.sql;

--6. Eventos (Requieren el scheduler activo)

SET GLOBAL event_scheduler = ON;
SOURCE src/07_events/ev_membresia.sql;
SOURCE src/07_events/ev_reservas.sql;
SOURCE src/07_events/ev_facturacion.sql;
SOURCE src/07_events/ev_accesos.sql;

-- 7. Roles y usuarios

SOURCE src/08_roles/roles.sql
SOURCE src/08_roles/usuarios_permisos.sql

SELECT 'Instalacion completada' AS resultado;
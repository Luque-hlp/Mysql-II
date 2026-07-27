USE coworking_db;

-- Limpieza previa (por si se re-ejecuta)
DROP ROLE IF EXISTS rol_administrador;
DROP ROLE IF EXISTS rol_recepcionista;
DROP ROLE IF EXISTS rol_usuario;
DROP ROLE IF EXISTS rol_gerente_corporativo;
DROP ROLE IF EXISTS rol_contador;

CREATE ROLE rol_administrador;
CREATE ROLE rol_recepcionista;
CREATE ROLE rol_usuario;
CREATE ROLE rol_gerente_corporativo;
CREATE ROLE rol_contador;


-- ---------------------------------------------------------------------
-- 1. ADMINISTRADOR DEL COWORKING - Acceso total.
--    Todos los privilegios sobre toda la base de datos.
-- ---------------------------------------------------------------------
GRANT ALL PRIVILEGES ON coworking_db.* TO rol_administrador;


-- ---------------------------------------------------------------------
-- 2. RECEPCIONISTA - Registro de usuarios, asignacion de membresias,
--    gestion de reservas.
--    Puede crear y modificar usuarios, membresias y reservas, y usar
--    los procedimientos operativos. NO toca facturacion ni contabilidad.
-- ---------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON coworking_db.usuarios      TO rol_recepcionista;
GRANT SELECT, INSERT, UPDATE ON coworking_db.membresias    TO rol_recepcionista;
GRANT SELECT, INSERT, UPDATE ON coworking_db.reservas      TO rol_recepcionista;
GRANT SELECT, INSERT, UPDATE ON coworking_db.credenciales  TO rol_recepcionista;
GRANT SELECT, INSERT         ON coworking_db.accesos        TO rol_recepcionista;
GRANT SELECT ON coworking_db.empresas         TO rol_recepcionista;
GRANT SELECT ON coworking_db.tipos_membresia  TO rol_recepcionista;
GRANT SELECT ON coworking_db.espacios         TO rol_recepcionista;
GRANT SELECT ON coworking_db.tipos_espacio    TO rol_recepcionista;
GRANT SELECT ON coworking_db.horarios_espacio TO rol_recepcionista;
-- Procedimientos operativos que puede ejecutar
GRANT EXECUTE ON PROCEDURE coworking_db.sp_registrar_membresia         TO rol_recepcionista;
GRANT EXECUTE ON PROCEDURE coworking_db.sp_renovar_membresia           TO rol_recepcionista;
GRANT EXECUTE ON PROCEDURE coworking_db.sp_crear_reserva               TO rol_recepcionista;
GRANT EXECUTE ON PROCEDURE coworking_db.sp_cancelar_reserva            TO rol_recepcionista;
GRANT EXECUTE ON PROCEDURE coworking_db.sp_verificar_disponibilidad    TO rol_recepcionista;
GRANT EXECUTE ON PROCEDURE coworking_db.sp_registrar_entrada           TO rol_recepcionista;
GRANT EXECUTE ON PROCEDURE coworking_db.sp_registrar_salida            TO rol_recepcionista;


-- ---------------------------------------------------------------------
-- 3. USUARIO - Reservar espacios, consultar historial, descargar
--    facturas.
--    Puede crear reservas y leer SUS datos. Solo lectura en facturas
--    (para descargar = consultar). No modifica nada estructural.
-- ---------------------------------------------------------------------
GRANT SELECT, INSERT ON coworking_db.reservas             TO rol_usuario;
GRANT SELECT         ON coworking_db.facturas             TO rol_usuario;
GRANT SELECT         ON coworking_db.detalle_factura      TO rol_usuario;
GRANT SELECT         ON coworking_db.pagos                TO rol_usuario;
GRANT SELECT         ON coworking_db.membresias           TO rol_usuario;
GRANT SELECT         ON coworking_db.accesos              TO rol_usuario;
GRANT SELECT         ON coworking_db.espacios             TO rol_usuario;
GRANT SELECT         ON coworking_db.tipos_espacio        TO rol_usuario;
GRANT SELECT         ON coworking_db.horarios_espacio     TO rol_usuario;
GRANT SELECT         ON coworking_db.servicios            TO rol_usuario;
-- Puede consultar disponibilidad y crear reservas via procedimiento
GRANT EXECUTE ON PROCEDURE coworking_db.sp_verificar_disponibilidad TO rol_usuario;
GRANT EXECUTE ON PROCEDURE coworking_db.sp_crear_reserva            TO rol_usuario;


-- ---------------------------------------------------------------------
-- 4. GERENTE CORPORATIVO - Administrar empleados de su empresa, ver
--    facturacion consolidada.
--    Gestiona usuarios y membresias (sus empleados) y LEE toda la
--    facturacion. Puede generar la factura consolidada.
-- ---------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON coworking_db.usuarios        TO rol_gerente_corporativo;
GRANT SELECT, INSERT, UPDATE ON coworking_db.membresias      TO rol_gerente_corporativo;
GRANT SELECT ON coworking_db.empresas        TO rol_gerente_corporativo;
GRANT SELECT ON coworking_db.facturas        TO rol_gerente_corporativo;
GRANT SELECT ON coworking_db.detalle_factura TO rol_gerente_corporativo;
GRANT SELECT ON coworking_db.pagos           TO rol_gerente_corporativo;
GRANT SELECT ON coworking_db.reservas        TO rol_gerente_corporativo;
GRANT EXECUTE ON PROCEDURE coworking_db.sp_registrar_lote_empleados      TO rol_gerente_corporativo;
GRANT EXECUTE ON PROCEDURE coworking_db.sp_generar_factura_consolidada   TO rol_gerente_corporativo;


-- ---------------------------------------------------------------------
-- 5. CONTADOR - Gestion de ingresos y reportes financieros.
--    Control total sobre facturas y pagos, lectura del resto para
--    armar reportes. No gestiona usuarios ni reservas.
-- ---------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON coworking_db.facturas        TO rol_contador;
GRANT SELECT, INSERT, UPDATE ON coworking_db.detalle_factura TO rol_contador;
GRANT SELECT, INSERT, UPDATE ON coworking_db.pagos           TO rol_contador;
GRANT SELECT, INSERT, UPDATE ON coworking_db.reembolsos      TO rol_contador;
GRANT SELECT, INSERT, UPDATE ON coworking_db.penalizaciones  TO rol_contador;
GRANT SELECT ON coworking_db.usuarios    TO rol_contador;
GRANT SELECT ON coworking_db.empresas    TO rol_contador;
GRANT SELECT ON coworking_db.membresias  TO rol_contador;
GRANT SELECT ON coworking_db.reservas    TO rol_contador;
GRANT SELECT ON coworking_db.metodos_pago TO rol_contador;
GRANT EXECUTE ON PROCEDURE coworking_db.sp_generar_factura_membresia   TO rol_contador;
GRANT EXECUTE ON PROCEDURE coworking_db.sp_aplicar_recargos_vencidas   TO rol_contador;
GRANT EXECUTE ON PROCEDURE coworking_db.sp_reporte_ingresos_mensuales  TO rol_contador;

FLUSH PRIVILEGES;
# Sistema de Gestión de Coworking — `coworking_db`

Base de datos relacional para la administración integral de un espacio de
coworking: usuarios, membresías, reserva de espacios, servicios adicionales,
facturación y control de acceso físico.

Desarrollado en **MySQL 8.0** como proyecto académico para Campuslands.

---

## 1. Descripción del Proyecto

El sistema modela las operaciones reales de un coworking moderno. La base de
datos resuelve cinco áreas de negocio:

- **Usuarios y membresías** — registro de personas y empresas, con cuatro
  tipos de membresía (Diaria, Mensual, Corporativa, Premium) y control de
  vigencia mediante estados Activa / Suspendida / Vencida / Cancelada.
- **Espacios y reservas** — escritorios flexibles, oficinas privadas, salas de
  reuniones y salas de eventos, con capacidad, horario de apertura y
  validación de solapamiento entre reservas.
- **Servicios adicionales** — internet premium, lockers, café, impresiones y
  proyector, facturables de forma independiente o asociados a una reserva.
- **Pagos y facturación** — facturas por membresía, reserva, servicio o
  consolidadas por empresa, con soporte para pagos parciales, recargos por
  mora y anulaciones justificadas.
- **Control de acceso** — entradas y salidas por tarjeta RFID o código QR,
  con validación de membresía activa y registro de intentos rechazados.

Sobre esa estructura se implementaron **100 consultas, 20 funciones,
20 procedimientos almacenados, 20 triggers, 20 eventos y 5 roles** de acceso.

## 2. Requisitos del Sistema

| Componente | Versión mínima | Nota |
|---|---|---|
| MySQL Server | 8.0 | Necesario para `CREATE ROLE` y funciones de ventana (`OVER`) |
| Cliente SQL | DBeaver 23+ / MySQL Workbench 8+ / consola `mysql` | Cualquiera sirve |

El planificador de eventos debe estar activo para que los 20 eventos corran:

```sql
SET GLOBAL event_scheduler = ON;
SHOW VARIABLES LIKE 'event_scheduler';   -- debe decir ON
```

## 3. Instalación y Configuración

### Opción A — consola `mysql` (todo de una vez)

```bash
git clone <URL-DEL-REPOSITORIO>
cd coworking-db
mysql -u root -p < install.sql
```

### Opción B — DBeaver

DBeaver no reconoce el comando `SOURCE`, así que hay que abrir y ejecutar los
archivos uno por uno **en este orden**:

1. `src/01_ddl/ddl.sql` — crea la base de datos y las 23 tablas
2. `src/04_functions/*.sql` — las funciones van primero: los procedimientos y triggers las invocan
3. `src/05_procedures/*.sql`
4. `src/06_triggers/*.sql`
5. `src/07_events/*.sql`
6. `src/08_roles/roles.sql` y `src/08_roles/usuarios_permisos.sql`
7. `src/02_dml/dml.sql` — carga los datos de prueba al final (con triggers ya activos)

En cada archivo usa **`Alt+X`** (ejecutar script completo). Con `Ctrl+Enter`
solo se ejecuta la sentencia bajo el cursor y el script queda a medias.

Las consultas de `src/03_dql/` son de solo lectura y pueden ejecutarse en
cualquier momento después del paso 7.

> **Nota sobre el orden:** las carpetas están numeradas en orden de ejecución.
> Las funciones (04) van antes que procedimientos (05), triggers (06) y events
> (07) porque estos las invocan. El DML se carga al final para que los triggers
> ya estén activos al insertar los datos.

## 4. Estructura de la Base de Datos

![Modelo entidad-relación](docs/modelo_er.png)

La base tiene 23 tablas organizadas en seis módulos. Motor **InnoDB** en todas,
para garantizar integridad referencial (claves foráneas) y transacciones.

### Módulo 1 — Empresas, usuarios y membresías

| Tabla | Propósito |
|---|---|
| `empresas` | Empresas cliente. Los usuarios individuales tienen `id_empresa` en NULL |
| `tipos_membresia` | Catálogo con precio y duración en días de cada plan |
| `usuarios` | Personas registradas; opcionalmente vinculadas a una empresa |
| `membresias` | Historial de contrataciones. Cada renovación es una fila nueva, no un UPDATE |

### Módulo 2 — Espacios y reservas

| Tabla | Propósito |
|---|---|
| `tipos_espacio` | Catálogo de tipos con tarifa por hora |
| `espacios` | Espacios físicos con capacidad y estado operativo |
| `horarios_espacio` | Franja de apertura por espacio y día de la semana |
| `reservas` | Reservas con rango de fechas, número de asistentes y estado |

### Módulo 3 — Servicios adicionales

| Tabla | Propósito |
|---|---|
| `servicios` | Catálogo de servicios facturables |
| `servicios_contratados` | Servicio consumido por un usuario, opcionalmente ligado a una reserva |

### Módulo 4 — Pagos y facturación

| Tabla | Propósito |
|---|---|
| `metodos_pago` | Efectivo, Tarjeta, Transferencia, PayPal |
| `facturas` | Encabezado de factura con total, saldo pendiente y estado |
| `detalle_factura` | Líneas de la factura; permite la factura consolidada por empresa |
| `pagos` | Pagos aplicados a una factura. Varios pagos por factura habilitan el pago parcial |
| `reembolsos` | Devoluciones generadas al cancelar reservas |
| `penalizaciones` | Cargos por reservas confirmadas sin asistencia (No Show) |

### Módulo 5 — Control de acceso

| Tabla | Propósito |
|---|---|
| `credenciales` | Tarjeta RFID o código QR asignado a un usuario |
| `accesos` | Entradas y salidas. `fecha_hora_salida` en NULL = la persona sigue adentro |

### Módulo 6 — Auditoría y notificaciones

| Tabla | Propósito |
|---|---|
| `log_membresias` | Cambios de tipo de membresía |
| `log_reservas_canceladas` | Cancelaciones de reserva con su motivo |
| `log_pagos_anulados` | Pagos anulados |
| `log_accesos_rechazados` | Intentos de acceso denegados |
| `notificaciones` | Mensajes generados por los eventos (recordatorios y reportes) |

### Relaciones clave

- `usuarios` → `empresas` es opcional (`ON DELETE SET NULL`): borrar una
  empresa no elimina a sus empleados, solo los desvincula.
- `membresias`, `reservas` y `facturas` usan `ON DELETE RESTRICT` sobre
  `usuarios`: no se puede borrar a alguien con historial financiero.
- `accesos` referencia a `usuarios` de forma anulable, porque un intento con
  un QR inexistente debe quedar registrado aunque no corresponda a nadie.

## 5. Ejemplos de Consultas

Las 100 consultas están en `src/03_dql/`, divididas en cinco archivos de 20.

**Consulta básica — usuarios con membresía activa (consulta 2)**

```sql
SELECT DISTINCT u.id_usuario, u.nombre, u.apellidos, m.fecha_fin
FROM usuarios u
INNER JOIN membresias m ON m.id_usuario = u.id_usuario
WHERE m.estado = 'Activa'
  AND CURDATE() BETWEEN m.fecha_inicio AND m.fecha_fin
ORDER BY u.apellidos;
```

Devuelve las personas con una membresía vigente a la fecha de hoy.

**Consulta avanzada — ingresos acumulados con función de ventana (consulta 99)**

```sql
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
```

Muestra el ingreso de cada mes y el acumulado corriente del año usando la
función de ventana `SUM() OVER (ORDER BY ...)`.

**Distribución de las 100 consultas**

| Archivo | Consultas | Contenido |
|---|---|---|
| `01_usuarios_membresias.sql` | 1–20 | Usuarios y membresías |
| `02_espacios_reservas.sql` | 21–40 | Espacios y reservas |
| `03_pagos_facturacion.sql` | 41–60 | Pagos y facturación |
| `04_accesos_asistencias.sql` | 61–80 | Accesos y asistencias |
| `05_consultas_avanzadas.sql` | 81–100 | Subconsultas, joins y funciones de ventana |

## 6. Procedimientos, Funciones, Triggers y Eventos

### Funciones (20)

Una función recibe datos, calcula y devuelve **un solo valor**; se puede usar
dentro de un `SELECT` o un `WHERE`. Se implementaron primero porque los
procedimientos, triggers y eventos las reutilizan.

| Función | Retorna | Descripción |
|---|---|---|
| `fn_membresia_activa` | BOOLEAN | Si el usuario tiene una membresía vigente hoy |
| `fn_dias_restantes_membresia` | INT | Días que le quedan a la membresía vigente |
| `fn_calcular_fecha_fin` | DATE | Fecha de vencimiento según el tipo de membresía |
| `fn_total_renovaciones` | INT | Cuántas veces renovó el usuario |
| `fn_precio_con_descuento` | DECIMAL | Precio final con descuentos corporativo y de fidelidad |
| `fn_espacio_disponible` | BOOLEAN | Si un espacio está libre en un rango de tiempo |
| `fn_calcular_costo_reserva` | DECIMAL | Costo de una reserva (tarifa × horas) |
| `fn_horas_reserva` | DECIMAL | Horas entre dos momentos (única DETERMINISTIC) |
| `fn_total_reservas_usuario` | INT | Reservas del usuario, con filtro opcional por estado |
| `fn_dentro_horario` | BOOLEAN | Si un momento cae dentro del horario del espacio |
| `fn_saldo_pendiente_usuario` | DECIMAL | Total que debe el usuario |
| `fn_calcular_recargo_mora` | DECIMAL | Recargo por mora de una factura |
| `fn_total_pagado_factura` | DECIMAL | Suma de pagos efectivos de una factura |
| `fn_usuario_en_mora` | BOOLEAN | Si el usuario tiene facturas vencidas impagas |
| `fn_generar_numero_factura` | VARCHAR | Consecutivo con formato FAC-2026-0001 |
| `fn_ultimo_acceso` | DATETIME | Fecha de la última entrada permitida |
| `fn_usuario_dentro` | BOOLEAN | Si el usuario sigue dentro del coworking |
| `fn_horas_permanencia` | DECIMAL | Duración de una visita concreta |
| `fn_credencial_valida` | INT | Id del dueño de una credencial, o 0 si no sirve |
| `fn_total_accesos_mes` | INT | Entradas permitidas en un mes dado |

Ejemplo de uso:

```sql
SELECT nombre, fn_dias_restantes_membresia(id_usuario) AS dias
FROM usuarios WHERE fn_membresia_activa(id_usuario) = TRUE;
```

### Procedimientos almacenados (20)

Un procedimiento **hace un trabajo** (inserta, actualiza, valida) y puede
devolver resultados por parámetros `OUT`. Usan transacciones y `HANDLER` de
errores donde corresponde.

| Grupo | Procedimientos |
|---|---|
| Membresías | `sp_registrar_membresia`, `sp_renovar_membresia`, `sp_actualizar_membresias_vencidas`, `sp_suspender_membresias_morosas` |
| Reservas | `sp_verificar_disponibilidad`, `sp_crear_reserva`, `sp_confirmar_reserva_con_pago`, `sp_cancelar_reserva`, `sp_liberar_reservas_no_confirmadas` |
| Facturación | `sp_generar_factura_membresia`, `sp_generar_factura_consolidada`, `sp_aplicar_recargos_vencidas`, `sp_bloquear_servicios_morosos` |
| Accesos | `sp_registrar_entrada`, `sp_registrar_salida`, `sp_reporte_diario_asistencias`, `sp_marcar_no_show` |
| Corporativos | `sp_registrar_lote_empleados`, `sp_cancelar_reservas_por_baja`, `sp_reporte_ingresos_mensuales` |

Ejemplo de uso:

```sql
CALL sp_registrar_membresia(15, 2, CURDATE(), @id_nueva);
SELECT @id_nueva;
```

### Triggers (20)

Un trigger se dispara automáticamente ante un `INSERT`, `UPDATE` o `DELETE`.
Se distribuyen 5 por módulo: membresías, reservas, pagos y accesos. Mantienen
la coherencia del sistema sin intervención (por ejemplo, el saldo de una
factura se recalcula solo cada vez que entra un pago).

| Módulo | Función de los triggers |
|---|---|
| Membresías | Calcular fecha de fin, activar/suspender por pago, log de cambio de tipo, bloquear borrado con reservas activas |
| Reservas | Validar solapamiento, estado inicial, confirmar por pago, cancelar por baja de membresía, log de cancelación |
| Pagos | Asegurar detalle de factura, marcar Pagada, bloquear borrado de pago, **actualizar saldo con pagos parciales**, log de anulados |
| Accesos | Estampar entrada, bloquear sin membresía, actualizar última fecha, registrar salida, log de rechazados |

> **Nota técnica:** el requisito "registrar salida automática al reentrar" se
> resolvió en el procedimiento `sp_registrar_entrada`, no en un trigger, porque
> MySQL prohíbe que un trigger modifique la misma tabla que lo dispara
> (error 1442). Esta es una limitación real del motor, no una omisión.

### Eventos (20)

Un evento es una tarea programada que MySQL ejecuta sola cada cierto tiempo
(el "cron" de la base). Requieren `event_scheduler = ON`. Como MySQL no envía
correos, los recordatorios y reportes se registran en la tabla `notificaciones`.

| Módulo | Ejemplos de eventos |
|---|---|
| Membresías | Marcar vencidas (diario), recordatorio de renovación, suspender inactivas |
| Reservas | Cancelar no confirmadas (cada hora), recordatorio de reserva, reporte de ocupación |
| Facturación | Recordatorio de pago, bloquear servicios por mora, aplicar recargos |
| Accesos | Reporte diario de asistencias, alerta fuera de horario, top 10 usuarios del mes |

Varios eventos solo invocan un procedimiento existente, por ejemplo:

```sql
CREATE EVENT ev_membresias_vencidas
ON SCHEDULE EVERY 1 DAY
DO CALL sp_actualizar_membresias_vencidas(@n);
```

## 7. Roles de Usuario y Permisos

Se crearon 5 roles siguiendo el **principio de mínimo privilegio**: cada rol
recibe solo los permisos que su función necesita.

| Rol | Alcance |
|---|---|
| `rol_administrador` | Acceso total a todos los objetos de la base de datos |
| `rol_recepcionista` | Registro de usuarios, asignación de membresías y gestión de reservas |
| `rol_usuario` | Crear reservas, consultar su historial y sus facturas |
| `rol_gerente_corporativo` | Administrar los empleados de su empresa y ver facturación consolidada |
| `rol_contador` | Gestión de pagos, facturas y reportes financieros |

### Crear un usuario y asignarle un rol

```sql
-- 1. Crear la cuenta
CREATE USER 'nombre_usuario'@'localhost' IDENTIFIED BY 'contraseña_segura';

-- 2. Asignar el rol
GRANT rol_recepcionista TO 'nombre_usuario'@'localhost';

-- 3. Activar el rol de forma permanente (¡paso obligatorio!)
SET DEFAULT ROLE rol_recepcionista TO 'nombre_usuario'@'localhost';
```

> **Importante:** sin `SET DEFAULT ROLE`, el usuario tiene el rol asignado pero
> desactivado, y parecerá que no tiene permisos hasta ejecutar `SET ROLE` en
> cada sesión. Es el error más común al trabajar con roles.
>
> **Compatibilidad:** en MariaDB la sintaxis del tercer paso cambia a
> `SET DEFAULT ROLE rol_recepcionista FOR 'nombre_usuario'@'localhost'`
> (`FOR` en vez de `TO`). Este proyecto está escrito para MySQL 8.

El detalle completo de permisos por rol está en `src/08_roles/roles.sql`, y
cinco usuarios de ejemplo (uno por rol) en `src/08_roles/usuarios_permisos.sql`.

## 8. Contribuciones

Proyecto desarrollado individualmente por **Angel Andrey Luque Parada**,
estudiante de desarrollo de software en Campuslands.

## 9. Licencia y Contacto

Proyecto académico desarrollado para Campuslands. Uso educativo.

- **Autor:** Angel Andrey Luque Parada
- **GitHub:** _(agregar tu usuario)_
- **Correo:** _(agregar tu correo)_
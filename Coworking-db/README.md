# Sistema de Gestión de Coworking — `coworking_db`

Base de datos relacional para la administración integral de un espacio de
coworking: usuarios, membresías, reserva de espacios, servicios adicionales,
facturación y control de acceso físico.

---

## 1. Descripción del Proyecto

<!-- OJO: el enunciado dice "Tienda de disfraces" en esta sección. Es un
     error de copiado del documento (viene de un proyecto anterior). Aquí
     va la descripción del coworking. -->

El sistema modela las operaciones reales de un coworking moderno. La base de
datos resuelve cinco áreas de negocio:

- **Usuarios y membresías** — registro de personas y empresas, con cuatro
  tipos de membresía (Diaria, Mensual, Corporativa, Premium) y control de
  vigencia mediante estados Activa / Suspendida / Vencida.
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

Sobre esa estructura se implementaron 100 consultas, 20 funciones,
20 procedimientos almacenados, 20 triggers, 20 eventos y 5 roles de acceso.

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
2. `src/02_dml/dml.sql` — carga los datos de prueba
3. `src/04_functions/*.sql` — las funciones van primero: los procedimientos y triggers las invocan
4. `src/05_procedures/*.sql`
5. `src/06_triggers/*.sql`
6. `src/07_events/*.sql`
7. `src/08_roles/*.sql`

En cada archivo usa **`Alt+X`** (ejecutar script completo). Con `Ctrl+Enter`
solo se ejecuta la sentencia bajo el cursor y el script queda a medias.

Las consultas de `src/03_dql/` son de solo lectura y pueden ejecutarse en
cualquier momento después del paso 2.

## 4. Estructura de la Base de Datos

<!-- TODO: pegar aquí el diagrama entidad-relación exportado desde DBeaver
     (clic derecho sobre la base de datos > View Diagram > exportar como PNG)
     y guardarlo en docs/modelo_er.png -->

![Modelo entidad-relación](docs/modelo_er.png)

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
| `accesos` | Entradas y salidas. `fecha_hora_salida` en NULL = sigue adentro |

### Módulo 6 — Auditoría y notificaciones

| Tabla | Propósito |
|---|---|
| `log_membresias` | Cambios de tipo o estado de membresía |
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

<!-- TODO: reemplazar por 3 o 4 consultas reales tuyas, con su resultado -->

**Consulta básica — usuarios con membresía activa**

```sql
-- (pegar aquí)
```

Devuelve …

**Consulta avanzada — empresas que generan más del 20% de los ingresos**

```sql
-- (pegar aquí)
```

Devuelve …

El listado completo está en `src/03_dql/`, dividido en cinco archivos de
20 consultas cada uno.

## 6. Procedimientos, Funciones, Triggers y Eventos

### Funciones (20)

<!-- TODO: tabla con nombre, parámetros, qué retorna -->

| Función | Retorna | Descripción |
|---|---|---|
| | | |

### Procedimientos almacenados (20)

<!-- TODO -->

| Procedimiento | Parámetros | Descripción |
|---|---|---|
| | | |

Ejemplo de uso:

```sql
CALL sp_registrar_membresia(15, 2, CURDATE());
```

### Triggers (20)

<!-- TODO -->

| Trigger | Tabla | Momento | Descripción |
|---|---|---|---|
| | | | |

### Eventos (20)

<!-- TODO -->

| Evento | Frecuencia | Descripción |
|---|---|---|
| | | |

## 7. Roles de Usuario y Permisos

| Rol | Alcance |
|---|---|
| `rol_administrador` | Acceso total a todos los objetos de la base de datos |
| `rol_recepcionista` | Registro de usuarios, asignación de membresías y gestión de reservas |
| `rol_usuario` | Consulta de su historial, creación de reservas y descarga de facturas |
| `rol_gerente_corporativo` | Administración de los empleados de su empresa y facturación consolidada |
| `rol_contador` | Lectura de pagos, facturas y reportes financieros |

### Crear un usuario y asignarle un rol

```sql
CREATE USER 'nombre_usuario'@'localhost' IDENTIFIED BY 'contraseña_segura';
GRANT rol_recepcionista TO 'nombre_usuario'@'localhost';

-- Activar el rol de forma permanente para ese usuario:
SET DEFAULT ROLE rol_recepcionista TO 'nombre_usuario'@'localhost';
```

Sin `SET DEFAULT ROLE`, el usuario debe ejecutar `SET ROLE` en cada sesión y
parecerá que no tiene permisos. El detalle completo está en
`src/08_roles/`.

## 8. Contribuciones

Proyecto desarrollado individualmente por **Angel Andrey Luque Parada**.

<!-- Si fuera grupal: una fila por integrante indicando qué módulo hizo -->

## 9. Licencia y Contacto

Proyecto académico desarrollado para Campuslands. Uso educativo.

- **Autor:** Angel Andrey Luque Parada
- **Correo:** <!-- TODO -->
- **GitHub:** <!-- TODO -->
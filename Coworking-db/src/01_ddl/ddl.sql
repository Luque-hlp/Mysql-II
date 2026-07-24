-- =====================================================================
-- PROYECTO: COWORKING_DB
-- Archivo : ddl.sql  -- Estructura de la base de datos
-- Autor   : Angel Andrey Luque Parada
-- Motor   : MySQL 8.0+  (requiere CREATE ROLE y funciones de ventana)
-- =====================================================================

DROP DATABASE IF EXISTS coworking_db;
CREATE DATABASE coworking_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE coworking_db;


-- =====================================================================
-- MODULO 1: EMPRESAS, USUARIOS Y MEMBRESIAS
-- =====================================================================

-- Empresas cliente. Un usuario puede o no pertenecer a una empresa
-- (los usuarios individuales tienen id_empresa NULL).
CREATE TABLE empresas (
    id_empresa      INT AUTO_INCREMENT PRIMARY KEY,
    nit             VARCHAR(20)  NOT NULL UNIQUE,
    nombre          VARCHAR(120) NOT NULL,
    sector          VARCHAR(80),
    telefono        VARCHAR(20),
    email           VARCHAR(120),
    direccion       VARCHAR(180),
    fecha_registro  DATE NOT NULL DEFAULT (CURRENT_DATE),
    activa          BOOLEAN NOT NULL DEFAULT TRUE,
    INDEX idx_empresa_nombre (nombre)
) ENGINE=InnoDB;


-- Catalogo de tipos de membresia. La duracion en dias permite que el
-- procedimiento de renovacion calcule la fecha de fin sin condicionales.
CREATE TABLE tipos_membresia (
    id_tipo_membresia INT AUTO_INCREMENT PRIMARY KEY,
    nombre            ENUM('Diaria','Mensual','Corporativa','Premium') NOT NULL UNIQUE,
    precio            DECIMAL(10,2) NOT NULL,
    duracion_dias     INT NOT NULL,
    descripcion       VARCHAR(200),
    CONSTRAINT chk_precio_membresia  CHECK (precio >= 0),
    CONSTRAINT chk_duracion_positiva CHECK (duracion_dias > 0)
) ENGINE=InnoDB;


CREATE TABLE usuarios (
    id_usuario          INT AUTO_INCREMENT PRIMARY KEY,
    identificacion      VARCHAR(20)  NOT NULL UNIQUE,
    nombre              VARCHAR(60)  NOT NULL,
    apellidos           VARCHAR(80)  NOT NULL,
    fecha_nacimiento    DATE         NOT NULL,
    telefono            VARCHAR(20),
    email               VARCHAR(120) NOT NULL UNIQUE,
    id_empresa          INT NULL,
    fecha_registro      DATE     NOT NULL DEFAULT (CURRENT_DATE),
    ultima_fecha_acceso DATETIME NULL,
    estado              ENUM('Activo','Inactivo') NOT NULL DEFAULT 'Activo',
    CONSTRAINT fk_usuario_empresa FOREIGN KEY (id_empresa)
        REFERENCES empresas(id_empresa)
        ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_usuario_empresa (id_empresa),
    INDEX idx_usuario_registro (fecha_registro)
) ENGINE=InnoDB;


-- Un usuario tiene VARIAS filas aqui a lo largo del tiempo: una por cada
-- membresia contratada o renovada. Eso es lo que permite responder
-- "usuarios que renovaron mas de 10 veces" con un simple COUNT.
CREATE TABLE membresias (
    id_membresia      INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario        INT NOT NULL,
    id_tipo_membresia INT NOT NULL,
    fecha_inicio      DATE NOT NULL,
    fecha_fin         DATE NOT NULL,
    estado            ENUM('Activa','Suspendida','Vencida','Cancelada')
                      NOT NULL DEFAULT 'Activa',
    fecha_registro    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_membresia_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuarios(id_usuario)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_membresia_tipo FOREIGN KEY (id_tipo_membresia)
        REFERENCES tipos_membresia(id_tipo_membresia)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_fechas_membresia CHECK (fecha_fin >= fecha_inicio),
    INDEX idx_membresia_usuario (id_usuario),
    INDEX idx_membresia_estado (estado),
    INDEX idx_membresia_fin (fecha_fin)
) ENGINE=InnoDB;


-- =====================================================================
-- MODULO 2: ESPACIOS Y RESERVAS
-- =====================================================================

CREATE TABLE tipos_espacio (
    id_tipo_espacio INT AUTO_INCREMENT PRIMARY KEY,
    nombre          ENUM('Escritorio flexible','Oficina privada',
                         'Sala de reuniones','Sala de eventos') NOT NULL UNIQUE,
    descripcion     VARCHAR(200),
    precio_hora     DECIMAL(10,2) NOT NULL,
    CONSTRAINT chk_precio_hora CHECK (precio_hora >= 0)
) ENGINE=InnoDB;


CREATE TABLE espacios (
    id_espacio       INT AUTO_INCREMENT PRIMARY KEY,
    codigo           VARCHAR(15) NOT NULL UNIQUE,
    nombre           VARCHAR(80) NOT NULL,
    id_tipo_espacio  INT NOT NULL,
    capacidad_maxima INT NOT NULL,
    piso             TINYINT,
    estado           ENUM('Disponible','Mantenimiento','Inactivo')
                     NOT NULL DEFAULT 'Disponible',
    CONSTRAINT fk_espacio_tipo FOREIGN KEY (id_tipo_espacio)
        REFERENCES tipos_espacio(id_tipo_espacio)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_capacidad CHECK (capacidad_maxima > 0),
    INDEX idx_espacio_tipo (id_tipo_espacio)
) ENGINE=InnoDB;


-- Horario de apertura por espacio y por dia de la semana.
-- dia_semana usa la convencion de MySQL DAYOFWEEK(): 1=Domingo ... 7=Sabado.
-- Sin esta tabla no se puede resolver "accesos fuera del horario permitido".
CREATE TABLE horarios_espacio (
    id_horario    INT AUTO_INCREMENT PRIMARY KEY,
    id_espacio    INT NOT NULL,
    dia_semana    TINYINT NOT NULL,
    hora_apertura TIME NOT NULL,
    hora_cierre   TIME NOT NULL,
    CONSTRAINT fk_horario_espacio FOREIGN KEY (id_espacio)
        REFERENCES espacios(id_espacio)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_dia_semana CHECK (dia_semana BETWEEN 1 AND 7),
    CONSTRAINT chk_horas CHECK (hora_cierre > hora_apertura),
    UNIQUE KEY uk_espacio_dia (id_espacio, dia_semana)
) ENGINE=InnoDB;


-- num_asistentes existe para poder detectar reservas que exceden la
-- capacidad del espacio (consulta 28 y trigger de validacion).
CREATE TABLE reservas (
    id_reserva          INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario          INT NOT NULL,
    id_espacio          INT NOT NULL,
    fecha_hora_inicio   DATETIME NOT NULL,
    fecha_hora_fin      DATETIME NOT NULL,
    num_asistentes      INT NOT NULL DEFAULT 1,
    estado              ENUM('Pendiente','Confirmada','Cancelada',
                             'Completada','No Show') NOT NULL DEFAULT 'Pendiente',
    monto_total         DECIMAL(10,2) NOT NULL DEFAULT 0,
    fecha_creacion      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    motivo_cancelacion  VARCHAR(200) NULL,
    CONSTRAINT fk_reserva_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuarios(id_usuario)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_reserva_espacio FOREIGN KEY (id_espacio)
        REFERENCES espacios(id_espacio)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_fechas_reserva CHECK (fecha_hora_fin > fecha_hora_inicio),
    CONSTRAINT chk_asistentes CHECK (num_asistentes > 0),
    INDEX idx_reserva_usuario (id_usuario),
    INDEX idx_reserva_espacio (id_espacio),
    INDEX idx_reserva_estado (estado),
    INDEX idx_reserva_inicio (fecha_hora_inicio)
) ENGINE=InnoDB;


-- =====================================================================
-- MODULO 3: SERVICIOS ADICIONALES
-- =====================================================================

CREATE TABLE servicios (
    id_servicio    INT AUTO_INCREMENT PRIMARY KEY,
    nombre         VARCHAR(80) NOT NULL UNIQUE,
    descripcion    VARCHAR(200),
    precio         DECIMAL(10,2) NOT NULL,
    unidad_medida  VARCHAR(30) NOT NULL DEFAULT 'Unidad',
    activo         BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_precio_servicio CHECK (precio >= 0)
) ENGINE=InnoDB;


-- Enlaza servicio -> usuario (siempre) y servicio -> reserva (opcional).
-- El estado 'Bloqueado' es lo que usa el procedimiento de bloqueo por mora.
CREATE TABLE servicios_contratados (
    id_servicio_contratado INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario             INT NOT NULL,
    id_servicio            INT NOT NULL,
    id_reserva             INT NULL,
    cantidad               INT NOT NULL DEFAULT 1,
    precio_unitario        DECIMAL(10,2) NOT NULL,
    subtotal               DECIMAL(10,2) NOT NULL,
    fecha_contratacion     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado                 ENUM('Activo','Bloqueado','Finalizado')
                           NOT NULL DEFAULT 'Activo',
    CONSTRAINT fk_sc_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuarios(id_usuario)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_sc_servicio FOREIGN KEY (id_servicio)
        REFERENCES servicios(id_servicio)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_sc_reserva FOREIGN KEY (id_reserva)
        REFERENCES reservas(id_reserva)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT chk_cantidad CHECK (cantidad > 0),
    INDEX idx_sc_usuario (id_usuario),
    INDEX idx_sc_reserva (id_reserva)
) ENGINE=InnoDB;


-- =====================================================================
-- MODULO 4: PAGOS Y FACTURACION
-- =====================================================================

CREATE TABLE metodos_pago (
    id_metodo_pago INT AUTO_INCREMENT PRIMARY KEY,
    nombre         ENUM('Efectivo','Tarjeta','Transferencia','PayPal')
                   NOT NULL UNIQUE,
    activo         BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;


-- Encabezado de factura.
--   * id_empresa se llena SOLO en facturas consolidadas corporativas.
--   * id_membresia / id_reserva son atajos para las consultas 44 y 45.
--   * saldo_pendiente lo mantiene un trigger cada vez que entra un pago.
CREATE TABLE facturas (
    id_factura       INT AUTO_INCREMENT PRIMARY KEY,
    numero_factura   VARCHAR(20) NOT NULL UNIQUE,
    id_usuario       INT NOT NULL,
    id_empresa       INT NULL,
    id_membresia     INT NULL,
    id_reserva       INT NULL,
    tipo_origen      ENUM('Membresia','Reserva','Servicio',
                          'Consolidada','Penalizacion') NOT NULL,
    subtotal         DECIMAL(10,2) NOT NULL DEFAULT 0,
    recargo          DECIMAL(10,2) NOT NULL DEFAULT 0,
    total            DECIMAL(10,2) NOT NULL DEFAULT 0,
    saldo_pendiente  DECIMAL(10,2) NOT NULL DEFAULT 0,
    estado           ENUM('Pendiente','Parcial','Pagada','Anulada','Vencida')
                     NOT NULL DEFAULT 'Pendiente',
    fecha_emision    DATE NOT NULL DEFAULT (CURRENT_DATE),
    fecha_vencimiento DATE NOT NULL,
    motivo_anulacion VARCHAR(200) NULL,
    CONSTRAINT fk_factura_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuarios(id_usuario)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_factura_empresa FOREIGN KEY (id_empresa)
        REFERENCES empresas(id_empresa)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_factura_membresia FOREIGN KEY (id_membresia)
        REFERENCES membresias(id_membresia)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_factura_reserva FOREIGN KEY (id_reserva)
        REFERENCES reservas(id_reserva)
        ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_factura_usuario (id_usuario),
    INDEX idx_factura_estado (estado),
    INDEX idx_factura_vencimiento (fecha_vencimiento)
) ENGINE=InnoDB;


-- Lineas de factura. Sin esta tabla no se puede armar la factura
-- consolidada que agrupa cargos de varios empleados de una empresa.
CREATE TABLE detalle_factura (
    id_detalle      INT AUTO_INCREMENT PRIMARY KEY,
    id_factura      INT NOT NULL,
    concepto        VARCHAR(150) NOT NULL,
    tipo_concepto   ENUM('Membresia','Reserva','Servicio',
                         'Recargo','Penalizacion') NOT NULL,
    id_referencia   INT NULL,
    cantidad        INT NOT NULL DEFAULT 1,
    precio_unitario DECIMAL(10,2) NOT NULL,
    subtotal        DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_detalle_factura FOREIGN KEY (id_factura)
        REFERENCES facturas(id_factura)
        ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_detalle_factura (id_factura)
) ENGINE=InnoDB;


-- Varios pagos pueden apuntar a una misma factura: eso es lo que hace
-- posible el escenario de pago parcial y saldo pendiente.
CREATE TABLE pagos (
    id_pago                INT AUTO_INCREMENT PRIMARY KEY,
    id_factura             INT NOT NULL,
    id_metodo_pago         INT NOT NULL,
    monto                  DECIMAL(10,2) NOT NULL,
    fecha_pago             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado                 ENUM('Pagado','Pendiente','Cancelado')
                           NOT NULL DEFAULT 'Pagado',
    referencia_transaccion VARCHAR(60),
    CONSTRAINT fk_pago_factura FOREIGN KEY (id_factura)
        REFERENCES facturas(id_factura)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_pago_metodo FOREIGN KEY (id_metodo_pago)
        REFERENCES metodos_pago(id_metodo_pago)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_monto_pago CHECK (monto > 0),
    INDEX idx_pago_factura (id_factura),
    INDEX idx_pago_fecha (fecha_pago),
    INDEX idx_pago_estado (estado)
) ENGINE=InnoDB;


CREATE TABLE reembolsos (
    id_reembolso INT AUTO_INCREMENT PRIMARY KEY,
    id_reserva   INT NOT NULL,
    id_pago      INT NULL,
    monto        DECIMAL(10,2) NOT NULL,
    porcentaje   DECIMAL(5,2)  NOT NULL,
    motivo       VARCHAR(200),
    fecha        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_reembolso_reserva FOREIGN KEY (id_reserva)
        REFERENCES reservas(id_reserva)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_reembolso_pago FOREIGN KEY (id_pago)
        REFERENCES pagos(id_pago)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;


CREATE TABLE penalizaciones (
    id_penalizacion INT AUTO_INCREMENT PRIMARY KEY,
    id_reserva      INT NOT NULL,
    id_usuario      INT NOT NULL,
    id_factura      INT NULL,
    monto           DECIMAL(10,2) NOT NULL,
    motivo          VARCHAR(200) NOT NULL,
    fecha           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_penal_reserva FOREIGN KEY (id_reserva)
        REFERENCES reservas(id_reserva)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_penal_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuarios(id_usuario)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_penal_factura FOREIGN KEY (id_factura)
        REFERENCES facturas(id_factura)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;


-- =====================================================================
-- MODULO 5: CONTROL DE ACCESO Y ASISTENCIAS
-- =====================================================================

-- Tarjeta RFID o codigo QR asignado a un usuario. Se separa de la tabla
-- usuarios porque una persona puede perder la tarjeta y recibir otra.
CREATE TABLE credenciales (
    id_credencial INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario    INT NOT NULL,
    tipo          ENUM('RFID','QR') NOT NULL,
    codigo        VARCHAR(60) NOT NULL UNIQUE,
    activa        BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_emision DATE NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT fk_credencial_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuarios(id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_credencial_usuario (id_usuario)
) ENGINE=InnoDB;


-- id_usuario es NULL cuando el intento vino de un QR que no existe.
-- fecha_hora_salida NULL = la persona sigue adentro (o no marco salida).
CREATE TABLE accesos (
    id_acceso          INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario         INT NULL,
    id_credencial      INT NULL,
    id_membresia       INT NULL,
    id_reserva         INT NULL,
    tipo_credencial    ENUM('RFID','QR') NOT NULL,
    codigo_presentado  VARCHAR(60),
    fecha_hora_entrada DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_hora_salida  DATETIME NULL,
    resultado          ENUM('Permitido','Rechazado') NOT NULL DEFAULT 'Permitido',
    motivo_rechazo     VARCHAR(150) NULL,
    CONSTRAINT fk_acceso_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuarios(id_usuario)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_acceso_credencial FOREIGN KEY (id_credencial)
        REFERENCES credenciales(id_credencial)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_acceso_membresia FOREIGN KEY (id_membresia)
        REFERENCES membresias(id_membresia)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_acceso_reserva FOREIGN KEY (id_reserva)
        REFERENCES reservas(id_reserva)
        ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_acceso_usuario (id_usuario),
    INDEX idx_acceso_entrada (fecha_hora_entrada),
    INDEX idx_acceso_resultado (resultado)
) ENGINE=InnoDB;


-- =====================================================================
-- MODULO 6: TABLAS DE AUDITORIA (LOGS)
-- Estas tablas NO aparecen en el enunciado de modelado, pero los
-- triggers 4, 10, 15 y 20 las exigen. Sin ellas hay que rehacer el DDL.
-- =====================================================================

CREATE TABLE log_membresias (
    id_log          INT AUTO_INCREMENT PRIMARY KEY,
    id_membresia    INT NOT NULL,
    id_usuario      INT NOT NULL,
    campo_afectado  VARCHAR(40)  NOT NULL,
    valor_anterior  VARCHAR(100),
    valor_nuevo     VARCHAR(100),
    usuario_sistema VARCHAR(100) NULL,
    fecha_registro  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_log_memb (id_membresia)
) ENGINE=InnoDB;


CREATE TABLE log_reservas_canceladas (
    id_log          INT AUTO_INCREMENT PRIMARY KEY,
    id_reserva      INT NOT NULL,
    id_usuario      INT NOT NULL,
    id_espacio      INT NOT NULL,
    estado_anterior VARCHAR(30),
    motivo          VARCHAR(200),
    usuario_sistema VARCHAR(100) NULL,
    fecha_registro  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_log_res (id_reserva)
) ENGINE=InnoDB;


CREATE TABLE log_pagos_anulados (
    id_log          INT AUTO_INCREMENT PRIMARY KEY,
    id_pago         INT NOT NULL,
    id_factura      INT NOT NULL,
    monto           DECIMAL(10,2) NOT NULL,
    estado_anterior VARCHAR(30),
    motivo          VARCHAR(200),
    usuario_sistema VARCHAR(100) NULL,
    fecha_registro  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_log_pago (id_pago)
) ENGINE=InnoDB;


CREATE TABLE log_accesos_rechazados (
    id_log            INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario        INT NULL,
    codigo_presentado VARCHAR(60),
    tipo_credencial   VARCHAR(10),
    motivo            VARCHAR(150) NOT NULL,
    fecha_registro    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_log_acc (fecha_registro)
) ENGINE=InnoDB;


-- Tabla de notificaciones: la usan los events que "envian recordatorios".
-- MySQL no manda correos, asi que el equivalente honesto es dejar el
-- mensaje registrado aqui.
CREATE TABLE notificaciones (
    id_notificacion INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario      INT NULL,
    destinatario    ENUM('Usuario','Administrador','Recepcion',
                         'Contador') NOT NULL,
    asunto          VARCHAR(120) NOT NULL,
    mensaje         TEXT NOT NULL,
    leida           BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_creacion  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_notif_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuarios(id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_notif_fecha (fecha_creacion)
) ENGINE=InnoDB;

-- =====================================================================
-- FIN DEL DDL
-- =====================================================================
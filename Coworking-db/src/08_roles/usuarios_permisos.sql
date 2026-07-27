-- Administrador
CREATE USER IF NOT EXISTS 'admin_coworking'@'localhost'
    IDENTIFIED BY 'Admin#2026';
GRANT rol_administrador TO 'admin_coworking'@'localhost';
SET DEFAULT ROLE rol_administrador TO 'admin_coworking'@'localhost';

-- Recepcionista
CREATE USER IF NOT EXISTS 'recepcion01'@'localhost'
    IDENTIFIED BY 'Recepcion#2026';
GRANT rol_recepcionista TO 'recepcion01'@'localhost';
SET DEFAULT ROLE rol_recepcionista TO 'recepcion01'@'localhost';

-- Usuario final
CREATE USER IF NOT EXISTS 'cliente01'@'localhost'
    IDENTIFIED BY 'Cliente#2026';
GRANT rol_usuario TO 'cliente01'@'localhost';
SET DEFAULT ROLE rol_usuario TO 'cliente01'@'localhost';

-- Gerente corporativo
CREATE USER IF NOT EXISTS 'gerente_innovatek'@'localhost'
    IDENTIFIED BY 'Gerente#2026';
GRANT rol_gerente_corporativo TO 'gerente_innovatek'@'localhost';
SET DEFAULT ROLE rol_gerente_corporativo TO 'gerente_innovatek'@'localhost';

-- Contador
CREATE USER IF NOT EXISTS 'contador01'@'localhost'
    IDENTIFIED BY 'Contador#2026';
GRANT rol_contador TO 'contador01'@'localhost';
SET DEFAULT ROLE rol_contador TO 'contador01'@'localhost';

FLUSH PRIVILEGES;
-- Ejemplo 1: Añadir una columna de auditoría de tiempo a la tabla baggage_claims
-- Verificamos la estructura antes de la modificación
SELECT * FROM bookings.baggage_claims;
-- Realizamos la modificación para añadir la columna last_updated
ALTER TABLE bookings.baggage_claims
ADD COLUMN last_updated timestamp DEFAULT CURRENT_TIMESTAMP;
-- Verificamos la estructura después de la modificación
SELECT * FROM bookings.baggage_claims;
-- Ejemplo 2: Añadir una CHECK constraint a la tabla boarding_gates para evitar
terminales vacías
-- Verificamos que podemos hacer una inserción sin terminal en antes de la modificación
INSERT INTO bookings.boarding_gates (gate_no, airport_code, terminal)
VALUES ('C03', 'MAD', '');
-- Verificamos la inserción después de la modificación
SELECT * FROM bookings.boarding_gates;
-- Borramos el registro insertado para mantener la integridad de los datos
DELETE FROM bookings.boarding_gates WHERE terminal = '';
-- Realizamos la modificación para añadir la CHECK constraint
ALTER TABLE bookings.boarding_gates
ADD CONSTRAINT chk_terminal_not_empty CHECK (terminal <> '');
-- Verificamos que ya no podemos hacer un insert en la tabla después de la
modificación
INSERT INTO bookings.boarding_gates (gate_no, airport_code, terminal)
VALUES ('C03', 'MAD', '');
-- Verificamos la inserción después de la modificación
SELECT * FROM bookings.boarding_gates;
-- 1. Insert Sencillo: Crear una nueva reserva
INSERT INTO bookings.bookings (book_ref, book_date, total_amount)
VALUES ('XYZ123', '2026-08-01', 500.00);

-- Validamos que la reserva se ha insertado correctamente
SELECT *
FROM bookings.bookings
WHERE book_ref = 'XYZ123';

-- 2. Insert de Varios Elementos: Añadir dos billetes para la reserva anterior
INSERT INTO bookings.tickets (ticket_no, book_ref, passenger_id,
passenger_name, outbound)
VALUES ('1234567890123', 'XYZ123', '77788899A', 'John Doe', 'Y'),
('1234567890124', 'XYZ123', '11122233B', 'Jane Doe', 'Y');

-- Validamos que los billetes se han insertado correctamente
SELECT *
FROM bookings.tickets
WHERE book_ref = 'XYZ123';

-- 3. Insert desde tabla temporal: Guardar temporalmente reservas VIP (> 1000)
CREATE TEMPORARY TABLE temp_vip_bookings
AS
SELECT 'T' as reg_type
,*
FROM bookings.bookings
LIMIT 0;

-- Validamos que la tabla temporal se ha creado correctamente
SELECT *
FROM temp_vip_bookings;

-- Insertar reservas VIP en la tabla temporal
INSERT INTO temp_vip_bookings
SELECT 'T',
bk.*
FROM bookings.bookings bk
WHERE bk.total_amount >= 1000.00
LIMIT 1000;

-- Validamos que las reservas VIP se han insertado correctamente en la tabla
temporal
SELECT *
FROM temp_vip_bookings;

-- 4. Error de Inserción por violación de PK y su solución
-- Provocará error: "violates unique constraint" porque 'XYZ123' ya existe
INSERT INTO bookings.bookings (book_ref, book_date, total_amount)
VALUES ('XYZ123', '2026-08-02', 800.00);

-- Solución: Usar una PK nueva ('XYZ124') o usar ON CONFLICT (Upsert)
-- Realmente esta solución es similar a realizar un UPDATE si la PK ya existe,
pero en este caso, como queremos insertar una nueva reserva, usamos un book_ref
diferente.
INSERT INTO bookings.bookings (book_ref, book_date, total_amount)
VALUES ('XYZ123', '2026-08-02', 1200.00)
ON CONFLICT (book_ref) DO UPDATE SET total_amount = EXCLUDED.total_amount

-- Validamos que la reserva se ha actualizado correctamente
SELECT *
FROM bookings.bookings
WHERE book_ref LIKE 'XYZ1%';

-- Solución: Usar una PK nueva ('ZZZZP9')
-- Buscamos el último book_ref para generar uno nuevo
SELECT MAX(book_ref) AS ultima_reserva
FROM bookings.bookings

-- Generar un nuevo book_ref basado en la última reserva
INSERT INTO bookings.bookings (book_ref, book_date, total_amount)
VALUES ('ZZZZP9', '2026-08-02', 800.00);

-- Validamos que la nueva reserva se ha insertado correctamente
SELECT *
FROM bookings.bookings
WHERE book_ref LIKE 'ZZZZP%';
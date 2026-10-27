-- 1. Eliminar un billete específico
-- INSERT para no alterar los datos originales de la base de datos
INSERT INTO bookings.tickets (ticket_no, book_ref, passenger_id,
passenger_name, outbound)
VALUES ('1234567890199', 'XYZ123','US 1903569888099', 'John Doe', 'True');

-- Validamos que el billete se ha insertado correctamente
SELECT *
FROM bookings.tickets
WHERE ticket_no = '1234567890199';

-- Eliminamos el billete específico
DELETE FROM bookings.tickets tk
WHERE tk.ticket_no = '1234567890199';

-- Validamos que el billete se ha eliminado correctamente
SELECT *
FROM bookings.tickets
WHERE ticket_no = '1234567890199';

-- 2. Eliminar múltiples billetes asociados a una misma reserva
-- INSERT para no alterar los datos originales de la base de datos
INSERT INTO bookings.tickets (ticket_no, book_ref, passenger_id,
passenger_name, outbound)
VALUES ('1234567890199', 'XYZ123','US 1903569888099', 'John Doe', 'True')
, ('1234567890200', 'XYZ123','US 1903569888100', 'Jane Doe', 'True')
, ('1234567890201', 'XYZ123','US 1903569888101', 'Jim Doe', 'True');

-- Validamos que el billete se ha insertado correctamente
SELECT *
FROM bookings.tickets
WHERE book_ref = 'XYZ123';

-- Eliminamos la reserva específica
DELETE FROM bookings.tickets tk
WHERE tk.book_ref = 'XYZ123';

-- Validamos que la reserva se ha eliminado correctamente junto con sus billetes asociados
SELECT *
FROM bookings.tickets
WHERE book_ref = 'XYZ123';

-- 3. Eliminar la reserva
-- INSERT para no alterar los datos originales de la tabla bookings
INSERT INTO bookings.bookings (book_ref, book_date, total_amount)
VALUES ('XYZ124', CURRENT_DATE, 500.00)

-- INSERT para no alterar los datos originales de la tabla tickets
INSERT INTO bookings.tickets (ticket_no, book_ref, passenger_id,
passenger_name, outbound)
VALUES ('1234567890199', 'XYZ124','US 1903569888099', 'John Doe', 'True')
, ('1234567890200', 'XYZ124','US 1903569888100', 'Jane Doe', 'True')
, ('1234567890201', 'XYZ124','US 1903569888101', 'Jim Doe', 'True');

-- Validamos que la reserva se ha insertado correctamente en bookings
SELECT *
FROM bookings.bookings
WHERE book_ref = 'XYZ124';

-- Validamos que los billetes se han insertado correctamente en tickets
SELECT *
FROM bookings.tickets
WHERE book_ref = 'XYZ124';

-- Eliminamos la reserva específica
DELETE FROM bookings.bookings bk
WHERE bk.book_ref = 'XYZ124';

-- Eliminamos los billetes asociados a la reserva eliminada
DELETE FROM bookings.tickets bk
WHERE bk.book_ref = 'XYZ124';

-- Validamos que la reserva se ha insertado correctamente en bookings
SELECT *
FROM bookings.bookings
WHERE book_ref = 'XYZ124';

-- Validamos que los billetes se han insertado correctamente en tickets
SELECT *
FROM bookings.tickets
WHERE book_ref = 'XYZ124';

-- 4. Eliminar usando condiciones compuestas: Vuelos cancelados del año pasado
-- INSERT para no alterar los datos originales de la tabla flights
INSERT INTO bookings.flights (route_no, status, scheduled_departure,
scheduled_arrival)
VALUES ('PG123', 'Cancelled','2024-12-15 14:25:00', '2024-12-15 18:35:00')
, ('PG456', 'Cancelled','2024-11-20 02:35:00', '2024-11-20 06:45:00')
, ('PG789', 'Cancelled','2024-10-05 08:45:00', '2024-10-05 12:55:00');

-- Validamos que los vuelos se han insertado correctamente en flights
SELECT *
FROM bookings.flights fl
WHERE fl.status = 'Cancelled'
AND fl.scheduled_departure < '2025-01-01';

-- Eliminamos los vuelos cancelados del año pasado
DELETE FROM bookings.flights fl
WHERE fl.status = 'Cancelled'
AND fl.scheduled_departure < '2025-01-01';

-- Validamos que los vuelos se han eliminado correctamente en flights
SELECT *
FROM bookings.flights fl
WHERE fl.status = 'Cancelled'
AND fl.scheduled_departure < '2025-01-01'
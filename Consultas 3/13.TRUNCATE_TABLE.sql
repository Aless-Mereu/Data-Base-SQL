-- 1. Creamos tablas temporales para almacenar información de vuelos retrasados
--o cancelados y reservas de alto valor (VIP)
-- Crear tabla temporal de resumen de vuelos retrasados o cancelados
CREATE TEMPORARY TABLE temp_flights_summary AS
SELECT fl.flight_id,
fl.route_no,
fl.status,
fl.scheduled_departure
FROM bookings.flights fl
WHERE fl.status IN ('Delayed', 'Cancelled')
LIMIT 1000;
-- Crear tabla temporal de reservas de alto valor (VIP)
CREATE TEMPORARY TABLE temp_bookings_summary AS
SELECT bk.book_ref,
bk.book_date,
bk.total_amount
FROM bookings.bookings bk
WHERE bk.total_amount > 50000.00
LIMIT 1000;
-- Verificamos que las tablas temporales se han creado correctamente
SELECT * FROM temp_flights_summary;
SELECT * FROM temp_bookings_summary;
-- 2. Vaciar rápidamente la tabla temporal de vuelos utilizando TRUNCATE
TRUNCATE TABLE temp_flights_summary;
-- Verificamos que la tabla temporal de vuelos se encuentra vacía
SELECT COUNT(*) FROM temp_flights_summary; -- Retornará 0 registros
-- 3. Eliminar de forma permanente ambas tablas de la sesión temporal (DROP)
DROP TABLE temp_flights_summary;
DROP TABLE temp_bookings_summary;
-- Verificamos que las tablas temporales se han eliminado correctamente
SELECT * FROM temp_flights_summary;
SELECT * FROM temp_bookings_summary;
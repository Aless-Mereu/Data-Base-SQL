-- 1. Ejecutaremos el procedimiento bookings.update_flight_segment_prices
-- creado anteriormente
CALL bookings.update_flight_segment_prices(12345, -10.00, 'Economy');
-- Validamos el cambio realizado en la tabla bookings.segments para el vuelo
-- con flight_id = 1001
SELECT *
FROM bookings.segments
WHERE flight_id = 12345
AND fare_conditions = 'Economy';
-- 2. Ejecutaremos el procedimiento bookings.archive_cancelled_flights creado
-- anteriormente
BEGIN;
CALL bookings.archive_cancelled_flights('PG0805', 'mi_cursor');
FETCH ALL FROM mi_cursor;
COMMIT;
-- 1. Creamos un registro en la tabla bookings.bookings con book_ref = 'XJK300'
BEGIN;
INSERT INTO bookings.bookings (book_ref, book_date, total_amount)
VALUES ('XJK300', '2024-06-01', 500.00);
-- Verificamos que el registro se haya insertado correctamente
/*
  Si abrimos otra sesión de base de datos y ejecutamos la siguiente consulta,
  no veremos el registro insertado hasta que se haga COMMIT.
*/

SELECT bk.*
FROM bookings.bookings bk
WHERE bk.book_ref = 'XJK300';
-- Validamos la transacción y confirmamos los cambios realizados en la base de
datos
COMMIT;

-- 2. Insertamos un registro en la tabla bookings.bookings y otro en la tabla
bookings.tickets, y luego hacemos un COMMIT para confirmar los cambios
realizados en ambas tablas.
BEGIN;
-- Insertar registro en la tabla cabecera de reservas
INSERT INTO bookings.bookings (book_ref, book_date, total_amount)
VALUES ('TX999A', CURRENT_TIMESTAMP, 15000.00);
-- Insertar el billete del pasajero asociado a la clave primaria generada
INSERT INTO bookings.tickets (ticket_no, book_ref, passenger_id,
passenger_name, outbound)
VALUES ('9999999999999', 'TX999A', 'ES 4383871116867', 'Alberto Gomez',
'True');
COMMIT;

-- Validamos los dos registros fuera de la transacción para confirmar que se han insertado correctamente
SELECT * FROM bookings.bookings WHERE book_ref = 'TX999A';
SELECT * FROM bookings.tickets WHERE book_ref = 'TX999A';
-- Ahora ejecutamos un UPDATE sobre bookings.tickets
BEGIN;
UPDATE bookings.tickets
SET passenger_name = 'Alberto Gomez Martinez'
WHERE book_ref = 'TX999A';
-- Validamos el cambio realizado en la tabla bookings.tickets
SELECT * FROM bookings.tickets WHERE book_ref = 'TX999A';
-- Confirmamos los cambios realizados en la tabla bookings.tickets
COMMIT;

-- 3. Insertamos un registro en la tabla bookings.bookings y otro en la tabla
-- bookings.tickets, y luego hacemos un ROLLBACK para deshacer los cambios
-- realizados en ambas tablas.

/*
-- Solo para DOCENTE:
DROP TABLE IF EXISTS bookings.tickets_it_temp;
*/

BEGIN;
CREATE TABLE bookings.tickets_it_temp AS
SELECT DISTINCT bk.book_date::date AS book_date,
fl.scheduled_departure,
fl.flight_id,
fl.route_no,
ad.airplane_code,
rt.arrival_airport,
ap.airport_name AS arrival_airport_name,
tk.*,
sg.fare_conditions,
bk.total_amount
FROM bookings.tickets tk
INNER JOIN bookings.bookings bk ON tk.book_ref = bk.book_ref
INNER JOIN bookings.segments sg ON tk.ticket_no = sg.ticket_no
INNER JOIN bookings.flights fl ON sg.flight_id = fl.flight_id
INNER JOIN bookings.routes rt ON fl.route_no = rt.route_no
INNER JOIN bookings.airplanes_data ad ON rt.airplane_code =
ad.airplane_code
INNER JOIN bookings.airports ap ON rt.arrival_airport = ap.airport_code
WHERE tk.passenger_id LIKE 'IT%'
AND tk.outbound = 'False'
AND bk.book_date::date = '2026-01-01';

-- Validamos el tipo de asiento por avión para todos los vuelos registrados
-- en la tabla bookings.tickets_temp
SELECT airplane_code,
SUM(CASE WHEN fare_conditions = 'Business' THEN 1 ELSE 0 END) AS
business_records,
SUM(CASE WHEN fare_conditions = 'Comfort' THEN 1 ELSE 0 END) AS
comfort_records,
SUM(CASE WHEN fare_conditions = 'Economy' THEN 1 ELSE 0 END) AS
economy_records
FROM bookings.tickets_it_temp
WHERE airplane_code IN ('77W', '351')
GROUP BY airplane_code
ORDER BY airplane_code;

-- Vamos a cambiar el tipo de avión de la tabla bookings.airplanes_data para
-- el avión con código '77W' a '351' y luego haremos un ROLLBACK para deshacer el
-- cambio realizado.
UPDATE bookings.tickets_it_temp
SET airplane_code = '77W'
WHERE airplane_code = '351';
-- Validamos cambio realizado en la tabla bookings.tickets_it_temp
SELECT airplane_code,
SUM(CASE WHEN fare_conditions = 'Business' THEN 1 ELSE 0 END) AS
business_records,
SUM(CASE WHEN fare_conditions = 'Comfort' THEN 1 ELSE 0 END) AS
comfort_records,
SUM(CASE WHEN fare_conditions = 'Economy' THEN 1 ELSE 0 END) AS
economy_records
FROM bookings.tickets_it_temp
WHERE airplane_code IN ('77W', '351')
GROUP BY airplane_code
ORDER BY airplane_code;

-- Ahora vamos a crear un punto de guardado con nombre "it_temp_savepoint"
-- para poder deshacer los cambios realizados en la tabla bookings.tickets_temp

SAVEPOINT it_temp_savepoint;
-- Vemos la situación de los registros por tipo de asiento en la tabla
bookings.tickets_temp antes de realizar el UPDATE
SELECT COUNT(*) AS total_records,
SUM(CASE WHEN fare_conditions = 'Business' THEN 1 ELSE 0 END) AS
business_records,
SUM(CASE WHEN fare_conditions = 'Comfort' THEN 1 ELSE 0 END) AS
comfort_records,
SUM(CASE WHEN fare_conditions = 'Economy' THEN 1 ELSE 0 END) AS
economy_records
FROM bookings.tickets_it_temp;

-- Realizamos un UPDATE sobre la tabla bookings.tickets_temp para cambiar
-- el valor de la columna fare_conditions de 'Confort' a 'Business'
UPDATE bookings.tickets_it_temp
SET fare_conditions = 'Business'
WHERE fare_conditions = 'Comfort';
-- Validamos el cambio realizado en la tabla bookings.tickets_temp
SELECT COUNT(*) AS total_records,
SUM(CASE WHEN fare_conditions = 'Business' THEN 1 ELSE 0 END) AS
business_records,
SUM(CASE WHEN fare_conditions = 'Comfort' THEN 1 ELSE 0 END) AS
comfort_records,
SUM(CASE WHEN fare_conditions = 'Economy' THEN 1 ELSE 0 END) AS
economy_records
FROM bookings.tickets_it_temp;

-- Deshacemos los cambios realizados en la tabla bookings.tickets_temp hasta
-- el punto de guardado "it_temp_savepoint"
ROLLBACK TO SAVEPOINT it_temp_savepoint;
/*
  Sin en mitad del bloque de transacción, queremos validar los cambios hasta el
punto de guardado "it_temp_savepoint"
  pero sin terminar de confirmar el resto de la transacción podemos usasr:
  RELEASE SAVEPOINT it_temp_savepoint;
*/
-- Validamos que los cambios realizados en la tabla bookings.tickets_temp se
-- hayan deshecho correctamente

SELECT airplane_code,
SUM(CASE WHEN fare_conditions = 'Business' THEN 1 ELSE 0 END) AS
business_records,
SUM(CASE WHEN fare_conditions = 'Comfort' THEN 1 ELSE 0 END) AS
comfort_records,
SUM(CASE WHEN fare_conditions = 'Economy' THEN 1 ELSE 0 END) AS
economy_records
FROM bookings.tickets_it_temp
WHERE airplane_code IN ('77W', '351')
GROUP BY airplane_code
ORDER BY airplane_code;
-- Podemos confirmar el resto de los cambios realizados en la tabla
bookings.tickets_temp
COMMIT;
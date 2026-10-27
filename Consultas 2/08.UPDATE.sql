-- 1. Actualizar el importe de una reserva específica
UPDATE bookings.bookings bk
SET total_amount = 650.00
WHERE bk.book_ref = 'XYZ123';

-- Validamos que la reserva se ha actualizado correctamente
SELECT *, 800.00 as total_amount_corrected
FROM bookings.bookings
WHERE book_ref = 'XYZ123';

-- 2. Corregir el nombre de un pasajero en su billete
UPDATE bookings.tickets tk
SET passenger_name = 'Jonathan Doe'
WHERE tk.ticket_no = '0005437629810';

-- Validamos que el nombre del pasajero se ha actualizado correctamente
SELECT *,
'James Rush' as passenger_name_corrected
FROM bookings.tickets
WHERE ticket_no = '0005437629810';

-- 3. Actualización múltiple: Marcar como 'Delayed' vuelos que no han salido a su hora
CREATE TEMPORARY TABLE temp_flights
AS
SELECT 'T' as reg_type
,*
FROM bookings.flights
LIMIT 0;

-- Creamos la tabla temporal para almacenar los vuelos retrasados y volver a su
-- estado original si es necesario
INSERT INTO temp_flights
SELECT 'T',
fl.*
FROM bookings.flights fl
WHERE fl.actual_departure IS NULL
AND fl.scheduled_departure < CURRENT_TIMESTAMP
ORDER BY fl.scheduled_departure DESC;

-- Lanzamos la actualización de los vuelos retrasados
UPDATE bookings.flights fl
SET status = 'Delayed'
WHERE fl.actual_departure IS NULL
AND fl.scheduled_departure < CURRENT_TIMESTAMP;

-- Validamos que los vuelos se han actualizado correctamente
SELECT *,'On Time' as status_corrected
FROM bookings.flights
WHERE actual_departure IS NULL
AND scheduled_departure < CURRENT_TIMESTAMP
ORDER BY scheduled_departure DESC;

-- Ahora podemos revertir los cambios si es necesario
UPDATE bookings.flights fl
SET status = u.status
FROM (SELECT flight_id, status FROM temp_flights) u
WHERE fl.flight_id = u.flight_id
AND fl.status = 'Delayed';

-- 4. Error de actualización por violación de PK y su solución
SELECT *
FROM bookings.tickets
WHERE ticket_no LIKE '00054376298%'
ORDER BY ticket_no DESC
LIMIT 2;

-- Provocará error si el ticket_no '0005437629810' existe en la tabla
UPDATE bookings.tickets tk
SET ticket_no = '0005437629809'
WHERE tk.ticket_no = '0005437629810';
/*
-- Error que obtenemos
llave duplicada viola restricción de unicidad «tickets_pkey»
DETAIL: Ya existe la llave (ticket_no)=(0005437629809).
*/
-- Solución: Asegurarse de actualizar a un valor de Primary Key que no exista
en la tabla, pero esto nos genera un error por violación de la clave foránea
UPDATE bookings.tickets tk
SET ticket_no = '0005437629811'
WHERE tk.ticket_no = '0005437629809';

/*
-- Error que obtenemos
update o delete en «tickets» viola la llave foránea «segments_ticket_no_fkey»
en la tabla «segments»
DETAIL: La llave (ticket_no)=(0005437629809) todavía es referida desde la tabla
«segments».
*/
---------------------------------------------
-- Parámetro ON UPDATE CASCADE --
---------------------------------------------
CREATE TABLE tabla_padre (
id INT PRIMARY KEY
);
CREATE TABLE tabla_hija (
id INT PRIMARY KEY,
padre_id INT REFERENCES tabla_padre(id) ON UPDATE CASCADE
);
INSERT INTO tabla_padre (id) VALUES (1);
INSERT INTO tabla_hija (id, padre_id) VALUES (1, 1);
SELECT * FROM tabla_padre;
SELECT * FROM tabla_hija;
UPDATE tabla_padre SET id = 100 WHERE id = 1;

SELECT * FROM tabla_padre;
SELECT * FROM tabla_hija;
DROP TABLE tabla_hija;
DROP TABLE tabla_padre;
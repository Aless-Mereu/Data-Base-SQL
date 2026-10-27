-- 1. Recuperar todos los datos de la cabecera de reservas
SELECT bk.*
FROM bookings.bookings bk
LIMIT 100;

-- 2. Uso de alias de tabla para simplificar la consulta de aeropuertos
SELECT ai.airport_code,
ai.airport_name
FROM bookings.airports ai;

-- 3. Limitar el resultado a los primeros 10 aviones registrados
SELECT ap.airplane_code,
ap.model
FROM bookings.airplanes ap;

-- 4. Mostrar los primeros 5 pasajeros registrados en la tabla de tickets
SELECT tk.ticket_no,
tk.passenger_name
FROM bookings.tickets tk
LIMIT 5;

-- 4.1 Paginación: Saltar los primeros 5 billetes y mostrar los siguientes 5
SELECT tk.ticket_no,
tk.passenger_name
FROM bookings.tickets tk
OFFSET 5 ROWS
FETCH FIRST 5 ROWS ONLY;

-- 5. Uso de DISTINCT y ORDER BY para obtener valores únicos en una columna
SELECT DISTINCT ai.country
FROM bookings.airports ai
ORDER BY ai.country;
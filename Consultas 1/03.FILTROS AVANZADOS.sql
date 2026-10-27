-- 1. Uso de BETWEEN para rangos de fechas en las reservas
SELECT bk.book_ref,
bk.book_date
FROM bookings.bookings bk
WHERE
bk.book_date BETWEEN '2026-01-10' AND '2026-01-11';

-- 2. Uso de IN para listas de valores en ciudades de aeropuertos
SELECT ai.airport_name,
ai.city
FROM bookings.airports ai
WHERE ai.city IN ('Madrid', 'Barcelona', 'Valencia');

-- 3. Uso de LIKE para buscar patrones de texto (pasajeros cuyo nombre empieza
-- por 'Garcia')
SELECT tk.passenger_name,
tk.ticket_no
FROM bookings.tickets tk
WHERE tk.passenger_name LIKE '%Mor%s'
LIMIT
200;

-- 4. Uso de IS NULL para encontrar vuelos sin salida real registrada (aún
-- pendientes)
SELECT fl.flight_id, fl.status
FROM bookings.flights fl
WHERE fl.actual_departure IS NULL
LIMIT
100;
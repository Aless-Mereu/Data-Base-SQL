-- 1. Filtrar un aeropuerto por un valor de texto exacto (país)
SELECT ai.airport_code,
ai.airport_name
FROM bookings.airports ai
WHERE ai.country = 'Spain';

-- 2. Filtrar utilizando operadores matemáticos en el coste de las reservas
SELECT bk.book_ref,
bk.total_amount
FROM bookings.bookings bk
WHERE bk.total_amount > 1000.00;

-- 3. Combinar condiciones lógicas con AND para vuelos a tiempo en una ruta u
usando ORDER BY para mostrar resultados de forma descendente
SELECT fl.flight_id,
fl.scheduled_departure
FROM bookings.flights fl
WHERE fl.status = 'Arrived'
AND fl.route_no = 'PG0139'
ORDER BY fl.flight_id DESC;

-- 4. Filtrar y limitar los resultados simultáneamente en segmentos de vuelo
SELECT sg.ticket_no,
sg.price
FROM bookings.segments sg
WHERE sg.fare_conditions = 'Business'
LIMIT 5;    
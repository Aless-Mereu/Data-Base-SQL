-- 1. Ranking de precios de billetes por clase (fare_conditions) utilizando
-- DENSE_RANK()
SELECT sg.ticket_no,
sg.flight_id,
sg.fare_conditions,
sg.price,
DENSE_RANK() OVER (
PARTITION BY sg.fare_conditions
ORDER BY sg.price DESC
) AS ranking_precio_clase
FROM bookings.segments sg
LIMIT 200;

-- 2. Ranking de ingresos acumulados por fecha de reserva (book_date) utilizando SUM() y OVER()
SELECT bk.book_ref,
bk.book_date,
bk.total_amount,
SUM(bk.total_amount) OVER (
ORDER BY bk.book_date
ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
) AS ingresos_acumulados
FROM bookings.bookings bk
ORDER BY bk.book_date ASC
LIMIT 200;

-- 3. Ranking de intervalos de despegue de vuelos por ruta (route_no) utilizando LAG() y OVER()
SELECT fl.flight_id,
fl.route_no,
fl.scheduled_departure,
fl.actual_departure,
LAG(fl.actual_departure) OVER (
PARTITION BY fl.route_no
ORDER BY fl.actual_departure ASC
) AS despegue_vuelo_anterior,
fl.actual_departure - LAG(fl.actual_departure) OVER (
PARTITION BY fl.route_no
ORDER BY fl.actual_departure ASC
) AS intervalo_con_anterior
FROM bookings.flights fl
WHERE fl.status = 'Arrived'
AND fl.actual_departure IS NOT NULL
LIMIT 200;
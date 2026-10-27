-- 1. Vuelos programados y su diferencia con el vuelo anterior de la misma ruta utilizando LAG() y OVER()
SELECT fl.flight_id,
fl.route_no,
fl.scheduled_departure,
-- Obtener la salida programada del vuelo anterior de la misma ruta
LAG(fl.scheduled_departure) OVER (
PARTITION BY fl.route_no
ORDER BY fl.scheduled_departure ASC
) AS salida_vuelo_anterior,
-- Calcular la diferencia temporal exacta
fl.scheduled_departure - LAG(fl.scheduled_departure) OVER (
PARTITION BY fl.route_no
ORDER BY fl.scheduled_departure ASC
) AS intervalo_con_anterior
FROM bookings.flights fl
ORDER BY fl.route_no,
fl.scheduled_departure;

-- 2. Análisis de vuelos programados y su diferencia con el vuelo siguiente de la misma ruta utilizando LEAD() y OVER()
SELECT fl.flight_id,
fl.route_no,
fl.scheduled_departure,
fl.status,
-- Obtener la salida programada del siguiente vuelo de la ruta
LEAD(fl.scheduled_departure) OVER (
PARTITION BY fl.route_no
ORDER BY fl.scheduled_departure ASC
) AS salida_siguiente_vuelo,
-- Calcular cuánto tiempo de margen hay hasta la siguiente salida
LEAD(fl.scheduled_departure) OVER (
PARTITION BY fl.route_no
ORDER BY fl.scheduled_departure ASC
) - fl.scheduled_departure AS margen_tiempo_siguiente
FROM bookings.flights fl
WHERE fl.status <> 'Cancelled' -- Excluir vuelos cancelados que no operarán
ORDER BY fl.route_no,
fl.scheduled_departure;

-- 3.Comparación de incremento precios de billetes por clase (fare_conditions)
utilizando LAG() y OVER()
-- Creamos una tabla temporal con precios aleatorios para simular incrementos
de tarifas
-- DROP TABLE IF EXISTS bookings.segments_price_random;
CREATE TABLE bookings.segments_price_random AS
SELECT sg2.flight_id,
sg2.ticket_no,
sg2.fare_conditions,
sg2.price+floor(random() * (100 - 1 + 1) + 1)::int AS price
FROM bookings.segments sg2
WHERE sg2.flight_id BETWEEN 2000 AND 5000
AND MOD(sg2.flight_id, 2) = 0;
-- Comprobamos la tabla creada
SELECT * FROM bookings.segments_price_random;
-- Ejecutamos la consulta para comparar los precios de billetes por clase y
calcular el incremento con respecto al precio anterior
SELECT sg.flight_id,
sg.ticket_no,
sg.fare_conditions,
sg.price,
-- Obtener el precio inmediatamente inferior para la misma clase y vuelo
LAG(sg.price) OVER (
PARTITION BY sg.flight_id, sg.fare_conditions
ORDER BY sg.price ASC
) AS precio_anterior,
-- Calcular la diferencia del incremento de tarifa
sg.price - LAG(sg.price) OVER (
PARTITION BY sg.flight_id, sg.fare_conditions
ORDER BY sg.price ASC
) AS incremento_precio
FROM bookings.segments_price_random sg
WHERE sg.fare_conditions IN ('Economy', 'Confort')
--AND sg.flight_id/2 = 0
ORDER BY sg.flight_id,
sg.fare_conditions,
sg.price;


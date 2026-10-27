-- 1. Contar el número de vuelos agrupados por su estado actual
SELECT fl.status, COUNT(fl.flight_id) AS total_vuelos
FROM bookings.flights fl
GROUP BY fl.status;

-- 2. Calcular la recaudación total de reservas agrupada por fecha
SELECT bk.book_date, SUM(bk.total_amount) AS recaudacion_diaria
FROM bookings.bookings bk
GROUP BY bk.book_date
ORDER BY bk.book_date DESC;

-- 3. Calcular el precio medio de un segmento de vuelo según la clase de tarifa
SELECT sg.fare_conditions, AVG(sg.price) AS precio_medio
FROM bookings.segments sg
GROUP BY sg.fare_conditions;

-- 4. Contar cuántos asientos tiene cada modelo de avión combinando JOIN y
GROUP BY
SELECT ap.model, COUNT(st.seat_no) AS total_asientos
FROM bookings.airplanes ap
INNER JOIN bookings.seats st ON ap.airplane_code = st.airplane_code
GROUP BY ap.model;
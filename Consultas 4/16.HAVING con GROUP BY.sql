SELECT fl.route_no,
COUNT(fl.flight_id) AS total_cancelados
FROM bookings.flights fl
WHERE fl.status = 'Cancelled'
GROUP BY fl.route_no
HAVING COUNT(fl.flight_id) > 2
ORDER BY total_cancelados DESC;

-- 2. Encuentra los pasajeros que han comprado más de 3, cuyo precio promedio sea superior a 25.000,00
SELECT tk.passenger_name,
tk.passenger_id,
COUNT(DISTINCT tk.ticket_no) AS total_billetes,
AVG(sg.price) AS precio_promedio
FROM bookings.tickets tk
INNER JOIN bookings.segments sg ON tk.ticket_no = sg.ticket_no
GROUP BY tk.passenger_name, tk.passenger_id
HAVING COUNT(DISTINCT tk.ticket_no) > 3 AND AVG(sg.price) > 25000.00
ORDER BY total_billetes DESC

-- 3. Encuentra los modelos de aviones (bookings.airplanes) que tienen más de 100 asientos y más de 20 asientos en clase Business
SELECT ap.model,
COUNT(st.seat_no) AS total_asientos,
SUM(CASE
WHEN st.fare_conditions = 'Business' THEN 1
ELSE 0
END) AS asientos_business
FROM bookings.airplanes ap
INNER JOIN bookings.seats st ON ap.airplane_code = st.airplane_code
GROUP BY ap.model
HAVING COUNT(st.seat_no) > 100
AND SUM(CASE
WHEN st.fare_conditions = 'Business' THEN 1
ELSE 0
END) > 20;


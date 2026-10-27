-- 1. INNER JOIN: Reservas y sus billetes cruzados por la referencia (book_ref)
SELECT bk.book_date,
tk.passenger_name,
tk.ticket_no
FROM bookings.bookings bk
INNER JOIN bookings.tickets tk ON bk.book_ref = tk.book_ref
WHERE bk.book_date BETWEEN '202-01-10' AND '2026-01-11'
LIMIT
10;

-- 2. LEFT JOIN: Todos los aviones y, si la tienen, la configuración de sus asientos
SELECT ap.model,
st.seat_no,
st.fare_conditions
FROM bookings.airplanes ap
LEFT JOIN bookings.seats st ON ap.airplane_code = st.airplane_code;

/**3. RIGHT JOIN: Todas las tarjetas de embarque y la información del billete
asociado por el número de embarque 44.*//
SELECT bp.boarding_no,
tk.passenger_name
FROM bookings.tickets tk
RIGHT JOIN bookings.boarding_passes bp ON tk.ticket_no = bp.ticket_no
WHERE bp.boarding_no = 44;

/** 3.1 RIGHT JOIN: Todas las tarjetas de embarque y la información del billete
asociado para el número de embarque 44.
 Tendremos que usar la cláusula WHERE para filtrar el número de embarque, ya
que no podemos ponerlo en la condición del JOIN si queremos que se muestren
todas las tarjetas de embarque, incluso aquellas que no tienen billete
asociado.
 Si no lo hacemos, tendremos que irnos a la posición 274 para ver el primer
resultado.*//
SELECT bp.boarding_no,
tk.passenger_name
FROM bookings.tickets tk
RIGHT JOIN bookings.boarding_passes bp ON (tk.ticket_no = bp.ticket_no
AND bp.boarding_no = 44)
LIMIT
1000;

/** 3.2 RIGHT JOIN: Todas las tarjetas de embarque y la información del billete
asociado para el número de embarque 44.
Añadir la condición de filtrado en el WHERE para que se muestren todas las
tarjetas de embarque 44 sin el resto de resultados a NULL.*//
SELECT bp.boarding_no,
tk.passenger_name
FROM bookings.tickets tk
RIGHT JOIN bookings.boarding_passes bp ON (tk.ticket_no = bp.ticket_no
AND bp.boarding_no = 44)
WHERE tk.passenger_name IS NOT NULL
LIMIT
1000;

-- 4. FULL OUTER JOIN: Rutas teóricas y vuelos programados cruzados por ruta
SELECT rt.route_no,
fl.flight_id,
fl.status
FROM bookings.routes rt
FULL OUTER JOIN bookings.flights fl ON rt.route_no = fl.route_no
ORDER by fl.route_no;
/**1. UNION simple: Combina eliminando códigos duplicados entre tablas maestras
de aeropuertos **/
SELECT ai.airport_code
FROM bookings.airports ai
UNION
SELECT airport_code
FROM bookings.airports_data aid;

/** 2. UNION ALL: Combina manteniendo todos los registros de códigos de aviones
(más rápido)**/ 
SELECT ap.airplane_code
FROM bookings.airplanes ap
UNION ALL
SELECT apd.airplane_code
FROM bookings.airplanes_data apd;

-- 3. UNION con literales: Clasificar el origen del identificador
SELECT tk.ticket_no AS identificador,
'Billete' AS tipo_registro
FROM bookings.tickets tk
WHERE tk.passenger_id LIKE 'JP%'
AND tk.outbound = 'Y'
UNION
SELECT bk.book_ref AS identificador,
'Reserva' AS tipo_registro
FROM bookings.bookings bk
WHERE bk.book_ref LIKE 'JP%';

-- 4. UNION aplicando condiciones previas: Agrupar vuelos con incidencias
SELECT fl.flight_id,
fl.status
FROM bookings.flights fl
WHERE fl.status = 'Cancelled'
UNION
SELECT fl.flight_id,
fl.status
FROM bookings.flights fl
WHERE fl.status = 'Delayed';

-- 5. UNION con ordenación: Agrupar vuelos con incidencias y ordenar por estado
SELECT ft.flight_id,
ft.status
FROM ( SELECT fl.flight_id,
fl.status
FROM bookings.flights fl
WHERE fl.status = 'Cancelled'
UNION
SELECT fl.flight_id,
fl.status
FROM bookings.flights fl
WHERE fl.status = 'Delayed'
) AS ft
ORDER BY ft.status;
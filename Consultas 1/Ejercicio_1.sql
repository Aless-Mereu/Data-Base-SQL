

SELECT fl.flight_id,
tk.passenger_name,
sg.price,
fl.status
FROM bookings.flights fl
JOIN bookings.segments sg ON sg.flight_id = fl.flight_id
JOIN bookings.tickets tk ON tk.ticket_no = sg.ticket_no
WHERE fl.status = 'Cancelled';
--Ninguna coincidencia.

--Comprobaciones
-- 1. Hay vuelos cancelados?
SELECT status, count(*) FROM bookings.flights GROUP BY status;
-- Sí, los hay.

-- 2. Tienen segments (billetes) esos vuelos?
SELECT count(*)
FROM bookings.flights fl
JOIN bookings.segments sg ON sg.flight_id = fl.flight_id
WHERE fl.status = 'Cancelled';
-- No, no los hay

--Deducimos que hay vuelos cancelados pero con ningún billete listado

--Vuelos cancelados sin pasajeros.
SELECT fl.flight_id, 
tk.passenger_name, 
sg.price, 
fl.status
FROM bookings.flights fl
FULL OUTER JOIN bookings.segments sg ON sg.flight_id = fl.flight_id
FULL OUTER JOIN bookings.tickets tk ON tk.ticket_no = sg.ticket_no
WHERE fl.status = 'Cancelled';
--201 registros generados

/*
En primer lugar realizamos una consulta sencilla con INNER JOIN para consultar las filas con
coincidencias en ambas tablas.(Usando una tabla de paso (segments) para unir flights y tickets)
Al no haber coincidencias, realizamos un part de comprobaciones, la primera es ver si existen
vuelos cancelados, al verificar que los hay, comprobamos que los vuelos cancelados tengan billetes,
como no los hay, deducimos que no existen billetes de vuelos cancelados con billete referenciado.
Por último hacemos la misma consulta pero con un FULL JOIN para que nos devuelva todos los registros
conal menos una coincidencia, listando 201 registros con vuelos cancelados.
*/
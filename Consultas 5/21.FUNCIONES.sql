-- 1. Creamos la función bookings.get_formatted_amount que recibe como
-- parámetro el book_ref de la reserva y devuelve el importe total de la reserva
-- en formato monetario.
CREATE OR REPLACE FUNCTION bookings.get_formatted_amount (p_book_ref
varchar(6))
RETURNS text
AS $$
SELECT TO_CHAR(bk.total_amount, 'LFM999,999,990.00')
FROM bookings.bookings bk
WHERE bk.book_ref = p_book_ref;
$$ LANGUAGE SQL;
-- Ejecutamos la función creada para obtener el importe total de la reserva con
book_ref = '13NH0K' en formato monetario
SELECT bookings.get_formatted_amount('13NH0K') AS formatted_amount;
-- Podemos ver la diferencia entre el resultado de la función y el resultado de
la consulta directa a la tabla bookings.bookings
SELECT * FROM bookings.bookings bk WHERE bk.book_ref = '13NH0K';

--  2. Creamos la función bookings.get_passenger_flight_history que recibe como
-- parámetro el passenger_id del pasajero
CREATE OR REPLACE FUNCTION bookings.get_passenger_flight_history
(p_passenger_id varchar(100))
RETURNS TABLE (
ticket_no text,
passenger_name text,
flight_id integer,
route_no text,
status text,
segment_price numeric(10,2)
)
AS $$
BEGIN RETURN QUERY
SELECT tk.ticket_no,
tk.passenger_name,
fl.flight_id,
fl.route_no,
fl.status,
sg.price
FROM bookings.tickets tk
INNER JOIN bookings.segments sg ON tk.ticket_no = sg.ticket_no
INNER JOIN bookings.flights fl ON sg.flight_id = fl.flight_id
WHERE tk.passenger_id = p_passenger_id;
END;
$$ LANGUAGE plpgsql;

-- Ejecutamos la función creada para obtener el historial de vuelos del
-- pasajero que indiquemos
SELECT * FROM bookings.get_passenger_flight_history('US 2779671121032');
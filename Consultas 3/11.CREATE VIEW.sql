-- 1. Vista de Itinerario de Vuelos (Alias: v_fs)
CREATE VIEW bookings.vw_flight_schedules
AS
SELECT fl.flight_id,
rt.route_no,
fl.scheduled_departure,
fl.scheduled_arrival,
fl.status
FROM bookings.flights fl
INNER JOIN bookings.routes rt ON fl.route_no = rt.route_no
WHERE fl.status = 'Scheduled';
-- Verificamos la creación de la vista
SELECT v_fs.*
FROM bookings.vw_flight_schedules v_fs;
-- 2. Vista de Recogidas de Equipaje Activas (Alias: v_ac)
CREATE VIEW bookings.vw_active_claims
AS
SELECT bc.claim_id, bc.carousel_no, fl.flight_id, rt.route_no, bc.status
FROM bookings.baggage_claims bc
INNER JOIN bookings.flights fl ON bc.flight_id = fl.flight_id
INNER JOIN bookings.routes rt ON fl.route_no = rt.route_no
WHERE bc.status != 'Completed';
-- Verificamos la creación de la vista
SELECT v_ac.*
FROM bookings.vw_active_claims v_ac;
-- 3. Vista de Puertas de Embarque por Aeropuerto y Ciudad (Alias: v_ag)
CREATE VIEW bookings.vw_airport_gates
AS
SELECT bg.gate_no, bg.terminal, ai.airport_code, ai.airport_name, ai.city,
ai.country
FROM bookings.boarding_gates bg
INNER JOIN bookings.airports ai ON bg.airport_code = ai.airport_code;
-- Verificamos la creación de la vista
SELECT v_ag.*
FROM bookings.vw_airport_gates v_ag;
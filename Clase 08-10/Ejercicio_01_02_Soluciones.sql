/*

EJERCICIO 1
---------------------------------------------------------
PARTE 1
Pregunta 1:
Al tratarse de un sistema crítico es fundamental el uso de un motor de base de datos SQL ya que las propiedades ACID
otorgan la atomicidad, consistencia, aislamiento y durabilidad a los datos durante su persistencia
y transacciones mientras que un motor de una base de datos NoSQL no es tan estricto 

Pregunta 2:
La diferencia técnica entre un WHERE y un HAVING es que el primero filtra filas independientes
antes de agrupar y el HAVING lo hace después, sobre los resultados del GROUP BY. 
El WHERE actúa justo después del FROM y JOIN, su uso es críticos para hacer consultas eficientes
y el HAVING después del GROUP BY.

*/
-- PARTE 2
--Tarea 1:
SELECT rt.route_no, 
ai.airport_name AS departure_airport, 
ap.airport_name AS arrival_airport, 
COUNT(fl.flight_id) AS total_cancelled
FROM bookings.routes AS rt
INNER JOIN bookings.flights fl ON fl.route_no = rt.route_no
INNER JOIN bookings.airports ai ON ai.airport_code = rt.departure_airport
INNER JOIN bookings.airports ap ON ap.airport_code = rt.arrival_airport
GROUP BY rt.route_no, ai.airport_name, ap.airport_name
HAVING COUNT(fl.flight_id) > 2
ORDER BY total_cancelled DESC  


--Tarea 2
CREATE TABLE bookings.flight_incidents (
    incident_id serial PRIMARY KEY,
    flight_id integer NOT NULL REFERENCES bookings.flights (flight_id) ON DELETE CASCADE,
    incident_type varchar(50) NOT NULL,
    severity varchar(20) NOT NULL,
    CONSTRAINT chk_incident_severity CHECK (
      severity IN ('Low', 'Medium', 'High', 'Critical')
    )
);

INSERT INTO bookings.flight_incidents (flight_id, incident_type, severity)
VALUES (1234, 'Engine Check', 'High');

SELECT *
FROM bookings.flight_incidents;


---------------------------------------------------------------
EJERCICIO 2
CREATE TABLE bookings.aircraft_maintenance(
  maintenance_id serial PRIMARY KEY,
  airplane_code bpchar(3) REFERENCES bookings.airplanes_data(airplane_code) ON UPDATE CASCADE ON DELETE CASCADE,
  maintenance_type varchar(50) NOT NULL,
  status varchar(20) NOT NULL,
  CONSTRAINT chk_maintenance_status CHECK(
    status IN(
      'In_Progress','Completed','Cancelled'
    )
  ),
  start_date  DATE DEFAULT (CURRENT_DATE) NOT NULL ,
  cost NUMERIC(10,2) NOT NULL,
  CONSTRAINT chk_maintenance_cost CHECK (cost >= 0)
  
  );

SELECT ap.airplane_code, 
ap.model, 
COUNT(fl.flight_id) AS total_flights, 
COUNT(*) FILTER(WHERE fl.status ='Cancelled') AS cancelled_flights
FROM bookings.airplanes_data AS ap
INNER JOIN bookings.routes rt ON ap.airplane_code = rt.airplane_code
INNER JOIN bookings.flights fl ON rt.route_no = fl.route_no
GROUP BY ap.airplane_code, ap.model
HAVING COUNT(fl.flight_id) > 10000
ORDER BY cancelled_flights DESC


-- SELECT fl.status
-- FROM bookings.flights fl
-- WHERE fl.status = 'Cancelled'


INSERT INTO bookings.aircraft_maintenance (airplane_code,maintenance_type, status, start_date, cost)
VALUES ('32N', 'Turbine Overhall', 'In_Progress',CURRENT_DATE,15000),
       ('339', 'Avionics Check', 'Completed',CURRENT_DATE,4500)

-- SELECT ap.airplane_code, ap.model
-- FROM bookings.airplanes_data ap
-- LIMIT 100

SELECT airplane_code, maintenance_type, status, start_date, cost
FROM bookings.aircraft_maintenance as ac

-- TRUNCATE TABLE bookings.aircraft_maintenance;

UPDATE bookings.aircraft_maintenance am
SET cost = cost * 1.1
WHERE status = 'In_Progress'


DELETE FROM bookings.aircraft_maintenance am 
WHERE status = 'Cancelled'




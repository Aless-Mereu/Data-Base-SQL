-- 1. Creación de la Tabla de Recogida de Equipajes (Alias: bc)
CREATE TABLE bookings.baggage_claims (
claim_id serial PRIMARY KEY, -- Identificador único de reclamo de equipaje
flight_id integer NOT NULL REFERENCES bookings.flights(flight_id) ON UPDATE
CASCADE ON DELETE CASCADE,
carousel_no varchar(10) NOT NULL, -- Cinta asignada (ej: 'C1', 'C2')
status varchar(30) DEFAULT 'Scheduled'::character varying,
CONSTRAINT chk_claim_status CHECK (
status IN ('Scheduled', 'Arriving', 'Delivered', 'Completed')
)
);
-- 2. Creación de la Tabla de Puertas de Embarque (Alias: bg)
CREATE TABLE bookings.boarding_gates (
gate_no varchar(10) NOT NULL, -- Código de pta de embarque (ej: 'A12', 'B05')
airport_code bpchar(3) NOT NULL REFERENCES
bookings.airports_data(airport_code) ON UPDATE CASCADE ON DELETE CASCADE,
terminal varchar(10)NOT NULL, -- Terminal del aeropuerto (ej: 'T4', 'T1')
PRIMARY KEY (gate_no, airport_code) -- Clave primaria compuesta por puerta y aeropuerto
);
/*
Para simular una operación real dentro del esquema, poblaremos cada una de las
nuevas tablas con un conjunto de 5 registros válidos, respetando las claves
foráneas hacia los aeropuertos ('MAD', 'BCN', 'VLC', 'JFK', 'LHR') y los
identificadores de vuelos registrados en el sistema:
*/
-- Insertar registros en bookings.baggage_claims (Asumiendo IDs de vuelos existentes en flights)
INSERT INTO bookings.baggage_claims (flight_id, carousel_no, status) VALUES
(1234, 'C1', 'Scheduled'),
(5678, 'C2', 'Arriving'),
(9012, 'C3', 'Delivered'),
(3456, 'C1', 'Completed'),
(7890, 'C2', 'Scheduled');
-- Insertar registros en bookings.boarding_gates (Asumiendo códigos de aeropuertos válidos)
INSERT INTO bookings.boarding_gates (gate_no, airport_code, terminal) VALUES
('A12', 'MAD', 'T4'),
('B05', 'BCN', 'T1'),
('C02', 'VLC', 'T1'),
('A01', 'JFK', 'T4'),
('B10', 'LHR', 'T2');
-- Comprobamos la creación de la tabla bookings.baggage_claims
SELECT *
FROM bookings.baggage_claims;
-- Comprobamos la creación de la tabla bookings.boarding_gates
SELECT *
FROM bookings.boarding_gates;
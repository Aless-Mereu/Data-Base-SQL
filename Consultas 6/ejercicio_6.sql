
--FASE A
CREATE TYPE bookings.crew_role_type 
AS ENUM ('Captain','Fist Officer','Purser', 'Cabin Crew');

-- ALTER TYPE bookings.crew_role_type 
-- RENAME VALUE 'Fist Officer' TO 'First Officer';



-- FASE B
CREATE TABLE bookings.flight_crew (
    crew_id         VARCHAR PRIMARY KEY
                    CONSTRAINT check_crew_id_format 
                    CHECK (crew_id ~ '^[A-Z]{2} [0-9]{8}[A-Z]$'),
    crew_name       TEXT NOT NULL,
    role            bookings.crew_role_type NOT NULL,
    hire_date       DATE DEFAULT CURRENT_DATE --así separado, es muy pro xDD
);

INSERT INTO bookings.flight_crew (crew_id,crew_name,role,hire_date )
VALUES  ('XX 99999999X', 'Alfredo Landa','Captain',CURRENT_DATE),
        ('YY 99669999Y', 'Fernando Esteso','Purser', CURRENT_DATE),
        ('VV 99995949V', 'EL Pozi','Cabin Crew', CURRENT_DATE);

SELECT * FROM bookings.flight_crew;


-- FASE C
CREATE TABLE bookings.boarding_manifests (
    manifest_id   serial PRIMARY KEY,
    flight_id     integer NOT NULL
                  REFERENCES bookings.flights (flight_id)
                  ON UPDATE CASCADE
                  ON DELETE CASCADE,
    pdf_manifest  bytea NOT NULL,
    uploaded_at   timestamptz DEFAULT now()
);

-- FASE D
-- SELECT INTO
SELECT
    fl.flight_id,
    fl.route_no,
    fl.scheduled_departure,
    fl.status,
    NULL::TEXT AS crew_id   -- marcador de posicion
INTO bookings.flight_crew_assignments
FROM bookings.flights fl
WHERE fl.status IN ('Arrived', 'Departed');

--Insertar asignaciones reales: tomamos un vuelo de la propia tabla 
-- y le asignamos los tres tripulantesde la Fase anterior (CROSS JOIN = 3 filas)
INSERT INTO bookings.flight_crew_assignments
    (flight_id, route_no, scheduled_departure, status, crew_id)
SELECT fca.flight_id, 
fca.route_no, 
fca.scheduled_departure,
fca.status, 
fc.crew_id
FROM(SELECT *
    FROM bookings.flight_crew_assignments
    WHERE crew_id IS NULL
    ORDER BY flight_id
    LIMIT 1) fca
CROSS JOIN bookings.flight_crew fc;

--Eliminar las filas plantilla (crew_id NULL), que impedirían la PK
DELETE FROM bookings.flight_crew_assignments
WHERE crew_id IS NULL;

-- Restriccion de PK compuesta
ALTER TABLE bookings.flight_crew_assignments 
ADD PRIMARY KEY (flight_id, crew_id);


-- FK hacia los tripulantes
ALTER TABLE bookings.flight_crew_assignments
ADD FOREIGN KEY (crew_id) REFERENCES bookings.flight_crew (crew_id);

SELECT * FROM bookings.flight_crew_assignments;

-- DROP TABLE bookings.flight_crew_assignments;

-- FASE E
CREATE OR REPLACE VIEW bookings.vw_flight_crew_roster AS
SELECT
    fca.flight_id,
    fl.route_no,
    rt.departure_airport,
    rt.arrival_airport,
    rt.airplane_code,
    fl.scheduled_departure,
    fl.scheduled_arrival,
    fl.status,
    flcw.crew_id,
    flcw.crew_name,
    flcw.role AS cwrl
FROM bookings.flight_crew_assignments fca
INNER JOIN bookings.flights fl ON fl.flight_id = fca.flight_id
INNER JOIN bookings.routes rt ON rt.route_no = fl.route_no
AND fl.scheduled_departure <@ rt.validity -- evita duplicados
INNER JOIN bookings.flight_crew flcw 
ON flcw.crew_id = fca.crew_id;

SELECT * FROM bookings.vw_flight_crew_roster;


CREATE TABLE IF NOT EXISTS bookings.flight_metadata (
    flight_id integer PRIMARY KEY
              REFERENCES bookings.flights (flight_id)
              ON UPDATE CASCADE ON DELETE CASCADE,
    details   jsonb NOT NULL
);

-- Sustituyo los valores y añado a la tabla
INSERT INTO bookings.flight_metadata (flight_id, details)
VALUES (9999, '{"pilot": "Capt. Landa", "weather": {"temp": 18, "wind": 22}}')
ON CONFLICT (flight_id) DO NOTHING;

SELECT * FROM bookings.flight_metadata;

CREATE OR REPLACE PROCEDURE bookings.get_flight_crew_details (
    p_flight_id      integer,
    p_role           bookings.crew_role_type,
    INOUT p_crew_name     text    DEFAULT NULL,
    INOUT p_role_text     text    DEFAULT NULL,
    INOUT p_flight_status text    DEFAULT NULL,
    INOUT p_pilot_name    text    DEFAULT NULL,
    INOUT p_wind_speed    integer DEFAULT NULL 
) AS $$
DECLARE
    v_sqlstate text;
    v_message  text;
    v_detail   text;
    v_context  text;
BEGIN
    RAISE NOTICE 'Buscando tripulante % del vuelo %', p_role, p_flight_id;

    BEGIN
        SELECT vw.crew_name,
               vw.cwrl::text,                                   -- ENUM -> texto
               vw.status,
               fm.details->>'pilot',                            -- campo JSON simple
               (fm.details->'weather'->>'wind')::integer        -- campo JSON anidado con cast a integer
        INTO STRICT p_crew_name, p_role_text, p_flight_status, p_pilot_name, p_wind_speed
        FROM bookings.vw_flight_crew_roster vw
        LEFT JOIN bookings.flight_metadata fm ON fm.flight_id = vw.flight_id
        WHERE vw.flight_id = p_flight_id
          AND vw.cwrl = p_role;

        RAISE NOTICE 'Registro encontrado: % (%), vuelo %, piloto %, viento % nudos',
                     p_crew_name, p_role_text, p_flight_status, p_pilot_name, p_wind_speed;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE NOTICE 'No hay ningún % asignado al vuelo %', p_role, p_flight_id;
        WHEN TOO_MANY_ROWS THEN
            RAISE NOTICE 'Hay más de un % en el vuelo %', p_role, p_flight_id;
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS
                v_sqlstate = RETURNED_SQLSTATE,
                v_message  = MESSAGE_TEXT,
                v_detail   = PG_EXCEPTION_DETAIL,
                v_context  = PG_EXCEPTION_CONTEXT;
            RAISE WARNING 'Error [%]: % | Detalle: % | Contexto: %',
                          v_sqlstate, v_message, v_detail, v_context;
            ROLLBACK;   -- se permite: el bloque con EXCEPTION ya ha terminado su subtransacción
            RETURN;
    END;

    COMMIT;   -- fuera del bloque EXCEPTION, para evitar el error de la trampa 1
END;
$$ LANGUAGE plpgsql;


CALL bookings.get_flight_crew_details(9999, 'Captain', NULL, NULL, NULL, NULL, NULL);

CALL bookings.get_flight_crew_details(1, 'Captain', NULL, NULL, NULL, NULL, NULL);

--Procedimiento almacenado explicado en Ejercicios_desarrollados.md para estudio y consulta.

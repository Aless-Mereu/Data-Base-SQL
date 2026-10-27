-- View: bookings.airplanes

-- DROP VIEW bookings.airplanes;

CREATE OR REPLACE VIEW bookings.airplanes
 AS
 SELECT 	ml.airplane_code,
    		ml.model->> 'en' AS model,
    		ml.range,
    		ml.speed
  FROM 		bookings.airplanes_data ml;

ALTER TABLE bookings.airplanes
    OWNER TO postgres;
COMMENT ON VIEW bookings.airplanes
    IS 'Airplanes';

COMMENT ON COLUMN bookings.airplanes.airplane_code
    IS 'Airplane code, IATA';

COMMENT ON COLUMN bookings.airplanes.model
    IS 'Airplane model';

COMMENT ON COLUMN bookings.airplanes.range
    IS 'Maximum flight range, km';

COMMENT ON COLUMN bookings.airplanes.speed
    IS 'Cruise speed, km/h';


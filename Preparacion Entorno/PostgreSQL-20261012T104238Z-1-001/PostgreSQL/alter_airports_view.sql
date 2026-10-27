-- View: bookings.airports

-- DROP VIEW bookings.airports;

CREATE OR REPLACE VIEW bookings.airports
 AS
 SELECT airport_code,
    airport_name->> 'en' AS airport_name,
    city->>'en' AS city,
    --country ->> bookings.lang() AS country,
	country->>'en' AS country,
    coordinates,
    timezone
   FROM bookings.airports_data ml;

ALTER TABLE bookings.airports
    OWNER TO postgres;
COMMENT ON VIEW bookings.airports
    IS 'Airports';

COMMENT ON COLUMN bookings.airports.airport_code
    IS 'Airport code, IATA';

COMMENT ON COLUMN bookings.airports.airport_name
    IS 'Airport name';

COMMENT ON COLUMN bookings.airports.city
    IS 'City';

COMMENT ON COLUMN bookings.airports.country
    IS 'Country';

COMMENT ON COLUMN bookings.airports.coordinates
    IS 'Airport coordinates (longitude and latitude)';

COMMENT ON COLUMN bookings.airports.timezone
    IS 'Airport time zone';


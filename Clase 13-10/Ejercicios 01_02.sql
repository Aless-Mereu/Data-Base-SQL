/*Parte 1

Cuestión 1.1.
(Window function vs GROUP BY)
GROUP BY: define el orden secuencial en el que la función de ventana pocesa las filas de cada partición.
Es una ordenación puramente para el cálculo interno sin definir el orden final en el que se mostararán
los datos al usuario.
OVER (PARTITION BY) Indica al motor de base de datos como fragmentar y ordenar los datos para su
procesamiento, después divide las filas lógicas de la consulta en particiones que comparten
el mismo valor en la columna especificada. El cálculo de la función de ventana se ejecuta de forma
aislada para cada grupo y se reinicia acero al pasar a la siguiente partición.

Cuestión 1.2.
(Control transaccional en PL/pgSQL)
Pertenece a Consultas 5

*/
 -- Parte 2

-- Tarea 1: Ranking tarifario y Diferencial con Window Function

SELECT fl.flight_id,
    fl.route_no,
    sg.fare_conditions,
    sg.price,
    ROW_NUMBER() OVER(PARTITION BY fl.flight_id ORDER BY sg.price DESC) AS price_position,
    LAG(sg.price) OVER(PARTITION BY fl.flight_id ORDER BY sg.price DESC) AS prev_price,
    AVG(sg.price) OVER (PARTITION BY fl.flight_id ORDER BY sg.price DESC) AS avg_price

FROM bookings.flights fl
JOIN bookings.segments sg 
    ON fl.flight_id = sg.flight_id
JOIN bookings.tickets tf 
    ON tf.ticket_no = sg.ticket_no
WHERE fl.status = 'Arrived'
LIMIT 1000; 


-- Tarea 2: Funcion procedural PL/pgSQL para resumen de pasajeros

CREATE OR REPLACE FUNCTION bookings.get_passenger_stats(p_passenger_id varchar)
RETURNS TABLE(
    passenger_id varchar,
    total_vuelos integer,
    monto_total_gastado numeric,
    clase_preferida varchar
)
AS $$
BEGIN 
    RETURN QUERY
    SELECT p_passenger_id,
            COUNT(*)::integer,
            SUM(sg.price),
            (mode() WITHIN GROUP (ORDER BY sg.fare_conditions)) :: VARCHAR
    FROM bookings.segments AS sg
    INNER JOIN bookings.tickets AS tk ON sg.ticket_no = tk.ticket_no
    WHERE tk.passenger_id = p_passenger_id; 
END;
$$ LANGUAGE plpgsql;

/*
mode() WITHIN GROUP (...) devuelve el valor más frecuente, 
o sea la clase preferida, sin necesidad de GROUP BY ni LIMIT.
El DROP FUNCTION hace falta porque CREATE OR REPLACE no te deja 
cambiar el tipo de retorno de una función que ya existe.
*/


DROP FUNCTION IF EXISTS bookings.get_passenger_stats(varchar);
SELECT passenger_id FROM bookings.tickets LIMIT 5;

SELECT * FROM bookings.get_passenger_stats ('IT 2425980678984');
SELECT * FROM bookings.get_passenger_stats ('CL 7793846138778');
SELECT * FROM bookings.get_passenger_stats ('IN 6055838167316');

-- EJERCICIO 2
--Integrante A:
WITH datos_cuartiles AS (
    SELECT fl.flight_id,
           fl.scheduled_departure,
           sg.ticket_no,
           sg.price,
           sg.fare_conditions,
           NTILE(4) OVER (PARTITION BY fl.flight_id ORDER BY sg.price) AS cuartil_precio,
           SUM(sg.price) OVER (
               PARTITION BY fl.flight_id
               ORDER BY sg.ticket_no
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS ingresos_acumulados,
           SUM(sg.price) OVER (PARTITION BY fl.flight_id) AS ingresos_totales_vuelo
    FROM bookings.flights AS fl
    INNER JOIN bookings.segments AS sg ON fl.flight_id = sg.flight_id
)
SELECT flight_id,
       scheduled_departure,
       ticket_no,
       price,
       fare_conditions,
       cuartil_precio,
       ingresos_acumulados,
       ingresos_totales_vuelo
FROM datos_cuartiles
WHERE cuartil_precio = 1
  AND (
        scheduled_departure::date = CURRENT_DATE
        OR ingresos_totales_vuelo > 1000
        
      )
LIMIT 100;

-- Integrante B:
CREATE OR REPLACE FUNCTION bookings.fn_route_occupancy_stats
(
  p_route_no varchar
)
RETURNS TABLE (
  flight_id integer,
  scheduled_departure text,
  total_passengers bigint,
  route_avg_passengers numeric
) AS $$
BEGIN
RETURN QUERY
WITH flight_counts AS (
    SELECT  fl.flight_id,
            fl.scheduled_departure::text,
            COUNT(bp.seat_no) AS passengers
    FROM bookings.flights fl
      LEFT JOIN bookings.boarding_passes bp ON fl.flight_id = bp.flight_id
    WHERE fl.route_no = p_route_no
    GROUP BY fl.flight_id, fl.scheduled_departure
  )
  SELECT  fc.flight_id,
          fc.scheduled_departure,
          fc.passengers AS total_passengers,
          ROUND(AVG(fc.passengers) OVER (), 2) AS route_avg_passengers
  FROM flight_counts fc
  ORDER BY fc.scheduled_departure DESC;
END;
$$ LANGUAGE plpgsql;
-- Ejemplos de Invocación de Prueba:
SELECT * 
FROM  bookings.fn_route_occupancy_stats('PG0598');
SELECT * 
FROM  bookings.fn_route_occupancy_stats('PG0346');


-- Integrante C:
CREATE OR REPLACE PROCEDURE bookings.sp_audit_adjust_fare_rates(
    p_flight_id  INTEGER,
    p_min_amount NUMERIC
) AS $$
DECLARE
    r        RECORD;
    v_total  INTEGER := 0;
BEGIN
    FOR r IN
        SELECT sg.ticket_no, sg.fare_conditions, sg.price
        FROM bookings.segments AS sg
        WHERE sg.flight_id = p_flight_id
          AND sg.price < p_min_amount
    LOOP
        RAISE NOTICE 'Ticket % (%) - precio % < mínimo %',
                     r.ticket_no, r.fare_conditions, r.price, p_min_amount;
        v_total := v_total + 1;
    END LOOP;

    RAISE NOTICE 'Vuelo %: % segmentos por debajo de %', p_flight_id, v_total, p_min_amount;

    UPDATE bookings.segments
    SET price = p_min_amount
    WHERE flight_id = p_flight_id
      AND price < p_min_amount;

    COMMIT;  

END;
$$ LANGUAGE plpgsql;


CALL bookings.sp_audit_adjust_fare_rates(2, 10000);




















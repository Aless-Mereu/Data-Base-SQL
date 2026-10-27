-- 1. Creamos el procedimiento bookings.update_flight_segment_prices que recibe
-- como parámetros el flight_id del vuelo y un porcentaje de ajuste para
-- actualizar los precios de los segmentos de ese vuelo.
CREATE OR REPLACE PROCEDURE bookings.update_flight_segment_prices (
p_flight_id integer,
p_adjustment_percentage numeric,
p_fare_conditions text DEFAULT NULL
) AS $$
BEGIN
UPDATE bookings.segments sg
SET price = sg.price * (1 + p_adjustment_percentage / 100.0)
WHERE sg.flight_id = p_flight_id
AND (p_fare_conditions IS NULL OR sg.fare_conditions = p_fare_conditions);
COMMIT; --Confirmación física e independiente de la transacción
END;
$$ LANGUAGE plpgsql;

-- 2. Creamos el procedimiento bookings.archive_cancelled_flights que recibe
--como parámetros el route_no de la ruta y un cursor lógico para devolver los
--registros archivados.
CREATE OR REPLACE PROCEDURE bookings.archive_cancelled_flights (
p_route_no text,
p_result_cursor INOUT refcursor
) AS $$
DECLARE v_count integer;
BEGIN
RAISE NOTICE 'Iniciando proceso de archivo de vuelos cancelados para la ruta:
%', p_route_no;
-- Paso 1: Crear una tabla temporal para la auditoría si no existe
CREATE TEMPORARY TABLE IF NOT EXISTS temp_cancelled_archive (
flight_id integer,
route_no text,
status text,
archived_at timestamp DEFAULT CURRENT_TIMESTAMP
) ON COMMIT PRESERVE ROWS;
RAISE NOTICE 'Tabla temporal verificada/creada con éxito.';
-- Paso 2: Contar registros a procesar
SELECT COUNT(*)
INTO v_count
FROM bookings.flights fl
WHERE fl.route_no = p_route_no
AND fl.status = 'Cancelled';
RAISE NOTICE 'Se han encontrado % vuelos cancelados para procesar.', v_count;
IF v_count > 0 THEN
-- Paso 3: Insertar en la tabla histórica
INSERT INTO temp_cancelled_archive (flight_id, route_no, status)
SELECT fl.flight_id,
fl.route_no,
fl.status
FROM bookings.flights fl
WHERE fl.route_no = p_route_no
AND fl.status = 'Cancelled';
RAISE NOTICE 'Registros copiados exitosamente a la tabla de archivo.';
ELSE
RAISE NOTICE 'No se requirieron operaciones de inserción.';
END IF;
-- Paso 4: Abrir el cursor de salida para que el cliente SQL consuma la
--información
OPEN p_result_cursor FOR
SELECT *
FROM temp_cancelled_archive
WHERE route_no = p_route_no;
RAISE NOTICE 'Cursor de salida abierto de manera exitosa.';
END;
$$ LANGUAGE plpgsql;
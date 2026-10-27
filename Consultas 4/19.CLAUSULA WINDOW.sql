-- 1. Consulta original: vuelos programados y su diferencia con el vuelo
-- anterior de la misma ruta utilizando LAG() y OVER()
SELECT fl.flight_id,
fl.route_no,
fl.scheduled_departure,
-- Obtener la salida programada del vuelo anterior de la misma ruta
LAG(fl.scheduled_departure) OVER (
PARTITION BY fl.route_no
ORDER BY fl.scheduled_departure ASC
) AS salida_vuelo_anterior,
-- Calcular la diferencia temporal exacta
fl.scheduled_departure - LAG(fl.scheduled_departure) OVER (
PARTITION BY fl.route_no
ORDER BY fl.scheduled_departure ASC
) AS intervalo_con_anterior
FROM bookings.flights fl
ORDER BY fl.route_no,
fl.scheduled_departure;
-- 2. Consulta optimizada con ventanas reutilizables utilizando WINDOW
SELECT fl.flight_id,
fl.route_no,
fl.scheduled_departure,
LAG(fl.scheduled_departure) OVER w_ruta AS salida_anterior,
LEAD(fl.scheduled_departure) OVER w_ruta AS salida_siguiente
FROM bookings.flights fl
-- Declaración de ventana con nombre reutilizable
WINDOW w_ruta AS (PARTITION BY fl.route_no ORDER BY fl.scheduled_departure ASC)
ORDER BY fl.route_no,
fl.scheduled_departure;

SELECT sum(salary) OVER w, avg(salary) OVER w
FROM empsalary
WINDOW w AS (PARTITION BY depname ORDER BY salary DESC);

SELECT depname, empno, salary
FROM (
SELECT depname, empno, salary,
row_number() OVER (PARTITION BY depname ORDER BY salary DESC) AS pos
FROM empsalary
) AS ss
WHERE pos < 3; -- Filtro de ventana óptimo mediante subconsulta
---------------------------------------------------------------------------------------------

BEGIN;
SET LOCAL work_mem = '64MB';
-- Ejecuta tu query pesada aquí
COMMIT;

-- Por usuario
ALTER ROLE mi_usuario SET work_mem = '16MB';
-- Por Base de Datos
ALTER DATABASE mi_base_datos SET work_mem = '16MB';


-- 1. Aplicar el cambio global
ALTER SYSTEM SET work_mem = '16MB';
-- 2. Recargar la configuración para que tenga efecto (No interrumpe el servicio)
SELECT pg_reload_conf();
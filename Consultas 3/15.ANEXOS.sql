/*
Conceptos clave del comportamiento descrito que aplica a DELETE
Este comando se ejecuta registro por registro, procesando cada fila evaluando condiciones lógicas. Al realizar esta acción,
escribe un registro de cambio masivo en el disco. Esto lo hace en el volumen WAL (Write-Ahead Log). De esta forma, se
asegura la recuperación ante fallos.
Es por ello que, si el conjunto eliminado de datos es muy grande, puede ser necesario el uso de VACUUM, dado que esta opera‐
ción deja espacios vacíos ("tuplas muertas") que no liberan el espacio al sistema operativo de inmediato (en el volumen de
disco dónde se encuentre WAL), requiriendo limpieza posterior.
• */

-- Ejemplo 1: Añadir un comentario descriptivo a la tabla de boarding_gates
COMMENT ON TABLE bookings.boarding_gates
IS 'Tabla que registra las puertas de embarque físicas de cada aeropuerto.';
-- Verificamos que el comentario se ha añadido correctamente
SELECT obj_description('bookings.boarding_gates'::regclass);
-- Ejemplo 2: Añadir un comentario a una columna de la tabla baggage_claims
COMMENT ON COLUMN bookings.baggage_claims.carousel_no
IS 'Número de cinta transportadora asignada para la recogida de equipajes por
vuelo.';
-- Verificamos el comentario se ha añadido correctamente
SELECT col_description('bookings.baggage_claims'::regclass,
'carousel_no'::regclass);
-- Consultamos los comentarios de las tablas y columnas de la base de datos
SELECT *
FROM pg_description
WHERE objoid = 'bookings.boarding_gates'::regclass
OR objoid = 'bookings.baggage_claims'::regclass;
-- VACUUM con ANALYZE (Recomendado)
VACUUM ANALYZE nombre_tabla;
-- Opción agresiva (Recuperar espacio en disco)
VACUUM FULL nombre_tabla;

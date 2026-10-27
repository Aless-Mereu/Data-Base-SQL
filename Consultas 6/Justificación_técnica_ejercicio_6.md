## Justificación técnica

| Elemento de diseño | Propuesta técnica | Justificación relacional e impacto en rendimiento |
|---|---|---|
| `crew_role_type` | Tipo `ENUM` | Dominio cerrado validado por el propio tipo; 4 bytes por fila frente al texto completo; se reutiliza como tipo de parámetro en el procedimiento; el orden declarado refleja la jerarquía |
| `flight_crew.crew_id` | `varchar` PK + `CHECK` con regex `^[A-Z]{2} [0-9]{8}[A-Z]$` | La integridad del formato la garantiza el motor, no la aplicación: ningún cliente puede insertar IDs mal formados. Restricción con nombre para que el error sea legible |
| `flight_crew.hire_date` | `date DEFAULT CURRENT_DATE` | Evita `NULL` en altas rápidas; `date` ocupa 4 bytes, sin hora innecesaria |
| `boarding_manifests.pdf_manifest` | `BYTEA` | PDFs de KB/MB (< 1 GB). Comprimido y almacenado fuera de la fila por TOAST, así que no penaliza las consultas que no lo leen. El `ON DELETE CASCADE` borra el binario, sin huérfanos como con OID. Backups y permisos integrados en la tabla |
| `boarding_manifests.flight_id` | FK con `ON UPDATE` / `ON DELETE CASCADE` | No puede haber manifiestos de vuelos inexistentes; si se borra o renumera un vuelo, sus manifiestos lo siguen automáticamente |
| `flight_crew_assignments` | `SELECT INTO` + `ALTER TABLE ADD PRIMARY KEY (flight_id, crew_id)` + FK | Creación rápida clonando estructura; la PK compuesta impide duplicar a un tripulante en un vuelo e indexa las búsquedas por vuelo. Tabla puente correcta para una relación N:M en lugar de repetir columnas `crew1`, `crew2`... (desnormalizado) |
| `vw_flight_crew_roster` | `VIEW` normal con `INNER JOIN` y `scheduled_departure <@ validity` | Encapsula 4 tablas en un único objeto para operaciones. Siempre muestra datos actualizados (el estado del vuelo cambia). El filtro por rango de validez evita filas duplicadas y aviones incorrectos. Permite dar `GRANT` sobre la vista sin exponer las tablas |
| `get_flight_crew_details` | `PROCEDURE` PL/pgSQL con `INOUT`, `INTO STRICT`, `JSONB` y `GET STACKED DIAGNOSTICS` | Se ejecuta en el servidor (un solo viaje de red). Parámetro `ENUM` validado al llamar. `STRICT` detecta 0 o varias filas. Lee datos semiestructurados (`JSONB`) sin cambiar el esquema. Control transaccional explícito y errores diagnosticados con su `SQLSTATE` |
| `flight_metadata.details` | `JSONB` | Datos variables por vuelo (clima, incidencias) sin crear columnas que estarían casi siempre vacías. `JSONB` es binario, más rápido de consultar que `JSON` y admite índices GIN |

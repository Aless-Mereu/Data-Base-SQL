# Consultas 6 — Gestión de tripulación y manifiestos de vuelo

Manual de estudio y consulta del ejercicio de *Otras estructuras de datos* (PostgreSQL, base `demodb`, esquema `bookings`).

**Índice**

1. [Visión general](#1-visión-general)
2. [Fase A — Tipo ENUM](#2-fase-a--tipo-enum-personalizado)
3. [Fase B — Tabla de tripulantes](#3-fase-b--tabla-de-tripulantes-ddl)
4. [Fase C — Manifiestos en PDF (BLOB)](#4-fase-c--manifiestos-en-pdf-blob)
5. [Fase D — SELECT INTO y clave primaria](#5-fase-d--select-into-y-clave-primaria-compuesta)
6. [Fase E — Vista analítica](#6-fase-e--vista-analítica-vw_flight_crew_roster)
7. [Fase F — Procedimiento almacenado](#7-fase-f--procedimiento-almacenado-get_flight_crew_details)
8. [Justificación técnica (tabla para la entrega)](#8-justificación-técnica-tabla-para-la-entrega)
9. [Chuleta rápida](#9-chuleta-rápida)

---

## 1. Visión general

La aerolínea necesita registrar **qué tripulación va en cada vuelo** y **archivar el manifiesto de pasajeros en PDF**. Cada fase construye una pieza que usa la siguiente:

```
Fase A  crew_role_type (ENUM)
          │  lo usa la columna role
          ▼
Fase B  flight_crew ────────────────┐
                                    │ crew_id
Fase D  flight_crew_assignments ◄───┘   (SELECT INTO desde flights)
          │ flight_id
          ▼
Fase E  vw_flight_crew_roster  =  assignments ⋈ flights ⋈ routes ⋈ flight_crew
          │
          ▼
Fase F  get_flight_crew_details(vuelo, cargo)  =  vista ⋈ flight_metadata (JSONB)

Fase C  boarding_manifests (PDF)  ── FK ──► flights   (pieza independiente)
```

Reparto de la nota: Fase B (ENUM + regex) 2 pts · Fase C (justificación del PDF) 2 pts · Fase D 2 pts · vista 2 pts · procedimiento 2 pts.

> **Nota de control obligatoria del enunciado:** en la vista, `flight_crew` debe tener el alias `flcw` y la columna `role` debe salir con el alias `cwrl`.

---

## 2. Fase A — Tipo ENUM personalizado

```sql
CREATE TYPE bookings.crew_role_type
AS ENUM ('Captain', 'First Officer', 'Purser', 'Cabin Crew');
```

### Qué es un ENUM

Un tipo de dato propio con una **lista cerrada y ordenada** de valores. Cualquier otro valor da error al insertar:

```sql
INSERT INTO bookings.flight_crew (crew_id, crew_name, role)
VALUES ('AB 12345678C', 'Prueba', 'Pilot');
-- ERROR: invalid input value for enum bookings.crew_role_type: "Pilot"
```

### ENUM frente a otras opciones

| Opción | Ventaja | Inconveniente |
|---|---|---|
| `ENUM` | 4 bytes por fila; validación integrada en el tipo; se puede reutilizar en varias tablas y como tipo de parámetro (Fase F) | Para cambiar la lista hace falta `ALTER TYPE` |
| `text` + `CHECK (role IN (...))` | Fácil de modificar | Ocupa lo que mida el texto; el CHECK hay que repetirlo en cada tabla |
| Tabla de catálogo + FK | Muy flexible (puedes añadir descripción, sueldo...) | Exige un JOIN más |

### Operaciones útiles

```sql
-- Ver los valores del tipo
SELECT enum_range(NULL::bookings.crew_role_type);

-- Añadir un valor (al final o en una posición concreta)
ALTER TYPE bookings.crew_role_type ADD VALUE 'Flight Engineer' AFTER 'First Officer';

-- Renombrar un valor (PostgreSQL 10+)
ALTER TYPE bookings.crew_role_type RENAME VALUE 'Fist Officer' TO 'First Officer';
```

- Los valores **no se pueden borrar**. Para eso hay que crear un tipo nuevo y migrar la columna.
- El orden es el de la declaración, así que `'Captain' < 'Purser'` es verdadero y `ORDER BY role` ordena por jerarquía, no alfabéticamente.

> ⚠️ **En tu script**: escribiste `'Fist Officer'`. Corrígelo con el `RENAME VALUE` de arriba; si no, el valor del enunciado (`'First Officer'`) no será válido.

---

## 3. Fase B — Tabla de tripulantes (DDL)

```sql
CREATE TABLE bookings.flight_crew (
    crew_id    varchar PRIMARY KEY
               CONSTRAINT check_crew_id_format
               CHECK (crew_id ~ '^[A-Z]{2} [0-9]{8}[A-Z]$'),
    crew_name  text NOT NULL,
    role       bookings.crew_role_type NOT NULL,
    hire_date  date DEFAULT CURRENT_DATE
);

INSERT INTO bookings.flight_crew (crew_id, crew_name, role)
VALUES ('XX 99999999X', 'Alfredo Landa',   'Captain'),
       ('YY 99669999Y', 'Fernando Esteso', 'Purser'),
       ('VV 99995949V', 'EL Pozi',         'Cabin Crew');
```

Para tener un tripulante de cada cargo, puedes añadir también un `'First Officer'`.

### La expresión regular, pieza a pieza

| Fragmento | Significado |
|---|---|
| `^` | inicio del texto |
| `[A-Z]{2}` | dos letras mayúsculas |
| ` ` | un espacio literal |
| `[0-9]{8}` | ocho dígitos |
| `[A-Z]` | una letra mayúscula |
| `$` | fin del texto (sin `^` y `$`, `'xxAB 12345678Cyy'` también pasaría) |

### Operadores de expresión regular en PostgreSQL

| Operador | Significado |
|---|---|
| `~` | coincide, **distinguiendo** mayúsculas |
| `~*` | coincide, **sin distinguir** mayúsculas |
| `!~` / `!~*` | no coincide |

> ⚠️ **En tu script** usaste `~*`, que acepta `'xx 99999999x'` en minúsculas. Como el formato pide mayúsculas, es más estricto usar `~`.

### Prueba del CHECK

```sql
INSERT INTO bookings.flight_crew (crew_id, crew_name, role)
VALUES ('X 123', 'Mal formato', 'Captain');
-- ERROR: new row ... violates check constraint "check_crew_id_format"
```

Ponerle nombre a la restricción (`CONSTRAINT check_crew_id_format`) hace que el mensaje de error se entienda y permite borrarla con `ALTER TABLE ... DROP CONSTRAINT check_crew_id_format`.

---

## 4. Fase C — Manifiestos en PDF (BLOB)

El enunciado llama a la tabla **`bookings.boarding_manifests`** (en tu script se llama `manifests`; conviene usar el nombre exacto).

### Opción elegida: `BYTEA`

```sql
CREATE TABLE bookings.boarding_manifests (
    manifest_id   serial PRIMARY KEY,
    flight_id     integer NOT NULL
                  REFERENCES bookings.flights (flight_id)
                  ON UPDATE CASCADE
                  ON DELETE CASCADE,
    pdf_manifest  bytea NOT NULL,
    uploaded_at   timestamptz DEFAULT now()
);
```

### BYTEA frente a Large Objects (OID)

| Criterio | `BYTEA` | `OID` + `pg_largeobject` |
|---|---|---|
| Dónde se guarda | En la propia fila. Si pasa de unos 2 KB, se comprime y se mueve a TOAST automáticamente | En la tabla del sistema `pg_largeobject`, troceado en bloques de 2 KB; la fila solo guarda un número (OID) |
| Tamaño máximo | 1 GB por valor | 4 TB por objeto |
| Lectura | Se lee entero de una vez | Por streaming (`lo_open`, `lo_read`, `lo_lseek`) |
| Borrado | Al borrar la fila se borra el PDF | Al borrar la fila **el objeto queda huérfano**; hay que hacer `lo_unlink`, añadir un trigger `lo_manage` o pasar `vacuumlo` |
| `ON DELETE CASCADE` | Funciona: borrar el vuelo borra el PDF | Solo borra el OID; el binario sigue ocupando espacio |
| Permisos y backup | Los de la tabla; se incluye en `pg_dump` sin hacer nada | Permisos aparte por objeto; `pg_dump` necesita opciones (`--large-objects`) |

**Justificación:** un manifiesto de pasajeros pesa de KB a pocos MB, muy por debajo de 1 GB, y siempre se lee entero. `BYTEA` mantiene la integridad referencial completa: el `ON DELETE CASCADE` que pide el enunciado borra de verdad el PDF. Con OID quedarían objetos huérfanos. La compresión TOAST hace que el PDF no penalice a las consultas que no seleccionan esa columna.

### Cómo cargar un PDF

```sql
-- Desde el servidor (necesita superusuario o el rol pg_read_server_files;
-- la ruta es la del servidor de la base de datos, no la de tu PC)
INSERT INTO bookings.boarding_manifests (flight_id, pdf_manifest)
VALUES (1234, pg_read_binary_file('/ruta/boarding-pass-5437176449.pdf'));

-- Comprobar
SELECT manifest_id, flight_id, pg_size_pretty(length(pdf_manifest)::bigint) AS tamaño
FROM bookings.boarding_manifests;
```

En una aplicación real el PDF se envía desde el cliente (Python con `psycopg`, por ejemplo) como parámetro binario.

---

## 5. Fase D — SELECT INTO y clave primaria compuesta

### `SELECT INTO` en SQL ≠ `SELECT INTO` en PL/pgSQL

- **En SQL normal**, `SELECT ... INTO nueva_tabla` **crea una tabla nueva** con el resultado. Equivale a `CREATE TABLE nueva_tabla AS SELECT ...` (forma recomendada hoy).
- **Dentro de PL/pgSQL** (Fase F), `SELECT ... INTO variable` **guarda el resultado en variables**.

### Código en el orden correcto

```sql
-- 1) Crear la tabla clonando estructura y datos
SELECT fl.flight_id,
       fl.route_no,
       fl.scheduled_departure,
       fl.status,
       NULL::text AS crew_id          -- marcador de posición
INTO bookings.flight_crew_assignments
FROM bookings.flights fl
WHERE fl.status IN ('Arrived', 'Departed');

-- 2) Asignar los tripulantes a un vuelo (1 vuelo × 3 tripulantes = 3 filas)
INSERT INTO bookings.flight_crew_assignments
       (flight_id, route_no, scheduled_departure, status, crew_id)
SELECT fca.flight_id, fca.route_no, fca.scheduled_departure, fca.status, fc.crew_id
FROM (SELECT *
      FROM bookings.flight_crew_assignments
      WHERE crew_id IS NULL
      ORDER BY flight_id
      LIMIT 1) fca
CROSS JOIN bookings.flight_crew fc;

-- 3) Borrar las filas plantilla ANTES de la PK
DELETE FROM bookings.flight_crew_assignments
WHERE crew_id IS NULL;

-- 4) Clave primaria compuesta
ALTER TABLE bookings.flight_crew_assignments
ADD PRIMARY KEY (flight_id, crew_id);

-- 5) Clave foránea hacia los tripulantes
ALTER TABLE bookings.flight_crew_assignments
ADD FOREIGN KEY (crew_id) REFERENCES bookings.flight_crew (crew_id);
```

### Por qué es importante el orden

Una `PRIMARY KEY` exige `NOT NULL` en todas sus columnas. Mientras existan filas con `crew_id IS NULL`, el `ALTER TABLE ... ADD PRIMARY KEY` falla con *"column "crew_id" of relation ... contains null values"*.

> ⚠️ **En tu script** la PK va antes del `DELETE`. Si ejecutas el script de principio a fin fallará: cambia el orden como arriba.

### Por qué hace falta `NULL::text`

Un `NULL` a secas no tiene tipo, y PostgreSQL no sabría qué tipo dar a la columna nueva. El *cast* `::text` fija que `crew_id` sea `text`, compatible con el `varchar` de `flight_crew`.

### Qué **no** copia `SELECT INTO`

Copia **columnas y datos**, pero no copia PK, FK, índices, CHECK, DEFAULT ni NOT NULL. Por eso la PK y la FK se añaden después con `ALTER TABLE`.

### Por qué una PK compuesta `(flight_id, crew_id)`

Es una relación muchos a muchos (un vuelo tiene muchos tripulantes y un tripulante vuela muchos vuelos). La pareja impide asignar dos veces la misma persona al mismo vuelo. Además crea un índice que acelera las búsquedas por `flight_id`.

### `CROSS JOIN`

Producto cartesiano: cada fila de la izquierda con cada fila de la derecha. 1 vuelo × 3 tripulantes = 3 filas, justo el mínimo que pide el enunciado.

---

## 6. Fase E — Vista analítica `vw_flight_crew_roster`

### Teoría: qué es una vista

Una vista es una **consulta guardada con nombre**. No almacena datos: cada vez que haces `SELECT * FROM vista`, PostgreSQL sustituye el nombre por la consulta y la ejecuta sobre las tablas reales, así que siempre devuelve datos actuales.

**Para qué sirve:**

- **Encapsular** JOINs complejos: operaciones consulta `SELECT * FROM vw_...` sin conocer el modelo.
- **Seguridad**: se puede dar `GRANT SELECT` sobre la vista sin dar acceso a las tablas, y ocultar columnas sensibles.
- **Contrato estable**: si cambian las tablas, se ajusta la vista y los consumidores no notan nada.
- **Reutilización**: la Fase F la consulta directamente.

### Solución

```sql
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
    flcw.role AS cwrl                                    -- alias obligatorio
FROM bookings.flight_crew_assignments fca
INNER JOIN bookings.flights fl
        ON fl.flight_id = fca.flight_id
INNER JOIN bookings.routes rt
        ON rt.route_no = fl.route_no
       AND fl.scheduled_departure <@ rt.validity         -- evita duplicados
INNER JOIN bookings.flight_crew flcw                     -- alias obligatorio
        ON flcw.crew_id = fca.crew_id;

SELECT * FROM bookings.vw_flight_crew_roster;
```

### Explicación de cada JOIN

| JOIN | Qué aporta | Clave |
|---|---|---|
| `flight_crew_assignments fca` | Tabla de partida: qué tripulante va en qué vuelo | — |
| `flights fl` | Horarios y estado actual del vuelo | `flight_id` |
| `routes rt` | Aeropuertos de origen y destino y modelo de avión | `route_no` + rango de validez |
| `flight_crew flcw` | Nombre y cargo del tripulante | `crew_id` |

Se usa `INNER JOIN` porque solo interesan las asignaciones completas. Con `LEFT JOIN` saldrían filas de asignaciones sin tripulante o sin ruta.

### El operador `<@` y la validez de las rutas

En la versión actual de `demodb`, una misma `route_no` aparece varias veces en `routes`, una por cada periodo de vigencia (`validity` es de tipo `tstzrange`).

```
route_no  validity                     airplane_code
PG0001    [2025-01-01, 2025-04-01)     773
PG0001    [2025-04-01, 2025-08-01)     321
```

`valor <@ rango` significa "el valor **está contenido en** el rango". Así, un vuelo que sale el 2025-05-10 solo se une con la segunda fila.

- **Sin esta condición:** el vuelo sale duplicado, y una de las copias tiene un `airplane_code` incorrecto.
- **Con ella:** una fila por vuelo y tripulante, con la ruta que estaba vigente ese día.

Otros operadores de rango: `@>` (contiene), `&&` (se solapan), `lower(r)` / `upper(r)` (extremos).

### Reglas de `CREATE OR REPLACE VIEW` (preguntas típicas)

- Puedes **añadir columnas al final**.
- **No puedes** quitar columnas, cambiarles el nombre, cambiarles el tipo ni reordenarlas. Para eso: `DROP VIEW ... ; CREATE VIEW ...`.
- Si otra vista o un procedimiento depende de ella, `DROP VIEW` falla. `DROP VIEW ... CASCADE` borra también las dependientes (con cuidado).
- `SELECT *` dentro de una vista se expande **al crearla**: si después añades columnas a la tabla, la vista no las ve.

### Vista normal frente a vista materializada

| | `VIEW` | `MATERIALIZED VIEW` |
|---|---|---|
| Guarda datos | No, se ejecuta cada vez | Sí, guarda el resultado en disco |
| Datos actualizados | Siempre | Solo tras `REFRESH MATERIALIZED VIEW` |
| Velocidad | La de la consulta original | Muy rápida (lee una tabla ya calculada) |
| Admite índices | No | Sí |
| Uso típico | Simplificar y dar seguridad | Informes pesados, cuadros de mando |

```sql
CREATE MATERIALIZED VIEW bookings.mv_flight_crew_roster AS
SELECT * FROM bookings.vw_flight_crew_roster;

REFRESH MATERIALIZED VIEW bookings.mv_flight_crew_roster;
```

Para el roster de tripulación conviene una **vista normal**: el estado del vuelo cambia (`Scheduled` → `Departed` → `Arrived`) y operaciones necesita el dato real en todo momento.

### Vistas actualizables (para saber más)

Una vista **simple** (una sola tabla, sin `GROUP BY`, `DISTINCT`, agregados ni `UNION`) admite `INSERT`/`UPDATE`/`DELETE`, que PostgreSQL traslada a la tabla. `WITH CHECK OPTION` impide insertar a través de la vista filas que la vista no mostraría. La nuestra **no es actualizable** porque tiene JOINs. Para hacerla actualizable habría que usar triggers `INSTEAD OF`.

### Consultar la definición guardada

```sql
SELECT pg_get_viewdef('bookings.vw_flight_crew_roster', true);
-- o en psql:  \d+ bookings.vw_flight_crew_roster
```

---

## 7. Fase F — Procedimiento almacenado `get_flight_crew_details`

> El PDF repite por error el título "Fase E". Es la sexta fase; aquí la llamamos **F**.

### Qué pide

Recibir un vuelo (`p_flight_id integer`) y un cargo (`p_role crew_role_type`) y devolver **una fila** con:

| Dato | Origen |
|---|---|
| Nombre del tripulante | `flight_crew.crew_name` (en la vista: `crew_name`) |
| Cargo en texto | ENUM `role` (en la vista: `cwrl`) convertido con `::text` |
| Estado del vuelo | `flights.status` (en la vista: `status`) |
| Piloto asignado | JSONB: `flight_metadata.details->>'pilot'` |
| Velocidad del viento | JSONB anidado: `flight_metadata.details->'weather'->>'wind'` |

Además, con **control transaccional** (`COMMIT`/`ROLLBACK`) e **introspección de errores** (`GET STACKED DIAGNOSTICS`).

### Teoría: FUNCTION frente a PROCEDURE

| | `FUNCTION` | `PROCEDURE` (PostgreSQL 11+) |
|---|---|---|
| Cómo se invoca | Dentro de una consulta: `SELECT f(...)` | Con `CALL p(...)` |
| Devuelve | Un valor, una fila o una tabla (`RETURNS`) | Nada; los datos salen por parámetros `INOUT` / `OUT` o por un cursor |
| `COMMIT` / `ROLLBACK` dentro | **No** permitido | **Sí** permitido |
| Uso típico | Cálculos, transformar datos, usar en un `SELECT` | Procesos por lotes, ETL, operaciones con varias transacciones |

### Modos de los parámetros

| Modo | Entra | Sale | Notas |
|---|---|---|---|
| `IN` (por defecto) | ✔ | ✘ | Datos de entrada |
| `INOUT` | ✔ | ✔ | En un `CALL` hay que pasarle algo (normalmente `NULL`) |
| `OUT` | ✘ | ✔ | En procedimientos solo desde PostgreSQL 14 |

### Tabla de metadatos (de la lección anterior)

```sql
CREATE TABLE IF NOT EXISTS bookings.flight_metadata (
    flight_id integer PRIMARY KEY
              REFERENCES bookings.flights (flight_id)
              ON UPDATE CASCADE ON DELETE CASCADE,
    details   jsonb NOT NULL
);
```

En la lección solo se insertaron los vuelos 1234, 5678 y 9012. Tu vuelo con tripulación es probablemente otro, así que añádele metadatos:

```sql
-- Averiguar el vuelo con tripulación
SELECT DISTINCT flight_id FROM bookings.vw_flight_crew_roster;

-- Sustituye 9999 por ese flight_id
INSERT INTO bookings.flight_metadata (flight_id, details)
VALUES (9999, '{"pilot": "Capt. Landa", "weather": {"temp": 18, "wind": 22}}')
ON CONFLICT (flight_id) DO NOTHING;
```

### Repaso de operadores JSONB

| Operador | Devuelve | Ejemplo | Resultado |
|---|---|---|---|
| `->` | `jsonb` | `details->'weather'` | `{"temp": 18, "wind": 22}` |
| `->>` | `text` | `details->>'pilot'` | `Capt. Landa` |
| `#>` | `jsonb` por ruta | `details #> '{weather,wind}'` | `22` (jsonb) |
| `#>>` | `text` por ruta | `details #>> '{weather,wind}'` | `'22'` (texto) |
| `@>` | `boolean` | `details @> '{"pilot":"Capt. Landa"}'` | `true` (aprovecha índices GIN) |
| `?` | `boolean` | `details ? 'delay_reason'` | ¿existe la clave? |

Regla mnemotécnica: **una flecha `->` sigue navegando, dos flechas `->>` sacan el valor como texto**. Para operar con números: `(details->'weather'->>'wind')::integer`.

### Solución A (recomendada): parámetros `INOUT`

```sql
CREATE OR REPLACE PROCEDURE bookings.get_flight_crew_details (
    p_flight_id           integer,
    p_role                bookings.crew_role_type,
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

    BEGIN                                                    -- bloque protegido
        SELECT vw.crew_name,
               vw.cwrl::text,                                -- ENUM -> texto
               vw.status,
               fm.details->>'pilot',                         -- JSON simple
               (fm.details->'weather'->>'wind')::integer     -- JSON anidado
        INTO STRICT p_crew_name, p_role_text, p_flight_status,
                    p_pilot_name, p_wind_speed
        FROM bookings.vw_flight_crew_roster vw
        LEFT JOIN bookings.flight_metadata fm
               ON fm.flight_id = vw.flight_id
        WHERE vw.flight_id = p_flight_id
          AND vw.cwrl      = p_role;

        IF p_pilot_name IS NULL THEN
            RAISE NOTICE 'El vuelo % no tiene metadatos JSON', p_flight_id;
        END IF;

        RAISE NOTICE 'Encontrado: % (%) | vuelo % | piloto % | viento % nudos',
                     p_crew_name, p_role_text, p_flight_status,
                     p_pilot_name, p_wind_speed;

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
            ROLLBACK;
            RETURN;
    END;

    COMMIT;                          -- fuera del bloque con EXCEPTION
END;
$$ LANGUAGE plpgsql;
```

#### Explicación línea a línea

- **`p_role bookings.crew_role_type`**: como el parámetro es del tipo ENUM, PostgreSQL valida el cargo **antes** de entrar al procedimiento. `CALL ...(9999, 'Pilot', ...)` falla en la llamada.
- **`INOUT ... DEFAULT NULL`**: cada dato de salida es un parámetro. El `DEFAULT` permite omitirlos en algunas herramientas.
- **`DECLARE`**: variables locales para guardar la información del error.
- **`RAISE NOTICE`**: mensajes informativos (pestaña *Mensajes/Output* del cliente). Cada `%` se sustituye por el siguiente argumento.
- **Bloque interno `BEGIN ... EXCEPTION ... END`**: PostgreSQL crea un *savepoint* implícito al entrar. Si algo falla, deshace lo hecho **dentro** de ese bloque y salta al `EXCEPTION`.
- **`INTO STRICT`**: exige exactamente **una** fila:
  - 0 filas → `NO_DATA_FOUND`
  - más de 1 → `TOO_MANY_ROWS`
  - Sin `STRICT`, con 0 filas las variables quedarían `NULL` sin avisar, y con varias se tomaría la primera.
- **`LEFT JOIN flight_metadata`**: si el vuelo no tiene JSON, el tripulante se devuelve igualmente, con piloto y viento a `NULL`.
- **`WHEN OTHERS`** + **`GET STACKED DIAGNOSTICS`**: captura cualquier otro error (por ejemplo, que el `wind` no sea numérico y falle el `::integer`) y extrae sus detalles.
- **`ROLLBACK` en el handler**: cuando se ejecuta el handler, PostgreSQL ya ha deshecho el savepoint del bloque, así que se permite terminar la transacción.
- **`COMMIT` al final**: va **fuera** del bloque con `EXCEPTION`, porque dentro daría error (ver trampas).

#### Llamada y pruebas

```sql
-- Caso correcto: los INOUT se pasan como NULL
CALL bookings.get_flight_crew_details(9999, 'Captain', NULL, NULL, NULL, NULL, NULL);
--  p_crew_name   | p_role_text | p_flight_status | p_pilot_name | p_wind_speed
--  Alfredo Landa | Captain     | Arrived         | Capt. Landa  | 22

-- Otro cargo
CALL bookings.get_flight_crew_details(9999, 'Purser', NULL, NULL, NULL, NULL, NULL);

-- NO_DATA_FOUND: vuelo sin tripulación
CALL bookings.get_flight_crew_details(1, 'Captain', NULL, NULL, NULL, NULL, NULL);

-- Error de tipo ENUM (antes de entrar al procedimiento)
CALL bookings.get_flight_crew_details(9999, 'Pilot', NULL, NULL, NULL, NULL, NULL);

-- WHEN OTHERS: forzar un viento no numérico
UPDATE bookings.flight_metadata
SET details = jsonb_set(details, '{weather,wind}', '"fuerte"')
WHERE flight_id = 9999;
CALL bookings.get_flight_crew_details(9999, 'Captain', NULL, NULL, NULL, NULL, NULL);
-- WARNING: Error [22P02]: invalid input syntax for type integer: "fuerte" ...
```

> Ejecuta el `CALL` **en modo autocommit**, sin `BEGIN;` delante, como hacen por defecto DBeaver y pgAdmin. Dentro de una transacción explícita, el `COMMIT` interno da *"invalid transaction termination"*.

### Solución B: cursor de salida (`INOUT refcursor`)

Es el mismo patrón que `archive_cancelled_flights` de *Consultas 5*. Devuelve un conjunto de resultados en lugar de variables sueltas.

```sql
CREATE OR REPLACE PROCEDURE bookings.get_flight_crew_details_cur (
    p_flight_id integer,
    p_role      bookings.crew_role_type,
    INOUT p_result_cursor refcursor DEFAULT 'crew_cursor'
) AS $$
DECLARE
    v_sqlstate text;
    v_message  text;
BEGIN
    OPEN p_result_cursor FOR
        SELECT vw.crew_name,
               vw.cwrl::text                              AS role_text,
               vw.status,
               fm.details->>'pilot'                       AS pilot_name,
               (fm.details->'weather'->>'wind')::integer  AS wind_speed
        FROM bookings.vw_flight_crew_roster vw
        LEFT JOIN bookings.flight_metadata fm ON fm.flight_id = vw.flight_id
        WHERE vw.flight_id = p_flight_id
          AND vw.cwrl      = p_role;

    RAISE NOTICE 'Cursor % abierto', p_result_cursor;
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_sqlstate = RETURNED_SQLSTATE,
                                v_message  = MESSAGE_TEXT;
        RAISE EXCEPTION 'Error [%] al abrir el cursor: %', v_sqlstate, v_message;
END;
$$ LANGUAGE plpgsql;
```

Cómo se usa (los tres pasos **en la misma transacción**):

```sql
BEGIN;
CALL bookings.get_flight_crew_details_cur(9999, 'Captain', 'crew_cursor');
FETCH ALL IN crew_cursor;
COMMIT;
```

El cursor solo vive mientras dura la transacción, por eso esta versión **no puede hacer `COMMIT` dentro**: cerraría el cursor antes de que el cliente lo lea. Aquí el control transaccional lo lleva quien llama (`BEGIN ... COMMIT`), y el procedimiento relanza el error con `RAISE EXCEPTION` para que la transacción completa se aborte.

### ¿INOUT o cursor?

| | INOUT | refcursor |
|---|---|---|
| Resultado | Una fila (variables sueltas) | Cualquier número de filas |
| Llamada | Un simple `CALL` | `BEGIN; CALL; FETCH; COMMIT;` |
| `COMMIT` interno | Sí | No |
| Encaja con el enunciado ("un registro detallado") | ✔ Mejor | ✔ Válido |

### Trampas de control transaccional en PL/pgSQL

1. **`COMMIT` dentro de un bloque con `EXCEPTION`** → *"cannot commit while a subtransaction is active"*. Ese bloque es un savepoint, y no se puede cerrar la transacción con un savepoint abierto. Pon el `COMMIT` fuera.
2. **`CALL` dentro de `BEGIN;` explícito** → el `COMMIT` interno da *"invalid transaction termination"*.
3. **Procedimiento llamado desde una función o desde un `SELECT`** → tampoco puede hacer `COMMIT`.
4. **Cursores y `COMMIT`**: un `COMMIT` cierra los cursores normales abiertos.
5. Tras un `COMMIT` o `ROLLBACK` dentro del procedimiento, PostgreSQL **abre automáticamente una transacción nueva** para el resto del código.

### Introspección de errores: referencia

```sql
-- Dentro de EXCEPTION (información del error capturado)
GET STACKED DIAGNOSTICS
    v1 = RETURNED_SQLSTATE,      -- código de 5 caracteres, ej. 23505
    v2 = MESSAGE_TEXT,           -- mensaje principal
    v3 = PG_EXCEPTION_DETAIL,    -- detalle (si lo hay)
    v4 = PG_EXCEPTION_HINT,      -- sugerencia
    v5 = PG_EXCEPTION_CONTEXT,   -- pila de llamadas: en qué línea falló
    v6 = CONSTRAINT_NAME,        -- restricción violada
    v7 = TABLE_NAME,
    v8 = COLUMN_NAME;

-- Fuera de EXCEPTION (información de la última sentencia)
GET DIAGNOSTICS v_filas = ROW_COUNT;   -- filas afectadas por el último UPDATE/INSERT/DELETE
```

Además, dentro de un handler existen las variables `SQLSTATE` y `SQLERRM` (atajo para código y mensaje).

**Errores con nombre más habituales**

| Nombre | SQLSTATE | Cuándo |
|---|---|---|
| `no_data_found` | P0002 | `INTO STRICT` sin filas |
| `too_many_rows` | P0003 | `INTO STRICT` con varias filas |
| `unique_violation` | 23505 | PK o UNIQUE duplicado |
| `foreign_key_violation` | 23503 | FK inexistente |
| `check_violation` | 23514 | Falla un CHECK (ej. regex de `crew_id`) |
| `not_null_violation` | 23502 | NULL en columna NOT NULL |
| `invalid_text_representation` | 22P02 | Cast imposible (`'abc'::integer`, valor de ENUM inválido) |
| `division_by_zero` | 22012 | División entre 0 |

**Niveles de `RAISE`**

| Nivel | Efecto |
|---|---|
| `DEBUG`, `LOG` | Solo en el log del servidor (según configuración) |
| `INFO`, `NOTICE` | Mensaje al cliente; la ejecución sigue |
| `WARNING` | Aviso destacado; la ejecución sigue |
| `EXCEPTION` | **Lanza un error**: aborta y deshace la transacción si nadie lo captura |

```sql
RAISE EXCEPTION 'Vuelo % no encontrado', p_flight_id
      USING ERRCODE = 'P0002', HINT = 'Revisa flight_crew_assignments';
```

### Consultar y borrar el procedimiento

```sql
-- Ver su código
SELECT pg_get_functiondef('bookings.get_flight_crew_details'::regproc);

-- Borrarlo (hay que indicar los tipos si hay sobrecargas)
DROP PROCEDURE bookings.get_flight_crew_details(integer, bookings.crew_role_type,
                                                text, text, text, text, integer);
```

---

## 8. Justificación técnica (tabla para la entrega)

| Elemento de diseño | Propuesta técnica | Justificación relacional e impacto en rendimiento |
|---|---|---|
| `crew_role_type` | Tipo `ENUM` | Dominio cerrado validado por el propio tipo; 4 bytes por fila frente al texto completo; se reutiliza como tipo de parámetro en el procedimiento; el orden declarado refleja la jerarquía |
| `flight_crew.crew_id` | `varchar` PK + `CHECK` con regex `^[A-Z]{2} [0-9]{8}[A-Z]$` | La integridad del formato la garantiza el motor, no la aplicación: ningún cliente puede insertar IDs mal formados. Restricción con nombre para que el error sea legible |
| `flight_crew.hire_date` | `date DEFAULT CURRENT_DATE` | Evita NULL en altas rápidas; `date` ocupa 4 bytes, sin hora innecesaria |
| `boarding_manifests.pdf_manifest` | `BYTEA` | PDFs de KB/MB (< 1 GB). Comprimido y almacenado fuera de la fila por TOAST, así que no penaliza las consultas que no lo leen. El `ON DELETE CASCADE` borra el binario, sin huérfanos como con OID. Backups y permisos integrados en la tabla |
| `boarding_manifests.flight_id` | FK con `ON UPDATE / ON DELETE CASCADE` | No puede haber manifiestos de vuelos inexistentes; si se borra o renumera un vuelo, sus manifiestos lo siguen automáticamente |
| `flight_crew_assignments` | `SELECT INTO` + `ALTER TABLE ADD PRIMARY KEY (flight_id, crew_id)` + FK | Creación rápida clonando estructura; la PK compuesta impide duplicar a un tripulante en un vuelo e indexa las búsquedas por vuelo. Tabla puente correcta para una relación N:M en lugar de repetir columnas `crew1`, `crew2`... (desnormalizado) |
| `vw_flight_crew_roster` | `VIEW` normal con `INNER JOIN` y `scheduled_departure <@ validity` | Encapsula 4 tablas en un único objeto para operaciones. Siempre muestra datos actualizados (el estado del vuelo cambia). El filtro por rango de validez evita filas duplicadas y aviones incorrectos. Permite dar `GRANT` sobre la vista sin exponer las tablas |
| `get_flight_crew_details` | `PROCEDURE` PL/pgSQL con `INOUT`, `INTO STRICT`, JSONB y `GET STACKED DIAGNOSTICS` | Se ejecuta en el servidor (un solo viaje de red). Parámetro ENUM validado al llamar. `STRICT` detecta 0 o varias filas. Lee datos semiestructurados (JSONB) sin cambiar el esquema. Control transaccional explícito y errores diagnosticados con su SQLSTATE |
| `flight_metadata.details` | `JSONB` | Datos variables por vuelo (clima, incidencias) sin crear columnas que estarían casi siempre vacías. `JSONB` es binario, más rápido de consultar que `JSON` y admite índices GIN |

---

## 9. Chuleta rápida

```sql
-- ENUM
CREATE TYPE esquema.tipo AS ENUM ('a', 'b');
ALTER TYPE esquema.tipo ADD VALUE 'c';
ALTER TYPE esquema.tipo RENAME VALUE 'a' TO 'A';

-- CHECK con regex
CONSTRAINT nombre CHECK (col ~ '^patrón$')

-- Crear tabla desde consulta
SELECT ... INTO nueva_tabla FROM ...;          -- o CREATE TABLE nueva AS SELECT ...
ALTER TABLE t ADD PRIMARY KEY (c1, c2);
ALTER TABLE t ADD FOREIGN KEY (c) REFERENCES otra (c);

-- Vistas
CREATE OR REPLACE VIEW v AS SELECT ...;
CREATE MATERIALIZED VIEW mv AS SELECT ...;
REFRESH MATERIALIZED VIEW mv;
DROP VIEW v [CASCADE];

-- JSONB
col->'clave'                  -- jsonb
col->>'clave'                 -- text
col->'a'->>'b'                -- anidado a texto
(col->>'n')::integer          -- a número
col @> '{"k":"v"}'            -- contiene

-- Procedimiento
CREATE OR REPLACE PROCEDURE p(a int, INOUT r text DEFAULT NULL) AS $$
DECLARE ...
BEGIN
    BEGIN
        SELECT ... INTO STRICT r ...;
    EXCEPTION
        WHEN no_data_found THEN ...
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v = MESSAGE_TEXT;
            RAISE WARNING '%', v;
    END;
    COMMIT;
END;
$$ LANGUAGE plpgsql;

CALL p(1, NULL);
```

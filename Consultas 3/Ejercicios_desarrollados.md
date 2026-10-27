# Consultas 3 — Operaciones DDL: CREATE, ALTER, TRUNCATE, DROP y COMMENT

Manual de estudio y consulta de *Operaciones DDL* (PostgreSQL, base `demodb`, esquema `bookings`). Este tema no tiene enunciado de ejercicio: se desarrollan y corrigen los ejemplos del curso (`10.CREATE TABLE.sql` … `15.ANEXOS.sql`).

**Índice**

1. [Visión general](#1-visión-general)
2. [CREATE TABLE y restricciones](#2-create-table-y-restricciones)
3. [CREATE VIEW](#3-create-view)
4. [ALTER TABLE](#4-alter-table)
5. [TRUNCATE y DROP](#5-truncate-y-drop)
6. [COMMENT y el catálogo](#6-comment-y-el-catálogo)
7. [Anexo: DELETE, WAL y VACUUM](#7-anexo-delete-wal-y-vacuum)
8. [Resumen técnico (tabla)](#8-resumen-técnico-tabla)
9. [Chuleta rápida](#9-chuleta-rápida)

---

## 1. Visión general

| Lenguaje | Para qué | Sentencias |
|---|---|---|
| **DDL** (*Data Definition Language*) | Definir la **estructura** | `CREATE`, `ALTER`, `DROP`, `TRUNCATE`, `COMMENT` |
| **DML** (*Data Manipulation Language*) | Manipular los **datos** | `SELECT`, `INSERT`, `UPDATE`, `DELETE` |

Los ejemplos del curso amplían `demodb` con dos tablas y tres vistas:

```
flights (flight_id) ──< baggage_claims (claim_id)          ── vw_active_claims
airports_data (airport_code) ──< boarding_gates (gate_no, airport_code) ── vw_airport_gates
flights ⋈ routes                                           ── vw_flight_schedules
```

> En PostgreSQL **el DDL es transaccional**: un `CREATE TABLE`, `ALTER TABLE` o `DROP TABLE` dentro de `BEGIN; ... ROLLBACK;` se deshace por completo. Muchos otros motores (MySQL, Oracle) confirman el DDL automáticamente.

---

## 2. CREATE TABLE y restricciones

```sql
CREATE TABLE bookings.baggage_claims (
    claim_id    serial PRIMARY KEY,
    flight_id   integer NOT NULL
                REFERENCES bookings.flights (flight_id)
                ON UPDATE CASCADE ON DELETE CASCADE,
    carousel_no varchar(10) NOT NULL,
    status      varchar(30) DEFAULT 'Scheduled',
    CONSTRAINT chk_claim_status
        CHECK (status IN ('Scheduled', 'Arriving', 'Delivered', 'Completed'))
);

CREATE TABLE bookings.boarding_gates (
    gate_no      varchar(10) NOT NULL,
    airport_code bpchar(3)   NOT NULL
                 REFERENCES bookings.airports_data (airport_code)
                 ON UPDATE CASCADE ON DELETE CASCADE,
    terminal     varchar(10) NOT NULL,
    PRIMARY KEY (gate_no, airport_code)          -- PK compuesta
);
```

### Restricciones (constraints)

| Restricción | Qué garantiza | Detalle |
|---|---|---|
| `NOT NULL` | La columna siempre tiene valor | |
| `UNIQUE` | No hay valores repetidos | Crea un índice; admite varios `NULL` |
| `PRIMARY KEY` | Identificador único y no nulo | = `UNIQUE` + `NOT NULL`; crea un índice B-Tree; solo una por tabla |
| `CHECK (condición)` | La condición se cumple en cada fila | Si da `NULL`, **pasa** (no la rechaza) |
| `FOREIGN KEY` / `REFERENCES` | El valor existe en la tabla padre | Reglas `ON UPDATE` / `ON DELETE` (ver Consultas 2); **no** crea índice en la hija |
| `DEFAULT valor` | Valor si no se indica | No es una restricción, pero se define igual |

### Restricción de columna frente a restricción de tabla

- **De columna**: va junto a la columna (`claim_id serial PRIMARY KEY`).
- **De tabla**: va al final y puede afectar a varias columnas (`PRIMARY KEY (gate_no, airport_code)`). Es la única forma de hacer una PK o FK compuesta.
- **Con nombre** (`CONSTRAINT chk_claim_status CHECK ...`): el mensaje de error es legible y se puede borrar con `ALTER TABLE ... DROP CONSTRAINT chk_claim_status`. Sin nombre, PostgreSQL inventa uno (`baggage_claims_status_check`).

### PK compuesta en `boarding_gates`

La puerta `'A12'` puede existir en Madrid y en Barcelona. Lo que es único es la **pareja** (puerta, aeropuerto). Por eso la PK es `(gate_no, airport_code)`.

### `serial` frente a `IDENTITY`

```sql
claim_id serial PRIMARY KEY                                  -- forma clásica de PostgreSQL
claim_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY    -- estándar SQL, recomendada hoy
```

Ambas crean una secuencia que numera las filas. `IDENTITY` es estándar, la secuencia pertenece a la columna, y con `ALWAYS` impide insertar IDs a mano por error.

### Tipos que aparecen

| Tipo | Uso |
|---|---|
| `integer`, `bigint` | Enteros (4 y 8 bytes) |
| `numeric(p,s)` | Decimal exacto (dinero) |
| `varchar(n)` / `text` | Texto con o sin límite (en PostgreSQL rinden igual) |
| `bpchar(n)` = `char(n)` | Texto de longitud fija, rellena con espacios (códigos IATA de 3 letras) |
| `date`, `timestamp`, `timestamptz` | Fecha; fecha y hora; fecha y hora con zona horaria |
| `boolean` | `true` / `false` |

> ⚠️ **En el script del curso**: los `INSERT` de `baggage_claims` dan por hecho que existen los vuelos 1234, 5678, 9012, 3456 y 7890. Si alguno no existe, la FK rechaza toda la sentencia. Compruébalo antes con `SELECT flight_id FROM bookings.flights WHERE flight_id IN (...)`.

---

## 3. CREATE VIEW

Una vista es una **consulta guardada con nombre**. No almacena datos: al consultarla, PostgreSQL ejecuta la consulta sobre las tablas reales.

```sql
CREATE VIEW bookings.vw_active_claims AS
SELECT bc.claim_id, bc.carousel_no, fl.flight_id, fl.route_no, bc.status
FROM bookings.baggage_claims bc
INNER JOIN bookings.flights fl ON bc.flight_id = fl.flight_id
WHERE bc.status <> 'Completed';

SELECT v_ac.* FROM bookings.vw_active_claims v_ac;
```

| Uso | Ejemplo |
|---|---|
| **Simplificar** consultas complejas | Los analistas consultan `vw_active_claims` sin conocer los JOIN |
| **Seguridad** | `GRANT SELECT` sobre la vista, no sobre las tablas; se ocultan columnas sensibles |
| **Contrato estable** | Si cambian las tablas, se redefine la vista y las aplicaciones no se enteran |

### Reglas de `CREATE OR REPLACE VIEW`

- Puedes **añadir columnas al final**.
- **No** puedes quitar, renombrar, reordenar ni cambiar el tipo de columnas: hay que hacer `DROP VIEW` y `CREATE VIEW`.
- `SELECT *` dentro de una vista se expande **al crearla**: las columnas que se añadan después a la tabla no aparecen.
- Una vista con un solo `FROM`, sin `GROUP BY`, `DISTINCT` ni agregados es **actualizable** (admite `INSERT`/`UPDATE`/`DELETE`). Con JOIN, no.

Vistas materializadas (`MATERIALIZED VIEW`, guardan el resultado y se refrescan con `REFRESH`): ver Consultas 6.

> ⚠️ **En el script del curso**:
> - `vw_flight_schedules` y `vw_active_claims` unen `flights` con `routes` solo por `route_no`. En la versión actual de `demodb` una ruta tiene varias filas (una por periodo de `validity`), así que **cada vuelo sale repetido**. Hay que añadir `AND fl.scheduled_departure <@ rt.validity` (explicado en Consultas 6).
> - En `vw_active_claims` el JOIN con `routes` no aporta nada: `route_no` ya está en `flights`. Basta con `fl.route_no` (es lo que se muestra arriba).

---

## 4. ALTER TABLE

Modifica una tabla existente **sin perder sus datos**.

| Operación | Ejemplo |
|---|---|
| Añadir columna | `ALTER TABLE t ADD COLUMN last_updated timestamp DEFAULT CURRENT_TIMESTAMP;` |
| Borrar columna | `ALTER TABLE t DROP COLUMN last_updated;` |
| Cambiar tipo | `ALTER TABLE t ALTER COLUMN gate_no TYPE varchar(20);` |
| Cambiar tipo con conversión | `ALTER TABLE t ALTER COLUMN x TYPE integer USING x::integer;` |
| Poner o quitar `NOT NULL` | `ALTER TABLE t ALTER COLUMN x SET NOT NULL;` / `DROP NOT NULL` |
| Poner o quitar `DEFAULT` | `ALTER TABLE t ALTER COLUMN x SET DEFAULT 0;` / `DROP DEFAULT` |
| Añadir restricción | `ALTER TABLE t ADD CONSTRAINT chk CHECK (terminal <> '');` |
| Borrar restricción | `ALTER TABLE t DROP CONSTRAINT chk;` |
| Añadir PK / FK tardía | `ALTER TABLE t ADD PRIMARY KEY (a, b);` / `ADD FOREIGN KEY (c) REFERENCES p (c);` |
| Renombrar | `ALTER TABLE t RENAME TO t2;` / `RENAME COLUMN a TO b;` |

### Ejemplo del curso: CHECK que valida datos existentes

```sql
-- Antes de la restricción se puede insertar una terminal vacía
INSERT INTO bookings.boarding_gates (gate_no, airport_code, terminal) VALUES ('C03', 'MAD', '');

-- Hay que limpiar antes de añadirla: el ADD CONSTRAINT revisa las filas existentes
DELETE FROM bookings.boarding_gates WHERE terminal = '';

ALTER TABLE bookings.boarding_gates
ADD CONSTRAINT chk_terminal_not_empty CHECK (terminal <> '');

-- Ahora el mismo INSERT falla
-- ERROR: new row ... violates check constraint "chk_terminal_not_empty"
```

Si quedara alguna fila que no cumple, el `ADD CONSTRAINT` fallaría. Para tablas enormes existe `ADD CONSTRAINT ... NOT VALID` (solo valida las filas nuevas) y después `VALIDATE CONSTRAINT`.

### Coste de un ALTER

- `ADD COLUMN` con un `DEFAULT` constante es instantáneo (PostgreSQL 11+): no reescribe la tabla.
- `ALTER COLUMN ... TYPE` suele **reescribir la tabla entera** y la bloquea mientras tanto.

> ⚠️ **En el PDF del curso**: en la tabla de usos de `ALTER TABLE`, la descripción de `DROP COLUMN` está copiada de `UNIQUE`. `DROP COLUMN` elimina una columna y sus datos.

---

## 5. TRUNCATE y DROP

```sql
CREATE TEMPORARY TABLE temp_flights_summary AS
SELECT fl.flight_id, fl.route_no, fl.status, fl.scheduled_departure
FROM bookings.flights fl
WHERE fl.status IN ('Delayed', 'Cancelled');

TRUNCATE TABLE temp_flights_summary;     -- vacía: la tabla sigue existiendo
SELECT COUNT(*) FROM temp_flights_summary;   -- 0

DROP TABLE temp_flights_summary;         -- elimina la tabla
SELECT * FROM temp_flights_summary;      -- ERROR: relation does not exist
```

### DELETE frente a TRUNCATE frente a DROP

| | `DELETE FROM t` | `TRUNCATE t` | `DROP TABLE t` |
|---|---|---|---|
| Qué elimina | Filas (con `WHERE`, solo algunas) | Todas las filas | Filas **y** estructura, índices, restricciones, triggers |
| Cómo | Fila a fila, deja tuplas muertas | Libera los ficheros de datos de golpe | Borra el objeto del catálogo |
| Espacio en disco | Hasta `VACUUM` | Inmediato | Inmediato |
| Triggers `ON DELETE` | Se disparan | No | No |
| Bloqueo | De fila | `ACCESS EXCLUSIVE` (nadie puede ni leer) | `ACCESS EXCLUSIVE` |
| `ROLLBACK` | Sí | Sí (en PostgreSQL) | Sí (en PostgreSQL) |
| Si hay FK que apuntan a la tabla | Comprueba fila a fila | Error, salvo `TRUNCATE ... CASCADE` | Error, salvo `DROP ... CASCADE` |

Opciones útiles:

```sql
TRUNCATE t RESTART IDENTITY;        -- reinicia también los serial/identity
TRUNCATE t CASCADE;                 -- vacía también las tablas que la referencian (¡cuidado!)
DROP TABLE IF EXISTS t;             -- no da error si no existe
DROP TABLE t CASCADE;               -- borra también las vistas y FK que dependen de ella
```

> ⚠️ **En el PDF del curso**, en el apartado de `DROP TABLE`, la frase "DROP evalúa y borra registro por registro... requiriendo un VACUUM posterior" describe en realidad a **`DELETE`** (ver el anexo). `DROP` y `TRUNCATE` no recorren las filas.

### Tablas temporales

- `CREATE TEMPORARY TABLE` (o `TEMP`): solo la ve la sesión que la crea y se borra al desconectar.
- `ON COMMIT DROP` / `DELETE ROWS` / `PRESERVE ROWS` decide qué pasa al terminar cada transacción (ver Consultas 5).

---

## 6. COMMENT y el catálogo

Guarda documentación **dentro** de la base de datos (tabla del sistema `pg_description`), visible desde DBeaver, pgAdmin, `\d+` de psql o herramientas de catálogo de datos.

```sql
COMMENT ON TABLE bookings.boarding_gates
IS 'Puertas de embarque físicas de cada aeropuerto.';

COMMENT ON COLUMN bookings.baggage_claims.carousel_no
IS 'Cinta transportadora asignada para recoger el equipaje del vuelo.';

-- Leer
SELECT obj_description('bookings.boarding_gates'::regclass, 'pg_class');

SELECT col_description('bookings.baggage_claims'::regclass,
                       (SELECT attnum
                        FROM pg_attribute
                        WHERE attrelid = 'bookings.baggage_claims'::regclass
                          AND attname  = 'carousel_no'));

-- Borrar un comentario
COMMENT ON TABLE bookings.boarding_gates IS NULL;
```

- `::regclass` convierte un nombre de tabla en su identificador interno (OID).
- `col_description` necesita el **número** de la columna (`attnum`), no su nombre.

> ⚠️ **En el script del curso** (`14.COMMENT.sql` y `15.ANEXOS.sql`): `col_description('bookings.baggage_claims'::regclass, 'carousel_no'::regclass)` da error, porque intenta convertir el nombre de la columna en una tabla. Usa la versión con `pg_attribute` de arriba.

Se puede comentar casi cualquier objeto: `COMMENT ON VIEW`, `ON FUNCTION`, `ON SCHEMA`, `ON CONSTRAINT ... ON tabla`, `ON TYPE`.

---

## 7. Anexo: DELETE, WAL y VACUUM

- **WAL** (*Write-Ahead Log*): antes de modificar los ficheros de datos, PostgreSQL escribe el cambio en un registro secuencial. Si el servidor cae, al arrancar repite el WAL y no se pierde nada confirmado (la **D** de ACID).
- **MVCC**: un `DELETE` o un `UPDATE` no borran la fila en el momento. La marcan como muerta (*tupla muerta*) porque otras transacciones aún podrían estar leyéndola.
- **VACUUM** recorre la tabla y deja ese espacio libre para reutilizarlo. El *autovacuum* lo hace solo en segundo plano.

| Comando | Qué hace | Bloqueo |
|---|---|---|
| `VACUUM t` | Marca el espacio de tuplas muertas como reutilizable (no lo devuelve al sistema operativo) | Ligero: la tabla sigue usable |
| `VACUUM ANALYZE t` | Lo anterior + actualiza estadísticas para el planificador | Ligero (**recomendado**) |
| `ANALYZE t` | Solo estadísticas | Ligero |
| `VACUUM FULL t` | Reescribe la tabla compactada y devuelve el espacio al sistema operativo | `ACCESS EXCLUSIVE`: la tabla queda bloqueada |

Por eso, para vaciar una tabla entera, `TRUNCATE` es mucho mejor que `DELETE` sin `WHERE`.

---

## 8. Resumen técnico (tabla)

| Elemento de diseño | Propuesta técnica | Justificación relacional e impacto en rendimiento |
|---|---|---|
| `baggage_claims.claim_id` | `serial PRIMARY KEY` (mejor `IDENTITY`) | Clave sustituta autonumérica; índice B-Tree automático |
| `baggage_claims.flight_id` | FK `ON UPDATE CASCADE ON DELETE CASCADE` | No hay reclamaciones de vuelos inexistentes; si se borra el vuelo, se borran sus reclamaciones |
| `baggage_claims.status` | `CHECK (status IN (...))` con nombre + `DEFAULT 'Scheduled'` | Dominio cerrado validado por el motor; error legible y borrable por nombre |
| `boarding_gates` | PK compuesta `(gate_no, airport_code)` | La misma puerta puede existir en varios aeropuertos; lo único es la pareja |
| `boarding_gates.airport_code` | `bpchar(3)` + FK a `airports_data` | Código IATA de longitud fija; FK a la tabla real (no a la vista `airports`) |
| Vistas `vw_*` | `CREATE VIEW` con `INNER JOIN` | Encapsulan los JOIN, permiten `GRANT` sin exponer tablas; siempre muestran datos actuales |
| Unión con `routes` | Añadir `scheduled_departure <@ validity` | Evita filas duplicadas por los distintos periodos de vigencia de una ruta |
| `last_updated` | `ALTER TABLE ADD COLUMN ... DEFAULT CURRENT_TIMESTAMP` | Columna de auditoría sin reconstruir la tabla; instantáneo con default constante |
| `chk_terminal_not_empty` | `ALTER TABLE ADD CONSTRAINT ... CHECK (terminal <> '')` | `NOT NULL` no impide la cadena vacía; el `CHECK` sí |
| Tablas de trabajo | `CREATE TEMP TABLE`, `TRUNCATE`, `DROP` | Vaciado inmediato sin tuplas muertas; las temporales no ensucian el esquema |
| Documentación | `COMMENT ON TABLE / COLUMN` | El diccionario de datos vive en el catálogo y lo leen las herramientas automáticamente |

---

## 9. Chuleta rápida

```sql
-- Crear
CREATE TABLE esquema.t (
    id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    padre integer NOT NULL REFERENCES esquema.p (id) ON UPDATE CASCADE ON DELETE CASCADE,
    cod   varchar(10) NOT NULL UNIQUE,
    est   text DEFAULT 'A',
    CONSTRAINT chk_est CHECK (est IN ('A', 'B'))
);
CREATE TABLE t2 (a int, b int, PRIMARY KEY (a, b));          -- PK compuesta
CREATE TEMP TABLE tmp AS SELECT ... ;                         -- temporal desde consulta

-- Vistas
CREATE [OR REPLACE] VIEW v AS SELECT ... ;
DROP VIEW [IF EXISTS] v [CASCADE];

-- Modificar
ALTER TABLE t ADD COLUMN c timestamp DEFAULT now();
ALTER TABLE t DROP COLUMN c;
ALTER TABLE t ALTER COLUMN c TYPE bigint [USING c::bigint];
ALTER TABLE t ALTER COLUMN c SET NOT NULL;
ALTER TABLE t ADD CONSTRAINT n CHECK (...);
ALTER TABLE t DROP CONSTRAINT n;
ALTER TABLE t RENAME COLUMN a TO b;
ALTER TABLE t RENAME TO t_nueva;

-- Vaciar y borrar
TRUNCATE t [RESTART IDENTITY] [CASCADE];
DROP TABLE [IF EXISTS] t [CASCADE];

-- Documentar
COMMENT ON TABLE t IS '...';
COMMENT ON COLUMN t.c IS '...';
SELECT obj_description('t'::regclass, 'pg_class');

-- Mantenimiento
VACUUM ANALYZE t;
VACUUM FULL t;        -- bloquea la tabla
```

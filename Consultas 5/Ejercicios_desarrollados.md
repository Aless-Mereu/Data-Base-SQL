# Consultas 5 — Transacciones, funciones y procedimientos almacenados

Manual de estudio y consulta de *Funciones y Procedimientos Almacenados* (PostgreSQL, base `demodb`, esquema `bookings`). Este tema no tiene enunciado de ejercicio: se desarrollan y corrigen los ejemplos del curso (`20.TRANSACCIONES.sql` … `23.CALL.sql`). Es la base directa de la Fase F de Consultas 6.

**Índice**

1. [Visión general](#1-visión-general)
2. [Transacciones: BEGIN, COMMIT y ROLLBACK](#2-transacciones-begin-commit-y-rollback)
3. [SAVEPOINT](#3-savepoint)
4. [Funciones (CREATE FUNCTION)](#4-funciones-create-function)
5. [Procedimientos (CREATE PROCEDURE)](#5-procedimientos-create-procedure)
6. [CALL y cursores de salida](#6-call-y-cursores-de-salida)
7. [Anexo: planes preparados y caché](#7-anexo-planes-preparados-y-caché)
8. [Resumen técnico (tabla)](#8-resumen-técnico-tabla)
9. [Chuleta rápida](#9-chuleta-rápida)

---

## 1. Visión general

```
Transacción  = unidad de trabajo "todo o nada"          BEGIN ... COMMIT | ROLLBACK
   └─ SAVEPOINT = punto intermedio al que volver         ROLLBACK TO SAVEPOINT x

FUNCTION     = devuelve un valor o una tabla            SELECT f(...)       sin COMMIT dentro
PROCEDURE    = ejecuta un proceso                        CALL p(...)         con COMMIT dentro
```

---

## 2. Transacciones: BEGIN, COMMIT y ROLLBACK

> "El punto esencial de una transacción es que agrupa múltiples pasos en una operación de todo o nada. Los estados intermedios entre los pasos no son visibles para otras transacciones concurrentes." — Documentación de PostgreSQL

| Sentencia | Sinónimo | Efecto |
|---|---|---|
| `BEGIN` | `START TRANSACTION` | Abre la transacción |
| `COMMIT` | `END` | Confirma: los cambios son permanentes y visibles para todos (Durabilidad) |
| `ROLLBACK` | `ABORT` | Descarta todo lo hecho desde el `BEGIN` |

### Autocommit

Sin `BEGIN`, cada sentencia es su propia transacción y se confirma sola (modo *autocommit*, el de DBeaver y pgAdmin por defecto). Con `BEGIN`, nada es definitivo hasta el `COMMIT`.

### Transacción de varias tablas

```sql
BEGIN;
INSERT INTO bookings.bookings (book_ref, book_date, total_amount)
VALUES ('TX999A', CURRENT_TIMESTAMP, 15000.00);

INSERT INTO bookings.tickets (ticket_no, book_ref, passenger_id, passenger_name, outbound)
VALUES ('9999999999999', 'TX999A', 'ES 4383871116867', 'Alberto Gomez', true);
COMMIT;
```

La reserva y su billete se guardan juntos o no se guarda ninguno: nunca queda una reserva sin billete por un fallo a mitad.

### Lo que hay que saber

- **Aislamiento**: hasta el `COMMIT`, otra sesión **no** ve los cambios (prueba: abre dos pestañas SQL en DBeaver, cada una es una sesión).
- **Error dentro de una transacción**: PostgreSQL la marca como abortada. Cualquier sentencia siguiente da *"current transaction is aborted, commands ignored until end of transaction block"* hasta que hagas `ROLLBACK` (o `ROLLBACK TO SAVEPOINT`).
- **El DDL también es transaccional**: un `CREATE TABLE` dentro del `BEGIN` desaparece con el `ROLLBACK`.
- **Ejecución por pasos**: para ver el efecto, ejecuta `BEGIN`, luego las sentencias una a una y por último `COMMIT` o `ROLLBACK`. En DBeaver, cambia antes a modo de transacción manual o ejecuta sentencia a sentencia (Ctrl+Enter).
- Las transacciones largas mantienen bloqueos de fila y retrasan a otras sesiones: hay que cerrarlas cuanto antes.

---

## 3. SAVEPOINT

Un punto de guardado **dentro** de una transacción, al que se puede volver sin perder lo anterior.

| Sentencia | Efecto |
|---|---|
| `SAVEPOINT nombre` | Marca el punto |
| `ROLLBACK TO SAVEPOINT nombre` | **Deshace** lo hecho **después** del punto. La transacción sigue abierta y el savepoint sigue existiendo |
| `RELEASE SAVEPOINT nombre` | **Elimina** el punto y **conserva** los cambios (no confirma nada: eso solo lo hace el `COMMIT` final) |

> ⚠️ **En el PDF del curso** las dos definiciones están cruzadas: dice que `ROLLBACK TO SAVEPOINT` "confirma" y que `RELEASE SAVEPOINT` "anula". Es al revés, como en la tabla de arriba.

### Ejemplo del curso, paso a paso

```sql
BEGIN;
CREATE TABLE bookings.tickets_it_temp AS SELECT ... ;            -- (1) tabla de trabajo

UPDATE bookings.tickets_it_temp
SET airplane_code = '77W'
WHERE airplane_code = '351';                                     -- (2) antes del savepoint

SAVEPOINT it_temp_savepoint;                                     -- (3)

UPDATE bookings.tickets_it_temp
SET fare_conditions = 'Business'
WHERE fare_conditions = 'Comfort';                               -- (4) después del savepoint

ROLLBACK TO SAVEPOINT it_temp_savepoint;                         -- deshace solo (4)
COMMIT;                                                          -- confirma (1) y (2)
```

Al final, la tabla existe, el cambio de avión **se conserva** (paso 2, anterior al savepoint) y el cambio de clase **se ha deshecho** (paso 4).

> ⚠️ **En el script del curso** (`20.TRANSACCIONES.sql`):
> - El comentario del paso 2 dice cambiar '77W' a '351', pero el `UPDATE` hace lo contrario (`SET '77W' WHERE '351'`).
> - El comentario del apartado 3 habla de insertar en `bookings` y `tickets` y hacer `ROLLBACK`, pero el código crea una tabla y termina con `COMMIT`.
> - `tickets_it_temp` es una tabla **permanente** en `bookings` (pese al nombre). Bórrala al terminar: `DROP TABLE bookings.tickets_it_temp;`.
> - El `JOIN` con `routes` se hace solo por `route_no` (sin `validity`), así que puede duplicar filas; el `DISTINCT` del `SELECT` lo disimula.

---

## 4. Funciones (CREATE FUNCTION)

Bloque reutilizable que **siempre devuelve algo** y se usa dentro de una consulta. Se ejecuta en la transacción de quien la llama, así que **no puede hacer `COMMIT` ni `ROLLBACK`**.

### Función en lenguaje SQL que devuelve un valor

```sql
CREATE OR REPLACE FUNCTION bookings.get_formatted_amount (p_book_ref varchar(6))
RETURNS text
AS $$
    SELECT TO_CHAR(bk.total_amount, 'FM999G999G990D00')
    FROM bookings.bookings bk
    WHERE bk.book_ref = p_book_ref;
$$ LANGUAGE sql;

SELECT bookings.get_formatted_amount('13NH0K');
```

- `$$ ... $$`: delimita el cuerpo sin tener que escapar comillas.
- `FM` quita espacios de relleno; `G` y `D` son los separadores de miles y decimales según la configuración regional. `L` (en el script del curso) añade el símbolo de moneda de `lc_monetary`.
- Si el `book_ref` no existe, devuelve `NULL`.

### Función PL/pgSQL que devuelve una tabla

```sql
CREATE OR REPLACE FUNCTION bookings.get_passenger_flight_history (p_passenger_id text)
RETURNS TABLE (
    ticket_no      text,
    passenger_name text,
    flight_id      integer,
    route_no       text,
    status         text,
    segment_price  numeric(10,2)
)
AS $$
BEGIN
    RETURN QUERY
    SELECT tk.ticket_no, tk.passenger_name, fl.flight_id, fl.route_no, fl.status, sg.price
    FROM bookings.tickets tk
    INNER JOIN bookings.segments sg ON tk.ticket_no = sg.ticket_no
    INNER JOIN bookings.flights  fl ON sg.flight_id = fl.flight_id
    WHERE tk.passenger_id = p_passenger_id;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM bookings.get_passenger_flight_history('US 2779671121032');
```

Puntos clave:
- `RETURNS TABLE (...)` + `RETURN QUERY`: la función se usa en el `FROM` como si fuera una tabla.
- Los nombres de `RETURNS TABLE` se convierten en **variables** dentro del cuerpo. Por eso hay que cualificar las columnas (`tk.ticket_no`); sin alias da *"column reference "ticket_no" is ambiguous"*.
- Los tipos de las columnas devueltas deben **coincidir exactamente** con los declarados. Si no, *"structure of query does not match function result type"*; se arregla con un cast (`fl.status::text`).
- Prefijo `p_` en parámetros y `v_` en variables: evita choques de nombre con las columnas.

### SQL frente a PL/pgSQL

| | `LANGUAGE sql` | `LANGUAGE plpgsql` |
|---|---|---|
| Contenido | Una o varias sentencias SQL | Variables, `IF`, bucles, excepciones, `RAISE` |
| Rendimiento | Las funciones simples se integran (*inline*) en la consulta que las llama | Se ejecutan como bloque aparte |
| Cuándo | Consultas o cálculos directos | Lógica con pasos, decisiones o control de errores |

### Volatilidad (para saber más)

| Categoría | Significa | Ejemplo |
|---|---|---|
| `IMMUTABLE` | Mismo resultado para los mismos argumentos, siempre | Cálculos puros |
| `STABLE` | Mismo resultado dentro de una consulta; lee tablas pero no las modifica | Funciones de consulta como las de arriba |
| `VOLATILE` (por defecto) | Puede cambiar en cada llamada o modificar datos | `random()`, funciones con `INSERT` |

Declarar `STABLE` o `IMMUTABLE` cuando corresponde ayuda al planificador.

---

## 5. Procedimientos (CREATE PROCEDURE)

Desde PostgreSQL 11. Se invocan con `CALL` y **pueden controlar la transacción** (`COMMIT`/`ROLLBACK` dentro). Pensados para procesos por lotes, ETL y mantenimiento.

### FUNCTION frente a PROCEDURE

| | `FUNCTION` | `PROCEDURE` |
|---|---|---|
| Invocación | Dentro de una sentencia: `SELECT f(...)` | Sola: `CALL p(...)` |
| Devuelve | Obligatorio (`RETURNS`): escalar, fila o tabla | Nada; los datos salen por parámetros `INOUT`/`OUT` o un cursor |
| `COMMIT` / `ROLLBACK` dentro | No | Sí |
| Uso típico | Cálculos, formateo, consultas reutilizables | Lotes, ETL, mantenimiento, operaciones con varias transacciones |

### Procedimiento con COMMIT

```sql
CREATE OR REPLACE PROCEDURE bookings.update_flight_segment_prices (
    p_flight_id             integer,
    p_adjustment_percentage numeric,
    p_fare_conditions       text DEFAULT NULL
) AS $$
BEGIN
    UPDATE bookings.segments sg
    SET price = ROUND(sg.price * (1 + p_adjustment_percentage / 100.0), 2)
    WHERE sg.flight_id = p_flight_id
      AND (p_fare_conditions IS NULL OR sg.fare_conditions = p_fare_conditions);

    COMMIT;
END;
$$ LANGUAGE plpgsql;
```

- `DEFAULT NULL` + `(p IS NULL OR col = p)`: **parámetro opcional**. Sin clase, se ajustan todas.
- `/ 100.0` (con decimal) evita la división entera.
- `ROUND(..., 2)` mantiene el precio con dos decimales.

Para contar filas afectadas, lo correcto en PL/pgSQL es `GET DIAGNOSTICS`:

```sql
DECLARE v_filas integer;
BEGIN
    UPDATE ... ;
    GET DIAGNOSTICS v_filas = ROW_COUNT;
    RAISE NOTICE '% tramos actualizados', v_filas;
```

### Reglas del COMMIT dentro de un procedimiento

1. Solo funciona si el `CALL` se ejecuta **fuera** de una transacción explícita (autocommit). Dentro de `BEGIN; CALL ...;` da *"invalid transaction termination"*.
2. No puede ir dentro de un bloque `BEGIN ... EXCEPTION ... END` (ver Consultas 6).
3. Tras un `COMMIT` dentro del procedimiento, PostgreSQL abre automáticamente una transacción nueva para el resto del código.
4. Un procedimiento llamado desde una función tampoco puede hacer `COMMIT`.

### Bloque PL/pgSQL: estructura

```sql
CREATE OR REPLACE PROCEDURE esquema.nombre (parámetros) AS $$
DECLARE
    v_count integer;                -- variables locales
BEGIN
    SELECT COUNT(*) INTO v_count FROM ... ;          -- guardar resultado en variable
    RAISE NOTICE 'Encontrados: %', v_count;          -- mensaje (cada % = un argumento)
    IF v_count > 0 THEN
        ...
    ELSE
        ...
    END IF;
END;
$$ LANGUAGE plpgsql;
```

Errores y excepciones (`EXCEPTION`, `GET STACKED DIAGNOSTICS`, `INTO STRICT`): ver Consultas 6, Fase F.

---

## 6. CALL y cursores de salida

```sql
-- Procedimiento con COMMIT: en autocommit, sin BEGIN
CALL bookings.update_flight_segment_prices(12345, -10.00, 'Economy');
CALL bookings.update_flight_segment_prices(12345, 5.00);              -- todas las clases
CALL bookings.update_flight_segment_prices(p_flight_id => 12345,
                                           p_adjustment_percentage => 5); -- por nombre
```

`CALL` no puede ir dentro de un `SELECT`: es una sentencia independiente.

### Devolver un conjunto de filas: INOUT refcursor

```sql
CREATE OR REPLACE PROCEDURE bookings.archive_cancelled_flights (
    p_route_no            text,
    INOUT p_result_cursor refcursor
) AS $$
DECLARE
    v_count integer;
BEGIN
    CREATE TEMPORARY TABLE IF NOT EXISTS temp_cancelled_archive (
        flight_id   integer,
        route_no    text,
        status      text,
        archived_at timestamp DEFAULT CURRENT_TIMESTAMP
    ) ON COMMIT PRESERVE ROWS;

    SELECT COUNT(*) INTO v_count
    FROM bookings.flights fl
    WHERE fl.route_no = p_route_no AND fl.status = 'Cancelled';

    IF v_count > 0 THEN
        INSERT INTO temp_cancelled_archive (flight_id, route_no, status)
        SELECT fl.flight_id, fl.route_no, fl.status
        FROM bookings.flights fl
        WHERE fl.route_no = p_route_no AND fl.status = 'Cancelled';
    END IF;

    OPEN p_result_cursor FOR
        SELECT * FROM temp_cancelled_archive WHERE route_no = p_route_no;
END;
$$ LANGUAGE plpgsql;
```

Uso (los tres pasos **en la misma transacción**, porque el cursor muere con ella):

```sql
BEGIN;
CALL bookings.archive_cancelled_flights('PG0805', 'mi_cursor');
FETCH ALL FROM mi_cursor;
COMMIT;
```

- Un **cursor** es un puntero a un resultado que el cliente lee por partes (`FETCH 10`, `FETCH ALL`).
- El segundo argumento (`'mi_cursor'`) es el **nombre** que tendrá el cursor; con él se hace el `FETCH`.
- Por eso este procedimiento **no** lleva `COMMIT` dentro: cerraría el cursor antes de leerlo.

### Opciones ON COMMIT de una tabla temporal

| Opción | Al terminar cada transacción |
|---|---|
| `PRESERVE ROWS` (por defecto) | Se conservan las filas hasta el fin de la sesión |
| `DELETE ROWS` | Se vacía |
| `DROP` | Se elimina la tabla |

> ⚠️ **En el script del curso**:
> - `archive_cancelled_flights`: como la tabla temporal es `PRESERVE ROWS`, si llamas dos veces al procedimiento con la misma ruta en la misma sesión, **las filas se duplican**. Se evita borrando antes las de esa ruta (`DELETE FROM temp_cancelled_archive WHERE route_no = p_route_no;`) o con `ON COMMIT DROP`.
> - `23.CALL.sql`: el comentario dice validar el vuelo 1001, pero la consulta usa 12345. Además, cada `CALL` con -10 % **modifica de verdad** los precios de `demodb`: si lo repites, se van acumulando. Ejecuta antes un `SELECT` para guardar los precios o deshazlo con el porcentaje inverso.

### Ver y borrar funciones y procedimientos

```sql
SELECT pg_get_functiondef('bookings.archive_cancelled_flights'::regproc);   -- código
-- en psql:  \df bookings.*

DROP FUNCTION  bookings.get_formatted_amount(varchar);
DROP PROCEDURE bookings.update_flight_segment_prices(integer, numeric, text);
```

Si hay varias versiones con el mismo nombre (sobrecarga), hay que indicar los tipos de los parámetros.

---

## 7. Anexo: planes preparados y caché

Cuando un procedimiento o función PL/pgSQL se ejecuta por primera vez en una sesión, PostgreSQL **prepara** cada sentencia interna y se ahorra en las siguientes llamadas:

1. **Parsing**: análisis de la sintaxis.
2. **Analyzing**: comprobación de tablas y columnas.
3. **Planning**: elección del plan de ejecución (índices, tipo de JOIN…).

| Ejecución | Plan |
|---|---|
| Primeras 5 | **Específico** para los valores concretos de los parámetros |
| A partir de la 6.ª | Compara con un **plan genérico** (válido para cualquier valor); si no es peor, lo cachea |

- La caché es **por sesión** (en SQL Server es global). Por eso conviene un *pool* de conexiones (PgBouncer o el del framework): mantiene las sesiones vivas y aprovecha los planes cacheados.
- El plan genérico puede ser malo si los datos están muy desequilibrados (una ruta con 10 vuelos y otra con 100 000). Se controla con `SET plan_cache_mode = force_custom_plan`.

---

## 8. Resumen técnico (tabla)

| Elemento de diseño | Propuesta técnica | Justificación relacional e impacto en rendimiento |
|---|---|---|
| Alta de reserva + billete | `BEGIN; INSERT ...; INSERT ...; COMMIT;` | Atomicidad: nunca queda una reserva sin billete; otras sesiones no ven estados intermedios |
| Cambios de prueba | `SAVEPOINT` + `ROLLBACK TO SAVEPOINT` | Deshace solo la parte posterior al punto sin perder el resto de la transacción |
| `get_formatted_amount` | `FUNCTION ... LANGUAGE sql RETURNS text` | Lógica de formato reutilizable dentro de cualquier `SELECT`; las funciones SQL simples se integran en el plan |
| `get_passenger_flight_history` | `FUNCTION ... RETURNS TABLE` + `RETURN QUERY` | Se consulta en el `FROM` como una tabla parametrizada; columnas cualificadas para evitar ambigüedad |
| `update_flight_segment_prices` | `PROCEDURE` con parámetro opcional y `COMMIT` | Proceso de escritura invocado con `CALL`; confirma su propio trabajo; `DEFAULT NULL` evita duplicar código para "todas las clases" |
| `archive_cancelled_flights` | `PROCEDURE` con `INOUT refcursor` y tabla temporal | Devuelve un conjunto de filas de tamaño variable; el cliente lo lee con `FETCH` en la misma transacción |
| Mensajes | `RAISE NOTICE` | Traza de cada paso en la pestaña de mensajes sin afectar al resultado |
| Filas afectadas | `GET DIAGNOSTICS v = ROW_COUNT` | Dato exacto de la última sentencia sin volver a consultar la tabla |
| Ejecución repetida | Planes preparados cacheados por sesión + *pool* de conexiones | Se ahorran parsing, análisis y planificación en cada llamada |

---

## 9. Chuleta rápida

```sql
-- Transacciones
BEGIN;
  ...;
  SAVEPOINT s1;
  ...;
  ROLLBACK TO SAVEPOINT s1;      -- deshace lo posterior a s1
  RELEASE SAVEPOINT s1;          -- elimina s1, conserva cambios
COMMIT;                          -- o ROLLBACK;

-- Función SQL escalar
CREATE OR REPLACE FUNCTION f(p int) RETURNS text AS $$
    SELECT ... WHERE id = p;
$$ LANGUAGE sql STABLE;
SELECT f(1);

-- Función que devuelve tabla
CREATE OR REPLACE FUNCTION g(p text) RETURNS TABLE (a int, b text) AS $$
BEGIN
    RETURN QUERY SELECT t.a, t.b FROM t WHERE t.c = p;
END;
$$ LANGUAGE plpgsql;
SELECT * FROM g('x');

-- Procedimiento
CREATE OR REPLACE PROCEDURE p(a int, b text DEFAULT NULL) AS $$
DECLARE v int;
BEGIN
    UPDATE ... WHERE (b IS NULL OR col = b);
    GET DIAGNOSTICS v = ROW_COUNT;
    RAISE NOTICE 'Filas: %', v;
    COMMIT;
END;
$$ LANGUAGE plpgsql;
CALL p(1);                       -- en autocommit, sin BEGIN

-- Procedimiento con cursor
CREATE OR REPLACE PROCEDURE q(x text, INOUT c refcursor) AS $$
BEGIN
    OPEN c FOR SELECT ... ;
END;
$$ LANGUAGE plpgsql;
BEGIN; CALL q('x', 'cur'); FETCH ALL FROM cur; COMMIT;

-- Catálogo
SELECT pg_get_functiondef('esquema.nombre'::regproc);
DROP FUNCTION f(int);
DROP PROCEDURE p(int, text);
```

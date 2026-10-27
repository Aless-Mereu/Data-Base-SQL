# Consultas 1 — Operaciones CRUD 1: lectura de datos

Manual de estudio y consulta de *Operaciones CRUD 1* (PostgreSQL, base `demodb`, esquema `bookings`): `SELECT`, filtros, `JOIN` y `UNION`, más el ejercicio *Análisis de impacto por cancelaciones de vuelos*.

**Índice**

1. [Visión general](#1-visión-general)
2. [SELECT básico y limitadores](#2-select-básico-y-limitadores)
3. [WHERE y filtros avanzados](#3-where-y-filtros-avanzados)
4. [JOINS](#4-joins)
5. [UNION y UNION ALL](#5-union-y-union-all)
6. [Ejercicio: cancelaciones de vuelos](#6-ejercicio-cancelaciones-de-vuelos)
7. [Justificación técnica (tabla para la entrega)](#7-justificación-técnica-tabla-para-la-entrega)
8. [Chuleta rápida](#8-chuleta-rápida)

---

## 1. Visión general

Todo el tema gira en torno a **leer** datos (la R de CRUD). Las tablas de `demodb` que más se usan:

```
bookings (book_ref) ──< tickets (ticket_no) ──< segments (ticket_no, flight_id) >── flights (flight_id)
   reserva               billete/pasajero         tramo: billete en un vuelo          vuelo
                                                       │
                                                       └──< boarding_passes (tarjeta de embarque)

flights.route_no ──► routes (route_no, validity) ──► airports / airplanes
```

- `──<` significa "uno a muchos": una reserva tiene muchos billetes; un billete tiene muchos tramos.
- `segments` es la **tabla puente** entre `tickets` y `flights`: para saber qué pasajeros iban en un vuelo hay que pasar por ella.

### Orden lógico de ejecución de un SELECT

Se escribe en un orden pero PostgreSQL lo evalúa en otro. Entenderlo explica casi todos los errores típicos:

| Paso | Cláusula | Qué hace |
|---|---|---|
| 1 | `FROM` + `JOIN` | Construye la tabla de trabajo |
| 2 | `WHERE` | Descarta filas |
| 3 | `GROUP BY` / `HAVING` | Agrupa y filtra grupos (Consultas 2 y 4) |
| 4 | `SELECT` | Calcula las columnas y los alias |
| 5 | `DISTINCT` | Quita duplicados |
| 6 | `ORDER BY` | Ordena (ya puede usar los alias del `SELECT`) |
| 7 | `LIMIT` / `OFFSET` / `FETCH` | Recorta |

Por eso un alias definido en el `SELECT` **no** se puede usar en el `WHERE`, pero **sí** en el `ORDER BY`.

---

## 2. SELECT básico y limitadores

```sql
-- Todas las columnas (útil para explorar; en producción, listar columnas)
SELECT bk.*
FROM bookings.bookings bk
LIMIT 100;

-- Columnas concretas con alias de tabla
SELECT ai.airport_code, ai.airport_name
FROM bookings.airports ai;

-- Paginación estándar SQL: saltar 5 y mostrar los 5 siguientes
SELECT tk.ticket_no, tk.passenger_name
FROM bookings.tickets tk
ORDER BY tk.ticket_no
OFFSET 5 ROWS
FETCH FIRST 5 ROWS ONLY;

-- Valores únicos ordenados
SELECT DISTINCT ai.country
FROM bookings.airports ai
ORDER BY ai.country;
```

### Esquemas y alias

- **Esquema** (`bookings`): espacio de nombres donde viven las tablas. `bookings.tickets` es la tabla `tickets` del esquema `bookings`.
- **Alias de tabla** (`tk`): nombre corto que evita repetir el nombre completo y resuelve ambigüedades cuando dos tablas tienen columnas con el mismo nombre (`ticket_no` está en `tickets` y en `segments`).
- **Alias de columna** (`AS total`): renombra la columna en el resultado.

### LIMIT, OFFSET y FETCH

| Cláusula | Significado | Estándar |
|---|---|---|
| `LIMIT n` | Como máximo n filas | Propio de PostgreSQL/MySQL |
| `OFFSET n` | Salta n filas | Ambos |
| `FETCH FIRST n ROWS ONLY` | Igual que `LIMIT n` | SQL estándar |

> ⚠️ **Sin `ORDER BY`, el orden no está garantizado.** `LIMIT 5` devuelve "5 filas cualesquiera". Para paginar de forma fiable siempre hay que ordenar por una columna única (el script del curso, apartado 4.1, pagina sin `ORDER BY`).

> ⚠️ **En el script del curso** (`01.SELECTS.sql`, apartado 3) el comentario dice "primeros 10 aviones", pero a la consulta le falta `LIMIT 10`.

---

## 3. WHERE y filtros avanzados

`WHERE` evalúa cada fila y se queda solo con las que dan **verdadero** (las que dan `NULL` también se descartan).

```sql
-- Texto exacto
SELECT ai.airport_code, ai.airport_name
FROM bookings.airports ai
WHERE ai.country = 'Spain';

-- Varias condiciones y orden descendente
SELECT fl.flight_id, fl.scheduled_departure
FROM bookings.flights fl
WHERE fl.status = 'Arrived'
  AND fl.route_no = 'PG0139'
ORDER BY fl.flight_id DESC;
```

### Operadores de filtro

| Operador | Uso | Ejemplo |
|---|---|---|
| `=`, `<>`, `<`, `>`, `<=`, `>=` | Comparación | `total_amount > 1000` |
| `AND`, `OR`, `NOT` | Lógica (ojo: `AND` tiene prioridad sobre `OR`; usar paréntesis) | `a = 1 AND (b = 2 OR c = 3)` |
| `BETWEEN a AND b` | Rango **incluyendo** extremos | `price BETWEEN 100 AND 200` |
| `IN (...)` | Pertenece a una lista | `city IN ('Madrid', 'Barcelona')` |
| `LIKE` | Patrón, distingue mayúsculas | `passenger_name LIKE 'MAR%'` |
| `ILIKE` | Patrón, sin distinguir mayúsculas | `passenger_name ILIKE 'mar%'` |
| `IS NULL` / `IS NOT NULL` | Ausencia de valor | `actual_departure IS NULL` |

### Comodines de LIKE

| Comodín | Significa | `'%Mor%s'` encaja con… |
|---|---|---|
| `%` | Cualquier cadena (también vacía) | `'Ana Morales'`, `'Moris'` |
| `_` | Exactamente un carácter | `'Ferr_n'` → `'Ferran'`, `'Ferrin'` |

### Por qué `= NULL` no funciona

`NULL` significa "desconocido". Cualquier comparación con `NULL` da `NULL` (ni verdadero ni falso), así que `WHERE actual_departure = NULL` **nunca** devuelve filas. Siempre `IS NULL`.

### La trampa de BETWEEN con fechas

`book_date` es `timestamptz` (fecha **y hora**). La cadena `'2026-01-11'` se interpreta como `2026-01-11 00:00:00`:

```sql
-- Se pierde casi todo el día 11
WHERE bk.book_date BETWEEN '2026-01-10' AND '2026-01-11'

-- Correcto: rango semiabierto
WHERE bk.book_date >= '2026-01-10'
  AND bk.book_date <  '2026-01-12'
```

> ⚠️ **En el script del curso**:
> - `02.SELECTS WHERE.sql`, apartado 3: el comentario se parte en dos líneas y la segunda (`usando ORDER BY ...`) no lleva `--`. Al ejecutar el fichero completo da error de sintaxis.
> - `03.FILTROS AVANZADOS.sql`, apartado 3: el comentario habla de nombres que empiezan por 'Garcia', pero el patrón es `'%Mor%s'` (contiene "Mor" y acaba en "s").

---

## 4. JOINS

Un `JOIN` combina columnas de dos tablas **en horizontal** a partir de una condición (`ON`).

| Tipo | Devuelve | Nombre en el temario |
|---|---|---|
| `INNER JOIN` (o `JOIN`) | Solo filas con pareja en ambas tablas | Incluyente estricto |
| `LEFT JOIN` | Todas las de la izquierda; la derecha a `NULL` si no hay pareja | Incluyente izquierdo |
| `RIGHT JOIN` | Todas las de la derecha; la izquierda a `NULL` si no hay pareja | Incluyente derecho |
| `FULL OUTER JOIN` | Todas las de ambas; `NULL` donde falte pareja | Incluyente total |
| `CROSS JOIN` | Producto cartesiano (todas con todas) | — |

```
 A ⋈ B          INNER        LEFT          RIGHT         FULL
 A: 1 2 3       2 3          1 2 3         2 3 4         1 2 3 4
 B: 2 3 4                    (1 con NULL)  (4 con NULL)  (1 y 4 con NULL)
```

### Ejemplos del temario

```sql
-- INNER: reservas con sus billetes
SELECT bk.book_date, tk.passenger_name, tk.ticket_no
FROM bookings.bookings bk
INNER JOIN bookings.tickets tk ON bk.book_ref = tk.book_ref
LIMIT 10;

-- LEFT: todos los aviones, tengan o no asientos configurados
SELECT ap.model, st.seat_no, st.fare_conditions
FROM bookings.airplanes ap
LEFT JOIN bookings.seats st ON ap.airplane_code = st.airplane_code;
```

### Condición en el ON frente a condición en el WHERE (pregunta típica)

En un `INNER JOIN` da igual dónde pongas el filtro. En un **OUTER JOIN** cambia el resultado:

```sql
-- (a) Filtro en el WHERE: solo tarjetas de embarque con boarding_no = 44
SELECT bp.boarding_no, tk.passenger_name
FROM bookings.tickets tk
RIGHT JOIN bookings.boarding_passes bp ON tk.ticket_no = bp.ticket_no
WHERE bp.boarding_no = 44;

-- (b) Filtro en el ON: TODAS las tarjetas; el pasajero solo se rellena si boarding_no = 44
SELECT bp.boarding_no, tk.passenger_name
FROM bookings.tickets tk
RIGHT JOIN bookings.boarding_passes bp
       ON tk.ticket_no = bp.ticket_no
      AND bp.boarding_no = 44;
```

- El `ON` decide **con qué** se empareja cada fila; la tabla "conservada" (aquí `boarding_passes`) sale entera pase lo que pase.
- El `WHERE` actúa **después** del JOIN y quita filas del resultado.
- Regla práctica: **un `WHERE` sobre una columna de la tabla opcional (la que puede venir a `NULL`) convierte el OUTER JOIN en un INNER JOIN**, porque descarta justo las filas sin pareja. Es lo que hace el apartado 3.2 del script con `WHERE tk.passenger_name IS NOT NULL`.

### FULL OUTER JOIN y las rutas

```sql
SELECT rt.route_no, fl.flight_id, fl.status
FROM bookings.routes rt
FULL OUTER JOIN bookings.flights fl ON rt.route_no = fl.route_no;
```

Sirve para auditorías: muestra rutas sin vuelos y vuelos sin ruta. Ojo: en `demodb` una `route_no` aparece varias veces en `routes` (una por periodo de `validity`), así que cada vuelo sale repetido. En Consultas 6 se resuelve con `fl.scheduled_departure <@ rt.validity`.

> ⚠️ **En el script del curso** (`04.JOINS.sql`):
> - Apartado 1: la fecha `'202-01-10'` tiene un dígito de menos en el año (año 202).
> - Los comentarios de bloque terminan en `*//`. El `*/` cierra el comentario y la `/` sobrante provoca un error de sintaxis. Debe ser `*/`.

---

## 5. UNION y UNION ALL

`UNION` combina resultados **en vertical** (añade filas). Requisitos: mismo número de columnas y tipos compatibles en el mismo orden. Los nombres de columna salen de la primera consulta.

| | `UNION` | `UNION ALL` |
|---|---|---|
| Duplicados | Los elimina | Los mantiene |
| Coste | Ordena o usa hash para deduplicar (más lento) | Solo concatena (más rápido) |
| Cuándo | Necesitas valores únicos | Sabes que no hay solapamiento o quieres todos |

Otros operadores de conjuntos: `INTERSECT` (filas comunes) y `EXCEPT` (filas de la primera que no están en la segunda).

```sql
-- Literales para marcar el origen de cada fila
SELECT tk.ticket_no AS identificador, 'Billete' AS tipo_registro
FROM bookings.tickets tk
WHERE tk.passenger_id LIKE 'JP%'
UNION
SELECT bk.book_ref, 'Reserva'
FROM bookings.bookings bk
WHERE bk.book_ref LIKE 'JP%';
```

### ORDER BY en un UNION

El `ORDER BY` final se aplica al resultado **completo** de la unión. No hace falta envolverla en una subconsulta como hace el apartado 5 del script del curso:

```sql
SELECT fl.flight_id, fl.status FROM bookings.flights fl WHERE fl.status = 'Cancelled'
UNION
SELECT fl.flight_id, fl.status FROM bookings.flights fl WHERE fl.status = 'Delayed'
ORDER BY status;          -- sin alias de tabla: se refiere a la columna del resultado
```

Y cuando las dos partes leen la **misma tabla**, lo más simple y rápido es un solo `SELECT` con `IN`:

```sql
SELECT fl.flight_id, fl.status
FROM bookings.flights fl
WHERE fl.status IN ('Cancelled', 'Delayed')
ORDER BY fl.status;
```

### airports frente a airports_data

En `demodb`, `airports_data` es la tabla real (con nombres en JSON multilingüe) y `airports` es una **vista** sobre ella que muestra los nombres en el idioma configurado. Por eso `UNION` entre sus códigos devuelve los mismos valores: es la misma información. Lo mismo ocurre con `airplanes` / `airplanes_data`.

---

## 6. Ejercicio: cancelaciones de vuelos

### Qué pide

Para Atención al Cliente: `flight_id`, `passenger_name` y `price` de los pasajeros de vuelos con `status = 'Cancelled'`. Además, justificar el tipo de JOIN y razonar qué pasaría con un `FULL OUTER JOIN` en la unión con `tickets`.

### Camino de las tablas

```
flights (flight_id, status) ──< segments (flight_id, ticket_no, price) >── tickets (ticket_no, passenger_name)
```

`flights` y `tickets` no se relacionan directamente: hay que pasar por `segments`, que además contiene el `price` del tramo.

### Solución

```sql
SELECT fl.flight_id,
       tk.passenger_name,
       sg.price
FROM bookings.flights fl
INNER JOIN bookings.segments sg ON sg.flight_id = fl.flight_id
INNER JOIN bookings.tickets  tk ON tk.ticket_no = sg.ticket_no
WHERE fl.status = 'Cancelled'
ORDER BY fl.flight_id, tk.passenger_name;

-- Número total de registros (lo pide la entrega)
SELECT COUNT(*) AS total_registros
FROM bookings.flights fl
INNER JOIN bookings.segments sg ON sg.flight_id = fl.flight_id
INNER JOIN bookings.tickets  tk ON tk.ticket_no = sg.ticket_no
WHERE fl.status = 'Cancelled';
```

### Por qué INNER JOIN

- Queremos **pasajeros afectados**: solo tiene sentido una fila si existe el vuelo cancelado, el tramo y el billete. Un vuelo cancelado sin billetes no es un cliente a compensar.
- `segments.flight_id` y `segments.ticket_no` son claves foráneas `NOT NULL`, así que todo tramo tiene vuelo y billete. El `INNER JOIN` no pierde ningún tramo válido.
- Es además el JOIN más barato: el planificador puede reordenar las tablas libremente y empezar por el filtro más selectivo (`status = 'Cancelled'`).

### Tu resultado: 0 filas

Tus comprobaciones son correctas y es justo lo que hay que hacer cuando una consulta sale vacía:

```sql
SELECT status, count(*) FROM bookings.flights GROUP BY status;        -- hay vuelos 'Cancelled'
SELECT count(*) FROM bookings.flights fl
JOIN bookings.segments sg ON sg.flight_id = fl.flight_id
WHERE fl.status = 'Cancelled';                                        -- 0 tramos
```

En esta versión de `demodb` los vuelos cancelados no tienen billetes vendidos, así que la respuesta correcta al negocio es **"0 pasajeros afectados"**. En la entrega pide 5 filas de ejemplo y el total: muestra la cabecera de la tabla vacía, el total (0) y la consulta de comprobación que lo demuestra.

### Qué ocurre realmente con tu FULL OUTER JOIN (201 filas)

```sql
FROM bookings.flights fl
FULL OUTER JOIN bookings.segments sg ON sg.flight_id = fl.flight_id
FULL OUTER JOIN bookings.tickets  tk ON tk.ticket_no = sg.ticket_no
WHERE fl.status = 'Cancelled';
```

- El `FULL` añade filas sin pareja de **ambos** lados: vuelos sin tramos (con `sg` y `tk` a `NULL`) y tramos o billetes sin vuelo (con `fl` a `NULL`).
- El `WHERE fl.status = 'Cancelled'` descarta toda fila con `fl` a `NULL`. Así que el resultado es exactamente el de un **`LEFT JOIN` desde `flights`**.
- Las 201 filas son **los 201 vuelos cancelados, cada uno con `passenger_name` y `price` a `NULL`**. No son "registros con al menos una coincidencia"; son justo los que **no** tienen coincidencia.

> ⚠️ **En tu script**: corrige la frase final de la explicación ("listando 201 registros con vuelos cancelados" → "201 vuelos cancelados sin ningún pasajero; passenger_name y price salen a NULL").

### Respuesta a la pregunta teórica: FULL OUTER JOIN solo con tickets

```sql
FROM bookings.flights fl
INNER JOIN bookings.segments sg ON sg.flight_id = fl.flight_id
FULL OUTER JOIN bookings.tickets tk ON tk.ticket_no = sg.ticket_no
WHERE fl.status = 'Cancelled';
```

1. **Antes del `WHERE`**, el `FULL` conservaría además todos los billetes que no casan con ningún tramo, con `flight_id`, `status` y `price` a `NULL`.
2. **El `WHERE`** elimina precisamente esas filas (su `fl.status` es `NULL`), así que el resultado final **es el mismo que con `INNER JOIN`**, pero con más trabajo: el motor tiene que construir y descartar las filas extra, y no puede reordenar libremente un `FULL JOIN`.
3. **Sin el filtro** (o con el filtro en el `ON`), el informe se llenaría de billetes sin vuelo, que no son pasajeros afectados por una cancelación: datos incorrectos para compensar clientes.

Conclusión: el `FULL OUTER JOIN` sirve para auditar integridad entre dos tablas (huérfanos a ambos lados), no para un informe de negocio con filtro.

---

## 7. Justificación técnica (tabla para la entrega)

| Elemento de diseño | Propuesta técnica | Justificación relacional e impacto en rendimiento |
|---|---|---|
| Camino de tablas | `flights` → `segments` → `tickets` | `segments` es la tabla puente N:M entre billetes y vuelos y contiene el `price` del tramo; no hay relación directa entre `flights` y `tickets` |
| Tipo de unión | `INNER JOIN` en ambas uniones | Solo interesan pasajeros con billete en un vuelo cancelado. Las FK `NOT NULL` de `segments` garantizan que no se pierden tramos válidos. Permite al planificador reordenar y empezar por el filtro más selectivo |
| Filtro | `WHERE fl.status = 'Cancelled'` | Se aplica sobre la tabla obligatoria; reduce las filas antes de unir con las tablas grandes |
| Alternativa `FULL OUTER JOIN` en `tickets` | Descartada | Genera billetes huérfanos con `NULL` que el `WHERE` vuelve a eliminar: mismo resultado y más coste. Sin filtro, daría filas que no son pasajeros afectados |
| Resultado vacío | Consultas de comprobación (`GROUP BY status`, `COUNT` sobre el JOIN) | Demuestran que hay vuelos cancelados pero sin tramos vendidos: la respuesta correcta es 0 pasajeros a compensar |
| Total de registros | `SELECT COUNT(*)` con el mismo `FROM`/`WHERE` | Da la cifra exacta que pide la entrega sin depender del cliente SQL |

---

## 8. Chuleta rápida

```sql
-- Estructura y orden de escritura
SELECT [DISTINCT] col1, col2 AS alias
FROM esquema.tabla t
[INNER|LEFT|RIGHT|FULL OUTER] JOIN esquema.otra o ON o.id = t.id
WHERE condición
ORDER BY col1 [ASC|DESC]
LIMIT n OFFSET m;                 -- o: OFFSET m ROWS FETCH FIRST n ROWS ONLY

-- Filtros
col BETWEEN a AND b               -- incluye extremos
col IN ('a', 'b')
col LIKE 'Ab%'   /  col ILIKE 'ab%'   -- % = cualquier cadena, _ = un carácter
col IS NULL      /  col IS NOT NULL

-- Fechas: rango semiabierto
col >= '2026-01-10' AND col < '2026-01-12'

-- Conjuntos
SELECT ... UNION     SELECT ...   -- sin duplicados
SELECT ... UNION ALL SELECT ...   -- con duplicados, más rápido
SELECT ... INTERSECT SELECT ...
SELECT ... EXCEPT    SELECT ...
-- ORDER BY al final se aplica al conjunto entero

-- Regla de oro de los OUTER JOIN
-- WHERE sobre la tabla opcional  => se comporta como INNER JOIN
-- Filtro en el ON                => la tabla conservada sale entera
```

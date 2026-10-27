# Consultas 4 — HAVING y funciones de ventana (Window Functions)

Manual de estudio y consulta de *Window Functions* (PostgreSQL, base `demodb`, esquema `bookings`). Este tema no tiene enunciado de ejercicio: se desarrollan y corrigen los ejemplos del curso (`16.HAVING con GROUP BY.sql` … `19.CLAUSULA WINDOW.sql`).

**Índice**

1. [Visión general](#1-visión-general)
2. [HAVING: filtrar grupos](#2-having-filtrar-grupos)
3. [Funciones de ventana: OVER, PARTITION BY y ORDER BY](#3-funciones-de-ventana-over-partition-by-y-order-by)
4. [Funciones de ranking](#4-funciones-de-ranking)
5. [Acumulados y el marco de la ventana](#5-acumulados-y-el-marco-de-la-ventana)
6. [LAG y LEAD](#6-lag-y-lead)
7. [Cláusula WINDOW y rendimiento](#7-cláusula-window-y-rendimiento)
8. [Resumen técnico (tabla)](#8-resumen-técnico-tabla)
9. [Chuleta rápida](#9-chuleta-rápida)

---

## 1. Visión general

| | `GROUP BY` + agregado | Función de ventana |
|---|---|---|
| Filas de salida | **Una por grupo** (se pierde el detalle) | **Una por fila de entrada** (se conserva el detalle) |
| Sintaxis | `SUM(x) ... GROUP BY g` | `SUM(x) OVER (PARTITION BY g)` |
| Ejemplo | Total por clase | Cada billete **y** el total de su clase al lado |

```sql
-- Cada tramo con el precio medio de su clase y su diferencia con la media
SELECT sg.ticket_no,
       sg.fare_conditions,
       sg.price,
       ROUND(AVG(sg.price) OVER (PARTITION BY sg.fare_conditions), 2)               AS media_clase,
       sg.price - ROUND(AVG(sg.price) OVER (PARTITION BY sg.fare_conditions), 2)    AS desviacion
FROM bookings.segments sg
LIMIT 20;
```

### Dónde encajan en el orden de ejecución

| Paso | Cláusula |
|---|---|
| 1 | `FROM` / `JOIN` |
| 2 | `WHERE` (filtra filas) |
| 3 | `GROUP BY` |
| 4 | `HAVING` (filtra grupos) |
| 5 | **Funciones de ventana** |
| 6 | `SELECT` (alias), `DISTINCT` |
| 7 | `ORDER BY` |
| 8 | `LIMIT` / `OFFSET` |

Consecuencias:
- Las ventanas trabajan sobre las filas que **ya** han pasado el `WHERE`, el `GROUP BY` y el `HAVING`.
- **No** se puede usar una función de ventana en `WHERE`, `GROUP BY` ni `HAVING`. Para filtrar por su resultado hay que usar una subconsulta (sección 7).
- El `LIMIT` se aplica **después** de calcular la ventana: el ranking se calcula sobre toda la tabla y luego se recorta.

---

## 2. HAVING: filtrar grupos

| | `WHERE` | `HAVING` |
|---|---|---|
| Actúa sobre | Filas individuales | Grupos |
| Cuándo | Antes de agrupar | Después de agrupar |
| Puede usar agregados | No | Sí |

```sql
-- Rutas con más de 2 vuelos cancelados
SELECT fl.route_no, COUNT(fl.flight_id) AS total_cancelados
FROM bookings.flights fl
WHERE fl.status = 'Cancelled'               -- filtra filas
GROUP BY fl.route_no
HAVING COUNT(fl.flight_id) > 2              -- filtra grupos
ORDER BY total_cancelados DESC;
```

> Siempre que una condición **no** dependa de un agregado, ponla en el `WHERE`: descarta filas antes de agrupar y la consulta es más rápida.

### Contar condicionalmente: CASE dentro de SUM, o FILTER

```sql
-- Modelos con más de 100 asientos y más de 20 en Business
SELECT ap.model,
       COUNT(st.seat_no)                                              AS total_asientos,
       SUM(CASE WHEN st.fare_conditions = 'Business' THEN 1 ELSE 0 END) AS asientos_business
FROM bookings.airplanes ap
INNER JOIN bookings.seats st ON ap.airplane_code = st.airplane_code
GROUP BY ap.model
HAVING COUNT(st.seat_no) > 100
   AND SUM(CASE WHEN st.fare_conditions = 'Business' THEN 1 ELSE 0 END) > 20;

-- Lo mismo con la sintaxis FILTER de PostgreSQL (más legible)
SELECT ap.model,
       COUNT(*)                                                AS total_asientos,
       COUNT(*) FILTER (WHERE st.fare_conditions = 'Business') AS asientos_business
FROM bookings.airplanes ap
INNER JOIN bookings.seats st ON ap.airplane_code = st.airplane_code
GROUP BY ap.model
HAVING COUNT(*) > 100
   AND COUNT(*) FILTER (WHERE st.fare_conditions = 'Business') > 20;
```

En PostgreSQL **no** se puede usar en el `HAVING` el alias del `SELECT` (`HAVING total_asientos > 100` da error): hay que repetir la expresión.

### COUNT(DISTINCT) al combinar JOIN y GROUP BY

```sql
SELECT tk.passenger_name, tk.passenger_id,
       COUNT(DISTINCT tk.ticket_no) AS total_billetes,
       ROUND(AVG(sg.price), 2)      AS precio_promedio
FROM bookings.tickets tk
INNER JOIN bookings.segments sg ON tk.ticket_no = sg.ticket_no
GROUP BY tk.passenger_name, tk.passenger_id
HAVING COUNT(DISTINCT tk.ticket_no) > 3;
```

Un billete con varios tramos aparece varias veces tras el JOIN. `COUNT(tk.ticket_no)` contaría tramos; `COUNT(DISTINCT ...)` cuenta billetes.

> ⚠️ **En el script del curso** (`16.HAVING con GROUP BY.sql`): a la consulta 2 le falta el `;` final, así que ejecutando el fichero entero se pega a la consulta 3 y da error de sintaxis.

---

## 3. Funciones de ventana: OVER, PARTITION BY y ORDER BY

```sql
funcion(...) OVER (
    PARTITION BY columnas      -- grupos independientes (opcional)
    ORDER BY columnas          -- orden dentro de cada grupo (opcional)
    marco                      -- qué filas del grupo entran en el cálculo (opcional)
)
```

| Pieza | Qué hace | Si se omite |
|---|---|---|
| `OVER` | Convierte la función en función de ventana (obligatorio) | Es un agregado normal |
| `PARTITION BY` | Divide las filas en grupos; el cálculo se reinicia en cada uno | Toda la consulta es una sola partición |
| `ORDER BY` | Orden para el cálculo (rankings, acumulados, anterior/siguiente) | Todas las filas son "iguales": los agregados dan el total de la partición |
| Marco (*frame*) | Subconjunto de filas de la partición para cada fila actual | Con `ORDER BY`: desde el inicio hasta la fila actual (y sus empates) |

> El `ORDER BY` **dentro** del `OVER` solo afecta al cálculo; **no** ordena la salida. Si quieres el resultado ordenado, añade también un `ORDER BY` al final de la consulta.

### Tipos de funciones de ventana

| Familia | Funciones |
|---|---|
| Ranking | `ROW_NUMBER()`, `RANK()`, `DENSE_RANK()`, `NTILE(n)`, `PERCENT_RANK()`, `CUME_DIST()` |
| Navegación | `LAG()`, `LEAD()`, `FIRST_VALUE()`, `LAST_VALUE()`, `NTH_VALUE()` |
| Agregados como ventana | `SUM()`, `AVG()`, `COUNT()`, `MIN()`, `MAX()` con `OVER` |

---

## 4. Funciones de ranking

```sql
-- Ranking de precios dentro de cada clase
SELECT sg.ticket_no,
       sg.fare_conditions,
       sg.price,
       ROW_NUMBER() OVER w AS row_number,
       RANK()       OVER w AS rank,
       DENSE_RANK() OVER w AS dense_rank
FROM bookings.segments sg
WINDOW w AS (PARTITION BY sg.fare_conditions ORDER BY sg.price DESC)
LIMIT 200;
```

Diferencia con empates (precios 300, 300, 250):

| price | `ROW_NUMBER` | `RANK` | `DENSE_RANK` |
|---|---|---|---|
| 300 | 1 | 1 | 1 |
| 300 | 2 | 1 | 1 |
| 250 | 3 | **3** (salta) | **2** (no salta) |

| Función | Cuándo usarla |
|---|---|
| `ROW_NUMBER` | Numerar o quedarse con "el primero de cada grupo" (desempata de forma arbitraria) |
| `RANK` | Clasificación deportiva: dos segundos y luego un cuarto |
| `DENSE_RANK` | "Los 3 precios más altos distintos" |
| `NTILE(4)` | Repartir en cuartiles |

---

## 5. Acumulados y el marco de la ventana

```sql
-- Ingresos acumulados por fecha de reserva (running total)
SELECT bk.book_ref,
       bk.book_date,
       bk.total_amount,
       SUM(bk.total_amount) OVER (
           ORDER BY bk.book_date
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS ingresos_acumulados
FROM bookings.bookings bk
ORDER BY bk.book_date
LIMIT 200;
```

### Sintaxis del marco

```
{ROWS | RANGE | GROUPS} BETWEEN inicio AND fin

inicio / fin:  UNBOUNDED PRECEDING   (primera fila de la partición)
               n PRECEDING           (n filas antes)
               CURRENT ROW
               n FOLLOWING           (n filas después)
               UNBOUNDED FOLLOWING   (última fila de la partición)
```

### ROWS frente a RANGE (pregunta típica)

| | `ROWS` | `RANGE` (por defecto con `ORDER BY`) |
|---|---|---|
| Cuenta | Filas físicas | Valores del `ORDER BY`; los empates entran juntos |
| Con dos reservas a la misma hora | La primera suma una, la segunda suma las dos | Ambas muestran ya la suma de las dos |

Por eso el ejemplo del curso pone `ROWS ...` explícitamente: así el acumulado crece fila a fila aunque haya empates.

### Otros marcos útiles

```sql
-- Media móvil de las 3 últimas reservas (incluida la actual)
AVG(total_amount) OVER (ORDER BY book_date ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)

-- Acumulado que se reinicia cada día
SUM(total_amount) OVER (PARTITION BY book_date::date ORDER BY book_date)

-- Porcentaje sobre el total de la partición
total_amount * 100.0 / SUM(total_amount) OVER ()
```

> ⚠️ **Trampa con `LAST_VALUE`**: con el marco por defecto (hasta la fila actual), `LAST_VALUE(x) OVER (ORDER BY ...)` devuelve el valor de la **propia** fila. Para el último de verdad: `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`.

---

## 6. LAG y LEAD

Acceden a otra fila de la misma partición **sin hacer un self-join**.

```
            fila − 1   ◄── LAG()
fila actual (offset 0)
            fila + 1   ◄── LEAD()
```

```sql
LAG(columna  [, desplazamiento [, valor_por_defecto]]) OVER (...)
LEAD(columna [, desplazamiento [, valor_por_defecto]]) OVER (...)
```

- `desplazamiento` por defecto es 1.
- Si no hay fila anterior/siguiente, devuelve `NULL` (o el valor por defecto que indiques).

### Intervalo entre vuelos consecutivos de una ruta

```sql
SELECT fl.flight_id,
       fl.route_no,
       fl.scheduled_departure,
       LAG(fl.scheduled_departure) OVER w                          AS salida_vuelo_anterior,
       fl.scheduled_departure - LAG(fl.scheduled_departure) OVER w AS intervalo_con_anterior,
       LEAD(fl.scheduled_departure) OVER w - fl.scheduled_departure AS margen_siguiente
FROM bookings.flights fl
WHERE fl.status <> 'Cancelled'
WINDOW w AS (PARTITION BY fl.route_no ORDER BY fl.scheduled_departure)
ORDER BY fl.route_no, fl.scheduled_departure;
```

- `PARTITION BY route_no`: solo se comparan vuelos de la misma ruta.
- `ORDER BY scheduled_departure`: da sentido a "anterior" y "siguiente".
- Restar dos `timestamp` da un `interval` (`1 day 02:30:00`).
- El primer vuelo de cada ruta tiene `LAG` a `NULL`; el último, `LEAD` a `NULL`.

### Variación de precio entre tramos de un mismo vuelo y clase

```sql
SELECT sg.flight_id,
       sg.fare_conditions,
       sg.price,
       LAG(sg.price) OVER w            AS precio_anterior,
       sg.price - LAG(sg.price) OVER w AS incremento_precio
FROM bookings.segments_price_random sg
WHERE sg.fare_conditions IN ('Economy', 'Comfort')
WINDOW w AS (PARTITION BY sg.flight_id, sg.fare_conditions ORDER BY sg.price)
ORDER BY sg.flight_id, sg.fare_conditions, sg.price;
```

> ⚠️ **En el script del curso** (`18.LAG , OVER.sql`):
> - El filtro usa `'Confort'`, pero en `demodb` la clase se llama `'Comfort'`. Con la errata, los tramos Comfort desaparecen del resultado sin dar error.
> - El comentario dice "tabla temporal", pero `CREATE TABLE bookings.segments_price_random` crea una tabla **permanente** en el esquema `bookings`. Bórrala al terminar (`DROP TABLE bookings.segments_price_random;`) o créala con `CREATE TEMP TABLE`.
> - Varias líneas de comentario se parten y la continuación no lleva `--` (por ejemplo `utilizando LAG() y OVER()`), lo que da error al ejecutar el fichero completo.

---

## 7. Cláusula WINDOW y rendimiento

### WINDOW: definir la ventana una vez

```sql
SELECT fl.flight_id,
       LAG(fl.scheduled_departure)  OVER w_ruta AS salida_anterior,
       LEAD(fl.scheduled_departure) OVER w_ruta AS salida_siguiente
FROM bookings.flights fl
WINDOW w_ruta AS (PARTITION BY fl.route_no ORDER BY fl.scheduled_departure)
ORDER BY fl.route_no, fl.scheduled_departure;
```

- Evita repetir la misma definición (menos errores de mantenimiento).
- Todas las funciones con la **misma** ventana comparten **una sola ordenación**.
- Una ventana con nombre se puede ampliar: `OVER (w_ruta ROWS BETWEEN 1 PRECEDING AND CURRENT ROW)`.

### Por qué las ventanas pueden ser costosas

| Causa | Remedio |
|---|---|
| Necesitan los datos **ordenados** por `PARTITION BY` + `ORDER BY` | Alinear las ventanas para compartir orden; un índice con esas columnas puede evitar el `Sort` |
| Ventanas con distinto `PARTITION BY`/`ORDER BY` obligan a ordenar varias veces | Usar la misma ventana siempre que se pueda |
| Si la ordenación no cabe en `work_mem`, se vuelca a disco (`Sort Method: external merge`) | Subir `work_mem` puntualmente |
| Muchas filas de entrada | Filtrar pronto con `WHERE` |

### Filtrar por el resultado de una ventana: subconsulta

```sql
-- Los 2 tramos más caros de cada clase
SELECT *
FROM (
    SELECT sg.ticket_no, sg.fare_conditions, sg.price,
           ROW_NUMBER() OVER (PARTITION BY sg.fare_conditions ORDER BY sg.price DESC) AS pos
    FROM bookings.segments sg
) AS ranking
WHERE pos <= 2;
```

`WHERE ROW_NUMBER() OVER (...) <= 2` directamente daría error, porque el `WHERE` se evalúa antes que las ventanas.

### work_mem

Memoria que puede usar **cada** operación de ordenación o hash antes de escribir en disco.

| Alcance | Comando |
|---|---|
| Solo esta transacción (**recomendado**) | `BEGIN; SET LOCAL work_mem = '64MB'; ...; COMMIT;` |
| Esta sesión | `SET work_mem = '32MB';` |
| Un usuario / una base de datos | `ALTER ROLE u SET work_mem = '16MB';` / `ALTER DATABASE db SET work_mem = '16MB';` |
| Todo el servidor | `ALTER SYSTEM SET work_mem = '16MB'; SELECT pg_reload_conf();` |

> **Cuidado**: es por operación, no por usuario. Una consulta con 3 ordenaciones y `work_mem = 64MB` puede usar 192 MB, y con 100 conexiones a la vez se puede agotar la RAM. Antes de subirlo, comprueba con `EXPLAIN (ANALYZE, BUFFERS)` si aparece `external merge` o escritura en ficheros temporales.

> ⚠️ **En el script del curso** (`19.CLAUSULA WINDOW.sql`): las consultas sobre `empsalary` son el ejemplo de la documentación oficial de PostgreSQL. Esa tabla **no existe** en `demodb`, así que dan error si las ejecutas.

---

## 8. Resumen técnico (tabla)

| Elemento de diseño | Propuesta técnica | Justificación relacional e impacto en rendimiento |
|---|---|---|
| Filtro de filas | `WHERE` antes de agrupar o de abrir ventanas | Reduce las filas que hay que agrupar u ordenar; puede usar índices |
| Filtro de grupos | `HAVING` con el agregado repetido | `WHERE` no conoce los grupos; en `HAVING` no se pueden usar alias del `SELECT` |
| Conteo condicional | `COUNT(*) FILTER (WHERE ...)` o `SUM(CASE ...)` | Varios recuentos en una sola pasada por la tabla |
| Conteo tras JOIN | `COUNT(DISTINCT ticket_no)` | El JOIN con `segments` repite billetes; `DISTINCT` cuenta entidades, no filas |
| Detalle + agregado | `agregado OVER (PARTITION BY ...)` | Mantiene cada fila y añade la métrica del grupo sin self-join ni subconsulta |
| Ranking | `ROW_NUMBER` / `RANK` / `DENSE_RANK` según empates | Elegir la función según si los empates deben compartir puesto y si hay saltos |
| Acumulado | `SUM() OVER (ORDER BY ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)` | `ROWS` acumula fila a fila; el marco por defecto (`RANGE`) agrupa los empates |
| Anterior / siguiente | `LAG` / `LEAD` con `PARTITION BY route_no ORDER BY scheduled_departure` | Compara filas consecutivas sin self-join; restar `timestamp` devuelve `interval` |
| Varias funciones, misma ventana | Cláusula `WINDOW w AS (...)` | Una sola ordenación compartida; menos código repetido |
| Filtrar por ventana | Subconsulta y `WHERE` exterior | Las ventanas se evalúan después del `WHERE` |
| Memoria | `SET LOCAL work_mem` en la transacción | Evita volcar la ordenación a disco sin afectar al resto del servidor |

---

## 9. Chuleta rápida

```sql
-- HAVING
SELECT g, COUNT(*) FROM t WHERE ... GROUP BY g HAVING COUNT(*) > 2;
COUNT(*) FILTER (WHERE cond)

-- Ventana
f() OVER (PARTITION BY p ORDER BY o ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
f() OVER ()                          -- toda la consulta
f() OVER w ... WINDOW w AS (PARTITION BY p ORDER BY o)

-- Ranking
ROW_NUMBER() OVER (...)   -- 1,2,3
RANK()       OVER (...)   -- 1,1,3
DENSE_RANK() OVER (...)   -- 1,1,2
NTILE(4)     OVER (...)

-- Navegación
LAG(col [, n [, def]])  OVER (...)   -- fila anterior
LEAD(col [, n [, def]]) OVER (...)   -- fila siguiente
FIRST_VALUE(col) OVER (...)
LAST_VALUE(col)  OVER (... ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)

-- Acumulado / media móvil / porcentaje
SUM(x) OVER (ORDER BY f ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
AVG(x) OVER (ORDER BY f ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
x * 100.0 / SUM(x) OVER ()

-- Top-N por grupo
SELECT * FROM (SELECT ..., ROW_NUMBER() OVER (PARTITION BY g ORDER BY x DESC) AS pos FROM t) s
WHERE pos <= 3;

-- Memoria
BEGIN; SET LOCAL work_mem = '64MB'; ... ; COMMIT;
```

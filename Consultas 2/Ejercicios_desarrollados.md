# Consultas 2 — Operaciones CRUD 2: agrupación, INSERT, UPDATE y DELETE

Manual de estudio y consulta de *Operaciones CRUD 2* (PostgreSQL, base `demodb`, esquema `bookings`), más el caso práctico de la cafetería **Espresso & Data**.

**Índice**

1. [Visión general](#1-visión-general)
2. [GROUP BY y funciones de agregado](#2-group-by-y-funciones-de-agregado)
3. [INSERT](#3-insert)
4. [UPDATE](#4-update)
5. [DELETE e integridad referencial](#5-delete-e-integridad-referencial)
6. [ACID y SQL frente a NoSQL](#6-acid-y-sql-frente-a-nosql)
7. [Ejercicio: cafetería Espresso & Data](#7-ejercicio-cafetería-espresso--data)
8. [Justificación técnica (tabla para la entrega)](#8-justificación-técnica-tabla-para-la-entrega)
9. [Chuleta rápida](#9-chuleta-rápida)

---

## 1. Visión general

| Letra | Operación | Sentencia | Tema |
|---|---|---|---|
| C | Create | `INSERT` | Este |
| R | Read | `SELECT` (+ `GROUP BY`) | Consultas 1 y este |
| U | Update | `UPDATE` | Este |
| D | Delete | `DELETE` | Este |

Las tres sentencias de escritura respetan las mismas reglas: **PK** (no hay dos filas con la misma clave), **FK** (no hay hijos sin padre), **NOT NULL** y **CHECK**. Casi todos los errores de este tema son una de esas cuatro restricciones protegiendo los datos.

---

## 2. GROUP BY y funciones de agregado

`GROUP BY` condensa en **una sola fila** todas las filas que comparten los mismos valores en las columnas agrupadas, y las funciones de agregado calculan sobre cada grupo.

```sql
-- Vuelos por estado
SELECT fl.status, COUNT(fl.flight_id) AS total_vuelos
FROM bookings.flights fl
GROUP BY fl.status;

-- Precio medio por clase, redondeado
SELECT sg.fare_conditions, ROUND(AVG(sg.price), 2) AS precio_medio
FROM bookings.segments sg
GROUP BY sg.fare_conditions;

-- JOIN + GROUP BY: asientos por modelo de avión
SELECT ap.model, COUNT(st.seat_no) AS total_asientos
FROM bookings.airplanes ap
INNER JOIN bookings.seats st ON ap.airplane_code = st.airplane_code
GROUP BY ap.model;
```

### Funciones de agregado

| Función | Devuelve | Nota |
|---|---|---|
| `COUNT(*)` | Número de filas | Cuenta también filas con `NULL` |
| `COUNT(col)` | Filas con `col` no nula | |
| `COUNT(DISTINCT col)` | Valores distintos no nulos | |
| `SUM(col)` | Suma | Ignora `NULL` |
| `AVG(col)` | Media | Ignora `NULL`; devuelve muchos decimales: usar `ROUND(..., 2)` |
| `MIN(col)` / `MAX(col)` | Mínimo / máximo | Sirve también con texto y fechas |

### La regla de oro

Toda columna del `SELECT` que **no** esté dentro de una función de agregado **debe aparecer en el `GROUP BY`**. Si no, PostgreSQL da *"column ... must appear in the GROUP BY clause or be used in an aggregate function"*: no sabría qué valor mostrar de entre todas las filas del grupo.

### Agrupar por día (trampa del script del curso)

```sql
-- book_date es timestamptz: cada reserva tiene su hora, así que casi no agrupa nada
GROUP BY bk.book_date

-- Correcto: agrupar por la fecha sin hora
SELECT bk.book_date::date AS dia, SUM(bk.total_amount) AS recaudacion_diaria
FROM bookings.bookings bk
GROUP BY bk.book_date::date
ORDER BY dia DESC;
```

> ⚠️ **En el script del curso** (`06.GROUP_BY.sql`, apartado 2) se agrupa por `bk.book_date` directamente. El PDF usa `TO_CHAR(bk.book_date, 'YYYY-MM-DD')`, que funciona pero devuelve texto; `::date` es más limpio y conserva el tipo fecha.

`HAVING` (filtrar grupos después de agrupar) se ve en Consultas 4.

---

## 3. INSERT

```sql
-- Una fila
INSERT INTO bookings.bookings (book_ref, book_date, total_amount)
VALUES ('XYZ123', '2026-08-01', 500.00);

-- Varias filas en una sola sentencia (más rápido y atómico)
INSERT INTO bookings.tickets (ticket_no, book_ref, passenger_id, passenger_name, outbound)
VALUES ('1234567890123', 'XYZ123', '77788899A', 'John Doe', 'Y'),
       ('1234567890124', 'XYZ123', '11122233B', 'Jane Doe', 'Y');

-- Desde una consulta
INSERT INTO temp_vip_bookings
SELECT 'T', bk.*
FROM bookings.bookings bk
WHERE bk.total_amount >= 1000.00;
```

### Buenas prácticas

- **Lista siempre las columnas** (`INSERT INTO t (a, b) ...`). Si alguien añade una columna a la tabla, el `INSERT` sigue funcionando.
- **Respeta la jerarquía**: primero los padres (`bookings`), después los hijos (`tickets`). Si no, salta la FK.
- **`RETURNING`** devuelve lo insertado, útil para obtener IDs generados:

```sql
INSERT INTO bookings.flights (route_no, status, scheduled_departure, scheduled_arrival)
VALUES ('PG0001', 'Scheduled', '2026-12-01 10:00', '2026-12-01 12:00')
RETURNING flight_id;
```

### Copiar la estructura de una tabla sin datos

```sql
CREATE TEMPORARY TABLE temp_vip_bookings AS
SELECT 'T' AS reg_type, *
FROM bookings.bookings
LIMIT 0;               -- 0 filas: solo se copian las columnas y sus tipos
```

La tabla temporal desaparece al cerrar la sesión y solo la ve la sesión que la creó.

### Violación de PK y UPSERT

```sql
INSERT INTO bookings.bookings (book_ref, book_date, total_amount)
VALUES ('XYZ123', '2026-08-02', 800.00);
-- ERROR: duplicate key value violates unique constraint "bookings_pkey"
```

Soluciones:

```sql
-- Si existe, actualizar (UPSERT)
INSERT INTO bookings.bookings (book_ref, book_date, total_amount)
VALUES ('XYZ123', '2026-08-02', 1200.00)
ON CONFLICT (book_ref) DO UPDATE SET total_amount = EXCLUDED.total_amount;

-- Si existe, ignorar
INSERT INTO ... VALUES (...)
ON CONFLICT (book_ref) DO NOTHING;
```

`EXCLUDED` es la fila que **intentabas** insertar; así puedes usar sus valores en el `UPDATE`.

> ⚠️ **En el script del curso** (`07.INSERT.sql`): faltan los `;` tras el `INSERT ... ON CONFLICT` y tras `SELECT MAX(book_ref) ...`. Ejecutando el fichero entero, la sentencia siguiente se pega a la anterior y da error de sintaxis.

---

## 4. UPDATE

```sql
UPDATE bookings.bookings bk
SET total_amount = 650.00
WHERE bk.book_ref = 'XYZ123';
```

> **Sin `WHERE`, `UPDATE` modifica todas las filas de la tabla.** Antes de lanzar un `UPDATE` delicado:
> 1. Ejecuta un `SELECT` con el mismo `WHERE` y comprueba cuántas filas salen.
> 2. O hazlo dentro de `BEGIN; ... ` y revisa antes de `COMMIT;` (o `ROLLBACK;`).

### UPDATE con datos de otra tabla (`UPDATE ... FROM`)

```sql
-- Restaurar el estado original de los vuelos desde la copia temporal
UPDATE bookings.flights fl
SET status = u.status
FROM temp_flights u
WHERE fl.flight_id = u.flight_id
  AND fl.status = 'Delayed';
```

Es el equivalente PostgreSQL a un `UPDATE` con `JOIN`. La condición de unión va en el `WHERE`.

### UPDATE con subconsulta correlacionada

```sql
UPDATE cafeteria.pedidos pe
SET total = (SELECT SUM(dp.cantidad * dp.precio_unitario)
             FROM cafeteria.detalles_pedido dp
             WHERE dp.id_pedido = pe.id_pedido)
WHERE pe.id_pedido = 1008;
```

### Errores al cambiar una clave primaria

```sql
-- 1) El nuevo valor ya existe → violación de PK
UPDATE bookings.tickets SET ticket_no = '0005437629809' WHERE ticket_no = '0005437629810';
-- ERROR: duplicate key value violates unique constraint "tickets_pkey"

-- 2) El valor antiguo está referenciado por hijos → violación de FK
-- ERROR: update or delete on table "tickets" violates foreign key constraint
--        "segments_ticket_no_fkey" on table "segments"
```

El segundo error ocurre porque la FK de `segments` se creó sin regla, es decir, con `ON UPDATE NO ACTION`. Con `ON UPDATE CASCADE`, el cambio se propagaría a los hijos.

### Reglas de integridad referencial (ON UPDATE / ON DELETE)

| Regla | Al cambiar o borrar el padre… |
|---|---|
| `NO ACTION` (por defecto) | Error si hay hijos (se comprueba al final de la sentencia) |
| `RESTRICT` | Error si hay hijos (se comprueba inmediatamente) |
| `CASCADE` | Se propaga: los hijos se actualizan o se borran |
| `SET NULL` | La FK de los hijos pasa a `NULL` |
| `SET DEFAULT` | La FK de los hijos toma su valor por defecto |

```sql
CREATE TABLE tabla_padre (id int PRIMARY KEY);
CREATE TABLE tabla_hija (
    id       int PRIMARY KEY,
    padre_id int REFERENCES tabla_padre (id) ON UPDATE CASCADE
);
INSERT INTO tabla_padre VALUES (1);
INSERT INTO tabla_hija  VALUES (1, 1);
UPDATE tabla_padre SET id = 100 WHERE id = 1;
SELECT * FROM tabla_hija;      -- padre_id = 100
```

---

## 5. DELETE e integridad referencial

```sql
DELETE FROM bookings.tickets tk
WHERE tk.ticket_no = '1234567890199';
```

Igual que `UPDATE`: **sin `WHERE` borra la tabla entera**.

### El orden importa: primero los hijos

Con FK `NO ACTION` (las de `demodb`), un padre con hijos **no se puede borrar**:

```sql
DELETE FROM bookings.bookings WHERE book_ref = 'XYZ124';
-- ERROR: update or delete on table "bookings" violates foreign key constraint
--        "tickets_book_ref_fkey" on table "tickets"
```

Orden correcto, y dentro de una transacción para que sea todo o nada:

```sql
BEGIN;
DELETE FROM bookings.tickets  WHERE book_ref = 'XYZ124';   -- hijos
DELETE FROM bookings.bookings WHERE book_ref = 'XYZ124';   -- padre
COMMIT;
```

> ⚠️ **En el script del curso** (`09.DELETE.sql`, apartado 3) se borra primero la reserva y después los billetes: el primer `DELETE` falla por la FK. Además falta el `;` tras el `INSERT` de `'XYZ124'`.

### DELETE con RETURNING

```sql
DELETE FROM bookings.flights fl
WHERE fl.status = 'Cancelled'
  AND fl.scheduled_departure < '2025-01-01'
RETURNING fl.flight_id, fl.route_no;      -- muestra lo que acaba de borrar
```

### DELETE, TRUNCATE y DROP

| | `DELETE` | `TRUNCATE` | `DROP TABLE` |
|---|---|---|---|
| Tipo | DML | DDL | DDL |
| Qué borra | Las filas que cumplen el `WHERE` | Todas las filas | La tabla entera (estructura incluida) |
| Velocidad | Fila a fila | Inmediato | Inmediato |
| Espacio en disco | Queda como "tuplas muertas" hasta `VACUUM` | Se libera al momento | Se libera al momento |

Se amplía en Consultas 3.

---

## 6. ACID y SQL frente a NoSQL

| Propiedad | Garantiza | Cómo lo hace PostgreSQL |
|---|---|---|
| **A**tomicidad | Todo o nada | Transacciones (`BEGIN`/`COMMIT`/`ROLLBACK`) |
| **C**onsistencia | Tras cada transacción se cumplen todas las reglas | PK, FK, CHECK, NOT NULL |
| a**I**slamiento | Las transacciones concurrentes no ven estados intermedios | MVCC y bloqueos de fila |
| **D**urabilidad | Lo confirmado sobrevive a una caída | WAL (*Write-Ahead Log*) |

| Característica | PostgreSQL (SQL) | NoSQL (MongoDB, Cassandra) |
|---|---|---|
| Modelo | Relacional: tablas, filas, columnas | Documentos, clave-valor, columnas anchas, grafos |
| Esquema | Estricto y predefinido | Flexible |
| Escalado | Vertical (más CPU/RAM) | Horizontal (más nodos) |
| Garantías | ACID, consistencia fuerte | Teorema CAP; muchas eligen consistencia eventual |
| Integridad | FK y CHECK en el motor | En la aplicación |

---

## 7. Ejercicio: cafetería Espresso & Data

### Qué pide

| Bloque | Requisito |
|---|---|
| DDL | 4 tablas (`productos`, `clientes`, `pedidos`, `detalles_pedido`), tipos estrictos, PK en todas, FK, **al menos dos FK con `ON UPDATE CASCADE`** |
| INSERT | Mínimo 10 filas en **cada** tabla, respetando padres → hijos |
| UPDATE | Al menos 1 en **cada** tabla, siempre con `WHERE` |
| DELETE | 1 borrado analizando cómo afectan las FK al borrar padre o hijo |
| Justificación | Normalización y anomalías; qué pasa internamente con `ON UPDATE CASCADE`; SQL frente a NoSQL de consistencia eventual |

### Modelo

```
clientes (id_cliente) ──< pedidos (id_pedido) ──< detalles_pedido (id_pedido, id_producto) >── productos (id_producto)
              ON UPDATE CASCADE           ON UPDATE CASCADE                    ON UPDATE CASCADE
              ON DELETE SET NULL          ON DELETE CASCADE                    ON DELETE RESTRICT
```

`detalles_pedido` es la tabla intermedia de la relación N:M pedido–producto.

### Revisión de tu script `Ejercicio_2.sql`

Tu script cumple todos los requisitos. Lo más destacable:

| Decisión | Por qué está bien |
|---|---|
| `DROP SCHEMA IF EXISTS cafeteria CASCADE` + `CREATE SCHEMA` | Script relanzable desde cero y separado de `bookings` |
| `NUMERIC(6,2)` para precios | Precisión exacta; nunca `real`/`float` para dinero (errores de redondeo binario) |
| Tres FK con `ON UPDATE CASCADE` | Supera el mínimo de dos |
| Reglas `ON DELETE` distintas según el significado | `SET NULL` conserva ventas si se da de baja un cliente; `CASCADE` borra líneas con su cabecera; `RESTRICT` impide borrar un producto ya vendido |
| `CHECK` en categoría, método de pago, estado, precio ≥ 0, cantidad > 0 | El motor rechaza valores imposibles |
| PK compuesta `(id_pedido, id_producto)` | Un producto aparece una vez por pedido; se acumula en `cantidad` |
| `precio_unitario` en el detalle | Precio histórico: subir el precio del catálogo no altera ventas pasadas |
| Consulta que compara `total` con la suma de líneas | Valida la consistencia de los datos cargados |
| Baja lógica (`activo = FALSE`) ante el `RESTRICT` | Solución de negocio realista en lugar de borrar |
| `DELETE` del pedido 1006 dentro de `BEGIN ... COMMIT` | Atomicidad: cabecera y líneas se borran juntas |

Puntos a mejorar:

> ⚠️ **En tu script**:
> 1. **UPDATE 3.3 y 3.4 deberían ir en la misma transacción.** Entre el cambio de cantidad del pedido 1008 y el recálculo del total, `pedidos.total` queda inconsistente. Si algo falla entre ambos, se queda así:
>    ```sql
>    BEGIN;
>    UPDATE detalles_pedido ... WHERE id_pedido = 1008 AND id_producto = 'CAF-002';
>    UPDATE pedidos ...         WHERE id_pedido = 1008;
>    COMMIT;
>    ```
> 2. **`pedidos.total` es un dato derivado** (se puede calcular desde las líneas). Guardarlo acelera las lecturas, pero obliga a mantenerlo sincronizado. Menciónalo en la justificación como decisión consciente (alternativas: calcularlo en una vista o mantenerlo con un trigger).
> 3. **`SET search_path TO cafeteria`** solo vale para la sesión actual. En la entrega, para que cada sentencia se entienda por sí sola, puedes cualificar los nombres (`cafeteria.productos`) o recordar que el script empieza fijando el `search_path`.
> 4. **IDs**: en un sistema real, `id_pedido` sería `GENERATED ALWAYS AS IDENTITY` (autonumérico). Los IDs manuales están bien aquí para controlar los datos de prueba.

### Lo que ocurre internamente con ON UPDATE CASCADE (resumen para estudiar)

1. Las FK se implementan con **triggers internos** del sistema.
2. El `UPDATE` sobre `productos` no modifica la fila en su sitio: por **MVCC** marca la versión antigua como obsoleta y escribe una nueva con el nuevo `id_producto`, y actualiza el índice de la PK.
3. Al terminar la sentencia, el trigger de cascada busca en `detalles_pedido` las filas con el `id_producto` antiguo y les aplica un `UPDATE` interno (nuevas versiones de fila).
4. Todo ocurre en **la misma transacción**, con bloqueos de fila: o se cambia todo o nada, y nadie ve un detalle apuntando a un producto inexistente.
5. Las versiones antiguas se limpian más tarde con `VACUUM`.

> Para que la búsqueda del paso 3 sea rápida conviene un índice cuya **primera** columna sea `id_producto`. La PK `(id_pedido, id_producto)` empieza por `id_pedido`, así que no sirve para esa búsqueda: con muchos pedidos, crea `CREATE INDEX ON detalles_pedido (id_producto);`. PostgreSQL **no** crea índices automáticamente en las columnas FK.

---

## 8. Justificación técnica (tabla para la entrega)

| Elemento de diseño | Propuesta técnica | Justificación relacional e impacto en rendimiento |
|---|---|---|
| Normalización | 4 tablas: `productos`, `clientes`, `pedidos`, `detalles_pedido` | Cada hecho se guarda una vez. Evita anomalías de inserción (dar de alta un producto sin pedido), actualización (un email repetido en muchas filas) y borrado (perder un cliente al borrar su único pedido) |
| `detalles_pedido` | Tabla intermedia con PK compuesta `(id_pedido, id_producto)` | Resuelve la relación N:M pedido–producto; impide líneas duplicadas y crea un índice para buscar las líneas de un pedido |
| Precios | `NUMERIC(6,2)` / `NUMERIC(8,2)` + `CHECK (>= 0)` | Aritmética decimal exacta para dinero; el motor rechaza importes negativos |
| `precio_unitario` | Precio copiado en la línea en el momento de la venta | Conserva el histórico aunque cambie el catálogo; no es redundancia sino otro hecho (precio de venta) |
| `pedidos.id_cliente` | FK `ON UPDATE CASCADE ON DELETE SET NULL`, columna nullable | Permite ventas a clientes no fidelizados y conserva el histórico si se da de baja un cliente |
| `detalles_pedido.id_pedido` | FK `ON UPDATE CASCADE ON DELETE CASCADE` | Una línea no tiene sentido sin su cabecera: se borra con ella |
| `detalles_pedido.id_producto` | FK `ON UPDATE CASCADE ON DELETE RESTRICT` | Un cambio de código se propaga a todas las ventas; no se puede borrar un producto vendido (se usa baja lógica `activo = FALSE`) |
| Dominios cerrados | `CHECK (... IN (...))` en categoría, método de pago y estado | Integridad garantizada por el motor, no por la aplicación |
| Operaciones de escritura | `UPDATE`/`DELETE` siempre con `WHERE` y en transacción cuando afectan a varias filas o tablas | Atomicidad: no quedan estados intermedios visibles (total desincronizado, cabecera sin líneas) |
| Motor | PostgreSQL (ACID) frente a NoSQL de consistencia eventual | Cobros: consistencia fuerte, FK, `CHECK` y bloqueos de fila evitan dobles cobros y stock negativo; Cassandra encaja en datos masivos tolerantes a retraso (logs, telemetría) |

---

## 9. Chuleta rápida

```sql
-- Agrupar
SELECT col, COUNT(*), SUM(x), ROUND(AVG(x), 2), MIN(x), MAX(x)
FROM t
GROUP BY col;                      -- toda columna no agregada va aquí
GROUP BY fecha::date               -- agrupar por día un timestamp

-- Insertar
INSERT INTO t (a, b) VALUES (1, 'x'), (2, 'y');
INSERT INTO t (a, b) SELECT ... FROM otra;
INSERT ... ON CONFLICT (pk) DO UPDATE SET b = EXCLUDED.b;
INSERT ... ON CONFLICT (pk) DO NOTHING;
INSERT ... RETURNING id;
CREATE TEMP TABLE copia AS SELECT * FROM t LIMIT 0;   -- solo estructura

-- Actualizar
UPDATE t SET b = 'z' WHERE a = 1;
UPDATE t SET b = o.b FROM otra o WHERE t.a = o.a;     -- UPDATE con "JOIN"

-- Borrar (hijos antes que padres)
DELETE FROM hija  WHERE padre_id = 1;
DELETE FROM padre WHERE id = 1;
DELETE ... RETURNING *;

-- Escritura segura
BEGIN;
UPDATE ... ;
SELECT ... ;          -- revisar
COMMIT;               -- o ROLLBACK;

-- FK con reglas
col tipo REFERENCES padre (id)
    ON UPDATE CASCADE
    ON DELETE CASCADE | SET NULL | RESTRICT | NO ACTION
```

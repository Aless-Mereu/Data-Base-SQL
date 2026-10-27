-- =====================================================================
-- Ejercicio 04 - Consultas 2: Operaciones CRUD 2
-- Caso práctico: cafetería "Espresso & Data"
-- Motor: PostgreSQL
-- =====================================================================

---------------------------------------------
-- 0. Preparación del esquema --
---------------------------------------------
-- Usamos un esquema propio para no mezclar con bookings y poder relanzar
-- el script desde cero tantas veces como sea necesario
DROP SCHEMA IF EXISTS cafeteria CASCADE;
CREATE SCHEMA cafeteria;
SET search_path TO cafeteria;

---------------------------------------------
-- 1. DDL: Creación de las tablas --
---------------------------------------------

-- 1.1 Productos: bebidas, repostería y café en grano
-- El id es un código de negocio (p.ej. 'GRA-001'), por eso tiene sentido
-- que pueda cambiar y propagarse con ON UPDATE CASCADE
CREATE TABLE productos (
    id_producto  VARCHAR(10)   PRIMARY KEY,
    nombre       VARCHAR(100)  NOT NULL,
    categoria    VARCHAR(20)   NOT NULL
                 CHECK (categoria IN ('bebida', 'reposteria', 'cafe_grano')),
    precio       NUMERIC(6,2)  NOT NULL CHECK (precio >= 0),
    stock        INTEGER       NOT NULL DEFAULT 0 CHECK (stock >= 0),
    activo       BOOLEAN       NOT NULL DEFAULT TRUE
);

-- 1.2 Clientes fidelizados
CREATE TABLE clientes (
    id_cliente   VARCHAR(10)   PRIMARY KEY,
    nombre       VARCHAR(50)   NOT NULL,
    apellidos    VARCHAR(100)  NOT NULL,
    email        VARCHAR(150)  NOT NULL UNIQUE,
    telefono     VARCHAR(15),
    fecha_alta   DATE          NOT NULL DEFAULT CURRENT_DATE,
    puntos       INTEGER       NOT NULL DEFAULT 0 CHECK (puntos >= 0)
);

-- 1.3 Pedidos (cabecera de la comanda)
-- id_cliente admite NULL: un cliente no fidelizado también puede comprar
CREATE TABLE pedidos (
    id_pedido    INTEGER       PRIMARY KEY,
    id_cliente   VARCHAR(10)
                 REFERENCES clientes (id_cliente)
                 ON UPDATE CASCADE      -- FK 1 con ON UPDATE CASCADE
                 ON DELETE SET NULL,    -- si se da de baja al cliente, el histórico de ventas se conserva
    fecha_pedido TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metodo_pago  VARCHAR(10)   NOT NULL
                 CHECK (metodo_pago IN ('efectivo', 'tarjeta', 'bizum')),
    estado       VARCHAR(10)   NOT NULL DEFAULT 'pendiente'
                 CHECK (estado IN ('pendiente', 'pagado', 'cancelado')),
    total        NUMERIC(8,2)  NOT NULL DEFAULT 0 CHECK (total >= 0)
);

-- 1.4 Detalles del pedido (tabla intermedia pedidos <-> productos)
-- PK compuesta: un producto aparece una sola vez por pedido (se acumula en cantidad)
-- precio_unitario guarda el precio en el momento de la venta (precio histórico)
CREATE TABLE detalles_pedido (
    id_pedido        INTEGER       NOT NULL
                     REFERENCES pedidos (id_pedido)
                     ON UPDATE CASCADE  -- FK 2 con ON UPDATE CASCADE
                     ON DELETE CASCADE, -- una línea no tiene sentido sin su cabecera
    id_producto      VARCHAR(10)   NOT NULL
                     REFERENCES productos (id_producto)
                     ON UPDATE CASCADE  -- FK 3 con ON UPDATE CASCADE
                     ON DELETE RESTRICT,-- no se puede borrar un producto ya vendido
    cantidad         INTEGER       NOT NULL CHECK (cantidad > 0),
    precio_unitario  NUMERIC(6,2)  NOT NULL CHECK (precio_unitario >= 0),
    PRIMARY KEY (id_pedido, id_producto)
);

---------------------------------------------
-- 2. DML: INSERT (respetando la jerarquía padres -> hijos) --
---------------------------------------------

-- 2.1 Productos (10 registros)
INSERT INTO productos (id_producto, nombre, categoria, precio, stock)
VALUES ('CAF-001', 'Espresso',                               'bebida',     1.60, 500)
     , ('CAF-002', 'Cappuccino',                             'bebida',     2.40, 400)
     , ('CAF-003', 'Flat White',                             'bebida',     2.80, 300)
     , ('CAF-004', 'Cold Brew',                              'bebida',     3.20, 120)
     , ('INF-001', 'Matcha Latte',                           'bebida',     3.50, 150)
     , ('REP-001', 'Croissant de mantequilla',               'reposteria', 1.90,  60)
     , ('REP-002', 'Cookie de chocolate',                    'reposteria', 2.20,  80)
     , ('REP-003', 'Tarta de queso (porción)',               'reposteria', 3.90,  24)
     , ('GRA-001', 'Café en grano Etiopía Yirgacheffe 250g', 'cafe_grano',14.50,  40)
     , ('GRA-002', 'Café en grano Colombia Huila 250g',      'cafe_grano',12.90,  35);

-- Validamos que los productos se han insertado correctamente
SELECT *
FROM productos;

-- 2.2 Clientes (10 registros)
INSERT INTO clientes (id_cliente, nombre, apellidos, email, telefono, fecha_alta, puntos)
VALUES ('CLI-001', 'Lucía',   'García Pérez',     'lucia.garcia@mail.com',    '600111222', '2026-01-15', 120)
     , ('CLI-002', 'Marcos',  'López Ruiz',       'marcos.lopez@mail.com',    '600222333', '2026-02-03',  45)
     , ('CLI-003', 'Elena',   'Martín Sanz',      'elena.martin@mail.com',    '600333444', '2026-02-20',  80)
     , ('CLI-004', 'Javier',  'Fernández Gil',    'javier.fdez@mail.com',     '600444555', '2026-03-11',  10)
     , ('CLI-005', 'Sara',    'Romero Díaz',      'sara.romero@mail.com',     '600555666', '2026-04-02', 200)
     , ('CLI-006', 'Pablo',   'Navarro Ortiz',    'pablo.navarro@mail.com',   '600666777', '2026-05-19',   0)
     , ('CLI-007', 'Carmen',  'Torres Molina',    'carmen.torres@mail.com',   '600777888', '2026-06-07',  35)
     , ('CLI-008', 'Diego',   'Ramos Castillo',   'diego.ramos@mail.com',     '600888999', '2026-07-23',  15)
     , ('CLI-009', 'Irene',   'Vega Morales',     'irene.vega@mail.com',      '600999000', '2026-08-30',  60)
     , ('CLI-010', 'Andrés',  'Herrera Blanco',   'andres.herrera@mail.com',  '601000111', '2026-09-14',   5);

-- Validamos que los clientes se han insertado correctamente
SELECT *
FROM clientes;

-- 2.3 Pedidos (10 registros). El total es la suma de sus líneas de detalle
INSERT INTO pedidos (id_pedido, id_cliente, fecha_pedido, metodo_pago, estado, total)
VALUES (1001, 'CLI-001', '2026-10-13 08:05:00', 'tarjeta',  'pagado',     5.10)
     , (1002, 'CLI-002', '2026-10-13 09:30:00', 'efectivo', 'pagado',     6.30)
     , (1003, 'CLI-005', '2026-10-13 11:15:00', 'tarjeta',  'pagado',    29.00)
     , (1004, 'CLI-003', '2026-10-14 08:45:00', 'bizum',    'pagado',    10.00)
     , (1005, 'CLI-007', '2026-10-14 10:20:00', 'tarjeta',  'pagado',    16.10)
     , (1006, 'CLI-004', '2026-10-15 12:00:00', 'efectivo', 'cancelado',  5.40)
     , (1007, 'CLI-009', '2026-10-15 16:40:00', 'tarjeta',  'pagado',    16.10)
     , (1008, 'CLI-006', '2026-10-16 09:10:00', 'bizum',    'pendiente',  7.20)
     , (1009, 'CLI-001', '2026-10-16 17:25:00', 'tarjeta',  'pagado',    27.40)
     , (1010, NULL,      '2026-10-17 08:30:00', 'efectivo', 'pagado',     3.80);

-- Validamos que los pedidos se han insertado correctamente
SELECT *
FROM pedidos;

-- 2.4 Detalles del pedido (18 registros)
INSERT INTO detalles_pedido (id_pedido, id_producto, cantidad, precio_unitario)
VALUES (1001, 'CAF-001', 2,  1.60), (1001, 'REP-001', 1,  1.90)
     , (1002, 'CAF-002', 1,  2.40), (1002, 'REP-003', 1,  3.90)
     , (1003, 'GRA-001', 2, 14.50)
     , (1004, 'CAF-003', 2,  2.80), (1004, 'REP-002', 2,  2.20)
     , (1005, 'CAF-004', 1,  3.20), (1005, 'GRA-002', 1, 12.90)
     , (1006, 'INF-001', 1,  3.50), (1006, 'REP-001', 1,  1.90)
     , (1007, 'GRA-001', 1, 14.50), (1007, 'CAF-001', 1,  1.60)
     , (1008, 'CAF-002', 3,  2.40)
     , (1009, 'GRA-001', 1, 14.50), (1009, 'GRA-002', 1, 12.90)
     , (1010, 'CAF-001', 1,  1.60), (1010, 'REP-002', 1,  2.20);

-- Validamos la consistencia: el total de cada cabecera coincide con la suma de sus líneas
SELECT pe.id_pedido,
       pe.total,
       SUM(dp.cantidad * dp.precio_unitario) AS total_lineas,
       pe.total = SUM(dp.cantidad * dp.precio_unitario) AS consistente
FROM pedidos pe
INNER JOIN detalles_pedido dp ON pe.id_pedido = dp.id_pedido
GROUP BY pe.id_pedido, pe.total
ORDER BY pe.id_pedido;

---------------------------------------------
-- 3. DML: UPDATE (al menos uno por tabla, siempre acotado con WHERE) --
---------------------------------------------

-- 3.1 Productos (a): subida del 5% en el café en grano
-- Las ventas ya realizadas no cambian porque guardan su precio_unitario histórico
UPDATE productos pr
SET precio = ROUND(pr.precio * 1.05, 2)
WHERE pr.categoria = 'cafe_grano';

-- Validamos que los precios se han actualizado correctamente
SELECT *
FROM productos
WHERE categoria = 'cafe_grano';

-- 3.1 Productos (b): cambio del identificador de un producto ya vendido
-- 'GRA-001' aparece en los pedidos 1003, 1007 y 1009
SELECT *
FROM detalles_pedido
WHERE id_producto = 'GRA-001';

UPDATE productos pr
SET id_producto = 'GRA-ETH-01'
WHERE pr.id_producto = 'GRA-001';

-- Validamos que ON UPDATE CASCADE ha propagado el nuevo id a detalles_pedido
SELECT dp.*, pr.nombre
FROM detalles_pedido dp
INNER JOIN productos pr ON dp.id_producto = pr.id_producto
WHERE dp.id_producto = 'GRA-ETH-01';

-- 3.2 Clientes: un cliente cambia su email
UPDATE clientes cl
SET email = 'javier.fernandez.gil@mail.com'
WHERE cl.id_cliente = 'CLI-004';

-- Validamos que el email se ha actualizado correctamente
SELECT *
FROM clientes
WHERE id_cliente = 'CLI-004';

-- 3.3 Detalles del pedido: en el pedido 1008 el cliente pide 2 cappuccinos en vez de 3
UPDATE detalles_pedido dp
SET cantidad = 2
WHERE dp.id_pedido = 1008
  AND dp.id_producto = 'CAF-002';

-- Validamos que la línea se ha actualizado correctamente
SELECT *
FROM detalles_pedido
WHERE id_pedido = 1008;

-- 3.4 Pedidos: recalculamos el total del pedido 1008 a partir de sus líneas y lo cobramos
UPDATE pedidos pe
SET total  = (SELECT SUM(dp.cantidad * dp.precio_unitario)
              FROM detalles_pedido dp
              WHERE dp.id_pedido = pe.id_pedido),
    estado = 'pagado'
WHERE pe.id_pedido = 1008;

-- Validamos que el pedido se ha actualizado correctamente (total esperado 4.80)
SELECT *
FROM pedidos
WHERE id_pedido = 1008;

---------------------------------------------
-- 4. DML: DELETE con análisis de integridad referencial --
---------------------------------------------

-- 4.1 Borrado de un PADRE con hijos protegidos (ON DELETE RESTRICT)
-- 'REP-003' se vendió en el pedido 1002. Si intentamos borrarlo:
--
--   DELETE FROM productos pr WHERE pr.id_producto = 'REP-003';
--
-- Error que obtenemos:
--   update o delete en «productos» viola la llave foránea
--   «detalles_pedido_id_producto_fkey» en la tabla «detalles_pedido»
--
-- Es el comportamiento deseado: no podemos perder qué se vendió en un pedido.
-- La solución de negocio es dar de baja lógica el producto, no borrarlo:
UPDATE productos pr
SET activo = FALSE
WHERE pr.id_producto = 'REP-003';

-- 4.2 Borrado de un PADRE con hijos dependientes (ON DELETE CASCADE)
-- Eliminamos el pedido cancelado 1006. Antes, comprobamos qué se verá afectado:
SELECT pe.id_pedido, pe.estado, dp.id_producto, dp.cantidad
FROM pedidos pe
INNER JOIN detalles_pedido dp ON pe.id_pedido = dp.id_pedido
WHERE pe.id_pedido = 1006;

-- Lo hacemos dentro de una transacción (atomicidad: o se borra todo o nada)
BEGIN;

DELETE FROM pedidos pe
WHERE pe.id_pedido = 1006
  AND pe.estado = 'cancelado';

-- Validamos que se ha borrado la cabecera y, en cascada, sus 2 líneas de detalle
SELECT *
FROM pedidos
WHERE id_pedido = 1006;

SELECT *
FROM detalles_pedido
WHERE id_pedido = 1006;

COMMIT;

-- Nota: el cliente CLI-004 y los productos INF-001 / REP-001 NO se ven afectados,
-- porque son padres del registro borrado, no hijos.

/*
=====================================================================
JUSTIFICACIÓN TÉCNICA
=====================================================================

1) ¿Por qué normalizar en 4 tablas en lugar de una única tabla desnormalizada?

   En una tabla única cada fila sería "una línea de un pedido" y repetiría en
   cada fila los datos del cliente, la cabecera del pedido y el producto.
   Esto provoca tres tipos de anomalías:

   - Inserción: no podríamos dar de alta un producto nuevo o un cliente que
     aún no ha comprado sin inventar un pedido ficticio (o dejar media fila a NULL).
   - Actualización: si un cliente cambia su email o un producto su nombre,
     habría que modificar todas las filas donde aparece; basta con olvidar una
     para tener datos contradictorios (el mismo cliente con dos emails).
   - Borrado: al borrar el único pedido de un cliente perderíamos también los
     datos del cliente, o al borrar la última venta de un producto, el producto.

   Con 4 tablas cada hecho se guarda una sola vez (cliente en clientes,
   producto en productos, cabecera en pedidos, y la relación N:M pedido-producto
   en detalles_pedido). Las PK impiden duplicados, las FK impiden referencias
   huérfanas y los CHECK impiden valores imposibles (precios negativos,
   métodos de pago no válidos). Además, precio_unitario en detalles_pedido
   no es redundante: es el precio en el momento de la venta, que debe
   conservarse aunque el precio del catálogo cambie (ver UPDATE 3.1.a).

2) ¿Qué ocurre internamente al cambiar id_producto con ON UPDATE CASCADE?

   - PostgreSQL implementa las FK mediante triggers internos del sistema
     (RI_FKey_cascade_upd en la tabla padre, RI_FKey_check en la hija).
   - Al ejecutar el UPDATE sobre productos, PostgreSQL (por MVCC) no modifica
     la fila en el sitio: marca la versión antigua como obsoleta y escribe
     una nueva versión de la fila con 'GRA-ETH-01'. También actualiza el
     índice de la PK.
   - Al terminar la sentencia se dispara el trigger de cascada, que busca
     (usando el índice de la PK compuesta de detalles_pedido) todas las filas
     con id_producto = 'GRA-001' y ejecuta sobre ellas un UPDATE interno
     cambiándolas a 'GRA-ETH-01' (de nuevo, nuevas versiones de fila).
   - Todo ocurre dentro de la misma transacción: las filas afectadas quedan
     bloqueadas (row locks) y, si cualquier paso falla, se deshace todo.
     Nunca existe un instante visible en que detalles_pedido apunte a un
     producto inexistente. Otras sesiones siguen viendo los valores antiguos
     hasta el COMMIT.
   - Las versiones antiguas de las filas se limpiarán después con VACUUM.

3) SQL relacional (PostgreSQL) frente a NoSQL de consistencia eventual
   (Cassandra) para cobrar comandas en tiempo real

   - PostgreSQL es ACID: una comanda (cabecera + líneas + descuento de stock
     + cobro) se confirma entera o no se confirma; tras el COMMIT, cualquier
     lectura ve el dato confirmado (consistencia fuerte) y es duradero (WAL).
   - La concurrencia se gestiona con MVCC y bloqueos de fila: dos camareros
     cobrando el mismo pedido o vendiendo la última tarta de queso no pueden
     pisarse; uno espera o falla y se reintenta. Las FK y los CHECK los
     valida el propio motor.
   - Cassandra prioriza disponibilidad y escalado horizontal (AP en el
     teorema CAP): una escritura puede llegar a un nodo y tardar en
     propagarse; durante ese intervalo otra lectura puede ver un estado
     antiguo. No tiene FK ni transacciones multi-tabla, y los conflictos
     se resuelven por "last write wins" (marca temporal), lo que puede
     provocar dobles cobros, stock negativo o pedidos con líneas perdidas.
   - Para cobros, donde un error es dinero, la consistencia fuerte es
     prioritaria. Cassandra sería adecuada para datos masivos donde un
     ligero retraso no importa (p.ej. logs de eventos o telemetría de las
     cafeteras), no para el núcleo transaccional.
*/

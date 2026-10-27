-- Actualizaciones de precios a valores más reales de la base de datos demodb
/*
PRECAUCIÓN: estas actualizaciones son "pesadas" por lo que llevará 
tiempo que el motor de base de datos termine de ejecutarlas.
*/
-- Actualización de precios en bookings.segments
BEGIN;
  UPDATE  bookings.segments
  SET     price = (price/25)
COMMIT; --ROLLBACK;
-- Actualización de precios en bookins.bookings
BEGIN;
  UPDATE  bookings.bookings
  SET     total_amount = (total_amount/25)
COMMIT; --ROLLBACK;
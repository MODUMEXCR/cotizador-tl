-- =====================================================================
-- Cotizador Thin Laminates — 24 · Interior de lockers Costa Rica (LATAM)
-- Interior de locker en CR: Gris (estándar) + Negro + Blanco (todos SIN recargo; el +10% se quitó).
-- Correr UNA vez. No afecta cotizaciones (la línea guarda el color por nombre).
-- =====================================================================
delete from public.color where region = 'LATAM' and ambito = 'locker_interior';

insert into public.color (nombre,grupo,ambito,region,tiempo_especial) values
  ('Gris','INT','locker_interior','LATAM',false),
  ('Negro','INT','locker_interior','LATAM',false),
  ('Blanco','INT','locker_interior','LATAM',false);

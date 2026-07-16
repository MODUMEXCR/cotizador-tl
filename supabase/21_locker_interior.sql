-- =====================================================================
-- Cotizador Thin Laminates — 21 · Interior de lockers por región
-- SOLO cambia el interior de lockers (no toca cubiertas, banca ni frente):
--   México (region 'MXN')        = Alúmina (estándar) + Negro + Blanco (+10%)
--   Costa Rica/LATAM (region 'LATAM') = solo Alúmina
-- Correr UNA vez. No afecta cotizaciones (la línea guarda el color por nombre).
-- =====================================================================
delete from public.color where ambito = 'locker_interior';

insert into public.color (nombre,grupo,ambito,region,tiempo_especial) values
  ('Alúmina','INT','locker_interior','MXN',false),
  ('Negro','INT','locker_interior','MXN',false),
  ('Blanco','INT','locker_interior','MXN',false),
  ('Alúmina','INT','locker_interior','LATAM',false);

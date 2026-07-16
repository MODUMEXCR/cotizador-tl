-- =====================================================================
-- Cotizador Thin Laminates — 23 · Nombres de colores Costa Rica (LATAM)
-- Los colores de CR son los MISMOS físicos que México, con otro nombre:
--   Gris Metalizado→Inox Satín, Alúmina→Gris, Walnut Heights→Ámbar Wood, Skyline Walnut→Nogal Grafito
--   (Negro, Blanco, Grafito Nocturno y exteriores = mismo nombre)
-- Cubierta interior y banca en CR ya estaban con nombres CR; aquí se corrigen locker frente e interior.
-- Correr UNA vez. No afecta cotizaciones (la línea guarda el color por nombre).
-- =====================================================================
delete from public.color where region = 'LATAM' and ambito in ('locker_frente','locker_interior');

insert into public.color (nombre,grupo,ambito,region,tiempo_especial) values
  ('Negro','G1','locker_frente','LATAM',false),
  ('Inox Satín','G1','locker_frente','LATAM',false),
  ('Blanco','G1','locker_frente','LATAM',false),
  ('Gris','G1','locker_frente','LATAM',false),
  ('Grafito Nocturno','G1','locker_frente','LATAM',false),
  ('Ámbar Wood','G1','locker_frente','LATAM',false),
  ('Nogal Grafito','G1','locker_frente','LATAM',false),
  ('Gris','INT','locker_interior','LATAM',false);

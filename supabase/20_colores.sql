-- =====================================================================
-- Cotizador Thin Laminates — 20 · Colores completos y CORRECTOS
-- Reinserta TODOS los colores con el mapeo ORIGINAL (tal como los pasó Dayanna):
--   México (region 'MXN')        = Lista A: Gris Metalizado, Alúmina, Walnut Heights, Skyline Walnut, Calcutta, White Marble...
--   Costa Rica/LATAM (region 'LATAM') = Lista B: Ámbar Wood, Nogal Grafito, Inox Satín, Gris...
-- Sirve para llenar el color de locker (locker_frente) que salía vacío. Correr UNA vez.
-- No afecta cotizaciones (la línea guarda el color por nombre).
-- Incluye los nombres de Costa Rica en locker (Inox Satín, Gris, Ámbar Wood, Nogal Grafito; interior = Gris).
-- Este archivo es el ÚNICO que necesitas para dejar los colores bien (reemplaza a 21 y 23).
-- =====================================================================
-- Asegura TODAS las columnas por si la base viene de una versión vieja
-- (evita "column region/grupo/ambito ... does not exist")
alter table public.color add column if not exists nombre text;
alter table public.color add column if not exists grupo text;
alter table public.color add column if not exists ambito text;
alter table public.color add column if not exists region text not null default 'MXN';
alter table public.color add column if not exists tiempo_especial boolean not null default false;
alter table public.color add column if not exists activo boolean not null default true;

delete from public.color;

insert into public.color (nombre,grupo,ambito,region,tiempo_especial) values
  -- ===== MÉXICO (region 'MXN') = Lista A =====
  ('Negro','G1','cubierta_int','MXN',false),
  ('Gris Metalizado','G1','cubierta_int','MXN',false),
  ('Blanco','G1','cubierta_int','MXN',false),
  ('Alúmina','G1','cubierta_int','MXN',false),
  ('Grafito Nocturno','G1','cubierta_int','MXN',false),
  ('Walnut Heights','G1','cubierta_int','MXN',false),
  ('Skyline Walnut','G1','cubierta_int','MXN',false),
  ('Calcutta Marble','G2','cubierta_int','MXN',false),
  ('White Marble','G3','cubierta_int','MXN',false),
  ('Roble Lineal','G4','cubierta_ext','MXN',false),
  ('Italian Walnut','G4','cubierta_ext','MXN',false),
  ('Atenas','G4','cubierta_ext','MXN',false),
  ('Tiziano','G4','cubierta_ext','MXN',false),
  ('Industrial Concrete','G4','cubierta_ext','MXN',false),
  ('Dark Steel','G4','cubierta_ext','MXN',true),
  ('Vanilla','G4','cubierta_ext','MXN',true),
  ('Negro','G1','locker_frente','MXN',false),
  ('Gris Metalizado','G1','locker_frente','MXN',false),
  ('Blanco','G1','locker_frente','MXN',false),
  ('Alúmina','G1','locker_frente','MXN',false),
  ('Grafito Nocturno','G1','locker_frente','MXN',false),
  ('Walnut Heights','G1','locker_frente','MXN',false),
  ('Skyline Walnut','G1','locker_frente','MXN',false),
  ('Alúmina','INT','locker_interior','MXN',false),
  ('Negro','INT','locker_interior','MXN',false),
  ('Blanco','INT','locker_interior','MXN',false),
  ('Negro','G1','banca','MXN',false),
  ('Gris Metalizado','G1','banca','MXN',false),
  ('Blanco','G1','banca','MXN',false),
  ('Alúmina','G1','banca','MXN',false),
  ('Grafito Nocturno','G1','banca','MXN',false),
  ('Walnut Heights','G1','banca','MXN',false),
  ('Skyline Walnut','G1','banca','MXN',false),
  -- ===== COSTA RICA / LATAM (region 'LATAM') = Lista B =====
  ('Blanco','G1','cubierta_int','LATAM',false),
  ('Gris','G1','cubierta_int','LATAM',false),
  ('Grafito Nocturno','G1','cubierta_int','LATAM',false),
  ('Negro','G1','cubierta_int','LATAM',false),
  ('Ámbar Wood','G1','cubierta_int','LATAM',false),
  ('Nogal Grafito','G1','cubierta_int','LATAM',false),
  ('Inox Satín','G1','cubierta_int','LATAM',false),
  ('Roble Lineal','G4','cubierta_ext','LATAM',false),
  ('Italian Walnut','G4','cubierta_ext','LATAM',false),
  ('Atenas','G4','cubierta_ext','LATAM',false),
  ('Tiziano','G4','cubierta_ext','LATAM',false),
  ('Industrial Concrete','G4','cubierta_ext','LATAM',false),
  ('Dark Steel','G4','cubierta_ext','LATAM',true),
  ('Vanilla','G4','cubierta_ext','LATAM',true),
  ('Negro','G1','locker_frente','LATAM',false),
  ('Inox Satín','G1','locker_frente','LATAM',false),
  ('Blanco','G1','locker_frente','LATAM',false),
  ('Gris','G1','locker_frente','LATAM',false),
  ('Grafito Nocturno','G1','locker_frente','LATAM',false),
  ('Ámbar Wood','G1','locker_frente','LATAM',false),
  ('Nogal Grafito','G1','locker_frente','LATAM',false),
  ('Gris','INT','locker_interior','LATAM',false),
  ('Blanco','G1','banca','LATAM',false),
  ('Gris','G1','banca','LATAM',false),
  ('Grafito Nocturno','G1','banca','LATAM',false),
  ('Negro','G1','banca','LATAM',false),
  ('Ámbar Wood','G1','banca','LATAM',false),
  ('Nogal Grafito','G1','banca','LATAM',false),
  ('Inox Satín','G1','banca','LATAM',false);

-- =====================================================================
-- Cotizador Thin Laminates — 04 · Usuarios y distribuidores (arranque)
-- Correr DESPUÉS de 01, 02 y 03.
-- =====================================================================

-- 1) Distribuidores de ejemplo (el % es el descuento por defecto del distribuidor).
insert into public.distribuidor (nombre, contacto, email, telefono, ubicacion, descuento_pct) values
  ('REQUIEZ',  'Guadalupe Murillo', null, null, 'México', 30),
  ('RATTAN',   'Roberto',           null, null, 'México', 20),
  ('SOLARE',   'Mayra Mancia',      null, null, 'México', 50)
on conflict do nothing;

-- 2) PRIMER SUPER ADMIN
-- Supabase Auth maneja el email + contraseña. Pasos:
--   a) En el panel de Supabase: Authentication > Users > "Add user"
--      (o que la persona se registre desde la app). Anota el email.
--   b) El trigger on_auth_user_created crea automáticamente su fila en profiles con rol 'Distribuidor'.
--   c) Eleva ese usuario a Super Admin corriendo (cambia el email):
--
-- update public.profiles
--   set rol = 'Super Admin', nombre = 'Dayanna Lizano'
--   where email = 'dlizano@modumex.com';
--
-- 3) Para asignar un distribuidor a un usuario Distribuidor (lo hace el Super Admin):
-- update public.profiles
--   set rol = 'Distribuidor',
--       distribuidor_id = (select distribuidor_id from public.distribuidor where nombre = 'REQUIEZ')
--   where email = 'comprasrequiez@ejemplo.com';
--
-- 4) Para crear un Administrador (ve todo, edita precios, NO gestiona otros usuarios):
-- update public.profiles set rol = 'Administrador' where email = 'admin@modumex.com';

-- =====================================================================
-- Cotizador Thin Laminates — 10 · Permitir que el Administrador rechace (elimine)
-- cuentas de distribuidor que no se autorizan. Correr en el SQL Editor.
-- =====================================================================
drop policy if exists profiles_delete on public.profiles;
create policy profiles_delete on public.profiles for delete
  using ( public.es_super() or (public.es_admin() and rol = 'Distribuidor') );

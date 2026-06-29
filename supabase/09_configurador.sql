-- =====================================================================
-- Cotizador Thin Laminates — 09 · Configurador (columna es_extra + tabla color)
-- Correr en el SQL Editor ANTES de re-ejecutar 03_seed.sql.
-- =====================================================================

-- Marca los productos que son "extras" de locker (se suman al precio del locker).
alter table public.producto add column if not exists es_extra boolean not null default false;

-- Catálogo de colores. El GRUPO (G1..G4) define el precio de la cubierta; el ÁMBITO
-- dice dónde aplica (cubierta interior/exterior, frente o interior de locker, banca).
create table if not exists public.color (
  color_id        bigint generated always as identity primary key,
  nombre          text not null,
  grupo           text not null,                 -- 'G1','G2','G3','G4','INT'
  ambito          text not null,                 -- 'cubierta_int','cubierta_ext','locker_frente','locker_interior','banca'
  tiempo_especial boolean not null default false,
  activo          boolean not null default true
);

alter table public.color enable row level security;

-- Leer: cualquier usuario logueado. Modificar: Administrador y Super Admin.
do $$
begin
  if not exists (select 1 from pg_policies where tablename='color' and policyname='color_select') then
    create policy color_select on public.color for select using ( auth.uid() is not null );
  end if;
  if not exists (select 1 from pg_policies where tablename='color' and policyname='color_modify') then
    create policy color_modify on public.color for all using ( public.es_admin() ) with check ( public.es_admin() );
  end if;
end $$;

-- =====================================================================
-- Cotizador Thin Laminates — 11 · Regiones MXN / LATAM
-- Correr en el SQL Editor. Luego RE-correr 03_seed.sql (marca colores región).
--   · México            -> región MXN  (precios en pesos, IVA 16% por defecto)
--   · cualquier otro país-> región LATAM (precios = MXN ÷ divisor, en USD, IVA 0% por defecto)
-- =====================================================================

-- País de la empresa distribuidora (define la región).
alter table public.distribuidor add column if not exists pais text not null default 'México';

-- Región del color (los actuales son MXN; los LATAM se siembran aparte).
alter table public.color add column if not exists region text not null default 'MXN';

-- Configuración editable (clave/valor). Aquí vive el divisor USD para LATAM.
create table if not exists public.config (
  clave text primary key,
  valor text not null
);
insert into public.config (clave, valor) values ('divisor_usd', '17') on conflict (clave) do nothing;

alter table public.config enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where tablename='config' and policyname='config_select') then
    create policy config_select on public.config for select using ( auth.uid() is not null );
  end if;
  if not exists (select 1 from pg_policies where tablename='config' and policyname='config_modify') then
    create policy config_modify on public.config for all using ( public.es_admin() ) with check ( public.es_admin() );
  end if;
end $$;

-- Las empresas demo existentes son de México.
update public.distribuidor set pais = 'México' where pais is null or pais = '';

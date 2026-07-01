-- =====================================================================
-- Cotizador Thin Laminates — 15 · Tanda 2: consecutivo + descuentos por familia
-- Correr una vez en el SQL Editor.
-- =====================================================================

-- Consecutivo de folio (temporal, editable desde Precios). Empieza en 1000.
insert into public.config (clave, valor) values ('folio_consecutivo', '1000') on conflict (clave) do nothing;

-- Descuento por distribuidor POR FAMILIA (ej. REQUIEZ: 20% cubiertas, 23% lockers).
-- Si no hay fila para una familia, se usa el descuento_pct general del distribuidor.
create table if not exists public.distribuidor_descuento (
  distribuidor_id bigint not null references public.distribuidor(distribuidor_id) on delete cascade,
  familia_codigo  text   not null references public.familia(codigo),
  descuento_pct   numeric(5,2) not null default 0,
  primary key (distribuidor_id, familia_codigo)
);

alter table public.distribuidor_descuento enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where tablename='distribuidor_descuento' and policyname='dd_select') then
    create policy dd_select on public.distribuidor_descuento for select
      using ( public.puede_ver_todo() or distribuidor_id = public.mi_distribuidor() );
  end if;
  if not exists (select 1 from pg_policies where tablename='distribuidor_descuento' and policyname='dd_modify') then
    create policy dd_modify on public.distribuidor_descuento for all
      using ( public.es_admin() ) with check ( public.es_admin() );
  end if;
end $$;

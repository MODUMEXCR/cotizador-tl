-- =====================================================================
-- Cotizador Thin Laminates — 12 · Rol Vendedor + Región (México/LATAM/Costa Rica)
-- Correr en el SQL Editor. Luego RE-correr 03_seed.sql (colores LATAM).
-- =====================================================================

-- ---------- Rol Vendedor ----------
alter table public.profiles drop constraint if exists profiles_rol_check;
alter table public.profiles add  constraint profiles_rol_check
  check (rol in ('Super Admin','Administrador','Vendedor','Distribuidor'));

-- ---------- Región explícita en la empresa distribuidora ----------
alter table public.distribuidor add column if not exists region text not null default 'México';
alter table public.distribuidor drop constraint if exists distribuidor_region_check;
alter table public.distribuidor add  constraint distribuidor_region_check
  check (region in ('México','LATAM','Costa Rica'));
-- Migra las existentes según su país (México=México, resto=LATAM).
update public.distribuidor
   set region = case when lower(coalesce(pais,'')) in ('méxico','mexico') then 'México' else 'LATAM' end;

-- ---------- Config: multiplicador colones (USD × mult = CRC) ----------
insert into public.config (clave, valor) values ('multiplicador_crc', '490') on conflict (clave) do nothing;

-- ---------- Helper: puede ver todo (Super, Admin, Vendedor) ----------
create or replace function public.puede_ver_todo() returns boolean
  language sql security definer stable set search_path = public as
$$ select coalesce(public.mi_rol() in ('Super Admin','Administrador','Vendedor'), false) $$;

-- ---------- Ajustar RLS para incluir al Vendedor (ve/gestiona todo menos precios/descuentos) ----------
-- COTIZACIONES: Vendedor ve y crea/edita todas.
drop policy if exists cot_select on public.cotizacion;
drop policy if exists cot_insert on public.cotizacion;
drop policy if exists cot_update on public.cotizacion;
drop policy if exists cot_delete on public.cotizacion;
create policy cot_select on public.cotizacion for select
  using ( public.puede_ver_todo() or distribuidor_id = public.mi_distribuidor() );
create policy cot_insert on public.cotizacion for insert
  with check ( public.puede_ver_todo() or distribuidor_id = public.mi_distribuidor() );
create policy cot_update on public.cotizacion for update
  using ( public.puede_ver_todo() or distribuidor_id = public.mi_distribuidor() )
  with check ( public.puede_ver_todo() or distribuidor_id = public.mi_distribuidor() );
create policy cot_delete on public.cotizacion for delete
  using ( public.puede_ver_todo() or distribuidor_id = public.mi_distribuidor() );

-- LÍNEAS: heredan (Vendedor incluido)
drop policy if exists cotlinea_all on public.cotizacion_linea;
create policy cotlinea_all on public.cotizacion_linea for all
  using ( exists (select 1 from public.cotizacion c where c.cotizacion_id = cotizacion_linea.cotizacion_id
                  and (public.puede_ver_todo() or c.distribuidor_id = public.mi_distribuidor())) )
  with check ( exists (select 1 from public.cotizacion c where c.cotizacion_id = cotizacion_linea.cotizacion_id
                  and (public.puede_ver_todo() or c.distribuidor_id = public.mi_distribuidor())) );

-- DISTRIBUIDOR: Vendedor VE todas (para cotizar/autorizar); MODIFICAR (incl. descuento) solo Admin/Super.
drop policy if exists distrib_select on public.distribuidor;
create policy distrib_select on public.distribuidor for select
  using ( public.puede_ver_todo() or distribuidor_id = public.mi_distribuidor() );

-- PROFILES: Vendedor puede ver/gestionar (autorizar) cuentas de rol 'Distribuidor'.
drop policy if exists profiles_select on public.profiles;
drop policy if exists profiles_insert on public.profiles;
drop policy if exists profiles_update on public.profiles;
drop policy if exists profiles_delete on public.profiles;
create policy profiles_select on public.profiles for select
  using ( public.es_super() or id = auth.uid() or (public.puede_ver_todo() and rol = 'Distribuidor') );
create policy profiles_insert on public.profiles for insert
  with check ( public.es_super() or (public.puede_ver_todo() and rol = 'Distribuidor') );
create policy profiles_update on public.profiles for update
  using ( public.es_super() or id = auth.uid() or (public.puede_ver_todo() and rol = 'Distribuidor') )
  with check ( public.es_super() or id = auth.uid() or (public.puede_ver_todo() and rol = 'Distribuidor') );
create policy profiles_delete on public.profiles for delete
  using ( public.es_super() or (public.puede_ver_todo() and rol = 'Distribuidor') );

-- El trigger proteger_profile: el Vendedor solo gestiona Distribuidores (igual que Admin).
create or replace function public.proteger_profile() returns trigger
  language plpgsql security definer set search_path = public as
$$
begin
  if auth.uid() is null then return new; end if;
  if public.es_super() then return new; end if;
  if public.puede_ver_todo() then            -- Administrador o Vendedor
    if (old.rol <> 'Distribuidor') or (new.rol <> 'Distribuidor') then
      raise exception 'Solo puedes gestionar usuarios de rol Distribuidor.';
    end if;
    return new;
  end if;
  if (new.rol is distinct from old.rol) or (new.distribuidor_id is distinct from old.distribuidor_id) then
    raise exception 'Solo el Super Admin puede cambiar rol o distribuidor.';
  end if;
  return new;
end $$;

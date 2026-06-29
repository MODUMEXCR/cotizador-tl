-- =====================================================================
-- Cotizador Thin Laminates — Supabase — 02 · Row Level Security (RLS)
-- Correr después de 01_schema.sql.
--
-- REGLAS (las pedidas por Dayanna):
--   · Distribuidor   -> SOLO ve/crea/edita sus propias cotizaciones; filtra por fecha.
--   · Administrador  -> ve TODAS las cotizaciones (filtra por fecha o distribuidor);
--                       PUEDE modificar precios (individual o grupal);
--                       en usuarios SOLO edita su propia ficha (su contraseña, vía Auth).
--   · Super Admin    -> ve y edita TODO, incluidos usuarios y distribuidores.
--
-- La seguridad real vive aquí (en Postgres), no en el navegador: aunque alguien
-- manipule el cliente Blazor, estas políticas se aplican del lado del servidor.
-- =====================================================================

-- ---------- Helpers (SECURITY DEFINER: leen profiles SIN gatillar RLS -> sin recursión) ----------
create or replace function public.mi_rol() returns text
  language sql security definer stable set search_path = public as
$$ select rol from public.profiles where id = auth.uid() $$;

create or replace function public.mi_distribuidor() returns bigint
  language sql security definer stable set search_path = public as
$$ select distribuidor_id from public.profiles where id = auth.uid() $$;

create or replace function public.es_admin() returns boolean
  language sql security definer stable set search_path = public as
$$ select coalesce(public.mi_rol() in ('Super Admin','Administrador'), false) $$;

create or replace function public.es_super() returns boolean
  language sql security definer stable set search_path = public as
$$ select coalesce(public.mi_rol() = 'Super Admin', false) $$;

-- ---------- Habilitar RLS ----------
alter table public.familia          enable row level security;
alter table public.producto         enable row level security;
alter table public.producto_precio  enable row level security;
alter table public.precio_log       enable row level security;
alter table public.distribuidor     enable row level security;
alter table public.profiles         enable row level security;
alter table public.cotizacion       enable row level security;
alter table public.cotizacion_linea enable row level security;
alter table public.color            enable row level security;

-- ---------- PROFILES (usuarios) ----------
-- Jerarquía:
--   · Super Admin -> gestiona CUALQUIER usuario (incluidos administradores).
--   · Administrador -> gestiona SOLO usuarios de rol 'Distribuidor' (los puede ver,
--     crear y asignarles distribuidor); NO puede crear/editar admins ni super admins.
--   · Cada usuario -> ve y edita su PROPIA ficha (la contraseña va por Supabase Auth).
create policy profiles_select on public.profiles for select
  using ( public.es_super()
          or id = auth.uid()
          or (public.es_admin() and rol = 'Distribuidor') );

-- Crear: super cualquier perfil; admin solo perfiles de rol 'Distribuidor'.
create policy profiles_insert on public.profiles for insert
  with check ( public.es_super()
               or (public.es_admin() and rol = 'Distribuidor') );

-- Editar: super todos; admin solo perfiles de distribuidor; cada quien su propia ficha.
create policy profiles_update on public.profiles for update
  using ( public.es_super()
          or id = auth.uid()
          or (public.es_admin() and rol = 'Distribuidor') )
  with check ( public.es_super()
               or id = auth.uid()
               or (public.es_admin() and rol = 'Distribuidor') );

-- Borrar usuarios: solo Super Admin.
create policy profiles_delete on public.profiles for delete
  using ( public.es_super() );

-- Evitar que un usuario no-super se auto-escale rol o cambie su distribuidor.
create or replace function public.proteger_profile() returns trigger
  language plpgsql security definer set search_path = public as
$$
begin
  -- Consola / service_role (sin sesión): operaciones de confianza -> se permiten.
  if auth.uid() is null then return new; end if;
  -- Super Admin: puede cambiar lo que sea.
  if public.es_super() then return new; end if;
  -- Administrador: solo perfiles de rol 'Distribuidor' (puede cambiar su distribuidor/datos),
  -- nunca promover/degradar entre roles ni tocar admins/super admins.
  if public.es_admin() then
    if (old.rol <> 'Distribuidor') or (new.rol <> 'Distribuidor') then
      raise exception 'Un administrador solo puede gestionar usuarios de rol Distribuidor.';
    end if;
    return new;
  end if;
  -- Usuario común (Distribuidor): solo su propia ficha; no cambia rol ni distribuidor.
  if (new.rol is distinct from old.rol) or (new.distribuidor_id is distinct from old.distribuidor_id) then
    raise exception 'Solo el Super Admin puede cambiar rol o distribuidor.';
  end if;
  return new;
end $$;
drop trigger if exists trg_proteger_profile on public.profiles;
create trigger trg_proteger_profile
  before update on public.profiles
  for each row execute function public.proteger_profile();

-- ---------- DISTRIBUIDOR ----------
-- Ver: admin/super ven todos (para filtrar); distribuidor ve solo el suyo.
create policy distrib_select on public.distribuidor for select
  using ( public.es_admin() or distribuidor_id = public.mi_distribuidor() );
-- Agregar/editar distribuidores: Administrador y Super Admin.
create policy distrib_insert on public.distribuidor for insert
  with check ( public.es_admin() );
create policy distrib_update on public.distribuidor for update
  using ( public.es_admin() ) with check ( public.es_admin() );
-- Borrar distribuidores: solo Super Admin.
create policy distrib_delete on public.distribuidor for delete
  using ( public.es_super() );

-- ---------- COTIZACIÓN (corazón de la visibilidad) ----------
create policy cot_select on public.cotizacion for select
  using ( public.es_admin() or distribuidor_id = public.mi_distribuidor() );
create policy cot_insert on public.cotizacion for insert
  with check ( public.es_admin() or distribuidor_id = public.mi_distribuidor() );
create policy cot_update on public.cotizacion for update
  using ( public.es_admin() or distribuidor_id = public.mi_distribuidor() )
  with check ( public.es_admin() or distribuidor_id = public.mi_distribuidor() );
create policy cot_delete on public.cotizacion for delete
  using ( public.es_admin() or distribuidor_id = public.mi_distribuidor() );

-- ---------- LÍNEAS (heredan el acceso de su cotización) ----------
create policy cotlinea_all on public.cotizacion_linea for all
  using ( exists (select 1 from public.cotizacion c
                  where c.cotizacion_id = cotizacion_linea.cotizacion_id
                  and (public.es_admin() or c.distribuidor_id = public.mi_distribuidor())) )
  with check ( exists (select 1 from public.cotizacion c
                  where c.cotizacion_id = cotizacion_linea.cotizacion_id
                  and (public.es_admin() or c.distribuidor_id = public.mi_distribuidor())) );

-- ---------- CATÁLOGO ----------
-- Leer: cualquier usuario logueado. Modificar: Administrador y Super Admin (precios individuales o grupales).
do $$
declare t text;
begin
  foreach t in array array['familia','producto','producto_precio','color'] loop
    execute format('create policy %1$s_select on public.%1$s for select using ( auth.uid() is not null );', t);
    execute format('create policy %1$s_modify on public.%1$s for all using ( public.es_admin() ) with check ( public.es_admin() );', t);
  end loop;
end $$;

-- ---------- BITÁCORA DE PRECIOS ----------
-- Solo admin/super la consultan; la escribe el trigger (security definer).
create policy precio_log_select on public.precio_log for select
  using ( public.es_admin() );

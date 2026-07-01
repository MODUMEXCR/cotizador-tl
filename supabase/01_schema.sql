-- =====================================================================
-- Cotizador Thin Laminates (TL) — Supabase / PostgreSQL — 01 · Esquema
-- Pegar en el SQL Editor de Supabase y ejecutar EN ORDEN:
--   01_schema.sql  ->  02_rls.sql  ->  03_seed.sql
-- Moneda base: MXN. IVA 16%. Productos en USD se convierten con tipo_cambio.
-- =====================================================================

-- ---------------------------------------------------------------------
-- CATÁLOGO
-- ---------------------------------------------------------------------

-- Familias de producto (Cubiertas, Lockers, Vestidores, Bancas, etc.)
-- aplica_descuento = false  -> Servicios / Flete (no se les aplica descuento)
create table public.familia (
  codigo           text primary key,
  nombre           text not null,
  aplica_descuento boolean not null default true,
  orden            int not null default 0,
  activo           boolean not null default true
);

-- Un producto vendible (incluye extras/accesorios: cada renglón del PDF / Excel SAP es un producto).
--   tipo_precio = 'fijo'  -> precio por pieza (producto_precio.precio)
--   tipo_precio = 'm2'    -> precio = m2 * producto_precio.precio  (requiere largo x ancho)
-- moneda = 'USD' se convierte a MXN al cotizar usando cotizacion.tipo_cambio.
create table public.producto (
  producto_id      bigint generated always as identity primary key,
  codigo_sap       text not null,                 -- Código SAP (puede repetirse en variantes ESP)
  familia_codigo   text not null references public.familia(codigo),
  nombre           text not null,                 -- nombre corto (UI)
  descripcion      text not null default '',       -- texto que va al PDF (plantilla editable)
  tipo_precio      text not null default 'fijo' check (tipo_precio in ('fijo','m2')),
  unidad           text not null default 'pieza' check (unidad in ('pieza','m2','ml')),
  moneda           text not null default 'MXN' check (moneda in ('MXN','USD')),
  espesor          text,
  requiere_medidas boolean not null default false, -- pide largo/ancho (cm) para calcular m2
  medida_unica     boolean not null default false, -- redonda/cuadrada: una sola medida (área = medida²)
  aplica_descuento boolean not null default true,
  es_extra         boolean not null default false,  -- extra de locker (se suma al precio del locker)
  activo           boolean not null default true,
  orden            int not null default 0,
  creado_el        timestamptz not null default now()
);

-- Catálogo de colores. El GRUPO (G1..G4) define el precio de la cubierta; el ÁMBITO
-- indica dónde aplica (cubierta interior/exterior, frente/interior de locker, banca).
create table public.color (
  color_id        bigint generated always as identity primary key,
  nombre          text not null,
  grupo           text not null,                 -- 'G1','G2','G3','G4','INT'
  ambito          text not null,                 -- 'cubierta_int','cubierta_ext','locker_frente','locker_interior','banca'
  region          text not null default 'MXN',   -- 'MXN' | 'LATAM'
  tiempo_especial boolean not null default false,
  activo          boolean not null default true
);

-- Configuración editable (clave/valor): divisor_usd (MXN ÷ divisor = USD para LATAM), etc.
create table public.config (
  clave text primary key,
  valor text not null
);
create index ix_producto_familia on public.producto(familia_codigo);
create index ix_producto_sap      on public.producto(codigo_sap);

-- Precio por GRUPO/TIER. Un producto puede tener varios precios (G1..G4, PRO/SMART, MT/SM/BR, etc.).
--   grupo='UNICO' cuando el producto tiene precio único.
--   Para tipo_precio='m2' el valor 'precio' es el precio POR m².
create table public.producto_precio (
  producto_id bigint not null references public.producto(producto_id) on delete cascade,
  grupo       text   not null,                    -- 'UNICO','G1','G2','G3','G4','PRO','SMART','3mm', etc.
  precio      numeric(14,4) not null,
  primary key (producto_id, grupo)
);

-- Bitácora de cambios de precio (auditoría). La llena un trigger en cada UPDATE de producto_precio.
create table public.precio_log (
  precio_log_id bigint generated always as identity primary key,
  producto_id   bigint references public.producto(producto_id),
  grupo         text,
  precio_anterior numeric(14,4),
  precio_nuevo    numeric(14,4),
  cambiado_por  uuid,                              -- auth.uid()
  cambiado_el   timestamptz not null default now()
);
create index ix_precio_log_prod on public.precio_log(producto_id);

-- ---------------------------------------------------------------------
-- NÚCLEO (usuarios / distribuidores)  — patrón reutilizado del Constructor de Planos
-- ---------------------------------------------------------------------
create table public.distribuidor (
  distribuidor_id  bigint generated always as identity primary key,
  nombre           text not null,
  email            text,
  telefono         text,
  ubicacion        text,
  pais             text not null default 'México',  -- país (informativo)
  region           text not null default 'México'   -- 'México' | 'LATAM' | 'Costa Rica' (define moneda/precio)
                    check (region in ('México','LATAM','Costa Rica')),
  descuento_pct    numeric(5,2) not null default 0, -- % de descuento por defecto del distribuidor
  activo           boolean not null default true,
  creado_el        timestamptz not null default now()
);

-- profiles: 1:1 con auth.users. Supabase Auth maneja email + contraseña.
create table public.profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  nombre          text not null default '',
  email           text,
  rol             text not null default 'Distribuidor'
                    check (rol in ('Super Admin','Administrador','Vendedor','Distribuidor')),
  distribuidor_id bigint references public.distribuidor(distribuidor_id),
  activo          boolean not null default true,
  creado_el       timestamptz not null default now()
);
create index ix_profiles_distribuidor on public.profiles(distribuidor_id);

-- ---------------------------------------------------------------------
-- COTIZACIONES
-- ---------------------------------------------------------------------
create table public.cotizacion (
  cotizacion_id   bigint generated always as identity primary key,
  folio           text not null unique,            -- ID COTIZACIÓN del PDF (ej. 2490, 2499-A)
  fecha           timestamptz not null default now(),
  vigencia        date,                            -- VIGENCIA DE COTIZACIÓN
  -- Encabezado del PDF
  razon_social    text,                            -- RAZON SOCIAL / NOMBRE COMERCIAL
  proyecto        text,                            -- PROYECTO
  titulo          text,                            -- barra verde (ej. "CUBIERTA PARA EXTERIOR")
  cliente         text,
  atencion_a      text,
  telefono        text,
  ciudad          text,
  cotizado_por    text,
  -- Dueño / control
  distribuidor_id bigint references public.distribuidor(distribuidor_id),
  creado_por      uuid references public.profiles(id),
  estado          text not null default 'borrador'
                    check (estado in ('borrador','enviada','aceptada','rechazada')),
  -- Cálculo
  moneda          text not null default 'MXN',
  tipo_cambio     numeric(12,4) not null default 1, -- MXN por 1 USD (para productos en USD)
  descuento_pct   numeric(5,2) not null default 0,  -- DESCUENTO DISTRIBUIDOR % (global)
  iva_pct         numeric(5,2) not null default 16,
  anticipo_pct    numeric(5,2) not null default 60,
  -- Textos
  comentarios     text,                            -- "Comentarios o instrucciones especiales"
  -- Totales (se calculan al guardar; persistidos para el PDF/Excel)
  subtotal        numeric(16,2) not null default 0, -- SUBTOTAL PÚBLICO
  descuento_monto numeric(16,2) not null default 0,
  subtotal_desc   numeric(16,2) not null default 0,
  iva_monto       numeric(16,2) not null default 0,
  gran_total      numeric(16,2) not null default 0,
  anticipo_monto  numeric(16,2) not null default 0,
  saldo_monto     numeric(16,2) not null default 0,
  app_json        text,                            -- estado completo del configurador (para reabrir/editar)
  fabricacion     text,                            -- lugar de fabricación: 'México' | 'Costa Rica'
  actualizado_el  timestamptz not null default now()
);
create index ix_cotizacion_distribuidor on public.cotizacion(distribuidor_id);
create index ix_cotizacion_fecha         on public.cotizacion(fecha);

create table public.cotizacion_linea (
  cotizacion_linea_id bigint generated always as identity primary key,
  cotizacion_id   bigint not null references public.cotizacion(cotizacion_id) on delete cascade,
  orden           int not null default 0,
  producto_id     bigint references public.producto(producto_id), -- null = texto libre
  cantidad        numeric(12,2) not null default 1,
  codigo_sap      text,                            -- CÓDIGO SAP (renglón del Excel)
  descripcion     text,                            -- DESCRIPCIÓN
  color           text,                            -- COLOR
  texto_libre     text,                            -- columna "Texto libre" del layout SAP
  -- medidas (para productos m2)
  largo_cm        numeric(10,2),
  ancho_cm        numeric(10,2),
  precio_unitario numeric(16,4) not null default 0, -- ya en MXN (convertido si era USD)
  descuento_pct   numeric(5,2) not null default 0,  -- Descuento por renglón
  aplica_descuento boolean not null default true,
  subtotal        numeric(16,2) not null default 0  -- cantidad * precio_unitario (sin desc.)
);
create index ix_cotlinea_cot on public.cotizacion_linea(cotizacion_id);

-- ---------------------------------------------------------------------
-- Trigger: auto-crear el profile al registrarse un usuario en Auth
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user() returns trigger
  language plpgsql security definer set search_path = public as
$$
begin
  -- Auto-registro: nace como Distribuidor INACTIVO (pendiente de aprobación de un Admin/Super).
  insert into public.profiles (id, nombre, email, rol, activo)
  values (new.id, coalesce(new.raw_user_meta_data->>'nombre',''), new.email, 'Distribuidor', false)
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- Trigger: bitácora de cambios de precio
-- ---------------------------------------------------------------------
create or replace function public.log_precio_cambio() returns trigger
  language plpgsql security definer set search_path = public as
$$
begin
  if (tg_op = 'UPDATE' and new.precio is distinct from old.precio) then
    insert into public.precio_log (producto_id, grupo, precio_anterior, precio_nuevo, cambiado_por)
    values (new.producto_id, new.grupo, old.precio, new.precio, auth.uid());
  end if;
  return new;
end $$;

drop trigger if exists trg_precio_log on public.producto_precio;
create trigger trg_precio_log
  after update on public.producto_precio
  for each row execute function public.log_precio_cambio();

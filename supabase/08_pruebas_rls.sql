-- =====================================================================
-- Cotizador Thin Laminates — 08 · Pruebas de seguridad (RLS)
-- Verifica el aislamiento por rol SIMULANDO el usuario (su JWT) dentro del SQL Editor.
-- Correr cada bloque por separado. NO modifica datos (salvo donde se indica, que falla a propósito).
--
-- Cómo funciona: en Supabase, auth.uid() = request.jwt.claims->>'sub'. Cambiando ese
-- claim "nos hacemos pasar" por un usuario y vemos exactamente lo que él vería desde la app.
-- =====================================================================

-- 0) Apunta los IDs reales con los que vas a probar:
--    select id, email, rol, distribuidor_id from public.profiles order by rol;

-- =====================================================================
-- PRUEBA A — Un DISTRIBUIDOR solo ve SUS cotizaciones
-- =====================================================================
begin;
  set local role authenticated;
  -- << pega el id (uuid) de un usuario con rol 'Distribuidor' >>
  select set_config('request.jwt.claims',
    json_build_object('sub','00000000-0000-0000-0000-000000000000','role','authenticated')::text, true);

  -- Debe devolver SOLO las cotizaciones de su distribuidor:
  select cotizacion_id, folio, distribuidor_id from public.cotizacion order by 1;

  -- Debe ver SOLO su propia ficha de usuario:
  select id, email, rol from public.profiles;
rollback;

-- =====================================================================
-- PRUEBA B — Un DISTRIBUIDOR NO puede cambiar precios (RLS lo bloquea: 0 filas)
-- =====================================================================
begin;
  set local role authenticated;
  select set_config('request.jwt.claims',
    json_build_object('sub','00000000-0000-0000-0000-000000000000','role','authenticated')::text, true);

  -- Intento de cambiar un precio: debe actualizar 0 filas (UPDATE 0).
  update public.producto_precio set precio = precio * 2 where grupo = 'G1';
rollback;

-- =====================================================================
-- PRUEBA C — Un DISTRIBUIDOR NO puede auto-promoverse a Super Admin
-- =====================================================================
begin;
  set local role authenticated;
  select set_config('request.jwt.claims',
    json_build_object('sub','00000000-0000-0000-0000-000000000000','role','authenticated')::text, true);

  -- Debe FALLAR con: "Solo el Super Admin puede cambiar rol o distribuidor."
  update public.profiles set rol = 'Super Admin' where id = auth.uid();
rollback;

-- =====================================================================
-- PRUEBA D — Un ADMINISTRADOR ve TODO y SÍ puede cambiar precios
-- =====================================================================
begin;
  set local role authenticated;
  -- << pega el id de un usuario con rol 'Administrador' >>
  select set_config('request.jwt.claims',
    json_build_object('sub','11111111-1111-1111-1111-111111111111','role','authenticated')::text, true);

  -- Debe ver TODAS las cotizaciones:
  select count(*) as cotizaciones_visibles from public.cotizacion;

  -- Debe poder ajustar precios (1 fila):
  update public.producto_precio set precio = precio where grupo = 'G1' and producto_id =
    (select producto_id from public.producto where codigo_sap = 'CR-60' limit 1);

  -- Pero NO puede crear/editar a otros administradores (debe FALLAR):
  -- update public.profiles set rol = 'Administrador' where rol = 'Distribuidor';
rollback;

-- =====================================================================
-- PRUEBA E — La bitácora de precios registró los cambios
-- =====================================================================
select producto_id, grupo, precio_anterior, precio_nuevo, cambiado_por, cambiado_el
  from public.precio_log order by cambiado_el desc limit 20;

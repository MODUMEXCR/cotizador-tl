-- =====================================================================
-- Cotizador Thin Laminates — 07 · Ajuste grupal de precios (RPC)
-- Correr en el SQL Editor (una vez). Permite subir/bajar precios en bloque
-- por familia y/o grupo. La bitácora (precio_log) se llena sola por el trigger.
-- =====================================================================

-- p_familia NULL = todas las familias; p_grupo NULL = todos los grupos/tiers.
-- p_factor: multiplicador. Ej. 1.10 = +10%, 0.95 = -5%.
-- Devuelve cuántos precios se modificaron.
create or replace function public.ajustar_precios(p_familia text, p_grupo text, p_factor numeric)
returns integer
language plpgsql
security invoker          -- respeta RLS: solo Admin/Super pueden modificar precios
set search_path = public as
$$
declare n integer;
begin
  update public.producto_precio pp
     set precio = round(pp.precio * p_factor, 4)
    from public.producto pr
   where pp.producto_id = pr.producto_id
     and (p_familia is null or pr.familia_codigo = p_familia)
     and (p_grupo   is null or pp.grupo = p_grupo);
  get diagnostics n = row_count;
  return n;
end $$;

grant execute on function public.ajustar_precios(text, text, numeric) to authenticated;

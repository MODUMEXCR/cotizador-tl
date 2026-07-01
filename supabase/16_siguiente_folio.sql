-- =====================================================================
-- Cotizador Thin Laminates — 16 · Consecutivo de folio (RPC atómico)
-- Cualquier usuario autenticado (distribuidor/vendedor/admin) puede tomar el
-- siguiente folio sin chocar con el RLS de config. Correr una vez.
-- =====================================================================
create or replace function public.siguiente_folio() returns integer
  language plpgsql
  security definer                 -- entrega el folio saltándose el RLS de config
  set search_path = public as
$$
declare n integer;
begin
  update public.config
     set valor = ((valor::int) + 1)::text
   where clave = 'folio_consecutivo'
   returning ((valor::int) - 1) into n;   -- devuelve el valor ANTERIOR (el que se usa)
  if n is null then
    insert into public.config (clave, valor) values ('folio_consecutivo', '1001')
      on conflict (clave) do nothing;
    n := 1000;
  end if;
  return n;
end $$;

grant execute on function public.siguiente_folio() to authenticated;

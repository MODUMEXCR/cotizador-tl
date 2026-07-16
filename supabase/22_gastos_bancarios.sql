-- =====================================================================
-- Cotizador Thin Laminates — 22 · Gastos (indirectos/envío) + datos bancarios
-- Gastos indirectos y de envío se suman ANTES del IVA (salen en el PDF solo si tienen valor).
-- Datos bancarios: texto libre del distribuidor que se muestra en el PDF. Correr una vez.
-- =====================================================================
alter table public.cotizacion add column if not exists gastos_indirectos numeric(16,2) not null default 0;
alter table public.cotizacion add column if not exists gastos_envio      numeric(16,2) not null default 0;
alter table public.cotizacion add column if not exists datos_bancarios   text;

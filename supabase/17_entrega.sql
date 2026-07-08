-- =====================================================================
-- Cotizador Thin Laminates — 17 · Tiempo de entrega en la cotización
-- Guarda el tiempo de entrega elegido (1..10 semanas) para mostrarlo en el PDF.
-- Correr una vez.
-- =====================================================================
alter table public.cotizacion add column if not exists entrega text;

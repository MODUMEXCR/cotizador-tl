-- =====================================================================
-- Cotizador Thin Laminates — 14 · Mejoras (fabricación + medida única)
-- Correr una vez en el SQL Editor. Luego RE-correr 03_seed.sql (medida_unica).
-- =====================================================================
alter table public.cotizacion add column if not exists fabricacion text;                 -- 'México' | 'Costa Rica'
alter table public.producto   add column if not exists medida_unica boolean not null default false; -- redonda/cuadrada = 1 medida

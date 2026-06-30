-- =====================================================================
-- Cotizador Thin Laminates — 13 · Reabrir/editar cotización
-- Guarda el estado completo del configurador (líneas, extras, colores) para
-- poder reabrir la cotización en "Cotizar" tal cual se armó. Correr una vez.
-- =====================================================================
alter table public.cotizacion add column if not exists app_json text;

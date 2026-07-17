-- =====================================================================
-- Cotizador Thin Laminates — 25 · Campos de seguimiento (CRM)
-- Para el dashboard/CRM de ventas: próxima acción, notas de seguimiento y motivo de rechazo.
-- El estado (borrador/enviada/aceptada/rechazada) ya existe. Correr una vez.
-- =====================================================================
alter table public.cotizacion add column if not exists proxima_accion  date;
alter table public.cotizacion add column if not exists seguimiento     text;
alter table public.cotizacion add column if not exists motivo_rechazo  text;

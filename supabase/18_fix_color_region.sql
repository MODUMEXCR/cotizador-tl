-- =====================================================================
-- Cotizador Thin Laminates — 18 · Corrige la región de los colores
-- Los colores venían intercambiados: los marcados 'MXN' eran de LATAM y viceversa.
-- Este intercambio deja: fabricación México → paleta MXN correcta; Costa Rica → LATAM.
-- Correr UNA vez.
-- =====================================================================
update public.color
set region = case region
               when 'MXN'   then 'LATAM'
               when 'LATAM' then 'MXN'
               else region
             end;

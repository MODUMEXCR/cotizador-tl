# Cotizador Thin Laminates (TL)

App web para que los **distribuidores** coticen productos Thin Laminates (cubiertas,
lockers, vestidores, bancas, paletas, grado laboratorio, panelex, placas, adhesivos y
servicios), generen el **PDF** de la cotización y exporten un **Excel** (layout SAP) por
proyecto. Pensada para vivir **en línea**: se publica una vez y todas las instancias ven
la última versión.

## Arquitectura (decidida con Dayanna)

| Pieza | Tecnología | Por qué |
|-------|-----------|---------|
| Frontend | **Blazor WebAssembly (C#, .NET 10)** | C# como pidió Dayanna; compila a estáticos. |
| Hosting | **GitHub Pages** | Igual que el Constructor de Planos; gratis; `git push` = actualización para todos. |
| Backend | **Supabase** (PostgreSQL + Auth + RLS) | BD + login + seguridad real del lado del servidor. |
| Moneda | **MXN** (IVA 16%) | Toda la lista Mayo 2026 está en pesos; no se convierte nada. El motor conserva soporte de `tipo_cambio` por si en el futuro se agrega algún producto en USD. |

> **Seguridad:** la app de navegador NO es la frontera de seguridad. Quién ve/edita qué lo
> impone **RLS en Postgres** (`supabase/02_rls.sql`). Aunque alguien manipule el cliente,
> Supabase rechaza lo que el rol no permite.

## Roles (según lo pedido)

- **Distribuidor** — solo la página de cotizar y *sus* proyectos; filtra por fecha. Solo edita su propia ficha/contraseña.
- **Administrador** — ve *todas* las cotizaciones (filtra por fecha o distribuidor); **modifica precios**
  (individual o grupal); **agrega y gestiona distribuidores** (empresa + usuarios de rol Distribuidor).
  **No** puede crear ni editar otros administradores/super admins; en su propio usuario solo cambia su contraseña.
- **Super Admin** — agrega y edita **todo**: administradores, distribuidores, precios y cotizaciones.

## Estructura del repo

```
CotizadorTL/
├─ supabase/                 # Backend (ejecutar en el SQL Editor en orden)
│  ├─ 01_schema.sql          #  tablas: familia, producto, producto_precio, precio_log,
│  │                         #          distribuidor, profiles, cotizacion, cotizacion_linea
│  ├─ 02_rls.sql             #  Row Level Security (los 3 roles) + triggers de protección/auditoría
│  ├─ 03_seed.sql            #  catálogo completo (153 productos) — GENERADO, no editar a mano
│  └─ 04_usuarios_demo.sql   #  distribuidores demo + cómo crear el Super Admin
├─ catalogo/
│  ├─ raw_dump.json          #  volcado crudo de la lista de precios Mayo 2026
│  └─ catalogo.json          #  vista normalizada (referencia)
├─ scripts/
│  ├─ extract_catalog.py     #  xlsx -> raw_dump.json
│  └─ build_seed.py          #  raw_dump.json -> 03_seed.sql + catalogo.json
├─ src/
│  ├─ CotizadorTL.Core/      #  modelos + MotorPrecios (lógica pura, auditable)
│  └─ CotizadorTL.Web/       #  Blazor WASM (PENDIENTE — siguiente fase)
└─ tests/
   └─ CotizadorTL.Tests/     #  pruebas que reproducen los 3 PDFs reales al centavo
```

## Cómo poner en marcha el backend

1. Crear proyecto en [supabase.com](https://supabase.com).
2. En **SQL Editor**, pegar y ejecutar **en orden**: `01_schema.sql`, `02_rls.sql`, `03_seed.sql`, `04_usuarios_demo.sql`.
3. Crear el primer usuario en **Authentication > Users** y elevarlo a Super Admin (ver `04_usuarios_demo.sql`).

## Correr la app (Blazor)

1. Pega tus credenciales de Supabase en `src/CotizadorTL.Web/wwwroot/appsettings.json`
   (campos `Supabase:Url` y `Supabase:AnonKey`). Mientras digan `TU-PROYECTO`, la app
   solo muestra el login (no intenta conectarse).
2. Desde `CotizadorTL/`: `dotnet run --project src/CotizadorTL.Web` y abre la URL que imprime.
   (O abre `CotizadorTL.sln` en Visual Studio y dale *Run*.)

## Publicar en línea (GitHub Pages)

La app se publica sola en cada `git push` mediante GitHub Actions (`.github/workflows/deploy.yml`):

1. Crear un repo en GitHub y subir el contenido de `CotizadorTL/` (la raíz del repo = esta carpeta).
2. En el repo → **Settings → Pages → Build and deployment → Source: GitHub Actions**.
3. `git push` a `main`: el workflow compila el Blazor WASM, ajusta el `base href` al nombre del repo,
   agrega `.nojekyll` + `404.html` (para el ruteo SPA) y despliega. La URL queda en Actions → Deploy.

> Toda actualización futura se refleja en todas las instancias con solo hacer push.

## Seguridad

Ver [SECURITY.md](SECURITY.md) (auditoría, hallazgos y checklist) y `supabase/08_pruebas_rls.sql`
(pruebas de aislamiento por rol). La frontera de seguridad es **RLS en Postgres**, no el navegador.

## Regenerar el catálogo (cuando cambie la lista de precios)

```bash
python scripts/extract_catalog.py   # lee el xlsx de la lista
python scripts/build_seed.py        # regenera supabase/03_seed.sql
```

## Pruebas

```bash
dotnet test
```

Las pruebas validan, **al centavo**, los 3 PDFs entregados (REQUIEZ 30 %, RATTAN 20 %, SOLARE 50 %),
más reglas: servicios/flete sin descuento, descuento renglón+global, conversión USD→MXN y precio por m².

## Estado y hoja de ruta

- [x] **Fase 0** — Extracción del catálogo completo desde la lista Mayo 2026.
- [x] **Fase 1** — Backend Supabase: esquema, RLS (3 roles), seed (153 productos), auditoría de precios.
- [x] **Fase 2** — Motor de precios en C# + pruebas que casan con los PDFs.
- [x] **Fase 3** — Blazor WASM: login (Supabase Auth) + ruteo por rol + menú según rol (compila y corre).
- [x] **Fase 4** — Página *Cotizar*: catálogo desde Supabase, variantes (grupo/tier), medidas m², varios renglones/extras, descuentos renglón+global, totales en vivo y guardado (verificado contra la BD real).
- [x] **Fase 5** — **PDF** con jsPDF (embebido, sin CDN) réplica de la plantilla TL; logos reales (TL + Grupo Modumex) embebidos; descarga automática al guardar + botón manual.
- [x] **Fase 6** — *Mis Proyectos*: lista con filtros por fecha (+ distribuidor para admin/super), reimprimir **PDF** y exportar **Excel** (layout SAP por columnas) por proyecto (SheetJS embebido).
- [x] **Fase 7** — Admin: **Precios** (individual + grupal por familia/tier vía RPC `ajustar_precios`), **Distribuidores** (alta/edición; borrar solo super) y **Usuarios** (rol/distribuidor/activación, solo super). ⚠ requiere correr `supabase/07_admin_precios.sql`.
- [x] **Fase 8** — Despliegue automático a GitHub Pages (GitHub Actions) + auditoría de seguridad ([SECURITY.md](SECURITY.md)) + pruebas RLS (`08_pruebas_rls.sql`). `dotnet publish` validado.

# Auditoría de seguridad — Cotizador Thin Laminates

Fecha: 2026-06-29 · Alcance: app Blazor WASM + backend Supabase (PostgreSQL + Auth + RLS).

## 1. Modelo de seguridad

La app es **estática** (Blazor WebAssembly en GitHub Pages). **El navegador NO es la frontera de
seguridad**: cualquiera puede leer el código del cliente y la *publishable key*. La autorización real
la impone **Row Level Security (RLS) en PostgreSQL** (`02_rls.sql`), que se aplica del lado del servidor
en Supabase sobre cada petición autenticada con el JWT del usuario. El cliente solo decide **qué se muestra**.

Roles: `Distribuidor` (solo lo suyo) · `Administrador` (ve todo, edita precios, gestiona distribuidores,
no toca otros admins) · `Super Admin` (todo).

## 2. Qué se verificó

| Área | Resultado |
|------|-----------|
| RLS habilitado en TODAS las tablas | ✅ `familia, producto, producto_precio, precio_log, distribuidor, profiles, cotizacion, cotizacion_linea` |
| Aislamiento por distribuidor (no ve cotizaciones ajenas) | ✅ política `cot_select` + `mi_distribuidor()` (prueba A) |
| Distribuidor no puede modificar precios | ✅ `producto_precio` modify = `es_admin()` (prueba B) |
| Distribuidor/Admin no pueden auto-escalar rol | ✅ trigger `proteger_profile` (pruebas C y D) |
| Admin no puede crear/editar otros administradores | ✅ políticas `profiles_*` + trigger |
| Funciones `SECURITY DEFINER` con `search_path` fijo | ✅ evita *search_path hijacking* |
| `ajustar_precios` respeta RLS | ✅ `SECURITY INVOKER` |
| Bitácora de precios no falsificable por el cliente | ✅ `precio_log` sin política INSERT; la escribe el trigger (definer) |
| Inyección SQL | ✅ PostgREST parametriza; el RPC usa parámetros tipados |
| XSS | ✅ Blazor codifica HTML por defecto; PDF/Excel tratan los datos como texto |
| Dependencias de terceros | ✅ jsPDF, autotable, SheetJS y logos **embebidos localmente** (sin CDN): menor superficie de *supply-chain* y compatible con CSP estricta |
| Secreto del servidor | ✅ solo se usa la *publishable key*; la *secret/service_role* NO está en el repo ni en el cliente |
| Corrección de cálculos (descuentos/IVA/anticipo) | ✅ 7 pruebas xUnit reproducen los 3 PDFs reales al centavo |

## 3. Hallazgos

| # | Severidad | Hallazgo | Estado / recomendación |
|---|-----------|----------|------------------------|
| F1 | Informativo | La *publishable key* queda pública en GitHub Pages. | **OK por diseño.** Nunca agregar la *secret/service_role key* al frontend ni al repo. |
| F2 | **Media** | Los totales se calculan en el cliente y se guardan tal cual; un cliente manipulado podría guardar una cotización con totales inconsistentes con sus renglones (afecta solo a sus propios documentos). | Recomendado: recalcular subtotal/IVA/total en un **trigger** o **RPC** en Postgres al guardar, como fuente de verdad. |
| F3 | Baja | El folio autogenerado tiene resolución de minuto → posible colisión con la restricción `unique`. | Usar una **secuencia** o sufijo aleatorio para el folio. |
| F4 | Baja | Un usuario puede actualizar su propia columna `activo` (re-activarse). No puede cambiar rol ni distribuidor (lo bloquea el trigger). | Aceptable. Si importa, restringir columnas editables por el dueño en el trigger. |
| F5 | **Media** | Crear el *login* de un usuario desde la app aún no existe (requiere `service_role`). | Implementar una **Edge Function** server-side que valide el rol del que llama y cree el usuario; nunca exponer la *secret key*. |
| F6 | Baja | Auto-registro de Auth: si está abierto, cualquiera puede crear una cuenta (entraría como `Distribuidor` sin distribuidor asignado, sin datos visibles). | Definir en Supabase → Auth si se permite signup; activar confirmación de correo; el Super Admin asigna distribuidor. |

No se encontraron vulnerabilidades **altas/críticas**.

## 4. Pruebas ejecutadas

1. **Unitarias de cálculo** (`tests/CotizadorTL.Tests`): `dotnet test` → 7/7 ✅. Reproducen COT.2490 (REQUIEZ 30%),
   COT.2499-A (RATTAN 20%) y COT.2505 (SOLARE 50%) al centavo, + reglas (servicios sin descuento, descuento
   renglón+global, conversión USD→MXN, precio por m²).
2. **RLS** (`supabase/08_pruebas_rls.sql`): pruebas A–E simulando el JWT de cada rol en el SQL Editor.
3. **En vivo** (contra el Supabase real): login + carga de perfil/rol, lectura de catálogo y guardado de
   cotización (POST 201) verificados; el aislamiento lo impone RLS.

## 5. Checklist de despliegue seguro

- [ ] Confirmar que **solo** la *publishable key* está en `wwwroot/appsettings.json` (nunca la secret).
- [ ] En Supabase → Auth: política de contraseñas, confirmación de correo y decisión sobre signups abiertos.
- [ ] Correr `01`→`08` en el SQL Editor (incluye RLS y la función de precios).
- [ ] Ejecutar `08_pruebas_rls.sql` con IDs reales y confirmar los resultados esperados.
- [ ] (Recomendado F2) Mover el cálculo de totales a un trigger/RPC del servidor.
- [ ] (Recomendado F5) Edge Function para alta de usuarios.

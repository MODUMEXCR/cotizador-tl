// Edge Function: eliminar-usuario
// Borra por completo el LOGIN de un usuario (auth.users) usando la service_role key
// del lado del servidor. Al borrar el auth.user, su fila en profiles se borra en cascada,
// y el correo queda libre para volver a registrarse.
//
// Seguridad: solo Super Admin / Administrador / Vendedor pueden llamarla; Admin y Vendedor
// solo pueden borrar cuentas de rol 'Distribuidor'.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const URL = Deno.env.get("SUPABASE_URL")!;
    const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
    const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization") ?? "";

    // 1) Identificar al que llama y su rol (con su propio JWT, respetando RLS)
    const caller = createClient(URL, ANON, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await caller.auth.getUser();
    if (!user) return json({ error: "No autenticado." }, 401);
    const { data: perfil } = await caller.from("profiles").select("rol").eq("id", user.id).single();
    const rol = perfil?.rol ?? "";
    if (!["Super Admin", "Administrador", "Vendedor"].includes(rol))
      return json({ error: "Sin permiso." }, 403);

    // 2) Validar el objetivo
    const { user_id } = await req.json();
    if (!user_id) return json({ error: "Falta user_id." }, 400);

    const admin = createClient(URL, SERVICE);
    if (rol !== "Super Admin") {
      const { data: objetivo } = await admin.from("profiles").select("rol").eq("id", user_id).single();
      if (objetivo?.rol !== "Distribuidor")
        return json({ error: "Solo puedes eliminar cuentas de distribuidor." }, 403);
    }

    // 3) Borrar el login (cascada borra el profile)
    const { error } = await admin.auth.admin.deleteUser(user_id);
    if (error) return json({ error: error.message }, 500);
    return json({ ok: true });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

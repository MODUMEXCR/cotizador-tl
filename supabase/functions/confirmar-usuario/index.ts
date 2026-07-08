// Edge Function: confirmar-usuario
// Confirma el correo de un usuario existente (sin que tenga que hacer clic en ningún email),
// usando la service_role DEL SERVIDOR. Se llama al Autorizar un distribuidor auto-registrado
// o al activar una cuenta desde Usuarios. Reemplaza tener que correr SQL por cada usuario.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Método no permitido." }, 405);

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization") ?? "";

    // 1) Verificar que quien llama puede gestionar cuentas (Super Admin / Administrador / Vendedor).
    const asCaller = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
    const { data: { user }, error: uErr } = await asCaller.auth.getUser();
    if (uErr || !user) return json({ error: "No autenticado." }, 401);

    const admin = createClient(url, service);
    const { data: perfil } = await admin
      .from("profiles").select("rol").eq("id", user.id).single();
    if (!["Super Admin", "Administrador", "Vendedor"].includes(perfil?.rol))
      return json({ error: "No tienes permiso para confirmar usuarios." }, 403);

    // 2) Confirmar el correo del usuario indicado.
    const { userId } = await req.json();
    if (!userId) return json({ error: "Falta el id del usuario." }, 400);

    const { error: cErr } = await admin.auth.admin.updateUserById(userId, { email_confirm: true });
    if (cErr) return json({ error: cErr.message }, 400);

    return json({ ok: true }, 200);
  } catch (e) {
    return json({ error: String((e as Error)?.message ?? e) }, 500);
  }
});

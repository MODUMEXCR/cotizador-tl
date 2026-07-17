// Edge Function: admin-usuario
// Solo Super Admin: actualizar (nombre/correo/contraseña) o eliminar un usuario.
// Usa la service_role DEL SERVIDOR (nunca en el navegador).
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

    // 1) Solo Super Admin.
    const asCaller = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
    const { data: { user }, error: uErr } = await asCaller.auth.getUser();
    if (uErr || !user) return json({ error: "No autenticado." }, 401);

    const admin = createClient(url, service);
    const { data: perfil } = await admin.from("profiles").select("rol").eq("id", user.id).single();
    if (perfil?.rol !== "Super Admin")
      return json({ error: "Solo un Super Admin puede editar o eliminar usuarios." }, 403);

    const { action, userId, nombre, email, password } = await req.json();
    if (!userId) return json({ error: "Falta el id del usuario." }, 400);
    if (userId === user.id && action === "eliminar")
      return json({ error: "No puedes eliminar tu propia cuenta." }, 400);

    // 2) Eliminar.
    if (action === "eliminar") {
      const { error } = await admin.auth.admin.deleteUser(userId); // profiles se borra en cascada
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true }, 200);
    }

    // 3) Actualizar (nombre / correo / contraseña).
    const attrs: Record<string, unknown> = {};
    if (email) { attrs.email = email; attrs.email_confirm = true; }
    if (password) {
      if (String(password).length < 6) return json({ error: "La contraseña es muy corta (mínimo 6 caracteres)." }, 400);
      attrs.password = password;
    }
    if (Object.keys(attrs).length > 0) {
      const { error: aErr } = await admin.auth.admin.updateUserById(userId, attrs);
      if (aErr) {
        const m = (aErr.message ?? "").toLowerCase();
        if (m.includes("already") || m.includes("registered") || m.includes("exists"))
          return json({ error: "Ese correo ya está en uso por otra cuenta." }, 409);
        return json({ error: aErr.message }, 400);
      }
    }

    // Perfil (nombre y/o correo).
    const perfilUpd: Record<string, unknown> = {};
    if (typeof nombre === "string") perfilUpd.nombre = nombre;
    if (email) perfilUpd.email = email;
    if (Object.keys(perfilUpd).length > 0) {
      const { error: pErr } = await admin.from("profiles").update(perfilUpd).eq("id", userId);
      if (pErr) return json({ error: pErr.message }, 500);
    }

    return json({ ok: true }, 200);
  } catch (e) {
    return json({ error: String((e as Error)?.message ?? e) }, 500);
  }
});

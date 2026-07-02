// Edge Function: crear-usuario
// El Super Admin crea una cuenta (Administrador/Vendedor/Super Admin) y le asigna el rol.
// Usa la service_role DEL SERVIDOR (variable de entorno inyectada por Supabase, NUNCA va al navegador)
// para crear el usuario ya confirmado con auth.admin.createUser, sin tocar la sesión de quien llama.
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

    // 1) Verificar que quien llama está autenticado y es Super Admin.
    const asCaller = createClient(url, anon, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: uErr } = await asCaller.auth.getUser();
    if (uErr || !user) return json({ error: "No autenticado." }, 401);

    const admin = createClient(url, service);
    const { data: perfil } = await admin
      .from("profiles").select("rol").eq("id", user.id).single();
    if (perfil?.rol !== "Super Admin")
      return json({ error: "Solo un Super Admin puede crear usuarios." }, 403);

    // 2) Datos de entrada.
    const { nombre, email, password, rol } = await req.json();
    if (!email || !password || !rol)
      return json({ error: "Faltan datos (email, contraseña o rol)." }, 400);
    if (String(password).length < 6)
      return json({ error: "La contraseña es muy corta (mínimo 6 caracteres)." }, 400);
    if (!["Administrador", "Vendedor", "Super Admin"].includes(rol))
      return json({ error: "Rol no válido." }, 400);

    // 3) Crear el usuario ya confirmado (no envía correo, no inicia sesión).
    const { data: creado, error: cErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { nombre: nombre ?? "" },
    });
    if (cErr || !creado?.user) {
      const m = (cErr?.message ?? "").toLowerCase();
      if (m.includes("already") || m.includes("registered") || m.includes("exists"))
        return json({ error: "Ese correo ya tiene una cuenta." }, 409);
      if (m.includes("password"))
        return json({ error: "La contraseña es muy corta (mínimo 6 caracteres)." }, 400);
      return json({ error: cErr?.message ?? "No se pudo crear el usuario." }, 400);
    }

    // 4) Asignar rol + activar. El trigger ya creó el perfil como Distribuidor inactivo;
    //    usamos upsert por si acaso no existiera.
    const { error: pErr } = await admin.from("profiles").upsert({
      id: creado.user.id,
      nombre: nombre ?? "",
      email,
      rol,
      activo: true,
    });
    if (pErr)
      return json({ error: "Usuario creado, pero no se pudo asignar el rol: " + pErr.message }, 500);

    return json({ ok: true, id: creado.user.id }, 200);
  } catch (e) {
    return json({ error: String((e as Error)?.message ?? e) }, 500);
  }
});

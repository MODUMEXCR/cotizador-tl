// Edge Function: registrar-distribuidor
// Auto-registro de distribuidores SIN enviar correos (evita el límite de intentos de Supabase).
// Crea la cuenta YA CONFIRMADA con service_role y la deja INACTIVA (rol Distribuidor, activo=false)
// hasta que un Admin/Super la autorice desde la app. Es pública: se llama con la anon key.
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
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const { nombre, email, password } = await req.json();
    if (!email || !password) return json({ error: "Faltan datos (email o contraseña)." }, 400);
    if (String(password).length < 6)
      return json({ error: "La contraseña es muy corta (mínimo 6 caracteres)." }, 400);

    const admin = createClient(url, service);

    // Crea la cuenta ya confirmada (NO envía correo de confirmación).
    const { data: creado, error: cErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { nombre: nombre ?? "" },
    });
    if (cErr || !creado?.user) {
      const m = (cErr?.message ?? "").toLowerCase();
      if (m.includes("already") || m.includes("registered") || m.includes("exists"))
        return json({ error: "already registered" }, 409);
      if (m.includes("password"))
        return json({ error: "password too short" }, 400);
      return json({ error: cErr?.message ?? "No se pudo crear la cuenta." }, 400);
    }

    // Queda como Distribuidor INACTIVO (pendiente de aprobación). El trigger ya lo crea así;
    // reforzamos por si acaso.
    await admin.from("profiles").upsert({
      id: creado.user.id,
      nombre: nombre ?? "",
      email,
      rol: "Distribuidor",
      activo: false,
    });

    return json({ ok: true }, 200);
  } catch (e) {
    return json({ error: String((e as Error)?.message ?? e) }, 500);
  }
});

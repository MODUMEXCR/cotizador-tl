// Llama Edge Functions con fetch nativo, controlando EXACTAMENTE los headers.
// Evita 2 problemas: el "Unsupported method" del HttpClient de .NET WASM y el "Conflicting API keys"
// del cliente de Supabase (que mete la anon key en Authorization además de apikey).
window.supaFn = {
  invoke: async function (url, apikey, bearer, bodyJson) {
    try {
      const headers = { "Content-Type": "application/json" };
      if (apikey) headers["apikey"] = apikey;                 // la sb_ key SOLO aquí
      if (bearer) headers["Authorization"] = "Bearer " + bearer; // JWT de usuario (solo cuando aplica)
      const resp = await fetch(url, { method: "POST", headers, body: bodyJson });
      let text = "";
      try { text = await resp.text(); } catch (e) { /* sin cuerpo */ }
      return JSON.stringify({ ok: resp.ok, status: resp.status, body: text });
    } catch (e) {
      return JSON.stringify({ ok: false, status: 0, body: "", err: String((e && e.message) || e) });
    }
  }
};

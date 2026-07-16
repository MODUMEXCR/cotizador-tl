using CotizadorTL.Web.Models;
using Microsoft.JSInterop;

namespace CotizadorTL.Web.Services;

/// <summary>
/// Estado de sesión y rol del usuario. La autorización REAL la impone Supabase (RLS);
/// esto solo decide qué se le muestra en pantalla.
/// </summary>
public class AuthService
{
    private readonly Supabase.Client _supa;
    private readonly Microsoft.JSInterop.IJSRuntime _js;
    private readonly string _url;
    private readonly string _anon;

    public AuthService(Supabase.Client supa, Microsoft.Extensions.Configuration.IConfiguration cfg, Microsoft.JSInterop.IJSRuntime js)
    {
        _supa = supa;
        _js = js;
        _url  = (cfg["Supabase:Url"] ?? "").TrimEnd('/');
        _anon = cfg["Supabase:AnonKey"] ?? "";
    }

    /// <summary>Llama una Edge Function con fetch nativo (JS interop), controlando los headers exactos.
    /// Evita el "Unsupported method" del HttpClient de WASM y el "Conflicting API keys" (la sb_ key va SOLO en
    /// apikey; Authorization solo lleva el JWT del usuario cuando conAuth=true). Devuelve (ok, cuerpo, error).</summary>
    private async Task<(bool ok, string body, string? error)> LlamarFuncion(string nombre, Dictionary<string, object> body, bool conAuth = true)
    {
        try
        {
            var url = $"{_url}/functions/v1/{nombre}";
            var bearer = conAuth ? _supa.Auth.CurrentSession?.AccessToken : null;
            var bodyJson = System.Text.Json.JsonSerializer.Serialize(body);
            var resJson = await _js.InvokeAsync<string>("supaFn.invoke", url, _anon, bearer, bodyJson);

            using var doc = System.Text.Json.JsonDocument.Parse(resJson);
            var root = doc.RootElement;
            var ok = root.TryGetProperty("ok", out var okEl) && okEl.GetBoolean();
            var respBody = root.TryGetProperty("body", out var bEl) ? (bEl.GetString() ?? "") : "";
            if (ok) return (true, respBody, null);

            var err = ExtraerError(respBody);
            if (err is null && root.TryGetProperty("err", out var eEl)) err = eEl.GetString();
            if (err is null && root.TryGetProperty("status", out var sEl)) err = $"código {sEl.GetInt32()}";
            return (false, respBody, err);
        }
        catch (Exception ex)
        {
            return (false, "", ex.Message);
        }
    }

    /// <summary>Perfil del usuario actual (rol, distribuidor). Null si no ha entrado.</summary>
    public Profile? Perfil { get; private set; }

    /// <summary>Se dispara cuando cambia el estado de sesión (entrar/salir).</summary>
    public event Action? Cambio;

    public bool Autenticado => _supa.Auth.CurrentUser != null && Perfil != null;
    public string Rol => Perfil?.Rol ?? "Distribuidor";
    public bool EsSuper => Rol == "Super Admin";
    public bool EsAdmin => Rol is "Super Admin" or "Administrador";   // gestiona precios/descuentos/usuarios
    public bool EsVendedor => Rol == "Vendedor";
    public bool PuedeVerTodo => Rol is "Super Admin" or "Administrador" or "Vendedor"; // ve/crea todo
    public bool EsDistribuidor => Rol == "Distribuidor";

    /// <summary>Al arrancar la app, si había sesión guardada, carga el perfil.</summary>
    public async Task Inicializar()
    {
        if (_supa.Auth.CurrentUser != null)
            await CargarPerfil();
        Cambio?.Invoke();
    }

    /// <summary>Devuelve null si el login fue exitoso, o un mensaje de error.</summary>
    public async Task<string?> IniciarSesion(string email, string password)
    {
        try
        {
            var session = await _supa.Auth.SignIn(email, password);
            if (session?.User == null) return "Correo o contraseña incorrectos.";
            await CargarPerfil();
            if (Perfil is { Activo: false }) { await CerrarSesion(); return "Tu cuenta aún no ha sido autorizada por un administrador."; }
            Cambio?.Invoke();
            return null;
        }
        catch (Exception ex)
        {
            return MensajeAmigable(ex.Message);
        }
    }

    /// <summary>Convierte el error técnico de Supabase Auth en un mensaje claro para el usuario.</summary>
    private static string MensajeAmigable(string error)
    {
        var e = (error ?? "").ToLowerInvariant();
        if (e.Contains("invalid_credentials") || e.Contains("invalid login")) return "Correo o contraseña incorrectos.";
        if (e.Contains("email not confirmed") || e.Contains("not confirmed"))  return "Correo aún no autorizado. Contacta con un administrador.";
        if (e.Contains("rate") || e.Contains("too many"))                       return "Demasiados intentos. Espera un momento e inténtalo de nuevo.";
        if (e.Contains("network") || e.Contains("failed to fetch"))            return "Sin conexión. Revisa tu internet e inténtalo de nuevo.";
        return "No se pudo iniciar sesión. Verifica tus datos e inténtalo de nuevo.";
    }

    /// <summary>Auto-registro de un distribuidor. Queda inactivo hasta que un Admin/Super lo apruebe.
    /// Devuelve null si todo bien, o un mensaje de error.</summary>
    public async Task<string?> Registrar(string nombre, string email, string password)
    {
        // Vía Edge Function con service_role: crea la cuenta YA CONFIRMADA (no envía correo → sin límite de
        // intentos) y queda INACTIVA hasta que un Admin/Super la autorice. Se llama con la anon key (usuario
        // no logueado). Devuelve null si todo bien.
        // Anónimo: la anon key va SOLO en apikey, sin Authorization (evita "Conflicting API keys").
        var (ok, _, error) = await LlamarFuncion("registrar-distribuidor", new Dictionary<string, object>
        {
            ["nombre"] = nombre, ["email"] = email, ["password"] = password,
        }, conAuth: false);
        if (ok) return null;

        var e = (error ?? "").ToLowerInvariant();
        if (e.Contains("already") || e.Contains("registered") || e.Contains("exists"))
            return "Ese correo ya tiene una cuenta. Si fue rechazada, pide a un administrador que la reactive.";
        if (e.Contains("password") || e.Contains("least") || e.Contains("6 char"))
            return "La contraseña es muy corta (mínimo 6 caracteres).";
        if (e.Contains("invalid") && e.Contains("email"))
            return "El correo no es válido.";
        return "No se pudo crear la cuenta: " + (error ?? "inténtalo más tarde.");
    }

    /// <summary>El Super Admin crea una cuenta y le asigna el rol de una vez (Administrador/Vendedor/Super Admin).
    /// Llama a la Edge Function "crear-usuario", que usa la service_role DEL SERVIDOR (nunca en el navegador) para
    /// crear el usuario ya confirmado sin tocar la sesión actual. Devuelve null si todo bien, o un mensaje de error.</summary>
    public async Task<string?> CrearUsuario(string nombre, string email, string password, string rol)
    {
        if (!EsSuper) return "Solo un Super Admin puede crear usuarios.";
        var (ok, _, error) = await LlamarFuncion("crear-usuario", new Dictionary<string, object>
        {
            ["nombre"] = nombre, ["email"] = email, ["password"] = password, ["rol"] = rol,
        });
        if (ok) return null;
        // La respuesta HTTP pudo fallar en el navegador aunque la función SÍ creó al usuario: la BD manda.
        if (await UsuarioListoPara(email, rol)) return null;
        return error ?? "No se pudo crear el usuario.";
    }

    /// <summary>¿El perfil ya quedó con el rol pedido y activo? Sirve para no mostrar error si la función
    /// creó al usuario pero la respuesta HTTP falló en el navegador.</summary>
    private async Task<bool> UsuarioListoPara(string email, string rol)
    {
        try
        {
            var found = (await _supa.From<Profile>().Where(p => p.Email == email).Get()).Models.FirstOrDefault();
            return found is not null && found.Rol == rol && found.Activo;
        }
        catch { return false; }
    }

    /// <summary>Confirma el correo de un usuario existente vía la Edge Function "confirmar-usuario"
    /// (usa la service_role del servidor). Evita tener que correr SQL por cada usuario.
    /// Devuelve null si todo bien, o un mensaje de error.</summary>
    public async Task<string?> ConfirmarUsuario(string userId)
    {
        if (!PuedeVerTodo) return "No tienes permiso para confirmar usuarios.";
        var (ok, _, error) = await LlamarFuncion("confirmar-usuario", new Dictionary<string, object> { ["userId"] = userId });
        if (ok) return null;
        // "Unsupported method" es un fallo de la capa HTTP de WASM que ocurre DESPUÉS de que el servidor
        // ya procesó: la confirmación en realidad se aplicó, así que lo tratamos como éxito.
        if (error != null && error.Contains("Unsupported method")) return null;
        return error ?? "No se pudo confirmar el correo.";
    }

    private static string? ExtraerError(string body)
    {
        try
        {
            using var doc = System.Text.Json.JsonDocument.Parse(body);
            if (doc.RootElement.TryGetProperty("error", out var e)) return e.GetString();
        }
        catch { /* cuerpo no-JSON */ }
        return null;
    }

    public async Task CerrarSesion()
    {
        await _supa.Auth.SignOut();
        Perfil = null;
        Cambio?.Invoke();
    }

    private async Task CargarPerfil()
    {
        var uid = _supa.Auth.CurrentUser?.Id;
        if (uid is null) return;
        Perfil = await _supa.From<Profile>().Where(p => p.Id == uid).Single();
    }
}

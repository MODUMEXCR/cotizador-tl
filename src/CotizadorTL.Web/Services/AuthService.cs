using CotizadorTL.Web.Models;

namespace CotizadorTL.Web.Services;

/// <summary>
/// Estado de sesión y rol del usuario. La autorización REAL la impone Supabase (RLS);
/// esto solo decide qué se le muestra en pantalla.
/// </summary>
public class AuthService
{
    private readonly Supabase.Client _supa;
    private readonly HttpClient _http;
    private readonly string _url;
    private readonly string _anon;

    public AuthService(Supabase.Client supa, HttpClient http, Microsoft.Extensions.Configuration.IConfiguration cfg)
    {
        _supa = supa;
        _http = http;
        _url  = (cfg["Supabase:Url"] ?? "").TrimEnd('/');
        _anon = cfg["Supabase:AnonKey"] ?? "";
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
        try
        {
            var opciones = new Supabase.Gotrue.SignUpOptions
            {
                Data = new Dictionary<string, object> { ["nombre"] = nombre }
            };
            await _supa.Auth.SignUp(email, password, opciones);
            // No lo dejamos entrar: queda pendiente de aprobación.
            await _supa.Auth.SignOut();
            Perfil = null;
            Cambio?.Invoke();
            return null;
        }
        catch (Exception ex)
        {
            Console.WriteLine("[registro] " + ex);   // detalle en la consola del navegador (F12) para diagnóstico
            var e = (ex.Message ?? "").ToLowerInvariant();
            if (e.Contains("already") || e.Contains("registered") || e.Contains("exists") || e.Contains("422"))
                return "Ese correo ya tiene una cuenta. Si fue rechazada, pide a un administrador que la reactive.";
            if (e.Contains("rate") || e.Contains("429") || e.Contains("too many"))
                return "Demasiados intentos de registro. Espera unos minutos e inténtalo de nuevo.";
            if (e.Contains("signup") || e.Contains("sign up") || e.Contains("not allowed") || e.Contains("disabled"))
                return "El registro de cuentas está deshabilitado. Contacta con un administrador.";
            if (e.Contains("password") || e.Contains("weak") || e.Contains("least") || e.Contains("6 char"))
                return "La contraseña es muy corta (mínimo 6 caracteres).";
            if (e.Contains("invalid") && e.Contains("email"))
                return "El correo no es válido.";
            return "No se pudo crear la cuenta. Revisa el correo o inténtalo más tarde.";
        }
    }

    /// <summary>El Super Admin crea una cuenta y le asigna el rol de una vez (Administrador/Vendedor/Super Admin).
    /// Llama a la Edge Function "crear-usuario", que usa la service_role DEL SERVIDOR (nunca en el navegador) para
    /// crear el usuario ya confirmado sin tocar la sesión actual. Devuelve null si todo bien, o un mensaje de error.</summary>
    public async Task<string?> CrearUsuario(string nombre, string email, string password, string rol)
    {
        if (!EsSuper) return "Solo un Super Admin puede crear usuarios.";
        var token = _supa.Auth.CurrentSession?.AccessToken;
        if (string.IsNullOrEmpty(token)) return "Tu sesión expiró. Vuelve a entrar.";

        try
        {
            var req = new HttpRequestMessage(HttpMethod.Post, $"{_url}/functions/v1/crear-usuario");
            req.Headers.TryAddWithoutValidation("Authorization", $"Bearer {token}");
            req.Headers.TryAddWithoutValidation("apikey", _anon);
            var payload = System.Text.Json.JsonSerializer.Serialize(new { nombre, email, password, rol });
            req.Content = new StringContent(payload, System.Text.Encoding.UTF8, "application/json");

            var resp = await _http.SendAsync(req);
            var body = await resp.Content.ReadAsStringAsync();
            if (resp.IsSuccessStatusCode) return null;

            return ExtraerError(body) ?? $"No se pudo crear el usuario (código {(int)resp.StatusCode}).";
        }
        catch (Exception ex)
        {
            return "No se pudo crear el usuario: " + ex.Message;
        }
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

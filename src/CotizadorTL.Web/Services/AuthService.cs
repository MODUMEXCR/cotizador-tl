using CotizadorTL.Web.Models;

namespace CotizadorTL.Web.Services;

/// <summary>
/// Estado de sesión y rol del usuario. La autorización REAL la impone Supabase (RLS);
/// esto solo decide qué se le muestra en pantalla.
/// </summary>
public class AuthService
{
    private readonly Supabase.Client _supa;

    public AuthService(Supabase.Client supa) => _supa = supa;

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
        if (e.Contains("email not confirmed") || e.Contains("not confirmed"))  return "Debes confirmar tu correo antes de entrar.";
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
            var e = (ex.Message ?? "").ToLowerInvariant();
            if (e.Contains("already") || e.Contains("registered") || e.Contains("exists")) return "Ese correo ya tiene una cuenta.";
            if (e.Contains("password") || e.Contains("weak") || e.Contains("least"))        return "La contraseña es muy corta (mínimo 6 caracteres).";
            if (e.Contains("invalid") && e.Contains("email"))                               return "El correo no es válido.";
            return "No se pudo crear la cuenta. Inténtalo de nuevo.";
        }
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

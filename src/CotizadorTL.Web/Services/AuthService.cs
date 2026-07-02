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
    /// Sin backend con service_role, se hace en dos pasos: SignUp del nuevo usuario (que inicia su sesión) y luego
    /// se RESTAURA la sesión del Super Admin para asignarle el rol saltando el RLS. Devuelve null si todo bien.</summary>
    public async Task<string?> CrearUsuario(string nombre, string email, string password, string rol)
    {
        if (!EsSuper) return "Solo un Super Admin puede crear usuarios.";
        var sesion = _supa.Auth.CurrentSession;
        if (sesion?.AccessToken is null || sesion.RefreshToken is null) return "Tu sesión expiró. Vuelve a entrar.";
        var accessToken = sesion.AccessToken;
        var refreshToken = sesion.RefreshToken;

        try
        {
            var opciones = new Supabase.Gotrue.SignUpOptions
            {
                Data = new Dictionary<string, object> { ["nombre"] = nombre }
            };
            await _supa.Auth.SignUp(email, password, opciones);
        }
        catch (Exception ex)
        {
            await RestaurarSesion(accessToken, refreshToken);
            var e = (ex.Message ?? "").ToLowerInvariant();
            if (e.Contains("already") || e.Contains("registered") || e.Contains("exists") || e.Contains("422"))
                return "Ese correo ya tiene una cuenta. Cámbiale el rol en la lista de abajo.";
            if (e.Contains("password") || e.Contains("weak") || e.Contains("least") || e.Contains("6 char"))
                return "La contraseña es muy corta (mínimo 6 caracteres).";
            if (e.Contains("invalid") && e.Contains("email"))
                return "El correo no es válido.";
            if (e.Contains("rate") || e.Contains("429") || e.Contains("too many"))
                return "Demasiados intentos. Espera unos minutos e inténtalo de nuevo.";
            return "No se pudo crear el usuario: " + ex.Message;
        }

        // El SignUp dejó iniciada la sesión del NUEVO usuario. Volvemos a la del Super Admin.
        await RestaurarSesion(accessToken, refreshToken);

        try
        {
            var nuevo = await _supa.From<Profile>().Where(p => p.Email == email).Single();
            if (nuevo is null) return "El usuario se creó, pero no se pudo asignar el rol. Ajústalo en la lista.";
            nuevo.Rol = rol;
            nuevo.Activo = true;
            await _supa.From<Profile>().Update(nuevo);
            return null;
        }
        catch (Exception ex)
        {
            return "El usuario se creó, pero no se pudo asignar el rol: " + ex.Message;
        }
    }

    private async Task RestaurarSesion(string accessToken, string refreshToken)
    {
        try
        {
            await _supa.Auth.SetSession(accessToken, refreshToken);
            await CargarPerfil();
            Cambio?.Invoke();
        }
        catch { /* si falla, el usuario tendrá que volver a entrar */ }
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

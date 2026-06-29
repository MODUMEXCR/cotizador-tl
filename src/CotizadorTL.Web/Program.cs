using Microsoft.AspNetCore.Components.Web;
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;
using Blazored.LocalStorage;
using CotizadorTL.Web;
using CotizadorTL.Web.Services;
using Supabase;

var builder = WebAssemblyHostBuilder.CreateDefault(args);
builder.RootComponents.Add<App>("#app");
builder.RootComponents.Add<HeadOutlet>("head::after");

builder.Services.AddScoped(sp => new HttpClient { BaseAddress = new Uri(builder.HostEnvironment.BaseAddress) });
builder.Services.AddBlazoredLocalStorage();

var url = builder.Configuration["Supabase:Url"] ?? "";
var key = builder.Configuration["Supabase:AnonKey"] ?? "";

builder.Services.AddScoped<LocalStorageSessionHandler>();
builder.Services.AddScoped(sp =>
{
    var handler = sp.GetRequiredService<LocalStorageSessionHandler>();
    var options = new SupabaseOptions
    {
        AutoRefreshToken    = true,
        AutoConnectRealtime = false,
        SessionHandler      = handler,
    };
    return new Supabase.Client(url, key, options);
});
builder.Services.AddScoped<AuthService>();
builder.Services.AddScoped<CatalogoService>();

var host = builder.Build();

// Inicializa Supabase en segundo plano (restaura la sesión guardada, si existe) para
// NO bloquear el primer render. Si no hay credenciales reales aún, ni se intenta.
var configurado = !string.IsNullOrWhiteSpace(url) && !url.Contains("TU-PROYECTO");
if (configurado)
{
    async Task InicializarEnSegundoPlano()
    {
        try
        {
            await host.Services.GetRequiredService<Supabase.Client>().InitializeAsync();
            await host.Services.GetRequiredService<AuthService>().Inicializar();
        }
        catch { /* sin conexión -> se queda en login */ }
    }
    _ = InicializarEnSegundoPlano();
}

await host.RunAsync();

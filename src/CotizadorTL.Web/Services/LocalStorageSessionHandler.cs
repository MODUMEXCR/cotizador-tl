using Blazored.LocalStorage;
using Supabase.Gotrue;
using Supabase.Gotrue.Interfaces;

namespace CotizadorTL.Web.Services;

/// <summary>
/// Guarda la sesión de Supabase Auth en el localStorage del navegador, para que el
/// distribuidor no tenga que volver a entrar cada vez que recarga la app.
/// </summary>
public class LocalStorageSessionHandler : IGotrueSessionPersistence<Session>
{
    private const string Key = "tl.session";
    private readonly ISyncLocalStorageService _ls;

    public LocalStorageSessionHandler(ISyncLocalStorageService ls) => _ls = ls;

    public void SaveSession(Session session) => _ls.SetItem(Key, session);
    public void DestroySession() => _ls.RemoveItem(Key);
    public Session? LoadSession() => _ls.ContainKey(Key) ? _ls.GetItem<Session>(Key) : null;
}

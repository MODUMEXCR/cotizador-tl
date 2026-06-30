using CotizadorTL.Core;
using CotizadorTL.Web.Models;
using Supabase.Postgrest;

namespace CotizadorTL.Web.Services;

/// <summary>
/// Carga el catálogo (familias, productos con precios por grupo) y los distribuidores
/// desde Supabase, y los mapea a los tipos de CotizadorTL.Core para el motor de cálculo.
/// Cachea en memoria: se carga una sola vez por sesión.
/// </summary>
public class CatalogoService
{
    private readonly Supabase.Client _supa;
    private bool _cargado;

    public CatalogoService(Supabase.Client supa) => _supa = supa;

    public List<Familia> Familias { get; private set; } = new();
    public List<Producto> Productos { get; private set; } = new();
    public List<PDistribuidor> Distribuidores { get; private set; } = new();
    public List<PColor> Colores { get; private set; } = new();
    /// <summary>Divisor para precios LATAM (MXN ÷ divisor = USD). Configurable; default 17.</summary>
    public decimal DivisorUsd { get; private set; } = 17m;

    public async Task CargarAsync(bool forzar = false)
    {
        if (_cargado && !forzar) return;

        var familias = await _supa.From<PFamilia>().Order("orden", Constants.Ordering.Ascending).Get();
        var productos = await _supa.From<PProducto>()
                                   .Filter("activo", Constants.Operator.Equals, "true")
                                   .Order("orden", Constants.Ordering.Ascending).Get();
        var precios   = await _supa.From<PProductoPrecio>().Get();
        var distribs  = await _supa.From<PDistribuidor>().Order("nombre", Constants.Ordering.Ascending).Get();
        var colores   = await _supa.From<PColor>().Order("nombre", Constants.Ordering.Ascending).Get();
        var config    = await _supa.From<PConfig>().Get();

        // Agrupar precios por producto
        var preciosPorProducto = precios.Models
            .GroupBy(p => p.ProductoId)
            .ToDictionary(g => g.Key, g => g.ToDictionary(x => x.Grupo, x => x.Precio));

        Familias = familias.Models.Select(f => new Familia
        {
            Codigo = f.Codigo, Nombre = f.Nombre, AplicaDescuento = f.AplicaDescuento, Orden = f.Orden
        }).ToList();

        Productos = productos.Models.Select(p => new Producto
        {
            ProductoId = p.ProductoId,
            CodigoSap = p.CodigoSap,
            FamiliaCodigo = p.FamiliaCodigo,
            Nombre = p.Nombre,
            Descripcion = p.Descripcion,
            TipoPrecio = p.TipoPrecio,
            Unidad = p.Unidad,
            Moneda = p.Moneda,
            Espesor = p.Espesor,
            RequiereMedidas = p.RequiereMedidas,
            AplicaDescuento = p.AplicaDescuento,
            EsExtra = p.EsExtra,
            Activo = p.Activo,
            Orden = p.Orden,
            Precios = preciosPorProducto.TryGetValue(p.ProductoId, out var d) ? d : new()
        }).ToList();

        Distribuidores = distribs.Models;
        Colores = colores.Models;
        var div = config.Models.FirstOrDefault(c => c.Clave == "divisor_usd")?.Valor;
        if (decimal.TryParse(div, out var d2) && d2 > 0) DivisorUsd = d2;
        _cargado = true;
    }

    public IEnumerable<Producto> PorFamilia(string familiaCodigo)
        => Productos.Where(p => p.FamiliaCodigo == familiaCodigo);

    public Producto? Buscar(long productoId) => Productos.FirstOrDefault(p => p.ProductoId == productoId);
}

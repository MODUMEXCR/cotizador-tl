using Supabase.Postgrest.Attributes;
using Supabase.Postgrest.Models;

namespace CotizadorTL.Web.Models;

// Modelos PostgREST (filas de Supabase). Se mapean a los tipos de CotizadorTL.Core
// para alimentar el motor de cálculo ya probado.

[Table("familia")]
public class PFamilia : BaseModel
{
    [PrimaryKey("codigo", false)] public string Codigo { get; set; } = "";
    [Column("nombre")]            public string Nombre { get; set; } = "";
    [Column("aplica_descuento")]  public bool AplicaDescuento { get; set; } = true;
    [Column("orden")]             public int Orden { get; set; }
    [Column("activo")]            public bool Activo { get; set; } = true;
}

[Table("producto")]
public class PProducto : BaseModel
{
    [PrimaryKey("producto_id", false)] public long ProductoId { get; set; }
    [Column("codigo_sap")]       public string CodigoSap { get; set; } = "";
    [Column("familia_codigo")]   public string FamiliaCodigo { get; set; } = "";
    [Column("nombre")]           public string Nombre { get; set; } = "";
    [Column("descripcion")]      public string Descripcion { get; set; } = "";
    [Column("tipo_precio")]      public string TipoPrecio { get; set; } = "fijo";
    [Column("unidad")]           public string Unidad { get; set; } = "pieza";
    [Column("moneda")]           public string Moneda { get; set; } = "MXN";
    [Column("espesor")]          public string? Espesor { get; set; }
    [Column("requiere_medidas")] public bool RequiereMedidas { get; set; }
    [Column("aplica_descuento")] public bool AplicaDescuento { get; set; } = true;
    [Column("activo")]           public bool Activo { get; set; } = true;
    [Column("orden")]            public int Orden { get; set; }
}

[Table("producto_precio")]
public class PProductoPrecio : BaseModel
{
    [PrimaryKey("producto_id", false)] public long ProductoId { get; set; }
    [Column("grupo")]  public string Grupo { get; set; } = "";
    [Column("precio")] public decimal Precio { get; set; }
}

[Table("distribuidor")]
public class PDistribuidor : BaseModel
{
    [PrimaryKey("distribuidor_id", false)] public long DistribuidorId { get; set; }
    [Column("nombre")]        public string Nombre { get; set; } = "";
    [Column("email")]         public string? Email { get; set; }
    [Column("telefono")]      public string? Telefono { get; set; }
    [Column("ubicacion")]     public string? Ubicacion { get; set; }
    [Column("descuento_pct")] public decimal DescuentoPct { get; set; }
    [Column("activo")]        public bool Activo { get; set; } = true;
}

[Table("cotizacion")]
public class PCotizacion : BaseModel
{
    [PrimaryKey("cotizacion_id", false)] public long CotizacionId { get; set; }
    [Column("folio")]          public string Folio { get; set; } = "";
    [Column("fecha")]          public DateTime Fecha { get; set; }
    [Column("vigencia")]       public DateTime? Vigencia { get; set; }
    [Column("razon_social")]   public string? RazonSocial { get; set; }
    [Column("proyecto")]       public string? Proyecto { get; set; }
    [Column("titulo")]         public string? Titulo { get; set; }
    [Column("cliente")]        public string? Cliente { get; set; }
    [Column("atencion_a")]     public string? AtencionA { get; set; }
    [Column("telefono")]       public string? Telefono { get; set; }
    [Column("ciudad")]         public string? Ciudad { get; set; }
    [Column("cotizado_por")]   public string? CotizadoPor { get; set; }
    [Column("distribuidor_id")]public long? DistribuidorId { get; set; }
    [Column("creado_por")]     public string? CreadoPor { get; set; }
    [Column("estado")]         public string Estado { get; set; } = "borrador";
    [Column("moneda")]         public string Moneda { get; set; } = "MXN";
    [Column("tipo_cambio")]    public decimal TipoCambio { get; set; } = 1m;
    [Column("descuento_pct")]  public decimal DescuentoPct { get; set; }
    [Column("iva_pct")]        public decimal IvaPct { get; set; } = 16m;
    [Column("anticipo_pct")]   public decimal AnticipoPct { get; set; } = 60m;
    [Column("comentarios")]    public string? Comentarios { get; set; }
    [Column("subtotal")]       public decimal Subtotal { get; set; }
    [Column("descuento_monto")]public decimal DescuentoMonto { get; set; }
    [Column("subtotal_desc")]  public decimal SubtotalDesc { get; set; }
    [Column("iva_monto")]      public decimal IvaMonto { get; set; }
    [Column("gran_total")]     public decimal GranTotal { get; set; }
    [Column("anticipo_monto")] public decimal AnticipoMonto { get; set; }
    [Column("saldo_monto")]    public decimal SaldoMonto { get; set; }
}

[Table("cotizacion_linea")]
public class PCotizacionLinea : BaseModel
{
    [PrimaryKey("cotizacion_linea_id", false)] public long CotizacionLineaId { get; set; }
    [Column("cotizacion_id")]  public long CotizacionId { get; set; }
    [Column("orden")]          public int Orden { get; set; }
    [Column("producto_id")]    public long? ProductoId { get; set; }
    [Column("cantidad")]       public decimal Cantidad { get; set; } = 1;
    [Column("codigo_sap")]     public string? CodigoSap { get; set; }
    [Column("descripcion")]    public string? Descripcion { get; set; }
    [Column("color")]          public string? Color { get; set; }
    [Column("texto_libre")]    public string? TextoLibre { get; set; }
    [Column("largo_cm")]       public decimal? LargoCm { get; set; }
    [Column("ancho_cm")]       public decimal? AnchoCm { get; set; }
    [Column("precio_unitario")]public decimal PrecioUnitario { get; set; }
    [Column("descuento_pct")]  public decimal DescuentoPct { get; set; }
    [Column("aplica_descuento")]public bool AplicaDescuento { get; set; } = true;
    [Column("subtotal")]       public decimal Subtotal { get; set; }
}

// Genera el Excel (.xlsx) con el layout tipo SAP, columnas separadas (no CSV).
// Usa SheetJS (wwwroot/lib/xlsx, sin CDN).
(function () {
  const ENCABEZADO = [
    "Clase de artículo/servicio", "Número de artículo", "Descripción del artículo",
    "Texto libre", "Cantidad", "Precio por unidad",
    "Descuento 1", "Descuento 2", "Descuento 3", "Descuento 4",
  ];

  window.cotizadorExcel = {
    generar: function (folio, lineas) {
      const XLSX = window.XLSX;
      const aoa = [ENCABEZADO];
      (lineas || []).forEach((l) => {
        aoa.push([
          "Artículo",
          l.codigoSap || "",
          l.descripcion || "",
          l.textoLibre || "",
          Number(l.cantidad || 0),
          Number(l.precioUnitario || 0),
          (l.desc1 === null || l.desc1 === undefined || l.desc1 === 0) ? "" : Number(l.desc1),
          (l.desc2 === null || l.desc2 === undefined || l.desc2 === 0) ? "" : Number(l.desc2),
          "",
          "",
        ]);
      });
      const ws = XLSX.utils.aoa_to_sheet(aoa);
      ws["!cols"] = [
        { wch: 22 }, { wch: 16 }, { wch: 50 }, { wch: 14 }, { wch: 9 },
        { wch: 14 }, { wch: 11 }, { wch: 11 }, { wch: 11 }, { wch: 11 },
      ];
      const wb = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(wb, ws, "Cotización");
      XLSX.writeFile(wb, "Cotizacion-" + (folio || "TL") + ".xlsx");
    },
  };
})();

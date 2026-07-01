// Genera el Excel (.xlsx) para SAP con encabezado (cliente/distribuidor/obra/fabricación)
// + tabla de columnas SAP, con celdas separadas y colores (usa xlsx-js-style).
(function () {
  const AZUL = "1F3864";     // encabezados oscuros
  const BANDA = "D9E1F2";    // bandas claras
  const GRIS = "BFBFBF";     // bordes
  const b = { style: "thin", color: { rgb: GRIS } };
  const BORDES = { top: b, bottom: b, left: b, right: b };

  const stTitulo = { font: { bold: true, sz: 14, color: { rgb: AZUL } }, alignment: { horizontal: "center", vertical: "center" } };
  const stMarca = { font: { bold: true, sz: 16, color: { rgb: AZUL } }, alignment: { vertical: "center" } };
  const stEmpresa = { font: { sz: 9, color: { rgb: "444444" } }, alignment: { horizontal: "right", vertical: "center", wrapText: true } };
  const stBandaHdr = { font: { bold: true, sz: 10, color: { rgb: "FFFFFF" } }, fill: { fgColor: { rgb: AZUL } }, alignment: { horizontal: "left", vertical: "center" } };
  const stInfo = { font: { sz: 10, color: { rgb: "222222" } }, fill: { fgColor: { rgb: BANDA } }, alignment: { horizontal: "left", vertical: "center" }, border: BORDES };
  const stTh = { font: { bold: true, sz: 10, color: { rgb: "FFFFFF" } }, fill: { fgColor: { rgb: AZUL } }, alignment: { horizontal: "center", vertical: "center", wrapText: true }, border: BORDES };
  const stTd = { font: { sz: 9, color: { rgb: "222222" } }, alignment: { vertical: "center", wrapText: true }, border: BORDES };
  const stTdNum = { font: { sz: 9, color: { rgb: "222222" } }, alignment: { horizontal: "right", vertical: "center" }, border: BORDES, numFmt: "#,##0.00" };
  const stTdCen = { font: { sz: 9, color: { rgb: "222222" } }, alignment: { horizontal: "center", vertical: "center" }, border: BORDES };
  const stTotal = { font: { bold: true, sz: 10, color: { rgb: "FFFFFF" } }, fill: { fgColor: { rgb: AZUL } }, alignment: { horizontal: "right", vertical: "center" }, border: BORDES };
  const stTotalNum = { font: { bold: true, sz: 10, color: { rgb: "FFFFFF" } }, fill: { fgColor: { rgb: AZUL } }, alignment: { horizontal: "right", vertical: "center" }, border: BORDES, numFmt: "#,##0.00" };

  const ENCAB = ["Clase de artículo/servicio", "Número de artículo", "Descripción del artículo", "Texto libre",
                 "Cantidad", "Precio por unidad", "Descuento 1", "Descuento 2", "Descuento 3", "Descuento 4"];
  const NCOL = ENCAB.length; // 10 (A..J)

  window.cotizadorExcel = {
    generar: function (info, lineas) {
      const XLSX = window.XLSX;
      info = info || {}; lineas = lineas || [];
      const ws = {}, merges = [];
      const set = (r, c, v, s, t) => { ws[XLSX.utils.encode_cell({ r, c })] = { v: v == null ? "" : v, t: t || "s", s: s }; };
      const mg = (r1, c1, r2, c2) => merges.push({ s: { r: r1, c: c1 }, e: { r: r2, c: c2 } });

      let r = 0;
      // Marca (izq) + empresa (der)
      set(r, 0, "GRUPO MODUMEX / THIN LAMINATES", stMarca); mg(r, 0, r + 1, 4);
      set(r, 5, "Calle La Válvula #15, Parque Industrial Perisur, 45619", stEmpresa); mg(r, 5, r, 9);
      set(r + 1, 5, "San Pedro Tlaquepaque, Jalisco · Tel. 33 3003 3200", stEmpresa); mg(r + 1, 5, r + 1, 9);
      r += 2;
      // Título
      set(r, 0, "COTIZACIÓN", stTitulo); mg(r, 0, r, 9); r += 2;
      // Bloques Cliente / Distribuidor
      set(r, 0, "CLIENTE", stBandaHdr); mg(r, 0, r, 4);
      set(r, 5, "DISTRIBUIDOR", stBandaHdr); mg(r, 5, r, 9); r++;
      const fila2 = (izqLabel, izqVal, derLabel, derVal) => {
        set(r, 0, (izqLabel ? izqLabel + ": " : "") + (izqVal || ""), stInfo); mg(r, 0, r, 4);
        set(r, 5, (derLabel ? derLabel + ": " : "") + (derVal || ""), stInfo); mg(r, 5, r, 9); r++;
      };
      fila2("", info.cliente, "", info.distribuidor);
      fila2("Ciudad", info.ciudad, "Atención", info.atencion);
      fila2("Obra/Proyecto", info.proyecto, "Fabricación", info.fabricacion);
      fila2("Folio", info.folio, "Fecha", info.fecha);
      fila2("Moneda", info.moneda, "", "");
      r++;
      // Encabezado de tabla
      const rHead = r;
      ENCAB.forEach((h, c) => set(rHead, c, h, stTh));
      r++;
      // Filas
      let totalCant = 0;
      lineas.forEach((l) => {
        set(r, 0, "Artículo", stTd);
        set(r, 1, l.codigoSap || "", stTd);
        set(r, 2, l.descripcion || "", stTd);
        set(r, 3, l.textoLibre || "", stTd);
        set(r, 4, Number(l.cantidad || 0), stTdCen, "n");
        set(r, 5, Number(l.precioUnitario || 0), stTdNum, "n");
        set(r, 6, (l.desc1 ? Number(l.desc1) : ""), stTdNum, l.desc1 ? "n" : "s");
        set(r, 7, (l.desc2 ? Number(l.desc2) : ""), stTdNum, l.desc2 ? "n" : "s");
        set(r, 8, "", stTd);
        set(r, 9, "", stTd);
        totalCant += Number(l.cantidad || 0);
        r++;
      });
      // Totales
      set(r, 0, "TOTALES", stTotal); mg(r, 0, r, 3);
      set(r, 4, totalCant, stTotalNum, "n");
      for (let c = 5; c < NCOL; c++) set(r, c, "", stTotal);

      ws["!ref"] = XLSX.utils.encode_range({ s: { r: 0, c: 0 }, e: { r: r, c: NCOL - 1 } });
      ws["!merges"] = merges;
      ws["!cols"] = [{ wch: 20 }, { wch: 16 }, { wch: 46 }, { wch: 14 }, { wch: 9 }, { wch: 13 }, { wch: 11 }, { wch: 11 }, { wch: 11 }, { wch: 11 }];
      ws["!rows"] = [{ hpt: 22 }];

      const wb = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(wb, ws, "Cotización");
      XLSX.writeFile(wb, "Cotizacion-" + (info.folio || "TL") + ".xlsx");
    },
  };
})();

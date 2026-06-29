# -*- coding: utf-8 -*-
"""
Extrae la lista de precios interna de Thin Laminates a un JSON crudo (grids completos).
Salida: catalogo/raw_dump.json  -> { hoja: [[celdas...], ...], ... }
Uso: python scripts/extract_catalog.py
"""
import json, os, sys
import openpyxl

SRC = r"C:/Users/NancyLizano/Downloads/Nueva carpeta/OneDrive - Modumex Mamparas Sanitarias Finas SA DE CV/Documentos/Cotizador TL/LISTA DE PRECIOS INTERNA THIN LAMINATES MAYO 2026.xlsx"
OUT = os.path.join(os.path.dirname(__file__), "..", "catalogo", "raw_dump.json")

def norm(c):
    if c is None:
        return None
    if isinstance(c, float):
        # redondear ruido de coma flotante a 4 decimales
        return round(c, 4)
    return str(c).strip()

def main():
    wb = openpyxl.load_workbook(SRC, read_only=True, data_only=True)
    out = {}
    for ws in wb.worksheets:
        grid = []
        for row in ws.iter_rows(values_only=True):
            grid.append([norm(c) for c in row])
        # recortar filas totalmente vacias al final
        while grid and all(c is None for c in grid[-1]):
            grid.pop()
        out[ws.title] = grid
    wb.close()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print("Hojas:", list(out.keys()))
    print("OK ->", os.path.abspath(OUT))

if __name__ == "__main__":
    main()

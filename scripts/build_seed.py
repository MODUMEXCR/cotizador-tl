# -*- coding: utf-8 -*-
"""
Construye supabase/03_seed.sql (catálogo completo) a partir de catalogo/raw_dump.json.
- Cubiertas de línea y Panelex: parseo programático de las tablas numéricas.
- Lockers, vestidores, bancas, paletas, grado lab, adhesivos, placas, servicios y
  todos los extras/accesorios: datos curados a mano (tomados de la lista Mayo 2026).
Emite también catalogo/catalogo.json (vista normalizada para referencia).
Uso: python scripts/build_seed.py
"""
import json, os

HERE = os.path.dirname(__file__)
RAW  = os.path.join(HERE, "..", "catalogo", "raw_dump.json")
OUT_SQL  = os.path.join(HERE, "..", "supabase", "03_seed.sql")
OUT_JSON = os.path.join(HERE, "..", "catalogo", "catalogo.json")

with open(RAW, "r", encoding="utf-8") as f:
    RAWD = json.load(f)

def num(v):
    try:
        return round(float(v), 4)
    except (TypeError, ValueError):
        return None

def sqls(s):
    if s is None:
        return "null"
    return "'" + str(s).replace("'", "''") + "'"

# ---------------------------------------------------------------------
# Familias
# ---------------------------------------------------------------------
FAMILIAS = [
    ("CUBIERTAS",   "Cubiertas",                 True,  10),
    ("LOCKERS",     "Lockers",                   True,  20),
    ("VESTIDORES",  "Vestidores",                True,  30),
    ("BANCAS",      "Bancas y paletas",          True,  40),
    ("GRADO_LAB",   "Grado laboratorio",         True,  50),
    ("PANELEX",     "Panelex",                   True,  60),
    ("PLACAS",      "Placas (Lamitech/Ralph)",   True,  70),
    ("ACCESORIOS",  "Accesorios y herrajes",     True,  80),
    ("ADHESIVOS",   "Adhesivos y perfiles",      True,  90),
    ("SERVICIOS",   "Servicios (instalación/flete)", False, 100),
]

# Toda la lista está en MXN (confirmado por Dayanna 2026-06-29): no se convierte nada.
# Nota: las hojas Panelex / Adhesivos / cerraduras Gatner decían "Precios en USD" en el
# archivo original; quedan en MXN por indicación. Poner en False solo si se confirma USD.
FORCE_MXN = True

# productos: lista de dicts. precios: {grupo: precio}
PRODUCTOS = []

def add(codigo, familia, nombre, precios, descripcion="", tipo="fijo",
        unidad="pieza", moneda="MXN", espesor=None, medidas=False, desc_aplica=True, orden=0):
    if FORCE_MXN:
        moneda = "MXN"
    PRODUCTOS.append(dict(
        codigo_sap=codigo, familia=familia, nombre=nombre, descripcion=descripcion,
        tipo_precio=tipo, unidad=unidad, moneda=moneda, espesor=espesor,
        requiere_medidas=medidas, aplica_descuento=desc_aplica, orden=orden,
        precios={g: round(p, 4) for g, p in precios.items() if p is not None},
    ))

# =====================================================================
# CUBIERTAS
# =====================================================================
cub = RAWD["CUBIERTAS"]

# --- Tarifas $/m² por grupo (cotizador express, medidas especiales) ---
# Filas (1-based en Excel) -> 0-based aquí
RATE_G1      = num(cub[4][2])    # GRUPO 1 12.7mm
RATE_G2      = num(cub[7][2])    # GRUPO 2 12mm
RATE_G3      = num(cub[8][2])    # GRUPO 3 - CORE BLANCO
RATE_G4      = num(cub[9][2])    # GRUPO 4 - UV
RATE_ESP_INT = num(cub[6][2])    # ESPECIAL INTERIOR G1+20%
RATE_ESP_EXT = num(cub[12][2])   # ESPECIAL EXTERIOR G4+20%
RATE_9MM     = num(cub[13][2])   # Blanco/Alumina/Negro 9mm

M2_RATES = {"G1": RATE_G1, "G2": RATE_G2, "G3": RATE_G3, "G4": RATE_G4,
            "ESP_INT": RATE_ESP_INT, "ESP_EXT": RATE_ESP_EXT}

DESC_CUB = ("SUMINISTRO DE CUBIERTA {forma} DE LAMINADO COMPACTO DE 12.7 MM DE ESPESOR "
            "MARCA THIN LAMINATES. MEDIDA FINAL: {medida}. GARANTÍA EN LAMINADO COMPACTO. CANTO __")

# Cubiertas medida especial (m²)
add("CR-ESP", "CUBIERTAS", "Cubierta redonda medida especial",
    M2_RATES, descripcion=DESC_CUB.format(forma="REDONDA", medida="__ CM DIÁMETRO"),
    tipo="m2", unidad="m2", medidas=True, orden=1)
add("CT-ESP", "CUBIERTAS", "Cubierta rectangular medida especial",
    M2_RATES, descripcion=DESC_CUB.format(forma="RECTANGULAR", medida="__ CM X __ CM"),
    tipo="m2", unidad="m2", medidas=True, orden=2)
add("CU-ESP", "CUBIERTAS", "Cubierta forma irregular medida especial",
    M2_RATES, descripcion=DESC_CUB.format(forma="FORMA IRREGULAR", medida="__ CM X __ CM"),
    tipo="m2", unidad="m2", medidas=True, orden=3)
# 9 mm (blanco/alumina/negro) por m²
add("CUB-9MM", "CUBIERTAS", "Cubierta 9 mm (blanco/alumina/negro)",
    {"UNICO": RATE_9MM}, descripcion="CUBIERTA LAMINADO COMPACTO 9 MM (BLANCO/ALUMINA/NEGRO). MEDIDA FINAL: __",
    tipo="m2", unidad="m2", moneda="MXN", espesor="9 mm", medidas=True, orden=4)

# --- Cubiertas de LÍNEA (precio fijo por grupo) ---
# Bloque que empieza tras la fila "CUBIERTAS DE LÍNEA" (idx ~19) y su encabezado (idx ~20).
# Columnas: [0]=CR/CT code, [1]=CC code, [2]=forma, [3]=ancho, [4]=largo, [5]=m2,
#           [6]=espesor, [7]=G1, [8]=G2, [9]=G3 core blanco, [10]=G4 UV
orden = 10
for r in cub:
    if len(r) < 11:
        continue
    codes = [str(r[0] or "").strip(), str(r[1] or "").strip()]
    forma = str(r[2] or "")
    ancho, largo = num(r[3]), num(r[4])
    g1, g2, g3, g4 = num(r[7]), num(r[8]), num(r[9]), num(r[10])
    cr = next((c for c in codes if c.startswith("CR-")), None)
    cc = next((c for c in codes if c.startswith("CC-")), None)
    ct = next((c for c in codes if c.startswith("CT-")), None)
    # fila 0.5 sin código (redonda/cuadrada 50)
    if not (cr or cc or ct) and "edonda y cuadrada" in forma and ancho == 0.5 and g1:
        cr, cc = "CR-50", "CC-5050"
    if not (cr or cc or ct) or g1 is None or ancho is None or largo is None:
        continue
    precios = {"G1": g1, "G2": g2, "G3": g3, "G4": g4}
    aa, ll = int(round(ancho*100)), int(round(largo*100))
    med_rect = f"{aa} CM X {ll} CM"
    if cr:
        add(cr, "CUBIERTAS", f"Cubierta redonda {aa} cm Ø",
            precios, descripcion=DESC_CUB.format(forma="REDONDA", medida=f"{aa} CM DIÁMETRO"),
            espesor="12 mm", orden=orden); orden += 1
    if cc:
        add(cc, "CUBIERTAS", f"Cubierta cuadrada {aa}x{ll} cm",
            precios, descripcion=DESC_CUB.format(forma="CUADRADA", medida=med_rect),
            espesor="12 mm", orden=orden); orden += 1
    if ct:
        add(ct, "CUBIERTAS", f"Cubierta rectangular {med_rect}",
            precios, descripcion=DESC_CUB.format(forma="RECTANGULAR", medida=med_rect),
            espesor="12 mm", orden=orden); orden += 1

# =====================================================================
# LOCKERS (PRO / SMART de línea + especial por m²)
# =====================================================================
add("LOQUADST",  "LOCKERS", "Torre Locker Quad L.C. 4 puertas",     {"UNICO": 13210.32}, espesor="L.C.", orden=1)
add("LOTRIPLEST","LOCKERS", "Torre Locker Triple L.C. 3 puertas",   {"UNICO": 13210.32}, espesor="L.C.", orden=2)
add("LOEJECST",  "LOCKERS", "Torre Locker Ejecutivo L.C. 2 puertas",{"UNICO": 13210.32}, espesor="L.C.", orden=3)
add("LODOBLEST", "LOCKERS", "Torre Locker Doble L.C. 2 puertas",    {"UNICO": 13210.32}, espesor="L.C.", orden=4)
# SMART de línea (precio fijo por modelo)
SMART = [
 ("L-100-Q","Quad aluminio 4 puertas",11776.7885),("L-100-T","Triple aluminio 3 puertas",11776.7885),
 ("L-100-D","Doble aluminio 2 puertas",11776.7885),("L-100-E","Ejecutivo aluminio 2 puertas",11776.7885),
 ("L-200-Q","Quad aluminio 8 puertas",22375.8982),("L-200-T","Triple aluminio 6 puertas",22375.8982),
 ("L-200-E","Ejecutivo aluminio 4 puertas",22375.8982),
 ("L-300-Q","Quad aluminio 12 puertas",31796.1513),("L-300-T","Triple aluminio 9 puertas",31796.1513),
 ("L-300-D","Doble aluminio 6 puertas",31796.1513),("L-300-E","Ejecutivo aluminio 6 puertas",31796.1513),
]
for i,(c,n,p) in enumerate(SMART, start=10):
    add(c, "LOCKERS", f"Locker SMART {n}", {"UNICO": p}, espesor="Aluminio", orden=i)
# Locker ESPECIAL por m² (SMART / PRO por espesor)
add("LO-ESP-SMART", "LOCKERS", "Locker especial SMART (por m²)",
    {"3mm":2447.1633, "6mm":2885.0999, "9mm":3542.9793, "12mm":3892.9209},
    descripcion="LOCKER ESPECIAL SMART FABRICADO EN LAMINADO COMPACTO. MEDIDA FINAL: __",
    tipo="m2", unidad="m2", medidas=True, orden=30)
add("LO-ESP-PRO", "LOCKERS", "Locker especial PRO (por m²)",
    {"3mm":2796.7580, "12mm":4170.9866},
    descripcion="LOCKER ESPECIAL PRO FABRICADO EN LAMINADO COMPACTO. MEDIDA FINAL: __",
    tipo="m2", unidad="m2", medidas=True, orden=31)

# =====================================================================
# VESTIDORES
# =====================================================================
add("LOESPECIAL", "VESTIDORES", "Vestidor de línea (PRO)", {"UNICO": 18287.94},
    descripcion="VESTIDOR MARCA THIN LAMINATES FABRICADO DE LAMINADO COMPACTO.", espesor="L.C.", orden=1)
add("VEST-ESP", "VESTIDORES", "Vestidor especial (por m²)",
    {"12mm": 4170.9866}, descripcion="VESTIDOR ESPECIAL FABRICADO EN LAMINADO COMPACTO. MEDIDA FINAL: __",
    tipo="m2", unidad="m2", medidas=True, orden=2)

# =====================================================================
# BANCAS y PALETAS
# =====================================================================
add("CP-001", "BANCAS", "Paleta de pupitre CP-001 (negro/blanco/alumina)", {"UNICO":1090.99}, espesor="9 mm", orden=1)
add("CP-002", "BANCAS", "Paleta de pupitre CP-002 (negro/blanco/alumina)", {"UNICO":1097.94}, espesor="9 mm", orden=2)
add("CP-003", "BANCAS", "Paleta de pupitre CP-003 (negro/blanco/alumina)", {"UNICO":947.43},  espesor="9 mm", orden=3)
add("BAR-76",  "BANCAS", "Banca 76 cm (G1)",  {"G1":2423.3432}, espesor="12 mm", orden=4)
add("BAR-90",  "BANCAS", "Banca 90 cm (G1)",  {"G1":2627.7216}, espesor="12 mm", orden=5)
add("BAR-114", "BANCAS", "Banca 114 cm (G1)", {"G1":2978.0845}, espesor="12 mm", orden=6)
add("BAR-152", "BANCAS", "Banca 152 cm (G1)", {"G1":3532.8257}, espesor="12 mm", orden=7)
add("BAR-ESP", "BANCAS", "Banca especial (por m² G1)", {"G1":RATE_G1},
    descripcion="BANCA ESPECIAL LAMINADO COMPACTO. MEDIDA FINAL: __", tipo="m2", unidad="m2", medidas=True, orden=8)

# =====================================================================
# GRADO LABORATORIO (precio G1 fijo por placa)
# =====================================================================
GLAB = [
 ("EB10396-25","Sólido fenólico 25mm 5x12 lab BLANCO Wilsonart",31076),
 ("EB10296-25","Sólido fenólico 25mm 5x12 lab GRIS Wilsonart",31076),
 ("EB10196-25","Sólido fenólico 25mm 5x12 lab NEGRO Wilsonart",31076),
 ("EB10396-19","Sólido fenólico 19mm 5x12 lab BLANCO Wilsonart",18280),
 ("EB10296-19","Sólido fenólico 19mm 5x12 lab GRIS Wilsonart",18280),
 ("EB10196-19","Sólido fenólico 19mm 5x12 lab NEGRO Wilsonart",18280),
 ("EB10196-12","Sólido fenólico 12mm 5x12 lab NEGRO Wilsonart",15158),
 ("EB10396-12","Sólido fenólico 12mm 5x12 lab BLANCO Wilsonart",15158),
 ("EB10296-12","Sólido fenólico 12mm 5x12 lab GRIS Wilsonart",15158),
]
for i,(c,n,p) in enumerate(GLAB, start=1):
    add(c, "GRADO_LAB", n, {"G1":p}, orden=i)

# =====================================================================
# PANELEX (USD, por m²) — matriz colección × acabado × espesor × caras
# =====================================================================
pan = RAWD["PANELEX"]
# Bloques de colección por fila inicial (0-based) -> 3 filas MT/SM/BR
PAN_BLOCKS = [
    ("UNICOLORES", 6),
    ("MADERA", 10),
    ("DISEÑOS EXCLUSIVOS / GRANITOS Y MÁRMOLES / METALIZADOS", 14),
    ("YOULAB / IMPRESIÓN DIGITAL", 18),
]
ESPESORES = [("4mm",2,3),("6mm",4,5),("8mm",6,7)]  # (nombre, col UF, col DB)
opan = 1
for coleccion, base in PAN_BLOCKS:
    for esp, cuf, cdb in ESPESORES:
        for caras, col in (("UF",cuf),("DB",cdb)):
            precios = {}
            for k,(acab) in enumerate(["MT","SM","BR"]):
                row = pan[base+k]
                p = num(row[col]) if len(row) > col else None
                if p is not None:
                    precios[acab] = p
            if precios:
                cn = "1 cara" if caras=="UF" else "2 caras"
                add(f"PANELEX-{coleccion[:4].upper()}-{esp}-{caras}", "PANELEX",
                    f"Panelex {coleccion} {esp} {cn}", precios,
                    descripcion=f"PANEL PANELEX {coleccion} {esp} ({cn}). PRECIO POR m².",
                    tipo="m2", unidad="m2", moneda="USD", espesor=esp, medidas=True, orden=opan)
                opan += 1

# =====================================================================
# PLACAS (Lamitech / Ralph) — precio público MXN
# =====================================================================
PLACAS = [
 ("PLACA-LAM-ROBLE-48","Lamitech Roble Lineal/Italian Walnut 4x8 12.5mm UV",7775.52),
 ("PLACA-LAM-ATENAS-48","Lamitech Atenas/Tizano/Concrete 4x8 12.5mm UV",8572.50),
 ("PLACA-LAM-ATENAS-410","Lamitech Atenas/Tizano/Concrete 4x10 12.5mm UV",10750.77),
 ("PLACA-LAM-ROBLE-410","Lamitech Roble Lineal/Italian Walnut 4x10 12.5mm UV",9751.26),
 ("PLACA-LAM-DIG-410-C","Lamitech Digital 1 cara negro core café 4x10 12.5mm",11858.07),
 ("PLACA-LAM-DIG-410-N","Lamitech Digital 1 cara negro core negro 4x10 12.5mm",13073.57),
 ("PLACA-RALPH-6MM","Ralph 6mm negro 5x12",6607.66),
]
for i,(c,n,p) in enumerate(PLACAS, start=1):
    add(c, "PLACAS", n, {"UNICO":p}, espesor="12.5 mm", orden=i)

# =====================================================================
# ACCESORIOS / HERRAJES (lockers) — MXN salvo GATNER (USD)
# =====================================================================
ACC = [
 ("G-LOCKER","Grabado a láser por número/diseño 30x30cm máx",120,"MXN"),
 ("FE4161","Pata niveladora locker aluminio 10cm",60,"MXN"),
 ("RP-LOCKER","Ranura tradicional (L:15cm x A:1.1cm x pieza)",50,"MXN"),
 ("GANCHO","Gancho para colgar",97.5,"MXN"),
 ("TO0021","Tubo para colgar",209,"MXN"),
 ("ZOCLO-127","Zoclo lateral 12.7mm",170,"MXN"),
 ("HERRAJES","Herrajes por puerta",150,"MXN"),
 ("C-HEFELE","Cerradura Hafele 22mm para locker",265.78,"MXN"),
 ("C-RIVEN","Cerradura horizontal Riven 4 dígitos con llave maestra",235,"MXN"),
 ("KPC","Kit de portacandado para locker",78.38,"MXN"),
 ("KJL81","Kit de jaladera aluminio para locker",25,"MXN"),
 ("KEB","Kit de 1 escuadra con 2 tornillos T4",50,"MXN"),
 ("T4","Tornillo T4",6.39,"MXN"),
 ("C-GL7P","Cerradura electrónica con teclado Gatner GL7P para locker",170.35,"USD"),
 ("G-921727","Cerradura electrónica Gatner GAT ECO 7100 NW BA",141.4,"USD"),
 ("GAT-BAT","Batería 3.6V Lithium SL-860/S (requerida Gatner)",16.3,"USD"),
 ("GAT-CARD","Set tarjetas configuración Gatner GL7P / GAT ECO",410.5,"USD"),
 # Fillers (CT-ESP) por rango de ancho -> precio PRO / SMART
]
for i,(c,n,p,m) in enumerate(ACC, start=1):
    add(c, "ACCESORIOS", n, {"UNICO":p}, moneda=m, orden=i)
# Fillers: grupo PRO/SMART
FILLERS = [
 ("FILLER-08-10","Filler 8-10 cm",531.3840,464.9610),
 ("FILLER-11-15","Filler 11-15 cm",797.0760,697.4415),
 ("FILLER-16-20","Filler 16-20 cm",1062.7680,929.9220),
 ("FILLER-21-25","Filler 21-25 cm",1328.4601,1162.4026),
 ("FILLER-26-30","Filler 26-30 cm",1594.1521,1394.8831),
 ("FILLER-31-37","Filler 31-37 cm",1966.1209,1720.3558),
]
for i,(c,n,pro,smart) in enumerate(FILLERS, start=50):
    add(c, "ACCESORIOS", n, {"PRO":pro, "SMART":smart}, orden=i)

# =====================================================================
# ADHESIVOS Y PERFILES (USD)
# =====================================================================
ADH = [
 ("7510","Panel-Fix adhesivo blanco o negro 600ml (salchicha)",35),
 ("1522","Panel-Fix promotor P202",95),
 ("15126","Panel-Fix primer 4515W",140),
 ("1589","Cinta Panel-Fix",20),
 ("W101-610","Perfil L ángulo 40x80x2.5mm",100),
 ("W102","Perfil T chica 40x80x2.5mm",100),
 ("W103-610","Perfil T grande 80x80x2.5mm",135),
 ("W101-90","Bracket sencillo 40x80x90 2.5mm",2),
 ("W101-180","Bracket doble 40x80x180mm",3),
]
for i,(c,n,p) in enumerate(ADH, start=1):
    add(c, "ADHESIVOS", n, {"UNICO":p}, moneda="USD", orden=i)

# =====================================================================
# SERVICIOS (MXN, NO aplica descuento)
# =====================================================================
SERV = [
 ("INST-CUB","Instalación por cubierta",250),
 ("INST-FILLER","Instalación por filler",450),
 ("INST-L100","Instalación locker SMART L-100",450),
 ("INST-L200","Instalación locker SMART L-200",800),
 ("INST-L300","Instalación locker SMART L-300",1100),
 ("INST-BANCA","Instalación por banca",300),
 ("INST-TORRE-PRO","Instalación por torre de locker PRO",450),
 ("FLETE-LOCAL","Flete local menor a 60 km",1500),
]
for i,(c,n,p) in enumerate(SERV, start=1):
    add(c, "SERVICIOS", n, {"UNICO":p}, desc_aplica=False, orden=i)

# =====================================================================
# Emitir SQL
# =====================================================================
lines = []
lines.append("-- =====================================================================")
lines.append("-- Cotizador Thin Laminates — 03 · Seed del catálogo (Lista Mayo 2026)")
lines.append("-- Generado por scripts/build_seed.py — NO editar a mano.")
lines.append("-- Correr después de 01_schema.sql y 02_rls.sql.")
lines.append("-- =====================================================================")
lines.append("")
lines.append("-- Limpia catálogo (no toca usuarios/cotizaciones).")
lines.append("truncate table public.producto_precio, public.producto restart identity cascade;")
lines.append("delete from public.familia;")
lines.append("")
lines.append("insert into public.familia (codigo,nombre,aplica_descuento,orden) values")
fv = ",\n".join(f"  ({sqls(c)},{sqls(n)},{str(a).lower()},{o})" for c,n,a,o in FAMILIAS)
lines.append(fv + "\non conflict (codigo) do update set nombre=excluded.nombre, aplica_descuento=excluded.aplica_descuento, orden=excluded.orden;")
lines.append("")

# Productos + precios usando un bloque do/declare para capturar el id
lines.append("do $$")
lines.append("declare pid bigint;")
lines.append("begin")
for p in PRODUCTOS:
    cols = (f"insert into public.producto (codigo_sap,familia_codigo,nombre,descripcion,"
            f"tipo_precio,unidad,moneda,espesor,requiere_medidas,aplica_descuento,orden) values "
            f"({sqls(p['codigo_sap'])},{sqls(p['familia'])},{sqls(p['nombre'])},{sqls(p['descripcion'])},"
            f"{sqls(p['tipo_precio'])},{sqls(p['unidad'])},{sqls(p['moneda'])},{sqls(p['espesor'])},"
            f"{str(p['requiere_medidas']).lower()},{str(p['aplica_descuento']).lower()},{p['orden']}) "
            f"returning producto_id into pid;")
    lines.append("  " + cols)
    for g, pr in p["precios"].items():
        lines.append(f"  insert into public.producto_precio (producto_id,grupo,precio) values (pid,{sqls(g)},{pr});")
lines.append("end $$;")
lines.append("")

with open(OUT_SQL, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))

with open(OUT_JSON, "w", encoding="utf-8") as f:
    json.dump({"familias": FAMILIAS, "productos": PRODUCTOS,
               "tarifas_m2_cubiertas": M2_RATES}, f, ensure_ascii=False, indent=1)

# Resumen
from collections import Counter
byf = Counter(p["familia"] for p in PRODUCTOS)
print("Tarifas m² cubiertas:", M2_RATES)
print("Productos por familia:")
for c,_,_,_ in FAMILIAS:
    print(f"  {c:12} {byf.get(c,0)}")
print("TOTAL productos:", len(PRODUCTOS))
print("OK ->", os.path.abspath(OUT_SQL))

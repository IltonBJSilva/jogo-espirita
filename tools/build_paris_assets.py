"""Prepara a arte do mapa "Paris, 1857" a partir da imagem de referencia.

Uso: python tools/build_paris_assets.py

Gera:
  assets/tilesets/paris_1857/paris_1857_atlas.png      arte base (atlas 48x32 tiles de 32px)
  assets/tilesets/paris_1857/paris_1857_foreground.png arvores/lampioes recortados (Y-Sort)
  data/maps/paris_1857_layout.json                     colisoes e camadas por celula

Depois rode o construtor Godot (veja README.md, "Regenerar a arte") para gerar os
TileSets e as TileMapLayers a partir desses arquivos.
"""
import colorsys
import json
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/references/paris_1857_reference.png"
OUT_DIR = ROOT / "assets/tilesets/paris_1857"
LAYOUT = ROOT / "data/maps/paris_1857_layout.json"
TILE = 32
COLS, ROWS = 48, 32

# --- Retangulos em coordenadas de celula (x0, y0, x1, y1), inclusivos -----

SOLID = [
    # Livraria e casas ao fundo (canto superior esquerdo)
    (0, 0, 10, 17), (1, 18, 1, 18), (2, 18, 4, 18), (9, 18, 9, 18),
    # Jardim e arvores entre a Livraria e a Sociedade
    (10, 0, 17, 6), (11, 7, 11, 9), (14, 7, 16, 9),
    (14, 11, 14, 13), (12, 12, 12, 13), (13, 12, 16, 15),
    # Lampioes
    (17, 15, 17, 16), (30, 15, 30, 16), (18, 26, 18, 27), (28, 26, 28, 27),
    # Sociedade Espirita de Paris (fachada e grades; escadaria livre)
    (17, 0, 33, 9), (17, 10, 21, 11), (27, 10, 33, 11),
    # Jardim/arvores a direita da Sociedade
    (34, 4, 34, 5), (34, 8, 35, 11), (31, 12, 35, 16), (34, 15, 36, 18),
    # Residencia de Allan Kardec e grade (portao 42-44 livre)
    (36, 0, 47, 17), (35, 18, 41, 19), (45, 18, 47, 19),
    # Fonte da praca + banco
    (21, 17, 26, 17), (20, 18, 27, 21), (21, 22, 26, 22), (22, 23, 24, 23),
    # Arvores e canteiros da praca
    (15, 22, 17, 26), (29, 22, 32, 25),
    # Carruagem
    (2, 20, 9, 23),
    # Grade e jardim inferior esquerdo; casa inferior esquerda
    (7, 24, 14, 27), (0, 25, 8, 31), (4, 24, 5, 24),
    # Telhados inferiores
    (9, 28, 23, 31), (25, 29, 27, 31),
    # Arbusto junto a ponte
    (36, 22, 39, 25),
    # Canal (agua + mureta) e ponte
    (26, 31, 47, 31), (27, 30, 47, 30), (29, 29, 47, 29), (31, 28, 47, 28),
    (33, 27, 47, 27), (36, 26, 47, 26), (39, 25, 47, 25), (40, 21, 47, 24),
]

# Celulas desenhadas na camada Environment (construcoes) — o restante da
# arte de construcoes/decoracao fica separado para facilitar edicao futura.
ENVIRONMENT = [
    (0, 0, 10, 18), (17, 0, 33, 11), (36, 0, 47, 19), (0, 24, 8, 31),
    (9, 28, 23, 31), (40, 21, 47, 26),
]
DECORATION = [
    (10, 0, 16, 10), (12, 11, 16, 16), (17, 12, 18, 17), (29, 12, 30, 17),
    (31, 10, 35, 18), (32, 0, 37, 5), (19, 16, 28, 23), (14, 19, 18, 26),
    (28, 18, 33, 26), (1, 19, 10, 23), (7, 24, 14, 27), (18, 23, 18, 27),
    (28, 23, 28, 27), (35, 20, 39, 25), (24, 28, 28, 31),
]
# Objetos altos com profundidade (Y-Sort): o jogador passa ATRAS deles quando
# esta acima da base e NA FRENTE quando esta abaixo dela.
# (nome, tipo, (x0, y0, x1, y1) em pixels, base_y em pixels = pe do tronco/poste)
DEPTH_OBJECTS = [
    ("cerejeira", "cherry", (298, 78, 470, 305), 300),
    ("arvore_sociedade_esq", "tree", (372, 222, 542, 436), 430),
    ("arvore_beco", "tree", (1020, 0, 1180, 185), 180),
    ("arbusto_lilas", "tree", (1105, 250, 1185, 335), 330),
    ("arvore_sociedade_dir", "tree", (1035, 330, 1186, 526), 520),
    ("arvore_praca_esq", "tree", (458, 600, 612, 800), 795),
    ("arvore_praca_dir", "tree", (922, 580, 1088, 786), 782),
    ("lampiao_1", "lamp", (546, 385, 592, 542), 538),
    ("lampiao_2", "lamp", (946, 385, 992, 542), 538),
    ("lampiao_3", "lamp", (564, 738, 610, 896), 893),
    ("lampiao_4", "lamp", (900, 748, 946, 896), 893),
]


def cells(rects):
    out = set()
    for x0, y0, x1, y1 in rects:
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                if 0 <= x < COLS and 0 <= y < ROWS:
                    out.add((x, y))
    return out


def patch(img, dest, src_xy, feather=6):
    """Copia um retalho de `src_xy` sobre `dest`, com bordas suavizadas."""
    x0, y0, x1, y1 = dest
    w, h = x1 - x0, y1 - y0
    piece = img.crop((src_xy[0], src_xy[1], src_xy[0] + w, src_xy[1] + h))
    mask = Image.new("L", (w, h), 0)
    inner = Image.new("L", (w - 2 * feather, h - 2 * feather), 255)
    mask.paste(inner, (feather, feather))
    mask = mask.filter(ImageFilter.GaussianBlur(feather / 2))
    img.paste(piece, (x0, y0), mask)


def clean_reference(img):
    # 1) Remove o Allan Kardec desenhado na praca (ele sera um NPC animado).
    patch(img, (748, 412, 842, 566), (648, 412))
    # 2) Remove a faixa "Paris, 1857" (agora faz parte do HUD), repetindo a
    #    fileira de mansardas que aparece logo a direita dela.
    for x in range(8, 312, 76):
        patch(img, (x, 6, x + 84, 88), (290, 6), feather=4)
    return img


def _hsv(p):
    h, sat, v = colorsys.rgb_to_hsv(p[0] / 255, p[1] / 255, p[2] / 255)
    return h * 360, sat, v


def is_object_pixel(p, kind):
    """Pixel pertence ao objeto (e nao ao chao de paralelepipedos)?"""
    hue, sat, v = _hsv(p)
    # Paralelepipedos: avermelhados/acinzentados com saturacao ~0.2-0.43.
    if kind == "lamp":
        # ferro escuro, metal aceso (laranja saturado) e vidro quase branco;
        # o reflexo da luz no chao (pouco saturado) fica de fora
        return v < 0.3 or (10 <= hue <= 60 and sat > 0.55) or v > 0.93
    if 50 <= hue <= 175 and sat > 0.25 and v > 0.1:  # folhagem
        return True
    if kind == "cherry" and hue >= 295 and sat > 0.18 and v > 0.42:  # flores rosadas
        return True
    if 8 <= hue <= 40 and sat > 0.38 and 0.1 < v < 0.62:  # tronco
        return True
    return v < 0.15  # contorno


def _components(mask, w, h):
    seen = bytearray(w * h)
    comps = []
    for i in range(w * h):
        if not mask[i] or seen[i]:
            continue
        stack, comp = [i], []
        seen[i] = 1
        while stack:
            j = stack.pop()
            comp.append(j)
            x, y = j % w, j // w
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < w and 0 <= ny < h:
                    k = ny * w + nx
                    if mask[k] and not seen[k]:
                        seen[k] = 1
                        stack.append(k)
        comps.append(comp)
    return comps


def object_mask(img, kind, rect):
    """Mascara limpa do objeto: so o maior bloco conectado, sem buracos."""
    x0, y0, x1, y1 = rect
    crop = img.crop(rect)
    w, h = crop.size
    px = crop.load()
    mask = bytearray(w * h)
    for y in range(h):
        for x in range(w):
            mask[y * w + x] = 1 if is_object_pixel(px[x, y], kind) else 0
    comps = _components(mask, w, h)
    keep = bytearray(w * h)
    if comps:
        biggest = max(len(c) for c in comps)
        for comp in comps:
            if len(comp) >= max(30, biggest * 0.08):  # descarta pontos de chao
                for i in comp:
                    keep[i] = 1
    # preenche buracos: tudo que nao se liga a borda pelo "fora" vira objeto
    outside = bytearray(w * h)
    stack = [i for i in range(w * h) if not keep[i] and
             (i % w in (0, w - 1) or i // w in (0, h - 1))]
    for i in stack:
        outside[i] = 1
    while stack:
        j = stack.pop()
        x, y = j % w, j // w
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h:
                k = ny * w + nx
                if not keep[k] and not outside[k]:
                    outside[k] = 1
                    stack.append(k)
    # so buracos pequenos (vaos entre folhas) sao preenchidos; areas grandes
    # cercadas pelo objeto sao chao de verdade e continuam transparentes
    holes = bytearray(w * h)
    for i in range(w * h):
        holes[i] = 1 if (not keep[i] and not outside[i]) else 0
    for comp in _components(holes, w, h):
        if len(comp) <= 120:
            for i in comp:
                keep[i] = 1
    alpha = Image.new("L", (w, h), 0)
    ap = alpha.load()
    for i in range(w * h):
        if keep[i]:
            ap[i % w, i // w] = 255
    # suaviza a borda serrilhada sem crescer sobre o chao
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
    return alpha


def build_foreground(img):
    """Imagem com apenas os objetos altos + base (Y-Sort) de cada celula."""
    fg = Image.new("RGBA", img.size, (0, 0, 0, 0))
    bases = {}
    for _name, kind, rect, base in DEPTH_OBJECTS:
        alpha = object_mask(img, kind, rect)
        piece = img.crop(rect).convert("RGBA")
        piece.putalpha(alpha)
        fg.alpha_composite(piece, (rect[0], rect[1]))
        bbox = alpha.getbbox()
        if not bbox:
            continue
        for cy in range((rect[1] + bbox[1]) // TILE, (rect[1] + bbox[3] - 1) // TILE + 1):
            for cx in range((rect[0] + bbox[0]) // TILE, (rect[0] + bbox[2] - 1) // TILE + 1):
                bases[(cx, cy)] = max(bases.get((cx, cy), 0), base)
    # celulas sem nenhum pixel de objeto nao entram na camada
    a = fg.getchannel("A")
    for cell in list(bases):
        box = (cell[0] * TILE, cell[1] * TILE, cell[0] * TILE + TILE, cell[1] * TILE + TILE)
        if not a.crop(box).getbbox():
            del bases[cell]
    return fg, bases


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    LAYOUT.parent.mkdir(parents=True, exist_ok=True)
    img = Image.open(SRC).convert("RGB")
    assert img.size == (COLS * TILE, ROWS * TILE), img.size
    img = clean_reference(img)
    img.save(OUT_DIR / "paris_1857_atlas.png")
    fg, bases = build_foreground(img)
    fg.save(OUT_DIR / "paris_1857_foreground.png")

    env = cells(ENVIRONMENT)
    deco = cells(DECORATION) - env
    layout = {
        "tile_size": TILE,
        "cols": COLS,
        "rows": ROWS,
        "solid": sorted(map(list, cells(SOLID))),
        "environment": sorted(map(list, env)),
        "decoration": sorted(map(list, deco)),
        # [x, y, base_y_em_pixels] — base usada pelo Y-Sort de cada celula
        "foreground": sorted([x, y, b] for (x, y), b in bases.items()),
    }
    LAYOUT.write_text(json.dumps(layout, separators=(",", ":")), encoding="utf8")
    print("ok:", OUT_DIR, LAYOUT)


if __name__ == "__main__":
    main()

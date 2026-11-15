"""Gera a arte do "Jardim da Reflexão" (plano espiritual) — capítulo 2, epílogo.

Uso: python tools/build_spiritual.py
Gera (30x17 tiles de 32px = 960x544, mesmo formato dos interiores):
  assets/tilesets/plano_espiritual/plano_espiritual_atlas.png
  data/maps/plano_espiritual_layout.json

Mesma técnica dos outros mapas: desenho em meia resolução (tiles de 16px),
ampliado 2x com vizinho-mais-próximo. Paleta suave: violeta, lavanda, dourado
e verde-claro; nada sombrio. Reaproveita helpers de tools/build_interiors.py
(sem alterá-lo).
"""
import json
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_interiors import COLS, ROWS, T, W, H, OUTLINE, cells, rect, shade  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
MAP_ID = "plano_espiritual"

GRASS = (120, 150, 128)
GRASS_L = (150, 180, 150)
LAVENDER = (168, 150, 206)
PATH = (236, 226, 196)
PATH_D = (206, 190, 156)
GOLD = (232, 196, 110)
GOLD_D = (190, 150, 80)
STONE = (226, 222, 236)
STONE_D = (176, 168, 196)
WATER = (150, 214, 236)
WATER_L = (214, 244, 252)
LEAF = (120, 186, 150)
LEAF_L = (176, 230, 196)
LEAF_D = (70, 120, 100)
TRUNK = (150, 120, 110)
WOOD = (170, 140, 120)

rng = random.Random(1869)


def sky(d):
    """Horizonte crepuscular (fileiras 0-3): do violeta ao dourado, com estrelas."""
    top, bottom = (70, 52, 120), (236, 186, 140)
    h = 4 * T
    for y in range(h):
        f = y / (h - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * f) for i in range(3))
        d.line((0, y, W, y), fill=c)
    for _ in range(60):
        x, y = rng.randrange(W), rng.randrange(0, 2 * T)
        d.point((x, y), fill=(250, 240, 220))
    # nuvens suaves
    for cx, cy, r in ((60, 40, 22), (150, 48, 16), (330, 36, 20), (420, 46, 18)):
        for k in range(3):
            d.ellipse((cx - r + k * 10, cy - 6 + (k % 2) * 3, cx + r + k * 10, cy + 6 + (k % 2) * 3),
                      fill=(244, 214, 200))
    # borda do terraço (o jardim "flutua" sobre as nuvens)
    rect(d, 0, 4 * T - 4, W, 4 * T, (250, 236, 220))


def ground(d):
    rect(d, 0, 4 * T, W, H, GRASS)
    # manchas suaves de lavanda e verde-claro
    for _ in range(30):
        x, y = rng.randrange(W), rng.randrange(4 * T, H)
        r = rng.randrange(6, 14)
        d.ellipse((x - r, y - r * 0.6, x + r, y + r * 0.6),
                  fill=rng.choice(((126, 156, 134), (128, 152, 140), (124, 146, 130))))
    for _ in range(1100):
        x, y = rng.randrange(W), rng.randrange(4 * T, H)
        d.point((x, y), fill=rng.choice((GRASS_L, shade(GRASS, -12), (160, 186, 160), (156, 150, 186))))


def path(d, x0, y0, x1, y1):
    rect(d, x0, y0, x1, y1, PATH)
    for y in range(y0, y1, 6):
        for x in range(x0 + ((y // 6) % 2) * 4, x1, 8):
            d.rectangle((x, y, x + 6, y + 4), fill=rng.choice((PATH, shade(PATH, -8), (244, 236, 210))),
                        outline=PATH_D)


def luminous_tree(d, cx, base, r=22):
    rect(d, cx - 3, base - 18, cx + 3, base, TRUNK, OUTLINE)
    for dx, dy, rr in ((0, -30, r), (-12, -22, r - 8), (12, -22, r - 8), (0, -40, r - 10)):
        d.ellipse((cx + dx - rr, base + dy - rr * 0.8, cx + dx + rr, base + dy + rr * 0.8),
                  fill=LEAF, outline=LEAF_D)
    for _ in range(26):
        a = rng.random() * math.tau
        rr = rng.random() * r
        x, y = cx + math.cos(a) * rr, base - 30 + math.sin(a) * rr * 0.7
        d.point((x, y), fill=rng.choice((LEAF_L, (250, 240, 200), (220, 200, 250))))


def flowers(d, x0, y0, x1, y1, n=18):
    for _ in range(n):
        x, y = rng.randrange(x0, x1), rng.randrange(y0, y1)
        c = rng.choice(((250, 226, 150), (230, 200, 250), (250, 250, 240), (200, 230, 250)))
        d.point((x, y), fill=c)
        d.point((x + 1, y), fill=shade(c, -30))
        d.point((x, y + 1), fill=LEAF_D)


def hedge(d, x0, y0, x1, y1):
    rect(d, x0, y0, x1, y1, LEAF_D)
    for _ in range(max(1, (x1 - x0) * (y1 - y0) // 14)):
        x, y = rng.randrange(x0, x1), rng.randrange(y0, y1)
        r = rng.randrange(3, 6)
        d.ellipse((x - r, y - r, x + r, y + r), fill=rng.choice((LEAF, shade(LEAF, 12), shade(LEAF, -10))),
                  outline=LEAF_D)
        if rng.random() < 0.3:
            d.point((x, y - 1), fill=rng.choice(((250, 236, 190), (230, 210, 250))))


def fountain(d, cx, cy):
    d.ellipse((cx - 30, cy - 18, cx + 30, cy + 18), fill=STONE, outline=STONE_D)
    d.ellipse((cx - 25, cy - 14, cx + 25, cy + 14), fill=WATER, outline=(110, 170, 200))
    for k in range(3):
        d.arc((cx - 20 + k * 6, cy - 8 + k * 2, cx + 20 - k * 6, cy + 8 - k * 2), 200, 340, fill=WATER_L)
    rect(d, cx - 4, cy - 22, cx + 4, cy, STONE, STONE_D)
    d.ellipse((cx - 10, cy - 26, cx + 10, cy - 18), fill=STONE, outline=STONE_D)
    for dx in (-6, 0, 6):  # jato de água cristalina
        d.line((cx + dx // 2, cy - 26, cx + dx, cy - 36), fill=WATER_L)


def portico(d, cx, top):
    for px in (cx - 30, cx + 22):
        rect(d, px, top + 6, px + 8, top + 44, STONE, STONE_D)
        rect(d, px - 2, top + 42, px + 10, top + 46, STONE_D, OUTLINE)
    d.arc((cx - 30, top - 8, cx + 30, top + 40), 180, 360, fill=STONE, width=6)
    d.arc((cx - 30, top - 8, cx + 30, top + 40), 180, 360, fill=STONE_D, width=1)
    rect(d, cx - 22, top + 14, cx + 22, top + 44, (250, 236, 200))  # luz suave atravessando o arco
    for _ in range(20):
        d.point((rng.randrange(cx - 20, cx + 20), rng.randrange(top + 16, top + 42)), fill=(255, 250, 230))
    rect(d, cx - 34, top + 46, cx + 34, top + 50, STONE_D, OUTLINE)


def bench(d, x, y):
    rect(d, x, y, x + 2 * T, y + 6, WOOD, OUTLINE)
    rect(d, x, y - 4, x + 2 * T, y, shade(WOOD, -20), OUTLINE)
    for lx in (x + 3, x + 2 * T - 5):
        rect(d, lx, y + 6, lx + 2, y + 9, shade(WOOD, -40))


def glow(img, spots):
    g = Image.new("RGB", img.size, (0, 0, 0))
    gd = ImageDraw.Draw(g)
    for x, y, r, c in spots:
        for k in range(r, 0, -2):
            f = 1 - k / r
            gd.ellipse((x - k, y - k * 0.8, x + k, y + k * 0.8), fill=tuple(int(v * f) for v in c))
    return ImageChops.add(img, g.filter(ImageFilter.GaussianBlur(5)))


def main():
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    ground(d)
    sky(d)
    # caminhos de luz: entrada (baixo) -> fonte -> pórtico; ramos para as árvores
    path(d, 14 * T, 5 * T, 16 * T, 16 * T)
    path(d, 7 * T, 9 * T + 4, 23 * T, 10 * T + 4)
    path(d, 5 * T, 9 * T, 7 * T, 10 * T + 4)
    # círculo de luz na entrada
    d.ellipse((14 * T - 6, 14 * T, 16 * T + 6, 15 * T + 10), outline=GOLD)
    # canteiros de flores
    for (a, b, c, e) in ((2 * T, 5 * T, 12 * T, 8 * T), (18 * T, 5 * T, 28 * T, 8 * T),
                         (2 * T, 11 * T, 12 * T, 15 * T), (18 * T, 11 * T, 28 * T, 15 * T)):
        flowers(d, a, b, c, e, 40)
    sides = [(0, 4 * T, T, H), (29 * T, 4 * T, W, H), (0, 16 * T, W, H)]
    for s in sides:
        hedge(d, *s)
    portico(d, 15 * T, 3 * T + 4)
    fountain(d, 15 * T, 9 * T + 12)
    luminous_tree(d, 5 * T + 8, 8 * T + 8, 24)       # árvore da reflexão (esquerda)
    luminous_tree(d, 24 * T + 8, 8 * T + 8, 24)
    luminous_tree(d, 3 * T + 8, 13 * T + 8, 18)
    luminous_tree(d, 26 * T + 8, 13 * T + 8, 18)
    bench(d, 8 * T, 11 * T + 6)
    bench(d, 20 * T, 11 * T + 6)
    for _ in range(70):  # partículas de luz flutuando
        x, y = rng.randrange(T, W - T), rng.randrange(4 * T, 16 * T)
        d.point((x, y), fill=(255, 248, 220))
        d.point((x + 1, y), fill=(240, 220, 170))
    img = glow(img, [(15 * T, 4 * T + 20, 50, (60, 54, 30)), (15 * T, 9 * T + 12, 46, (30, 50, 60)),
                     (5 * T + 8, 7 * T, 40, (30, 50, 36)), (24 * T + 8, 7 * T, 40, (30, 50, 36)),
                     (15 * T, 14 * T + 10, 26, (60, 50, 26))])
    out_dir = ROOT / f"assets/tilesets/{MAP_ID}"
    out_dir.mkdir(parents=True, exist_ok=True)
    img.resize((W * 2, H * 2), Image.NEAREST).save(out_dir / f"{MAP_ID}_atlas.png")

    edges = [(0, 0, 29, 3), (0, 0, 0, 16), (29, 0, 29, 16), (0, 16, 29, 16)]
    objects = [
        (13, 3, 13, 5), (16, 3, 16, 5), (14, 3, 15, 4),   # pórtico (pilares e arco)
        (13, 8, 16, 10),                                   # fonte
        (4, 6, 6, 8), (23, 6, 25, 8),                      # árvores grandes
        (3, 12, 3, 13), (26, 12, 26, 13),                  # árvores pequenas
        (8, 11, 9, 11), (20, 11, 21, 11),                  # bancos
    ]
    env = cells(edges)
    layout = {
        "tile_size": 32, "cols": COLS, "rows": ROWS,
        "solid": sorted(map(list, cells(edges + objects))),
        "environment": sorted(map(list, env)),
        "decoration": sorted(map(list, cells(objects) - env)),
        "foreground": [],
    }
    (ROOT / f"data/maps/{MAP_ID}_layout.json").write_text(json.dumps(layout, separators=(",", ":")),
                                                          encoding="utf8")
    print("ok:", MAP_ID)


if __name__ == "__main__":
    main()

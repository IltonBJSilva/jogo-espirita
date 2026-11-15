"""Gera a arte dos interiores da expansão (mesma técnica e paleta da Livraria).

Uso: python tools/build_interiors.py [id ...]
Gera, para cada interior (30x17 tiles de 32px = 960x544):
  assets/tilesets/<id>/<id>_atlas.png
  data/maps/<id>_layout.json        (colisões e camadas por célula)

Interiores:
  residencia_kardec  escritório/sala de estar de Allan Kardec e Amélie Boudet
  sociedade_salao    salão de reuniões e estudos da Sociedade
  tipografia         oficina de impressão (Revista Espírita, 1858)

Desenho em meia resolução (tiles de 16px) ampliado 2x com vizinho-mais-próximo,
como em tools/build_livraria_assets.py (que não é alterado).
"""
import json
import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
COLS, ROWS = 30, 17
T = 16
W, H = COLS * T, ROWS * T

OUTLINE = (24, 14, 14)
WOOD_D = (52, 30, 22)
WOOD_M = (84, 50, 32)
WOOD_L = (120, 76, 46)
WOOD_H = (150, 100, 62)
GOLD = (201, 160, 74)
GOLD_D = (150, 112, 50)
WINE = (110, 32, 48)
WINE_D = (80, 22, 36)
GREEN = (40, 76, 56)
GREEN_D = (28, 52, 40)
NAVY = (36, 44, 78)
PURPLE = (82, 48, 104)
OCHRE = (168, 118, 52)
PAPER = (232, 220, 190)
PAPER_D = (200, 186, 152)
IRON = (46, 44, 50)
IRON_L = (84, 82, 92)
STONE = (150, 140, 130)
BOOKS = [WINE, GREEN, NAVY, PURPLE, OCHRE, (96, 58, 36), (60, 30, 40), (46, 62, 52)]
GLASS = (34, 46, 84)

rng = random.Random(1858)


def rect(d, x0, y0, x1, y1, fill, outline=None):
    d.rectangle((x0, y0, x1 - 1, y1 - 1), fill=fill, outline=outline)


def shade(c, k):
    return tuple(max(0, min(255, int(v + k))) for v in c)


# --- Peças comuns --------------------------------------------------------------

def floor_planks(d, y0, y1, base):
    cols = [base, shade(base, -10), shade(base, 8)]
    for y in range(y0, y1, 8):
        x = -rng.randrange(0, 40)
        while x < W:
            length = rng.choice((32, 40, 48, 56))
            c = rng.choice(cols)
            rect(d, x, y, x + length, y + 8, c)
            d.line((x, y + 7, x + length - 1, y + 7), fill=shade(base, -48))
            d.line((x, y, x, y + 7), fill=shade(base, -48))
            d.line((x + 1, y, x + length - 2, y), fill=shade(c, 14))
            x += length


def floor_parquet(d, y0, y1, base):
    """Parquete em espinha de peixe (residência)."""
    for y in range(y0, y1, 8):
        for x in range(0, W, 16):
            flip = ((x // 16) + (y // 8)) % 2
            c = shade(base, 6 if flip else -6)
            rect(d, x, y, x + 16, y + 8, c)
            if flip:
                d.line((x, y + 7, x + 15, y), fill=shade(base, -30))
            else:
                d.line((x, y, x + 15, y + 7), fill=shade(base, -30))
            d.point((x + 3, y + 3), fill=shade(base, 18))


def wallpaper(d, y1, base, accent, pattern="diamond"):
    rect(d, 0, 0, W, y1, base)
    for y in range(4, y1, 8):
        for x in range((y // 8 % 2) * 4, W, 8):
            if pattern == "diamond":
                d.point((x, y), fill=accent)
            else:
                d.line((x, y - 1, x, y + 1), fill=accent)
    rect(d, 0, y1 - 6, W, y1, WOOD_M)  # lambri
    d.line((0, y1 - 6, W, y1 - 6), fill=WOOD_H)
    d.line((0, y1 - 1, W, y1 - 1), fill=OUTLINE)


def side_walls(d, door_cols=(14, 15)):
    for x0 in (0, 29 * T):
        rect(d, x0, 0, x0 + T, H, WOOD_D)
        for y in range(0, H, 12):
            rect(d, x0 + 2, y + 1, x0 + T - 2, y + 11, WOOD_M, OUTLINE)
            d.line((x0 + 3, y + 2, x0 + T - 4, y + 2), fill=WOOD_L)
    rect(d, 0, 16 * T, W, H, WOOD_D)
    d.line((0, 16 * T, W, 16 * T), fill=WOOD_H)
    for x in range(0, W, 12):
        d.line((x, 16 * T + 2, x, H), fill=OUTLINE)
    a, b = door_cols
    rect(d, a * T, 16 * T, (b + 1) * T, H, (70, 40, 28), OUTLINE)
    rect(d, a * T + 2, 16 * T + 2, (b + 1) * T - 2, H, WOOD_L)
    d.point(((b + 1) * T - 6, 16 * T + 8), fill=GOLD)
    rect(d, a * T, 15 * T + 2, (b + 1) * T, 16 * T, WINE_D, OUTLINE)  # capacho
    for x in range(a * T + 3, (b + 1) * T - 2, 3):
        d.line((x, 15 * T + 4, x, 16 * T - 3), fill=WINE)


def bookshelf(d, x0, x1, y0=4, y1=74):
    rect(d, x0, y0, x1, y1, WOOD_D, OUTLINE)
    rect(d, x0 + 3, y0 + 3, x1 - 3, y1 - 2, (30, 17, 13))
    for sy in range(y0 + 3, y1 - 16, 17):
        bx = x0 + 4
        while bx < x1 - 6:
            bw = rng.choice((2, 3, 3, 4))
            bh = rng.randrange(11, 16)
            c = rng.choice(BOOKS)
            if rng.random() > 0.08:
                rect(d, bx, sy + 16 - bh, bx + bw, sy + 16, c)
                d.line((bx, sy + 16 - bh, bx, sy + 15), fill=shade(c, 30))
                if bh > 12:
                    d.point((bx + bw // 2, sy + 19 - bh), fill=GOLD)
            bx += bw
        rect(d, x0 + 2, sy + 16, x1 - 2, sy + 18, WOOD_L)
        d.line((x0 + 2, sy + 16, x1 - 3, sy + 16), fill=WOOD_H)
    rect(d, x0, y0, x1, y0 + 2, WOOD_L)


def window(d, x0, x1, y0, y1, curtain=PURPLE):
    rect(d, x0 - 3, y0 - 3, x1 + 3, y1 + 3, WOOD_D, OUTLINE)
    rect(d, x0, y0, x1, y1, GLASS)
    for i in range(0, y1 - y0, 3):
        if i % 6 == 0:
            d.line((x0, y0 + i, x1 - 1, y0 + i), fill=(40, 54, 94))
    d.point((x0 + 6, y0 + 7), fill=PAPER)
    d.point((x0 + (x1 - x0) * 2 // 3, y0 + 12), fill=PAPER)
    mx = (x0 + x1) // 2
    rect(d, mx - 1, y0, mx + 1, y1, WOOD_D)
    rect(d, x0, (y0 + y1) // 2 - 1, x1, (y0 + y1) // 2 + 1, WOOD_D)
    for cx in (x0 - 6, x1 - 4):
        rect(d, cx, y0 - 6, cx + 10, y1 + 8, curtain, OUTLINE)
        for k in range(2, 10, 3):
            d.line((cx + k, y0 - 5, cx + k, y1 + 6), fill=shade(curtain, 22))
    rect(d, x0 - 8, y0 - 9, x1 + 8, y0 - 5, GOLD_D, OUTLINE)


def rug(d, x0, y0, x1, y1, base, border):
    rect(d, x0, y0, x1, y1, shade(base, -25), OUTLINE)
    rect(d, x0 + 3, y0 + 3, x1 - 3, y1 - 3, border)
    rect(d, x0 + 5, y0 + 5, x1 - 5, y1 - 5, base)
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    for r in range(4, min(x1 - x0, y1 - y0) // 2 - 4, 6):
        d.polygon([(cx, cy - r), (cx + r * 2, cy), (cx, cy + r), (cx - r * 2, cy)], outline=border)


def chair(d, x, y, color=WINE_D, facing="down"):
    if facing == "down":
        rect(d, x + 2, y, x + 12, y + 4, WOOD_M, OUTLINE)  # encosto
        rect(d, x + 2, y + 3, x + 12, y + 11, color, OUTLINE)
    else:
        rect(d, x + 2, y + 1, x + 12, y + 9, color, OUTLINE)
        rect(d, x + 2, y + 8, x + 12, y + 12, WOOD_M, OUTLINE)


def table(d, x0, y0, x1, y1, top=WOOD_M):
    rect(d, x0, y0 + 3, x1, y1 + 3, (30, 18, 14))
    rect(d, x0, y0, x1, y1, top, OUTLINE)
    d.line((x0 + 1, y0 + 1, x1 - 2, y0 + 1), fill=shade(top, 30))
    for x in (x0 + 2, x1 - 4):
        rect(d, x, y1, x + 2, y1 + 3, WOOD_D)


def candle(d, x, y):
    rect(d, x, y + 3, x + 4, y + 7, GOLD_D, OUTLINE)
    rect(d, x + 1, y - 1, x + 3, y + 3, PAPER)
    d.point((x + 2, y - 2), fill=(255, 220, 140))


def papers(d, x, y, n=3):
    for i in range(n):
        ox, oy = rng.randrange(-2, 3), rng.randrange(-1, 2)
        rect(d, x + ox + i * 2, y + oy + i, x + ox + i * 2 + 7, y + oy + i + 9, PAPER, PAPER_D)
        d.line((x + ox + i * 2 + 2, y + oy + i + 3, x + ox + i * 2 + 5, y + oy + i + 3), fill=(150, 130, 110))


def plant(d, cx, cy):
    rect(d, cx - 5, cy - 2, cx + 5, cy + 6, (140, 70, 40), OUTLINE)
    for dx, dy in ((-6, -6), (0, -10), (6, -6), (-3, -3), (3, -3), (0, -6)):
        d.ellipse((cx + dx - 4, cy + dy - 4, cx + dx + 4, cy + dy + 3), fill=GREEN, outline=GREEN_D)


def frame_picture(d, x0, y0, x1, y1, inner):
    rect(d, x0, y0, x1, y1, GOLD_D, OUTLINE)
    rect(d, x0 + 2, y0 + 2, x1 - 2, y1 - 2, inner)


def lighting(img, lamps, warm=(70, 50, 24), vignette=0.45):
    glow = Image.new("RGB", img.size, (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for x, y, r in lamps:
        for k in range(r, 0, -2):
            f = 1 - k / r
            gd.ellipse((x - k, y - k * 0.8, x + k, y + k * 0.8),
                       fill=(int(warm[0] * f), int(warm[1] * f), int(warm[2] * f)))
    img = ImageChops.add(img, glow.filter(ImageFilter.GaussianBlur(6)))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse((-60, -50, W + 60, H + 50), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(40))
    dark = Image.new("RGB", img.size, (20, 10, 16))
    return Image.composite(img, Image.blend(img, dark, vignette), mask)


def cells(rects):
    out = set()
    for x0, y0, x1, y1 in rects:
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                if 0 <= x < COLS and 0 <= y < ROWS:
                    out.add((x, y))
    return out


WALLS = [(0, 0, 29, 4), (0, 0, 0, 16), (29, 0, 29, 16), (0, 16, 29, 16)]


def save(map_id, img, furniture, deco_extra=()):
    out_dir = ROOT / f"assets/tilesets/{map_id}"
    out_dir.mkdir(parents=True, exist_ok=True)
    img.resize((W * 2, H * 2), Image.NEAREST).save(out_dir / f"{map_id}_atlas.png")
    env = cells(WALLS)
    layout = {
        "tile_size": 32, "cols": COLS, "rows": ROWS,
        "solid": sorted(map(list, cells(WALLS + list(furniture)))),
        "environment": sorted(map(list, env)),
        "decoration": sorted(map(list, cells(list(furniture) + list(deco_extra)) - env)),
        "foreground": [],
    }
    (ROOT / f"data/maps/{map_id}_layout.json").write_text(
        json.dumps(layout, separators=(",", ":")), encoding="utf8")
    print("ok:", map_id)


# --- Residência de Allan Kardec -------------------------------------------------

def residencia_kardec():
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    floor_parquet(d, 5 * T, 16 * T, (118, 74, 44))
    wallpaper(d, 5 * T, GREEN_D, (52, 92, 66))
    # estantes (esquerda) e janela (direita)
    bookshelf(d, 1 * T, 8 * T)
    window(d, 23 * T + 8, 27 * T - 8, 10, 60, curtain=WINE)
    # lareira central com espelho e retrato
    fx0, fx1 = 12 * T, 18 * T
    frame_picture(d, fx0 + 22, 6, fx1 - 22, 38, (60, 48, 70))
    d.ellipse((fx0 + 38, 12, fx1 - 38, 32), fill=(160, 120, 90), outline=OUTLINE)  # rosto do retrato
    rect(d, fx0, 44, fx1, 80, STONE, OUTLINE)
    rect(d, fx0 - 4, 42, fx1 + 4, 47, shade(STONE, 25), OUTLINE)
    rect(d, fx0 + 16, 54, fx1 - 16, 80, (30, 16, 12), OUTLINE)
    for i, c in enumerate(((255, 190, 90), (240, 130, 50), (255, 220, 140))):
        d.polygon([(fx0 + 30 + i * 10, 78), (fx0 + 35 + i * 10, 62 + i * 2), (fx0 + 40 + i * 10, 78)], fill=c)
    rect(d, fx0 + 26, 76, fx1 - 26, 80, (70, 40, 26))
    # relógio e vasos sobre a lareira
    rect(d, fx0 + 44, 36, fx0 + 52, 44, GOLD_D, OUTLINE)
    plant(d, fx0 + 10, 40)
    plant(d, fx1 - 10, 40)
    # cômoda de correspondências (missão das cartas)
    table(d, 9 * T, 5 * T + 2, 11 * T + 8, 6 * T + 10, top=WOOD_L)
    papers(d, 9 * T + 6, 5 * T + 4, 4)
    rect(d, 10 * T + 10, 5 * T + 3, 11 * T + 4, 5 * T + 9, WINE_D, OUTLINE)  # caixa de cartas
    # tapete e poltronas diante da lareira
    rug(d, 11 * T, 7 * T, 19 * T, 12 * T, GREEN, GOLD_D)
    for x in (12 * T + 4, 17 * T - 4):
        rect(d, x, 8 * T, x + 18, 8 * T + 16, WINE, OUTLINE)
        rect(d, x + 2, 8 * T - 4, x + 16, 8 * T + 2, WINE_D, OUTLINE)
    table(d, 14 * T + 8, 9 * T + 4, 16 * T + 8, 10 * T + 4)
    rect(d, 15 * T, 9 * T + 6, 15 * T + 10, 9 * T + 12, PAPER, PAPER_D)  # livro aberto
    # escrivaninha de Kardec (direita) com papéis, tinteiro e pena
    table(d, 21 * T, 7 * T, 27 * T, 9 * T, top=WOOD_M)
    papers(d, 22 * T, 7 * T + 4, 5)
    rect(d, 24 * T + 4, 7 * T + 6, 24 * T + 10, 7 * T + 12, IRON, OUTLINE)  # tinteiro
    d.line((24 * T + 9, 7 * T + 8, 25 * T + 2, 7 * T - 2), fill=PAPER)  # pena
    candle(d, 26 * T, 7 * T + 4)
    for i, c in enumerate((NAVY, WINE, GREEN)):
        rect(d, 25 * T + 4, 8 * T + 6 - i * 3, 26 * T + 12, 8 * T + 9 - i * 3, c, OUTLINE)
    chair(d, 23 * T + 4, 6 * T - 2, WINE_D, "down")
    # globo e plantas
    d.ellipse((2 * T, 13 * T, 3 * T + 8, 14 * T + 8), fill=(70, 110, 140), outline=OUTLINE)
    d.arc((2 * T - 2, 13 * T - 2, 3 * T + 10, 14 * T + 10), 200, 340, fill=GOLD_D)
    rect(d, 2 * T + 9, 14 * T + 8, 2 * T + 15, 15 * T + 4, WOOD_D, OUTLINE)
    plant(d, 28 * T + 8, 14 * T + 10)
    plant(d, 1 * T + 8, 5 * T + 10)
    side_walls(d)
    img = lighting(img, [(15 * T, 4 * T + 6, 60), (26 * T + 2, 7 * T, 36), (25 * T, 2 * T, 44)])
    furniture = [(9, 5, 11, 6), (21, 7, 26, 8), (23, 6, 23, 6), (12, 8, 13, 8), (16, 8, 17, 8),
                 (14, 9, 16, 9), (2, 13, 3, 14), (28, 14, 28, 14), (1, 5, 1, 5)]
    save("residencia_kardec", img, furniture, [(11, 7, 18, 11)])


# --- Sociedade: salão de reuniões ----------------------------------------------

def sociedade_salao():
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    floor_planks(d, 5 * T, 16 * T, (108, 66, 40))
    wallpaper(d, 5 * T, WINE_D, (128, 52, 68), pattern="stripe")
    window(d, 3 * T + 8, 7 * T - 8, 10, 60)
    window(d, 23 * T + 8, 27 * T - 8, 10, 60)
    # estandarte com a pomba e quadro-negro
    rect(d, 13 * T + 4, 4, 17 * T - 4, 52, PURPLE, OUTLINE)
    d.polygon([(13 * T + 4, 52), (15 * T, 62), (17 * T - 4, 52)], fill=PURPLE, outline=OUTLINE)
    d.polygon([(15 * T - 8, 30), (15 * T, 20), (15 * T + 8, 30), (15 * T, 36)], fill=PAPER)
    d.line((15 * T - 10, 26, 15 * T + 10, 26), fill=PAPER)
    rect(d, 8 * T, 12, 12 * T, 58, (34, 48, 40), WOOD_D)  # quadro
    for i in range(4):
        d.line((8 * T + 6, 22 + i * 9, 8 * T + 30 + (i * 7) % 20, 22 + i * 9), fill=(200, 210, 200))
    frame_picture(d, 19 * T, 14, 22 * T, 50, (70, 60, 46))
    # mesa de estudos (centro) com cadeiras
    table(d, 9 * T, 7 * T, 21 * T, 9 * T, top=WOOD_M)
    rect(d, 9 * T + 4, 7 * T + 3, 21 * T - 4, 9 * T - 3, GREEN_D)  # feltro
    for x in range(10, 20, 2):
        papers(d, x * T + 2, 7 * T + 5, 2)
    candle(d, 12 * T, 7 * T + 8)
    candle(d, 18 * T, 7 * T + 8)
    rect(d, 15 * T - 6, 7 * T + 6, 15 * T + 6, 7 * T + 14, WINE_D, OUTLINE)  # livro de atas
    for x in range(10, 21, 2):
        chair(d, x * T, 6 * T, WINE_D, "down")
        chair(d, x * T, 9 * T + 2, WINE_D, "up")
    # púlpito
    rect(d, 14 * T + 4, 5 * T + 2, 16 * T - 4, 6 * T + 6, WOOD_L, OUTLINE)
    rect(d, 14 * T + 2, 5 * T, 16 * T - 2, 5 * T + 4, WOOD_H, OUTLINE)
    # fileiras de cadeiras do público
    for row in (11, 13):
        for x in list(range(3, 12, 2)) + list(range(18, 27, 2)):
            chair(d, x * T, row * T, PURPLE, "up")
    # estantes laterais e plantas
    bookshelf(d, 1 * T + 2, 3 * T - 2, 5 * T + 4, 9 * T)
    bookshelf(d, 27 * T + 2, 29 * T - 2, 5 * T + 4, 9 * T)
    plant(d, 1 * T + 8, 14 * T + 10)
    plant(d, 28 * T + 8, 14 * T + 10)
    side_walls(d)
    img = lighting(img, [(12 * T + 2, 7 * T + 6, 44), (18 * T + 2, 7 * T + 6, 44), (15 * T, 3 * T, 60)])
    furniture = [(9, 7, 20, 8), (14, 5, 15, 5), (1, 5, 2, 8), (27, 5, 28, 8),
                 (1, 14, 1, 14), (28, 14, 28, 14)]
    chairs = [(x, r, x, r) for r in (11, 13) for x in list(range(3, 12, 2)) + list(range(18, 27, 2))]
    save("sociedade_salao", img, furniture + chairs, [(10, 6, 20, 6), (10, 9, 20, 9)])


# --- Tipografia ----------------------------------------------------------------

def tipografia():
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    floor_planks(d, 5 * T, 16 * T, (124, 86, 56))
    # parede de tijolos/reboco
    rect(d, 0, 0, W, 5 * T, (120, 74, 58))
    for y in range(0, 5 * T - 6, 6):
        off = 0 if (y // 6) % 2 else 6
        for x in range(-off, W, 12):
            rect(d, x, y, x + 12, y + 6, rng.choice(((128, 78, 60), (116, 70, 54), (136, 86, 66))), (84, 50, 40))
    rect(d, 0, 5 * T - 6, W, 5 * T, WOOD_M)
    d.line((0, 5 * T - 6, W, 5 * T - 6), fill=WOOD_H)
    # caixas de tipos (gavetas com compartimentos)
    for x0 in (2 * T, 6 * T):
        rect(d, x0, 10, x0 + 3 * T + 8, 70, WOOD_D, OUTLINE)
        for yy in range(14, 66, 8):
            for xx in range(x0 + 3, x0 + 3 * T + 4, 6):
                rect(d, xx, yy, xx + 5, yy + 7, (60, 40, 30), (40, 26, 20))
                d.point((xx + 2, yy + 4), fill=IRON_L)
    # cartazes e varal de folhas secando
    frame_picture(d, 12 * T, 10, 14 * T + 8, 46, PAPER)
    for i in range(4):
        d.line((12 * T + 6, 18 + i * 6, 14 * T, 18 + i * 6), fill=(90, 60, 50))
    d.line((16 * T, 14, 28 * T, 14), fill=(60, 40, 30))
    for x in range(16 * T + 4, 28 * T - 8, 22):
        rect(d, x, 15, x + 14, 36, PAPER, PAPER_D)
        for i in range(3):
            d.line((x + 2, 20 + i * 5, x + 11, 20 + i * 5), fill=(120, 110, 100))
    # prensa manual de ferro (esquerda-centro)
    px0, py0 = 6 * T, 7 * T
    rect(d, px0, py0 + 10, px0 + 5 * T, py0 + 3 * T + 8, (30, 18, 14))
    rect(d, px0 + 6, py0 - 18, px0 + 14, py0 + 3 * T, IRON, OUTLINE)  # coluna
    rect(d, px0 + 5 * T - 14, py0 - 18, px0 + 5 * T - 6, py0 + 3 * T, IRON, OUTLINE)
    rect(d, px0 + 4, py0 - 22, px0 + 5 * T - 4, py0 - 12, IRON_L, OUTLINE)  # cabeçote
    rect(d, px0 + 2 * T, py0 - 12, px0 + 3 * T, py0 + 8, IRON_L, OUTLINE)  # parafuso
    d.line((px0 + 3 * T, py0 - 4, px0 + 5 * T + 10, py0 - 10), fill=IRON, width=2)  # alavanca
    d.ellipse((px0 + 5 * T + 8, py0 - 14, px0 + 5 * T + 14, py0 - 8), fill=WOOD_L, outline=OUTLINE)
    rect(d, px0 + 10, py0 + 8, px0 + 5 * T - 10, py0 + 18, IRON_L, OUTLINE)  # platina
    rect(d, px0 + 2, py0 + 2 * T, px0 + 5 * T - 2, py0 + 2 * T + 14, WOOD_M, OUTLINE)  # carro
    rect(d, px0 + 12, py0 + 2 * T + 2, px0 + 5 * T - 12, py0 + 2 * T + 12, PAPER, PAPER_D)
    # mesa de composição, rolos de tinta e pilhas de papel
    table(d, 15 * T, 7 * T, 20 * T, 8 * T + 8, top=WOOD_L)
    for i in range(3):
        rect(d, 15 * T + 6 + i * 20, 7 * T + 4, 15 * T + 18 + i * 20, 7 * T + 8, IRON, OUTLINE)  # componedores
    d.ellipse((19 * T, 7 * T + 2, 19 * T + 14, 7 * T + 8), fill=(20, 20, 26), outline=OUTLINE)  # tinta
    rect(d, 18 * T, 7 * T + 10, 19 * T + 6, 7 * T + 14, IRON_L, OUTLINE)  # rolo
    for x in (23 * T, 25 * T + 4):
        for i in range(6):
            rect(d, x, 8 * T + 6 - i * 3, x + 2 * T - 4, 8 * T + 9 - i * 3, PAPER if i % 2 else PAPER_D, OUTLINE)
    table(d, 22 * T, 11 * T, 27 * T, 12 * T + 8, top=WOOD_M)  # mesa de dobra
    papers(d, 23 * T, 11 * T + 4, 5)
    # barris de tinta e caixotes
    for x, y in ((2 * T, 12 * T), (3 * T + 6, 12 * T + 4)):
        d.ellipse((x, y, x + 20, y + 24), fill=WOOD_M, outline=OUTLINE)
        d.line((x + 2, y + 8, x + 18, y + 8), fill=IRON)
        d.line((x + 2, y + 16, x + 18, y + 16), fill=IRON)
    rect(d, 12 * T, 12 * T, 14 * T, 13 * T + 8, WOOD_L, OUTLINE)
    d.line((12 * T, 12 * T, 14 * T - 1, 13 * T + 7), fill=WOOD_D)
    side_walls(d)
    img = lighting(img, [(17 * T, 3 * T, 60), (9 * T, 5 * T, 46), (24 * T, 10 * T, 40)],
                   warm=(64, 48, 26), vignette=0.4)
    furniture = [(6, 6, 11, 9), (15, 7, 19, 8), (23, 7, 26, 8), (22, 11, 26, 12),
                 (2, 12, 3, 13), (12, 12, 13, 13), (2, 0, 9, 4)]
    save("tipografia", img, furniture)


BUILDERS = {
    "residencia_kardec": residencia_kardec,
    "sociedade_salao": sociedade_salao,
    "tipografia": tipografia,
}

if __name__ == "__main__":
    for name in (sys.argv[1:] or list(BUILDERS)):
        BUILDERS[name]()

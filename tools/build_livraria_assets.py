"""Gera a arte do interior da Livraria (Paris, 1857) em pixel art.

Uso: python tools/build_livraria_assets.py

Gera:
  assets/tilesets/livraria/livraria_atlas.png   arte base (30x17 tiles de 32px)
  data/maps/livraria_layout.json                colisoes e camadas por celula

A arte e desenhada em meia resolucao (tiles de 16px) e ampliada 2x com
vizinho-mais-proximo, para casar com a densidade de pixels do mapa de Paris.
Paleta: vinho, marrom, dourado, verde-escuro e roxo (direcao visual do jogo).
"""
import json
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets/tilesets/livraria"
LAYOUT = ROOT / "data/maps/livraria_layout.json"
COLS, ROWS = 30, 17
T = 16  # tile em meia resolucao
W, H = COLS * T, ROWS * T

# Paleta
OUTLINE = (24, 14, 14)
WOOD_D = (52, 30, 22)
WOOD_M = (84, 50, 32)
WOOD_L = (120, 76, 46)
WOOD_H = (150, 100, 62)
FLOOR = [(112, 70, 42), (102, 63, 38), (122, 77, 46)]
FLOOR_SEAM = (62, 37, 24)
WALLPAPER = (78, 30, 44)
WALLPAPER_P = (104, 46, 60)
GOLD = (201, 160, 74)
GOLD_D = (150, 112, 50)
WINE = (110, 32, 48)
WINE_D = (80, 22, 36)
GREEN = (40, 76, 56)
NAVY = (36, 44, 78)
PURPLE = (82, 48, 104)
OCHRE = (168, 118, 52)
BOOKS = [WINE, GREEN, NAVY, PURPLE, OCHRE, (96, 58, 36), (60, 30, 40), (46, 62, 52)]
PAPER = (232, 220, 190)
GLASS = (34, 46, 84)
GLASS_L = (64, 86, 132)

rng = random.Random(1857)


def rect(d, x0, y0, x1, y1, fill, outline=None):
    d.rectangle((x0, y0, x1 - 1, y1 - 1), fill=fill, outline=outline)


def draw_floor(d):
    rect(d, 0, 0, W, H, FLOOR[0])
    for y in range(5 * T, 16 * T, 8):
        x = -rng.randrange(0, 40)
        while x < W:
            length = rng.choice((32, 40, 48, 56))
            c = rng.choice(FLOOR)
            rect(d, x, y, x + length, y + 8, c)
            d.line((x, y + 7, x + length - 1, y + 7), fill=FLOOR_SEAM)
            d.line((x, y, x, y + 7), fill=FLOOR_SEAM)
            d.line((x + 1, y, x + length - 2, y), fill=tuple(min(255, v + 14) for v in c))
            # veios da madeira
            for _ in range(2):
                gx = x + rng.randrange(3, max(4, length - 6))
                d.line((gx, y + 3, gx + 3, y + 3), fill=tuple(max(0, v - 14) for v in c))
            x += length


def draw_bookshelf(d, x0, x1, y0=4, y1=74):
    rect(d, x0, y0, x1, y1, WOOD_D, OUTLINE)
    rect(d, x0 + 3, y0 + 3, x1 - 3, y1 - 2, (30, 17, 13))
    shelf_ys = [y0 + 3, y0 + 20, y0 + 37, y0 + 54]
    for sy in shelf_ys:
        bx = x0 + 4
        while bx < x1 - 6:
            bw = rng.choice((2, 3, 3, 4))
            bh = rng.randrange(11, 16)
            c = rng.choice(BOOKS)
            top = sy + 16 - bh
            if rng.random() < 0.08:  # livro inclinado / vao
                bx += bw + 1
                continue
            rect(d, bx, top, bx + bw, sy + 16, c)
            d.line((bx, top, bx, sy + 15), fill=tuple(min(255, v + 30) for v in c))
            if bh > 12:
                d.point((bx + bw // 2, top + 3), fill=GOLD)
                d.point((bx + bw // 2, sy + 12), fill=GOLD_D)
            bx += bw
        rect(d, x0 + 2, sy + 16, x1 - 2, sy + 18, WOOD_L)
        d.line((x0 + 2, sy + 16, x1 - 3, sy + 16), fill=WOOD_H)
    # cornija dourada
    rect(d, x0, y0, x1, y0 + 2, WOOD_L)
    d.line((x0, y0, x1 - 1, y0), fill=GOLD_D)


def draw_back_wall(d):
    rect(d, 0, 0, W, 5 * T, WALLPAPER)
    for y in range(4, 5 * T, 8):
        for x in range((y // 8 % 2) * 4, W, 8):
            d.point((x, y), fill=WALLPAPER_P)
    # rodape / lambri
    rect(d, 0, 5 * T - 6, W, 5 * T, WOOD_M)
    d.line((0, 5 * T - 6, W, 5 * T - 6), fill=WOOD_H)
    d.line((0, 5 * T - 1, W, 5 * T - 1), fill=OUTLINE)
    draw_bookshelf(d, 1 * T, 13 * T)
    draw_bookshelf(d, 17 * T, 29 * T)
    # janela entre as estantes
    wx0, wx1, wy0, wy1 = 13 * T + 8, 17 * T - 8, 10, 60
    rect(d, wx0 - 3, wy0 - 3, wx1 + 3, wy1 + 3, WOOD_D, OUTLINE)
    rect(d, wx0, wy0, wx1, wy1, GLASS)
    for i in range(0, wy1 - wy0, 3):
        d.line((wx0, wy0 + i, wx1 - 1, wy0 + i), fill=GLASS if i % 6 else (40, 54, 94))
    d.point((wx0 + 9, wy0 + 8), fill=PAPER)  # estrelas / lua
    d.point((wx0 + 30, wy0 + 15), fill=PAPER)
    rect(d, wx0 + 36, wy0 + 5, wx0 + 42, wy0 + 11, (236, 224, 170))
    d.line((wx0 + 3, wy1 - 6, wx0 + 14, wy1 - 18), fill=GLASS_L)
    mx = (wx0 + wx1) // 2
    rect(d, mx - 1, wy0, mx + 1, wy1, WOOD_D)
    rect(d, wx0, (wy0 + wy1) // 2 - 1, wx1, (wy0 + wy1) // 2 + 1, WOOD_D)
    # cortinas roxas
    for cx, direction in ((wx0 - 6, 1), (wx1 - 4, -1)):
        rect(d, cx, wy0 - 6, cx + 10, wy1 + 10, PURPLE, OUTLINE)
        for k in range(2, 10, 3):
            d.line((cx + k, wy0 - 5, cx + k, wy1 + 8), fill=(104, 66, 130))
    rect(d, wx0 - 8, wy0 - 9, wx1 + 8, wy0 - 5, GOLD_D, OUTLINE)
    # parapeito com vaso de flores
    rect(d, wx0 - 4, wy1 + 3, wx1 + 4, wy1 + 7, WOOD_L, OUTLINE)
    rect(d, mx - 5, wy1 - 2, mx + 5, wy1 + 3, (140, 70, 40), OUTLINE)
    for fx, fc in ((-3, (210, 120, 160)), (0, (240, 220, 120)), (3, (200, 90, 120))):
        d.point((mx + fx, wy1 - 4), fill=fc)
        d.point((mx + fx, wy1 - 3), fill=GREEN)


def draw_side_walls(d):
    for x0 in (0, 29 * T):
        rect(d, x0, 0, x0 + T, H, WOOD_D)
        for y in range(0, H, 12):
            rect(d, x0 + 2, y + 1, x0 + T - 2, y + 11, WOOD_M, OUTLINE)
            d.line((x0 + 3, y + 2, x0 + T - 4, y + 2), fill=WOOD_L)
    # parede inferior com a porta
    rect(d, 0, 16 * T, W, H, WOOD_D)
    d.line((0, 16 * T, W, 16 * T), fill=WOOD_H)
    for x in range(0, W, 12):
        d.line((x, 16 * T + 2, x, H), fill=OUTLINE)
    # porta (vao de saida)
    rect(d, 14 * T, 16 * T, 16 * T, H, (70, 40, 28), OUTLINE)
    rect(d, 14 * T + 2, 16 * T + 2, 16 * T - 2, H, WOOD_L)
    d.point((16 * T - 6, 16 * T + 8), fill=GOLD)
    # capacho
    rect(d, 14 * T, 15 * T + 2, 16 * T, 16 * T, WINE_D, OUTLINE)
    for x in range(14 * T + 3, 16 * T - 2, 3):
        d.line((x, 15 * T + 4, x, 16 * T - 3), fill=WINE)


def draw_rug(d):
    x0, y0, x1, y1 = 11 * T, 8 * T, 19 * T, 14 * T
    rect(d, x0, y0, x1, y1, WINE_D, OUTLINE)
    rect(d, x0 + 3, y0 + 3, x1 - 3, y1 - 3, GOLD_D)
    rect(d, x0 + 5, y0 + 5, x1 - 5, y1 - 5, WINE)
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    for r in range(4, 30, 6):
        d.polygon([(cx, cy - r), (cx + r * 2, cy), (cx, cy + r), (cx - r * 2, cy)],
                  outline=GOLD_D if r % 12 else PURPLE)
    for x in range(x0 + 1, x1, 4):  # franjas
        d.line((x, y0 - 2, x, y0), fill=PAPER)
        d.line((x, y1 - 1, x, y1 + 1), fill=PAPER)


def draw_table(d):
    # mesa de leitura (cols 6-10, linhas 9-10) e cadeiras (linha 8)
    for cx in (7, 9):
        rect(d, cx * T + 3, 8 * T + 4, cx * T + 13, 9 * T + 2, WINE_D, OUTLINE)
        rect(d, cx * T + 3, 8 * T + 1, cx * T + 13, 8 * T + 5, WOOD_M, OUTLINE)
    x0, y0, x1, y1 = 6 * T + 2, 9 * T, 11 * T - 2, 11 * T - 3
    rect(d, x0, y0 + 3, x1, y1 + 3, (30, 18, 14))  # sombra
    rect(d, x0, y0, x1, y1, WOOD_M, OUTLINE)
    d.line((x0 + 1, y0 + 1, x1 - 2, y0 + 1), fill=WOOD_H)
    for x in (x0 + 2, x1 - 4):
        rect(d, x, y1, x + 2, y1 + 3, WOOD_D)
    # livro aberto
    bx, by = 7 * T + 4, 9 * T + 6
    rect(d, bx, by, bx + 18, by + 12, WINE_D, OUTLINE)
    rect(d, bx + 1, by + 1, bx + 9, by + 11, PAPER)
    rect(d, bx + 9, by + 1, bx + 17, by + 11, (220, 206, 172))
    for ly in range(by + 3, by + 10, 2):
        d.line((bx + 2, ly, bx + 7, ly), fill=(150, 130, 110))
        d.line((bx + 11, ly, bx + 16, ly), fill=(150, 130, 110))
    # pilha de livros e lampiao a oleo
    for i, c in enumerate((NAVY, GREEN, WINE)):
        rect(d, 9 * T + 2, 9 * T + 10 - i * 3, 9 * T + 14, 9 * T + 13 - i * 3, c, OUTLINE)
    rect(d, 10 * T - 2, 9 * T + 4, 10 * T + 4, 9 * T + 12, GOLD_D, OUTLINE)
    rect(d, 10 * T - 1, 9 * T + 1, 10 * T + 3, 9 * T + 6, (255, 220, 140))


def draw_counter(d):
    x0, y0, x1, y1 = 22 * T, 7 * T, 28 * T, 9 * T
    rect(d, x0, y0 + 4, x1, y1 + 2, (30, 18, 14))
    rect(d, x0, y0, x1, y1, WOOD_D, OUTLINE)
    rect(d, x0 + 1, y0 + 1, x1 - 1, y0 + 10, WOOD_L)
    d.line((x0 + 1, y0 + 1, x1 - 2, y0 + 1), fill=WOOD_H)
    for x in range(x0 + 6, x1 - 4, 16):  # paineis frontais
        rect(d, x, y0 + 14, x + 12, y1 - 3, WOOD_M, OUTLINE)
    # caixa registradora de latao
    rect(d, x1 - 22, y0 - 6, x1 - 6, y0 + 8, GOLD_D, OUTLINE)
    rect(d, x1 - 20, y0 - 4, x1 - 8, y0, (230, 200, 120))
    for k in range(3):
        d.point((x1 - 18 + k * 4, y0 + 4), fill=OUTLINE)
    # livros sobre o balcao, campainha e lampiao
    for i, c in enumerate((PURPLE, OCHRE, GREEN, WINE)):
        rect(d, x0 + 8 + i * 6, y0 + 2, x0 + 13 + i * 6, y0 + 9, c, OUTLINE)
    rect(d, x0 + 40, y0 + 3, x0 + 46, y0 + 8, GOLD, OUTLINE)
    rect(d, x0 + 58, y0 - 8, x0 + 64, y0 + 6, GOLD_D, OUTLINE)
    rect(d, x0 + 59, y0 - 7, x0 + 63, y0 - 1, (255, 220, 140))


def draw_plants(d):
    for cx, cy in ((1 * T + 8, 5 * T + 10), (28 * T + 8, 14 * T + 10)):
        rect(d, cx - 5, cy - 2, cx + 5, cy + 6, (140, 70, 40), OUTLINE)
        for dx, dy in ((-6, -6), (0, -10), (6, -6), (-3, -3), (3, -3), (0, -6)):
            d.ellipse((cx + dx - 4, cy + dy - 4, cx + dx + 4, cy + dy + 3), fill=GREEN,
                      outline=(24, 46, 32))
            d.point((cx + dx, cy + dy - 2), fill=(80, 130, 90))


def add_lighting(img):
    """Brilho quente dos lampioes + vinheta, para a iluminacao aconchegante."""
    glow = Image.new("RGB", img.size, (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    lamps = [(10 * T + 1, 9 * T + 3, 40), (22 * T + 61, 7 * T - 4, 40),
             (15 * T, 3 * T, 46), (1 * T, 10 * T, 30), (29 * T, 10 * T, 30)]
    for x, y, r in lamps:
        for k in range(r, 0, -2):
            v = int(70 * (1 - k / r))
            gd.ellipse((x - k, y - k * 0.8, x + k, y + k * 0.8),
                       fill=(v, int(v * 0.72), int(v * 0.35)))
    img = ImageChops.add(img, glow.filter(ImageFilter.GaussianBlur(6)))
    vignette = Image.new("L", img.size, 0)
    vd = ImageDraw.Draw(vignette)
    vd.ellipse((-60, -50, W + 60, H + 50), fill=255)
    vignette = vignette.filter(ImageFilter.GaussianBlur(40))
    dark = Image.new("RGB", img.size, (20, 10, 16))
    return Image.composite(img, Image.blend(img, dark, 0.45), vignette)


def cells(rects):
    out = set()
    for x0, y0, x1, y1 in rects:
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                if 0 <= x < COLS and 0 <= y < ROWS:
                    out.add((x, y))
    return out


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    LAYOUT.parent.mkdir(parents=True, exist_ok=True)
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    draw_floor(d)
    draw_rug(d)
    draw_back_wall(d)
    draw_side_walls(d)
    draw_table(d)
    draw_counter(d)
    draw_plants(d)
    img = add_lighting(img)
    img = img.resize((W * 2, H * 2), Image.NEAREST)
    img.save(OUT_DIR / "livraria_atlas.png")

    walls = [(0, 0, 29, 4), (0, 0, 0, 16), (29, 0, 29, 16), (0, 16, 29, 16)]
    furniture = [(6, 9, 10, 10), (7, 8, 7, 8), (9, 8, 9, 8), (22, 7, 27, 8),
                 (1, 5, 1, 5), (28, 14, 28, 14)]
    env = cells(walls)
    deco = cells(furniture + [(11, 8, 18, 13), (14, 15, 15, 15)]) - env
    layout = {
        "tile_size": 32, "cols": COLS, "rows": ROWS,
        "solid": sorted(map(list, cells(walls + furniture))),
        "environment": sorted(map(list, env)),
        "decoration": sorted(map(list, deco)),
        "foreground": [],
    }
    LAYOUT.write_text(json.dumps(layout, separators=(",", ":")), encoding="utf8")
    print("ok:", OUT_DIR, LAYOUT)


if __name__ == "__main__":
    main()

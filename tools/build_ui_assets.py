"""Gera arte de interface da expansão.

Uso: python tools/build_ui_assets.py
Saída: assets/ui/mapa_paris.png  (mapa de localidades em pergaminho, 640x400)

Desenhado em meia resolução e ampliado 2x (mesma densidade de pixels do jogo).
Os pinos e nomes dos destinos são desenhados pela interface (data/travel.json).
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
W, H = 320, 200
PARCH = (222, 198, 150)
PARCH_D = (196, 168, 118)
INK = (92, 58, 40)
WINE = (110, 32, 48)
GOLD = (201, 160, 74)
RIVER = (104, 138, 160)
RIVER_D = (74, 104, 128)
GREEN = (120, 140, 90)

rng = random.Random(7)


def main():
    img = Image.new("RGB", (W, H), PARCH)
    d = ImageDraw.Draw(img)
    # textura do pergaminho
    for _ in range(1400):
        x, y = rng.randrange(W), rng.randrange(H)
        d.point((x, y), fill=PARCH_D if rng.random() < 0.6 else (230, 210, 165))
    # quarteirões
    for _ in range(170):
        x, y = rng.randrange(14, W - 24), rng.randrange(14, H - 20)
        w, h = rng.randrange(6, 14), rng.randrange(4, 9)
        d.rectangle((x, y, x + w, y + h), fill=(206, 180, 134), outline=(176, 146, 100))
    # avenidas
    for (a, b) in (((20, 40), (300, 70)), ((40, 170), (290, 120)), ((160, 14), (150, 190)),
                   ((60, 20), (250, 180))):
        d.line((a, b), fill=(232, 214, 172), width=3)
    # o Sena: curva de oeste a leste
    pts = [(x, 112 + 18 * math.sin(x / 48) - (x - 160) * 0.12) for x in range(0, W + 1, 4)]
    d.line(pts, fill=RIVER_D, width=11)
    d.line(pts, fill=RIVER, width=7)
    # Île de la Cité
    d.ellipse((150, 104, 182, 116), fill=(206, 180, 134), outline=INK)
    # parques
    for (x, y, w, h) in ((30, 140, 26, 16), (238, 34, 22, 14), (96, 30, 18, 12)):
        d.ellipse((x, y, x + w, y + h), fill=GREEN, outline=(90, 110, 70))
    # rosa dos ventos
    cx, cy = 290, 172
    d.polygon([(cx, cy - 12), (cx + 3, cy), (cx, cy + 12), (cx - 3, cy)], fill=WINE)
    d.polygon([(cx - 12, cy), (cx, cy - 3), (cx + 12, cy), (cx, cy + 3)], fill=INK)
    d.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill=GOLD)
    # moldura vinho/dourada
    d.rectangle((0, 0, W - 1, H - 1), outline=WINE)
    d.rectangle((2, 2, W - 3, H - 3), outline=GOLD)
    d.rectangle((4, 4, W - 5, H - 5), outline=WINE)
    out = ROOT / "assets/ui"
    out.mkdir(parents=True, exist_ok=True)
    img.resize((W * 2, H * 2), Image.NEAREST).save(out / "mapa_paris.png")
    print("ok:", out / "mapa_paris.png")


if __name__ == "__main__":
    main()

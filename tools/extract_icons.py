"""Recorta os ícones de itens do "Pacote Visual do RPG Espírita 2D" (referência).

Uso: python tools/extract_icons.py
Entrada: assets/references/pacote_visual.png
Saída:   assets/ui/icons/<nome>.png (48x48, fundo transparente)

Os nomes seguem o desenho (na prancha original os rótulos "Relíquia" e
"Flores" estão trocados: o buquê é "flores" e o cristal é "cristal").
"""
from pathlib import Path

from PIL import Image

from extract_archetypes import fuzzy_background

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/references/pacote_visual.png"
OUT = ROOT / "assets/ui/icons"
SIZE = 48
# nome -> centro x na prancha original (fileira "Itens e Colecionáveis", y 944-984, sem os rótulos)
ICONS = {
    "livro": 57, "cartas": 112, "documento": 170, "jornal": 230, "tinta": 282,
    "pena": 325, "chave": 372, "flores": 425, "cristal": 480, "fotografia": 528,
    "bilhete": 582,
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(SRC).convert("RGBA")
    for name, cx in ICONS.items():
        crop = sheet.crop((cx - 26, 944, cx + 26, 984))
        icon = fuzzy_background(crop, tol=9)
        bbox = icon.getbbox()
        icon = icon.crop(bbox)
        scale = min(SIZE / icon.width, SIZE / icon.height)
        icon = icon.resize((max(1, round(icon.width * scale)), max(1, round(icon.height * scale))),
                           Image.LANCZOS)
        icon.putalpha(icon.getchannel("A").point(lambda v: 255 if v > 100 else 0))
        canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        canvas.paste(icon, ((SIZE - icon.width) // 2, (SIZE - icon.height) // 2), icon)
        canvas.save(OUT / f"{name}.png")
        print("ok", name)


if __name__ == "__main__":
    main()

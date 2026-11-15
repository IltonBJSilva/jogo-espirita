"""Extrai animacoes de folhas de sprites com fundo magenta (#FF00FF).

Uso: python tools/extract_sheet.py [personagem]
Folhas: assets/references/generated/<personagem>_animacoes.png
        (geradas com o Codex a partir da referencia do personagem; veja SHEETS)
Saida:  assets/characters/<personagem>/<personagem>_<animacao>.png

Cada fileira da folha e uma animacao. Os frames sao normalizados para a
celula do jogo (72x92, mesma escala do Kardec) com UMA escala comum para a
folha inteira, preservando a altura relativa dos quadros (ex.: o quadro da
corrida com os dois pes no ar continua "no ar").
"""
import sys
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
CELL = (72, 92)
TARGET_HEIGHT = 84  # altura do personagem parado, igual ao Kardec

# Fileiras de cada folha, de cima para baixo: (animacao, frames esperados).
# "align": "head" centraliza pela cabeca (perfil), "box" pelo retangulo.
SHEETS = {
    "estudante": {
        "rows": [
            ("walk_down", 4, "box"),
            ("walk_up", 4, "box"),
            ("walk_side", 6, "head"),
            ("run_side", 6, "head"),
            ("idle_down", 4, "box"),
        ],
        # quadros extras derivados das fileiras: animacao -> (fileira, indice)
        "stills": {"idle_side": ("walk_side", 0), "idle_up": ("walk_up", 0)},
        "scale_ref": "idle_down",
    },
}

# Personagens da expansão (gerados com o mesmo modelo, fileira 4 = "falar").
_NPC_ROWS = [
    ("walk_down", 4, "box"),
    ("walk_up", 4, "box"),
    ("walk_side", 6, "head"),
    ("talk", 4, "box"),
    ("idle_down", 4, "box"),
]
for _cid in ("amelie", "medium", "medico", "impressor", "cocheiro", "crianca", "espirito_guia"):
    SHEETS[_cid] = {
        "rows": _NPC_ROWS,
        "stills": {"idle_side": ("walk_side", 0), "idle_up": ("walk_up", 0)},
        "scale_ref": "idle_down",
        # criança é menor que os adultos (84 px)
        "target_height": 64 if _cid == "crianca" else TARGET_HEIGHT,
    }


def is_key(p):
    r, g, b = p[:3]
    return r > 150 and b > 150 and g < 110 and abs(r - b) < 70


def key_out(img):
    img = img.convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            if is_key(px[x, y]):
                px[x, y] = (0, 0, 0, 0)
    # remove o "halo" magenta das bordas (pixels misturados com o fundo)
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a and r > 120 and b > 120 and g < r * 0.6 and g < b * 0.6:
                px[x, y] = (0, 0, 0, 0)
    return img


def blobs(img, min_area=600):
    a = img.getchannel("A").load()
    w, h = img.size
    seen = bytearray(w * h)
    out = []
    for y0 in range(h):
        for x0 in range(w):
            if not a[x0, y0] or seen[y0 * w + x0]:
                continue
            q = deque([(x0, y0)])
            seen[y0 * w + x0] = 1
            xs, ys = [], []
            while q:
                x, y = q.popleft()
                xs.append(x)
                ys.append(y)
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and a[nx, ny] and not seen[ny * w + nx]:
                        seen[ny * w + nx] = 1
                        q.append((nx, ny))
            if len(xs) >= min_area:
                out.append((min(xs), min(ys), max(xs) + 1, max(ys) + 1))
    return out


def group_rows(boxes):
    """Agrupa caixas em fileiras pela sobreposicao vertical."""
    rows = []
    for box in sorted(boxes, key=lambda b: (b[1] + b[3]) / 2):
        cy = (box[1] + box[3]) / 2
        for row in rows:
            if row["y0"] <= cy <= row["y1"]:
                row["boxes"].append(box)
                row["y0"] = min(row["y0"], box[1])
                row["y1"] = max(row["y1"], box[3])
                break
        else:
            rows.append({"y0": box[1], "y1": box[3], "boxes": [box]})
    rows.sort(key=lambda r: r["y0"])
    for row in rows:
        row["boxes"].sort(key=lambda b: b[0])
    return rows


def head_center_x(sprite):
    """Centro horizontal da cabeca (primeiras linhas opacas)."""
    a = sprite.getchannel("A").load()
    xs = [x for y in range(min(sprite.height, 30)) for x in range(sprite.width) if a[x, y]]
    return sum(xs) / len(xs) if xs else sprite.width / 2


def place(sheet, box, baseline, scale, align):
    sprite = sheet.crop(box)
    w = max(1, round(sprite.width * scale))
    h = max(1, round(sprite.height * scale))
    sprite = sprite.resize((w, h), Image.LANCZOS)
    sprite.putalpha(sprite.getchannel("A").point(lambda v: 255 if v > 110 else 0))
    lift = round((baseline - box[3]) * scale)  # quanto o quadro esta acima do chao
    cx = head_center_x(sprite) if align == "head" else w / 2
    canvas = Image.new("RGBA", CELL, (0, 0, 0, 0))
    canvas.paste(sprite, (round(CELL[0] / 2 - cx), CELL[1] - h - lift), sprite)
    return canvas


def save_strip(path, frames):
    strip = Image.new("RGBA", (CELL[0] * len(frames), CELL[1]), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * CELL[0], 0), f)
    strip.save(path)


def extract(character):
    cfg = SHEETS[character]
    src = ROOT / f"assets/references/generated/{character}_animacoes.png"
    sheet = key_out(Image.open(src))
    rows = group_rows(blobs(sheet))
    names = [r[0] for r in cfg["rows"]]
    assert len(rows) == len(cfg["rows"]), f"{len(rows)} fileiras encontradas, esperadas {len(names)}"
    for row, (name, count, _align) in zip(rows, cfg["rows"]):
        assert len(row["boxes"]) == count, f"{name}: {len(row['boxes'])} frames, esperados {count}"
    ref_row = rows[names.index(cfg["scale_ref"])]
    scale = cfg.get("target_height", TARGET_HEIGHT) / max(b[3] - b[1] for b in ref_row["boxes"])
    out_dir = ROOT / f"assets/characters/{character}"
    out_dir.mkdir(parents=True, exist_ok=True)
    frames_by_anim = {}
    for row, (name, _count, align) in zip(rows, cfg["rows"]):
        baseline = max(b[3] for b in row["boxes"])
        frames = [place(sheet, b, baseline, scale, align) for b in row["boxes"]]
        frames_by_anim[name] = frames
        save_strip(out_dir / f"{character}_{name}.png", frames)
    for name, (anim, index) in cfg.get("stills", {}).items():
        save_strip(out_dir / f"{character}_{name}.png", [frames_by_anim[anim][index]])
    print("ok", character, {k: len(v) for k, v in frames_by_anim.items()})


if __name__ == "__main__":
    for c in (sys.argv[1:] or list(SHEETS)):
        extract(c)

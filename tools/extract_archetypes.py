"""Extrai os personagens do painel "Arquetipos Parisienses".

Uso: python tools/extract_archetypes.py
Entrada: assets/references/arquetipos_parisienses.png (4 colunas: Estudante,
         Livreiro, Estudioso, Moradora; cada uma com vistas, andar, falar)
Saida:   assets/characters/<id>/<id>_<anim>.png  (mesmos nomes dos sprites de Kardec)
         assets/characters/<id>/<id>_portrait.png

Os frames sao normalizados para a mesma escala/celula dos sprites de Kardec
(72x92, pes alinhados na base), para que todos os personagens convivam no mapa.
"""
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/references/arquetipos_parisienses.png"
OUT = ROOT / "assets/characters"
CELL = (72, 92)
TARGET_HEIGHT = 84  # mesma altura do Kardec no jogo

COLUMNS = ["estudante", "livreiro", "estudioso", "moradora"]
COL_X = [(10, 380), (395, 765), (780, 1150), (1165, 1530)]
ROWS = {"views": (300, 455), "walk": (492, 617)}
PORTRAIT_Y = (40, 236)
# A arte desenha o "andar" com 4 frames: perfil, perfil, costas, perfil.
WALK_SIDE_FRAMES = [0, 1, 3]


def fuzzy_background(img, tol=6):
    """Remove o fundo por "varinha magica" a partir das bordas: o fundo do
    painel e um degrade suave, entao cada pixel so e incorporado se for
    parecido com o vizinho de onde a busca veio. O contorno escuro e as
    bordas nitidas dos personagens interrompem o preenchimento."""
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.append((x, 0, px[x, 0]))
        q.append((x, h - 1, px[x, h - 1]))
    for y in range(h):
        q.append((0, y, px[0, y]))
        q.append((w - 1, y, px[w - 1, y]))
    while q:
        x, y, prev = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y * w + x]:
            continue
        p = px[x, y]
        if max(abs(p[0] - prev[0]), abs(p[1] - prev[1]), abs(p[2] - prev[2])) > tol:
            continue
        if max(p[:3]) < 30:  # contorno
            continue
        seen[y * w + x] = 1
        q.extend(((x + 1, y, p), (x - 1, y, p), (x, y + 1, p), (x, y - 1, p)))
    for y in range(h):
        for x in range(w):
            if seen[y * w + x]:
                px[x, y] = (0, 0, 0, 0)
    return img


def blobs(img, min_area=800):
    a = img.getchannel("A").load()
    w, h = img.size
    seen = set()
    out = []
    for x in range(w):
        for y in range(h):
            if a[x, y] == 0 or (x, y) in seen:
                continue
            q = deque([(x, y)])
            seen.add((x, y))
            pts = []
            while q:
                cx, cy = q.popleft()
                pts.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and a[nx, ny] and (nx, ny) not in seen:
                        seen.add((nx, ny))
                        q.append((nx, ny))
            if len(pts) >= min_area:
                out.append(pts)
    out.sort(key=lambda pts: min(p[0] for p in pts))
    return out


def blob_image(img, pts):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    x0, y0 = min(xs), min(ys)
    sprite = Image.new("RGBA", (max(xs) - x0 + 1, max(ys) - y0 + 1), (0, 0, 0, 0))
    src = img.load()
    dst = sprite.load()
    for x, y in pts:
        dst[x - x0, y - y0] = src[x, y]
    return strip_shadow(sprite)


def strip_shadow(img):
    """Remove a sombra no chao (pixels escuros e pouco saturados nas ultimas linhas)."""
    w, h = img.size
    px = img.load()
    for y in range(max(0, h - 8), h):
        for x in range(w):
            r, g, b, al = px[x, y]
            # sombra: escura e arroxeada (azul >= vermelho). Sapatos sao marrons
            # (vermelho > azul) e por isso sao preservados.
            if al and max(r, g, b) < 75 and max(r, g, b) - min(r, g, b) < 28 and b >= r - 4:
                px[x, y] = (0, 0, 0, 0)
    return img.crop(img.getbbox())


def extract_row(sheet, x_range, y_range):
    crop = fuzzy_background(sheet.crop((x_range[0], y_range[0], x_range[1], y_range[1])))
    return [blob_image(crop, pts) for pts in blobs(crop)]


def normalize(frames, ref_height):
    scale = TARGET_HEIGHT / ref_height
    out = []
    for f in frames:
        f = f.resize((max(1, round(f.width * scale)), max(1, round(f.height * scale))),
                     Image.LANCZOS)
        f.putalpha(f.getchannel("A").point(lambda v: 255 if v > 110 else 0))
        canvas = Image.new("RGBA", CELL, (0, 0, 0, 0))
        canvas.paste(f, ((CELL[0] - f.width) // 2, CELL[1] - f.height), f)
        out.append(canvas)
    return out


def mask_diff(a, b):
    """Diferenca entre as silhuetas (alpha) de dois frames do mesmo tamanho."""
    pa, pb = a.getchannel("A").load(), b.getchannel("A").load()
    return sum((pa[x, y] > 0) != (pb[x, y] > 0) for x in range(a.width) for y in range(a.height))


def match_facing(side, walk_frames):
    """A vista de perfil da referencia pode olhar para o lado oposto ao da
    caminhada; o jogo espera tudo olhando para a DIREITA (espelha no codigo).
    Escolhe a orientacao cuja silhueta mais se parece com a caminhada."""
    mirrored = side.transpose(Image.FLIP_LEFT_RIGHT)
    d_keep = sum(mask_diff(side, w) for w in walk_frames)
    d_flip = sum(mask_diff(mirrored, w) for w in walk_frames)
    return mirrored if d_flip < d_keep else side


def save_strip(path, frames):
    strip = Image.new("RGBA", (CELL[0] * len(frames), CELL[1]), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * CELL[0], 0), f)
    strip.save(path)


def bob(frame):
    """Ciclo frontal/costas simples (a referencia nao traz esses ciclos)."""
    up = Image.new("RGBA", CELL, (0, 0, 0, 0))
    up.paste(frame, (0, -2), frame)
    # mantem os pes no chao
    feet = frame.crop((0, CELL[1] - 10, CELL[0], CELL[1]))
    up.paste(feet, (0, CELL[1] - 10), feet)
    return [frame, up, frame, up]


def main():
    sheet = Image.open(SRC).convert("RGBA")
    for cid, xr in zip(COLUMNS, COL_X):
        views = extract_row(sheet, xr, ROWS["views"])
        walk = extract_row(sheet, xr, ROWS["walk"])
        assert len(views) == 4 and len(walk) == 4, (cid, len(views), len(walk))
        # Cada fileira da referencia foi desenhada numa escala diferente; a
        # maior figura de cada fileira e normalizada para TARGET_HEIGHT.
        front, three_q, back, side = normalize(views, max(f.height for f in views))
        walk_n = normalize(walk, max(f.height for f in walk))
        side = match_facing(side, [walk_n[i] for i in WALK_SIDE_FRAMES])
        # A fileira "Falar" da referencia corta as pernas dos personagens, entao
        # ela nao vira animacao de corpo inteiro (os NPCs usam o idle ao falar).
        d = OUT / cid
        d.mkdir(parents=True, exist_ok=True)
        x0, x1 = xr
        sheet.crop((x0 + 18, PORTRAIT_Y[0], x1 - 18, PORTRAIT_Y[1])).save(d / f"{cid}_portrait.png")
        if (ROOT / f"assets/references/generated/{cid}_animacoes.png").exists():
            # animacoes completas vem da folha gerada (tools/extract_sheet.py)
            print("ok", cid, "(apenas retrato; animacoes via extract_sheet.py)")
            continue
        save_strip(d / f"{cid}_idle_down.png", [front])
        save_strip(d / f"{cid}_idle_side.png", [side])
        save_strip(d / f"{cid}_idle_up.png", [back])
        save_strip(d / f"{cid}_walk_side.png", [walk_n[i] for i in WALK_SIDE_FRAMES] + [side])
        save_strip(d / f"{cid}_walk_down.png", bob(front))
        save_strip(d / f"{cid}_walk_up.png", bob(back))
        three_q.save(d / f"{cid}_three_quarter.png")
        print("ok", cid)


if __name__ == "__main__":
    main()

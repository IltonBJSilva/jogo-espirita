"""Extrai os sprites de Allan Kardec do painel de referencia.

Uso: python tools/extract_kardec.py
Entrada: assets/references/kardec_panel.png
Saida:   assets/characters/kardec/*.png (frames individuais, fundo transparente)

O painel tem fundo roxo escuro com degrade. O fundo e removido por flood fill
a partir das bordas de cada recorte; o contorno escuro dos personagens impede
que o preenchimento "vaze" para dentro deles.
"""
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/references/kardec_panel.png"
OUT = ROOT / "assets/characters/kardec"

# Altura final (px) do personagem no jogo, alinhada a escala do mapa de Paris.
TARGET_HEIGHT = 84


def is_background(p):
    r, g, b = p[:3]
    if max(r, g, b) < 34:  # contorno preto do personagem
        return False
    # sombra no chao: tons escuros quase sem cor
    if max(r, g, b) < 85 and max(r, g, b) - min(r, g, b) < 30:
        return True
    # fundo: tons roxos/violeta pouco saturados
    return b + 6 >= g and r < 150 and abs(r - b) < 45 and g < 110


def remove_background(img):
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    seen = [[False] * h for _ in range(w)]
    q = deque()
    for x in range(w):
        q.append((x, 0))
        q.append((x, h - 1))
    for y in range(h):
        q.append((0, y))
        q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or seen[x][y]:
            continue
        seen[x][y] = True
        if not is_background(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    # remove o "anel" escuro remanescente da sombra no chao (pixels isolados)
    return img


def components(img, min_area=1500):
    """Retorna as caixas (x0,y0,x1,y1) dos blocos opacos, ordenadas por x."""
    w, h = img.size
    a = img.getchannel("A").load()
    seen = set()
    boxes = []
    for x in range(w):
        for y in range(h):
            if a[x, y] == 0 or (x, y) in seen:
                continue
            q = deque([(x, y)])
            seen.add((x, y))
            x0 = x1 = x
            y0 = y1 = y
            n = 0
            while q:
                cx, cy = q.popleft()
                n += 1
                x0, x1, y0, y1 = min(x0, cx), max(x1, cx), min(y0, cy), max(y1, cy)
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and a[nx, ny] and (nx, ny) not in seen:
                        seen.add((nx, ny))
                        q.append((nx, ny))
            if n >= min_area:
                boxes.append((x0, y0, x1 + 1, y1 + 1))
    return sorted(boxes)


def is_shadow(p):
    """Sombra/fundo roxo: escuro, com azul bem acima do verde (ex. (30,18,36)).
    Os sapatos (ex. (43,33,41)), o contorno preto e o casaco vinho nao passam."""
    r, g, b = p[:3]
    return max(r, g, b) < 90 and b >= r + 3 and b - g >= 12


def strip_shadow(img):
    """Remove a sombra no chao e restos roxos do fundo: apaga pixels "de
    sombra" ligados ao exterior transparente, em qualquer altura do quadro,
    para que o jogo desenhe a sua propria sombra."""
    w, h = img.size
    px = img.load()
    stack = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] == 0]
    seen = set(stack)
    while stack:
        x, y = stack.pop()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen:
                p = px[nx, ny]
                if p[3] and is_shadow(p):
                    seen.add((nx, ny))
                    px[nx, ny] = (0, 0, 0, 0)
                    stack.append((nx, ny))
    bbox = img.getbbox()
    return img.crop(bbox) if bbox else img


def largest_only(img):
    """Mantem apenas o maior bloco opaco (descarta restos de sombra/brilho)."""
    boxes = components(img, min_area=1)
    if len(boxes) <= 1:
        return img
    a = img.getchannel("A").load()
    w, h = img.size
    best, best_n = None, -1
    seen = set()
    groups = []
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
            groups.append(pts)
    keep = set(max(groups, key=len))
    px = img.load()
    for x in range(w):
        for y in range(h):
            if (x, y) not in keep:
                px[x, y] = (0, 0, 0, 0)
    return img.crop(img.getbbox())


def extract_row(panel, region, splits=None, ref_index=0):
    """Recorta uma fileira do painel. `splits` (coordenadas x relativas ao
    recorte) separa colunas quando restos de brilho unem dois personagens.
    Cada fileira e normalizada para TARGET_HEIGHT usando o frame `ref_index`
    (no painel, as fileiras de baixo foram desenhadas em escala menor)."""
    crop = remove_background(panel.crop(region))
    if splits:
        cols = list(zip(splits[:-1], splits[1:]))
        boxes = [(x0, 0, x1, crop.height) for x0, x1 in cols]
    else:
        boxes = components(crop)
    raw = [largest_only(strip_shadow(crop.crop(box))) for box in boxes]
    scale = TARGET_HEIGHT / raw[ref_index].height
    frames = []
    for f in raw:
        nw = max(1, round(f.width * scale))
        nh = max(1, round(f.height * scale))
        f = f.resize((nw, nh), Image.LANCZOS)
        # binariza alpha para manter o visual pixelado
        a = f.getchannel("A").point(lambda v: 255 if v > 110 else 0)
        f.putalpha(a)
        frames.append(f)
    return frames


def remove_dark_blobs(img, reach=2):
    """Remove blocos escuros soltos (restos da sombra roxa do painel).
    Um contorno verdadeiro sempre encosta numa parte "quente" do personagem
    a ate `reach` px; pixels escuros na borda sem nenhuma cor por perto sao
    descascados, repetidamente, ate sobrar so o personagem."""
    w, h = img.size
    px = img.load()

    def dark(p):
        # escuro e roxo/neutro (azul >= vermelho): cor da sombra e do contorno
        return p[3] and max(p[:3]) < 55 and p[2] >= p[0]

    def colored(p):
        # qualquer outra parte do personagem (calca marrom, sapato, casaco vinho)
        return p[3] and not dark(p)

    changed = True
    while changed:
        changed = False
        remove = []
        for y in range(h):
            for x in range(w):
                p = px[x, y]
                if not dark(p):
                    continue
                edge = any(not (0 <= x + dx < w and 0 <= y + dy < h) or px[x + dx, y + dy][3] == 0
                           for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if not edge:
                    continue
                near_color = any(colored(px[x + dx, y + dy])
                                 for dx in range(-reach, reach + 1) for dy in range(-reach, reach + 1)
                                 if 0 <= x + dx < w and 0 <= y + dy < h)
                if not near_color:
                    remove.append((x, y))
        for x, y in remove:
            px[x, y] = (0, 0, 0, 0)
            changed = True
    return img


def pad_frames(frames, size):
    """Centraliza cada frame horizontalmente e alinha pelos pes."""
    out = []
    for f in frames:
        canvas = Image.new("RGBA", size, (0, 0, 0, 0))
        x = (size[0] - f.width) // 2
        y = size[1] - f.height
        canvas.paste(f, (x, y), f)
        out.append(remove_dark_blobs(canvas))
    return out


def main():
    panel = Image.open(SRC).convert("RGBA")
    OUT.mkdir(parents=True, exist_ok=True)

    view_splits = [0, 150, 300, 440, 595]

    rows = {
        "views": (470, 20, 1065, 235),
        "walk_side": (1160, 55, 2015, 235),
        "talk": (480, 300, 1025, 476),
        "study": (1085, 300, 1605, 476),
        "idle": (1670, 300, 2025, 476),
    }
    result = {}
    for name, region in rows.items():
        splits = view_splits if name == "views" else None
        result[name] = extract_row(panel, region, splits)
        print(name, [f.size for f in result[name]])

    cell = (72, 92)
    # Vistas: 0=frente, 1=3/4, 2=perfil (direita), 3=costas
    front, three_q, side, back = pad_frames(result["views"], cell)
    idle = pad_frames(result["idle"], cell)
    walk_side = pad_frames(result["walk_side"], cell)
    talk = pad_frames(result["talk"], cell)
    study = pad_frames(result["study"][:3], cell)

    save_strip(OUT / "kardec_idle_down.png", idle)
    save_strip(OUT / "kardec_idle_side.png", [side])
    save_strip(OUT / "kardec_idle_up.png", [back])
    save_strip(OUT / "kardec_walk_side.png", walk_side)
    save_strip(OUT / "kardec_walk_down.png", bob_frames(front))
    save_strip(OUT / "kardec_walk_up.png", bob_frames(back))
    save_strip(OUT / "kardec_talk.png", talk)
    save_strip(OUT / "kardec_study.png", study)
    three_q.save(OUT / "kardec_three_quarter.png")

    portrait = panel.crop((40, 40, 400, 590)).resize((180, 275), Image.LANCZOS)
    portrait.save(OUT / "kardec_portrait.png")
    print("ok ->", OUT)


def bob_frames(base):
    """Ciclo de caminhada frontal/costas (4 frames). O painel de referencia so
    traz caminhada lateral; aqui o corpo sobe 1-2 px e uma das pernas fica
    "plantada" no chao, alternando entre esquerda e direita."""
    w, h = base.size
    leg_h = 16
    frames = [base.copy()]
    for side in (0, 1):
        f = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        f.paste(base, (0, -2), base)
        x0 = 0 if side == 0 else w // 2
        leg = base.crop((x0, h - leg_h, x0 + w // 2, h))
        f.paste(leg, (x0, h - leg_h), leg)
        frames.append(f)
        frames.append(base.copy()) if side == 0 else None
    return frames  # [neutro, passo esq., neutro, passo dir.]


def save_strip(path, frames):
    w, h = frames[0].size
    strip = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * w, 0), f)
    strip.save(path)


if __name__ == "__main__":
    main()

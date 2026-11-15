# Gerando animações de personagens

Os ciclos completos do jogador (andar nas 4 direções, correr, respirar) foram gerados
com o Codex CLI a partir do recorte do personagem na referência
`assets/references/arquetipos_parisienses.png`, e depois extraídos com `tools/extract_sheet.py`.

## 1. Gerar a folha (Codex)

```bash
codex exec -s workspace-write -i <recorte_do_personagem>.png - < prompt.txt
```

Modelo de prompt (troque a descrição e o nome do arquivo):

```
Use your image generation tool. The attached image shows "<Nome>", <descrição: roupa, cabelo,
acessórios> of our 16-bit pixel-art RPG set in Paris 1857. Keep EXACTLY the same character
design, proportions (chibi, about 3 heads tall), colors, black pixel outline and shading.

Generate ONE sprite sheet image (PNG, about 1536x1280) with a perfectly FLAT, uniform pure
magenta background (#FF00FF) everywhere (no gradients, no panels, no text, no ground shadows).
Every sprite full body, same size, feet aligned on the same baseline inside each row, with
generous empty magenta space between sprites so none touch.

Rows (top to bottom):
1. Walk DOWN (facing the camera): 4 frames, alternating legs and arms swinging.
2. Walk UP (seen from the back): 4 frames, alternating legs and arms.
3. Walk RIGHT (side profile facing right): 6 frames, smooth walk cycle.
4. Run RIGHT (side profile facing right): 6 frames, leaning forward, longer strides.
5. Idle DOWN (facing camera, breathing): 4 frames, subtle breathing, blink in one frame.

Save it exactly as: assets/references/generated/<id>_animacoes.png
```

## 2. Extrair e montar

1. Registre a folha em `SHEETS` dentro de `tools/extract_sheet.py`. O padrão do estudante
   serve para o modelo acima.
2. Rode:

```bash
python tools/extract_sheet.py <id>
godot --headless --path . --import
godot --headless --path . --script res://scripts/tools/build_world.gd
```

O extrator remove o magenta e normaliza tudo para a célula 72x92 com a mesma escala do
Kardec, preservando a altura relativa dos quadros. Ele também alinha os perfis pela cabeça,
para o personagem não "tremer". Personagens com folha gerada são ignorados por
`extract_archetypes.py`, exceto o retrato.

## Convenções de animação

`idle_*`, `walk_*` e o opcional `run_*`, em que `*` é `down`, `side` ou `up`. Também são
opcionais `talk` e `study`. A vista `side` olha para a **direita**, e o jogo espelha para a
esquerda. Sem `run_*`, a corrida reaproveita a caminhada acelerada. Para mudar a duração de
cada frame (por exemplo, para uma piscada rápida), use `FRAME_DURATIONS` em `build_world.gd`.

## Profundidade (Y-Sort) dos objetos do mapa

Árvores e lampiões ficam em `DEPTH_OBJECTS` (`tools/build_paris_assets.py`), cada um com um
retângulo e uma **base**, que é o pé do tronco ou do poste. O jogador fica atrás do objeto
quando está acima da base e na frente quando está abaixo. Quando ele está escondido, a camada
Foreground fica semitransparente (`scripts/maps/foreground_layer.gd`).

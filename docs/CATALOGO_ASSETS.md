# Catálogo de assets

## Convenções
- Estilo: pixel art 16-bit, contorno preto, paleta vinho, marrom, dourado, verde-escuro e roxo,
  com iluminação quente.
- Os personagens usam células de **72x92 px**, com os pés alinhados na base.
  - Adultos medem **84 px** de altura; a criança mede **64 px**.
  - Os strips (faixas de frames) ficam em `assets/characters/<id>/<id>_<anim>.png`.
  - O perfil `side` olha para a direita (o jogo espelha para a esquerda).
- Os tiles têm **32 px**. Os interiores medem 30x17 tiles (960x544); Paris mede 48x32 tiles (1536x1024).
- A arte procedural é desenhada em meia resolução e ampliada 2x com vizinho-mais-próximo.
- Os recursos Godot gerados (`resources/tilesets`, `resources/sprite_frames` e `scenes/maps/*/*_tiles.tscn`)
  vêm de `scripts/tools/build_world.gd`. Não edite esses arquivos à mão.

## Referências (`assets/references/`)

| Arquivo | Origem | Uso |
|---|---|---|
| kardec_panel.png | usuário | sprites e retrato do Kardec |
| paris_1857_reference.png | usuário | mapa de Paris |
| arquetipos_parisienses.png | usuário | estudante, livreiro, estudioso, moradora (+ retratos) |
| pacote_visual.png | usuário ("Pacote Visual do RPG Espírita 2D") | bustos dos NPCs novos e ícones de itens |
| guia_visual_completo.png | usuário ("RPG Espírita 2D: Guia Visual Completo") | direção geral, capítulos, roadmap |
| generated/estudante_animacoes.png | Codex | animações completas do jogador |
| generated/{amelie,medium,medico,crianca,impressor,cocheiro}_animacoes.png | Codex | animações dos NPCs da expansão |
| generated/amelie_portrait.png | Codex | retrato da Amélie envelhecida (62 anos) |

O prompt-modelo do Codex está em `docs/SPRITES.md`. Para os NPCs, o pedido usou duas imagens: o busto
(design) e a folha do estudante (estilo e layout).

## Personagens (`assets/characters/`)

| Id | Animações | Retrato | Script |
|---|---|---|---|
| kardec | padrão + talk, study, three_quarter | painel (recorte) | tools/extract_kardec.py |
| estudante | walk 4/4/6, run_side 6, idle_down 4, idle_side, idle_up | arquétipos | tools/extract_sheet.py (o retrato vem de extract_archetypes.py) |
| livreiro, estudioso, moradora | padrão (walk_side 4, frente/costas "bob") + three_quarter | arquétipos | tools/extract_archetypes.py |
| amelie, medium, medico, impressor, cocheiro | walk 4/4/6, talk 4, idle_down 4, idle_side, idle_up | bustos do Pacote Visual (Amélie: retrato do Codex) | tools/extract_sheet.py |
| crianca | igual, com 64 px | busto "Criança" | tools/extract_sheet.py (`target_height` 64) |

Cada personagem é registrado nos `SpriteFrames` pela lista `CHARACTERS` de `build_world.gd`.
`FRAME_DURATIONS` define a piscada rápida do idle.

## Tilesets (`assets/tilesets/`)

| Mapa | Arquivos | Script |
|---|---|---|
| paris_1857 | paris_1857_atlas.png, paris_1857_foreground.png (só árvores e lampiões recortados) | tools/build_paris_assets.py |
| livraria | livraria_atlas.png | tools/build_livraria_assets.py |
| residencia_kardec, sociedade_salao, tipografia | <id>_atlas.png | tools/build_interiors.py |

Os layouts (colisão e camadas) ficam em `data/maps/<id>_layout.json`. No foreground de Paris, cada célula
tem a forma `[x, y, base_y]`.

## Interface (`assets/ui/`)
- `mapa_paris.png` (640x400): pergaminho com o Sena, a Île de la Cité, os parques e a rosa dos ventos.
  Gerado por `tools/build_ui_assets.py`.
- `icons/*.png` (48x48, fundo transparente):
  - livro, cartas, documento, jornal, tinta, pena, chave, flores, cristal, fotografia, bilhete
  - recortados de `pacote_visual.png` por `tools/extract_icons.py`
  - na prancha original, os rótulos "Relíquia" e "Flores" estão trocados; os arquivos usam o nome do desenho
- `resources/ui/main_theme.tres`: tema da interface (SystemFont serifada, painéis vinho e dourado).

## Uso dos ícones por item (`data/items/items.json`)
livro_dos_espiritos → livro · carta_recomendacao → cartas · marcador_pagina → bilhete ·
caderno_estudos → documento · provas_revista → documento · revista_espirita_1 → jornal ·
pao → bilhete · agasalho → documento · pena_presente → pena.

O pão e o casaco não têm ícone próprio e usam provisoriamente bilhete e documento; essa pendência está
em `docs/BACKLOG.md`. Os ícones tinta, chave, flores, cristal e fotografia ainda não têm uso.

## Regenerar tudo
```bash
python tools/extract_kardec.py
python tools/extract_archetypes.py
python tools/extract_sheet.py
python tools/build_paris_assets.py
python tools/build_livraria_assets.py
python tools/build_interiors.py
python tools/build_ui_assets.py
cd tools && python extract_icons.py && cd ..
godot --headless --path . --import
godot --headless --path . --script res://scripts/tools/build_world.gd
```

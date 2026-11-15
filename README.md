# Jogo Espírita — Paris, 1857

RPG 2D em pixel art 16-bit (Godot 4.7, GDScript) sobre a vida e os estudos de Allan Kardec.

## MVP jogável

- Tela inicial → mapa **Paris, 1857** (praça com fonte, Sociedade Espírita, livraria, residência de Kardec, bancos, lampiões, canal, fiacre).
- Interior da **Livraria** (entrar/sair pela porta).
- Jogador em 4 direções com animações de idle/caminhada, corrida, colisões e Y-Sort.
- NPCs: Allan Kardec, Professor Delaunay (estudioso), Madame Marguerite (moradora), Monsieur Gérard (livreiro).
- Interação (E), diálogos ramificados com retrato e texto progressivo, missão completa
  **Conhecendo a Sociedade Espírita**, minigame **Organizar a enciclopédia**, HUD, pausa, diário e inventário.

**Controles:** WASD/Setas mover · Shift correr · E interagir · J diário · I inventário · Esc pausa · F11 tela cheia.

## Estrutura

```
assets/        arte (characters/, tilesets/, references/ = imagens de referência originais)
data/          conteúdo em JSON: characters, dialogues/, quests/, items/, minigames, maps/ (layouts)
resources/     recursos Godot gerados (tilesets/, sprite_frames/) e ui/main_theme.tres
scenes/        main/ (título, jogo), maps/, characters/, npcs/, ui/, minigames/
scripts/       core/ (DataLoader, GameActions), managers/, dialogue/, quests/, inventory/,
			   interaction/, minigames/, player/, npcs/, characters/, maps/, ui/, tools/
tests/         smoke_test (joga a missão inteira) e screenshots
tools/         scripts Python que preparam a arte a partir das referências
docs/DADOS.md  formato de diálogos, missões, itens, condições e ações
docs/SPRITES.md  como gerar animações (Codex) e como funciona a profundidade (Y-Sort) do mapa
```

### Autoloads

| Manager | Papel |
|---|---|
| `GameManager` | estado do jogo, flags de progresso, personagens, novo jogo |
| `SceneManager` | troca de telas/mapas com fade; move o jogador para o mapa |
| `DialogueManager` | executa diálogos JSON (variantes, desvios, escolhas, ações) |
| `QuestManager` | missões, objetivos sequenciais, requisitos e recompensas |
| `InteractionManager` | escolhe o objeto mais próximo e dispara a interação |
| `InventoryManager` | itens do jogador |
| `MinigameManager` | abre minigames registrados em `data/minigames.json` |

Diálogos, objetos, gatilhos e minigames usam a mesma linguagem de **condições e ações**
(`scripts/core/game_actions.gd`), então novas histórias são escritas em JSON, sem código.

### Mapas

Cada mapa tem as camadas `Ground`, `Environment`, `Decoration`, `Collision` (visível só no
editor) e `Foreground` (copas e lampiões acima do jogador) em `<mapa>_tiles.tscn`, e a camada
`Interactive` (Y-Sort: NPCs, portas, objetos, gatilhos) em `<mapa>.tscn`.

## Regenerar a arte e os recursos

```bash
python tools/extract_kardec.py          # sprites do Kardec  (assets/references/kardec_panel.png)
python tools/extract_archetypes.py      # livreiro, estudioso, moradora (+ retratos) de arquetipos_parisienses.png
python tools/extract_sheet.py           # animacoes completas geradas (estudante: andar 4 direcoes, correr, respirar)
python tools/build_paris_assets.py      # atlas/foreground/layout de Paris
python tools/build_livraria_assets.py   # interior da livraria
godot --headless --path . --import
godot --headless --path . --script res://scripts/tools/build_world.gd   # TileSets, camadas e SpriteFrames
```

O construtor só reescreve os arquivos `*_tiles.tscn` e `resources/`; NPCs e objetos posicionados
nas cenas dos mapas não são afetados.

## Testes

```bash
godot --headless --path . res://tests/smoke_test.tscn            # joga a missão inteira (sai com 1 se falhar)
godot --path . res://tests/screenshots.tscn -- <pasta>           # captura telas para revisão
```

## Exportação

Inclua `*.json` em *Projeto › Exportar › Recursos › Filtros para exportar arquivos que não são recursos*.

### Android (APK de teste)

O preset `Android (teste)` gera um APK de depuração para aparelhos ARM 32/64-bit. Com o Android SDK e o
JDK 17 configurados no Godot, exporte pelo menu ou execute:

```bash
godot --headless --path . --export-debug "Android (teste)" build/android/JogoEspirita-debug.apk
```

O APK é assinado com chave de depuração e fica fora do Git em `build/android/`.

## Como adicionar conteúdo

- **NPC:** instancie `scenes/npcs/npc.tscn` na camada `Interactive` e defina `sprite_frames`, `npc_id`
  (em `data/characters.json`) e `dialogue_id` (em `data/dialogues/`).
- **Objeto/porta:** nó `Area2D` com `scripts/interaction/interactable.gd` + um diálogo
  (portas usam a ação `change_map`).
- **Missão:** novo arquivo em `data/quests/` e ações `start_quest`/`complete_objective` nos diálogos.
- **Minigame:** cena cuja raiz estende `Minigame`, registrada em `data/minigames.json`.
- **Mapa:** gere atlas + layout, adicione-o a `MAPS` em `build_world.gd` e crie `scenes/maps/<id>/<id>.tscn`.

---

## Expansão (capítulos 1 e 2)

A expansão acrescenta conteúdo **sem substituir** o MVP:
- 3 interiores novos: residência de Kardec, salão da Sociedade e tipografia.
- 6 personagens com animações completas: Amélie Boudet, Mlle. Aline, Dr. Lefèvre, Louis, M. Bertin e o
  cocheiro Bertrand.
- 5 missões novas: *Perguntas e Respostas*, *As Cartas do Professor*, *Pão para Louis*, *O Cético* e
  *A Revista Espírita*.
- **Enciclopédia** com 44 entradas, cada uma marcada como fato histórico, conceito doutrinário ou ficção.
- **Biblioteca** de livros e documentos legíveis.
- **Afinidade** com os NPCs e **progresso moral** pelas virtudes Caridade, Estudo e Fraternidade.
- **Viagem de fiacre** pelo mapa de Paris.
- **Salvar e Continuar** e calendário da história.
- Minigames de **questionário**, **debate** e **ordenação** (cartas, imprensa e linha do tempo).

**Como jogar:** dê dois cliques em `Jogar.bat`, que abre o jogo sem o editor. Ou rode
`godot --path .`.

**Novos controles:** **C** abre o Compêndio (Enciclopédia, Biblioteca, Relações e Progresso). No menu de
pausa há **Salvar jogo**, e o inventário ganhou o botão **Ler**.

**Novos testes:**
```bash
godot --headless --path . res://tests/expansion_test.tscn   # joga toda a expansão + salvar/carregar
godot --headless --path . res://tests/smoke_test.tscn       # missão original (continua passando)
godot --headless --path . res://tests/louis_lesson_test.tscn # arco de alfabetização de Louis
```

**Novos scripts de arte:**
```bash
python tools/extract_sheet.py           # estudante + amelie, medium, medico, impressor, cocheiro, crianca (folhas do Codex)
python tools/build_interiors.py         # residencia_kardec, sociedade_salao, tipografia
python tools/build_ui_assets.py         # assets/ui/mapa_paris.png
cd tools && python extract_icons.py     # ícones de itens (assets/ui/icons) a partir do Pacote Visual
```
Depois, rode `--import` e `scripts/tools/build_world.gd`, como antes.

### Documentação
| Documento | Conteúdo |
|---|---|
| [docs/DADOS.md](docs/DADOS.md) | formatos JSON (diálogos, missões, itens, enciclopédia, livros, quizzes, viagens) |
| [docs/MECANICAS.md](docs/MECANICAS.md) | sistemas e como estendê-los |
| [docs/MISSOES.md](docs/MISSOES.md) | as 6 missões, passo a passo |
| [docs/PERSONAGENS.md](docs/PERSONAGENS.md) | personagens, sprites, diálogos e onde aparecem |
| [docs/MAPAS.md](docs/MAPAS.md) | mapas, objetos interativos e spawns |
| [docs/MINIGAMES.md](docs/MINIGAMES.md) | minigames e como criar novos só com dados |
| [docs/NARRATIVA.md](docs/NARRATIVA.md) | capítulos, linha do tempo e cuidados editoriais |
| [docs/CATALOGO_ASSETS.md](docs/CATALOGO_ASSETS.md) | inventário de assets e scripts geradores |
| [docs/SPRITES.md](docs/SPRITES.md) | geração de animações (Codex) e profundidade |
| [docs/PLANO_ESPIRITUAL.md](docs/PLANO_ESPIRITUAL.md) | plano espiritual |
| [docs/BACKLOG.md](docs/BACKLOG.md) | o que está pronto e o que falta |
| [docs/CHANGELOG.md](docs/CHANGELOG.md) | registro de alterações |

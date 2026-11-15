# Mecânicas e sistemas

Todos os sistemas são autoloads (veja `project.godot`). A expansão acrescentou os seis últimos
sem reescrever os do MVP:

| Autoload | Arquivo | Papel |
|---|---|---|
| GameManager | scripts/managers/game_manager.gd | estado, flags, personagens, novo jogo |
| InventoryManager | scripts/inventory/inventory_manager.gd | itens |
| QuestManager | scripts/quests/quest_manager.gd | missões |
| DialogueManager | scripts/dialogue/dialogue_manager.gd | diálogos JSON |
| InteractionManager | scripts/interaction/interaction_manager.gd | foco e tecla E |
| MinigameManager | scripts/minigames/minigame_manager.gd | minigames |
| SceneManager | scripts/managers/scene_manager.gd | troca de cenas e mapas |
| **EncyclopediaManager** | scripts/managers/encyclopedia_manager.gd | Enciclopédia |
| **LibraryManager** | scripts/managers/library_manager.gd | Biblioteca e leitor |
| **RelationshipManager** | scripts/managers/relationship_manager.gd | afinidade |
| **ProgressManager** | scripts/managers/progress_manager.gd | virtudes e etapas |
| **TravelManager** | scripts/managers/travel_manager.gd | viagens de fiacre |
| **SaveManager** | scripts/managers/save_manager.gd | salvar e continuar |

Mudanças aditivas nos sistemas do MVP:
- O GameManager ganhou o sinal `new_game_started` e o estado `MENU`.
- Os managers que guardam estado ganharam `save_data()` e `load_data()`.
- O NPC ganhou `present_when`.

## Linguagem de condições e ações (`scripts/core/game_actions.gd`)
As condições e ações originais continuam iguais. A expansão acrescentou:

**Condições**
- `{"entry_unlocked": "id"}`: a entrada da enciclopédia foi descoberta.
- `{"book_read": "id"}`: o texto foi lido.
- `{"affinity_at_least": {"npc": "amelie", "value": 30}}`
- `{"virtue_at_least": {"virtue": "caridade", "value": 15}}`

**Ações**
- `{"type": "unlock_entry", "entry": "id"}`
- `{"type": "read_book", "book": "id"}`: abre o leitor no frame seguinte.
- `{"type": "add_affinity", "npc": "id", "amount": n}`
- `{"type": "add_virtue", "virtue": "caridade|estudo|fraternidade", "amount": n}`
- `{"type": "open_travel"}`
- `{"type": "save_game"}`

Para estender, acrescente um `case` em `check()` ou em `_run_one()` e documente-o em `docs/DADOS.md`.

> **Atenção:** as `actions` rodam quando o diálogo **entra** no nó, antes do texto. Num nó com texto,
> uma ação que troca de contexto (`change_map`, `start_minigame`, `read_book`) acontece enquanto a
> fala ainda está na tela. Para trocar de mapa depois de uma narração, crie um nó seguinte só com a
> ação (veja `porta_saida_tipografia.json`).

## Enciclopédia
- Os dados ficam em `data/encyclopedia/*.json`, no formato
  `{"entries": {id: {title, category, kind, text, source}}}`. Hoje são 44 entradas.
- `category` é uma destas: Personagens, Conceitos, Obras, Lugares, Acontecimentos.
- `kind` faz a distinção editorial exigida pelo escopo:
  - `fato_historico` (dourado no Compêndio)
  - `conceito_doutrinario` (azul)
  - `ficcao` (lilás)
- O campo `source` é obrigatório para fatos e conceitos.
- A entrada é desbloqueada pela ação `unlock_entry` ou ao ler um texto que a lista em `unlocks`.
- **Para estender:** acrescente entradas no JSON (ou crie outro arquivo na pasta). As categorias novas
  precisam entrar em `EncyclopediaManager.CATEGORIES`.

## Biblioteca e leitor
- Os dados ficam em `data/books/*.json`, no formato
  `{"books": {id: {title, author, kind, pages[], unlocks[], source}}}`.
- `kind` é um destes: livro, carta, documento, jornal.
- As páginas aceitam BBCode. A fonte (`source`) aparece no pé da última página.
- `LibraryManager.open(id)` registra a leitura, desbloqueia as entradas e abre `scenes/ui/book_reader.tscn`
  num CanvasLayer próprio (camada 35, `PROCESS_MODE_ALWAYS`). Isso permite abri-lo também com o jogo pausado.
- Um item com o campo `"book"` mostra o botão **Ler** no inventário. O Compêndio permite reler tudo o que já foi lido.
- **Para estender:** acrescente o texto ao JSON e abra-o com `read_book`, a partir de um objeto ou de um item.

## Relações (afinidade)
- A afinidade vai de 0 a 100 por personagem.
- Os níveis são: 0 Desconhecido, 10 Conhecido, 30 Amigo, 60 Confidente. Uma notificação aparece ao subir de nível.
- A aba **Relações** do Compêndio mostra o retrato, o título e uma barra de afinidade.
- **Para estender:** use `add_affinity` em diálogos e a condição `affinity_at_least` para falas ou
  missões exclusivas. Os níveis ficam em `RelationshipManager.LEVELS`.

## Progresso moral (virtudes)
- É uma adaptação **não competitiva** da "barra de moralidade" e das "ordens" do documento do mod. Não
  há combate, punição nem "barra de bondade" que bloqueie o jogador. Boas ações e estudo fazem o
  personagem progredir.
- As virtudes são `caridade`, `estudo` e `fraternidade`. O valor nunca fica abaixo de 0. Zombar
  reduz afinidade, não virtude.
- As etapas, pela soma das virtudes, são:
  - 0 Recém-chegado
  - 30 Aprendiz
  - 80 Estudante dedicado
  - 150 Trabalhador do bem

  Elas ficam em `ProgressManager.STAGES`.
- A aba **Progresso** do Compêndio mostra as virtudes, a etapa e as estatísticas (missões, entradas e textos).
- **Para estender:** use `add_virtue` e `virtue_at_least`. Uma virtude nova entra em `ProgressManager.VIRTUES`
  e em `compendium.tscn` (uma barra nova).

## Salvar e carregar
- Há um **salvamento automático** e **3 espaços manuais**, cada um em `user://saves/<auto|1|2|3>.json`
  com versão, data real, tempo de jogo, mapa, posição do jogador, um resumo (`meta`: local, data/hora do
  jogo, missão ativa) e o `save_data()` de cada sistema listado em `SaveManager.SYSTEMS`.
- O salvamento automático acontece ao trocar de mapa, a cada 3 minutos jogando, ao voltar ao título/sair e
  quando o app vai para segundo plano ou é fechado (no Android o sistema pode encerrar o app sem aviso).
  Não salva durante transições e minigames.
- **Salvar jogo** (pausa) abre a tela de espaços (`scripts/ui/save_slots.gd`); gravar por cima ou apagar
  pede confirmação (tocar duas vezes). **Carregar jogo** existe na pausa e no título. **Continuar** (título)
  carrega o save mais recente e mostra onde você parou.
- A gravação usa arquivo temporário + troca, então um app encerrado no meio não corrompe o save anterior.
  Um save corrompido aparece como vazio. O antigo `user://save.json` vira o Espaço 1 automaticamente.
- Cenas de teste (`res://tests/...`) usam `user://test_saves` e nunca tocam no jogo salvo do jogador.
- O carregamento emite `new_game_started` (todos os sistemas se zeram), aplica os dados salvos, chama
  `SceneManager.start_game(map)` e reposiciona o jogador.
- **Para estender:** um sistema novo com estado implementa `save_data()` e `load_data()` e entra em `SYSTEMS`.

## Controles de toque (Android)
- Autoload `TouchControls` (`scripts/ui/touch_controls.gd`): joystick virtual (empurrar até a borda corre),
  o personagem segue o eixo mais inclinado do joystick (4 direções),
  botões **Agir** (acende quando há algo para interagir) e **Correr** (liga/desliga), e atalhos **Menu**,
  **Diário**, **Itens** e **Comp.** Eles geram as mesmas ações do teclado, então os sistemas não mudam.
- Aparecem só no estado PLAYING e só no celular/tablet (Android/iOS); no PC o jogo é no teclado. Para testar no PC:
  `godot --path . -- --touch` (o mouse faz o papel do dedo).
- O botão **voltar** do Android funciona como Esc (abre/fecha a pausa, fecha telas); no título, fecha o app.
- No celular, os botões das telas ganham altura mínima de 40 px para caber o dedo.
## Viagens (fiacre)
- Os dados ficam em `data/travel.json`:
  `{"destinations": [{id, name, description, map, spawn, pin:[x,y], condition, locked_hint}]}`.
  `pin` é uma posição relativa de 0 a 1 no mapa `assets/ui/mapa_paris.png`.
- O cocheiro Bertrand (praça) executa `open_travel`.
- A tela `scenes/ui/travel_map.tscn` lista todos os destinos:
  - os liberados (condição atendida e mapa diferente do atual) são selecionáveis;
  - os bloqueados mostram `locked_hint`.
- Os destinos "Universidade" e "Cemitério do Père-Lachaise" aparecem bloqueados como prévia (flag `__futuro__`).
- **Para estender:** crie o mapa, acrescente o destino com uma condição (normalmente uma flag ligada por
  missão) e um spawn de chegada.

## Presença condicional de NPCs (`present_when`)
- É uma propriedade exportada de `npc.gd`: um JSON com a mesma linguagem de condições.
- Se a condição for falsa, o NPC fica invisível, sem colisão e sem interação. A condição é reavaliada
  quando as missões ou as flags mudam.
- Exemplo: o Doutor Lefèvre fica na praça com `{"not": {"quest_status": {... "o_cetico" ... completed}}}`
  e no salão com a condição inversa.
- **Para estender:** é a base para rotinas simples (personagens que mudam de lugar conforme a história).
  Rotinas por horário são uma pendência.

## Calendário (`data_atual`)
- A data da história é a flag `data_atual`, um texto livre (ex.: "Dezembro de 1857").
- O HUD a mostra sob o local (`DateLabel`). Os diálogos a mudam com `set_flag`.
- Hoje ela é usada na missão 6 (dezembro de 1857 e depois janeiro de 1858).

## Estado MENU
- `GameManager.State.MENU` foi acrescentado no fim do enum. Ele é usado pelo leitor e pelo mapa de viagem.
- Nesse estado o jogador não se move e o InteractionManager e o menu de pausa ignoram entradas.

## Compêndio (tecla C)
- A cena é `scenes/ui/compendium.tscn` (instanciada em `game.tscn` como `%Compendium`, camada 31).
- Abre com a tecla C (ação `compendium`) ou pelo botão "Compêndio" do menu de pausa. Ele pausa a árvore.
- Tem 4 abas: Enciclopédia, Biblioteca, Relações e Progresso. Ele só apresenta os dados; a lógica fica nos managers.

## Interface ampliada
- **Menu de pausa:** novos botões Compêndio e Salvar jogo; o inventário ganhou ícones (`assets/ui/icons`,
  pelo campo `icon` do item) e o botão Ler.
- **Título:** novo botão Continuar.
- **HUD:** mostra a data e a dica da tecla C.

# Registro de alterações

## 2026-11-14 — Sessão 1: MVP
- Projeto Godot 4.7 organizado com 7 autoloads: Game, Inventory, Quest, Dialogue, Interaction, Minigame e Scene.
- Mapa de Paris 1857 a partir da referência do usuário (`tools/build_paris_assets.py`), com camadas Ground,
  Environment, Decoration, Collision e Foreground.
- Interior da livraria (`tools/build_livraria_assets.py`).
- Sprites do Kardec (`tools/extract_kardec.py`) e dos arquétipos estudante, livreiro, estudioso e moradora
  (`tools/extract_archetypes.py`). A primeira tentativa recolorindo o Kardec foi descartada a pedido do usuário.
- Jogador (CharacterBody2D, 4 direções, corrida), NPC reutilizável, Interactable e TriggerZone.
- Diálogos JSON com variantes, desvios, escolhas e ações; missão "Conhecendo a Sociedade Espírita";
  minigame "Organizar a enciclopédia".
- HUD, caixa de diálogo, pausa, diário, inventário e tela de título.
- Teste automático `tests/smoke_test.tscn` e capturas `tests/screenshots.tscn`; `docs/DADOS.md`.

## 2026-11-14 — Sessão 2: animação e profundidade
- Folha de animações do jogador gerada pelo Codex (`assets/references/generated/estudante_animacoes.png`)
  e extraída por `tools/extract_sheet.py`: caminhada nas 4 direções, corrida e respiração com piscada.
- Actor e Player: estado de corrida (`run_side`) e fase do passo preservada na troca entre andar e correr.
- Correções nos arquétipos: o perfil parado olhava para o lado oposto ao da caminhada e os sapatos eram
  apagados pelo filtro de sombra.
- Foreground de Paris reconstruído como objetos com Y-Sort pela base (`DEPTH_OBJECTS`). Isso removeu
  pedaços de chão desenhados sobre o personagem e acrescentou transparência quando ele está atrás de uma
  copa (`scripts/maps/foreground_layer.gd`).
- `docs/SPRITES.md`, `Jogar.bat` (abre o jogo sem o editor) e os testes `depth_shots` e `anim_shots`.

## 2026-11-14 — Sessão 2b: pés do Kardec
- `tools/extract_kardec.py`: o filtro de sombra agora distingue a sombra roxa dos sapatos escuros, e
  `remove_dark_blobs` remove os restos roxos do fundo. Teste `kardec_shot`.

## 2026-11-14 — Sessão 3: Expansão dos capítulos 1 e 2 (somente aditiva)
**Sistemas novos (autoloads):**
- EncyclopediaManager, LibraryManager, RelationshipManager, ProgressManager, TravelManager e SaveManager.

**Integrações aditivas:**
- GameManager: sinal `new_game_started`, estado `MENU`, `save_data` e `load_data`.
- Inventory e Quest: `save_data` e `load_data`.
- GameActions: 4 condições e 6 ações novas.
- NPC: `present_when`.

**Interface:**
- Compêndio (C), com Enciclopédia, Biblioteca, Relações e Progresso.
- Leitor de livros e documentos.
- Mapa de viagem.
- Menu de pausa: Compêndio, Salvar jogo, ícones e Ler no inventário.
- Título: Continuar.
- HUD: data da história.

**Minigames genéricos:**
- `quiz.tscn`: questionario_le, debate_cetico.
- `ordenar.tscn`: cartas_kardec, imprensa_etapas, linha_do_tempo.

**Arte:**
- 6 personagens gerados pelo Codex: Amélie Boudet, Mlle. Aline, Dr. Lefèvre, Louis, M. Bertin e Bertrand.
  As referências são os bustos do Pacote Visual do usuário.
- Retrato da Amélie com a idade histórica.
- 3 interiores procedurais (`tools/build_interiors.py`): residência de Kardec, salão da Sociedade e tipografia.
- Ícones de itens (`tools/extract_icons.py`) e mapa de Paris em pergaminho (`tools/build_ui_assets.py`).

**Conteúdo:**
- 5 missões: perguntas_e_respostas, cartas_do_professor, pao_para_louis, o_cetico e revista_espirita.
- 26 diálogos novos e variantes acrescentadas a kardec, moradora, livreiro, porta_sociedade e
  porta_residencia, sem alterar nenhum nó existente.
- 44 entradas da enciclopédia, 8 textos legíveis, 2 questionários e 6 itens novos (os itens antigos
  ganharam ícone e livro).
- Destinos de viagem.

**Cenas:**
- Novos mapas `residencia_kardec`, `sociedade_salao` e `tipografia`.
- Novos nós na praça: Cocheiro, Louis, Lefèvre, JornalBanco, CartazObras e 3 spawns.

**Correções durante a validação:**
- Tipagem em `travel_map.gd`.
- O diálogo de saída da tipografia trocava de mapa com o texto ainda aberto; a troca foi separada em outro nó.

**Testes e documentação:**
- Teste `tests/expansion_test.tscn`, que joga toda a expansão e o ciclo salvar/carregar.
- Referências do usuário copiadas: `pacote_visual.png` e `guia_visual_completo.png`.
- Documentação: PERSONAGENS, MAPAS, MISSOES, MECANICAS, MINIGAMES, CATALOGO_ASSETS, NARRATIVA, BACKLOG,
  CHANGELOG, seções novas em DADOS e no README.
- O plano espiritual foi desenvolvido em paralelo por outro agente; veja `docs/PLANO_ESPIRITUAL.md`.

### 2026-11-14: Plano espiritual (epílogo do capítulo 2)
- Novo mapa `plano_espiritual` (Jardim da Reflexão), com arte gerada por `tools/build_spiritual.py`.
- Nova personagem: Irmã Clara (`espirito_guia`), com sprite e retrato gerados pelo Codex.
- Nova missão `jardim_da_reflexao` e 4 entradas novas na enciclopédia.
- Novo teste `tests/spiritual_test.tscn`. As 3 suítes passam: smoke, expansão e plano espiritual.

### 2026-11-14: Sistema de vida e As Primeiras Letras
- Calendário, luz ambiente, eventos e rotinas dos 11 NPCs passaram a compor a simulação persistente do mundo.
- `GameActions` ganhou condições reutilizáveis de agenda: `weekday` e `time_between`.
- Nova missão opcional *As Primeiras Letras*: após receber ajuda, Louis começa a aprender a ler com Amélie,
  toda quinta-feira das 13:00 às 14:30, na residência de Kardec.
- Testes `time_test`, `life_test` e `louis_lesson_test` validam as condições de agenda, as rotinas e a aula.

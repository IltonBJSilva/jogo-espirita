# Sistema de vida: contratos de integração

Este documento é a fonte da verdade para os módulos do sistema de vida (tempo, ambiente, NPCs,
vida social e eventos). Cada módulo tem um **dono** e só o dono edita os seus arquivos. Os módulos
conversam **apenas** pelas APIs e sinais abaixo.

## Regras gerais

- **Não alterar o que já existe.** Missões, diálogos, cenas de mapas, sprites e testes antigos
  continuam iguais. Integração com o código antigo só pelos pontos de gancho já preparados
  (marcados com `# --- sistema de vida ---`).
- Os dados ficam em JSON, em `data/world/` e `data/npcs/`. Nada de rotina hardcoded.
- **O tempo só passa no estado `PLAYING`.** Ele para em diálogos, menus, minigames, transições e
  na tela de título.
- **NPCs importantes para a história nunca ficam indisponíveis quando são necessários.** Isso é
  controlado pelos `pins` do perfil (seção 3).
- **Desempenho:** só os NPCs do mapa atual existem como nós. Os demais são simulados de forma
  abstrata, com mapa, local e atividade. As decisões rodam a cada mudança de minuto de jogo,
  nunca por frame; o movimento usa `_physics_process` apenas enquanto o NPC anda.
- Arte: só sprites existentes (`idle_*`, `walk_*`, `talk`, `study`). O que faltar (sentar,
  dormir, comer) é representado por pose, posição e **balões de emoção em pixel art** desenhados
  em código, e fica registrado como dependência de asset.
- Os testes antigos (`smoke_test`, `expansion_test`, `spiritual_test`) **têm de continuar
  passando** sem alterações. Os jogos novos começam às **09:00**, horário em que todos os NPCs
  estão nos mapas onde aparecem na cena original.

## 1. TimeManager (autoload `TimeManager`)

**Dono:** agente Tempo + Ambiente. Arquivo: `scripts/world/time_manager.gd`.

```gdscript
signal minute_changed(total_minutes: int)      # a cada minuto de jogo
signal hour_changed(hour: int)
signal phase_changed(phase: String)            # ver PHASES
signal day_changed(date: Dictionary)           # meia-noite
signal week_changed(week_index: int)           # segunda-feira 00:00
signal month_changed(month: int, year: int)
signal year_changed(year: int)
signal time_jumped(total_minutes: int)         # salto (história, carregar, avanço manual)

const PHASES := ["madrugada", "amanhecer", "manha", "meio_dia", "tarde", "por_do_sol", "noite"]
var time_scale: float                          # minutos de jogo por segundo real (padrão 1.0)
var running: bool                              # false = pausado por código (testes)

func get_total_minutes() -> int                # desde 01/01/ano_base 00:00
func get_hour() -> int
func get_minute() -> int
func get_minute_of_day() -> int                # 0..1439
func get_date() -> Dictionary                  # {year, month(1-12), day, weekday(0=segunda..6=domingo),
                                               #  weekday_name, month_name, day_of_year}
func get_phase() -> String
func is_night() -> bool                        # noite ou madrugada
func get_time_string() -> String               # "14:05"
func get_date_string() -> String               # "Terça-feira, 5 de maio de 1857"
func set_datetime(year, month, day, hour, minute) -> void   # emite time_jumped
func advance_minutes(minutes: int) -> void     # emite TODOS os sinais cruzados, em ordem
static func parse_hhmm(text: String) -> int    # "06:30" -> 390
func save_data() -> Dictionary
func load_data(data: Dictionary) -> void
```

- O calendário fica em `data/world/calendar.json`: meses (nome e dias), regra bissexta,
  nomes dos dias da semana, data inicial e faixas de horário de cada fase. Ele é gregoriano por
  padrão, com o dia da semana real.
- **Sincronia com a história:** a flag existente `data_atual` (ex.: "Dezembro de 1857") faz o
  calendário saltar para o dia 1 desse mês, às 09:00, se a data estiver no futuro.
- Novo jogo: zera via `GameManager.new_game_started` e vai para a data inicial.

## 2. EnvironmentManager (autoload `EnvironmentManager`)

**Dono:** agente Tempo + Ambiente. Arquivos: `scripts/world/environment_manager.gd` e
`data/world/lighting.json`.

- Escuta `TimeManager.minute_changed` e `SceneManager.map_changed`. Aplica um `CanvasModulate`
  (nó `DayNight`, criado em tempo de execução dentro do mapa atual) com cor interpolada
  suavemente pelas fases e também luzes (`PointLight2D`) de lampiões e janelas à noite.
- Cada mapa tem um perfil em `lighting.json`: `"outdoor"` (ciclo completo), `"indoor"` (variação
  leve; janelas escurecem à noite) ou `"none"` (plano espiritual: sem alteração).
- Legibilidade: brilho mínimo de cerca de 0.55 à noite. O HUD não é afetado (é um CanvasLayer).
- API: `get_light_color() -> Color` e `refresh()`.

## 3. LifeManager (autoload `LifeManager`)

**Dono:** agente Vida dos NPCs. Arquivos em `scripts/life/`, `data/npcs/*.json` e
`data/world/spots.json`.

```gdscript
signal npc_activity_changed(npc_id: String, activity: String, map_id: String, spot_id: String)
signal npc_arrived(npc_id: String, map_id: String, spot_id: String)

func get_profile(npc_id) -> Dictionary
func get_all_ids() -> Array[String]
func get_state(npc_id) -> Dictionary           # {map, spot, activity, mood, since(total_min), busy, pinned}
func get_npcs_in_map(map_id) -> Array[String]  # inclui simulação fora da tela
func get_npc_node(npc_id) -> NPC               # nó no mapa atual (ou null)
func request_activity(npc_id, activity: Dictionary, priority: int, until_minutes: int, source: String) -> bool
func release(npc_id, source: String) -> void
func is_available(npc_id) -> bool              # livre para social/eventos (sem diálogo, sem pin, acordado)
func walk_to(npc_id, map_id, spot_id) -> void  # pedido de deslocamento (social)
func face_towards_npc(npc_id, other_id) -> void
func show_emote(npc_id, emote: String) -> void # "conversa", "sono", "comida", "trabalho", "musica", "exclamacao", "coracao", "prece", "estudo"
func show_bark(npc_id, text: String, seconds := 3.0) -> void   # fala curta acima da cabeça
func remember(npc_id, text: String) -> void    # histórico (máx. 20, com data/hora)
func get_memory(npc_id) -> Array
func save_data() -> Dictionary
func load_data(data: Dictionary) -> void
```

`activity = {"activity": "reuniao", "map": "sociedade_salao", "spot": "mesa_1", "anim": "idle"}`

### Perfil `data/npcs/<npc_id>.json`

```json
{
  "id": "livreiro", "name": "Monsieur Gérard", "personality": "...", "occupation": "Livreiro",
  "mood": "sereno", "home": "casa_gerard", "wake": "06:30", "sleep": "22:00",
  "frames": "res://resources/sprite_frames/livreiro.tres", "dialogue_id": "livreiro",
  "favorite_places": ["livraria:balcao"], "favorite_activities": ["ler", "conversar"],
  "relations": {"moradora": "vizinho"},
  "schedule": {
    "default": [{"from": "06:30", "to": "08:00", "activity": "cuidar_casa", "location": "casa_gerard"},
                {"from": "08:00", "to": "18:00", "activity": "trabalhar", "location": "livraria:balcao"}],
    "domingo": [ ... ]
  },
  "pins": [{"condition": {"objective_current": {"quest": "conhecendo_sociedade", "objective": "encontrar_livro"}},
            "map": "livraria"}]
}
```

- `location`: `"<mapa>:<spot>"` (num mapa jogável) ou `"<lugar_abstrato>"` (casa, fora). Um NPC num
  lugar abstrato não aparece em nenhum mapa.
- `pins`: enquanto a condição (linguagem `GameActions`) for verdadeira, o NPC fica **na posição
  original da cena** daquele mapa: visível, parado e disponível. As rotinas de missões ficam
  bloqueadas por esse mecanismo e voltam ao normal sozinhas quando a condição deixa de valer.
- **Instâncias:** se o mapa tiver um nó NPC com o mesmo `npc_id`, esse nó é usado. Se não tiver,
  o LifeManager **instancia** `scenes/npcs/npc.tscn` com `frames` e `dialogue_id` (visitas a
  outros mapas). Nós de um NPC que está em outro lugar ficam ocultos.
- **Gancho no NPC existente:** `npc.gd` ganhou `life_present` e `life_controlled`. A presença
  final é `present_when` **E** `life_present`.
- Navegação: `AStarGrid2D` gerado de `data/maps/<mapa>_layout.json` (`solid`). Os NPCs não
  atravessam paredes e desviam do jogador e de outros NPCs (esperam ou recalculam a rota).
- Animação: mapeamento de atividade para animação com fallback. Balões de emoção ficam em
  `scripts/life/emote_bubble.gd`.

### Spots `data/world/spots.json`
`{"paris_1857": {"banco_esq": {"pos": [484, 540], "facing": [0, -1], "kind": "banco"}, ...}}`.
Todo spot precisa estar numa célula livre (há teste para isso).

## 4. SocialManager (autoload `SocialManager`)

**Dono:** agente Social + Eventos. Arquivos em `scripts/social/` e `data/world/social.json`
(relações, falas curtas).

- Relações entre NPCs: tipo (cônjuge, vizinho, amigo, colega, aluno), familiaridade de 0 a 100
  e mudanças com o convívio.
- Encontros: dois NPCs disponíveis (`LifeManager.is_available`) no mesmo mapa e próximos, com
  relação ou atividade compatível → aproximam-se, viram-se um para o outro, trocam falas curtas
  (`show_bark`) e emotes, e registram a conversa em `remember`. Isso tem cooldown por par.
- Reação ao jogador: um NPC disponível olha para o jogador que se aproxima e às vezes cumprimenta,
  conforme a afinidade do `RelationshipManager`.
- As falas curtas não contradizem a história; elas podem citar acontecimentos com condição
  (`GameActions`).
- API: `get_relation(a, b) -> Dictionary`, `get_familiarity(a, b) -> int`.

## 5. WorldEventManager (autoload `WorldEventManager`)

**Dono:** agente Social + Eventos. Arquivos em `scripts/events/` e `data/world/events.json`.

- Eventos diários, semanais (ex.: reunião de estudos às terças, 19:30–21:30, no salão), mensais e
  anuais (ex.: 18/04, aniversário de O Livro dos Espíritos; 03/10, aniversário de Kardec; 01/01,
  Ano-Novo) e eventos da história (com `condition`).
- Ao começar: notificação (opcional), `LifeManager.request_activity` para os participantes com
  prioridade de evento, e ações `GameActions` opcionais. Ao terminar: `release`.
- API: `get_active_events() -> Array`, `get_events_on(date: Dictionary) -> Array`,
  `signal event_started(id)` e `signal event_ended(id)`.

## 6. HUD do relógio

**Dono:** agente Tempo + Ambiente. Arquivos: `scenes/ui/clock_widget.tscn` e
`scripts/ui/clock_widget.gd` (já instanciados em `game.tscn` como `ClockWidget`). Mostra
hora, dia da semana, dia, mês, ano e ícone de dia ou noite, no estilo do HUD.

## 7. Prioridades de atividade (LifeManager)

| prioridade | origem |
|---|---|
| 100 | pin de missão (sempre vence) |
| 80 | diálogo com o jogador em andamento (NPC parado) |
| 60 | evento do mundo (`WorldEventManager`) |
| 40 | social (encontro, conversa) |
| 20 | rotina diária (`schedule`) |

## 8. Salvar e carregar

`TimeManager`, `LifeManager` e `SocialManager` entram em `SaveManager.SYSTEMS` (já registrados).

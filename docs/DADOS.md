# Formato dos dados (JSON)

Todo o conteúdo narrativo fica em `data/`. Textos em português, UTF-8.

## Personagens — `data/characters.json`

```json
{"characters": {"kardec": {"name": "Allan Kardec", "title": "...", "portrait": "res://...png"}}}
```

`narrador` (sem nome nem retrato) é usado para descrições de objetos.

## Diálogos — `data/dialogues/<id>.json`

```json
{
  "speaker": "kardec",
  "start": "inicio",
  "variants": [{"condition": {...}, "start": "outro_no"}],
  "nodes": {
    "inicio": {
      "speaker": "kardec",
      "text": "Uma fala"  ou  ["página 1", "página 2"],
      "actions": [ ... ],
      "branches": [{"condition": {...}, "next": "no"}],
      "choices": [{"text": "Opção", "next": "no", "condition": {...}, "actions": [ ... ]}],
      "next": "outro_no"
    }
  }
}
```

- `variants`: a primeira cuja condição for verdadeira define o nó inicial; senão usa `start`.
- Ao entrar num nó: executa `actions`, depois testa `branches` (desvio imediato).
- Nó sem `text` não aparece na tela: serve para só executar ações (ex.: portas) ou desviar.
- `next` vazio ou `"end"` encerra o diálogo. As escolhas aparecem na última página.

## Condições

Um objeto em que **todas** as chaves precisam ser verdadeiras:

| Chave | Exemplo |
|---|---|
| `flag` / `not_flag` | `{"flag": "apresentado_ao_grupo"}` |
| `has_item` / `not_item` | `{"has_item": "livro_dos_espiritos"}` |
| `quest_status` | `{"quest_status": {"quest": "id", "status": "not_started\|active\|completed"}}` |
| `objective_done` | `{"objective_done": {"quest": "id", "objective": "obj"}}` |
| `objective_current` | `{"objective_current": {"quest": "id", "objective": "obj"}}` |
| `all` / `any` / `not` | `{"any": [cond, cond]}` |

## Ações

| `type` | Campos |
|---|---|
| `set_flag` | `flag`, `value` (padrão `true`) |
| `give_item` / `remove_item` | `item`, `amount` |
| `start_quest` | `quest` |
| `complete_objective` | `quest`, `objective` |
| `change_map` | `map`, `spawn` (nome do SpawnPoint) |
| `start_dialogue` | `dialogue` |
| `start_minigame` | `minigame`, `on_success` (ações), `on_fail` (ações) |
| `notify` | `text` |

## Missões — `data/quests/<id>.json`

```json
{
  "id": "conhecendo_sociedade",
  "name": "...", "description": "...",
  "sequential": true,
  "requirements": {"quests_completed": [], "flags": [], "items": []},
  "objectives": [{"id": "explorar_praca", "description": "..."}],
  "rewards": {"items": {"carta_recomendacao": 1}, "flags": ["apresentado_ao_grupo"]}
}
```

Estados: não iniciada, ativa, concluída. Em missões `sequential`, só o objetivo atual pode ser concluído.

## Itens — `data/items/items.json`

```json
{"items": {"livro_dos_espiritos": {"name": "...", "description": "...", "category": "livro"}}}
```

## Minigames — `data/minigames.json`

```json
{"minigames": {"organizar_livros": {"scene": "res://scenes/minigames/organizar_livros.tscn", "title": "...", "description": "..."}}}
```

## Layouts de mapa — `data/maps/<mapa>_layout.json`

Gerados pelos scripts em `tools/`: listas de células `[x, y]` (tiles de 32 px) para
`solid` (colisão), `environment`, `decoration` e `foreground`.

---

# Formatos da expansão (capítulos 1 e 2)

## Personagens: campo `title`
`data/characters.json` aceita `title` (subtítulo exibido no Compêndio, aba Relações).

## Missões: campo `chapter`
`"chapter": 1` é informativo e serve para organizar a narrativa. Também é possível usar
`"sequential": false` (exemplo: `pao_para_louis`).

## Itens: campos `icon` e `book`
```json
"revista_espirita_1": {"name": "...", "description": "...", "category": "livro",
                       "icon": "jornal", "book": "revista_espirita_1"}
```
- `icon`: nome de um arquivo em `assets/ui/icons/<icon>.png`.
- `book`: id de um texto da biblioteca; com ele aparece o botão **Ler** no inventário.

## Enciclopédia: `data/encyclopedia/*.json`
```json
{"entries": {"deus": {"title": "Deus", "category": "Conceitos", "kind": "conceito_doutrinario",
                      "text": "...", "source": "O Livro dos Espíritos, q. 1"}}}
```
- `category`: Personagens | Conceitos | Obras | Lugares | Acontecimentos.
- `kind`: `fato_historico` | `conceito_doutrinario` | `ficcao`.

## Biblioteca: `data/books/*.json`
```json
{"books": {"id": {"title": "...", "author": "...", "kind": "livro|carta|documento|jornal",
                  "pages": ["texto com [b]BBCode[/b]", "..."], "unlocks": ["entrada"],
                  "source": "fonte exibida no pé da última página"}}}
```

## Questionários: `data/quizzes/*.json`
```json
{"intro": "...", "pass_score": 3,
 "questions": [{"question": "...", "options": ["...", "..."], "answer": 1,
                "explanation": "...", "source": "..."}]}
```

## Minigames: campo `params`
```json
"cartas_kardec": {"scene": "res://scenes/minigames/ordenar.tscn", "title": "...", "description": "...",
                  "params": {"instructions": "...", "items": ["na ordem correta", "..."], "conclusion": "..."}}
```
O quiz usa `{"questions_file": "res://data/quizzes/<id>.json"}`.

## Viagens: `data/travel.json`
```json
{"destinations": [{"id": "tipografia", "name": "...", "description": "...", "map": "tipografia",
                   "spawn": "entrada", "pin": [0.62, 0.56], "condition": {"flag": "tipografia_conhecida"},
                   "locked_hint": "Descubra este lugar na história."}]}
```

## Condições e ações novas
- **Condições:** `entry_unlocked`, `book_read`, `affinity_at_least {npc, value}`,
  `virtue_at_least {virtue, value}`.
- **Ações:** `unlock_entry {entry}`, `read_book {book}`, `add_affinity {npc, amount}`,
  `add_virtue {virtue, amount}`, `open_travel`, `save_game`.

Os detalhes estão em `docs/MECANICAS.md`.

## NPC: `present_when` (na cena)
É uma propriedade de `npc.tscn`: um texto JSON com uma condição. Se ela for falsa, o NPC some.
```
present_when = "{\"quest_status\": {\"quest\": \"o_cetico\", \"status\": \"completed\"}}"
```

## Flag especial `data_atual`
É um texto livre ("Dezembro de 1857") que o HUD mostra como data da história.

## Boa prática: ações que trocam de contexto
As `actions` rodam ao **entrar** no nó, antes do texto. Para trocar de mapa depois de uma fala,
coloque `change_map` num nó seguinte, sem texto.

# Minigames

**Arquitetura:**
- Toda cena de minigame tem uma raiz que estende `Minigame` (`scripts/minigames/minigame.gd`) e
  chama `finish(true/false)` ao terminar.
- O `MinigameManager` lê o registro `data/minigames.json`, abre a cena numa CanvasLayer própria
  (camada 40), passa a entrada do registro em `setup(info)` e, ao final, executa as ações `on_success`
  ou `on_fail` da ação `start_minigame` que o abriu.
- O mapa e o NPC não conhecem as regras do minigame.

```json
{"type": "start_minigame", "minigame": "<id>", "on_success": [...], "on_fail": [...]}
```

A expansão acrescentou o campo `params` ao registro, lido pelos minigames genéricos através de `info["params"]`.

---

## organizar_livros (MVP)
- **Cena:** `scenes/minigames/organizar_livros.tscn`. Ordenar os tomos I a V de uma enciclopédia.
- **Onde:** livraria, estante da esquerda. Dá a flag `enciclopedia_organizada` e o item `marcador_pagina`.

## Quiz genérico — `scenes/minigames/quiz.tscn`
- **Parâmetro:** `"questions_file": "res://data/quizzes/<id>.json"`.
- **Formato do arquivo:**

  ```json
  {"intro": "...", "pass_score": 4,
   "questions": [{"question": "...", "options": ["a", "b", "c"], "answer": 0,
                  "explanation": "...", "source": "..."}]}
  ```
- **Fluxo:** introdução, perguntas (cada resposta mostra a explicação e a fonte), resultado.
  Se passar, aparece "Concluir"; se não, "Tentar novamente". Esc desiste.
- **Usos:**

| Id | Arquivo | Onde | Aprovação | Também serve para |
|---|---|---|---|---|
| `questionario_le` | `questionario_le.json` (6 perguntas) | mesa do salão (missão 2) | 4 acertos | rever depois da missão |
| `debate_cetico` | `debate_cetico.json` (4 objeções) | Doutor Lefèvre (missão 5) | 3 acertos | Debate filosófico |

No `debate_cetico`, a resposta certa é a mais honesta e respeitosa.

## Ordenar genérico — `scenes/minigames/ordenar.tscn`
- **Parâmetros:** `instructions`, `items` (já na ordem **correta**; a cena embaralha) e `conclusion`
  (texto exibido ao terminar).
- **Interação:** selecione um cartão e depois outro para trocar os dois de lugar. "Concluir" aparece quando
  a ordem estiver certa.
- **Usos:**
  - `cartas_kardec`: ordenar 5 cartas de leitores por data (as cartas são fictícias; a conclusão é histórica).
    Fica na cômoda da residência (missão 3).
  - `imprensa_etapas`: as 6 etapas da impressão com prensa manual. Fica na prensa da tipografia (missão 6).
  - `linha_do_tempo`: 7 acontecimentos de 1848 a 1861. Fica no quadro-negro do salão (opcional;
    dá a flag `linha_do_tempo_feita`).

## Como criar um minigame só com dados
1. **Quiz:** crie `data/quizzes/<id>.json` e registre a entrada:

   ```json
   "meu_quiz": {"scene": "res://scenes/minigames/quiz.tscn", "title": "...", "description": "...",
                "params": {"questions_file": "res://data/quizzes/<id>.json"}}
   ```
2. **Ordenação:** registre a entrada com `params.items`, `params.instructions` e `params.conclusion`.
3. Abra o minigame com `start_minigame` num diálogo e coloque as recompensas em `on_success`.

## Minigames planejados (pendentes)
Investigação histórica, Escrita de manuscritos e Classificação de objetos (veja `docs/BACKLOG.md`). Os
dois primeiros podem reaproveitar o quiz e o ordenar.

## Testes
`tests/expansion_test.gd` resolve todos os minigames da expansão automaticamente (`_solve_quiz` e `_solve_ordering`).

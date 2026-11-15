# Vida dos NPCs (LifeManager)

Implementação das seções 3, 7 e 8 de [VIDA_CONTRATOS.md](VIDA_CONTRATOS.md).

## Arquivos

| Arquivo | Papel |
|---|---|
| `scripts/life/life_manager.gd` | Autoload `LifeManager`: estado global, decisões, prioridades, materialização no mapa, API |
| `scripts/life/npc_brain.gd` | `NPCBrain`: FSM, movimento e apresentação de um NPC no mapa atual (filho do nó NPC) |
| `scripts/life/nav_grid.gd` | `LifeNavGrid`: `AStarGrid2D` por mapa (células de 32 px, 4 direções), em cache |
| `scripts/life/npc_animator.gd` | `LifeAnimator`: atividade → pose/animação/balão (só sprites existentes) |
| `scripts/life/emote_bubble.gd` | `EmoteBubble`: balões de emoção e falas curtas em pixel art desenhados em código |
| `data/npcs/<id>.json` | Perfis e rotinas dos 11 NPCs |
| `data/world/spots.json` | Locais (spots) de cada mapa + saídas (`_exits`) |
| `tests/life_test.tscn` | Teste automatizado (headless) |
| `tests/life_shots.tscn` | Capturas para revisão visual |

## Como funciona

1. **Simulação abstrata:** todos os NPCs têm estado (`map`, `spot`, `location`, `activity`,
   `pinned`, `source`, `priority`), mesmo fora da tela. Um NPC em lugar abstrato (`casa_gerard`,
   `visitas_medicas`...) não aparece em nenhum mapa.
2. **Decisão:** a cada `TimeManager.minute_changed`, ou quando missões ou flags mudam, uma única
   rodada por frame (`_schedule` → `_flush`) recalcula o desejado de cada NPC. A prioridade é:
   pin de missão (100) > pedido de evento (60) > social (40) > rotina (20). O diálogo com o
   jogador (80) é tratado no cérebro: o NPC para e as ordens ficam pendentes até o fim da conversa.
3. **Materialização:** só o mapa atual tem nós. Ao entrar num mapa, os nós NPC da cena são
   reaproveitados pelo `npc_id`; quem visita um mapa sem nó próprio é instanciado
   (`scenes/npcs/npc.tscn`, nome `Life_<id>`, meta `life_spawned`); quem está em outro lugar fica
   oculto (`npc.set_life_present(false)`).
4. **Mudanças com o jogador presente:** o NPC sai andando até a saída (`_exits`) e some, ou entra
   pela saída que leva ao lugar de onde vem e anda até o spot.
5. **Saltos de tempo** (história, carregar, testes): as mudanças são aplicadas na hora, e
   `_sync_nodes` reconcilia nós e estado.
6. **Pins de missão:** enquanto a condição for verdadeira, o NPC fica na posição original da cena
   (`<id>_origem`), visível e disponível; ao terminar, volta sozinho à rotina.

### FSM do NPCBrain

`IDLE` → `WALKING` (A*) → `ACTIVITY` (pose + balões) · `LEAVING` (até a saída e some) ·
`DIALOGUE` (conversa com o jogador; ordens pendentes aplicadas depois).

- O jogador a menos de 48 px pausa o caminhar e o NPC olha para ele. Se o jogador ficar parado no
  caminho por mais de 3 s, o NPC recalcula a rota contornando-o, sem impasse.
- **Anti-sobreposição:** cada NPC reserva a célula seguinte (`LifeManager._reserved`); quem
  encontra a célula ocupada espera, replaneja após 2 s e, em último caso, atravessa após 6 s.
- Nunca atravessa paredes: o caminho usa só células livres do layout, e o teste confere isso
  a cada frame.

### Passeio ocioso

Na praça (`paris_1857`), durante `brincar`, `passear`, `conversar` e `trabalhar`, os NPCs
secundários andam um pouco em volta do ponto e voltam (raio de 1 a 3 células, pausas de 1,5 s a
16 s; ver `NPCBrain.WANDER`). Não passeiam: Kardec e a Irmã Clara, quem está com pin de missão ou
num encontro social, e ninguém sai quando o jogador está a menos de 64 px (para não fugir de quem
quer conversar). Os passeios não avisam o `LifeManager` (a atividade e o spot continuam os mesmos)
e usam as reservas de célula, então ninguém para dentro de outro NPC. `NPCBrain.wander_enabled`
desliga o recurso. Teste: `tests/wander_test.tscn`.

Nos encontros sociais (`walk_to(npc, mapa, "@outro")`), o NPC para a ~40 px do outro, do lado de
onde vem; se esse lado for parede ou estiver ocupado, tenta o outro lado, embaixo e em cima.

## Animações (atividade → apresentação)

| Atividade | Apresentação (só sprites existentes) | Balão |
|---|---|---|
| estudar | `study` (Kardec); os demais, idle | estudo |
| conversar | idle; `talk` durante encontros sociais | conversa |
| trabalhar / cuidar_casa | idle + bob de 1 px | trabalho |
| comer | idle | comida |
| descansar | idle (no banco ou na poltrona) | música |
| reunião | idle no lugar da mesa | estudo |
| prece | idle_down | prece |
| brincar | idle + passeio ocioso (corre em volta do ponto) | música |
| dormir | fora da tela (balão de sono se ocorrer num mapa) | sono |
| andar | `walk_down` / `walk_up` / `walk_side` (espelhado) | — |

Os balões e as falas (`show_emote`, `show_bark`) são desenhados em código, em pixel art.
Os ícones são: conversa, sono, comida, trabalho, música, exclamação, coração, prece e estudo.

## Rotinas (dia de semana; a terça tem a reunião de estudos às 19:15–21:45)

| NPC | Acorda / dorme | Rotina principal |
|---|---|---|
| Kardec | 06:00 / 22:30 | escreve em casa (06–07:30), café, **praça 08:15–12:00**, almoço, escreve (13–16), passeio na fonte, praça, jantar, escreve; terça: reunião no púlpito |
| Amélie | 06:00 / 22:00 | cuida da casa, café, **residência 08:15–12:00**, almoço, estuda na cômoda, porta da residência (15:30), casa, jantar, lareira |
| Gérard | 06:30 / 22:00 | **livraria 08:00–12:30** (balcão), almoço na livraria, estante, balcão até 19:00, banco da praça; domingo: meio período |
| Delaunay | 06:00 / 22:30 | **praça 08:00–12:00**, almoço, lê na livraria, trabalha em casa, banco da praça; terça: reunião |
| Marguerite | 05:30 / 21:30 | **praça 08:00–11:30**, almoço, feira, banco, praça, casa |
| Aline | 06:00 / 22:00 | prece em casa, **salão 08:00–12:00**, costura em casa, passeio no canal; terça: reunião |
| Lefèvre | 06:30 / 23:00 | **praça 08:00–11:30**, visitas médicas (fora do mapa), praça (16–17:30), casa; terça: observa a reunião (se `o_cetico` estiver concluída, o nó do salão aparece) |
| Louis | 07:00 / 20:00 | **praça 08:30–12:00**, almoço, fonte, canal, praça até 18:00, casa |
| Bertin | 05:30 / 21:30 | **tipografia 07:00–12:00**, almoço na dobra, prensa, composição até 18:00; domingo: meio período |
| Bertrand | 06:00 / 22:30 | **ponto do fiacre 08:00–20:00** (almoço na feira) |
| Irmã Clara | sempre | plano espiritual (com pin permanente) |

Às 09:00–11:00 todos estão no mapa e na posição em que aparecem nas cenas originais (os testes
antigos dependem disso).

## Pins de missão

| NPC | Condição | Mapa |
|---|---|---|
| Kardec | `conhecendo_sociedade`: conversar_kardec ou retornar_sociedade atual | praça |
| Kardec | `perguntas_e_respostas` ativa | salão |
| Kardec | `revista_espirita` ativa | praça |
| Amélie | `cartas_do_professor` ativa | residência |
| Gérard | `conhecendo_sociedade`: visitar_livraria ou encontrar_livro atual; `pao_para_louis` ativa sem o agasalho | livraria |
| Marguerite | `pao_para_louis` ativa sem o pão | praça |
| Aline | `perguntas_e_respostas` ativa; `revista_espirita` concluída e `jardim_da_reflexao` não concluída | salão |
| Lefèvre | `conhecendo_sociedade` concluída e `o_cetico` não concluída | praça |
| Louis | `pao_para_louis` ativa | praça |
| Bertin | `revista_espirita` ativa | tipografia |
| Bertrand | flag `tipografia_conhecida` ou `revista_espirita` ativa | praça |
| Irmã Clara | sempre | plano espiritual |

## Spots

Os ids fixos usados pelo social e pelos eventos (praça, salão, livraria, residência, tipografia
e jardim), mais `<npc_id>_origem` (posição original na cena), estão em `data/world/spots.json`.
Todos ficam em células livres; o teste verifica isso. `_exits` define por onde cada NPC entra e
sai de cada mapa.

## Extensões ao contrato

- `walk_to(npc, mapa, "@<outro_npc>")` caminha até o lado de outro NPC (usado em encontros).
- Pins aceitam `"activity"` opcional (padrão: `conversar`).
- `LifeManager.evaluate_all()` é público (reavaliação imediata).

## Desempenho (tests/life_test, headless)

- Cérebros de 6 NPCs andando na praça: cerca de **0,10–0,16 ms por frame** no total (cerca de
  0,02 ms por NPC).
- Decisão de todos os 11 NPCs: cerca de **0,2–0,3 ms** por rodada, no máximo uma vez por frame e
  só quando um minuto de jogo passa.
- NPCs fora do mapa atual não têm nós: a simulação deles é só uma consulta de agenda.

## Dependências de assets (sprites que não existem)

Hoje essas poses são representadas por pose + balão. Com sprites próprios, bastaria acrescentar
a animação ao SpriteFrames e ao `STYLES` de `npc_animator.gd`:
- **Sentar** (bancos, cadeiras do salão, poltronas): todos os NPCs.
- **Dormir/deitar**: hoje o sono acontece fora da tela.
- **Comer/beber**: refeições.
- **Trabalhar** específico: Bertin na prensa, Gérard arrumando livros, Bertrand com as rédeas.
- **Falar** (`talk`) para Gérard, Delaunay e Marguerite: os sprites atuais desses três não têm
  essa animação.
- **Ler** (`study`) para todos além do Kardec.
- **Brincar** (Louis: correr, pular).

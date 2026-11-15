# Vida social e eventos do mundo

Os módulos `SocialManager` e `WorldEventManager` são autoloads. O contrato de integração está em
[VIDA_CONTRATOS.md](VIDA_CONTRATOS.md), seções 4 e 5. Todo o conteúdo fica em JSON:

- `data/world/social.json`: relações, conversas entre NPCs e cumprimentos.
- `data/world/events.json`: calendário de eventos.

Os dois módulos só conversam com o resto do jogo pelas APIs públicas do `TimeManager`, do
`LifeManager`, do `GameActions`, do `RelationshipManager` e do `GameManager`.

## 1. Relações entre NPCs

Cada relação tem `a`, `b`, `type`, uma `familiarity` inicial (de 0 a 100) e, se for o caso, uma
`condition` e uma nota `fact` (quando a relação é histórica).

| Par | Tipo | Observação |
|---|---|---|
| Kardec e Amélie | cônjuge | Fato histórico: casados desde 1832. |
| Kardec e Delaunay, Kardec e Aline, Delaunay e Aline | colegas de estudo | Grupo de estudos. |
| Kardec e Bertin | colega de trabalho | Só depois da missão `revista_espirita`. |
| Amélie e Louis | professora e aluno | Só com a flag `amelie_ensina_louis`. |
| Delaunay e Lefèvre | cético e estudioso | |
| Gérard, Marguerite, Bertrand, Louis... | vizinhos e conhecidos | A vida do bairro. |

A familiaridade sobe `familiarity_gain` pontos (padrão 3) a cada conversa e é salva no jogo
(`SaveManager`, chave `social`). Ela volta ao valor inicial num jogo novo.

API: `get_relation(a, b)` devolve a relação, ou `{}` se ela não existir ou se a condição for falsa.
`get_familiarity(a, b)` e `is_in_conversation(id)` completam a consulta.

## 2. Encontros (conversas entre NPCs)

- São avaliados a cada `check_every_minutes` minutos de jogo (padrão 5), sempre pelo sinal do
  relógio, **nunca por frame**.
- Só participam NPCs com `LifeManager.is_available(id)`: acordados, sem pin de missão e sem
  diálogo em andamento. Os dois precisam estar no mesmo mapa jogável; quem está "em casa" ou
  "fora" não conversa.
- Cada par tem um cooldown (`pair_cooldown_minutes`, padrão 120). Pares com relação têm peso
  maior no sorteio, e `encounter_chance` controla a frequência.
- **Na tela** (o mapa é o atual e os dois estão a até 220 px um do outro):
  1. Os dois pedem a atividade `conversar` (prioridade 40) ao LifeManager.
  2. Viram-se um para o outro, e o primeiro mostra o emote `conversa`.
  3. Trocam as falas alternadas com `show_bark`, com 2,6 s cada.
- **Fora da tela**, a conversa é abstrata: o estado `conversar` dura o tempo de jogo equivalente.
- No fim, a familiaridade sobe, cada um registra "Conversou com X." na memória (`remember`) e os
  dois são liberados (`release`), voltando à rotina.

### Escolha das falas
1. Uma conversa específica do par em `conversations`, cuja `condition` seja verdadeira. A ordem
   das falas segue `participants` (`[0, "texto"]` é o primeiro, `[1, "texto"]` é o segundo).
2. Se não houver, uma das `generic_conversations`.

Algumas conversas dependem da história. Exemplos:
- Delaunay e Lefèvre têm uma conversa antes e outra depois de `o_cetico`.
- Marguerite pergunta a Louis sobre o casaco depois de `pao_para_louis`.
- Amélie e Louis só conversam sobre a aula com a flag `amelie_ensina_louis`.

**Cuidado editorial:** Kardec e Amélie dizem apenas frases genéricas e cordiais do cotidiano.
Nenhuma fala é apresentada como citação real.

## 3. Reação ao jogador
A cada 0,4 s (tempo real, só no estado PLAYING), os NPCs visíveis do mapa atual que estão a menos
de `greet_distance` px (padrão 72):
- olham para o jogador, se estiverem parados;
- ao serem **abordados** (a transição de longe para perto), cumprimentam com probabilidade
  `greet_chance` e com cooldown por NPC (`greet_cooldown_minutes`).

O cumprimento usa `greetings.by_npc[id]`, se existir; senão usa `greetings.by_level[nível]`,
pelo nível de afinidade do `RelationshipManager` (Desconhecido, Conhecido, Amigo, Confidente).
`{periodo}` vira "Bom dia", "Boa tarde" ou "Boa noite", conforme a fase do `TimeManager`.

## 4. Calendário de eventos (`data/world/events.json`)

| Evento | Quando | Onde | Participantes |
|---|---|---|---|
| Abertura da tipografia | diário, exceto domingo, 07:00–07:30 | tipografia | Bertin (prensa) |
| Abertura da livraria | diário, exceto domingo, 09:00–09:20 | livraria | Gérard (balcão) |
| Almoço | diário, 12:00–12:45 | vários | Gérard, Bertin, Bertrand e Marguerite comem |
| Acendedor de lampiões | diário, 18:00 | praça | só aviso (se o jogador estiver na praça) |
| Reunião de estudos | **terça**, 19:30–21:30 | salão | Kardec (púlpito), Aline, Delaunay, Amélie e Lefèvre (com `lefevre_observador`) |
| Lefèvre observa | terça, 19:00–19:30 | salão | Lefèvre (com `lefevre_observador`) |
| Feira na praça | **sábado**, 08:00–12:00 | praça | Marguerite, Bertrand e Louis (`feira_1..3`) |
| Passeio de domingo | **domingo**, 15:00–17:00 | praça | Amélie, Kardec, Delaunay e Louis |
| Nova Revista Espírita | dia **1** de cada mês, 09:00–11:00 | tipografia e residência | Bertin e Kardec, depois de `revista_espirita` |
| Aniversário de O Livro dos Espíritos | **18/04**, a partir de 1858 | livraria | Gérard; desbloqueia a entrada |
| Aniversário do professor Rivail | **03/10**, 19:00–21:00 | residência | Kardec e Amélie |
| Ano-Novo | **01/01** | — | aviso |
| Fundação da Sociedade Parisiense | **01/04**, a partir de 1858 | salão | Kardec, Delaunay e Aline |

As datas históricas usadas são: O Livro dos Espíritos publicado em 18/04/1857; Rivail nascido
em 03/10/1804; Sociedade Parisiense de Estudos Espíritas fundada em 01/04/1858. A reunião de
terça segue a placa da porta da Sociedade ("Reuniões de estudo às terças-feiras"). O jogo evita
de propósito eventos de religião institucional.

### Funcionamento
- A cada minuto de jogo, `evaluate()` liga os eventos cuja data, horário e `condition` valem, e
  desliga os que deixaram de valer. Saltos de tempo (`time_jumped`) também reavaliam, sem
  notificação.
- Quando um evento começa:
  - cada participante recebe `LifeManager.request_activity(npc, {activity, map, spot}, 60, fim,
    "event:<id>")`; um pin de missão (prioridade 100) vence, e o participante fica onde está;
  - a memória do NPC registra "Participou: ...";
  - as `actions` rodam e a `notify` é mostrada (com `notify_map`, só se o jogador estiver lá).
- Quando um evento termina, `release(npc, "event:<id>")` devolve o NPC à rotina.
- Tudo funciona com o jogador em qualquer mapa, porque o LifeManager simula os NPCs fora da tela.

API: `get_active_events()`, `is_active(id)`, `get_events_on(date)` (só pela recorrência, para
calendários), `get_event(id)`, `evaluate()` e os sinais `event_started(id)` e `event_ended(id)`.

## 5. Como adicionar conteúdo só com dados

**Novo evento:**
```json
{"id": "sarau", "name": "Sarau na residência",
 "recurrence": {"type": "weekly", "weekday": 4}, "start": "20:00", "end": "22:00",
 "map": "residencia_kardec", "condition": {"flag": "capitulo2_revista"},
 "participants": [{"npc": "amelie", "spot": "lareira", "activity": "conversar"}],
 "notify": "Sexta-feira: sarau na casa dos Rivail."}
```

Tipos de recorrência:
- `daily`, que aceita `except_weekdays`;
- `weekly`, com `weekday` (0 = segunda ... 6 = domingo);
- `monthly`, com `day`;
- `yearly`, com `month` e `day`;
- `date`, com `year`, `month` e `day`.

Os três últimos aceitam `from_year` e `to_year`. Use apenas spots que existem em
`data/world/spots.json`.

**Nova conversa:** acrescente a `conversations`:
```json
{"id": "x", "participants": ["livreiro", "medico"], "condition": {...},
 "lines": [[0, "Fala do primeiro."], [1, "Resposta do segundo."]]}
```

**Novo cumprimento:** acrescente a `greetings.by_npc` ou `greetings.by_level`.

## 6. Testes
`tests/social_events_test.tscn` (headless) verifica:
- relações (inclusive as condicionais);
- uma conversa forçada: estado no LifeManager, fim da conversa, familiaridade, memória e volta à
  rotina;
- encontros espontâneos e o cumprimento ao jogador;
- a reunião de terça (com pins respeitados) e a feira de sábado;
- o evento mensal com condição e os eventos anuais (18/04, 03/10, 01/01, 01/04 com `from_year`);
- salvar e carregar a familiaridade.

Com `-- shot <pasta>` (sem headless), o teste salva uma captura de dois NPCs conversando.

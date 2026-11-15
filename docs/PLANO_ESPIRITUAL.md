# Plano espiritual: O Jardim da Reflexão (epílogo do capítulo 2)

Primeiro ambiente espiritual do jogo. É um lugar sereno de **recolhimento e revisão**: não tem
combate, perigo nem "provas". O jogador chega a ele por meio de uma prece em silêncio no salão
da Sociedade e revê, com uma benfeitora, os conceitos que estudou nos capítulos 1 e 2.

## Mapa `plano_espiritual`

| | |
|---|---|
| Cena | `scenes/maps/plano_espiritual/plano_espiritual.tscn` (raiz `GameMap`) |
| Camadas | `plano_espiritual_tiles.tscn`, gerada pelo `build_world.gd` (Ground/Environment/Decoration/Collision) |
| Arte | `assets/tilesets/plano_espiritual/plano_espiritual_atlas.png` (960x544) |
| Layout | `data/maps/plano_espiritual_layout.json` |
| Spawn | `entrada` (480, 470), olhando para cima |

Composição: um horizonte crepuscular (do violeta ao dourado, com estrelas e nuvens) na borda
superior; um terraço gramado com flores luminosas; caminhos de pedra clara em cruz; uma fonte
de água cristalina no centro; árvores luminosas; dois bancos; e um pórtico de pedra branca por
onde passa uma luz suave. Uma sebe florida fecha as bordas. Um círculo dourado marca a entrada.

Pontos interativos (`Interactive`, com Y-Sort):

| Nó | Diálogo | Função |
|---|---|---|
| `IrmaClara` (NPC) | `irma_clara` | acolhida, lembrete e despedida (volta ao salão) |
| `Fonte` | `reflexao_fonte` | imortalidade da alma |
| `Arvore` | `reflexao_arvore` | reencarnação e progresso |
| `Portico` | `reflexao_portico` | caridade e lei de amor |
| `CirculoLuz` | `jardim_saida` | encerra a prece a qualquer momento e volta ao salão |
| `GatilhoEntrada` | `gatilho_jardim` | conclui "Chegar ao Jardim da Reflexão" |

## Guia: Irmã Clara (`espirito_guia`)

É um Espírito benfeitor **fictício**: uma mulher serena de meia-idade, de túnica lilás clara e
xale. Ela não representa Jesus nem nenhuma pessoa real, e suas falas são criação do jogo. Os
dados ficam em `data/characters.json` e a entrada `irma_clara` da enciclopédia é do tipo
`ficcao`.

- Sprites: `assets/characters/espirito_guia/` (idle, walk nas 3 direções e talk), extraídos de
  `assets/references/generated/espirito_guia_animacoes.png` com `tools/extract_sheet.py`.
- Retrato: `assets/characters/espirito_guia/espirito_guia_portrait.png` (cópia de
  `assets/references/generated/espirito_guia_portrait.png`).

## Missão `jardim_da_reflexao`

- **Capítulo:** 2. **Requisito:** `revista_espirita` concluída.
- **Início:** Mademoiselle Aline, no salão, convida para uma prece em silêncio (variante nova
  `prece_convite` em `aline.json`). Se o jogador sair antes do fim, a variante `prece_retorno`
  deixa voltar ao jardim.
- **Objetivos** (`sequential: false`, mas a ordem é garantida pelas condições dos diálogos):
  1. Chegar ao Jardim da Reflexão (gatilho).
  2. Conversar com Irmã Clara.
  3. a 5. Refletir diante da fonte, da árvore e do pórtico, em qualquer ordem. Só valem depois
     de falar com a guia.
  6. Despedir-se de Irmã Clara. Só fica disponível depois das três reflexões e devolve o
     jogador ao `sociedade_salao`.
- **Recompensas:** flag `capitulo2_epilogo`; virtudes estudo (+15 no total), caridade (+5) e
  fraternidade (+10); afinidade com a guia; entradas da enciclopédia.

### Conceitos e entradas da enciclopédia

| Ponto | Ideia | Entradas desbloqueadas |
|---|---|---|
| Guia | mundo espiritual, prece | `mundo_espiritual`, `prece`, `irma_clara` (novas) |
| Fonte | a vida continua | `imortalidade` |
| Árvore | existências sucessivas, progresso | `reencarnacao`, `escala_espirita` |
| Pórtico | benevolência, indulgência, perdão | `caridade`, `lei_amor` |
| Despedida | o jardim é uma representação | `jardim_jogo` (nova) |

As entradas novas ficam no arquivo próprio `data/encyclopedia/plano_espiritual.json`.

## Cuidados doutrinários e editoriais

- O jardim é uma **representação artística**, e o jogo deixa isso claro na fala da guia e na
  entrada `jardim_jogo`. Ele não pretende descrever literalmente o plano espiritual.
- Nenhuma fala é apresentada como citação real. Os conceitos seguem *O Livro dos Espíritos*
  (Parte 2: mundo espírita; Parte 3: lei de adoração e lei de amor), indicado como fonte nas
  entradas.
- O tom é sereno e acolhedor, sem nada sombrio, sem medo e sem combate. As reflexões retomam
  vivências do próprio jogador (a carta de Lyon, Louis, o Doutor Lefèvre).
- Toda troca de mapa fica num nó só de ação, **depois** do texto (veja `docs/DADOS.md`).

## Como gerar a arte

```bash
python tools/build_spiritual.py                 # atlas + layout do jardim
python tools/extract_sheet.py espirito_guia     # sprites da guia (folha gerada pelo Codex)
godot --headless --path . --import
godot --headless --path . --script res://scripts/tools/build_world.gd
```

A folha da guia foi gerada pelo Codex CLI com o modelo de prompt de `docs/SPRITES.md`
(5 fileiras, fundo magenta), usando `assets/references/generated/medium_animacoes.png` como
referência de estilo. O retrato foi gerado da mesma forma, usando o retrato da Amélie como
referência de estilo.

## Testes

```bash
godot --headless --path . res://tests/spiritual_test.tscn        # joga a missão inteira
godot --path . res://tests/spiritual_shot.tscn -- <pasta>        # capturas do jardim
```

# Personagens

Os dados de nome, título e retrato ficam em `data/characters.json`; os SpriteFrames em
`resources/sprite_frames/<id>.tres` (gerados por `scripts/tools/build_world.gd`); os PNGs
em `assets/characters/<id>/`. Cada NPC é uma instância de `scenes/npcs/npc.tscn` configurada
com `npc_id`, `dialogue_id`, `sprite_frames`, `facing` e, opcionalmente, `talk_radius` e
`present_when` (veja `docs/MECANICAS.md`).

**Legenda:** 🟫 fato histórico · 🟪 ficção do jogo (sempre marcado na Enciclopédia).

Animações padrão: `idle_down`, `idle_side`, `idle_up`, `walk_down`, `walk_side`, `walk_up`
(o perfil `side` olha para a direita e é espelhado para a esquerda). Célula 72x92 px; adultos com
84 px de altura e a criança com 64 px.

---

## Allan Kardec 🟫 — `kardec`
- **Papel:** mentor e personagem histórico central. Dá início às missões principais 1, 2 e 6.
- **Personalidade:** sério, metódico, gentil e paciente com quem pergunta de boa-fé.
- **Histórico:** Hippolyte Léon Denizard Rivail (1804–1869), educador e discípulo de Pestalozzi,
  autor de *O Livro dos Espíritos* (1857), fundador da *Revista Espírita* e da Sociedade
  Parisiense de Estudos Espíritas (ambas em 1858).
- **Onde aparece:**
  - Praça `paris_1857`, nó `Kardec` em (795, 452), diante da escadaria. Diálogo: `kardec`.
  - Salão `sociedade_salao`, nó `KardecSalao` em (480, 205), atrás da mesa, com `talk_radius` 64. Diálogo: `kardec_salao`.
- **Sprite:** `assets/characters/kardec/` (extraído de `kardec_panel.png` por
  `tools/extract_kardec.py`). Animações: as padrão, mais `talk` (4 frames) e `study` (3 frames).
  A caminhada de frente e de costas é só um sobe-e-desce ("bob"), sem ciclo de passos.
- **Retrato:** `kardec_portrait.png`.
- **Missões:** inicia a 1, a 2 e a 6; conclui a 1, a 2 (no salão) e a 6.
- **Afinidade:** +5 no convite para o estudo, +10 no fim da missão 2 e +10 na entrega da Revista.

## Étienne (jogador) 🟪 — `estudante`
- **Papel:** protagonista. É um jovem estudante recém-chegado de Lyon.
- **Sprite:** `assets/characters/estudante/`. As animações completas foram geradas pelo Codex
  (`assets/references/generated/estudante_animacoes.png`) e extraídas por `tools/extract_sheet.py`:
  - caminhada de 4 frames para baixo e para cima
  - caminhada lateral de 6 frames
  - `run_side` (corrida, 6 frames)
  - `idle_down` com respiração e piscada (4 frames, com durações próprias em `FRAME_DURATIONS`)
- **Retrato:** recortado da referência `arquetipos_parisienses.png`.
- **Cena:** `scenes/characters/player.tscn`.

## Monsieur Gérard, o livreiro 🟪 — `livreiro`
- **Papel:** dono da livraria. Guarda *O Livro dos Espíritos* e o casaco para Louis.
- **Onde:** `livraria`, nó `Livreiro` em (790, 214), atrás do balcão, com `talk_radius` 92. Diálogo: `livreiro`.
- **Sprite:** extraído de `arquetipos_parisienses.png` (`tools/extract_archetypes.py`). Só tem as animações padrão.
- **Missões:** 1 (dá a dica do livro) e 4 (dá o `agasalho`, +5 de afinidade).

## Professor Delaunay, o estudioso 🟪 — `estudioso`
- **Papel:** membro do grupo de estudos. Explica o que são médiuns e como são as reuniões.
- **Onde:** praça, nó `Estudioso` em (1000, 572). Diálogo: `estudioso`.
- **Sprite:** de `arquetipos_parisienses.png`. Só tem as animações padrão.

## Madame Marguerite, a moradora 🟪 — `moradora`
- **Papel:** moradora da praça que conhece todo mundo. Dá o pão para Louis.
- **Onde:** praça, nó `Moradora` em (372, 690). Diálogo: `moradora`.
- **Missão:** 4 (variante `pao_louis`: dá o item `pao`, +5 de afinidade).

## Amélie Boudet 🟫 — `amelie`
- **Papel:** esposa de Kardec (1795–1883), professora, escritora e pintora. Em 1857 tinha 62 anos,
  e o sprite e o retrato respeitam essa idade.
- **Personalidade:** acolhedora, prática e dedicada à educação.
- **Onde:** `residencia_kardec`, nó `Amelie` em (496, 380). Diálogo: `amelie`.
- **Sprite:** gerado pelo Codex a partir do busto do Pacote Visual
  (`assets/references/generated/amelie_animacoes.png`), com `talk`.
- **Retrato:** versão envelhecida gerada pelo Codex (`generated/amelie_portrait.png`, copiada para
  `amelie_portrait.png`).
- **Missões:** inicia e conclui a 3 (dá `pena_presente`). Também tem a variante `louis`, em que
  aceita ensinar Louis a ler (`amelie_ensina_louis`).
- **Afinidade:** +5 ao se apresentar, +15 ao concluir a missão 3, +3 ao contar sua história e +5 no gancho de Louis.

## Mademoiselle Aline, a médium 🟪 — `medium`
- **Papel:** jovem médium do grupo, inspirada nas irmãs Baudin (que são fato histórico).
- **Personalidade:** simples e serena; não se acha especial.
- **Onde:** `sociedade_salao`, nó `Aline` em (176, 215), olhando para a direita. Diálogo: `aline`.
- **Sprite:** gerado pelo Codex, com `talk`. O retrato é o busto "Médium" do Pacote Visual.
- **Missão:** 2 (`conversar_aline`, +10 de afinidade; desbloqueia `medium`, `psicografia` e `irmas_baudin`).

## Doutor Lefèvre, o médico cético 🟪 — `medico`
- **Papel:** representa a crítica honesta da época.
- **Onde:**
  - Praça, nó `Lefevre` em (520, 625), com `present_when = not(o_cetico concluída)`. Diálogo: `lefevre`.
  - Salão, nó `LefevreSalao` em (832, 316), com `present_when = o_cetico concluída`. Diálogo: `lefevre_salao`.
- **Sprite:** gerado pelo Codex (com maleta), com `talk`. O retrato é o busto "Cético/Crítico".
- **Missão:** 5. Afinidade: +5 por ouvir com respeito, −5 por zombar, +15 ao vencer o debate,
  +5 ao aceitar o convite e +2 a cada conversa no salão.

## Louis, o menino 🟪 — `crianca`
- **Papel:** filho de uma lavadeira; mostra que a caridade começa perto de nós.
- **Onde:** praça, nó `Louis` em (650, 805), perto da fonte. Diálogo: `louis`.
- **Sprite:** gerado pelo Codex, com altura de 64 px (`target_height` em `extract_sheet.py`) e `talk`.
- **Missão:** inicia e conclui a 4 (+5 de afinidade ao aceitar ajuda, +20 na entrega). Gancho futuro:
  quer aprender a ler (`louis_quer_ler`).

## Monsieur Bertin, o tipógrafo 🟪 — `impressor`
- **Onde:** `tipografia`, nó `Bertin` em (464, 280). Diálogo: `bertin`.
- **Sprite:** gerado pelo Codex a partir do busto "Operário", com `talk`.
- **Missão:** 6 (`falar_bertin` dá +10 de afinidade; `imprimir`, pela prensa, dá mais +10).

## Bertrand, o cocheiro 🟪 — `cocheiro`
- **Papel:** leva o jogador de fiacre para outros destinos (abre o mapa de viagem).
- **Onde:** praça, nó `Cocheiro` em (300, 632), ao lado da carruagem. Diálogo: `cocheiro`.
- **Sprite:** gerado pelo Codex a partir do busto "Jornalista" (cartola), com `talk`.

---

## Decisões editoriais
- Personagens históricos (Kardec, Amélie) só dizem coisas compatíveis com fatos documentados ou com
  a doutrina. Suas falas são paráfrases do jogo, não citações.
- Pessoas vivas não são retratadas. Chico Xavier, Divaldo Franco e Haroldo Dutra Dias, citados no
  documento do mod, ficam fora do jogo ou para capítulos futuros (veja `docs/NARRATIVA.md`).
- Jesus não aparece como NPC.

---

## Irmã Clara (`espirito_guia`): ficção
Espírito benevolente fictício que recebe Étienne no Jardim da Reflexão, no plano espiritual.
Ela não representa nenhuma pessoa real nem figura religiosa. O sprite e o retrato foram gerados
com o Codex no estilo do jogo. Detalhes em [PLANO_ESPIRITUAL.md](PLANO_ESPIRITUAL.md).

# Missões

Os arquivos ficam em `data/quests/<id>.json`, no formato descrito em `docs/DADOS.md`. As missões com
`"sequential": true` só deixam concluir o objetivo atual. A expansão acrescentou o campo informativo
`"chapter"`.

## Encadeamento

```
Capítulo 1 — Paris, 1857: o início dos estudos
  [1] conhecendo_sociedade  (principal, inicia com o jogo)
        ├─> [2] perguntas_e_respostas  (principal)  ──> Capítulo 2
        ├─> [3] cartas_do_professor    (secundária)
        └─> [5] o_cetico               (secundária)
  [4] pao_para_louis  (secundária, sem requisito)
Capítulo 2 — A Codificação
  [6] revista_espirita  (principal; requer a 2)  -> anuncia a fundação da Sociedade (abril de 1858)
```

---

## 1. conhecendo_sociedade — Conhecendo a Sociedade Espírita (MVP)
- **Inicia:** automaticamente no novo jogo (`GameManager.START_QUEST`).
- **Objetivos (sequenciais):**
  1. `explorar_praca`: gatilho da praça ou examinar a fonte.
  2. `conversar_kardec`: escolher "Por onde começo?".
  3. `visitar_livraria`: gatilho de entrada da livraria.
  4. `encontrar_livro`: estante ao lado da janela; dá `livro_dos_espiritos`.
  5. `retornar_sociedade`: entregar o livro a Kardec.
- **Recompensas:** `carta_recomendacao` e a flag `apresentado_ao_grupo`.
- **Efeito da expansão:** ao concluir esta missão, a residência abre e Kardec passa a oferecer a missão 2.

## 2. perguntas_e_respostas — Perguntas e Respostas
- **Requisito:** missão 1 concluída.
- **Inicia:** Kardec na praça (variante `convite_estudo`), que também ativa a flag `sociedade_aberta`.
  Desbloqueia `allan_kardec` e `espiritismo`, e dá +5 de afinidade com Kardec.
- **Objetivos:**
  1. `entrar_salao`: `gatilho_salao`. Desbloqueia `sede_no_jogo`.
  2. `conversar_aline`: diálogo `aline`. Dá +10 de afinidade com Aline e desbloqueia `medium`,
     `psicografia` e `irmas_baudin`.
  3. `questionario`: `mesa_estudos` abre o quiz `questionario_le` (é preciso acertar 4 de 6). Dá +10 de
     Estudo e desbloqueia `deus`, `escala_espirita` e `perispirito`.
  4. `falar_kardec_salao`: diálogo `kardec_salao`. Dá +10 de afinidade com Kardec, +5 de Estudo e
     desbloqueia `estudo_em_grupo` e `allan_kardec`.
- **Recompensas:** `caderno_estudos` (pode ser lido) e a flag `capitulo1_concluido`.
- **Extra no salão:** o quadro-negro (`linha_do_tempo`) dá +8 de Estudo e 6 entradas da enciclopédia.

## 3. cartas_do_professor — As Cartas do Professor
- **Requisito:** missão 1 concluída.
- **Inicia:** Amélie, na residência ("Posso organizá-las..."). Dá +3 de Caridade.
- **Objetivos:**
  1. `organizar_cartas`: a cômoda abre o minigame `cartas_kardec` (ordenar 5 cartas fictícias de 1857).
     Dá +3 de Estudo e abre a leitura de `carta_de_lyon`.
  2. `voltar_amelie`: dá +15 de afinidade com Amélie e +5 de Fraternidade. Desbloqueia `residencia_kardec` e
     `revista_espirita`.
- **Recompensa:** `pena_presente`.

## 4. pao_para_louis — Pão para Louis
- **Requisito:** nenhum. A missão não é sequencial.
- **Inicia:** Louis ("Vou conseguir ajuda para você"). Dá +5 de afinidade e +3 de Caridade.
- **Objetivos:**
  - `pedir_pao`: Madame Marguerite dá o item `pao`.
  - `pedir_agasalho`: Monsieur Gérard dá o item `agasalho`. Essa variante não aparece enquanto o objetivo
    `encontrar_livro` da missão 1 estiver ativo.
  - `entregar_louis`: exige os dois itens, que são consumidos. Dá +15 de Caridade, +20 de afinidade
    com Louis e desbloqueia `caridade` e `louis`.
- **Recompensa:** a flag `louis_ajudado`. Gancho: se a missão 3 estiver concluída, Louis pede para
  aprender a ler (flag `louis_quer_ler`), e Amélie aceita ensiná-lo (flag `amelie_ensina_louis`).

## 5. o_cetico — O Cético
- **Requisito:** missão 1 concluída.
- **Inicia:** o Doutor Lefèvre na praça, com uma escolha moral:
  - "Ouvir com respeito": inicia a missão, dá +5 de Fraternidade e +5 de afinidade.
  - "Zombar dele": dá −5 de afinidade e não inicia a missão. Dá para tentar de novo depois.
- **Objetivos:**
  1. `debater`: quiz `debate_cetico` (é preciso acertar 3 de 4). Dá +5 de Estudo, +10 de Fraternidade,
     +15 de afinidade e desbloqueia `doutor_lefevre` e `escala_espirita`.
  2. `convidar`: dá +5 de afinidade e desbloqueia `controle_universal`.
- **Recompensa:** a flag `lefevre_observador`. O doutor sai da praça e aparece no salão (veja `present_when`).

## 6. revista_espirita — A Revista Espírita (Capítulo 2)
- **Requisito:** missão 2 concluída.
- **Inicia:** Kardec na praça (`revista_convite`): faz um salto de tempo para dezembro de 1857
  (flag `data_atual`), dá `provas_revista` e libera a tipografia no mapa de viagem
  (flag `tipografia_conhecida`).
- **Objetivos:**
  1. `ir_tipografia`: viagem de fiacre com o cocheiro; conclui no `gatilho_tipografia`.
  2. `falar_bertin`: consome `provas_revista` e dá +10 de afinidade.
  3. `imprimir`: a prensa abre o minigame `imprensa_etapas`. Dá `revista_espirita_1`, muda `data_atual` para
     "Janeiro de 1858", dá +5 de Estudo, +10 de afinidade e desbloqueia `prensa_manual`.
  4. `entregar_kardec`: dá +10 de afinidade e +10 de Estudo. Desbloqueia `revista_espirita` e `sociedade_parisiense`.
     Kardec anuncia a fundação da Sociedade em abril de 1858 ("outro capítulo").
- **Recompensa:** a flag `capitulo2_revista`.

## Como criar uma missão
1. Crie `data/quests/<id>.json` com os campos `id`, `name`, `description`, `sequential`, `requirements`,
   `objectives` e `rewards` (e, se quiser, `chapter`).
2. Inicie a missão com a ação `{"type": "start_quest", "quest": "<id>"}` em um diálogo.
3. Conclua os objetivos com `complete_objective` em diálogos, gatilhos ou no `on_success` de minigames.
4. Use as condições `objective_current` e `quest_status` nas variantes dos NPCs.
5. Acrescente as verificações em `tests/expansion_test.gd` ou crie um teste novo.

---

## 7. Jardim da Reflexão (`jardim_da_reflexao`): epílogo do capítulo 2

- **Requisito:** `revista_espirita` concluída.
- **Início:** Mademoiselle Aline, no salão da Sociedade, convida para uma prece em silêncio.
- **Fluxo:** chegar ao jardim (plano espiritual) → conversar com a Irmã Clara (guia fictícia) →
  refletir na fonte (imortalidade), na árvore (reencarnação e progresso) e no pórtico (caridade),
  em qualquer ordem → despedir-se e voltar ao salão.
- **Recompensas:** flag `capitulo2_epilogo`, virtudes, afinidade e entradas da enciclopédia.
- **Detalhes completos:** [PLANO_ESPIRITUAL.md](PLANO_ESPIRITUAL.md).

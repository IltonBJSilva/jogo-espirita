# Backlog de desenvolvimento

Última atualização: 2026-11-14. Prioridade: **P1** (próximo), **P2** e **P3**.

## Concluído
- [x] **MVP:**
  - título, praça de Paris 1857, livraria, jogador, colisões e câmera
  - 4 NPCs, interação, diálogos, missão 1, minigame organizar_livros
  - HUD, pausa, diário e inventário
- [x] **Animações do jogador** (Codex): caminhada nas 4 direções, corrida e respiração com piscada.
- [x] **Profundidade:** objetos de Paris com Y-Sort pela base e transparência quando o jogador está atrás.
- [x] **Sprites corrigidos:** perfil espelhado e sapatos dos arquétipos; pés e restos de sombra do Kardec.
- [x] **Expansão dos capítulos 1 e 2:**
  - 6 NPCs gerados pelo Codex e 3 interiores
  - 5 missões e 26 diálogos novos
  - enciclopédia (44 entradas), biblioteca e leitor, afinidade, virtudes
  - salvar/continuar, viagem de fiacre e Compêndio
  - minigames genéricos (quiz e ordenar), ícones de itens e calendário
- [x] **Testes automatizados:** `tests/smoke_test.tscn` e `tests/expansion_test.tscn`.
- [x] **Plano espiritual:** veja `docs/PLANO_ESPIRITUAL.md` (outro agente).

## P1 — próximos passos
- [ ] **Animações completas (Codex) para livreiro, estudioso, moradora e Kardec.** Hoje a caminhada de frente e
      de costas deles é só "bob" e não há `talk` (exceto no Kardec). Use o prompt-modelo de `docs/SPRITES.md`,
      acrescente os ids a `SHEETS` em `tools/extract_sheet.py` e **preserve** os PNGs atuais (gere com
      nomes novos ou só depois de aprovar).
- [ ] **Arco de Louis:** aprender a ler com Amélie. As flags `louis_quer_ler` e `amelie_ensina_louis` já existem;
      falta uma missão curta e uma cena de aula na residência.
- [ ] **Capítulo 2 completo:** fundação da Sociedade Parisiense (abril de 1858), com uma sessão e as regras
      (o programa já existe como documento).
- [ ] **Ícones próprios** para o pão e o casaco de lã (hoje usam bilhete e documento).

## P2 — sistemas
- [ ] Rotinas de NPCs por horário. Hoje existe a presença condicional `present_when`; falta a hora do dia.
- [ ] Ciclo dia/noite e clima (manhã, tarde, noite e chuva no Guia Visual). Pode ser um CanvasModulate por
      mapa, ligado a `data_atual` e a uma hora.
- [ ] Áudio: **não há nenhum som ou música ainda**. Faltam trilha de piano/cordas de época, passos, portas,
      páginas, prensa e ambiente da praça. É preciso criar a pasta `assets/audio/` e um AudioManager.
- [ ] Fonte pixel para a interface (hoje é a SystemFont serifada Georgia).
- [ ] Conquistas e colecionáveis (há a categoria "Conquista" nos ícones do Pacote Visual).
- [ ] Glossário espírita separado da enciclopédia, ou uma categoria "Glossário".
- [ ] Linha do tempo interativa no Compêndio (os dados já estão no minigame `linha_do_tempo`).
- [ ] Opções e configurações na tela de título (volume e controles).

## P2 — minigames restantes (escopo, seção 9)
- [ ] Investigação histórica: comparar fontes e organizar pistas. Pode reaproveitar o ordenar e o quiz.
- [ ] Escrita de manuscritos: ordenar trechos de um texto para publicação.
- [ ] Classificação de objetos: identificar a origem de documentos e objetos.

## P3 — capítulos e localidades
- [ ] Capítulos 3 a 6 (veja `docs/NARRATIVA.md`).
- [ ] Novas localidades das referências:
  - Ruas de Paris, Universidade (já pré-listada no mapa de viagem), Cemitério do Père-Lachaise (pré-listado)
  - Vila francesa, Campo/Fazenda, Floresta, Estação ferroviária, Porto, Museu, Château
  - Londres, Genebra, Rio de Janeiro (arco brasileiro, futuro)
- [ ] Interiores restantes do Guia Visual: Biblioteca, Quarto, Sala da universidade e Imprensa ampliada.
- [ ] Personagens históricos sugeridos: Flammarion, Léon Denis, Gustave Doré, George Sand (apenas com fatos documentados).

## Técnico
- [ ] Exportar um `.exe` Windows: é preciso baixar os **export templates** do Godot 4.7 e incluir `*.json`
      nos filtros de exportação.
- [ ] Revisar avisos do console no fechamento headless (vazamentos de RID do próprio motor em modo `--script`).
- [ ] Commit inicial do projeto (o usuário pediu para não commitar automaticamente).

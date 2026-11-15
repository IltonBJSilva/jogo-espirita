# Planejamento narrativo

**Premissa:** Étienne, um jovem estudante de Lyon, chega a Paris em 1857, ano em que *O Livro dos
Espíritos* é publicado. Ao conviver com Allan Kardec, Amélie Boudet e os moradores do bairro, ele
aprende a estudar com método, a dialogar com respeito e a praticar a caridade.

O jogo é um RPG narrativo e educativo: **não há combate**. O progresso é moral e intelectual.

## Capítulos
A estrutura segue o "Guia Visual Completo" do usuário (`assets/references/guia_visual_completo.png`).

| Cap. | Título | Estado | Conteúdo |
|---|---|---|---|
| 1 | Paris, 1857 — O Início dos Estudos | **implementado** | missões 1–5 (veja `docs/MISSOES.md`) |
| 2 | A Codificação | **iniciado** | missão 6 (Revista Espírita, jan. 1858); anúncio da Sociedade (abr. 1858) |
| 3 | Expansão — Viagens e Correspondências | proposto | cartas de leitores pela Europa, viagens (Lyon, Bordeaux), Livro dos Médiuns (1861) |
| 4 | Desafios — Críticas e Debates | proposto | auto de fé de Barcelona (1861), debates na imprensa, o Doutor Lefèvre mais presente |
| 5 | Consolidação — O Espiritismo se difunde | proposto | Evangelho segundo o Espiritismo (1864), O Céu e o Inferno (1865), A Gênese (1868) |
| 6 | Legado — A Imortalidade da Alma | proposto | 1869: desencarne de Kardec; Amélie continua a obra; memória no Père-Lachaise |

O plano espiritual (visão de reflexão) é tratado em `docs/PLANO_ESPIRITUAL.md`.

## Linha do tempo histórica usada

| Data | Fato | Onde aparece no jogo |
|---|---|---|
| 1804 | Nascimento de H. L. D. Rivail em Lyon | diálogo de Kardec |
| c. 1815 | Estudos com Pestalozzi em Yverdon | Amélie, estante, enciclopédia |
| 1832 | Casamento com Amélie Boudet | Amélie |
| mar. 1848 | Irmãs Fox, Hydesville | jornal, linha do tempo |
| c. 1853 | Mesas girantes na Europa; Haussmann prefeito do Sena | jornal, cocheiro, cartaz |
| 1853–1855 | Victor Hugo e as mesas de Jersey | jornal |
| 1855 | Rivail vê as mesas girantes | Kardec, linha do tempo |
| 1855–1856 | Irmãs Baudin colaboram como médiuns | Aline, enciclopédia |
| 18/04/1857 | *O Livro dos Espíritos* (501 perguntas; editor Dentu) | missão 1, quiz |
| 1857 | *Madame Bovary* e *As Flores do Mal* | livraria |
| 01/01/1858 | Primeiro número da *Revista Espírita* | missão 6 |
| 01/04/1858 | Fundação da Sociedade Parisiense de Estudos Espíritas | missão 6, linha do tempo |
| 1860 | 2ª edição de O Livro dos Espíritos (1.019 perguntas) | quiz, enciclopédia |
| 1861 | *O Livro dos Médiuns* | linha do tempo |
| 1864–1868 | Evangelho, Céu e Inferno, Gênese | enciclopédia (obras básicas) |
| 31/03/1869 | Desencarne de Kardec | enciclopédia |

## Cuidados editoriais (seção 17 do escopo)
1. **Toda entrada da enciclopédia tem um `kind`** (`fato_historico`, `conceito_doutrinario` ou `ficcao`)
   e uma fonte.
2. **Não há citações inventadas de figuras reais.** As falas de Kardec e Amélie são paráfrases do jogo,
   coerentes com fatos e com a doutrina. As únicas citações literais são:
   - *O Livro dos Espíritos*, q. 1: "Deus é a inteligência suprema, causa primária de todas as coisas."
   - *O Livro dos Espíritos*, q. 886 (sobre a caridade): "Benevolência para com todos, indulgência para
     as imperfeições dos outros, perdão das ofensas."
   - O epitáfio associado a Kardec: "Nascer, morrer, renascer ainda e progredir sempre, tal é a lei."

   A numeração indicada é a da edição definitiva (1860).
3. **Documentos fictícios** (jornal do bairro, cartas, programa da sessão, caderno) dizem que são fictícios
   no autor ou na fonte. Quando citam fatos, os fatos são reais.
4. **Licença artística declarada:** o prédio "Sociedade Espírita de Paris" já existe em 1857 no jogo. A
   entrada `sede_no_jogo` explica que a fundação real foi em abril de 1858.
5. O resumo da Revista nº 1 avisa que **não é transcrição** do original.

## Uso do repositório do mod (adaptado, sem Minecraft)
O documento "Documentação inicial Mod Espiritismo Minecraft" serviu só como fonte de **conceitos**.
Tudo o que é de Minecraft foi ignorado: blocos, mobs, crafting, dimensões como mecânica, portais e skins.

| Conceito do mod | Adaptação no RPG 2D |
|---|---|
| Classes Médium / Doutrinador / Trabalhador Espiritual | Viraram papéis de NPCs: Aline (médium), Delaunay e Kardec (estudo e orientação). As ações de caridade do jogador seguem a ideia do "Trabalhador". Não há classes jogáveis nem habilidades de poder. |
| Barra de moralidade / bondade, ordens | Progresso moral **não competitivo**: virtudes Caridade, Estudo e Fraternidade, com etapas de título. Não há punição nem bloqueio. |
| Escala espírita (puros, bons, imperfeitos) | Conteúdo educativo: enciclopédia, quiz e debate com o cético |
| Provas morais e escolhas | Escolha com Lefèvre (ouvir ou zombar); ajudar Louis |
| Doutrinação / evangelização | Diálogo respeitoso e debate com argumentos (quiz `debate_cetico`) |
| Mesa mediúnica, psicografia | Explicadas por Aline; sessão de estudos no salão (sem "poderes") |
| Centro Espírita como base | Salão da Sociedade como espaço de estudo |
| Umbral, colônias, Nosso Lar, água fluidificada | Para capítulos futuros e para o plano espiritual de reflexão, sempre com sensibilidade (ver `PLANO_ESPIRITUAL.md`). Não há combate contra espíritos. |
| Espíritos perturbadores e encarnados perturbadores | Futuro: dilemas morais por diálogo, nunca por combate |

## Decisões sobre figuras reais
- **Pessoas vivas não são retratadas** (por exemplo, Haroldo Dutra Dias, citado no documento do mod).
- **Jesus não aparece como NPC**, por respeito. Os ensinamentos do Evangelho podem aparecer como texto
  citado em capítulos futuros (1864).
- **Chico Xavier, Divaldo Franco e a colônia "Nosso Lar" (André Luiz)** pertencem ao Espiritismo no Brasil
  do século XX. Ficam para um eventual arco ambientado no Brasil (há "Rio de Janeiro" no Pacote Visual),
  respeitando a cronologia.
- **Personagens históricos de 1857–1869** que podem entrar depois: Camille Flammarion (conheceu Kardec em
  1861), Léon Denis, Victor Hugo (como referência), Gustave Doré e George Sand (sugestões do guia visual).
  Eles devem aparecer apenas com fatos documentados.

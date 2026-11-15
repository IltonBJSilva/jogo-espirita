# Mapas

Todo mapa tem a raiz `GameMap` (`scripts/maps/game_map.gd`) e a estrutura abaixo:

```
<Mapa> (GameMap: map_id, display_name, map_size)
  Tiles        <- instancia scenes/maps/<id>/<id>_tiles.tscn (GERADO)
                  Ground, Environment, Decoration, Collision (visível só no editor)
  Interactive  (Node2D, y_sort_enabled)
                  Foreground (só em Paris: <id>_foreground.tscn, GERADO, Y-Sort por objeto)
                  NPCs, Interactables (Area2D + interactable.gd), TriggerZones
  Spawns       SpawnPoint (Marker2D + spawn_point.gd; o nome do nó é o id do spawn)
```

- As bordas do mapa recebem paredes invisíveis automaticamente (`GameMap._add_map_edges`).
- Os tiles têm 32 px. Os interiores medem 30x17 tiles (960x544 px).
- **Construção:** um script Python gera o atlas e `data/maps/<id>_layout.json` (células sólidas e
  camadas). Depois, `scripts/tools/build_world.gd` gera o TileSet, `<id>_tiles.tscn` e, quando há
  foreground, `<id>_foreground.tscn`. A cena `<id>.tscn` é escrita à mão e nunca é sobrescrita.

---

## paris_1857 — Praça de Paris (exterior, 1536x1024)
- **Propósito:** hub da história, onde ficam a Sociedade, a livraria, a residência de Kardec,
  a fonte, os bancos, os lampiões, o canal e o fiacre.
- **Arte:** `tools/build_paris_assets.py`, feita a partir da referência do usuário. O script remove o
  Kardec desenhado na praça e a faixa de título.
- **Profundidade:** `DEPTH_OBJECTS` em `build_paris_assets.py` define 7 árvores e 4 lampiões, cada
  um com retângulo e base (`base_y`). Cada tile do Foreground recebe `y_sort_origin` igual à base do
  seu objeto. Com isso:
  - o jogador fica atrás da árvore ou do lampião quando está acima da base e na frente quando está abaixo;
  - quando ele está escondido, a camada fica semitransparente (`scripts/maps/foreground_layer.gd`).
- **NPCs:** Kardec (795,452), Estudioso (1000,572), Moradora (372,690), Cocheiro (300,632),
  Louis (650,805) e Lefevre (520,625; presente até concluir `o_cetico`).
- **Objetos interativos (nó → diálogo):**

| Nó | Diálogo | Observação |
|---|---|---|
| PortaLivraria | `porta_livraria` | entra na livraria |
| VitrineLivraria | `vitrine_livraria` | |
| PortaSociedade | `porta_sociedade` | entra no salão com a flag `sociedade_aberta` |
| PortaResidencia | `porta_residencia` | entra na residência depois da missão 1 |
| Fonte | `fonte` | conclui `explorar_praca` |
| Carruagem | `carruagem` | |
| Lampiao | `lampiao` | |
| Banco | `banco` | |
| Canal | `canal` | |
| JornalBanco | `jornal_banco` | lê `gazeta_mesas` |
| CartazObras | `cartaz_obras` | lê `cartaz_obras` |
| GatilhoPraca (TriggerZone) | `gatilho_praca` | |

- **Spawns:** `inicio`, `porta_livraria`, `porta_residencia` (1392,645), `porta_sociedade` (795,380),
  `fiacre` (360,650).

## livraria — Livraria de Monsieur Gérard (interior)
- **Arte:** `tools/build_livraria_assets.py`.
- **NPC:** Livreiro (790,214).
- **Objetos:** Saida → `porta_saida_livraria`, EstanteRomances, EstanteEnciclopedia (minigame
  `organizar_livros`), Janela, EstanteJanela (o livro da missão 1), EstantePedagogia, MesaLeitura.
  Gatilho de entrada: `gatilho_livraria`.
- **Spawn:** `entrada`.

## residencia_kardec — Residência de Allan Kardec (interior, expansão)
- **Arte:** `tools/build_interiors.py residencia_kardec`. Tem parquete, papel de parede verde, estante,
  lareira com retrato, escrivaninha com tinteiro e pena, poltronas, tapete, globo e janela.
- **Acesso:** pela PortaResidencia, depois de concluir `conhecendo_sociedade`.
- **NPC:** Amelie (496,380).
- **Objetos:**

| Nó | Diálogo | Observação |
|---|---|---|
| Comoda | `comoda_cartas` | minigame `cartas_kardec` |
| Escrivaninha | `escrivaninha_kardec` | |
| Estante | `estante_residencia` | |
| Lareira | `lareira` | |
| Globo | `globo` | |
| Saida | `porta_saida_residencia` | volta à praça |

- **Spawn:** `entrada` (480,470).

## sociedade_salao — Salão da Sociedade (interior, expansão)
- **Arte:** `tools/build_interiors.py sociedade_salao`. Tem papel de parede vinho listrado, estandarte
  com a pomba, quadro-negro, mesa de estudos de feltro verde, púlpito, fileiras de cadeiras e janelas.
- **Acesso:** pela PortaSociedade, quando a flag `sociedade_aberta` está ativa (o convite de Kardec
  no início da missão 2).
- **NPCs:** KardecSalao (480,205), Aline (176,215) e LefevreSalao (832,316; só depois de `o_cetico`).
- **Objetos:**

| Nó | Diálogo | Observação |
|---|---|---|
| MesaEstudos | `mesa_estudos` | quiz `questionario_le` |
| Quadro | `quadro_linha_tempo` | minigame `linha_do_tempo` |
| Programa | `programa_sessao_obj` | lê `programa_sessao` |
| Saida | `porta_saida_salao` | |
| GatilhoEntrada | `gatilho_salao` | conclui `entrar_salao` |

## tipografia — Tipografia de M. Bertin (interior, expansão)
- **Arte:** `tools/build_interiors.py tipografia`. Tem parede de tijolos, caixas de tipos, varal de folhas,
  prensa manual de ferro, mesa de composição, pilhas de papel e barris de tinta.
- **Acesso:** só de fiacre (o cocheiro Bertrand abre o mapa de viagem). O destino é liberado pela flag
  `tipografia_conhecida`.
- **NPC:** Bertin (464,280).
- **Objetos:**

| Nó | Diálogo | Observação |
|---|---|---|
| Prensa | `prensa` | minigame `imprensa_etapas` |
| CartazOficina | `cartaz_tipografo` | lê `manual_tipografo` |
| Varal | `varal_folhas` | |
| Saida | `porta_saida_tipografia` | narração e depois volta de fiacre ao spawn `fiacre` da praça |
| GatilhoEntrada | `gatilho_tipografia` | |

---

## Mapa de localidades (viagem)
O mapa em pergaminho fica em `assets/ui/mapa_paris.png` (gerado por `tools/build_ui_assets.py`). Os
destinos ficam em `data/travel.json` (veja `docs/MECANICAS.md`).

## Plano espiritual
Veja [docs/PLANO_ESPIRITUAL.md](PLANO_ESPIRITUAL.md).

## Como adicionar um interior novo
1. Escreva uma função em `tools/build_interiors.py` (ou em um script novo) e registre-a em `BUILDERS`.
2. Acrescente o mapa a `MAPS` em `scripts/tools/build_world.gd` e rode o construtor.
3. Crie `scenes/maps/<id>/<id>.tscn` instanciando `<id>_tiles.tscn`, com `Interactive` (Y-Sort) e `Spawns`.
4. Crie as portas, com diálogos que usam a ação `change_map`.

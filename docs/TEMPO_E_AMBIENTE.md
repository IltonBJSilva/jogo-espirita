# Tempo, calendário e dia/noite

Contrato geral: [VIDA_CONTRATOS.md](VIDA_CONTRATOS.md) (seções 1, 2, 6 e 8).

## TimeManager (autoload) — `scripts/world/time_manager.gd`

O relógio global guarda o tempo como **minutos inteiros desde 01/01/`base_year` 00:00**.

- **Quando corre:** só com `GameManager.state == PLAYING` e `running == true`. Fica parado em
  diálogos, menus, minigames, transições e na tela de título.
- **Velocidade:** `time_scale` minutos de jogo por segundo real. O padrão é 1.0, então um dia
  dura 24 minutos reais; ajuste em `calendar.json`.
- **Novo jogo:** volta à data inicial (`GameManager.new_game_started`).
- **Salvar:** `save_data()` e `load_data()` (registrado no `SaveManager` como `"time"`).
- **Sincronia com a história:** a flag `data_atual` (ex.: `"Dezembro de 1857"`) faz o calendário
  saltar para o dia 1 desse mês, às 09:00. Isso só acontece se a data estiver no futuro; o
  calendário nunca volta no tempo.

### API

```gdscript
signal minute_changed(total_minutes: int)
signal hour_changed(hour: int)
signal phase_changed(phase: String)
signal day_changed(date: Dictionary)
signal week_changed(week_index: int)          # emitido à meia-noite de segunda-feira
signal month_changed(month: int, year: int)
signal year_changed(year: int)
signal time_jumped(total_minutes: int)

const PHASES := ["madrugada", "amanhecer", "manha", "meio_dia", "tarde", "por_do_sol", "noite"]
var time_scale: float
var running: bool

get_total_minutes(), get_hour(), get_minute(), get_minute_of_day()
get_date() -> {year, month, day, weekday (0=segunda), weekday_name, month_name, day_of_year}
get_phase(), is_night(), get_time_string() ("14:05"), get_date_string() ("Terça-feira, 5 de maio de 1857")
set_datetime(year, month, day, hour, minute)   # salto: emite time_jumped
advance_minutes(minutes)                       # emite os sinais cruzados, em ordem
weekday_of(year, month, day) -> int            # extra
total_for(year, month, day, hour, minute) -> int   # extra: minutos totais de uma data
static parse_hhmm("06:30") -> 390
```

### Regras dos sinais em avanços e saltos

| situação | sinais emitidos |
|---|---|
| até 60 minutos | `minute_changed` para cada minuto, mais hora, fase, dia, semana, mês e ano quando cruzados |
| mais de 60 minutos | `minute_changed` só do minuto final, mais `time_jumped`; hora e fase do estado final; um `day_changed` por dia cruzado (até 31 dias; acima disso, só o final); `week_changed`, `month_changed` e `year_changed` quando cruzados |
| salto para trás (`set_datetime`, `load_data`) | só o estado final do que mudou, mais `time_jumped` |

### Calendário: `data/world/calendar.json`

- `base_year` e `base_weekday` (dia da semana de 1º de janeiro do ano-base; 0 = segunda).
  1º/01/1850 foi uma terça-feira, então `base_weekday` vale 1. O calendário é gregoriano real.
- `months`: 12 meses com nome e número de dias. `leap_month` e `gregorian_leap` definem o ano
  bissexto. Para um calendário fictício, basta trocar os meses e desligar o bissexto.
- `weekdays`: nomes em português.
- `start`: a data inicial, 04/05/1857 (segunda-feira), às 09:00.
- `phases`: o início de cada fase (cada uma vai até o início da seguinte): madrugada 00:00,
  amanhecer 05:00, manhã 07:00, meio-dia 11:30, tarde 13:30, pôr do sol 17:30, noite 19:30.
- `time_scale`.

## EnvironmentManager (autoload) — `scripts/world/environment_manager.gd`

- No mapa atual, ele cria um `CanvasModulate` (nó `DayNight`) e um nó `EnvLights` com
  `PointLight2D`. A textura é um gradiente radial gerado em código; não há assets novos.
- **Atualização:** a cada `minute_changed` ou `time_jumped` e na troca de mapa. Nada roda por
  frame. As cores são interpoladas entre keyframes com *smoothstep*, então as transições são
  graduais (menos de 3% de diferença por minuto).
- **HUD:** não é afetado, porque é um CanvasLayer.
- **API:** `get_light_color()`, `get_night_factor()` (0 = dia, 1 = noite plena) e `refresh()`.

### `data/world/lighting.json`

- `profiles`:
  - `outdoor`: ciclo completo. Amanhecer quente, meio-dia neutro (branco), pôr do sol alaranjado
    e noite azul-arroxeada (cor mínima de cerca de 0.52/0.53/0.75, legível).
  - `indoor`: variação leve, um pouco mais escura e mais quente à noite.
  - `none`: sem alteração.
  - Cada perfil tem `colors` (keyframes `[hora, [r,g,b]]`) e `lights_curve` (`[hora, fator]`).
- `light_types`: `lamp` (lampião), `window` (janela) e `candle` (vela/lareira), cada um com cor,
  energia e escala.
- `maps`: o perfil e as luzes de cada mapa.
  - `paris_1857` (outdoor): os 4 lampiões e cerca de 25 janelas iluminadas dos prédios.
  - Interiores (indoor): as velas e lareiras.
  - `plano_espiritual`: `none`.
  - Mapas sem entrada usam `default_profile` (indoor).
- As luzes acendem gradualmente entre 17:45 e 19:15 e apagam entre 05:30 e 06:45. Nos interiores,
  as velas ficam a 35% durante o dia.

## Relógio do HUD

Arquivos: `scenes/ui/clock_widget.tscn`, `scripts/ui/clock_widget.gd` e `scripts/ui/clock_icon.gd`.

- É um painel no canto inferior direito (CanvasLayer 11), no estilo do tema. Mostra a hora
  (dourada), o dia da semana, a data ("4 de maio de 1857") e um ícone em pixel art desenhado em
  código: sol, sol no horizonte (amanhecer e pôr do sol) ou lua com estrelas.
- Atualiza a cada `minute_changed` e `time_jumped`.
- Fica oculto em minigames, como o HUD. Não se sobrepõe ao HUD existente.

## Testes

- `tests/time_test.tscn` (headless): 42 verificações.
  - Calendário real: 04/05/1857 segunda, 18/04/1857 sábado, 01/01/1858 sexta; 1856 bissexto e
    1857 não.
  - Sinais e viradas de dia, semana, mês e ano.
  - Fases do dia e salto grande.
  - Sincronia com `data_atual`.
  - Pausa fora de PLAYING e com `running = false`.
  - Cores do dia e da noite, luzes, transição gradual e interior.
  - Relógio do HUD, salvar/carregar e novo jogo.
- `tests/time_shots.tscn` (com janela): `--resolution 960x540 res://tests/time_shots.tscn -- <pasta>`
  captura a praça às 06:00, 12:00, 18:30 e 22:00 e a residência às 12:00 e 22:00.

## Pendências e ideias

- Os sprites dos prédios já têm janelas acesas na arte base, então de dia elas continuam com
  aparência iluminada. Seria preciso uma variante "janelas apagadas" do atlas (asset).
- Clima (chuva, neblina) ainda não está implementado. O `EnvironmentManager` pode receber um
  segundo multiplicador de cor e partículas.
- Uma sombra que acompanhe a posição do sol (os personagens já têm sombra própria) é opcional.

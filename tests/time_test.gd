extends "res://tests/smoke_test.gd"
## Teste do tempo, calendário, dia/noite e relógio do HUD.
##   godot --headless --path . res://tests/time_test.tscn

var _counts := {}
var _last := {}


func _run() -> void:
	print("== Teste do tempo e ambiente ==")
	_detach()
	await GameManager.new_game()
	await _frames(5)
	TimeManager.running = false
	for sig in ["minute_changed", "hour_changed", "phase_changed", "day_changed", "week_changed",
			"year_changed", "time_jumped"]:
		TimeManager.connect(sig, func(x): _rec(sig, [x]))
	TimeManager.month_changed.connect(func(m, y): _rec("month_changed", [m, y]))

	# --- Data inicial e calendário real ---------------------------------------------
	var d := TimeManager.get_date()
	_check(d["year"] == 1857 and d["month"] == 5 and d["day"] == 4, "data inicial 4/5/1857")
	_check(d["weekday"] == 0 and d["weekday_name"] == "Segunda-feira", "4/5/1857 é segunda-feira")
	_check(TimeManager.get_time_string() == "09:00", "começa às 09:00")
	_check(TimeManager.weekday_of(1857, 4, 18) == 5, "18/04/1857 foi um sábado")
	_check(TimeManager.weekday_of(1858, 1, 1) == 4, "01/01/1858 foi uma sexta-feira")
	_check(TimeManager.total_for(1856, 3, 1) - TimeManager.total_for(1856, 2, 28) == 2 * 1440, "1856 é bissexto (29/02)")
	_check(TimeManager.total_for(1857, 3, 1) - TimeManager.total_for(1857, 2, 28) == 1440, "1857 não é bissexto")
	_check(TimeManager.get_date_string() == "Segunda-feira, 4 de maio de 1857", "texto da data")
	_check(TimeManager.parse_hhmm("06:30") == 390, "parse_hhmm")

	# --- Minutos e horas ------------------------------------------------------------
	TimeManager.set_datetime(1857, 5, 4, 10, 0)
	_reset_counts()
	TimeManager.advance_minutes(60)
	_check(_counts.get("minute_changed", 0) == 60, "60 sinais de minuto")
	_check(_counts.get("hour_changed", 0) == 1 and _last["hour_changed"][0] == 11, "hour_changed(11)")
	_check(TimeManager.get_time_string() == "11:00", "11:00 após 60 min")

	# --- Fases ------------------------------------------------------------------------
	var phases := {"03:00": "madrugada", "06:00": "amanhecer", "09:00": "manha", "12:00": "meio_dia",
			"15:00": "tarde", "18:30": "por_do_sol", "22:00": "noite"}
	for t in phases:
		var m := TimeManager.parse_hhmm(t)
		TimeManager.set_datetime(1857, 5, 5, m / 60, m % 60)
		_check(TimeManager.get_phase() == phases[t], "%s = %s" % [t, phases[t]])
	_check(TimeManager.is_night(), "22:00 é noite")
	TimeManager.set_datetime(1857, 5, 5, 11, 29)
	_reset_counts()
	TimeManager.advance_minutes(1)
	_check(_counts.get("phase_changed", 0) == 1 and _last["phase_changed"][0] == "meio_dia", "phase_changed ao meio-dia")

	# --- Virada de dia, semana, mês e ano -------------------------------------------------
	TimeManager.set_datetime(1857, 5, 31, 23, 59)
	_reset_counts()
	TimeManager.advance_minutes(1)
	d = TimeManager.get_date()
	_check(d["month"] == 6 and d["day"] == 1, "31/05 → 01/06")
	_check(_counts.get("month_changed", 0) == 1 and _last["month_changed"][0] == 6, "month_changed(6)")
	_check(_counts.get("day_changed", 0) == 1, "day_changed na virada do mês")
	TimeManager.set_datetime(1857, 12, 31, 23, 59)
	_reset_counts()
	TimeManager.advance_minutes(1)
	d = TimeManager.get_date()
	_check(d["year"] == 1858 and d["month"] == 1 and d["day"] == 1, "31/12/1857 → 01/01/1858")
	_check(_counts.get("year_changed", 0) == 1 and _last["year_changed"][0] == 1858, "year_changed(1858)")
	_check(_counts.get("month_changed", 0) == 1, "month_changed na virada do ano")
	_check(_counts.get("week_changed", 0) == 0, "sem week_changed (01/01/1858 é sexta)")
	TimeManager.set_datetime(1858, 1, 3, 23, 59)  # domingo
	_reset_counts()
	TimeManager.advance_minutes(1)
	_check(TimeManager.get_date()["weekday"] == 0 and _counts.get("week_changed", 0) == 1, "domingo → segunda: week_changed")

	# --- Salto grande ------------------------------------------------------------------
	TimeManager.set_datetime(1857, 5, 4, 9, 0)
	_reset_counts()
	TimeManager.advance_minutes(3 * 1440)
	_check(_counts.get("day_changed", 0) == 3, "salto de 3 dias: 3 day_changed")
	_check(_counts.get("time_jumped", 0) == 1, "salto emite time_jumped")
	_check(_counts.get("minute_changed", 0) == 1, "salto: minute_changed só do minuto final")
	_check(TimeManager.get_date()["day"] == 7, "4/5 + 3 dias = 7/5")

	# --- Sincronia com a história (flag data_atual) ------------------------------------------
	GameManager.set_flag("data_atual", "Dezembro de 1857")
	d = TimeManager.get_date()
	_check(d["month"] == 12 and d["day"] == 1 and d["year"] == 1857 and TimeManager.get_hour() == 9, "data_atual → 01/12/1857 09:00")
	GameManager.set_flag("data_atual", "Maio de 1857")
	_check(TimeManager.get_date()["month"] == 12, "data_atual não volta no tempo")

	# --- Pausa fora de PLAYING ------------------------------------------------------------------
	TimeManager.time_scale = 600.0
	TimeManager.running = true
	var t0 := TimeManager.get_total_minutes()
	GameManager.set_state(GameManager.State.DIALOGUE)
	await _frames(20)
	_check(TimeManager.get_total_minutes() == t0, "tempo parado em diálogo")
	GameManager.set_state(GameManager.State.PLAYING)
	await _frames(20)
	_check(TimeManager.get_total_minutes() > t0, "tempo corre em PLAYING")
	TimeManager.running = false
	t0 = TimeManager.get_total_minutes()
	await _frames(10)
	_check(TimeManager.get_total_minutes() == t0, "running = false para o relógio")
	TimeManager.time_scale = 1.0

	# --- Ambiente: dia e noite --------------------------------------------------------------------
	_check(SceneManager.current_map.map_id == "paris_1857", "mapa externo carregado")
	_check(SceneManager.current_map.get_node_or_null("DayNight") is CanvasModulate, "CanvasModulate no mapa")
	TimeManager.set_datetime(1857, 6, 1, 12, 0)
	var noon := EnvironmentManager.get_light_color()
	_check(noon.v > 0.97, "meio-dia claro (%.2f)" % noon.v)
	_check(EnvironmentManager.get_night_factor() < 0.01, "lampiões apagados de dia")
	TimeManager.set_datetime(1857, 6, 1, 22, 0)
	var night := EnvironmentManager.get_light_color()
	_check(night.v < 0.85 and night.v >= 0.5, "noite escura mas legível (%.2f)" % night.v)
	_check(night.b > night.r, "noite azul-arroxeada")
	_check(EnvironmentManager.get_night_factor() > 0.99, "lampiões acesos à noite")
	var lights := SceneManager.current_map.get_node("EnvLights").get_children()
	_check(lights.size() >= 4 and (lights[0] as PointLight2D).energy > 0.5, "luzes dos lampiões (%d)" % lights.size())
	TimeManager.set_datetime(1857, 6, 1, 18, 30)
	var sunset := EnvironmentManager.get_light_color()
	_check(sunset.r > sunset.b, "pôr do sol quente")
	# transição suave: minuto a minuto a cor muda pouco
	var a := EnvironmentManager.get_light_color()
	TimeManager.advance_minutes(1)
	var b := EnvironmentManager.get_light_color()
	_check(absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.03, "transição gradual")

	# --- Interior --------------------------------------------------------------------------------
	SceneManager.change_map("livraria", "entrada")
	await _wait_until(func(): return SceneManager.current_map.map_id == "livraria" and GameManager.is_playing(), 300)
	await _frames(3)
	if DialogueManager.is_active():
		DialogueManager.end()
	TimeManager.running = false
	TimeManager.set_datetime(1857, 6, 1, 22, 0)
	var indoor := EnvironmentManager.get_light_color()
	_check(indoor.v > night.v and indoor.v < 1.0, "interior: variação leve à noite (%.2f)" % indoor.v)

	# --- Relógio do HUD -------------------------------------------------------------------------
	var clock := get_tree().current_scene.get_node("%ClockWidget")
	_check(clock.get_node("%Time").text == "22:00", "relógio mostra 22:00")
	_check(clock.get_node("%Weekday").text == "Segunda-feira", "relógio mostra o dia da semana")
	_check(clock.get_node("%Date").text == "1 de junho de 1857", "relógio mostra a data")

	# --- Salvar/carregar e novo jogo ---------------------------------------------------------------
	var saved := TimeManager.save_data()
	TimeManager.set_datetime(1860, 1, 1, 8, 0)
	TimeManager.load_data(saved)
	_check(TimeManager.get_time_string() == "22:00" and TimeManager.get_date()["month"] == 6, "save/load do tempo")
	await GameManager.new_game()
	_check(TimeManager.get_date_string() == "Segunda-feira, 4 de maio de 1857" and TimeManager.get_time_string() == "09:00", "novo jogo volta à data inicial")
	TimeManager.running = true

	print("== %s (%d falha(s)) ==" % ["OK" if _failures == 0 else "FALHOU", _failures])
	get_tree().quit(1 if _failures else 0)


func _rec(sig: String, args: Array) -> void:
	_counts[sig] = _counts.get(sig, 0) + 1
	_last[sig] = args


func _reset_counts() -> void:
	_counts.clear()
	_last.clear()

extends Node
## TimeManager (autoload): relógio e calendário globais do jogo.
## Contrato: docs/VIDA_CONTRATOS.md (seção 1). Dados: data/world/calendar.json.
##
## O tempo é guardado como minutos inteiros desde 01/01/base_year 00:00.
## Ele só corre quando GameManager.state == PLAYING e running == true.

signal minute_changed(total_minutes: int)
signal hour_changed(hour: int)
signal phase_changed(phase: String)
signal day_changed(date: Dictionary)
signal week_changed(week_index: int)
signal month_changed(month: int, year: int)
signal year_changed(year: int)
signal time_jumped(total_minutes: int)

const CALENDAR_PATH := "res://data/world/calendar.json"
const PHASES := ["madrugada", "amanhecer", "manha", "meio_dia", "tarde", "por_do_sol", "noite"]
const MINUTES_PER_DAY := 1440
## Em avanços maiores que isto, minute_changed só é emitido para o minuto final.
const STEP_LIMIT := 60
## Em saltos que cruzam mais dias que isto, day_changed/week_changed só são emitidos uma vez.
const DAY_SIGNAL_LIMIT := 31

## Minutos de jogo por segundo real.
var time_scale := 1.0
## false = relógio parado por código (ex.: testes, cutscenes).
var running := true

var calendar: Dictionary = {}
var _total := 0
var _accum := 0.0
var _phase_starts: Array = []  # [[minuto_do_dia, id], ...]
var _cached_day := -1
var _cached_date: Dictionary = {}


func _ready() -> void:
	calendar = DataLoader.load_json(CALENDAR_PATH)
	time_scale = float(calendar.get("time_scale", 1.0))
	for p in calendar.get("phases", []):
		_phase_starts.append([parse_hhmm(p["from"]), p["id"]])
	_phase_starts.sort_custom(func(a, b): return a[0] < b[0])
	_total = _start_total()
	GameManager.new_game_started.connect(reset)
	GameManager.flag_changed.connect(_on_flag_changed)


func _process(delta: float) -> void:
	if not running or GameManager.state != GameManager.State.PLAYING:
		return
	_accum += delta * time_scale
	if _accum >= 1.0:
		var steps := int(_accum)
		_accum -= steps
		_advance(steps, false)


## Volta à data inicial do calendário (novo jogo).
func reset() -> void:
	_accum = 0.0
	_jump_to(_start_total())


# --- Consulta -------------------------------------------------------------------

func get_total_minutes() -> int:
	return _total


func get_hour() -> int:
	return get_minute_of_day() / 60


func get_minute() -> int:
	return get_minute_of_day() % 60


func get_minute_of_day() -> int:
	return _total % MINUTES_PER_DAY


func get_date() -> Dictionary:
	return _date_for_day(_total / MINUTES_PER_DAY).duplicate()


func get_phase() -> String:
	return _phase_for(get_minute_of_day())


func is_night() -> bool:
	var p := get_phase()
	return p == "noite" or p == "madrugada"


func get_time_string() -> String:
	return "%02d:%02d" % [get_hour(), get_minute()]


func get_date_string() -> String:
	var d := get_date()
	return "%s, %d de %s de %d" % [d["weekday_name"], d["day"], d["month_name"], d["year"]]


## Dia da semana (0 = segunda ... 6 = domingo) de uma data qualquer.
func weekday_of(year: int, month: int, day: int) -> int:
	var days := _days_until(year, month, day)
	return (int(calendar.get("base_weekday", 0)) + days) % 7


## Minutos totais de uma data/hora (útil para eventos e testes).
func total_for(year: int, month: int, day: int, hour: int = 0, minute: int = 0) -> int:
	return _days_until(year, month, day) * MINUTES_PER_DAY + hour * 60 + minute


static func parse_hhmm(text: String) -> int:
	var parts := text.strip_edges().split(":")
	if parts.size() < 2:
		return 0
	return int(parts[0]) * 60 + int(parts[1])


# --- Controle ----------------------------------------------------------------

func set_datetime(year: int, month: int, day: int, hour: int, minute: int) -> void:
	_jump_to(total_for(year, month, day, hour, minute))


func advance_minutes(minutes: int) -> void:
	_advance(minutes, minutes > STEP_LIMIT)


func save_data() -> Dictionary:
	return {"total": _total, "time_scale": time_scale}


func load_data(data: Dictionary) -> void:
	time_scale = float(data.get("time_scale", time_scale))
	_accum = 0.0
	_jump_to(int(data.get("total", _start_total())))


# --- Interno -------------------------------------------------------------------

func _advance(minutes: int, jumped: bool) -> void:
	if minutes <= 0:
		return
	if minutes <= STEP_LIMIT:
		for i in minutes:
			var old := _total
			_total += 1
			_emit_crossings(old, _total)
			minute_changed.emit(_total)
		if jumped:
			time_jumped.emit(_total)
		return
	var old_total := _total
	_total += minutes
	_emit_crossings(old_total, _total)
	minute_changed.emit(_total)
	time_jumped.emit(_total)


## Salto para qualquer momento (para frente ou para trás).
func _jump_to(new_total: int) -> void:
	new_total = maxi(0, new_total)
	if new_total > _total:
		_advance(new_total - _total, true)
		return
	var old := _total
	_total = new_total
	# Para trás: emite só o estado final do que mudou.
	if old / 60 != _total / 60:
		hour_changed.emit(get_hour())
	if _phase_for(old % MINUTES_PER_DAY) != get_phase():
		phase_changed.emit(get_phase())
	if old / MINUTES_PER_DAY != _total / MINUTES_PER_DAY:
		var d := get_date()
		var od := _date_for_day(old / MINUTES_PER_DAY)
		day_changed.emit(d)
		if od["year"] != d["year"]:
			year_changed.emit(d["year"])
		if od["month"] != d["month"] or od["year"] != d["year"]:
			month_changed.emit(d["month"], d["year"])
	minute_changed.emit(_total)
	time_jumped.emit(_total)


## Emite os sinais de hora/fase/dia/semana/mês/ano cruzados entre old e new (old < new).
func _emit_crossings(old: int, new: int) -> void:
	if old / 60 != new / 60:
		hour_changed.emit((new % MINUTES_PER_DAY) / 60)
	var old_phase := _phase_for(old % MINUTES_PER_DAY)
	var new_phase := _phase_for(new % MINUTES_PER_DAY)
	if old_phase != new_phase or new - old >= MINUTES_PER_DAY:
		phase_changed.emit(new_phase)
	var old_day := old / MINUTES_PER_DAY
	var new_day := new / MINUTES_PER_DAY
	if old_day == new_day:
		return
	var first := old_day + 1
	if new_day - old_day > DAY_SIGNAL_LIMIT:
		first = new_day  # salto longo: só o dia final
	var prev := _date_for_day(old_day)
	for day_index in range(first, new_day + 1):
		var d := _date_for_day(day_index)
		if d["year"] != prev["year"]:
			year_changed.emit(d["year"])
		if d["month"] != prev["month"] or d["year"] != prev["year"]:
			month_changed.emit(d["month"], d["year"])
		var skipped_week := first == new_day and new_day - old_day >= 7
		if d["weekday"] == 0 or skipped_week:
			week_changed.emit(_week_index(day_index))
		day_changed.emit(d)
		prev = d


func _week_index(day_index: int) -> int:
	return (day_index + int(calendar.get("base_weekday", 0))) / 7


func _phase_for(minute_of_day: int) -> String:
	var phase: String = _phase_starts[-1][1] if not _phase_starts.is_empty() else "manha"
	for p in _phase_starts:
		if minute_of_day >= p[0]:
			phase = p[1]
	return phase


func _start_total() -> int:
	var s: Dictionary = calendar.get("start", {})
	return total_for(int(s.get("year", 1857)), int(s.get("month", 1)), int(s.get("day", 1)),
			int(s.get("hour", 9)), int(s.get("minute", 0)))


func _base_year() -> int:
	return int(calendar.get("base_year", 1850))


func _is_leap(year: int) -> bool:
	if not calendar.get("gregorian_leap", true):
		return false
	return (year % 4 == 0 and year % 100 != 0) or year % 400 == 0


func _month_days(year: int, month: int) -> int:
	var months: Array = calendar.get("months", [])
	var days := int(months[month - 1].get("days", 30))
	if month == int(calendar.get("leap_month", 2)) and _is_leap(year):
		days += 1
	return days


func _year_days(year: int) -> int:
	var total := 0
	for m in range(1, calendar.get("months", []).size() + 1):
		total += _month_days(year, m)
	return total


func _days_until(year: int, month: int, day: int) -> int:
	var days := 0
	for y in range(_base_year(), year):
		days += _year_days(y)
	for m in range(1, month):
		days += _month_days(year, m)
	return days + day - 1


func _date_for_day(day_index: int) -> Dictionary:
	if day_index == _cached_day:
		return _cached_date
	var year := _base_year()
	var rest := day_index
	while rest >= _year_days(year):
		rest -= _year_days(year)
		year += 1
	var month := 1
	while rest >= _month_days(year, month):
		rest -= _month_days(year, month)
		month += 1
	var weekday := (int(calendar.get("base_weekday", 0)) + day_index) % 7
	var months: Array = calendar.get("months", [])
	var date := {
		"year": year, "month": month, "day": rest + 1, "weekday": weekday,
		"weekday_name": calendar.get("weekdays", [])[weekday],
		"month_name": months[month - 1].get("name", ""),
		"day_of_year": day_index - _days_until(year, 1, 1) + 1,
	}
	_cached_day = day_index
	_cached_date = date
	return date


## Sincronia com a história: flag "data_atual" = "Dezembro de 1857".
func _on_flag_changed(flag: String, value: Variant) -> void:
	if flag != "data_atual" or not value is String:
		return
	var parts := (value as String).to_lower().split(" de ")
	if parts.size() < 2:
		return
	var months: Array = calendar.get("months", [])
	var month := 0
	for i in months.size():
		if months[i].get("name", "") == parts[0].strip_edges():
			month = i + 1
	var year := int(parts[-1])
	if month == 0 or year < _base_year():
		return
	var target := total_for(year, month, 1, 9, 0)
	if target > _total:
		_jump_to(target)

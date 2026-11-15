extends Node
## WorldEventManager (autoload): acontecimentos do mundo ligados ao calendário.
## Contrato: docs/VIDA_CONTRATOS.md, seção 5. Dados: data/world/events.json.
##
## Recorrência ("recurrence"):
##   {"type": "daily", "except_weekdays": [6]}
##   {"type": "weekly", "weekday": 1}            0 = segunda ... 6 = domingo
##   {"type": "monthly", "day": 1}
##   {"type": "yearly", "month": 4, "day": 18, "from_year": 1858, "to_year": 1869}
##   {"type": "date", "year": 1858, "month": 1, "day": 1}
## Cada evento: id, name, recurrence, start/end ("HH:MM"), map (opcional),
## participants [{npc, spot, activity, map?, anim?, condition?}], notify,
## notify_map (só notifica se o jogador estiver nesse mapa), actions, condition.
## Funciona mesmo com o jogador em outro mapa (o LifeManager simula fora da tela).

signal event_started(event_id: String)
signal event_ended(event_id: String)

const DATA_PATH := "res://data/world/events.json"
const PRIORITY := 60

var events: Array = []
var _active: Dictionary = {}   # id -> evento

var _time = null
var _life = null


func _ready() -> void:
	events = DataLoader.load_json(DATA_PATH).get("events", [])
	_time = get_node_or_null("/root/TimeManager")
	_life = get_node_or_null("/root/LifeManager")
	if _time and _time.has_signal("minute_changed"):
		_time.minute_changed.connect(_on_minute)
	if _time and _time.has_signal("time_jumped"):
		_time.time_jumped.connect(_on_jump)
	GameManager.new_game_started.connect(reset)


func reset() -> void:
	for id in _active.keys():
		_end(id, false)
	_active.clear()


# --- API do contrato -------------------------------------------------------------

func get_active_events() -> Array:
	return _active.values()


func is_active(event_id: String) -> bool:
	return _active.has(event_id)


## Eventos cuja recorrência cai na data (sem avaliar condições: útil para calendário).
func get_events_on(date: Dictionary) -> Array:
	var out := []
	for e in events:
		if _matches_date(e.get("recurrence", {}), date):
			out.append(e)
	return out


func get_event(event_id: String) -> Dictionary:
	for e in events:
		if e.get("id") == event_id:
			return e
	return {}


# --- Avaliação --------------------------------------------------------------------

func _on_minute(_total: int) -> void:
	evaluate()


func _on_jump(_total: int) -> void:
	evaluate(true)


## Liga/desliga eventos conforme a data/hora atual. `silent` evita notificações
## em saltos de tempo (carregar jogo, salto da história).
func evaluate(silent: bool = false) -> void:
	if _time == null or not _time.has_method("get_date"):
		return
	var date: Dictionary = _time.get_date()
	var minute: int = _time.get_minute_of_day()
	for e in events:
		var id: String = e.get("id", "")
		var should := _should_run(e, date, minute)
		if should and not _active.has(id):
			_start(e, silent)
		elif not should and _active.has(id):
			_end(id)


func _should_run(e: Dictionary, date: Dictionary, minute: int) -> bool:
	if not _matches_date(e.get("recurrence", {}), date):
		return false
	var start := _hhmm(e.get("start", "00:00"))
	var end := _hhmm(e.get("end", "23:59"))
	if minute < start or minute >= end:
		return false
	return GameActions.check(e.get("condition"))


func _matches_date(r: Dictionary, date: Dictionary) -> bool:
	var year := int(date.get("year", 0))
	if r.has("from_year") and year < int(r["from_year"]):
		return false
	if r.has("to_year") and year > int(r["to_year"]):
		return false
	match r.get("type", ""):
		"daily":
			var weekday := int(date.get("weekday", -1))
			for w in r.get("except_weekdays", []):
				if int(w) == weekday:
					return false
			return true
		"weekly":
			return int(date.get("weekday", -1)) == int(r.get("weekday", -2))
		"monthly":
			return int(date.get("day", 0)) == int(r.get("day", -1))
		"yearly":
			return int(date.get("month", 0)) == int(r.get("month", -1)) \
					and int(date.get("day", 0)) == int(r.get("day", -1))
		"date":
			return year == int(r.get("year", -1)) and int(date.get("month", 0)) == int(r.get("month", -1)) \
					and int(date.get("day", 0)) == int(r.get("day", -1))
	return false


func _start(e: Dictionary, silent: bool) -> void:
	var id: String = e["id"]
	_active[id] = e
	if _life and _life.has_method("request_activity"):
		var until := _end_total(e)
		for p in e.get("participants", []):
			if not GameActions.check(p.get("condition")):
				continue
			var act := {
				"activity": p.get("activity", "visitar"),
				"map": p.get("map", e.get("map", "")),
				"spot": p.get("spot", ""),
			}
			if p.has("anim"):
				act["anim"] = p["anim"]
			# pins de missão (prioridade 100) vencem: se recusar, o NPC fica onde está
			if _life.request_activity(p["npc"], act, PRIORITY, until, _source(id)):
				_life.remember(p["npc"], "Participou: %s." % e.get("name", id))
	GameActions.run(e.get("actions", []))
	if not silent and e.get("notify", "") != "" and _should_notify(e):
		GameManager.notify(e["notify"])
	event_started.emit(id)


func _end(id: String, emit := true) -> void:
	var e: Dictionary = _active.get(id, {})
	_active.erase(id)
	if _life and _life.has_method("release"):
		for p in e.get("participants", []):
			_life.release(p["npc"], _source(id))
	if emit:
		event_ended.emit(id)


func _should_notify(e: Dictionary) -> bool:
	var only: String = e.get("notify_map", "")
	if only == "":
		return true
	return SceneManager.current_map != null and SceneManager.current_map.map_id == only


func _end_total(e: Dictionary) -> int:
	var now: int = _time.get_total_minutes()
	return now - int(_time.get_minute_of_day()) + _hhmm(e.get("end", "23:59"))


func _source(id: String) -> String:
	return "event:" + id


func _hhmm(text: String) -> int:
	var parts := text.split(":")
	return int(parts[0]) * 60 + (int(parts[1]) if parts.size() > 1 else 0)

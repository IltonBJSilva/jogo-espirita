extends Node
## SocialManager (autoload): relações e encontros entre NPCs e reação ao jogador.
## Contrato: docs/VIDA_CONTRATOS.md, seção 4. Dados: data/world/social.json.
##
## - Relações (tipo + familiaridade 0..100) que crescem com o convívio.
## - Encontros avaliados a cada N minutos de jogo (nunca por frame): dois NPCs
##   disponíveis no mesmo mapa trocam falas curtas. Na tela, com balões; fora
##   dela, de forma abstrata (memória e familiaridade são atualizadas igual).
## - Reação ao jogador: o NPC disponível olha para quem se aproxima e às vezes
##   cumprimenta conforme a afinidade e a hora do dia.

signal conversation_started(a: String, b: String, conversation_id: String)
signal conversation_ended(a: String, b: String, conversation_id: String)

const DATA_PATH := "res://data/world/social.json"
const PRIORITY := 40
const SOURCE := "social"

var settings: Dictionary = {}
var relations: Array = []
var conversations: Array = []
var generic_conversations: Array = []
var greetings: Dictionary = {}

var _familiarity: Dictionary = {}     # "a|b" -> int
var _cooldowns: Dictionary = {}       # "a|b" -> total_minutes em que pode conversar de novo
var _greet_cooldowns: Dictionary = {} # npc -> total_minutes
var _active: Array = []               # [{a, b, id, end, onscreen}]
var _near_player: Dictionary = {}     # npc -> bool (para detectar a aproximação)
var _rng := RandomNumberGenerator.new()
var _poll := 0.0

# Acesso dinâmico (os autoloads de tempo e vida são de outros módulos).
var _time = null
var _life = null


func _ready() -> void:
	var data := DataLoader.load_json(DATA_PATH)
	settings = data.get("settings", {})
	relations = data.get("relations", [])
	conversations = data.get("conversations", [])
	generic_conversations = data.get("generic_conversations", [])
	greetings = data.get("greetings", {})
	_rng.randomize()
	_time = get_node_or_null("/root/TimeManager")
	_life = get_node_or_null("/root/LifeManager")
	if _time and _time.has_signal("minute_changed"):
		_time.minute_changed.connect(_on_minute)
	GameManager.new_game_started.connect(reset)
	reset()


func reset() -> void:
	_familiarity.clear()
	_cooldowns.clear()
	_greet_cooldowns.clear()
	_active.clear()
	_near_player.clear()
	for r in relations:
		_familiarity[_key(r["a"], r["b"])] = int(r.get("familiarity", 0))


# --- API do contrato -------------------------------------------------------------

## Relação ativa entre dois NPCs (vazio se não houver ou se a condição não valer).
func get_relation(a: String, b: String) -> Dictionary:
	for r in relations:
		if (r["a"] == a and r["b"] == b) or (r["a"] == b and r["b"] == a):
			if GameActions.check(r.get("condition")):
				var out: Dictionary = r.duplicate()
				out["familiarity"] = get_familiarity(a, b)
				return out
	return {}


func get_familiarity(a: String, b: String) -> int:
	return int(_familiarity.get(_key(a, b), 0))


func is_in_conversation(npc_id: String) -> bool:
	for c in _active:
		if c["a"] == npc_id or c["b"] == npc_id:
			return true
	return false


func save_data() -> Dictionary:
	return {"familiarity": _familiarity.duplicate(), "cooldowns": _cooldowns.duplicate(),
			"greet": _greet_cooldowns.duplicate()}


func load_data(data: Dictionary) -> void:
	reset()
	for k in data.get("familiarity", {}):
		_familiarity[k] = int(data["familiarity"][k])
	for k in data.get("cooldowns", {}):
		_cooldowns[k] = int(data["cooldowns"][k])
	for k in data.get("greet", {}):
		_greet_cooldowns[k] = int(data["greet"][k])


# --- Encontros ---------------------------------------------------------------------

func _on_minute(total: int) -> void:
	_finish_due(total)
	var every := int(settings.get("check_every_minutes", 5))
	if every > 0 and total % every == 0:
		try_encounters(total)


## Avalia encontros em todos os mapas (também usado pelos testes).
func try_encounters(total: int = -1) -> void:
	if _life == null or not _life.has_method("get_all_ids"):
		return
	if total < 0:
		total = _now()
	var by_map := {}
	for id in _life.get_all_ids():
		if is_in_conversation(id) or not _life.is_available(id):
			continue
		var st: Dictionary = _life.get_state(id)
		var map_id: String = st.get("map", "")
		if map_id == "":
			continue  # em lugar abstrato (casa, fora): sem encontros
		if not by_map.has(map_id):
			by_map[map_id] = []
		by_map[map_id].append(id)
	var current := _current_map()
	for map_id in by_map:
		var ids: Array = by_map[map_id]
		if ids.size() < 2:
			continue
		var pair := _pick_pair(ids, total, map_id == current)
		if pair.is_empty():
			continue
		if _rng.randf() > float(settings.get("encounter_chance", 0.45)) and not pair.get("forced", false):
			continue
		_start_conversation(pair["a"], pair["b"], map_id, total, map_id == current)


## Força uma conversa entre dois NPCs (testes e eventos).
func start_conversation(a: String, b: String) -> bool:
	if is_in_conversation(a) or is_in_conversation(b):
		return false
	var st: Dictionary = _life.get_state(a)
	var map_id: String = st.get("map", "")
	return _start_conversation(a, b, map_id, _now(), map_id != "" and map_id == _current_map())


func _pick_pair(ids: Array, total: int, onscreen: bool) -> Dictionary:
	var candidates := []
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: String = ids[i]
			var b: String = ids[j]
			if int(_cooldowns.get(_key(a, b), -1)) > total:
				continue
			if onscreen and not _close_enough(a, b):
				continue
			# pares com relação têm mais peso
			var weight := 3 if not get_relation(a, b).is_empty() else 1
			for w in weight:
				candidates.append({"a": a, "b": b})
	if candidates.is_empty():
		return {}
	return candidates[_rng.randi() % candidates.size()]


func _close_enough(a: String, b: String) -> bool:
	var na = _life.get_npc_node(a)
	var nb = _life.get_npc_node(b)
	if na == null or nb == null or not na.visible or not nb.visible:
		return false
	return na.global_position.distance_to(nb.global_position) <= float(settings.get("onscreen_max_distance", 220))


func _choose_conversation(a: String, b: String) -> Dictionary:
	var specific := []
	for c in conversations:
		var p: Array = c.get("participants", [])
		if p.size() == 2 and ((p[0] == a and p[1] == b) or (p[0] == b and p[1] == a)) \
				and GameActions.check(c.get("condition")):
			specific.append(c)
	if not specific.is_empty():
		var chosen: Dictionary = specific[_rng.randi() % specific.size()]
		# a ordem das falas segue a ordem de "participants"
		var p2: Array = chosen["participants"]
		return {"conv": chosen, "order": [p2[0], p2[1]]}
	var generic: Dictionary = generic_conversations[_rng.randi() % generic_conversations.size()] \
			if not generic_conversations.is_empty() else {"id": "silencio", "lines": []}
	return {"conv": generic, "order": [a, b]}


func _start_conversation(a: String, b: String, map_id: String, total: int, onscreen: bool) -> bool:
	var pick := _choose_conversation(a, b)
	var conv: Dictionary = pick["conv"]
	var order: Array = pick["order"]
	var lines: Array = conv.get("lines", [])
	var duration := maxi(5, lines.size() * 3)
	var end := total + duration
	for id in order:
		var st: Dictionary = _life.get_state(id)
		var act := {"activity": "conversar", "map": map_id, "spot": st.get("spot", ""), "anim": "talk"}
		if not _life.request_activity(id, act, PRIORITY, end, SOURCE):
			for other in order:
				_life.release(other, SOURCE)
			return false
	var entry := {"a": order[0], "b": order[1], "id": conv.get("id", ""), "end": end, "onscreen": onscreen}
	_active.append(entry)
	_cooldowns[_key(a, b)] = total + int(settings.get("pair_cooldown_minutes", 120))
	conversation_started.emit(order[0], order[1], entry["id"])
	if onscreen:
		_life.face_towards_npc(order[0], order[1])
		_life.face_towards_npc(order[1], order[0])
		_life.show_emote(order[0], "conversa")
		_play_lines(entry, lines)
	return true


func _play_lines(entry: Dictionary, lines: Array) -> void:
	var seconds := float(settings.get("bark_seconds", 2.6))
	for line in lines:
		if not _active.has(entry):
			return
		var who: String = entry["a"] if int(line[0]) == 0 else entry["b"]
		_life.show_bark(who, str(line[1]), seconds)
		await get_tree().create_timer(seconds, false).timeout


func _finish_due(total: int) -> void:
	for entry in _active.duplicate():
		if total >= int(entry["end"]):
			_finish(entry)


func _finish(entry: Dictionary) -> void:
	_active.erase(entry)
	var a: String = entry["a"]
	var b: String = entry["b"]
	var k := _key(a, b)
	_familiarity[k] = mini(100, int(_familiarity.get(k, 0)) + int(settings.get("familiarity_gain", 3)))
	var name_a := GameManager.get_character_name(a)
	var name_b := GameManager.get_character_name(b)
	_life.remember(a, "Conversou com %s." % name_b)
	_life.remember(b, "Conversou com %s." % name_a)
	_life.release(a, SOURCE)
	_life.release(b, SOURCE)
	conversation_ended.emit(a, b, entry["id"])


## Encerra imediatamente as conversas em andamento (ex.: o jogador puxou assunto).
func finish_all() -> void:
	for entry in _active.duplicate():
		_finish(entry)


# --- Reação ao jogador --------------------------------------------------------------

func _process(delta: float) -> void:
	_poll += delta
	if _poll < 0.4:
		return
	_poll = 0.0
	if _life == null or not GameManager.is_playing() or not _life.has_method("get_npcs_in_map"):
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var current := _current_map()
	if player == null or current == "":
		return
	var limit := float(settings.get("greet_distance", 72))
	for id in _life.get_npcs_in_map(current):
		var node = _life.get_npc_node(id)
		if node == null or not node.visible:
			continue
		var near: bool = node.global_position.distance_to(player.global_position) <= limit
		var was_near: bool = _near_player.get(id, false)
		_near_player[id] = near
		if not near or not _life.is_available(id) or is_in_conversation(id):
			continue
		if not node.is_moving:
			node.face_towards(player.global_position)
		if not was_near:
			_maybe_greet(id)


func _maybe_greet(id: String) -> void:
	var now := _now()
	if int(_greet_cooldowns.get(id, -1)) > now:
		return
	if _rng.randf() > float(settings.get("greet_chance", 0.6)):
		return
	_greet_cooldowns[id] = now + int(settings.get("greet_cooldown_minutes", 90))
	_life.show_bark(id, greeting_for(id), 2.4)


## Cumprimento conforme afinidade e período do dia.
func greeting_for(id: String) -> String:
	var phase: String = _time.get_phase() if _time and _time.has_method("get_phase") else "manha"
	var periodo: String = greetings.get("periods", {}).get(phase, "Bom dia")
	var options: Array = greetings.get("by_npc", {}).get(id, [])
	if options.is_empty():
		var level := RelationshipManager.get_level_name(RelationshipManager.get_affinity(id))
		options = greetings.get("by_level", {}).get(level, ["{periodo}."])
	return str(options[_rng.randi() % options.size()]).replace("{periodo}", periodo)


# --- Utilitários ----------------------------------------------------------------------

func _key(a: String, b: String) -> String:
	return "%s|%s" % ([a, b] if a < b else [b, a])


func _now() -> int:
	return _time.get_total_minutes() if _time and _time.has_method("get_total_minutes") else 0


func _current_map() -> String:
	return SceneManager.current_map.map_id if SceneManager.current_map else ""

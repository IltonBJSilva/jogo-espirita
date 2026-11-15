extends Node
## LifeManager (autoload): simulação de vida de TODOS os NPCs.
## Contrato: docs/VIDA_CONTRATOS.md (seções 3, 7 e 8). Documentação: docs/VIDA_DOS_NPCS.md.
##
## - Estado global (mapa, spot, atividade...) de cada NPC, mesmo fora da tela.
## - Decisões a cada minuto de jogo (TimeManager.minute_changed), nunca por frame.
## - Prioridades: pin de missão (100) > diálogo (80) > evento (60) > social (40) > rotina (20).
## - Só o mapa atual tem nós: NPCs existentes na cena são reaproveitados; quem visita um mapa
##   sem nó próprio é instanciado (scenes/npcs/npc.tscn); quem está em outro lugar fica oculto.

signal npc_activity_changed(npc_id: String, activity: String, map_id: String, spot_id: String)
signal npc_arrived(npc_id: String, map_id: String, spot_id: String)

const NPC_DIR := "res://data/npcs/"
const SPOTS_PATH := "res://data/world/spots.json"
const NPC_SCENE := "res://scenes/npcs/npc.tscn"
const PRIORITY_PIN := 100
const PRIORITY_DIALOGUE := 80
const PRIORITY_EVENT := 60
const PRIORITY_SOCIAL := 40
const PRIORITY_ROUTINE := 20
const WEEKDAY_KEYS := ["segunda", "terca", "quarta", "quinta", "sexta", "sabado", "domingo"]
const MEMORY_MAX := 20

var profiles: Dictionary = {}
var spots: Dictionary = {}
var exits: Dictionary = {}
## Células reservadas no mapa atual (anti-sobreposição): Vector2i -> npc_id.
var _reserved: Dictionary = {}

var _states: Dictionary = {}    # id -> {map, spot, location, activity, mood, since, busy, pinned, source, priority}
var _requests: Dictionary = {}  # id -> [{activity, priority, until, source}]
var _memory: Dictionary = {}    # id -> [{when, text}]
var _nodes: Dictionary = {}     # id -> NPC no mapa atual
var _map_id := ""
## Decisões agrupadas: no máximo uma rodada por frame (frequência controlada).
var _eval_pending := false
## true quando a rodada vem de um salto de tempo: mudanças são aplicadas na hora
## (sem caminhar até a porta), pois o tempo "pulou".
var _instant := false


func _ready() -> void:
	for data in DataLoader.load_json_dir(NPC_DIR).values():
		if data.has("id"):
			profiles[data["id"]] = data
	var s := DataLoader.load_json(SPOTS_PATH)
	exits = s.get("_exits", {})
	for k in s:
		if k != "_exits":
			spots[k] = s[k]
	GameManager.new_game_started.connect(reset)
	SceneManager.map_changed.connect(_on_map_changed)
	TimeManager.minute_changed.connect(_on_minute)
	TimeManager.time_jumped.connect(func(_t): _schedule(true))
	QuestManager.quests_changed.connect(func(): _schedule(false))
	GameManager.flag_changed.connect(func(_f, _v): _schedule(false))


func reset() -> void:
	_states.clear()
	_requests.clear()
	_memory.clear()


# =====================================================================================
# API pública (contrato)
# =====================================================================================

func get_profile(npc_id: String) -> Dictionary:
	return profiles.get(npc_id, {})


func get_all_ids() -> Array[String]:
	var out: Array[String] = []
	for id in profiles:
		out.append(id)
	return out


func get_state(npc_id: String) -> Dictionary:
	if _eval_pending:
		_flush()
	if not _states.has(npc_id):
		_evaluate(npc_id)
	var st: Dictionary = _states.get(npc_id, {}).duplicate()
	st["busy"] = _in_dialogue(npc_id)
	return st


func get_npcs_in_map(map_id: String) -> Array[String]:
	var out: Array[String] = []
	for id in profiles:
		if get_state(id).get("map", "") == map_id:
			out.append(id)
	return out


func get_npc_node(npc_id: String) -> NPC:
	var n = _nodes.get(npc_id)
	if n == null or not is_instance_valid(n):
		return null
	return n


func request_activity(npc_id: String, activity: Dictionary, priority: int, until_minutes: int, source: String) -> bool:
	if not profiles.has(npc_id):
		return false
	var list: Array = _requests.get(npc_id, [])
	list = list.filter(func(r): return r["source"] != source)
	list.append({"activity": activity, "priority": priority, "until": until_minutes, "source": source})
	_requests[npc_id] = list
	_evaluate(npc_id)
	return _states[npc_id].get("source", "") == source


func release(npc_id: String, source: String) -> void:
	if _requests.has(npc_id):
		_requests[npc_id] = _requests[npc_id].filter(func(r): return r["source"] != source)
	var brain := _brain(npc_id)
	_evaluate(npc_id)
	# volta ao spot do estado atual (caso um walk_to social o tenha deslocado)
	if brain and not brain.is_walking():
		_send_to_state_spot(npc_id, false)


func is_available(npc_id: String) -> bool:
	if not profiles.has(npc_id):
		return false
	var st := get_state(npc_id)
	if st.get("pinned", false) or st.get("busy", false) or st.get("activity", "") == "dormir":
		return false
	if int(st.get("priority", 0)) >= PRIORITY_EVENT:
		return false
	var brain := _brain(npc_id)
	return brain == null or not brain.is_walking()


## Deslocamento pedido pelo sistema social. spot_id pode ser "@<outro_npc>" (ao lado dele).
func walk_to(npc_id: String, map_id: String, spot_id: String) -> void:
	var brain := _brain(npc_id)
	if brain == null or map_id != _map_id:
		return
	var st: Dictionary = _states.get(npc_id, {})
	if spot_id.begins_with("@"):
		var other := get_npc_node(spot_id.substr(1))
		if other == null:
			return
		var pos := _beside(npc_id, map_id, other)
		brain.go_to(pos, (other.global_position - pos).normalized(), st.get("activity", "conversar"), st.get("spot", ""))
	else:
		var spot := _spot(map_id, spot_id)
		if not spot.is_empty():
			brain.go_to(_vec(spot["pos"]), _vec(spot["facing"]), st.get("activity", "passear"), spot_id)


## Lugar ao lado de outro NPC para conversar: ~40 px (os sprites não se
## encavalam), do lado de onde vem; se estiver ocupado ou for parede, tenta o
## outro lado, embaixo e em cima.
func _beside(npc_id: String, map_id: String, other: Node2D) -> Vector2:
	var s := 1.0 if npc_node_x(npc_id) > other.global_position.x else -1.0
	for off in [Vector2(40 * s, 0), Vector2(-40 * s, 0), Vector2(0, 36), Vector2(0, -36)]:
		var pos: Vector2 = other.global_position + off
		var cell := LifeNavGrid.to_cell(pos)
		if not LifeNavGrid.is_free(map_id, pos):
			continue
		if _reserved.get(cell, "") not in ["", npc_id]:
			continue
		if cell == LifeNavGrid.to_cell(other.global_position):
			continue
		return pos
	var fallback := other.global_position + Vector2(40 * s, 0)
	return LifeNavGrid.cell_center(LifeNavGrid.nearest_free(map_id, LifeNavGrid.to_cell(fallback)))


func npc_node_x(npc_id: String) -> float:
	var n := get_npc_node(npc_id)
	return n.global_position.x if n else 0.0


func face_towards_npc(npc_id: String, other_id: String) -> void:
	var a := get_npc_node(npc_id)
	var b := get_npc_node(other_id)
	if a and b and a.visible and b.visible:
		a.face_towards(b.global_position)


func show_emote(npc_id: String, emote: String) -> void:
	var brain := _brain(npc_id)
	if brain:
		brain.emote(emote)


func show_bark(npc_id: String, text: String, seconds := 3.0) -> void:
	var brain := _brain(npc_id)
	if brain:
		brain.bark(text, seconds)


func remember(npc_id: String, text: String) -> void:
	var list: Array = _memory.get(npc_id, [])
	list.append({"when": "%s %s" % [TimeManager.get_date_string(), TimeManager.get_time_string()], "text": text})
	while list.size() > MEMORY_MAX:
		list.pop_front()
	_memory[npc_id] = list


func get_memory(npc_id: String) -> Array:
	return _memory.get(npc_id, []).duplicate()


func save_data() -> Dictionary:
	return {"states": _states.duplicate(true), "requests": _requests.duplicate(true), "memory": _memory.duplicate(true)}


func load_data(data: Dictionary) -> void:
	_states = data.get("states", {}).duplicate(true)
	_requests = data.get("requests", {}).duplicate(true)
	_memory = data.get("memory", {}).duplicate(true)


# =====================================================================================
# Decisão (simulação abstrata)
# =====================================================================================

func evaluate_all() -> void:
	for id in profiles:
		_evaluate(id)


func _on_minute(_total: int) -> void:
	_schedule(false)


func _schedule(instant: bool) -> void:
	_instant = _instant or instant
	if not _eval_pending:
		_eval_pending = true
		_flush.call_deferred()


func _flush() -> void:
	if not _eval_pending:
		return
	_eval_pending = false
	evaluate_all()
	_sync_nodes(_instant)
	_instant = false


## Reconcilia os nós do mapa atual com o estado (ordens cruzadas, saltos de tempo):
## quem não deveria estar aqui some (ou termina de sair andando); num salto de
## tempo, quem deveria estar aqui aparece direto no seu spot.
func _sync_nodes(instant: bool) -> void:
	if _map_id == "":
		return
	for id in _nodes.keys():
		var node := get_npc_node(id)
		if node == null:
			continue
		var st: Dictionary = _states.get(id, {})
		var brain := _brain(id)
		if st.get("map", "") != _map_id:
			if node.life_present and (instant or brain == null or not brain.is_walking()):
				node.set_life_present(false)
		elif instant and not node.life_present:
			node.set_life_present(true)
			_send_to_state_spot(id, true)


## O que o NPC deveria estar fazendo agora (sem efeitos colaterais).
func _desired(npc_id: String) -> Dictionary:
	var p: Dictionary = profiles[npc_id]
	for pin in p.get("pins", []):
		if GameActions.check(pin.get("condition", {})):
			var map_id: String = pin["map"]
			var spot_id := npc_id + "_origem"
			if not _spot(map_id, spot_id).size():
				spot_id = _first_spot(map_id)
			return {"activity": pin.get("activity", "conversar"), "map": map_id, "spot": spot_id,
					"location": map_id + ":" + spot_id, "source": "pin", "priority": PRIORITY_PIN, "pinned": true}
	var now := TimeManager.get_total_minutes()
	var best: Dictionary = {}
	for r in _requests.get(npc_id, []):
		if int(r["until"]) > now and (best.is_empty() or int(r["priority"]) > int(best["priority"])):
			best = r
	if not best.is_empty():
		var a: Dictionary = best["activity"]
		var loc: String = a.get("map", "") + (":" + a.get("spot", "") if a.get("spot", "") != "" else "")
		return _with_location({"activity": a.get("activity", "conversar"), "source": best["source"],
				"priority": int(best["priority"]), "pinned": false}, loc, npc_id)
	return _routine(npc_id)


func _routine(npc_id: String) -> Dictionary:
	var p: Dictionary = profiles[npc_id]
	var minute := TimeManager.get_minute_of_day()
	var weekday: int = TimeManager.get_date().get("weekday", 0)
	var schedule: Dictionary = p.get("schedule", {})
	var blocks: Array = schedule.get(WEEKDAY_KEYS[weekday], schedule.get("default", []))
	for blk in blocks:
		var a := TimeManager.parse_hhmm(blk["from"])
		var b := TimeManager.parse_hhmm(blk["to"])
		var inside := (minute >= a and minute < b) if a <= b else (minute >= a or minute < b)
		if inside:
			return _with_location({"activity": blk["activity"], "source": "rotina",
					"priority": PRIORITY_ROUTINE, "pinned": false}, blk["location"], npc_id)
	var wake := TimeManager.parse_hhmm(p.get("wake", "06:00"))
	var sleep := TimeManager.parse_hhmm(p.get("sleep", "22:00"))
	var awake := minute >= wake and minute < sleep
	var home: String = p.get("home", "casa")
	var where := (home + "_quarto") if spots.has(home) else home
	return _with_location({"activity": "descansar" if awake else "dormir", "source": "rotina",
			"priority": PRIORITY_ROUTINE, "pinned": false}, where, npc_id)


func _with_location(d: Dictionary, location: String, npc_id: String) -> Dictionary:
	var map_id := ""
	var spot_id := ""
	if location.contains(":"):
		map_id = location.get_slice(":", 0)
		spot_id = location.get_slice(":", 1)
	elif spots.has(location):
		map_id = location
		spot_id = npc_id + "_origem" if _spot(location, npc_id + "_origem").size() else _first_spot(location)
	if map_id != "" and not spots.has(map_id):
		map_id = ""
	d["map"] = map_id
	d["spot"] = spot_id if map_id != "" else ""
	d["location"] = location
	return d


func _evaluate(npc_id: String) -> void:
	if not profiles.has(npc_id):
		return
	var want := _desired(npc_id)
	var old: Dictionary = _states.get(npc_id, {})
	if not old.is_empty() and old.get("location") == want["location"] and old.get("activity") == want["activity"] \
			and old.get("pinned", false) == want["pinned"]:
		old["source"] = want["source"]
		old["priority"] = want["priority"]
		return
	var st := {
		"map": want["map"], "spot": want["spot"], "location": want["location"], "activity": want["activity"],
		"mood": profiles[npc_id].get("mood", "sereno"), "since": TimeManager.get_total_minutes(),
		"pinned": want["pinned"], "source": want["source"], "priority": want["priority"],
	}
	_states[npc_id] = st
	_note_memory(npc_id, old, st)
	npc_activity_changed.emit(npc_id, st["activity"], st["map"], st["spot"])
	if _map_id != "":
		_materialize_change(npc_id, old, st)


func _note_memory(npc_id: String, old: Dictionary, st: Dictionary) -> void:
	if old.get("activity", "") == "dormir" and st["activity"] != "dormir":
		remember(npc_id, "Acordou às %s." % TimeManager.get_time_string())
	elif st["activity"] == "dormir" and old.get("activity", "") != "dormir" and not old.is_empty():
		remember(npc_id, "Foi dormir às %s." % TimeManager.get_time_string())
	elif st["activity"] == "reuniao":
		remember(npc_id, "Participou da reunião de estudos.")


# =====================================================================================
# Materialização no mapa atual
# =====================================================================================

func _on_map_changed(map_id: String, _display_name: String) -> void:
	_map_id = map_id
	_nodes.clear()
	_reserved.clear()
	var map := SceneManager.current_map
	if map == null:
		return
	for node in map.find_children("*", "NPC", true, false):
		var id: String = node.npc_id
		if profiles.has(id) and not _nodes.has(id):
			_attach(node, id)
	for id in profiles:
		if not _states.has(id):
			_evaluate(id)
		else:
			# reavalia sem materializar mudanças antigas (o mapa acabou de carregar)
			var saved := _map_id
			_map_id = ""
			_evaluate(id)
			_map_id = saved
		var st: Dictionary = _states[id]
		if st["map"] == map_id:
			var node := _ensure_node(id)
			if node:
				node.set_life_present(true)
				_send_to_state_spot(id, true)
		elif _nodes.has(id):
			_nodes[id].set_life_present(false)


func _attach(node: NPC, id: String) -> NPCBrain:
	node.life_controlled = true
	var brain := NPCBrain.new()
	brain.name = "LifeBrain"
	node.add_child(brain)
	brain.setup(node, id, _map_id)
	_nodes[id] = node
	return brain


func _ensure_node(npc_id: String) -> NPC:
	var node := get_npc_node(npc_id)
	if node:
		return node
	var map := SceneManager.current_map
	var p: Dictionary = profiles[npc_id]
	if map == null or not ResourceLoader.exists(p.get("frames", "")):
		return null
	node = load(NPC_SCENE).instantiate()
	node.name = "Life_" + npc_id
	node.sprite_frames = load(p["frames"])
	node.npc_id = npc_id
	node.dialogue_id = p.get("dialogue_id", "")
	node.set_meta("life_spawned", true)
	map.get_entities_root().add_child(node)
	_attach(node, npc_id)
	return node


func _materialize_change(npc_id: String, old: Dictionary, st: Dictionary) -> void:
	var was_here: bool = old.get("map", "") == _map_id
	var is_here: bool = st["map"] == _map_id
	if not was_here and not is_here:
		return
	if _instant:  # salto de tempo: aparece/some na hora
		if is_here:
			var n := _ensure_node(npc_id)
			if n:
				n.set_life_present(true)
				_send_to_state_spot(npc_id, true)
		elif get_npc_node(npc_id):
			get_npc_node(npc_id).set_life_present(false)
		return
	if is_here:
		var node := _ensure_node(npc_id)
		if node == null:
			return
		if not was_here:  # chega pela porta/saída que leva ao lugar de onde vem
			node.set_life_present(true)
			var entry := _exit_spot(_map_id, old.get("map", ""))
			var brain := _brain(npc_id)
			if not entry.is_empty() and not st["pinned"]:
				brain.place_at(_vec(entry["pos"]), Vector2.ZERO, "", "")
			else:
				_send_to_state_spot(npc_id, true)
				return
		_send_to_state_spot(npc_id, st["pinned"] and not was_here)
	else:  # estava aqui e vai embora: caminha até a saída e some
		var brain := _brain(npc_id)
		if brain == null:
			return
		var exit_spot := _exit_spot(_map_id, st["map"])
		if exit_spot.is_empty() or not get_npc_node(npc_id).visible:
			get_npc_node(npc_id).set_life_present(false)
		else:
			brain.leave_via(_vec(exit_spot["pos"]))


func _send_to_state_spot(npc_id: String, instant: bool) -> void:
	var brain := _brain(npc_id)
	var st: Dictionary = _states.get(npc_id, {})
	if brain == null or st.get("map", "") != _map_id:
		return
	var spot := _spot(_map_id, st["spot"])
	if spot.is_empty():
		return
	var pos := _vec(spot["pos"])
	var facing := _vec(spot.get("facing", [0, 1]))
	if instant:
		brain.place_at(pos, facing, st["activity"], st["spot"])
	else:
		brain.go_to(pos, facing, st["activity"], st["spot"])


func _on_brain_arrived(npc_id: String, map_id: String, spot_id: String) -> void:
	if spot_id != "":
		npc_arrived.emit(npc_id, map_id, spot_id)


# =====================================================================================
# Auxiliares
# =====================================================================================

func _brain(npc_id: String) -> NPCBrain:
	var node := get_npc_node(npc_id)
	return node.get_node_or_null("LifeBrain") as NPCBrain if node else null


func _in_dialogue(npc_id: String) -> bool:
	var node := get_npc_node(npc_id)
	return node != null and DialogueManager.is_active() and DialogueManager.context.get("source") == node.interactable


func _spot(map_id: String, spot_id: String) -> Dictionary:
	return spots.get(map_id, {}).get(spot_id, {})


func _first_spot(map_id: String) -> String:
	for k in spots.get(map_id, {}):
		return k
	return ""


func _exit_spot(map_id: String, toward: String) -> Dictionary:
	var e: Dictionary = exits.get(map_id, {})
	var sid: String = e.get(toward, e.get("*", ""))
	return _spot(map_id, sid)


func _vec(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))

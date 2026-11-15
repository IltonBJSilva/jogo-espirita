class_name NPCBrain
extends Node
## Cérebro de um NPC no mapa atual (filho do nó NPC; criado pelo LifeManager).
##
## FSM:
##   IDLE      parado, sem destino
##   WALKING   seguindo um caminho A* até um spot
##   ACTIVITY  no destino, executando a atividade (pose + balões)
##   LEAVING   indo até a saída do mapa; ao chegar, o nó some
##   DIALOGUE  conversando com o jogador (parado; ordens ficam pendentes)
## O jogador por perto (< 48 px) pausa o caminhar e faz o NPC olhar para ele.
## Decisões de "para onde ir" vêm do LifeManager (por minuto de jogo); aqui só
## há movimento e apresentação (_physics_process leve).

enum S { IDLE, WALKING, ACTIVITY, LEAVING, DIALOGUE }

const SPEED := 52.0
const PLAYER_STOP := 48.0
const REACT_RADIUS := 64.0
const BLOCK_RADIUS := 18.0
const REPLAN_AFTER := 2.0
const GIVE_UP_AFTER := 6.0
## Jogador parado no caminho por mais que isto: o NPC contorna (evita impasse).
const PLAYER_PATIENCE := 3.0

## Perfil de desempenho (tempo gasto em _physics_process por todos os cérebros).
static var prof_usec := 0
static var prof_calls := 0

var npc: NPC
var npc_id := ""
var map_id := ""
var state := S.IDLE
var activity := ""
var spot_id := ""

var _path := PackedVector2Array()
var _path_i := 0
var _final_facing := Vector2.DOWN
var _blocked := 0.0
var _style: Dictionary = {}
var _emote_wait := 0.0
var _bob_t := 0.0
var _check_t := 0.0
var _pending: Callable
var _state_before_dialogue := S.IDLE
var _bubble: EmoteBubble
var _reserved := Vector2i(-999, -999)
var _player_wait := 0.0


func setup(target: NPC, id: String, current_map: String) -> void:
	npc = target
	npc_id = id
	map_id = current_map
	_bubble = EmoteBubble.new()
	_bubble.name = "EmoteBubble"
	npc.add_child.call_deferred(_bubble)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


# --- Ordens (vindas do LifeManager) ---------------------------------------------

## Coloca o NPC imediatamente no spot (usado ao carregar o mapa).
func place_at(pos: Vector2, facing: Vector2, new_activity: String, new_spot: String) -> void:
	_release_cell()
	npc.global_position = pos
	_path = PackedVector2Array()
	activity = new_activity
	spot_id = new_spot
	_arrive(facing)


## Caminha até pos e depois executa a atividade.
func go_to(pos: Vector2, facing: Vector2, new_activity: String, new_spot: String) -> void:
	if state == S.DIALOGUE:
		_pending = go_to.bind(pos, facing, new_activity, new_spot)
		return
	activity = new_activity
	spot_id = new_spot
	_final_facing = facing
	if npc.global_position.distance_to(pos) < 4.0:
		npc.global_position = pos
		_arrive(facing)
		return
	_path = LifeNavGrid.find_path(map_id, npc.global_position, pos)
	if _path.is_empty():  # sem caminho (raro): reposiciona discretamente
		place_at(pos, facing, new_activity, new_spot)
		return
	_path_i = 0
	_blocked = 0.0
	state = S.WALKING
	npc.play_special("")


## Sai do mapa pela porta/saída e some ao chegar.
func leave_via(pos: Vector2) -> void:
	if state == S.DIALOGUE:
		_pending = leave_via.bind(pos)
		return
	go_to(pos, Vector2.ZERO, "", "")
	if state == S.WALKING:
		state = S.LEAVING
	else:
		_vanish()


func emote(kind: String, seconds := 2.2) -> void:
	if _bubble and npc.visible:
		_bubble.show_emote(kind, seconds)


func bark(text: String, seconds := 3.0) -> void:
	if _bubble and npc.visible:
		_bubble.show_bark(text, seconds)


func is_walking() -> bool:
	return state == S.WALKING or state == S.LEAVING


# --- Laço ----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if npc == null or not npc.visible:
		return
	var t0 := Time.get_ticks_usec()
	_tick(delta)
	prof_usec += Time.get_ticks_usec() - t0
	prof_calls += 1


func _tick(delta: float) -> void:
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 0.15
		_check_dialogue()
	match state:
		S.WALKING, S.LEAVING:
			_walk(delta)
		S.ACTIVITY:
			_animate_activity(delta)
		S.IDLE:
			_react_to_player()


func _walk(delta: float) -> void:
	if not GameManager.is_playing():
		npc.set_moving(false)
		return
	var player := _player()
	var near := player != null and player.global_position.distance_to(npc.global_position) < PLAYER_STOP
	if near and _player_wait < PLAYER_PATIENCE:
		_player_wait += delta
		npc.set_moving(false)
		npc.face_towards(player.global_position)
		if _player_wait >= PLAYER_PATIENCE:
			_replan_around_player(player)
		return
	if player and player.global_position.distance_to(npc.global_position) > PLAYER_STOP * 1.5:
		_player_wait = 0.0
	if _path_i >= _path.size():
		_finish_walk()
		return
	var target := _path[_path_i]
	if _is_blocked(target):
		npc.set_moving(false)
		_blocked += delta
		if _blocked > GIVE_UP_AFTER:  # impasse: atravessa a célula para não travar o mundo
			_blocked = 0.0
			_path_i += 1
		elif _blocked > REPLAN_AFTER and int(_blocked * 10) % 10 == 0:
			var goal := _path[_path.size() - 1]
			_path = LifeNavGrid.find_path(map_id, npc.global_position, goal)
			_path_i = 0
		return
	_blocked = 0.0
	_reserve(LifeNavGrid.to_cell(target))
	var dir := target - npc.global_position
	var step := SPEED * delta
	if dir.length() <= step:
		npc.global_position = target
		_path_i += 1
	else:
		npc.global_position += dir.normalized() * step
	npc.face(dir)
	npc.set_moving(true)


## Recalcula a rota tratando a célula do jogador como obstáculo.
func _replan_around_player(player: Node2D) -> void:
	if _path.is_empty():
		return
	var grid := LifeNavGrid.get_grid(map_id)
	var cell := LifeNavGrid.to_cell(player.global_position)
	var inside := grid != null and grid.is_in_boundsv(cell)
	var was_solid := inside and grid.is_point_solid(cell)
	if inside:
		grid.set_point_solid(cell, true)
	var goal := _path[_path.size() - 1]
	var new_path := LifeNavGrid.find_path(map_id, npc.global_position, goal)
	if inside and not was_solid:
		grid.set_point_solid(cell, false)
	if not new_path.is_empty():
		_path = new_path
		_path_i = 0


func _finish_walk() -> void:
	npc.set_moving(false)
	if state == S.LEAVING:
		_vanish()
		return
	_arrive(_final_facing)


func _arrive(facing: Vector2) -> void:
	if facing != Vector2.ZERO:
		_final_facing = facing
	npc.sprite.offset.y = -46.0
	state = S.ACTIVITY if activity != "" else S.IDLE
	_style = LifeAnimator.apply(npc, activity, facing)
	_emote_wait = randf_range(1.5, 4.0)
	_reserve(LifeNavGrid.to_cell(npc.global_position))
	LifeManager._on_brain_arrived(npc_id, map_id, spot_id)


func _vanish() -> void:
	_release_cell()
	state = S.IDLE
	npc.set_moving(false)
	npc.set_life_present(false)


func _animate_activity(delta: float) -> void:
	var bob: int = _style.get("bob", 0)
	if bob > 0:
		_bob_t += delta
		npc.sprite.offset.y = -46.0 - (bob if int(_bob_t * 2.5) % 2 == 0 else 0)
	var interval: float = _style.get("interval", 0.0)
	if interval > 0.0 and GameManager.is_playing():
		_emote_wait -= delta
		if _emote_wait <= 0.0:
			_emote_wait = interval * randf_range(0.7, 1.3)
			emote(_style.get("emote", ""))
	_react_to_player()


func _react_to_player() -> void:
	var player := _player()
	if player and GameManager.is_playing():
		if player.global_position.distance_to(npc.global_position) < REACT_RADIUS * 0.6:
			npc.face_towards(player.global_position)


func _check_dialogue() -> void:
	var talking: bool = DialogueManager.is_active() and DialogueManager.context.get("source") == npc.interactable
	if talking and state != S.DIALOGUE:
		_state_before_dialogue = state
		state = S.DIALOGUE
		npc.set_moving(false)
		npc.sprite.offset.y = -46.0


func _on_dialogue_ended(_id: String) -> void:
	if state != S.DIALOGUE:
		return
	state = _state_before_dialogue
	_after_dialogue.call_deferred()  # depois do NPC restaurar a pose padrão


func _after_dialogue() -> void:
	if not is_instance_valid(npc):
		return
	if _pending.is_valid():
		var cmd := _pending
		_pending = Callable()
		cmd.call()
	elif state == S.ACTIVITY or state == S.IDLE:
		_style = LifeAnimator.apply(npc, activity, _final_facing)


func _is_blocked(target: Vector2) -> bool:
	var player := _player()
	if player and player.global_position.distance_to(target) < BLOCK_RADIUS and _player_wait < PLAYER_PATIENCE:
		return true
	var cell := LifeNavGrid.to_cell(target)
	var owner_id: String = LifeManager._reserved.get(cell, "")
	return owner_id != "" and owner_id != npc_id


func _reserve(cell: Vector2i) -> void:
	if cell == _reserved:
		return
	_release_cell()
	_reserved = cell
	LifeManager._reserved[cell] = npc_id


func _release_cell() -> void:
	if LifeManager._reserved.get(_reserved, "") == npc_id:
		LifeManager._reserved.erase(_reserved)
	_reserved = Vector2i(-999, -999)


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _exit_tree() -> void:
	_release_cell()

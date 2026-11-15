extends Node
## SceneManager (autoload): troca de telas e de mapas com transicao em fade.
##
## Mapas ficam em scenes/maps/<id>/<id>.tscn e tem raiz GameMap. O jogador
## e persistente (vive em game.tscn) e e movido para o mapa atual a cada troca.

signal map_changed(map_id: String, display_name: String)

const GAME_SCENE := "res://scenes/main/game.tscn"
const TITLE_SCENE := "res://scenes/main/title_screen.tscn"
const MAPS_DIR := "res://scenes/maps/"
const FADE_TIME := 0.35

var current_map: GameMap = null
var _busy := false
var _fade: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.04, 0.02, 0.05, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


func map_path(map_id: String) -> String:
	return MAPS_DIR.path_join(map_id).path_join(map_id + ".tscn")


## Sai da tela de titulo e entra no jogo, no mapa/spawn indicados.
func start_game(map_id: String, spawn: String) -> void:
	_busy = true
	GameManager.set_state(GameManager.State.TRANSITION)
	await _fade_to(1.0)
	current_map = null
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)
	await get_tree().process_frame
	await get_tree().process_frame
	_load_map(map_id, spawn)
	await _fade_to(0.0)
	_busy = false
	GameManager.set_state(GameManager.State.PLAYING)


## Troca de mapa durante o jogo (portas, eventos).
func change_map(map_id: String, spawn: String = "") -> void:
	if _busy:
		return
	_busy = true
	GameManager.set_state(GameManager.State.TRANSITION)
	await _fade_to(1.0)
	_load_map(map_id, spawn)
	await get_tree().physics_frame
	await _fade_to(0.0)
	_busy = false
	GameManager.set_state(GameManager.State.PLAYING)


func go_to_title() -> void:
	_busy = true
	await _fade_to(1.0)
	get_tree().paused = false
	DialogueManager.end()
	current_map = null
	get_tree().change_scene_to_file(TITLE_SCENE)
	GameManager.set_state(GameManager.State.TITLE)
	await get_tree().process_frame
	await _fade_to(0.0)
	_busy = false


func _load_map(map_id: String, spawn: String) -> void:
	var game := get_tree().current_scene
	var world: Node2D = game.get_node("World")
	var player: Player = game.get_node("%Player")
	var scene := load(map_path(map_id)) as PackedScene
	if scene == null:
		push_error("SceneManager: mapa '%s' nao encontrado." % map_id)
		return
	# Retira o jogador do mapa antigo antes de descarta-lo.
	if player.get_parent() != world:
		player.reparent(world, false)
	if current_map:
		world.remove_child(current_map)
		current_map.queue_free()
	current_map = scene.instantiate()
	world.add_child(current_map)
	player.reparent(current_map.get_entities_root(), false)
	var spawn_point := current_map.get_spawn(spawn)
	if spawn_point:
		player.global_position = spawn_point.global_position
		player.face(spawn_point.facing)
	player.apply_camera_limits(current_map.get_bounds())
	map_changed.emit(map_id, current_map.display_name)


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, FADE_TIME)
	await tween.finished

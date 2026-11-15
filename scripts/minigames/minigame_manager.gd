extends Node
## MinigameManager (autoload): abre e fecha minigames independentes.
##
## O registro fica em data/minigames.json. Cada minigame e uma cena cuja raiz
## estende Minigame (scripts/minigames/minigame.gd).

signal minigame_started(minigame_id: String)
signal minigame_finished(minigame_id: String, success: bool)

const REGISTRY_PATH := "res://data/minigames.json"
const LAYER := 40

var registry: Dictionary = {}
var _layer: CanvasLayer
var _current: Minigame = null
var _current_id := ""
var _on_success: Array = []
var _on_fail: Array = []


func _ready() -> void:
	registry = DataLoader.load_json(REGISTRY_PATH).get("minigames", {})
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)


func is_active() -> bool:
	return _current != null


func start(minigame_id: String, on_success: Array = [], on_fail: Array = []) -> bool:
	if is_active():
		return false
	var info: Dictionary = registry.get(minigame_id, {})
	if info.is_empty():
		push_error("MinigameManager: minigame '%s' nao registrado." % minigame_id)
		return false
	var scene := load(info.get("scene", "")) as PackedScene
	if scene == null:
		push_error("MinigameManager: cena invalida para '%s'." % minigame_id)
		return false
	var instance := scene.instantiate()
	if not instance is Minigame:
		push_error("MinigameManager: a raiz de '%s' deve estender Minigame." % minigame_id)
		instance.free()
		return false
	_current = instance
	_current_id = minigame_id
	_on_success = on_success
	_on_fail = on_fail
	_current.setup(info)
	_current.finished.connect(_on_finished, CONNECT_ONE_SHOT)
	GameManager.set_state(GameManager.State.MINIGAME)
	_layer.add_child(_current)
	minigame_started.emit(minigame_id)
	return true


func _on_finished(success: bool) -> void:
	var id := _current_id
	_current.queue_free()
	_current = null
	_current_id = ""
	GameManager.set_state(GameManager.State.PLAYING)
	GameActions.run(_on_success if success else _on_fail)
	minigame_finished.emit(id, success)

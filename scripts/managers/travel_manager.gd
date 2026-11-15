extends Node
## TravelManager (autoload): viagens pelo mapa de localidades (de fiacre).
##
## Destinos em data/travel.json:
##   {"destinations": [{"id", "name", "description", "map", "spawn",
##                      "pin": [x, y] (posição no mapa 0..1), "condition": {...}}]}
## Aberto pela ação {"type": "open_travel"} (ex.: conversa com o cocheiro).

signal travel_started(destination_id: String)

const DATA_PATH := "res://data/travel.json"
const UI_SCENE := "res://scenes/ui/travel_map.tscn"
const LAYER := 36

var destinations: Array = []
var _layer: CanvasLayer
var _ui: Node = null


func _ready() -> void:
	destinations = DataLoader.load_json(DATA_PATH).get("destinations", [])
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)


## Destinos liberados (condição atendida), exceto o mapa atual.
func get_available() -> Array:
	var current := SceneManager.current_map.map_id if SceneManager.current_map else ""
	var out := []
	for d in destinations:
		if d.get("map", "") != current and GameActions.check(d.get("condition")):
			out.append(d)
	return out


func is_open() -> bool:
	return _ui != null


func open() -> void:
	if is_open():
		return
	GameManager.set_state(GameManager.State.MENU)
	_ui = load(UI_SCENE).instantiate()
	_ui.setup(destinations, get_available())
	_ui.chosen.connect(_on_chosen)
	_ui.cancelled.connect(_close)
	_layer.add_child(_ui)


func _on_chosen(destination: Dictionary) -> void:
	_close()
	travel_started.emit(destination.get("id", ""))
	GameManager.notify("Viagem: %s" % destination.get("name", ""))
	SceneManager.change_map(destination.get("map", ""), destination.get("spawn", ""))


func _close() -> void:
	if _ui:
		_ui.queue_free()
		_ui = null
	if GameManager.state == GameManager.State.MENU:
		GameManager.set_state(GameManager.State.PLAYING)

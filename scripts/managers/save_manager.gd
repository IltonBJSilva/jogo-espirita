extends Node
## SaveManager (autoload): salvar e continuar o jogo (user://save.json).
##
## Cada sistema com estado fornece save_data() -> Dictionary e load_data(dict).
## A tela de título mostra "Continuar" quando existe um jogo salvo.

signal game_saved
signal game_loaded

const SAVE_PATH := "user://save.json"
const VERSION := 1

## Autoloads persistidos: chave no arquivo -> nome do nó na raiz.
const SYSTEMS := {
	"game": "GameManager",
	"inventory": "InventoryManager",
	"quests": "QuestManager",
	"encyclopedia": "EncyclopediaManager",
	"library": "LibraryManager",
	"relationships": "RelationshipManager",
	"progress": "ProgressManager",
}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var map := SceneManager.current_map
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if map == null or player == null:
		return false
	var data := {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"map": map.map_id,
		"position": [player.global_position.x, player.global_position.y],
	}
	for key in SYSTEMS:
		data[key] = get_node("/root/" + SYSTEMS[key]).save_data()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: não foi possível gravar %s" % SAVE_PATH)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	game_saved.emit()
	GameManager.notify("Jogo salvo")
	return true


## Info curta para a tela de título ("Paris, 1857 — 14/11 21:30").
func get_save_summary() -> String:
	var data := _read()
	if data.is_empty():
		return ""
	return "%s" % data.get("saved_at", "")


func load_game() -> bool:
	var data := _read()
	if data.is_empty():
		return false
	GameManager.new_game_started.emit()
	for key in SYSTEMS:
		if data.has(key):
			get_node("/root/" + SYSTEMS[key]).load_data(data[key])
	var pos: Array = data.get("position", [])
	await SceneManager.start_game(data.get("map", GameManager.START_MAP), "")
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and pos.size() == 2:
		player.global_position = Vector2(pos[0], pos[1])
		player.camera.reset_smoothing()
	game_loaded.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _read() -> Dictionary:
	if not has_save():
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	return parsed if parsed is Dictionary else {}

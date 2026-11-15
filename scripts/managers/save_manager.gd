extends Node
## SaveManager (autoload): salvar e carregar o jogo.
##
## Há um espaço de salvamento automático ("auto") e SLOT_COUNT espaços manuais
## (1..3), cada um em user://saves/<id>.json. Cada sistema com estado fornece
## save_data() -> Dictionary e load_data(dict) e está listado em SYSTEMS.
##
## O salvamento automático acontece ao trocar de mapa, a cada AUTOSAVE_INTERVAL
## segundos de jogo e quando o app vai para segundo plano ou é fechado
## (importante no Android, que pode encerrar o app sem aviso).

signal game_saved(slot: String)
signal game_loaded(slot: String)
signal saves_changed

const VERSION := 2
const AUTO := "auto"
const SLOT_COUNT := 3
const AUTOSAVE_INTERVAL := 180.0
## Intervalo mínimo entre dois salvamentos automáticos seguidos.
const AUTOSAVE_COOLDOWN := 15.0
const LEGACY_PATH := "user://save.json"

## Autoloads persistidos: chave no arquivo -> nome do nó na raiz.
const SYSTEMS := {
	"game": "GameManager",
	"inventory": "InventoryManager",
	"quests": "QuestManager",
	"encyclopedia": "EncyclopediaManager",
	"library": "LibraryManager",
	"relationships": "RelationshipManager",
	"progress": "ProgressManager",
	# --- sistema de vida ---
	"time": "TimeManager",
	"life": "LifeManager",
	"social": "SocialManager",
}

## Pasta dos saves (os testes usam outra para não apagar o jogo do usuário).
var save_dir := "user://saves"
## Espaço manual usado por último (o "Salvar jogo" rápido grava nele).
var current_slot := "1"
var autosave_enabled := true
## Segundos jogados nesta partida (persistido em cada save).
var play_time := 0.0

var _since_autosave := 0.0
var _last_autosave_msec := -100000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Cenas de teste (res://tests/...) usam uma pasta própria e não tocam no
	# jogo salvo do jogador.
	for arg in OS.get_cmdline_args():
		if arg.begins_with("res://tests/"):
			save_dir = "user://test_saves"
	_migrate_legacy()
	GameManager.new_game_started.connect(_on_new_game)
	GameManager.state_changed.connect(_on_state_changed)


func _process(delta: float) -> void:
	var state := GameManager.state
	if state == GameManager.State.TITLE or state == GameManager.State.TRANSITION:
		return
	play_time += delta
	if state != GameManager.State.PLAYING:
		return
	_since_autosave += delta
	if _since_autosave >= AUTOSAVE_INTERVAL:
		autosave()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			autosave(true)


# --- Espaços ------------------------------------------------------------------

## Todos os espaços, na ordem de exibição: ["auto", "1", "2", "3"].
func get_slots() -> Array[String]:
	var slots: Array[String] = [AUTO]
	for i in SLOT_COUNT:
		slots.append(str(i + 1))
	return slots


func slot_path(slot: String) -> String:
	return save_dir.path_join(slot + ".json")


func slot_name(slot: String) -> String:
	return "Salvamento automático" if slot == AUTO else "Espaço %s" % slot


func has_save(slot: String = "") -> bool:
	if slot != "":
		return FileAccess.file_exists(slot_path(slot))
	for s in get_slots():
		if FileAccess.file_exists(slot_path(s)):
			return true
	return false


## O espaço salvo mais recentemente ("" se não houver nenhum).
func get_latest_slot() -> String:
	var best := ""
	var best_time := -1.0
	for s in get_slots():
		var info := get_slot_info(s)
		if not info.is_empty() and float(info.get("saved_unix", 0)) > best_time:
			best_time = float(info.get("saved_unix", 0))
			best = s
	return best


## Resumo de um espaço para os menus (vazio se o espaço estiver livre):
## {"slot", "saved_at", "saved_unix", "location", "game_time", "quest", "play_time"}.
func get_slot_info(slot: String) -> Dictionary:
	var data := _read(slot)
	if data.is_empty():
		return {}
	var meta: Dictionary = data.get("meta", {})
	return {
		"slot": slot,
		"saved_at": data.get("saved_at", ""),
		"saved_unix": data.get("saved_unix", 0),
		"location": meta.get("location", data.get("map", "")),
		"game_time": meta.get("game_time", ""),
		"quest": meta.get("quest", ""),
		"play_time": float(data.get("play_time", 0.0)),
	}


## Texto curto de um espaço ("Paris, 1857 · ter 05/05/1857 09:30 · 0h12").
func get_save_summary(slot: String = "") -> String:
	var info := get_slot_info(slot if slot != "" else get_latest_slot())
	if info.is_empty():
		return ""
	var parts := PackedStringArray()
	for key in ["location", "game_time"]:
		if str(info[key]) != "":
			parts.append(str(info[key]))
	parts.append(format_play_time(info["play_time"]))
	return " · ".join(parts)


static func format_play_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	return "%dh%02d" % [minutes / 60, minutes % 60]


# --- Salvar -------------------------------------------------------------------

## Grava o jogo. Sem argumento, usa o último espaço manual escolhido.
func save_game(slot: String = "") -> bool:
	if slot == "":
		slot = current_slot
	var ok := _write(slot)
	if ok and slot != AUTO:
		current_slot = slot
		GameManager.notify("Jogo salvo (%s)" % slot_name(slot))
	return ok


## Salvamento automático silencioso. `force` ignora o intervalo mínimo.
func autosave(force: bool = false) -> bool:
	if not autosave_enabled or not _can_save_now():
		return false
	if not force and Time.get_ticks_msec() - _last_autosave_msec < AUTOSAVE_COOLDOWN * 1000.0:
		return false
	var ok := _write(AUTO)
	if ok:
		_last_autosave_msec = Time.get_ticks_msec()
		_since_autosave = 0.0
	return ok


func _can_save_now() -> bool:
	if SceneManager.current_map == null:
		return false
	if get_tree().get_first_node_in_group("player") == null:
		return false
	var state := GameManager.state
	return state != GameManager.State.TITLE and state != GameManager.State.TRANSITION \
			and state != GameManager.State.MINIGAME


func _write(slot: String) -> bool:
	var map := SceneManager.current_map
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if map == null or player == null:
		return false
	DirAccess.make_dir_recursive_absolute(save_dir)
	var data := {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"saved_unix": Time.get_unix_time_from_system(),
		"play_time": play_time,
		"map": map.map_id,
		"position": [player.global_position.x, player.global_position.y],
		"meta": {
			"location": map.display_name,
			"game_time": "%s %s" % [TimeManager.get_date_string(), TimeManager.get_time_string()],
			"quest": _active_quest_name(),
		},
	}
	for key in SYSTEMS:
		data[key] = get_node("/root/" + SYSTEMS[key]).save_data()
	# Grava num arquivo temporário e troca: um app encerrado no meio da gravação
	# não corrompe o save anterior.
	var path := slot_path(slot)
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: não foi possível gravar %s" % path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var dir := DirAccess.open(save_dir)
	if dir.rename(tmp.get_file(), path.get_file()) != OK:
		push_error("SaveManager: não foi possível finalizar %s" % path)
		return false
	game_saved.emit(slot)
	saves_changed.emit()
	return true


func _active_quest_name() -> String:
	var active := QuestManager.get_quests_by_status(QuestManager.Status.ACTIVE)
	if active.is_empty():
		return ""
	return QuestManager.get_quest(active[0]).get("name", active[0])


# --- Carregar -----------------------------------------------------------------

## Carrega um espaço. Sem argumento, o mais recente ("Continuar").
func load_game(slot: String = "") -> bool:
	if slot == "":
		slot = get_latest_slot()
	var data := _read(slot)
	if data.is_empty():
		return false
	GameManager.new_game_started.emit()
	for key in SYSTEMS:
		if data.has(key):
			get_node("/root/" + SYSTEMS[key]).load_data(data[key])
	play_time = float(data.get("play_time", 0.0))
	if slot != AUTO:
		current_slot = slot
	var pos: Array = data.get("position", [])
	await SceneManager.start_game(data.get("map", GameManager.START_MAP), "")
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and pos.size() == 2:
		player.global_position = Vector2(pos[0], pos[1])
		player.camera.reset_smoothing()
	_since_autosave = 0.0
	_last_autosave_msec = Time.get_ticks_msec()
	game_loaded.emit(slot)
	return true


## Apaga um espaço; sem argumento, apaga todos.
func delete_save(slot: String = "") -> void:
	var slots := get_slots()
	if slot != "":
		slots = [slot] as Array[String]
	for s in slots:
		if FileAccess.file_exists(slot_path(s)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(s)))
	saves_changed.emit()


func _read(slot: String) -> Dictionary:
	if slot == "" or not FileAccess.file_exists(slot_path(slot)):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(slot_path(slot)))
	return parsed if parsed is Dictionary else {}


# --- Eventos ------------------------------------------------------------------

func _on_new_game() -> void:
	play_time = 0.0
	_since_autosave = 0.0


func _on_state_changed(new_state: int, old_state: int) -> void:
	# Fim de uma troca de mapa: bom momento para o salvamento automático.
	if new_state == GameManager.State.PLAYING and old_state == GameManager.State.TRANSITION:
		autosave.call_deferred()


## Saves da versão 1 (user://save.json, espaço único) viram o Espaço 1.
func _migrate_legacy() -> void:
	if not FileAccess.file_exists(LEGACY_PATH):
		return
	DirAccess.make_dir_recursive_absolute(save_dir)
	if not FileAccess.file_exists(slot_path("1")):
		DirAccess.copy_absolute(LEGACY_PATH, slot_path("1"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_PATH))

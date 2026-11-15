extends Node
## GameManager (autoload): estado global do jogo.
##
## Guarda o modo atual (titulo, jogando, dialogo, pausa...), as flags de
## progresso da historia e os dados dos personagens (data/characters.json).
## Tambem inicia um novo jogo.

signal state_changed(new_state: State, old_state: State)
signal flag_changed(flag: String, value: Variant)
## Mensagem curta para o jogador (exibida pelo HUD).
signal notification_posted(text: String)
## Emitido ao iniciar um jogo novo (ou antes de carregar um salvo): os sistemas
## adicionados depois do MVP (enciclopédia, biblioteca, relações...) se zeram aqui.
signal new_game_started

## MENU: leitor de livros, mapa de viagem e outras telas que pausam o jogador.
enum State { TITLE, PLAYING, DIALOGUE, PAUSED, MINIGAME, TRANSITION, MENU }

const GAME_TITLE := "Jogo Espírita"
const GAME_SUBTITLE := "Paris, 1857"
const CHARACTERS_PATH := "res://data/characters.json"
const START_MAP := "paris_1857"
const START_SPAWN := "inicio"
const START_QUEST := "conhecendo_sociedade"

var state: State = State.TITLE
var flags: Dictionary = {}
var characters: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	characters = DataLoader.load_json(CHARACTERS_PATH).get("characters", {})


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		var mode := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED
				if mode == DisplayServer.WINDOW_MODE_FULLSCREEN
				else DisplayServer.WINDOW_MODE_FULLSCREEN)


# --- Estado -----------------------------------------------------------------

func set_state(new_state: State) -> void:
	if new_state == state:
		return
	var old := state
	state = new_state
	state_changed.emit(new_state, old)


func is_playing() -> bool:
	return state == State.PLAYING


# --- Novo jogo ----------------------------------------------------------------

func new_game() -> void:
	new_game_started.emit()
	flags.clear()
	InventoryManager.reset()
	QuestManager.reset()
	await SceneManager.start_game(START_MAP, START_SPAWN)
	QuestManager.start_quest(START_QUEST)


# --- Flags de progresso -----------------------------------------------------

func set_flag(flag: String, value: Variant = true) -> void:
	flags[flag] = value
	flag_changed.emit(flag, value)


func get_flag(flag: String, default: Variant = false) -> Variant:
	return flags.get(flag, default)


# --- Personagens --------------------------------------------------------------

## Dados de um personagem: {"name", "portrait", "title"...}.
func get_character(id: String) -> Dictionary:
	return characters.get(id, {})


func get_character_name(id: String) -> String:
	return get_character(id).get("name", "")


func notify(text: String) -> void:
	if text != "":
		notification_posted.emit(text)


# --- Salvar/carregar (SaveManager) ------------------------------------------

func save_data() -> Dictionary:
	return {"flags": flags.duplicate(true)}


func load_data(data: Dictionary) -> void:
	flags = data.get("flags", {}).duplicate(true)

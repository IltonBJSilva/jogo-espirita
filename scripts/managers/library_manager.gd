extends Node
## LibraryManager (autoload): livros, cartas e documentos legíveis (Biblioteca).
##
## Textos em data/books/*.json:
##   {"books": {"id": {"title", "author", "kind", "pages": [..], "unlocks": [entradas],
##                     "source"}}}
## kind: "livro", "carta", "documento", "jornal".
## Ler um texto o registra na Biblioteca e desbloqueia as entradas da Enciclopédia.

signal book_read(book_id: String)
signal reader_closed(book_id: String)

const DIR := "res://data/books/"
const READER_SCENE := "res://scenes/ui/book_reader.tscn"
const LAYER := 35

var books: Dictionary = {}
var _read: Array[String] = []
var _layer: CanvasLayer
var _reader: Node = null
var _previous_state := 0


func _ready() -> void:
	for data in DataLoader.load_json_dir(DIR).values():
		books.merge(data.get("books", {}))
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	GameManager.new_game_started.connect(reset)


func reset() -> void:
	_read.clear()


func get_book(book_id: String) -> Dictionary:
	return books.get(book_id, {})


func is_read(book_id: String) -> bool:
	return book_id in _read


func get_read_books() -> Array[String]:
	return _read.duplicate()


func is_open() -> bool:
	return _reader != null


## Abre o leitor. Funciona durante o jogo e também a partir do menu de pausa.
func open(book_id: String) -> void:
	if is_open():
		return
	var book := get_book(book_id)
	if book.is_empty():
		push_error("LibraryManager: texto '%s' não existe." % book_id)
		return
	if not book_id in _read:
		_read.append(book_id)
		book_read.emit(book_id)
		GameManager.notify("Biblioteca: %s" % book.get("title", book_id))
	for entry in book.get("unlocks", []):
		EncyclopediaManager.unlock(entry)
	_previous_state = GameManager.state
	if GameManager.state == GameManager.State.PLAYING:
		GameManager.set_state(GameManager.State.MENU)
	_reader = load(READER_SCENE).instantiate()
	_reader.setup(book_id, book)
	_reader.closed.connect(_on_reader_closed.bind(book_id), CONNECT_ONE_SHOT)
	_layer.add_child(_reader)


func _on_reader_closed(book_id: String) -> void:
	_reader.queue_free()
	_reader = null
	if GameManager.state == GameManager.State.MENU and _previous_state == GameManager.State.PLAYING:
		GameManager.set_state(GameManager.State.PLAYING)
	reader_closed.emit(book_id)


func save_data() -> Dictionary:
	return {"read": _read.duplicate()}


func load_data(data: Dictionary) -> void:
	_read.clear()
	for id in data.get("read", []):
		if books.has(id):
			_read.append(id)

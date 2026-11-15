extends Control
## Leitor de livros, cartas e documentos (aberto pelo LibraryManager).
## Setas ou E/Enter: virar a página · Esc: fechar.

signal closed

const KIND_LABELS := {"livro": "Livro", "carta": "Carta", "documento": "Documento", "jornal": "Jornal"}

var _book: Dictionary = {}
var _pages: Array = []
var _page := 0

@onready var title_label: Label = %Title
@onready var meta_label: Label = %Meta
@onready var text_label: RichTextLabel = %Text
@onready var page_label: Label = %PageLabel
@onready var prev_button: Button = %PrevButton
@onready var next_button: Button = %NextButton
@onready var close_button: Button = %CloseButton


func setup(_book_id: String, book: Dictionary) -> void:
	_book = book
	_pages = book.get("pages", [])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	title_label.text = _book.get("title", "")
	var meta: String = KIND_LABELS.get(_book.get("kind", ""), "Texto")
	if _book.get("author", "") != "":
		meta += " · " + _book["author"]
	meta_label.text = meta
	prev_button.pressed.connect(_turn.bind(-1))
	next_button.pressed.connect(_on_next)
	close_button.pressed.connect(_close)
	_show()
	next_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_close()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		_turn(-1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		_turn(1)
	elif event.is_action_pressed("interact"):
		if _page >= _pages.size() - 1:
			_close()
		else:
			_turn(1)
	else:
		return
	get_viewport().set_input_as_handled()


func _turn(step: int) -> void:
	_page = clampi(_page + step, 0, maxi(0, _pages.size() - 1))
	_show()


func _show() -> void:
	var text: String = _pages[_page] if _page < _pages.size() else ""
	if _page == _pages.size() - 1 and _book.get("source", "") != "":
		text += "\n\n[color=#8a6d4a][i]%s[/i][/color]" % _book["source"]
	text_label.text = text
	page_label.text = "%d / %d" % [_page + 1, maxi(1, _pages.size())]
	prev_button.disabled = _page == 0
	next_button.text = "Fechar" if _page >= _pages.size() - 1 else "Próxima ▸"


func _on_next() -> void:
	if _page >= _pages.size() - 1:
		_close()
	else:
		_turn(1)


func _close() -> void:
	closed.emit()

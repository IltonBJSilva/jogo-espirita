extends Minigame
## Minigame genérico de ordenação (cartas por data, etapas da imprensa,
## linha do tempo...). Selecione um cartão e depois outro para trocá-los.
##
## Parâmetros (data/minigames.json -> "params"):
##   "instructions": "...",
##   "items": ["primeiro", "segundo", ...]    (já na ordem CORRETA)
##   "conclusion": "texto exibido ao concluir"

var _correct: Array = []
var _order: Array[int] = []
var _selected := -1
var _done := false
var _cards: Array[Button] = []

@onready var title_label: Label = %Title
@onready var instructions_label: Label = %Instructions
@onready var list: VBoxContainer = %List
@onready var status_label: RichTextLabel = %Status
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	var params: Dictionary = info.get("params", {})
	_correct = params.get("items", [])
	title_label.text = info.get("title", "Organizar")
	instructions_label.text = params.get("instructions", info.get("description", ""))
	quit_button.pressed.connect(finish.bind(false))
	for i in _correct.size():
		_order.append(i)
	while _is_sorted() and _order.size() > 1:
		_order.shuffle()
	for slot in _order.size():
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_on_card.bind(slot))
		list.add_child(b)
		_cards.append(b)
	_refresh()
	_cards[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		finish(false)
	elif event.is_action_pressed("interact"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused in _cards:
			get_viewport().set_input_as_handled()
			focused.pressed.emit()


func _on_card(slot: int) -> void:
	if _done:
		return
	if _selected == -1:
		_selected = slot
	elif _selected == slot:
		_selected = -1
	else:
		var tmp := _order[slot]
		_order[slot] = _order[_selected]
		_order[_selected] = tmp
		_selected = -1
	_refresh()
	if _is_sorted():
		_done = true
		var conclusion: String = info.get("params", {}).get("conclusion", "")
		status_label.text = "[color=#8fbf8f]Tudo em ordem![/color] " + conclusion
		var done := Button.new()
		done.text = "Concluir"
		done.pressed.connect(finish.bind(true))
		quit_button.get_parent().add_child(done)
		done.grab_focus()


func _refresh() -> void:
	for slot in _cards.size():
		var b := _cards[slot]
		b.text = "%d.  %s" % [slot + 1, _correct[_order[slot]]]
		b.modulate = Color(1.0, 0.9, 0.55) if slot == _selected else Color.WHITE
	if not _done:
		status_label.text = ("Agora escolha onde colocar este cartão." if _selected != -1
				else "Escolha um cartão para mover.")


func _is_sorted() -> bool:
	for i in _order.size():
		if _order[i] != i:
			return false
	return true

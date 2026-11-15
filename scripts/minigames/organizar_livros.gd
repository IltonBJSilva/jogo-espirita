extends Minigame
## Minigame "Organizar a enciclopedia": coloque os tomos I a V em ordem.
## Selecione um tomo (E/Enter ou clique) e depois outro para trocar de lugar.
## Esc desiste.

const ROMAN := ["I", "II", "III", "IV", "V"]
const COLORS := [
	Color(0.43, 0.13, 0.19), Color(0.16, 0.3, 0.22), Color(0.14, 0.17, 0.31),
	Color(0.32, 0.19, 0.41), Color(0.55, 0.38, 0.17),
]

var _order: Array[int] = []
var _selected := -1
var _done := false
var _buttons: Array[Button] = []

@onready var shelf: HBoxContainer = %Shelf
@onready var status: Label = %Status


func _ready() -> void:
	%Title.text = info.get("title", "Organizar a enciclopédia")
	%Description.text = info.get("description", "")
	%GiveUpButton.pressed.connect(finish.bind(false))
	_order = [0, 1, 2, 3, 4]
	while _is_sorted():
		_order.shuffle()
	for i in _order.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(76, 170)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_on_book_pressed.bind(i))
		shelf.add_child(button)
		_buttons.append(button)
	_refresh()
	_buttons[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		finish(false)
	elif event.is_action_pressed("interact"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused in _buttons:
			get_viewport().set_input_as_handled()
			focused.pressed.emit()


func _on_book_pressed(slot: int) -> void:
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
		status.text = "Perfeito! Os tomos estão em ordem."
		await get_tree().create_timer(1.2).timeout
		finish(true)


func _refresh() -> void:
	for slot in _buttons.size():
		var tome := _order[slot]
		var button := _buttons[slot]
		button.text = "Tomo\n%s" % ROMAN[tome]
		var style := StyleBoxFlat.new()
		style.bg_color = COLORS[tome]
		style.border_color = Color(0.98, 0.83, 0.45) if slot == _selected else Color(0.79, 0.6, 0.29)
		style.set_border_width_all(4 if slot == _selected else 2)
		style.set_corner_radius_all(3)
		style.content_margin_top = 10
		for state in ["normal", "hover", "pressed", "focus"]:
			var s := style.duplicate() as StyleBoxFlat
			if state == "hover" or state == "focus":
				s.bg_color = COLORS[tome].lightened(0.15)
			button.add_theme_stylebox_override(state, s)
	if not _done:
		status.text = "Escolha outro tomo para trocar." if _selected != -1 else "Escolha um tomo."


func _is_sorted() -> bool:
	for i in _order.size():
		if _order[i] != i:
			return false
	return true

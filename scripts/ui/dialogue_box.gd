extends CanvasLayer
## Caixa de dialogo: nome, retrato, texto progressivo e opcoes de resposta.
## So apresenta; quem decide o fluxo e o DialogueManager.

const CHARS_PER_SECOND := 55.0
const BASE_HEIGHT := 174.0
const CHOICE_HEIGHT := 36.0

var _typing := false
var _shown_chars := 0.0
var _pending_choices: Array = []

@onready var box: PanelContainer = %Box
@onready var portrait_frame: PanelContainer = %PortraitFrame
@onready var portrait: TextureRect = %Portrait
@onready var name_label: Label = %NameLabel
@onready var text: RichTextLabel = %Text
@onready var choices: VBoxContainer = %Choices
@onready var indicator: Label = %Indicator


func _ready() -> void:
	box.hide()
	DialogueManager.line_shown.connect(_on_line_shown)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	box.gui_input.connect(_on_box_gui_input)


func _on_line_shown(line: Dictionary) -> void:
	box.show()
	name_label.text = line.get("name", "")
	name_label.visible = name_label.text != ""
	portrait.texture = line.get("portrait")
	portrait_frame.visible = portrait.texture != null
	text.text = line.get("text", "")
	# Narracao (sem orador) em italico suave.
	text.modulate = Color(1, 1, 1) if name_label.visible else Color(0.88, 0.84, 0.95)
	_clear_choices()
	_pending_choices = line.get("choices", [])
	indicator.hide()
	_shown_chars = 0.0
	text.visible_characters = 0
	_typing = true
	_fit_height()


func _process(delta: float) -> void:
	if not _typing:
		return
	_shown_chars += CHARS_PER_SECOND * delta
	text.visible_characters = int(_shown_chars)
	if text.visible_characters >= text.get_total_character_count():
		_finish_typing()


func _finish_typing() -> void:
	_typing = false
	text.visible_characters = -1
	if _pending_choices.is_empty():
		indicator.show()
		return
	for i in _pending_choices.size():
		var button := Button.new()
		button.text = _pending_choices[i]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_choice_pressed.bind(i))
		choices.add_child(button)
	_fit_height()
	(choices.get_child(0) as Button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not box.visible or not DialogueManager.is_active():
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_confirm()


func _on_box_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if choices.get_child_count() == 0:
			_confirm()


func _confirm() -> void:
	if _typing:
		_finish_typing()
		return
	if choices.get_child_count() > 0:
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and focused.get_parent() == choices:
			focused.pressed.emit()
		return
	DialogueManager.advance()


func _on_choice_pressed(index: int) -> void:
	_clear_choices()
	DialogueManager.choose(index)


func _on_dialogue_ended(_id: String) -> void:
	_typing = false
	_clear_choices()
	box.hide()


func _clear_choices() -> void:
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()


## Altura fixa para o texto; a caixa cresce para cima conforme o numero de opcoes.
func _fit_height() -> void:
	var needed := BASE_HEIGHT + CHOICE_HEIGHT * choices.get_child_count()
	box.offset_top = box.offset_bottom - needed

class_name SaveSlotsPanel
extends CenterContainer
## Tela de salvar/carregar: lista o salvamento automático e os espaços 1..3
## com local, data do jogo, missão e tempo jogado. Usada pela tela de título
## (modo LOAD) e pelo menu de pausa (SAVE e LOAD).
##
## Sobrescrever ou apagar um espaço pede confirmação (tocar duas vezes).

signal closed

enum Mode { SAVE, LOAD }

const GOLD := Color(0.92, 0.74, 0.38)
const MUTED := Color(0.75, 0.68, 0.6)
const CONFIRM_TIME := 3.0

var mode: Mode = Mode.LOAD

var _title: Label
var _rows: VBoxContainer
var _status: Label
var _back: Button
## botão aguardando confirmação -> texto original
var _confirming := {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	var header := HBoxContainer.new()
	vbox.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_color_override("font_color", GOLD)
	_title.add_theme_font_size_override("font_size", 24)
	header.add_child(_title)
	_back = Button.new()
	_back.text = "Voltar"
	_back.pressed.connect(close)
	header.add_child(_back)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	vbox.add_child(_rows)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", MUTED)
	_status.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_status)
	hide()


func open(new_mode: Mode) -> void:
	mode = new_mode
	_title.text = "Salvar jogo" if mode == Mode.SAVE else "Carregar jogo"
	_status.text = ("Escolha um espaço. O salvamento automático é feito ao trocar de local "
			+ "e a cada 3 minutos.") if mode == Mode.SAVE else "Escolha o jogo para continuar."
	_confirming.clear()
	_refresh()
	show()


func close() -> void:
	hide()
	closed.emit()


func _refresh() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var first_focus: Button = null
	for slot in SaveManager.get_slots():
		var info := SaveManager.get_slot_info(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_rows.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		row.add_child(text)
		var name_label := Label.new()
		name_label.text = SaveManager.slot_name(slot)
		name_label.add_theme_color_override("font_color", GOLD)
		name_label.add_theme_font_size_override("font_size", 18)
		text.add_child(name_label)
		var details := Label.new()
		details.add_theme_font_size_override("font_size", 14)
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if info.is_empty():
			details.text = "— vazio —"
			details.add_theme_color_override("font_color", MUTED)
		else:
			details.text = _describe(info)
		text.add_child(details)
		# Ação principal
		var action := Button.new()
		action.custom_minimum_size = Vector2(110, 0)
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if mode == Mode.SAVE:
			action.text = "Salvar"
			action.disabled = slot == SaveManager.AUTO
			if slot == SaveManager.AUTO:
				action.tooltip_text = "Este espaço é gravado sozinho."
			action.pressed.connect(_on_save.bind(slot, action, not info.is_empty()))
		else:
			action.text = "Carregar"
			action.disabled = info.is_empty()
			action.pressed.connect(_on_load.bind(slot))
		row.add_child(action)
		# Apagar
		var delete := Button.new()
		delete.text = "Apagar"
		delete.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		delete.disabled = info.is_empty()
		delete.pressed.connect(_on_delete.bind(slot, delete))
		row.add_child(delete)
		if first_focus == null and not action.disabled:
			first_focus = action
	(first_focus if first_focus else _back).grab_focus.call_deferred()


func _describe(info: Dictionary) -> String:
	var lines := PackedStringArray()
	var where := PackedStringArray()
	for key in ["location", "game_time"]:
		if str(info.get(key, "")) != "":
			where.append(str(info[key]))
	lines.append(" · ".join(where))
	if str(info.get("quest", "")) != "":
		lines.append("Missão: %s" % info["quest"])
	lines.append("Tempo de jogo %s · salvo em %s" % [
		SaveManager.format_play_time(info.get("play_time", 0.0)),
		_format_real_date(str(info.get("saved_at", "")))])
	return "\n".join(lines)


## "2026-11-15 21:30:12" -> "15/11 21:30"
func _format_real_date(text: String) -> String:
	var parts := text.split(" ")
	if parts.size() < 2:
		return text
	var date := parts[0].split("-")
	if date.size() < 3:
		return text
	return "%s/%s %s" % [date[2], date[1], parts[1].substr(0, 5)]


func _needs_confirm(button: Button) -> bool:
	if _confirming.has(button):
		_confirming.erase(button)
		return false
	_confirming[button] = button.text
	button.text = "Confirmar?"
	get_tree().create_timer(CONFIRM_TIME, true, false, true).timeout.connect(func():
		if is_instance_valid(button) and _confirming.has(button):
			button.text = _confirming[button]
			_confirming.erase(button))
	return true


func _on_save(slot: String, button: Button, occupied: bool) -> void:
	if occupied and _needs_confirm(button):
		_status.text = "Toque de novo para gravar por cima do %s." % SaveManager.slot_name(slot)
		return
	if SaveManager.save_game(slot):
		_status.text = "Jogo salvo no %s." % SaveManager.slot_name(slot)
	else:
		_status.text = "Não foi possível salvar agora."
	_refresh()


func _on_load(slot: String) -> void:
	for b in _rows.find_children("*", "Button", true, false):
		(b as Button).disabled = true
	_back.disabled = true
	_status.text = "Carregando..."
	SaveManager.load_game(slot)


func _on_delete(slot: String, button: Button) -> void:
	if _needs_confirm(button):
		_status.text = "Toque de novo para apagar o %s." % SaveManager.slot_name(slot)
		return
	SaveManager.delete_save(slot)
	_status.text = "%s apagado." % SaveManager.slot_name(slot)
	_refresh()

extends CanvasLayer
## TouchControls (autoload): controles na tela para celular/tablet.
##
## Joystick virtual (canto inferior esquerdo) que aciona move_*, botão de
## interagir e de correr (canto inferior direito) e atalhos para Menu, Diário,
## Inventário e Compêndio (canto superior direito). Os botões geram as mesmas
## ações do teclado (project.godot -> [input]), então nenhum sistema do jogo
## precisa saber que existe toque.
##
## Aparece só durante o jogo (estado PLAYING) e só em aparelhos com toque.
## Para testar no PC:  godot --path . -- --touch   (o mouse faz o papel do dedo).
##
## O botão "voltar" do Android abre/fecha o menu de pausa (ou fecha a tela aberta).

const JOY_RADIUS := 62.0
const KNOB_RADIUS := 26.0
const JOY_DEADZONE := 0.18
## Empurrar o joystick além disto faz o personagem correr.
const JOY_RUN := 0.92
const MOVE_ACTIONS := ["move_left", "move_right", "move_up", "move_down"]

## Ativo neste aparelho (toque disponível ou --touch).
var active := false
## Corrida travada pelo botão "Correr".
var run_locked := false

var _root: Control
var _joy_touch := -1
var _joy_vec := Vector2.ZERO
## índice do toque -> id do botão pressionado
var _button_touches := {}
var _buttons: Array[Dictionary] = []
var _font: Font


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	active = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() \
			or "--touch" in OS.get_cmdline_user_args()
	if "--touch" in OS.get_cmdline_user_args():
		Input.emulate_touch_from_mouse = true
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_controls)
	_root.resized.connect(_layout)
	add_child(_root)
	_font = ThemeDB.fallback_font
	var theme_font = ProjectSettings.get_setting("gui/theme/custom", "")
	if theme_font is String and theme_font != "":
		var theme := load(theme_font) as Theme
		if theme and theme.default_font:
			_font = theme.default_font
	_buttons = [
		{"id": "interact", "label": "Agir", "radius": 44.0, "action": "interact"},
		{"id": "run", "label": "Correr", "radius": 30.0, "action": ""},
		{"id": "pause", "label": "Menu", "radius": 22.0, "action": "pause"},
		{"id": "journal", "label": "Diário", "radius": 22.0, "action": "journal"},
		{"id": "inventory", "label": "Itens", "radius": 22.0, "action": "inventory"},
		{"id": "compendium", "label": "Comp.", "radius": 22.0, "action": "compendium"},
	]
	GameManager.state_changed.connect(_on_state_changed)
	InteractionManager.focus_changed.connect(func(_i): _root.queue_redraw())
	if active:
		get_tree().node_added.connect(_enlarge_button)
	_on_state_changed(GameManager.state, GameManager.state)
	_layout.call_deferred()


# --- Layout e desenho ---------------------------------------------------------

func _layout() -> void:
	var size := _root.size
	for b in _buttons:
		match b["id"]:
			"interact":
				b["center"] = Vector2(size.x - 78, size.y - 150)
			"run":
				b["center"] = Vector2(size.x - 170, size.y - 112)
			"pause":
				b["center"] = Vector2(size.x - 36, 106)
			"journal":
				b["center"] = Vector2(size.x - 88, 106)
			"inventory":
				b["center"] = Vector2(size.x - 140, 106)
			"compendium":
				b["center"] = Vector2(size.x - 192, 106)
	_root.queue_redraw()


func _joy_center() -> Vector2:
	return Vector2(104, _root.size.y - 104)


func _draw_controls() -> void:
	if not _root.visible:
		return
	# Joystick
	var c := _joy_center()
	_root.draw_circle(c, JOY_RADIUS, Color(0.06, 0.03, 0.07, 0.38))
	_root.draw_arc(c, JOY_RADIUS, 0, TAU, 48, Color(0.93, 0.75, 0.4, 0.55), 2.0, true)
	var knob := c + _joy_vec * JOY_RADIUS
	var knob_color := Color(0.93, 0.75, 0.4, 0.85) if _joy_vec.length() >= JOY_RUN \
			else Color(0.95, 0.9, 0.82, 0.6)
	_root.draw_circle(knob, KNOB_RADIUS, knob_color)
	# Botões
	for b in _buttons:
		var pressed: bool = b["id"] in _button_touches.values()
		var lit := pressed
		if b["id"] == "run":
			lit = lit or run_locked
		if b["id"] == "interact":
			lit = lit or InteractionManager.focused != null
		var fill := Color(0.93, 0.75, 0.4, 0.75) if lit else Color(0.06, 0.03, 0.07, 0.5)
		if pressed:
			fill = Color(1.0, 0.9, 0.6, 0.9)
		var r: float = b["radius"]
		_root.draw_circle(b["center"], r, fill)
		_root.draw_arc(b["center"], r, 0, TAU, 40, Color(0.93, 0.75, 0.4, 0.8), 2.0, true)
		var font_size := 15 if r > 35 else (13 if r > 25 else 10)
		var text: String = b["label"]
		var text_color := Color(0.12, 0.05, 0.08) if lit else Color(0.98, 0.93, 0.85)
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var asc := _font.get_ascent(font_size) - _font.get_descent(font_size)
		_root.draw_string(_font, b["center"] + Vector2(-w / 2.0, asc / 2.0), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


# --- Entrada ------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not active or not _root.visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_touch_down(event.index, event.position)
		else:
			_on_touch_up(event.index)
	elif event is InputEventScreenDrag and event.index == _joy_touch:
		_update_joystick(event.position)
		get_viewport().set_input_as_handled()


func _on_touch_down(index: int, pos: Vector2) -> void:
	for b in _buttons:
		if pos.distance_to(b["center"]) <= float(b["radius"]) + 10.0:
			_button_touches[index] = b["id"]
			_press_button(b)
			get_viewport().set_input_as_handled()
			_root.queue_redraw()
			return
	# Joystick: qualquer toque na metade esquerda, parte de baixo da tela.
	if _joy_touch == -1 and pos.x < _root.size.x * 0.45 and pos.y > _root.size.y * 0.35:
		_joy_touch = index
		_update_joystick(pos)
		get_viewport().set_input_as_handled()


func _on_touch_up(index: int) -> void:
	if index == _joy_touch:
		_joy_touch = -1
		_set_joystick(Vector2.ZERO)
		get_viewport().set_input_as_handled()
	elif _button_touches.has(index):
		var id: String = _button_touches[index]
		_button_touches.erase(index)
		for b in _buttons:
			if b["id"] == id and b["action"] != "":
				_send_action(b["action"], false)
		get_viewport().set_input_as_handled()
		_root.queue_redraw()


func _press_button(b: Dictionary) -> void:
	if b["id"] == "run":
		run_locked = not run_locked
		if not run_locked:
			Input.action_release("run")
		return
	_send_action(b["action"], true)


func _update_joystick(pos: Vector2) -> void:
	var v := (pos - _joy_center()) / JOY_RADIUS
	if v.length() > 1.0:
		v = v.normalized()
	_set_joystick(v)


func _set_joystick(v: Vector2) -> void:
	_joy_vec = v
	var strength := v
	if v.length() < JOY_DEADZONE:
		strength = Vector2.ZERO
	_set_axis("move_left", "move_right", strength.x)
	_set_axis("move_up", "move_down", strength.y)
	if run_locked or v.length() >= JOY_RUN:
		Input.action_press("run")
	else:
		Input.action_release("run")
	_root.queue_redraw()


func _set_axis(neg: String, pos: String, value: float) -> void:
	if value < 0.0:
		Input.action_press(neg, -value)
		Input.action_release(pos)
	elif value > 0.0:
		Input.action_press(pos, value)
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


## Gera a ação como se fosse uma tecla (passa por _unhandled_input dos sistemas).
func _send_action(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func release_all() -> void:
	_joy_touch = -1
	for id in _button_touches.values():
		for b in _buttons:
			if b["id"] == id and b["action"] != "":
				_send_action(b["action"], false)
	_button_touches.clear()
	_joy_vec = Vector2.ZERO
	for a in MOVE_ACTIONS:
		Input.action_release(a)
	Input.action_release("run")
	_root.queue_redraw()


# --- Estado do jogo -------------------------------------------------------------

func _on_state_changed(new_state: int, _old: int) -> void:
	_root.visible = active and new_state == GameManager.State.PLAYING
	if not _root.visible:
		release_all()
	elif run_locked:
		Input.action_press("run")
	_root.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Botão "voltar" do Android: no título fecha o app; no jogo, abre/fecha a
		# pausa ou fecha a tela aberta (livro, mapa, minigame), como o Esc.
		if GameManager.state == GameManager.State.TITLE:
			get_tree().quit()
		else:
			_send_action("pause", true)
			_send_action.call_deferred("pause", false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_all()


## No celular, botões das telas (menus, diálogos, minigames) ficam mais altos
## para caber o dedo.
func _enlarge_button(node: Node) -> void:
	if node is Button:
		var b := node as Button
		b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 40.0)

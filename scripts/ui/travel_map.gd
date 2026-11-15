extends Control
## Mapa de localidades (viagem de fiacre). Mostra todos os destinos: os liberados
## podem ser escolhidos; os bloqueados aparecem com a dica de como liberá-los.

signal chosen(destination: Dictionary)
signal cancelled

var _all: Array = []
var _available: Array = []

@onready var map_rect: TextureRect = %Map
@onready var pins: Control = %Pins
@onready var list: VBoxContainer = %List
@onready var description: Label = %Description


func setup(all_destinations: Array, available: Array) -> void:
	_all = all_destinations
	_available = available


func _ready() -> void:
	%CancelButton.pressed.connect(func(): cancelled.emit())
	var first: Button = null
	for d in _all:
		var ok: bool = _available.has(d)
		var current: bool = SceneManager.current_map != null and d.get("map", "") == SceneManager.current_map.map_id
		var b := Button.new()
		b.text = d.get("name", "") + ("  (você está aqui)" if current else "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not ok
		b.focus_entered.connect(_describe.bind(d, ok, current))
		b.mouse_entered.connect(_describe.bind(d, ok, current))
		if ok:
			b.pressed.connect(func(): chosen.emit(d))
			if first == null:
				first = b
		list.add_child(b)
		_add_pin(d, ok, current)
	if first:
		first.grab_focus()
	else:
		%CancelButton.grab_focus()
		description.text = "Nenhum destino novo por enquanto. Continue a história para descobrir outros lugares."


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancelled.emit()
	elif event.is_action_pressed("interact"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and not focused.disabled:
			get_viewport().set_input_as_handled()
			focused.pressed.emit()


func _describe(d: Dictionary, ok: bool, current: bool) -> void:
	var text: String = d.get("description", "")
	if current:
		text += "\nVocê já está aqui."
	elif not ok:
		text += "\n" + d.get("locked_hint", "Ainda não disponível.")
	description.text = text


func _add_pin(d: Dictionary, ok: bool, current: bool) -> void:
	var pin: Array = d.get("pin", [])
	if pin.size() != 2:
		return
	var dot := Label.new()
	dot.text = "●" if ok or current else "○"
	dot.add_theme_color_override("font_color",
			Color(0.43, 0.13, 0.19) if current else (Color(0.2, 0.5, 0.25) if ok else Color(0.45, 0.4, 0.35)))
	dot.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	dot.add_theme_font_size_override("font_size", 18)
	var name_label := Label.new()
	name_label.text = d.get("name", "")
	name_label.add_theme_color_override("font_color", Color(0.25, 0.14, 0.08))
	name_label.add_theme_color_override("font_shadow_color", Color(1, 0.95, 0.85, 0.6))
	name_label.add_theme_font_size_override("font_size", 11)
	pins.add_child(dot)
	pins.add_child(name_label)
	dot.set_meta("pin", Vector2(pin[0], pin[1]))
	name_label.set_meta("pin_label", dot)
	_place_pins()


## Posiciona os pinos sobre a área real da imagem (o mapa mantém a proporção
## e fica centralizado); refeito sempre que o mapa muda de tamanho.
func _place_pins() -> void:
	if not map_rect.resized.is_connected(_place_pins):
		map_rect.resized.connect(_place_pins)
	var tex_size := map_rect.texture.get_size()
	var k := minf(map_rect.size.x / tex_size.x, map_rect.size.y / tex_size.y)
	var drawn := tex_size * k
	var origin := (map_rect.size - drawn) / 2.0
	for child in pins.get_children():
		if child.has_meta("pin"):
			var p: Vector2 = child.get_meta("pin")
			child.position = origin + p * drawn - Vector2(6, 14)
	for child in pins.get_children():
		if child.has_meta("pin_label"):
			child.position = (child.get_meta("pin_label") as Control).position + Vector2(14, 2)

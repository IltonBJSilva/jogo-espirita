extends Node
## EnvironmentManager (autoload): iluminação conforme o horário (dia e noite).
## Contrato: docs/VIDA_CONTRATOS.md (seção 2). Dados: data/world/lighting.json.
##
## Cria no mapa atual um CanvasModulate ("DayNight") e um nó "EnvLights" com
## PointLight2D (lampiões, janelas, velas). Atualiza a cada minuto de jogo,
## nunca por frame. O HUD (CanvasLayers) não é afetado.

const DATA_PATH := "res://data/world/lighting.json"

var data: Dictionary = {}
var _modulate: CanvasModulate = null
var _lights: Array[PointLight2D] = []  # luzes do mapa atual
var _light_base: Array[float] = []      # energia máxima de cada luz
var _profile: Dictionary = {}
var _texture: Texture2D
var _color := Color.WHITE
var _night := 0.0


func _ready() -> void:
	data = DataLoader.load_json(DATA_PATH)
	_texture = _make_light_texture()
	SceneManager.map_changed.connect(_on_map_changed)
	TimeManager.minute_changed.connect(_on_minute)
	TimeManager.time_jumped.connect(_on_minute)


## Cor atual da luz ambiente do mapa (branco = sem alteração).
func get_light_color() -> Color:
	return _color


## Intensidade das luzes artificiais (0 = dia, 1 = noite plena).
func get_night_factor() -> float:
	return _night


## Reaplica a iluminação ao mapa atual (ex.: depois de trocar o mapa).
func refresh() -> void:
	_setup_map()
	_update()


func _on_map_changed(_map_id: String, _display_name: String) -> void:
	refresh()


func _on_minute(_total: int) -> void:
	_update()


func _setup_map() -> void:
	_lights.clear()
	_light_base.clear()
	_modulate = null
	var map := SceneManager.current_map
	if map == null or not is_instance_valid(map):
		_profile = {}
		return
	var map_cfg: Dictionary = data.get("maps", {}).get(map.map_id, {})
	var profile_id: String = map_cfg.get("profile", data.get("default_profile", "indoor"))
	_profile = data.get("profiles", {}).get(profile_id, {})
	if _profile.is_empty():
		return
	_modulate = map.get_node_or_null("DayNight") as CanvasModulate
	if _modulate == null:
		_modulate = CanvasModulate.new()
		_modulate.name = "DayNight"
		map.add_child(_modulate)
	var holder := map.get_node_or_null("EnvLights")
	if holder == null:
		holder = Node2D.new()
		holder.name = "EnvLights"
		map.add_child(holder)
	for child in holder.get_children():
		child.queue_free()
	var types: Dictionary = data.get("light_types", {})
	for l in map_cfg.get("lights", []):
		var t: Dictionary = types.get(l.get("type", "candle"), {})
		var light := PointLight2D.new()
		light.texture = _texture
		var c: Array = t.get("color", [1, 0.8, 0.5])
		light.color = Color(c[0], c[1], c[2])
		light.texture_scale = float(t.get("scale", 1.0))
		light.position = Vector2(l["pos"][0], l["pos"][1])
		light.energy = 0.0
		holder.add_child(light)
		_lights.append(light)
		_light_base.append(float(t.get("energy", 1.0)))


func _update() -> void:
	if _modulate == null or not is_instance_valid(_modulate):
		_color = Color.WHITE
		_night = 0.0
		return
	var minute := TimeManager.get_minute_of_day()
	var cols: Array = _profile.get("colors", [])
	if not cols.is_empty():
		var c: Array = _sample(cols, minute)
		_color = Color(c[0], c[1], c[2])
		_modulate.color = _color
	_night = float(_sample(_profile.get("lights_curve", [["00:00", 0.0]]), minute))
	for i in _lights.size():
		if is_instance_valid(_lights[i]):
			_lights[i].energy = _light_base[i] * _night
			_lights[i].visible = _night > 0.01


## Interpolação cíclica de keyframes [["HH:MM", valor], ...] (valor = número ou [r,g,b]).
func _sample(keys: Array, minute: int) -> Variant:
	var pts := []
	for k in keys:
		pts.append([TimeManager.parse_hhmm(k[0]), k[1]])
	pts.sort_custom(func(a, b): return a[0] < b[0])
	var prev: Array = pts[-1]
	var prev_t: int = prev[0] - 1440
	for p in pts:
		if minute < p[0]:
			return _lerp_value(prev[1], p[1], float(minute - prev_t) / float(p[0] - prev_t))
		prev = p
		prev_t = p[0]
	var first: Array = pts[0]
	return _lerp_value(prev[1], first[1], float(minute - prev_t) / float(first[0] + 1440 - prev_t))


func _lerp_value(a: Variant, b: Variant, t: float) -> Variant:
	t = clampf(t, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)  # suaviza as transições
	if a is Array:
		return [lerpf(a[0], b[0], t), lerpf(a[1], b[1], t), lerpf(a[2], b[2], t)]
	return lerpf(float(a), float(b), t)


## Gradiente radial gerado em código (sem assets novos).
func _make_light_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.45))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex

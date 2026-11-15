extends SceneTree
## Construtor de recursos do mundo (rodar fora do jogo, pela linha de comando):
##
##   godot --headless --path . --import
##   godot --headless --path . --script res://scripts/tools/build_world.gd
##
## Gera, a partir dos PNGs e dos layouts em data/maps/:
##   resources/tilesets/<mapa>.tres                 TileSet (arte, foreground e colisao)
##   scenes/maps/<mapa>/<mapa>_tiles.tscn           camadas Ground/Environment/Decoration/Collision
##   scenes/maps/<mapa>/<mapa>_foreground.tscn      camada Foreground com Y-Sort por objeto
##                                                  (instanciada dentro de Interactive)
##   resources/sprite_frames/<personagem>.tres      SpriteFrames dos personagens
##
## As cenas dos mapas (scenes/maps/<mapa>/<mapa>.tscn) apenas instanciam
## <mapa>_tiles.tscn, entao NPCs, portas e gatilhos editados no editor nao
## sao sobrescritos ao reconstruir.

const TILE := 32
const FRAME_SIZE := Vector2i(72, 92)

const MAPS := [
	{
		"id": "paris_1857",
		"atlas": "res://assets/tilesets/paris_1857/paris_1857_atlas.png",
		"foreground": "res://assets/tilesets/paris_1857/paris_1857_foreground.png",
		"layout": "res://data/maps/paris_1857_layout.json",
	},
	{
		"id": "livraria",
		"atlas": "res://assets/tilesets/livraria/livraria_atlas.png",
		"foreground": "",
		"layout": "res://data/maps/livraria_layout.json",
	},	# --- Expansão (tools/build_interiors.py) ---
	{
		"id": "residencia_kardec",
		"atlas": "res://assets/tilesets/residencia_kardec/residencia_kardec_atlas.png",
		"foreground": "",
		"layout": "res://data/maps/residencia_kardec_layout.json",
	},
	{
		"id": "sociedade_salao",
		"atlas": "res://assets/tilesets/sociedade_salao/sociedade_salao_atlas.png",
		"foreground": "",
		"layout": "res://data/maps/sociedade_salao_layout.json",
	},
	{
		"id": "tipografia",
		"atlas": "res://assets/tilesets/tipografia/tipografia_atlas.png",
		"foreground": "",
		"layout": "res://data/maps/tipografia_layout.json",
	},
	# --- Plano espiritual (tools/build_spiritual.py) ---
	{
		"id": "plano_espiritual",
		"atlas": "res://assets/tilesets/plano_espiritual/plano_espiritual_atlas.png",
		"foreground": "",
		"layout": "res://data/maps/plano_espiritual_layout.json",
	},
]

const CHARACTERS := ["kardec", "estudante", "livreiro", "estudioso", "moradora",
		"amelie", "medium", "medico", "impressor", "cocheiro", "crianca", "espirito_guia"]
## animacao -> velocidade (fps)
const ANIMATIONS := {
	"idle_down": 2.0, "idle_side": 2.0, "idle_up": 2.0,
	"walk_down": 7.0, "walk_side": 10.0, "walk_up": 7.0,
	"run_down": 11.0, "run_side": 13.0, "run_up": 11.0,
	"talk": 5.0, "study": 1.5,
}
## Duracao relativa de cada frame (opcional), por personagem/animacao.
## Ex.: respiracao lenta com uma piscada rapida no 3o frame.
const FRAME_DURATIONS := {
	"estudante": {"idle_down": [3.0, 3.0, 0.5, 3.0]},
	"amelie": {"idle_down": [3.0, 3.0, 0.5, 3.0]},
	"medium": {"idle_down": [3.0, 3.0, 0.5, 3.0]},
	"medico": {"idle_down": [3.0, 3.0, 0.5, 3.0]},
	"impressor": {"idle_down": [3.0, 3.0, 0.5, 3.0]},
	"cocheiro": {"idle_down": [3.0, 3.0, 0.5, 3.0]},
	"crianca": {"idle_down": [3.0, 3.0, 0.5, 3.0]},
	"espirito_guia": {"idle_down": [3.0, 3.0, 0.5, 3.0]},
}

const SOURCE_ART := 0
const SOURCE_FOREGROUND := 1
const SOURCE_COLLISION := 2


func _initialize() -> void:
	for map in MAPS:
		_build_map(map)
	for character in CHARACTERS:
		_build_sprite_frames(character)
	print("build_world: concluido.")
	quit()


# --- Mapas --------------------------------------------------------------------

func _build_map(map: Dictionary) -> void:
	var id: String = map["id"]
	var layout := _load_json(map["layout"])
	var cols: int = layout["cols"]
	var rows: int = layout["rows"]

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)  # camada "world"
	tileset.set_physics_layer_collision_mask(0, 0)

	var art := _atlas_source(map["atlas"])
	tileset.add_source(art, SOURCE_ART)
	for y in rows:
		for x in cols:
			art.create_tile(Vector2i(x, y))

	# Foreground: [x, y, base_y]. Cada tile ordena (Y-Sort) pela base do seu
	# objeto (pe do tronco/poste), nao pela propria posicao.
	var fg_bases := {}
	for entry in layout.get("foreground", []):
		fg_bases[Vector2i(int(entry[0]), int(entry[1]))] = int(entry[2])
	if map["foreground"] != "":
		var fg := _atlas_source(map["foreground"])
		tileset.add_source(fg, SOURCE_FOREGROUND)
		for cell in fg_bases:
			fg.create_tile(cell)
			var center_y: int = cell.y * TILE + TILE / 2
			fg.get_tile_data(cell, 0).y_sort_origin = fg_bases[cell] - center_y

	_add_collision_source(tileset)

	var tileset_path := "res://resources/tilesets/%s.tres" % id
	_ensure_dir(tileset_path)
	_check(ResourceSaver.save(tileset, tileset_path, ResourceSaver.FLAG_CHANGE_PATH), tileset_path)

	var env := _cells(layout.get("environment", []))
	var deco := _cells(layout.get("decoration", []))
	var root := Node2D.new()
	root.name = "Tiles"

	var ground := _layer(root, "Ground", tileset)
	var environment := _layer(root, "Environment", tileset)
	var decoration := _layer(root, "Decoration", tileset)
	for y in rows:
		for x in cols:
			var cell := Vector2i(x, y)
			var target := ground
			if env.has(cell):
				target = environment
			elif deco.has(cell):
				target = decoration
			target.set_cell(cell, SOURCE_ART, cell)

	var collision := _layer(root, "Collision", tileset)
	collision.set_script(load("res://scripts/maps/collision_layer.gd"))
	for cell in _cells(layout.get("solid", [])):
		collision.set_cell(cell, SOURCE_COLLISION, Vector2i.ZERO)

	for layer in [ground, environment, decoration]:
		layer.collision_enabled = false

	var scene := PackedScene.new()
	_check(scene.pack(root), "pack %s" % id)
	var scene_path := "res://scenes/maps/%s/%s_tiles.tscn" % [id, id]
	_ensure_dir(scene_path)
	_check(ResourceSaver.save(scene, scene_path), scene_path)
	root.free()

	if map["foreground"] != "":
		var foreground := TileMapLayer.new()
		foreground.name = "Foreground"
		foreground.tile_set = tileset
		foreground.y_sort_enabled = true
		foreground.set_script(load("res://scripts/maps/foreground_layer.gd"))
		foreground.collision_enabled = false
		for cell in fg_bases:
			foreground.set_cell(cell, SOURCE_FOREGROUND, cell)
		var fg_scene := PackedScene.new()
		_check(fg_scene.pack(foreground), "pack foreground %s" % id)
		var fg_path := "res://scenes/maps/%s/%s_foreground.tscn" % [id, id]
		_check(ResourceSaver.save(fg_scene, fg_path), fg_path)
		foreground.free()
	print("mapa ok: ", id)


func _atlas_source(texture_path: String) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = load(texture_path)
	source.texture_region_size = Vector2i(TILE, TILE)
	return source


## A fonte precisa estar no TileSet (que tem a camada de fisica) antes de
## receber o poligono de colisao.
func _add_collision_source(tileset: TileSet) -> void:
	var image := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.9, 0.15, 0.2, 0.55))
	for i in TILE:  # borda para enxergar as celulas no editor
		for p in [Vector2i(i, 0), Vector2i(i, TILE - 1), Vector2i(0, i), Vector2i(TILE - 1, i)]:
			image.set_pixelv(p, Color(1, 0.4, 0.4, 0.9))
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(TILE, TILE)
	tileset.add_source(source, SOURCE_COLLISION)
	source.create_tile(Vector2i.ZERO)
	var data := source.get_tile_data(Vector2i.ZERO, 0)
	var h := TILE / 2.0
	data.add_collision_polygon(0)
	data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))


func _layer(root: Node, layer_name: String, tileset: TileSet) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tileset
	root.add_child(layer)
	layer.owner = root
	return layer


func _cells(list: Array) -> Dictionary:
	var out := {}
	for c in list:
		out[Vector2i(int(c[0]), int(c[1]))] = true
	return out


# --- Personagens ----------------------------------------------------------------

func _build_sprite_frames(character: String) -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim in ANIMATIONS:
		var path := "res://assets/characters/%s/%s_%s.png" % [character, character, anim]
		if not ResourceLoader.exists(path):
			continue
		var texture: Texture2D = load(path)
		var count := int(texture.get_width() / FRAME_SIZE.x)
		frames.add_animation(anim)
		frames.set_animation_speed(anim, ANIMATIONS[anim])
		frames.set_animation_loop(anim, true)
		var durations: Array = FRAME_DURATIONS.get(character, {}).get(anim, [])
		for i in count:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(i * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
			frames.add_frame(anim, atlas, durations[i] if i < durations.size() else 1.0)
	var out := "res://resources/sprite_frames/%s.tres" % character
	_ensure_dir(out)
	_check(ResourceSaver.save(frames, out), out)
	print("personagem ok: ", character, " ", frames.get_animation_names())


# --- Utilitarios ------------------------------------------------------------------

func _load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _ensure_dir(file_path: String) -> void:
	DirAccess.make_dir_recursive_absolute(file_path.get_base_dir())


func _check(err: int, what: String) -> void:
	if err != OK:
		push_error("build_world: falha em %s (erro %d)" % [what, err])

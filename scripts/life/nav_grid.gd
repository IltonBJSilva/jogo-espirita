class_name LifeNavGrid
extends RefCounted
## Navegação dos NPCs: AStarGrid2D (células de 32 px, 4 direções) montado a partir
## da colisão dos mapas (data/maps/<mapa>_layout.json, lista "solid") + bordas.
## Um grid por mapa, em cache (montado uma vez).

const TILE := 32
static var _cache: Dictionary = {}


static func get_grid(map_id: String) -> AStarGrid2D:
	if _cache.has(map_id):
		return _cache[map_id]
	var layout := DataLoader.load_json("res://data/maps/%s_layout.json" % map_id)
	if layout.is_empty():
		return null
	var cols: int = layout["cols"]
	var rows: int = layout["rows"]
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, cols, rows)
	grid.cell_size = Vector2(TILE, TILE)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.update()
	for c in layout.get("solid", []):
		grid.set_point_solid(Vector2i(int(c[0]), int(c[1])), true)
	for x in cols:  # bordas do mapa
		grid.set_point_solid(Vector2i(x, 0), true)
		grid.set_point_solid(Vector2i(x, rows - 1), true)
	for y in rows:
		grid.set_point_solid(Vector2i(0, y), true)
		grid.set_point_solid(Vector2i(cols - 1, y), true)
	_cache[map_id] = grid
	return grid


static func to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE + TILE / 2.0 + 6.0)


static func is_free(map_id: String, pos: Vector2) -> bool:
	var grid := get_grid(map_id)
	if grid == null:
		return true
	var cell := to_cell(pos)
	return grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)


## Célula livre mais próxima (procura em anéis).
static func nearest_free(map_id: String, cell: Vector2i) -> Vector2i:
	var grid := get_grid(map_id)
	if grid == null or (grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)):
		return cell
	for r in range(1, 8):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var c := cell + Vector2i(dx, dy)
				if grid.is_in_boundsv(c) and not grid.is_point_solid(c):
					return c
	return cell


## Caminho em pixels (centros de célula) de from até to; o último ponto é o destino exato.
static func find_path(map_id: String, from: Vector2, to: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var grid := get_grid(map_id)
	if grid == null:
		out.append(to)
		return out
	var a := nearest_free(map_id, to_cell(from))
	var b := nearest_free(map_id, to_cell(to))
	var cells := grid.get_id_path(a, b)
	if cells.is_empty():
		return out  # sem caminho: o chamador decide (teleporte discreto)
	for i in range(1, cells.size()):
		out.append(cell_center(cells[i]))
	if out.is_empty() or out[out.size() - 1].distance_to(to) > 1.0:
		if out.size() > 0:
			out[out.size() - 1] = to
		else:
			out.append(to)
	return out

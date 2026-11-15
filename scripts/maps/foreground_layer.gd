extends TileMapLayer
## Camada "Foreground" (arvores, lampioes): cada tile e ordenado pelo Y-Sort
## na base do seu objeto (pe do tronco/poste), definido no TileSet.
## Quando o jogador fica escondido atras de um objeto, a camada fica
## semitransparente para ele nao se perder de vista.

const HIDDEN_ALPHA := 0.55
const FADE_SPEED := 6.0
## Pontos do corpo do jogador (relativos aos pes) testados contra os objetos.
const PROBES := [Vector2(0, -12), Vector2(0, -40), Vector2(0, -70)]


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var target := HIDDEN_ALPHA if player and _is_behind(player) else 1.0
	self_modulate.a = move_toward(self_modulate.a, target, FADE_SPEED * delta)


func _is_behind(player: Node2D) -> bool:
	var feet_y := to_local(player.global_position).y
	for probe in PROBES:
		var cell := local_to_map(to_local(player.global_position + probe))
		var data := get_cell_tile_data(cell)
		if data == null:
			continue
		var base_y := map_to_local(cell).y + data.y_sort_origin
		if base_y > feet_y:
			return true
	return false

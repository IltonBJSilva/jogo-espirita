class_name GameMap
extends Node2D
## Raiz de todo mapa jogavel.
##
## Estrutura esperada:
##   GameMap
##     Tiles        (cena gerada: Ground, Environment, Decoration, Collision, Foreground)
##     Interactive  (Node2D com Y-Sort: NPCs, objetos, portas, gatilhos e o jogador)
##     Spawns       (SpawnPoint: pontos de entrada no mapa)

@export var map_id := ""
@export var display_name := ""
## Tamanho do mapa em pixels (limites da camera).
@export var map_size := Vector2i(1536, 1024)

@onready var interactive: Node2D = $Interactive
@onready var spawns: Node = $Spawns


func _ready() -> void:
	_add_map_edges()


## Paredes invisiveis nas bordas, para o jogador nunca sair do mapa.
func _add_map_edges() -> void:
	var body := StaticBody2D.new()
	body.name = "MapEdges"
	body.collision_layer = 1
	body.collision_mask = 0
	var t := 32.0
	var w := float(map_size.x)
	var h := float(map_size.y)
	for r in [Rect2(-t, -t, w + 2 * t, t), Rect2(-t, h, w + 2 * t, t),
			Rect2(-t, 0, t, h), Rect2(w, 0, t, h)]:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.get_center()
		body.add_child(shape)
	add_child(body)


func get_entities_root() -> Node2D:
	return interactive


func get_bounds() -> Rect2i:
	return Rect2i(Vector2i.ZERO, map_size)


## Devolve o SpawnPoint pelo nome (ou o primeiro, se nao existir).
func get_spawn(spawn_name: String) -> SpawnPoint:
	if spawn_name != "" and spawns.has_node(spawn_name):
		return spawns.get_node(spawn_name)
	for child in spawns.get_children():
		if child is SpawnPoint:
			return child
	return null

@tool
extends TileMapLayer
## Camada "Collision": visivel no editor (para conferir/editar as colisoes),
## invisivel durante o jogo. As colisoes continuam ativas.


func _ready() -> void:
	self_modulate.a = 0.45 if Engine.is_editor_hint() else 0.0

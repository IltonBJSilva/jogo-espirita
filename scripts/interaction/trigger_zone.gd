@tool
class_name TriggerZone
extends Area2D
## Area que dispara um dialogo/acoes quando o jogador entra nela
## (ex.: concluir "Explorar a praca", registrar a visita a livraria).
##
## Se o jogador ja estiver dentro quando o jogo voltar ao estado "jogando"
## (ex.: ao surgir na porta de um mapa), o gatilho dispara assim mesmo.

@export var dialogue_id := ""
@export var size := Vector2(96, 96):
	set(value):
		size = value
		queue_redraw()
## Dispara so uma vez por entrada na area.
@export var once_per_entry := true

var _inside := false
var _fired := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = Interactable.PLAYER_LAYER
	if Engine.is_editor_hint():
		return
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_inside = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_inside = false
		_fired = false


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _inside and not (_fired and once_per_entry) and GameManager.is_playing():
		_fired = true
		DialogueManager.start(dialogue_id, {"source": self})


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(-size / 2, size), Color(0.3, 0.6, 1.0, 0.15))
		draw_rect(Rect2(-size / 2, size), Color(0.3, 0.6, 1.0, 0.6), false, 1.0)

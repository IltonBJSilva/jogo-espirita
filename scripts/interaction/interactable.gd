@tool
class_name Interactable
extends Area2D
## Componente reutilizavel de interacao (portas, objetos, livros, NPCs).
##
## Ao interagir, emite `interacted` e inicia o dialogo `dialogue_id`.
## Dialogos podem conter acoes (dar item, trocar de mapa, iniciar missao,
## abrir minigame...), entao quase tudo e configurado nos arquivos de dados.

signal interacted

const PLAYER_LAYER := 2
const INTERACTION_LAYER := 8

## Verbo exibido no indicador: "Conversar", "Examinar", "Entrar", "Ler"...
@export var prompt := "Examinar"
## Nome exibido junto ao verbo (ex.: "Allan Kardec", "Fonte").
@export var display_name := ""
## Dialogo em data/dialogues/<id>.json executado na interacao.
@export var dialogue_id := ""
## Alcance usado quando o no nao tem um CollisionShape2D proprio.
@export var radius := 40.0:
	set(value):
		radius = value
		if _auto_shape:
			(_auto_shape.shape as CircleShape2D).radius = value
		queue_redraw()
@export var enabled := true

var _auto_shape: CollisionShape2D = null


func _ready() -> void:
	collision_layer = INTERACTION_LAYER
	collision_mask = PLAYER_LAYER
	monitorable = false
	if Engine.is_editor_hint():
		return
	if not _has_shape() and _auto_shape == null:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = radius
		shape.shape = circle
		add_child(shape)
		_auto_shape = shape
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		InteractionManager.unregister_candidate(self)


func get_prompt_text() -> String:
	return prompt if display_name == "" else "%s: %s" % [prompt, display_name]


func interact() -> void:
	if not enabled:
		return
	interacted.emit()
	if dialogue_id != "":
		DialogueManager.start(dialogue_id, {"source": self})


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		InteractionManager.register_candidate(self)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		InteractionManager.unregister_candidate(self)


func _has_shape() -> bool:
	for child in get_children():
		if (child is CollisionShape2D or child is CollisionPolygon2D) and child != _auto_shape:
			return true
	return false


func _draw() -> void:
	# Mostra o alcance apenas no editor, para facilitar o posicionamento.
	if Engine.is_editor_hint() and not _has_shape():
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.8, 0.2, 0.18))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(1.0, 0.8, 0.2, 0.6), 1.0)

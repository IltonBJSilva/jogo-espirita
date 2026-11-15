class_name NPC
extends Actor
## Personagem nao jogavel. Configure por instancia:
##   npc_id       -> chave em data/characters.json (nome exibido)
##   dialogue_id  -> dialogo em data/dialogues/<id>.json
##   sprite_frames, facing, idle_animation ("" = idle normal, ou "study"...)

@export var npc_id := ""
@export var dialogue_id := ""
## Animacao usada quando parado (ex.: "study" para alguem lendo).
@export var idle_animation := ""
## Alcance da conversa (ex.: maior para quem fica atras de um balcao).
@export var talk_radius := 44.0
@export var face_player_on_talk := true
## Condição (JSON, mesma linguagem dos diálogos) para o NPC estar presente.
## Vazio = sempre presente. Ex.: {"quest_status": {"quest": "o_cetico", "status": "completed"}}
## Permite que moradores "apareçam" em lugares diferentes conforme a história.
@export_multiline var present_when := ""

var _presence_condition: Variant = null

# --- sistema de vida --- (LifeManager, docs/VIDA_CONTRATOS.md)
## false = a rotina colocou este NPC em outro lugar (o nó fica oculto).
var life_present := true
## true = o LifeManager controla a posição/animação deste nó (rotina ativa).
var life_controlled := false

var _rest_facing := Vector2.DOWN

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	super()
	_rest_facing = facing
	special_animation = idle_animation
	_update_animation()
	interactable.prompt = "Conversar"
	interactable.display_name = GameManager.get_character_name(npc_id)
	interactable.dialogue_id = dialogue_id
	interactable.radius = talk_radius
	interactable.interacted.connect(_on_interacted)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	if present_when.strip_edges() != "":
		_presence_condition = JSON.parse_string(present_when)
		QuestManager.quests_changed.connect(_refresh_presence)
		GameManager.flag_changed.connect(_on_flag_changed)
		_refresh_presence()


func is_present() -> bool:
	return life_present and (_presence_condition == null or GameActions.check(_presence_condition))


## Usado pelo LifeManager para mostrar/ocultar o nó conforme a rotina.
func set_life_present(value: bool) -> void:
	life_present = value
	_refresh_presence()


func _refresh_presence() -> void:
	var present := is_present()
	visible = present
	interactable.enabled = present
	interactable.set_deferred("monitoring", present)
	$CollisionShape2D.set_deferred("disabled", not present)
	if not present:
		InteractionManager.unregister_candidate(interactable)


func _on_flag_changed(_flag: String, _value: Variant) -> void:
	_refresh_presence()


func _on_interacted() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if face_player_on_talk and player:
		face_towards(player.global_position)
		player.face_towards(global_position)
	play_special("talk" if has_animation("talk") and facing == Vector2.DOWN else "")


func _on_dialogue_ended(_id: String) -> void:
	face(_rest_facing)
	play_special(idle_animation)

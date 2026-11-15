class_name Actor
extends CharacterBody2D
## Base de personagens (jogador e NPCs): direcao, animacoes e sombra.
##
## Convencao de animacoes no SpriteFrames (geradas por scripts/tools/build_world.gd):
##   idle_down, idle_side, idle_up, walk_down, walk_side, walk_up
##   e opcionais: run_down, run_side, run_up, talk, study.
##   "side" e desenhado olhando para a direita (a esquerda e espelhada).
##   Sem animacao de corrida, a caminhada e tocada mais rapido.

@export var sprite_frames: SpriteFrames:
	set(value):
		sprite_frames = value
		if is_node_ready():
			sprite.sprite_frames = value
			_update_animation()
@export var facing := Vector2.DOWN

var is_moving := false
var is_running := false
## Animacao especial (talk, study...) que substitui o idle enquanto definida.
var special_animation := ""

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	if sprite_frames:
		sprite.sprite_frames = sprite_frames
	face(facing)


## Vira para uma direcao, arredondando para uma das 4 direcoes cardinais.
func face(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	if absf(direction.x) > absf(direction.y):
		facing = Vector2(signf(direction.x), 0)
	else:
		facing = Vector2(0, signf(direction.y))
	_update_animation()


func face_towards(point: Vector2) -> void:
	face(point - global_position)


func set_moving(moving: bool, running: bool = false) -> void:
	running = running and moving
	if moving != is_moving or running != is_running:
		is_moving = moving
		is_running = running
		_update_animation()


func play_special(animation: String) -> void:
	special_animation = animation
	_update_animation()


func has_animation(animation: String) -> bool:
	return sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation)


func _direction_suffix() -> String:
	if facing.y < 0:
		return "up"
	if facing.x != 0:
		return "side"
	return "down"


func _update_animation() -> void:
	if not is_node_ready() or sprite.sprite_frames == null:
		return
	var suffix := _direction_suffix()
	var anim := "idle_" + suffix
	var speed := 1.0
	if is_moving:
		anim = "walk_" + suffix
		if is_running:
			if has_animation("run_" + suffix):
				anim = "run_" + suffix
			else:
				speed = 1.6
	elif special_animation != "" and has_animation(special_animation):
		anim = special_animation
	sprite.speed_scale = speed
	sprite.flip_h = facing.x < 0 and anim.ends_with("side")
	if sprite.animation != anim or not sprite.is_playing():
		# Ao trocar entre andar e correr na mesma direcao, mantem a fase do
		# passo para a transicao nao "engasgar".
		var old_anim := String(sprite.animation)
		var keep_phase := is_moving and old_anim.get_slice("_", 1) == suffix \
				and old_anim.begins_with("walk") != anim.begins_with("walk")
		var progress := 0.0
		if sprite.sprite_frames.has_animation(old_anim):
			progress = float(sprite.frame) / maxf(1.0, sprite.sprite_frames.get_frame_count(old_anim))
		sprite.play(anim)
		if keep_phase:
			sprite.frame = int(progress * sprite.sprite_frames.get_frame_count(anim))
	queue_redraw()


func _draw() -> void:
	# Sombra eliptica sob os pes (o sprite e desenhado por cima).
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, 17.0, Color(0.05, 0.02, 0.06, 0.32))
	draw_set_transform(Vector2.ZERO)

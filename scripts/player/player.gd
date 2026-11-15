class_name Player
extends Actor
## Personagem controlavel: movimento em 4 direcoes, corrida (Shift) e camera.

@export var walk_speed := 105.0
@export var run_speed := 170.0

@onready var camera: Camera2D = $Camera2D

var _bounds := Rect2i()


func _ready() -> void:
	super()
	add_to_group("player")
	get_viewport().size_changed.connect(_refresh_camera_limits)


func _physics_process(_delta: float) -> void:
	var input := Vector2.ZERO
	if GameManager.is_playing():
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Apenas 4 direcoes: na diagonal, mantem o eixo da direcao atual.
	if input.x != 0 and input.y != 0:
		if facing.x != 0:
			input.y = 0
		else:
			input.x = 0
	if input != Vector2.ZERO:
		input = input.normalized()
		face(input)
	var running := Input.is_action_pressed("run") and GameManager.is_playing()
	velocity = input * (run_speed if running else walk_speed)
	move_and_slide()
	# "andando" so se realmente se deslocou (encostado numa parede = parado)
	var moved := input != Vector2.ZERO and get_real_velocity().length() > 5.0
	set_moving(moved, running)


## Ajusta a camera ao mapa. Mapas menores que a tela ficam centralizados.
func apply_camera_limits(bounds: Rect2i) -> void:
	_bounds = bounds
	_refresh_camera_limits()
	camera.reset_smoothing()


func _refresh_camera_limits() -> void:
	if _bounds.size == Vector2i.ZERO:
		return
	var view := Vector2i(get_viewport_rect().size / camera.zoom)
	for axis in 2:
		var extra := view[axis] - _bounds.size[axis]
		var lo := _bounds.position[axis]
		var hi := _bounds.end[axis]
		if extra > 0:
			lo -= extra / 2
			hi = lo + view[axis]
		if axis == 0:
			camera.limit_left = lo
			camera.limit_right = hi
		else:
			camera.limit_top = lo
			camera.limit_bottom = hi

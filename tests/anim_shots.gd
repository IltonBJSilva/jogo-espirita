extends "res://tests/smoke_test.gd"
## Captura uma tira de quadros do jogador andando/correndo em cada direcao.
##   godot --path . res://tests/anim_shots.tscn -- <pasta>

const MOVES := [
	["andar_baixo", ["move_down"], Vector2(680, 420)],
	["andar_cima", ["move_up"], Vector2(680, 520)],
	["andar_direita", ["move_right"], Vector2(560, 480)],
	["correr_direita", ["move_right", "run"], Vector2(560, 480)],
	["correr_esquerda", ["move_left", "run"], Vector2(1000, 480)],
]

var _out := "user://screenshots"


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_detach()
	await GameManager.new_game()
	# evita que o gatilho da praca abra um dialogo no meio da captura
	QuestManager.complete_objective("conhecendo_sociedade", "explorar_praca")
	var player := get_tree().get_first_node_in_group("player") as Player
	var sheet := Image.create(96 * 8, 120 * MOVES.size(), false, Image.FORMAT_RGBA8)
	for row in MOVES.size():
		player.global_position = MOVES[row][2]
		player.camera.reset_smoothing()
		for action in MOVES[row][1]:
			Input.action_press(action)
		for i in 8:
			await _physics_frames(7)
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var p := Vector2i(player.get_global_transform_with_canvas().origin)
			var crop := img.get_region(Rect2i(p - Vector2i(48, 104), Vector2i(96, 120)))
			crop.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(96 * i, 120 * row))
		for action in MOVES[row][1]:
			Input.action_release(action)
		await _physics_frames(10)
	sheet.save_png(_out.path_join("animacoes_jogo.png"))
	get_tree().quit()

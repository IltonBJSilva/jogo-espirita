extends "res://tests/smoke_test.gd"
## Captura o jogador ao lado de Kardec (conferir os pes/sombra dos sprites).

func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	_detach()
	await GameManager.new_game()
	GameManager.set_state(GameManager.State.TRANSITION)
	var player := get_tree().get_first_node_in_group("player") as Player
	player.global_position = Vector2(720, 470)
	player.face(Vector2.RIGHT)
	player.camera.reset_smoothing()
	await _frames(15)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var c := Vector2i(player.get_global_transform_with_canvas().origin) + Vector2i(40, -40)
	img = img.get_region(Rect2i(c - Vector2i(130, 90), Vector2i(260, 170)))
	img.resize(780, 510, Image.INTERPOLATE_NEAREST)
	img.save_png(out.path_join("kardec.png"))
	get_tree().quit()

extends "res://tests/smoke_test.gd"
## Captura do Jardim da Reflexão para revisão visual:
##   godot --path . res://tests/spiritual_shot.tscn -- <pasta>

func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	_detach()
	await GameManager.new_game()
	SceneManager.change_map("plano_espiritual", "entrada")
	await _wait_until(func(): return SceneManager.current_map.map_id == "plano_espiritual" and GameManager.is_playing(), 300)
	GameManager.set_state(GameManager.State.TRANSITION)
	var player := get_tree().get_first_node_in_group("player") as Player
	player.global_position = Vector2(540, 440)
	player.face(Vector2.RIGHT)
	player.camera.reset_smoothing()
	await _frames(20)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("jardim.png"))
	await _interact_dialogue()
	get_tree().quit()


func _interact_dialogue() -> void:
	GameManager.set_state(GameManager.State.PLAYING)
	DialogueManager.start("irma_clara")
	await _frames(90)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join("jardim_dialogo.png"))

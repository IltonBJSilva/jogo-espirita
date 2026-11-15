extends "res://tests/smoke_test.gd"
## Capturas do ciclo de dia e noite para revisão visual (precisa de janela):
##   godot --path . --resolution 960x540 res://tests/time_shots.tscn -- <pasta>

const TIMES := [["0600", 6, 0], ["1200", 12, 0], ["1830", 18, 30], ["2200", 22, 0]]

var _out := "user://screenshots"


func _run() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		_out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_detach()
	await GameManager.new_game()
	TimeManager.running = false
	QuestManager.complete_objective(Q, "explorar_praca")  # evita o gatilho da fonte
	var player := get_tree().get_first_node_in_group("player") as Player
	player.global_position = Vector2(700, 470)
	player.camera.reset_smoothing()
	await _frames(240)  # espera os avisos sumirem
	if DialogueManager.is_active():
		DialogueManager.end()
	for t in TIMES:
		TimeManager.set_datetime(1857, 5, 4, t[1], t[2])
		await _frames(6)
		await _shot("praca_" + t[0])
	SceneManager.change_map("residencia_kardec", "entrada")
	await _wait_until(func(): return SceneManager.current_map.map_id == "residencia_kardec" and GameManager.is_playing(), 300)
	TimeManager.running = false
	await _frames(5)
	if DialogueManager.is_active():
		DialogueManager.end()
	TimeManager.set_datetime(1857, 5, 4, 22, 0)
	await _frames(10)
	await _shot("interior_2200")
	TimeManager.set_datetime(1857, 5, 4, 12, 0)
	await _frames(6)
	await _shot("interior_1200")
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(shot_name + ".png"))

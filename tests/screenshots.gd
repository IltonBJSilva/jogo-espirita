extends "res://tests/smoke_test.gd"
## Captura telas do jogo para revisao visual (precisa de janela, nao headless):
##   godot --path . res://tests/screenshots.tscn -- <pasta_de_saida>

var _out := "user://screenshots"


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_detach()
	get_tree().change_scene_to_file(SceneManager.TITLE_SCENE)
	await _frames(30)
	await _shot("01_titulo")
	await GameManager.new_game()
	await _frames(20)
	await _shot("02_praca")
	var player := get_tree().get_first_node_in_group("player") as Player
	player.global_position = Vector2(757, 520)
	await _wait_until(func(): return DialogueManager.is_active(), 120)
	await _finish_dialogue()
	await _interact_with("Kardec")
	player.global_position += Vector2(0, 40)
	await _frames(90)
	await _shot("03_dialogo_kardec")
	await _advance_until_choices()
	await _frames(10)
	await _shot("04_escolhas")
	await _finish_dialogue()
	await _interact_with("PortaLivraria")
	await _wait_until(func(): return SceneManager.current_map.map_id == "livraria" and GameManager.is_playing(), 300)
	await _frames(30)
	await _shot("05_livraria")
	await _finish_dialogue()
	await _interact_with("EstanteEnciclopedia")
	await _advance_until_choices()
	_choose_text("Organizar")
	await _frames(20)
	await _shot("06_minigame")
	MinigameManager._current.finish(false)
	await _frames(10)
	var menu := get_tree().current_scene.get_node("PauseMenu")
	menu.open(menu.Page.JOURNAL)
	await _frames(10)
	await _shot("07_diario")
	menu.close()
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _out.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("screenshot: ", path)

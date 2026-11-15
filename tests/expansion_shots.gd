extends "res://tests/smoke_test.gd"
## Capturas das telas da expansão para revisão visual (precisa de janela):
##   godot --path . res://tests/expansion_shots.tscn -- <pasta>

var _out := "user://screenshots"


func _run() -> void:
	_out = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else _out
	DirAccess.make_dir_recursive_absolute(_out)
	_detach()
	await GameManager.new_game()
	for o in ["explorar_praca", "conversar_kardec", "visitar_livraria", "encontrar_livro", "retornar_sociedade"]:
		if o == "encontrar_livro":
			InventoryManager.add_item("livro_dos_espiritos")
		QuestManager.complete_objective(Q, o)
	await _frames(30)
	var player := get_tree().get_first_node_in_group("player") as Player
	GameManager.set_state(GameManager.State.TRANSITION)
	await _place(player, Vector2(450, 700))
	await _shot("e01_praca_novos_npcs")
	GameManager.set_state(GameManager.State.PLAYING)
	# Interiores
	for m in ["residencia_kardec", "sociedade_salao", "tipografia"]:
		SceneManager.change_map(m, "entrada")
		await _wait_until(func(): return SceneManager.current_map.map_id == m and GameManager.is_playing(), 300)
		await _frames(20)
		if DialogueManager.is_active():
			DialogueManager.end()
		await _place(player, Vector2(480, 380))
		await _shot("e02_" + m)
	# Diálogo com retrato novo (Bertin)
	DialogueManager.start("bertin")
	await _frames(80)
	await _shot("e03_dialogo_bertin")
	DialogueManager.end()
	await _frames(5)
	# Minigames
	MinigameManager.start("questionario_le")
	await _frames(10)
	MinigameManager._current._on_next()
	MinigameManager._current._on_option(0)
	await _frames(10)
	await _shot("e04_quiz")
	MinigameManager._current.finish(false)
	await _frames(5)
	MinigameManager.start("imprensa_etapas")
	await _frames(10)
	await _shot("e05_ordenar")
	MinigameManager._current.finish(false)
	await _frames(5)
	# Leitor, viagem, compêndio, inventário
	LibraryManager.open("livro_dos_espiritos")
	await _frames(10)
	await _shot("e06_leitor")
	LibraryManager._reader.closed.emit()
	await _frames(5)
	GameManager.set_flag("tipografia_conhecida")
	TravelManager.open()
	await _frames(10)
	await _shot("e07_viagem")
	TravelManager._close()
	await _frames(5)
	EncyclopediaManager.unlock("allan_kardec", true)
	EncyclopediaManager.unlock("caridade", true)
	EncyclopediaManager.unlock("louis", true)
	RelationshipManager.add("amelie", 35)
	RelationshipManager.add("crianca", 20)
	ProgressManager.add("caridade", 20)
	ProgressManager.add("estudo", 25)
	var comp := get_tree().current_scene.get_node("%Compendium")
	for tab in 4:
		comp.open(tab)
		await _frames(8)
		await _shot("e08_compendio_%d" % tab)
	comp.close()
	await _frames(5)
	InventoryManager.add_item("caderno_estudos")
	InventoryManager.add_item("pena_presente")
	var menu := get_tree().current_scene.get_node("PauseMenu")
	menu.open(menu.Page.INVENTORY)
	await _frames(8)
	await _shot("e09_inventario")
	menu.open(menu.Page.MAIN)
	await _frames(5)
	await _shot("e10_pausa")
	menu.close()
	get_tree().quit()


func _place(player: Player, pos: Vector2) -> void:
	player.global_position = pos
	player.camera.reset_smoothing()
	await _frames(8)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(shot_name + ".png"))

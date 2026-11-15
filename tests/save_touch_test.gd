extends "res://tests/smoke_test.gd"
## Teste do sistema de save (espaços, automático, carregar) e dos controles de
## toque (joystick, botões, botão voltar do Android).
##
##   godot --headless --path . res://tests/save_touch_test.tscn
##   godot --path . res://tests/save_touch_test.tscn -- <pasta>   (+ capturas)


func _run() -> void:
	print("== Teste de save e toque ==")
	var out := ""
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and DisplayServer.get_name() != "headless":
		out = args[0]
		DirAccess.make_dir_recursive_absolute(out)
	_check(SaveManager.save_dir == "user://test_saves", "testes usam pasta própria de saves")
	_detach()
	SaveManager.delete_save()
	_check(not SaveManager.has_save(), "nenhum save no início")

	# --- Salvamento automático ao entrar no mapa ---
	await GameManager.new_game()
	await _frames(5)
	_check(SaveManager.has_save(SaveManager.AUTO), "salvamento automático ao começar")
	var player := get_tree().get_first_node_in_group("player") as Player

	# --- Espaços manuais ---
	player.global_position = Vector2(800, 800)
	TimeManager.set_datetime(1857, 5, 6, 15, 30)
	GameManager.set_flag("teste_save", 42)
	_check(SaveManager.save_game("2"), "salvar no espaço 2")
	var info := SaveManager.get_slot_info("2")
	_check(info.get("location", "") != "", "resumo tem o local: %s" % info.get("location", ""))
	_check(str(info.get("game_time", "")).contains("15:30"), "resumo tem a hora do jogo: %s" % info.get("game_time", ""))
	_check(str(info.get("quest", "")) != "", "resumo tem a missão: %s" % info.get("quest", ""))
	_check(SaveManager.get_latest_slot() == "2", "espaço 2 é o mais recente")
	_check(SaveManager.current_slot == "2", "espaço atual vira o 2")
	_check(not SaveManager.has_save("3"), "espaço 3 continua vazio")
	_check(SaveManager.get_save_summary("2") != "", "texto curto: %s" % SaveManager.get_save_summary("2"))

	# --- Autosave não sobrescreve espaço manual e respeita o intervalo ---
	_check(not SaveManager.autosave(), "autosave respeita o intervalo mínimo")
	_check(SaveManager.autosave(true), "autosave forçado (app em segundo plano)")

	# --- Carregar ---
	GameManager.set_flag("teste_save", 0)
	player.global_position = Vector2(400, 400)
	await SaveManager.load_game("2")
	await _frames(5)
	player = get_tree().get_first_node_in_group("player") as Player
	_check(GameManager.get_flag("teste_save", 0) == 42, "carregar restaura as flags")
	_check(player.global_position.distance_to(Vector2(800, 800)) < 2.0, "carregar restaura a posição")
	_check(TimeManager.get_hour() == 15, "carregar restaura a hora do jogo")

	# --- Save corrompido não derruba o jogo ---
	var f := FileAccess.open(SaveManager.slot_path("3"), FileAccess.WRITE)
	f.store_string("{ quebrado")
	f.close()
	_check(SaveManager.get_slot_info("3").is_empty(), "save corrompido aparece como vazio")
	_check(not await SaveManager.load_game("3"), "carregar save corrompido falha sem travar")
	SaveManager.delete_save("3")

	# --- Tela de espaços ---
	var panel := SaveSlotsPanel.new()
	get_tree().current_scene.add_child(panel)
	panel.open(SaveSlotsPanel.Mode.LOAD)
	await _frames(2)
	var buttons := panel.find_children("*", "Button", true, false)
	var load_enabled := 0
	for b in buttons:
		if b.text == "Carregar" and not b.disabled:
			load_enabled += 1
	_check(load_enabled == 2, "tela de carregar: auto + espaço 2 disponíveis (%d)" % load_enabled)
	panel.queue_free()

	# --- Controles de toque ---
	# (o local carregado fica num gatilho de diálogo da praça: encerra antes)
	DialogueManager.end()
	await _frames(3)
	GameManager.set_state(GameManager.State.PLAYING)
	TouchControls.active = true
	TouchControls._on_state_changed(GameManager.State.PLAYING, GameManager.State.PLAYING)
	await _frames(2)
	var joy: Vector2 = TouchControls._joy_center()
	var start := player.global_position
	await _touch(0, joy, true)
	await _drag(0, joy + Vector2(50, 0))
	_check(Input.get_action_strength("move_right") > 0.5, "joystick aciona move_right")
	for i in 30:
		await get_tree().physics_frame
	_check(player.global_position.x > start.x + 10, "jogador anda com o joystick (%.0f -> %.0f)" % [start.x, player.global_position.x])
	await _drag(0, joy + Vector2(0, -62))
	_check(Input.is_action_pressed("run") and Input.get_action_strength("move_up") > 0.9, "joystick no limite = correr")
	if out != "":
		await _shot(out.path_join("touch_controls.png"))
	await _touch(0, joy, false)
	_check(not Input.is_action_pressed("move_up") and not Input.is_action_pressed("run"), "soltar o joystick para o jogador")

	var pause_center: Vector2 = TouchControls._buttons.filter(func(b): return b["id"] == "pause")[0]["center"]
	await _touch(1, pause_center, true)
	await _frames(3)
	_check(GameManager.state == GameManager.State.PAUSED, "botão Menu abre a pausa")
	_check(not TouchControls._root.visible, "controles somem na pausa")
	await _touch(1, pause_center, false)
	if out != "":
		await _shot(out.path_join("pause_menu.png"))
	TouchControls._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(3)
	_check(GameManager.state == GameManager.State.PLAYING, "botão voltar do Android fecha a pausa")
	_check(TouchControls._root.visible, "controles voltam ao jogo")

	# Tela de espaços dentro do menu de pausa (salvar)
	var pause := get_tree().root.find_child("PauseMenu", true, false)
	pause.open_slots(SaveSlotsPanel.Mode.SAVE)
	await _frames(3)
	_check(pause.page == pause.Page.SLOTS, "pausa abre a tela de espaços")
	if out != "":
		await _shot(out.path_join("save_slots.png"))
	pause.close()

	SaveManager.delete_save()
	print("== %s (%d falha(s)) ==" % ["OK" if _failures == 0 else "FALHOU", _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = get_tree().root.get_final_transform() * pos  # coordenadas da janela
	ev.pressed = pressed
	Input.parse_input_event(ev)
	await _frames(2)


func _drag(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = get_tree().root.get_final_transform() * pos  # coordenadas da janela
	Input.parse_input_event(ev)
	await _frames(2)


func _shot(path: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

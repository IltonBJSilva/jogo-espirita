extends Node
## Teste de fumaca: joga a missao inicial inteira automaticamente.
##
##   godot --headless --path . res://tests/smoke_test.tscn
##
## Usa os mesmos caminhos do jogador (interagir com objetos/NPCs, avancar e
## escolher falas, trocar de mapa, minigame) e confere o estado a cada passo.
## Sai com codigo 0 se tudo passar e 1 se algo falhar.

const Q := "conhecendo_sociedade"

var _failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


## O teste e a cena atual; troca de cena o destruiria. Um no vazio assume
## o papel de cena atual e o teste continua vivo como filho da raiz.
func _detach() -> void:
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder


func _run() -> void:
	print("== Smoke test ==")
	_detach()
	await GameManager.new_game()
	await _frames(5)
	_check(SceneManager.current_map != null and SceneManager.current_map.map_id == "paris_1857", "mapa inicial carregado")
	_check(GameManager.is_playing(), "estado PLAYING apos novo jogo")
	_check(QuestManager.get_status(Q) == QuestManager.Status.ACTIVE, "missao iniciada")
	var player := get_tree().get_first_node_in_group("player") as Player
	_check(player != null, "jogador existe")

	# Movimento e colisao: andar para cima ate a fonte (solida) deve parar antes dela.
	var start := player.global_position
	Input.action_press("move_up")
	await _physics_frames(90)
	Input.action_release("move_up")
	_check(player.global_position.y < start.y - 40, "jogador anda (%.0f -> %.0f)" % [start.y, player.global_position.y])
	_check(player.global_position.y > 23 * 32, "colisao da fonte bloqueia (%.0f)" % player.global_position.y)

	# 1. Explorar a praca (o gatilho da fonte dispara ao entrar na area).
	await _wait_until(func(): return QuestManager.is_objective_done(Q, "explorar_praca") or DialogueManager.is_active(), 120)
	await _finish_dialogue()
	_check(QuestManager.is_objective_done(Q, "explorar_praca"), "objetivo: explorar a praca")

	# 2. Conversar com Kardec e escolher "Por onde comeco?".
	await _interact_with("Kardec")
	await _advance_until_choices()
	_choose_text("pseudônimo")
	await _advance_until_choices()
	_choose_text("Por onde começo")
	await _finish_dialogue()
	_check(QuestManager.is_objective_done(Q, "conversar_kardec"), "objetivo: conversar com Kardec")

	# Outros NPCs da praca respondem.
	for npc_name in ["Estudioso", "Moradora"]:
		await _interact_with(npc_name)
		_check(DialogueManager.is_active(), "dialogo com %s" % npc_name)
		await _finish_dialogue()

	# 3. Entrar na livraria pela porta.
	await _interact_with("PortaLivraria")
	await _wait_until(func(): return SceneManager.current_map.map_id == "livraria" and GameManager.is_playing(), 180)
	_check(SceneManager.current_map.map_id == "livraria", "entrou na livraria")
	await _wait_until(func(): return DialogueManager.is_active(), 60)
	await _finish_dialogue()
	_check(QuestManager.is_objective_done(Q, "visitar_livraria"), "objetivo: visitar a livraria")

	# Minigame da enciclopedia (resolvido pelo teste).
	await _interact_with("EstanteEnciclopedia")
	await _advance_until_choices()
	_choose_text("Organizar")
	await _wait_until(func(): return MinigameManager.is_active(), 30)
	_check(MinigameManager.is_active(), "minigame aberto")
	await _solve_minigame()
	await _wait_until(func(): return not MinigameManager.is_active(), 200)
	_check(GameManager.get_flag("enciclopedia_organizada"), "minigame concluido")
	_check(InventoryManager.has_item("marcador_pagina"), "recompensa do minigame")

	# 4. Encontrar o livro.
	await _interact_with("Livreiro")
	await _finish_dialogue()
	await _interact_with("EstanteJanela")
	await _finish_dialogue()
	_check(InventoryManager.has_item("livro_dos_espiritos"), "pegou O Livro dos Espiritos")
	_check(QuestManager.is_objective_done(Q, "encontrar_livro"), "objetivo: encontrar o livro")

	# Voltar para a praca.
	await _interact_with("Saida")
	await _wait_until(func(): return SceneManager.current_map.map_id == "paris_1857" and GameManager.is_playing(), 180)
	_check(SceneManager.current_map.map_id == "paris_1857", "voltou para a praca")

	# 5. Retornar a Sociedade (entregar a Kardec).
	await _interact_with("Kardec")
	await _finish_dialogue()
	_check(QuestManager.get_status(Q) == QuestManager.Status.COMPLETED, "missao concluida")
	_check(InventoryManager.has_item("carta_recomendacao"), "recompensa da missao")
	_check(GameManager.get_flag("apresentado_ao_grupo"), "flag de recompensa")

	# Menu de pausa, diario e inventario.
	var menu := get_tree().current_scene.get_node("PauseMenu")
	menu.open(menu.Page.JOURNAL)
	await _frames(2)
	_check(get_tree().paused and GameManager.state == GameManager.State.PAUSED, "pausa/diario abre")
	menu.open(menu.Page.INVENTORY)
	await _frames(2)
	_check(menu.get_node("%ItemsList").item_count == 3, "inventario lista 3 itens")
	menu.close()
	await _frames(2)
	_check(not get_tree().paused and GameManager.is_playing(), "pausa fecha")

	print("== %s (%d falha(s)) ==" % ["OK" if _failures == 0 else "FALHOU", _failures])
	get_tree().quit(1 if _failures else 0)


# --- Auxiliares -------------------------------------------------------------------

func _check(ok: bool, what: String) -> void:
	print(("  [ok]   " if ok else "  [FAIL] ") + what)
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return
		await get_tree().process_frame


## Teleporta o jogador para perto do objeto e interage como o jogador faria (tecla E).
func _interact_with(node_name: String) -> void:
	await _wait_until(func(): return GameManager.is_playing(), 120)
	var target := SceneManager.current_map.find_child(node_name, true, false) as Node2D
	if target == null:
		_check(false, "objeto '%s' existe" % node_name)
		return
	var interactable: Interactable = target if target is Interactable else target.get_node("Interactable")
	var player := get_tree().get_first_node_in_group("player") as Player
	player.global_position = interactable.global_position + Vector2(0, 12)
	await _physics_frames(4)
	await _frames(2)
	# respeita o intervalo anti-repeticao entre dialogos
	await get_tree().create_timer(InteractionManager.COOLDOWN + 0.05).timeout
	_check(InteractionManager.focused == interactable, "foco em %s" % node_name)
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(3)
	var release := InputEventAction.new()
	release.action = "interact"
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(1)


func _dialogue_box() -> Node:
	return get_tree().current_scene.get_node("DialogueBox")


func _advance_until_choices() -> void:
	for i in 40:
		await _frames(2)
		var box := _dialogue_box()
		if not DialogueManager.is_active():
			return
		if box._typing:
			box._finish_typing()
			await _frames(1)
		if box.choices.get_child_count() > 0:
			return
		DialogueManager.advance()


func _choose_text(fragment: String) -> void:
	var box := _dialogue_box()
	for button in box.choices.get_children():
		if fragment in button.text:
			button.pressed.emit()
			return
	_check(false, "opcao '%s' disponivel" % fragment)


## Avanca falas ate o dialogo terminar (escolhe a ultima opcao se houver escolhas).
func _finish_dialogue() -> void:
	for i in 60:
		if not DialogueManager.is_active():
			await _frames(2)
			return
		await _advance_until_choices()
		var box := _dialogue_box()
		if DialogueManager.is_active() and box.choices.get_child_count() > 0:
			box.choices.get_child(box.choices.get_child_count() - 1).pressed.emit()
	_check(false, "dialogo terminou")


func _solve_minigame() -> void:
	var mg := MinigameManager._current
	for target in 5:
		var slot: int = mg._order.find(target)
		if slot != target:
			mg._on_book_pressed(target)
			mg._on_book_pressed(slot)
		await _frames(1)

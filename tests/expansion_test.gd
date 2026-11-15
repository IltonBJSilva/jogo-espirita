extends "res://tests/smoke_test.gd"
## Teste da expansão: joga as missões dos capítulos 1 e 2, os interiores novos,
## minigames, viagem de fiacre, biblioteca, compêndio e salvar/carregar.
##
##   godot --headless --path . res://tests/expansion_test.tscn

const Q2 := "perguntas_e_respostas"
const Q3 := "cartas_do_professor"
const Q4 := "pao_para_louis"
const Q5 := "o_cetico"
const Q6 := "revista_espirita"


func _run() -> void:
	print("== Teste da expansão ==")
	_detach()
	SaveManager.delete_save()
	await GameManager.new_game()
	await _frames(5)
	_check(EncyclopediaManager.entries.size() >= 40, "enciclopédia carregada (%d)" % EncyclopediaManager.entries.size())
	_check(LibraryManager.books.size() >= 8, "biblioteca carregada")
	_check(QuestManager.quests.size() >= 6, "missões registradas (%d)" % QuestManager.quests.size())

	# Missão 1 (já testada em smoke_test) concluída diretamente.
	for o in ["explorar_praca", "conversar_kardec", "visitar_livraria", "encontrar_livro", "retornar_sociedade"]:
		if o == "encontrar_livro":
			InventoryManager.add_item("livro_dos_espiritos")
		QuestManager.complete_objective(Q, o)
	_check(QuestManager.get_status(Q) == QuestManager.Status.COMPLETED, "missão 1 concluída")
	await _close_reader()

	# --- Capítulo 1: Perguntas e Respostas --------------------------------------
	await _talk("Kardec")
	_check(QuestManager.get_status(Q2) == QuestManager.Status.ACTIVE, "convite para o estudo (Q2 ativa)")
	await _interact_with("PortaSociedade")
	await _wait_map("sociedade_salao")
	await _wait_until(func(): return DialogueManager.is_active(), 60)
	await _finish_dialogue()
	_check(QuestManager.is_objective_done(Q2, "entrar_salao"), "Q2: entrar no salão")
	await _talk("Aline")
	_check(QuestManager.is_objective_done(Q2, "conversar_aline"), "Q2: conversar com Aline")
	await _interact_with("MesaEstudos")
	await _advance_until_choices()
	_choose_text("Participar")
	await _solve_quiz()
	_check(QuestManager.is_objective_done(Q2, "questionario"), "Q2: questionário (minigame quiz)")
	await _talk("KardecSalao")
	_check(QuestManager.get_status(Q2) == QuestManager.Status.COMPLETED, "Q2 concluída")
	_check(InventoryManager.has_item("caderno_estudos"), "recompensa: caderno de estudos")
	await _interact_with("Quadro")
	await _advance_until_choices()
	_choose_text("Organizar")
	await _solve_ordering()
	_check(GameManager.get_flag("linha_do_tempo_feita"), "linha do tempo (minigame ordenar)")
	await _interact_with("Programa")
	await _wait_until(func(): return LibraryManager.is_open(), 30)
	_check(LibraryManager.is_open(), "leitor de documentos abre")
	await _close_reader()
	_check(LibraryManager.is_read("programa_sessao"), "documento registrado na biblioteca")
	await _interact_with("Saida")
	await _wait_map("paris_1857")

	# --- Pão para Louis ------------------------------------------------------------
	await _interact_with("Louis")
	await _advance_until_choices()
	_choose_text("Vou conseguir")
	await _finish_dialogue()
	_check(QuestManager.get_status(Q4) == QuestManager.Status.ACTIVE, "Q4 iniciada por Louis")
	await _talk("Moradora")
	_check(InventoryManager.has_item("pao"), "Madame Marguerite dá o pão")
	await _interact_with("PortaLivraria")
	await _wait_map("livraria")
	await _finish_dialogue()
	await _talk("Livreiro")
	_check(InventoryManager.has_item("agasalho"), "Monsieur Gérard dá o agasalho")
	await _interact_with("Saida")
	await _wait_map("paris_1857")
	await _talk("Louis")
	_check(QuestManager.get_status(Q4) == QuestManager.Status.COMPLETED, "Q4 concluída")
	_check(ProgressManager.get_value("caridade") >= 15, "virtude caridade aumentou")
	_check(RelationshipManager.get_affinity("crianca") >= 20, "afinidade com Louis")

	# --- O Cético ------------------------------------------------------------------
	await _interact_with("Lefevre")
	await _advance_until_choices()
	_choose_text("Ouvir")
	await _advance_until_choices()
	_choose_text("Estou pronto")
	await _solve_quiz()
	_check(QuestManager.is_objective_done(Q5, "debater"), "Q5: debate (quiz)")
	await _talk("Lefevre")
	_check(QuestManager.get_status(Q5) == QuestManager.Status.COMPLETED, "Q5 concluída")
	await _frames(3)
	var lefevre := SceneManager.current_map.find_child("Lefevre", true, false) as NPC
	_check(lefevre != null and not lefevre.visible, "Lefèvre sai da praça (presença condicional)")

	# --- As Cartas do Professor -------------------------------------------------------
	await _interact_with("PortaResidencia")
	await _wait_map("residencia_kardec")
	await _interact_with("Amelie")
	await _advance_until_choices()
	_choose_text("Posso organizá-las")
	await _finish_dialogue()
	_check(QuestManager.get_status(Q3) == QuestManager.Status.ACTIVE, "Q3 iniciada por Amélie")
	await _interact_with("Comoda")
	await _advance_until_choices()
	_choose_text("Organizar")
	await _solve_ordering()
	await _wait_until(func(): return LibraryManager.is_open(), 30)
	await _close_reader()
	_check(LibraryManager.is_read("carta_de_lyon"), "carta de Lyon lida após o minigame")
	await _talk("Amelie")
	_check(QuestManager.get_status(Q3) == QuestManager.Status.COMPLETED, "Q3 concluída")
	_check(InventoryManager.has_item("pena_presente"), "presente de Amélie")
	await _interact_with("Saida")
	await _wait_map("paris_1857")

	# --- Capítulo 2: A Revista Espírita -----------------------------------------------
	await _talk("Kardec")
	_check(QuestManager.get_status(Q6) == QuestManager.Status.ACTIVE, "Q6 iniciada (capítulo 2)")
	_check(GameManager.get_flag("data_atual") == "Dezembro de 1857", "calendário avança")
	await _interact_with("Cocheiro")
	await _advance_until_choices()
	_choose_text("Quero viajar")
	await _wait_until(func(): return TravelManager.is_open(), 30)
	_check(TravelManager.is_open(), "mapa de viagem abre")
	var dest: Dictionary = {}
	for d in TravelManager.get_available():
		if d["id"] == "tipografia":
			dest = d
	_check(not dest.is_empty(), "tipografia liberada no mapa")
	TravelManager._on_chosen(dest)
	await _wait_map("tipografia")
	await _wait_until(func(): return DialogueManager.is_active(), 60)
	await _finish_dialogue()
	_check(QuestManager.is_objective_done(Q6, "ir_tipografia"), "Q6: chegar à tipografia")
	await _talk("Bertin")
	_check(QuestManager.is_objective_done(Q6, "falar_bertin"), "Q6: entregar as provas")
	await _interact_with("Prensa")
	await _advance_until_choices()
	_choose_text("Imprimir")
	await _solve_ordering()
	_check(InventoryManager.has_item("revista_espirita_1"), "Revista Espírita impressa")
	await _interact_with("Saida")
	await _finish_dialogue()  # "Bertrand espera do lado de fora..."
	await _wait_map("paris_1857")
	await _talk("Kardec")
	_check(QuestManager.get_status(Q6) == QuestManager.Status.COMPLETED, "Q6 concluída")

	# --- Leituras na praça, compêndio, salvar/carregar ----------------------------------
	for obj in ["JornalBanco", "CartazObras"]:
		await _interact_with(obj)
		await _wait_until(func(): return LibraryManager.is_open(), 30)
		await _close_reader()
	_check(LibraryManager.is_read("gazeta_mesas") and LibraryManager.is_read("cartaz_obras"), "jornal e cartaz lidos")
	var comp := get_tree().current_scene.get_node("%Compendium")
	for tab in 4:
		comp.open(tab)
		await _frames(2)
	_check(comp.is_open() and get_tree().paused, "compêndio abre nas 4 abas")
	comp.close()
	await _frames(2)
	_check(EncyclopediaManager.count_unlocked() >= 25, "entradas descobertas: %d" % EncyclopediaManager.count_unlocked())
	_check(ProgressManager.get_stage_name() != "Recém-chegado", "etapa de progresso: %s" % ProgressManager.get_stage_name())
	_check(SaveManager.save_game("1") and SaveManager.has_save(), "jogo salvo")
	var entries_before := EncyclopediaManager.count_unlocked()
	await GameManager.new_game()
	_check(QuestManager.get_status(Q6) == QuestManager.Status.NOT_STARTED, "novo jogo zera o progresso")
	await SaveManager.load_game("1")
	await _frames(5)
	_check(QuestManager.get_status(Q6) == QuestManager.Status.COMPLETED, "carregar restaura missões")
	_check(EncyclopediaManager.count_unlocked() == entries_before, "carregar restaura a enciclopédia")
	_check(InventoryManager.has_item("revista_espirita_1"), "carregar restaura o inventário")
	SaveManager.delete_save()

	print("== %s (%d falha(s)) ==" % ["OK" if _failures == 0 else "FALHOU", _failures])
	get_tree().quit(1 if _failures else 0)


# --- Auxiliares ----------------------------------------------------------------

func _talk(node_name: String) -> void:
	await _interact_with(node_name)
	await _finish_dialogue()
	await _close_reader()


func _wait_map(map_id: String) -> void:
	await _wait_until(_on_map.bind(map_id), 300)
	_check(SceneManager.current_map.map_id == map_id, "mapa %s" % map_id)


func _on_map(map_id: String) -> bool:
	return SceneManager.current_map != null and SceneManager.current_map.map_id == map_id \
			and not SceneManager._busy


func _close_reader() -> void:
	await _frames(2)
	if LibraryManager.is_open():
		LibraryManager._reader.closed.emit()
		await _frames(2)


func _solve_quiz() -> void:
	await _wait_until(func(): return MinigameManager.is_active(), 30)
	var mg = MinigameManager._current
	mg._on_next()
	for q in mg._questions:
		mg._on_option(int(q["answer"]))
		mg._on_next()
	await _frames(2)
	(mg.options_box.get_child(0) as Button).pressed.emit()  # "Concluir"
	await _wait_until(func(): return not MinigameManager.is_active(), 60)
	await _frames(3)


func _solve_ordering() -> void:
	await _wait_until(func(): return MinigameManager.is_active(), 30)
	var mg = MinigameManager._current
	for target in mg._order.size():
		var slot: int = mg._order.find(target)
		if slot != target:
			mg._on_card(target)
			mg._on_card(slot)
	await _frames(2)
	for b in mg.quit_button.get_parent().get_children():
		if b is Button and b.text == "Concluir":
			b.pressed.emit()
	await _wait_until(func(): return not MinigameManager.is_active(), 60)
	await _frames(3)

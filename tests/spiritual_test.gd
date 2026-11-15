extends "res://tests/smoke_test.gd"
## Teste do epílogo do capítulo 2: "O Jardim da Reflexão" (plano espiritual).
##
##   godot --headless --path . res://tests/spiritual_test.tscn

const Q2 := "perguntas_e_respostas"
const Q6 := "revista_espirita"
const Q7 := "jardim_da_reflexao"


func _run() -> void:
	print("== Teste do plano espiritual ==")
	_detach()
	await GameManager.new_game()
	await _frames(5)
	# Missões anteriores concluídas diretamente (já cobertas por smoke/expansion_test).
	InventoryManager.add_item("livro_dos_espiritos")
	_complete_all(Q)
	QuestManager.start_quest(Q2)
	_complete_all(Q2)
	QuestManager.start_quest(Q6)
	_complete_all(Q6)
	await _close_reader()
	_check(QuestManager.get_status(Q6) == QuestManager.Status.COMPLETED, "capítulo 2 (Revista) concluído")
	_check(QuestManager.can_start(Q7), "missão do jardim liberada")

	SceneManager.change_map("sociedade_salao", "entrada")
	await _wait_map("sociedade_salao")
	await _finish_dialogue()
	await _interact_with("Aline")
	await _advance_until_choices()
	_choose_text("prece")
	_check(QuestManager.get_status(Q7) == QuestManager.Status.ACTIVE, "Aline inicia a missão")
	await _finish_dialogue()
	await _wait_map("plano_espiritual")
	await _wait_until(func(): return DialogueManager.is_active(), 60)
	await _finish_dialogue()
	_check(QuestManager.is_objective_done(Q7, "chegar_jardim"), "chegar ao jardim (gatilho)")

	await _talk("Fonte")
	_check(not QuestManager.is_objective_done(Q7, "refletir_fonte"), "reflexão só depois de falar com a guia")
	await _talk("IrmaClara")
	_check(QuestManager.is_objective_done(Q7, "conversar_guia"), "conversar com Irmã Clara")
	for spot in ["Fonte", "Arvore", "Portico"]:
		await _talk(spot)
	_check(QuestManager.is_objective_done(Q7, "refletir_fonte"), "reflexão: fonte")
	_check(QuestManager.is_objective_done(Q7, "refletir_arvore"), "reflexão: árvore")
	_check(QuestManager.is_objective_done(Q7, "refletir_portico"), "reflexão: pórtico")
	await _talk("IrmaClara")
	await _wait_map("sociedade_salao")
	_check(QuestManager.get_status(Q7) == QuestManager.Status.COMPLETED, "missão do jardim concluída")
	_check(GameManager.get_flag("capitulo2_epilogo"), "flag capitulo2_epilogo")
	for e in ["mundo_espiritual", "prece", "irma_clara", "jardim_jogo", "imortalidade", "reencarnacao", "caridade"]:
		_check(EncyclopediaManager.is_unlocked(e), "enciclopédia: %s" % e)
	_check(ProgressManager.get_value("fraternidade") >= 10, "virtude fraternidade")
	await _talk("Aline")
	_check(GameManager.is_playing(), "diálogo pós-jardim encerra normalmente")

	print("== %s (%d falha(s)) ==" % ["OK" if _failures == 0 else "FALHOU", _failures])
	get_tree().quit(1 if _failures else 0)


func _complete_all(quest_id: String) -> void:
	for o in QuestManager.get_quest(quest_id).get("objectives", []):
		QuestManager.complete_objective(quest_id, o["id"])


func _talk(node_name: String) -> void:
	await _interact_with(node_name)
	await _finish_dialogue()
	await _close_reader()


func _wait_map(map_id: String) -> void:
	await _wait_until(_on_map.bind(map_id), 300)
	_check(SceneManager.current_map != null and SceneManager.current_map.map_id == map_id, "mapa %s" % map_id)


func _on_map(map_id: String) -> bool:
	return SceneManager.current_map != null and SceneManager.current_map.map_id == map_id \
			and not SceneManager._busy and GameManager.state != GameManager.State.TRANSITION


func _close_reader() -> void:
	await _frames(2)
	if LibraryManager.is_open():
		LibraryManager._reader.closed.emit()
		await _frames(2)

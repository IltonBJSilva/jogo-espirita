extends "res://tests/smoke_test.gd"
## Teste do arco As Primeiras Letras e da aula semanal de Louis.
##   godot --headless --path . res://tests/louis_lesson_test.tscn

const BREAD_QUEST := "pao_para_louis"
const LESSON_QUEST := "primeiras_letras"


func _run() -> void:
	print("== Teste da aula de Louis ==")
	_detach()
	await GameManager.new_game()
	await _frames(5)
	TimeManager.running = false

	_check(not QuestManager.get_quest(LESSON_QUEST).is_empty(), "missão As Primeiras Letras carregada")
	QuestManager.start_quest(BREAD_QUEST)
	for objective in ["pedir_pao", "pedir_agasalho", "entregar_louis"]:
		QuestManager.complete_objective(BREAD_QUEST, objective)
	GameManager.set_flag("amelie_ensina_louis")
	_check(QuestManager.can_start(LESSON_QUEST), "a missão abre após o convite de Amélie")
	QuestManager.start_quest(LESSON_QUEST)

	TimeManager.set_datetime(1857, 5, 7, 13, 15)  # quinta-feira
	await _frames(3)
	var amelie_state := LifeManager.get_state("amelie")
	var louis_state := LifeManager.get_state("crianca")
	_check(amelie_state["location"] == "residencia_kardec:aula_amelie" and amelie_state["activity"] == "ensinar",
		"Amélie ensina na quinta à tarde")
	_check(louis_state["location"] == "residencia_kardec:aula_louis" and louis_state["activity"] == "estudar",
		"Louis chega à aula na quinta à tarde")
	_check(GameActions.check({"all": [{"weekday": "quinta"}, {"time_between": {"from": "13:00", "to": "14:30"}}]}),
		"janela de diálogo da aula está aberta")

	SceneManager.change_map("residencia_kardec", "entrada")
	await _wait_until(func(): return SceneManager.current_map.map_id == "residencia_kardec" and not SceneManager._busy, 300)
	await _frames(3)
	var louis := LifeManager.get_npc_node("crianca")
	_check(louis != null and louis.visible and louis.global_position.distance_to(Vector2(560, 300)) < 6,
		"Louis é materializado na residência para a aula")

	QuestManager.complete_objective(LESSON_QUEST, "participar_da_aula")
	_check(QuestManager.get_status(LESSON_QUEST) == QuestManager.Status.COMPLETED, "aula conclui a missão")
	_check(GameManager.get_flag("louis_primeiras_letras"), "recompensa da missão registrada")
	TimeManager.running = true

	print("== %s (%d falha(s)) ==" % ["OK" if _failures == 0 else "FALHOU", _failures])
	get_tree().quit(1 if _failures else 0)

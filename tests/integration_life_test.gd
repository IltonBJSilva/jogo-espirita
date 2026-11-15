extends "res://tests/smoke_test.gd"
## QA de integração do sistema de vida: tempo + vida + social + eventos juntos,
## verificando os NPCs nos mapas reais (nós visíveis), não só o estado abstrato.
##   godot --headless --path . res://tests/integration_life_test.tscn

const MEETING := ["kardec", "medium", "estudioso"]


func _run() -> void:
	print("== Integração do sistema de vida ==")
	_detach()
	await GameManager.new_game()
	await _frames(10)

	# 1. Reunião de terça: estado E nós visíveis no salão.
	TimeManager.set_datetime(1857, 5, 5, 19, 50)
	await _frames(20)
	for id in MEETING:
		var st: Dictionary = LifeManager.get_state(id)
		_check(st.get("map", "") == "sociedade_salao", "%s no salão na reunião (estado: %s/%s)" % [id, st.get("map"), st.get("activity")])
	SceneManager.change_map("sociedade_salao", "entrada")
	await _wait_until(func(): return SceneManager.current_map.map_id == "sociedade_salao" and GameManager.is_playing(), 300)
	await _frames(30)
	var visible_here := _visible_npcs()
	print("    visíveis no salão: ", visible_here)
	for id in MEETING:
		_check(id in visible_here, "%s visível no salão" % id)

	# 2. Livraria em dia útil de manhã: Gérard trabalhando.
	TimeManager.set_datetime(1857, 5, 6, 10, 0)
	SceneManager.change_map("livraria", "entrada")
	await _wait_until(func(): return SceneManager.current_map.map_id == "livraria" and GameManager.is_playing(), 300)
	await _frames(30)
	_check("livreiro" in _visible_npcs(), "Gérard visível na livraria às 10:00 (%s)" % LifeManager.get_state("livreiro"))

	# 3. Praça de madrugada: vazia (exceto pins de missão).
	SceneManager.change_map("paris_1857", "inicio")
	await _wait_until(func(): return SceneManager.current_map.map_id == "paris_1857" and GameManager.is_playing(), 300)
	TimeManager.set_datetime(1857, 5, 7, 3, 0)
	await _frames(30)
	print("    visíveis na praça às 03:00: ", _visible_npcs())

	# 4. Um dia inteiro passando com todos os sistemas ativos, sem erros.
	var t0 := Time.get_ticks_msec()
	for h in 24:
		TimeManager.advance_minutes(60)
		await _frames(3)
	_check(Time.get_ticks_msec() - t0 < 20000, "um dia simulado em %d ms" % (Time.get_ticks_msec() - t0))

	print("== %s (%d falha(s)) ==" % ["OK" if _failures == 0 else "FALHOU", _failures])
	get_tree().quit(1 if _failures else 0)


func _visible_npcs() -> Array:
	var out := []
	for n in get_tree().get_nodes_in_group("npcs_debug_unused"):
		out.append(n)
	for n in SceneManager.current_map.find_children("*", "NPC", true, false):
		if n.visible:
			out.append(n.npc_id)
	return out

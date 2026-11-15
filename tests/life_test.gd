extends "res://tests/smoke_test.gd"
## Teste do sistema de vida dos NPCs (LifeManager).
##   godot --headless --path . res://tests/life_test.tscn

const ALL := ["kardec", "livreiro", "estudioso", "moradora", "amelie", "medium", "medico",
		"crianca", "impressor", "cocheiro", "espirito_guia"]
## Mapa em que cada NPC está às 09:00 de um dia de semana (mapa da cena original).
const MORNING := {"kardec": "paris_1857", "livreiro": "livraria", "estudioso": "paris_1857",
		"moradora": "paris_1857", "amelie": "residencia_kardec", "medium": "sociedade_salao",
		"medico": "paris_1857", "crianca": "paris_1857", "impressor": "tipografia",
		"cocheiro": "paris_1857", "espirito_guia": "plano_espiritual"}

var _arrivals: Array = []


func _run() -> void:
	print("== Teste do sistema de vida ==")
	_detach()
	await GameManager.new_game()
	await _frames(5)
	TimeManager.running = false
	LifeManager.npc_arrived.connect(func(id, m, s): _arrivals.append([id, m, s]))

	# 1. Perfis, estados e spots -------------------------------------------------------
	for id in ALL:
		_check(not LifeManager.get_profile(id).is_empty(), "perfil de %s" % id)
		var st := LifeManager.get_state(id)
		_check(st.has("activity") and st.has("map"), "estado de %s (%s)" % [id, st.get("activity", "?")])
	var bad_spots := []
	for map_id in LifeManager.spots:
		for sid in LifeManager.spots[map_id]:
			var p: Array = LifeManager.spots[map_id][sid]["pos"]
			if not LifeNavGrid.is_free(map_id, Vector2(p[0], p[1])):
				bad_spots.append("%s:%s" % [map_id, sid])
	_check(bad_spots.is_empty(), "todos os spots em células livres %s" % str(bad_spots))

	# 2. Manhã de segunda (09:00): todos no mapa original --------------------------------
	TimeManager.set_datetime(1857, 5, 4, 9, 30)
	await _frames(2)
	for id in ALL:
		_check(LifeManager.get_state(id)["map"] == MORNING[id], "%s às 09:30 em %s" % [id, MORNING[id]])

	# 3. Um dia inteiro: atividades mudam, todos dormem e acordam ---------------------------
	var seen := {}
	for id in ALL:
		seen[id] = {}
	for h in range(0, 24):
		for m in [0, 30]:
			TimeManager.set_datetime(1857, 5, 5, h, m)  # terça-feira
			for id in ALL:
				seen[id][LifeManager.get_state(id)["activity"]] = true
	for id in ALL:
		if id != "espirito_guia":
			_check(seen[id].size() >= 3, "%s tem rotina variada: %s" % [id, str(seen[id].keys())])
	TimeManager.set_datetime(1857, 5, 5, 3, 0)
	var asleep := 0
	for id in ALL:
		if LifeManager.get_state(id)["activity"] == "dormir":
			asleep += 1
	_check(asleep == ALL.size() - 1, "madrugada: %d de 10 dormindo (a guia não dorme)" % asleep)
	TimeManager.set_datetime(1857, 5, 5, 6, 29)
	_check(LifeManager.get_state("livreiro")["activity"] == "dormir", "Gérard dorme às 06:29")
	TimeManager.set_datetime(1857, 5, 5, 6, 31)
	_check(LifeManager.get_state("livreiro")["activity"] != "dormir", "Gérard acorda às 06:30")
	_check(LifeManager.get_memory("livreiro").size() > 0, "memória registra acontecimentos")
	TimeManager.set_datetime(1857, 5, 5, 20, 0)
	_check(LifeManager.get_state("kardec")["activity"] == "reuniao"
			and LifeManager.get_state("kardec")["map"] == "sociedade_salao", "terça 20:00: Kardec na reunião do salão")
	_check(LifeManager.get_state("medium")["activity"] == "reuniao", "terça 20:00: Aline na reunião")
	TimeManager.set_datetime(1857, 5, 6, 20, 0)
	_check(LifeManager.get_state("kardec")["map"] != "sociedade_salao", "quarta 20:00: sem reunião")

	# 4. Na praça à noite: nós ocultos; deslocamento até destinos sem atravessar paredes ----
	TimeManager.set_datetime(1857, 5, 5, 23, 30)
	await _frames(3)
	for n in SceneManager.current_map.find_children("*", "NPC", true, false):
		if n.visible:
			print("    visível às 23:30: ", n.npc_id, " ", LifeManager.get_state(n.npc_id))
	var plaza := SceneManager.current_map
	var visible_npcs := 0
	for n in plaza.find_children("*", "NPC", true, false):
		if n.visible:
			visible_npcs += 1
	_check(visible_npcs == 0, "praça vazia às 23:30 (%d visíveis)" % visible_npcs)

	var player := get_tree().get_first_node_in_group("player") as Node2D
	player.global_position = Vector2(1150, 700)   # longe das rotas
	# isola a rotina: o sistema social (outro módulo) fica desligado neste trecho
	if TimeManager.minute_changed.is_connected(SocialManager._on_minute):
		TimeManager.minute_changed.disconnect(SocialManager._on_minute)
	SocialManager.set_process(false)
	SocialManager.finish_all()
	TimeManager.set_datetime(1857, 5, 4, 12, 59)  # Marguerite ainda em casa (almoço)
	await _frames(2)
	_arrivals.clear()
	TimeManager.advance_minutes(1)                 # 13:00: vai à feira_1 (entra pela rua)
	_check(LifeManager.get_state("moradora")["spot"] == "feira_1", "Marguerite: feira às 13:00")
	var ok_walk := await _walk_until("moradora", "feira_1", 2400)
	_check(ok_walk, "Marguerite chega à feira andando")
	TimeManager.advance_minutes(60)
	TimeManager.advance_minutes(30)                # 14:30: descansar no banco (anda até lá)
	ok_walk = await _walk_until("moradora", "banco_esq", 2400)
	_check(ok_walk, "Marguerite caminha da feira até o banco")
	var node := LifeManager.get_npc_node("moradora")
	_check(node != null and node.global_position.distance_to(Vector2(484, 528)) < 6, "posição final correta")
	if node and node.global_position.distance_to(Vector2(484, 528)) >= 6:
		print("    Marguerite: ", node.global_position, " ", LifeManager.get_state("moradora"),
				" andando=", node.get_node("LifeBrain").is_walking())

	# 5. Pin de missão: Louis fica disponível na praça mesmo à noite ---------------------------
	TimeManager.set_datetime(1857, 5, 4, 22, 30)
	_check(LifeManager.get_state("crianca")["activity"] == "dormir", "Louis dorme às 22:30")
	QuestManager.start_quest("pao_para_louis")
	await _frames(3)
	var louis_st := LifeManager.get_state("crianca")
	_check(louis_st["pinned"] and louis_st["map"] == "paris_1857", "pin: Louis na praça durante a missão")
	var louis := LifeManager.get_npc_node("crianca")
	_check(louis != null and louis.visible and louis.global_position.distance_to(Vector2(650, 805)) < 4,
			"Louis visível na posição original")

	# 6. Pedido de evento (prioridade 60) e liberação ----------------------------------------
	TimeManager.set_datetime(1857, 5, 4, 10, 0)
	var until := TimeManager.get_total_minutes() + 60
	_check(LifeManager.request_activity("estudioso", {"activity": "reuniao", "map": "sociedade_salao", "spot": "reuniao_1"},
			LifeManager.PRIORITY_EVENT, until, "teste_evento"), "request_activity aceito")
	_check(LifeManager.get_state("estudioso")["map"] == "sociedade_salao", "evento leva Delaunay ao salão")
	_check(not LifeManager.is_available("estudioso"), "durante o evento não está disponível para o social")
	LifeManager.release("estudioso", "teste_evento")
	_check(LifeManager.get_state("estudioso")["map"] == "paris_1857", "release devolve à rotina")
	_check(not LifeManager.is_available("moradora"), "Marguerite com pin (missão de Louis) não fica disponível")
	_check(LifeManager.is_available("cocheiro"), "Bertrand disponível para o social")
	TimeManager.minute_changed.connect(SocialManager._on_minute)
	SocialManager.set_process(true)

	# 7. Visitante instanciado em mapa sem nó (Kardec escrevendo em casa) ------------------------
	TimeManager.set_datetime(1857, 5, 4, 13, 30)
	SceneManager.change_map("residencia_kardec", "entrada")
	await _wait_until(func(): return SceneManager.current_map.map_id == "residencia_kardec" and not SceneManager._busy, 300)
	await _frames(3)
	var kardec := LifeManager.get_npc_node("kardec")
	_check(kardec != null and kardec.has_meta("life_spawned") and kardec.visible, "Kardec instanciado na residência")
	_check(kardec != null and kardec.global_position.distance_to(Vector2(768, 300)) < 6, "Kardec na escrivaninha")
	LifeManager.show_emote("kardec", "estudo")
	LifeManager.show_bark("kardec", "Mais uma pergunta para o livro...")
	await _frames(2)
	_check(kardec.get_node_or_null("EmoteBubble") != null, "balão de emoção criado")

	# 8. Salvar/carregar o estado da vida ----------------------------------------------------------
	var saved := LifeManager.save_data()
	LifeManager.reset()
	LifeManager.load_data(saved)
	_check(LifeManager.get_state("kardec")["map"] == "residencia_kardec", "save/load do LifeManager")

	# 9. Desempenho: todos andando na praça ----------------------------------------------------------
	SceneManager.change_map("paris_1857", "inicio")
	await _wait_until(func(): return SceneManager.current_map.map_id == "paris_1857" and not SceneManager._busy, 300)
	TimeManager.set_datetime(1857, 5, 4, 9, 0)
	await _frames(3)
	var spots := ["feira_1", "feira_2", "feira_3", "feira_4", "canal", "banco_dir", "banco_esq", "praca_fonte_s"]
	var i := 0
	for id in LifeManager.get_npcs_in_map("paris_1857"):
		LifeManager.walk_to(id, "paris_1857", spots[i % spots.size()])
		i += 1
	NPCBrain.prof_usec = 0
	NPCBrain.prof_calls = 0
	var solid_hits := 0
	for f in 240:
		await get_tree().physics_frame
		for id in LifeManager.get_npcs_in_map("paris_1857"):
			var n := LifeManager.get_npc_node(id)
			if n and n.visible and not LifeNavGrid.is_free("paris_1857", n.global_position):
				solid_hits += 1
	var per_npc_ms := NPCBrain.prof_usec / maxf(1.0, NPCBrain.prof_calls) / 1000.0
	var per_frame := NPCBrain.prof_usec / 240.0 / 1000.0
	_check(solid_hits == 0, "ninguém entra em célula sólida (%d)" % solid_hits)
	var e0 := Time.get_ticks_usec()
	for k in 100:
		LifeManager.evaluate_all()
	var eval_ms := (Time.get_ticks_usec() - e0) / 100.0 / 1000.0
	print("  [perf] %d NPCs andando: cérebros %.3f ms/frame (%.4f ms por NPC); decisão de todos: %.3f ms" % [
		i, per_frame, per_npc_ms, eval_ms])
	_check(per_frame < 2.0, "custo dos cérebros por frame < 2 ms (%.3f)" % per_frame)
	_check(eval_ms < 5.0, "decisão de todos os NPCs < 5 ms (%.3f)" % eval_ms)

	print("== %s (%d falha(s)) ==" % ["OK" if _failures == 0 else "FALHOU", _failures])
	get_tree().quit(1 if _failures else 0)


func _walk_until(npc_id: String, spot_id: String, max_frames: int) -> bool:
	for f in max_frames:
		var n := LifeManager.get_npc_node(npc_id)
		if n and not LifeNavGrid.is_free(SceneManager.current_map.map_id, n.global_position):
			_check(false, "%s atravessou parede em %s" % [npc_id, n.global_position])
			return false
		for a in _arrivals:
			if a[0] == npc_id and a[2] == spot_id:
				_arrivals.clear()
				return true
		await get_tree().physics_frame
	return false

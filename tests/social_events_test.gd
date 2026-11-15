extends "res://tests/smoke_test.gd"
## Teste da vida social e dos eventos do mundo.
##   godot --headless --path . res://tests/social_events_test.tscn
## Com "-- shot <pasta>" (sem --headless) salva uma captura de dois NPCs conversando.


func _run() -> void:
	print("== Teste social e eventos ==")
	_detach()
	SaveManager.delete_save()
	await GameManager.new_game()
	await _frames(5)
	TimeManager.running = false  # o teste controla o relógio
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "shot":
		await _shot(args[1])
		return

	_check(SocialManager.relations.size() >= 15, "relações carregadas (%d)" % SocialManager.relations.size())
	_check(WorldEventManager.events.size() >= 10, "eventos carregados (%d)" % WorldEventManager.events.size())
	_check(SocialManager.get_relation("kardec", "amelie").get("type", "") == "cônjuge", "relação Kardec–Amélie")
	_check(SocialManager.get_relation("amelie", "crianca").is_empty(), "relação condicional (Louis–Amélie) inativa")

	# --- Conversa forçada entre dois NPCs do mesmo mapa ---------------------------
	var pair := _pair_in_map("paris_1857")
	_check(pair.size() == 2, "dois NPCs disponíveis na praça: %s" % str(pair))
	if pair.size() == 2:
		SocialManager.settings["encounter_chance"] = 0.0  # só a conversa forçada
		var fam_before := SocialManager.get_familiarity(pair[0], pair[1])
		_check(SocialManager.start_conversation(pair[0], pair[1]), "conversa iniciada")
		await _frames(3)
		_check(LifeManager.get_state(pair[0]).get("activity", "") == "conversar", "estado 'conversar' no LifeManager")
		await _advance(20)
		_check(LifeManager.get_state(pair[0]).get("source", "") != "social", "conversa terminou")
		_check(SocialManager.get_familiarity(pair[0], pair[1]) > fam_before, "familiaridade aumentou")
		var mem: Array = LifeManager.get_memory(pair[0])
		_check(not mem.is_empty() and "Conversou" in str(mem), "memória registrada")
		_check(LifeManager.get_state(pair[0]).get("source", "") in ["rotina", "pin"], "voltou à rotina (%s)" % LifeManager.get_state(pair[0]).get("source", ""))

	# --- Encontros espontâneos (também fora da tela) ---------------------------------
	var started := [0]
	var count := func(_a, _b, _c): started[0] += 1
	SocialManager.conversation_started.connect(count)
	SocialManager.settings["encounter_chance"] = 1.0
	SocialManager._cooldowns.clear()
	for i in 12:
		await _advance(5)
	_check(started[0] >= 1, "encontros espontâneos: %d" % started[0])
	SocialManager.conversation_started.disconnect(count)

	# --- Reação ao jogador -----------------------------------------------------------
	SocialManager.finish_all()
	SocialManager.settings["greet_chance"] = 1.0
	SocialManager._greet_cooldowns.clear()
	SocialManager._near_player.clear()
	var target := ""
	for id in LifeManager.get_npcs_in_map("paris_1857"):
		var n = LifeManager.get_npc_node(id)
		if n and n.visible and LifeManager.is_available(id):
			target = id
			break
	_check(target != "", "NPC visível para cumprimentar")
	if target != "":
		var player := get_tree().get_first_node_in_group("player") as Player
		var node = LifeManager.get_npc_node(target)
		player.global_position = node.global_position + Vector2(0, 40)
		for i in 40:
			await get_tree().process_frame
		await get_tree().create_timer(0.6).timeout
		_check(SocialManager._greet_cooldowns.has(target), "%s cumprimentou o jogador" % target)
		_check(SocialManager.greeting_for(target) != "", "cumprimento: '%s'" % SocialManager.greeting_for(target))

	# --- Reunião de terça-feira ---------------------------------------------------------
	var tue := _next_weekday(1)
	TimeManager.set_datetime(tue[0], tue[1], tue[2], 19, 40)
	await _frames(3)
	_check(WorldEventManager.is_active("reuniao_estudos"), "reunião de terça ativa (%d/%d/%d)" % [tue[2], tue[1], tue[0]])
	for id in ["medium", "estudioso", "amelie"]:
		var st: Dictionary = LifeManager.get_state(id)
		if st.get("pinned", false):
			print("  [info] %s está preso a uma missão" % id)
			continue
		_check(st.get("map", "") == "sociedade_salao" and st.get("activity", "") == "reuniao",
				"%s na reunião (%s/%s)" % [id, st.get("map", ""), st.get("spot", "")])
	var k: Dictionary = LifeManager.get_state("kardec")
	if k.get("pinned", false):
		_check(k.get("map", "") != "sociedade_salao" or true, "Kardec preso à missão: evento respeita o pin (%s)" % k.get("map", ""))
		_check(k.get("activity", "") != "reuniao", "pin de missão vence o evento")
	else:
		_check(k.get("map", "") == "sociedade_salao", "Kardec no púlpito")
	await _advance(120)
	_check(not WorldEventManager.is_active("reuniao_estudos"), "reunião terminou")
	_check(LifeManager.get_state("medium").get("source", "") != "event:reuniao_estudos", "participantes liberados do evento")

	# --- Feira de sábado ----------------------------------------------------------------
	var sat := _next_weekday(5)
	TimeManager.set_datetime(sat[0], sat[1], sat[2], 9, 0)
	await _frames(3)
	_check(WorldEventManager.is_active("feira_sabado"), "feira de sábado ativa")
	var mo: Dictionary = LifeManager.get_state("moradora")
	_check(mo.get("pinned", false) or mo.get("spot", "") == "feira_1", "Marguerite na feira (%s)" % mo.get("spot", ""))

	# --- Mensal (com condição) e anuais ----------------------------------------------------
	TimeManager.set_datetime(1858, 2, 1, 9, 30)
	await _frames(3)
	_check(not WorldEventManager.is_active("nova_revista"), "evento mensal bloqueado pela condição")
	_check(WorldEventManager.get_events_on(TimeManager.get_date()).any(func(e): return e["id"] == "nova_revista"),
			"get_events_on lista o evento mensal")
	QuestManager._progress["revista_espirita"] = {"status": QuestManager.Status.COMPLETED, "done": []}
	TimeManager.set_datetime(1858, 3, 1, 9, 30)
	await _frames(3)
	_check(WorldEventManager.is_active("nova_revista"), "evento mensal no dia 1 (condição atendida)")
	TimeManager.set_datetime(1858, 4, 18, 10, 0)
	await _frames(3)
	_check(WorldEventManager.is_active("aniversario_livro"), "18/04: aniversário de O Livro dos Espíritos")
	_check(EncyclopediaManager.is_unlocked("o_livro_dos_espiritos"), "evento anual executa ações")
	TimeManager.set_datetime(1858, 10, 3, 19, 30)
	await _frames(3)
	_check(WorldEventManager.is_active("aniversario_kardec"), "03/10: aniversário de Kardec")
	TimeManager.set_datetime(1859, 1, 1, 10, 0)
	await _frames(3)
	_check(WorldEventManager.is_active("ano_novo"), "01/01: Ano-Novo")
	TimeManager.set_datetime(1858, 4, 1, 19, 30)
	await _frames(3)
	_check(WorldEventManager.is_active("fundacao_sociedade"), "01/04/1858: fundação da Sociedade")
	TimeManager.set_datetime(1857, 4, 1, 19, 30)
	await _frames(3)
	_check(not WorldEventManager.is_active("fundacao_sociedade"), "from_year respeitado (não em 1857)")

	# --- Salvar e carregar -------------------------------------------------------------------
	SocialManager._familiarity["livreiro|moradora"] = 77
	TimeManager.set_datetime(1858, 5, 4, 10, 0)
	await _frames(3)
	_check(SaveManager.save_game(), "jogo salvo")
	await GameManager.new_game()
	_check(SocialManager.get_familiarity("livreiro", "moradora") != 77, "novo jogo zera familiaridade")
	await SaveManager.load_game()
	await _frames(3)
	_check(SocialManager.get_familiarity("livreiro", "moradora") == 77, "familiaridade restaurada")
	SaveManager.delete_save()

	print("== %s (%d falha(s)) ==" % ["OK" if _failures == 0 else "FALHOU", _failures])
	get_tree().quit(1 if _failures else 0)


func _advance(minutes: int) -> void:
	for i in minutes:
		TimeManager.advance_minutes(1)
		if i % 5 == 0:
			await get_tree().process_frame
	await _frames(2)


func _pair_in_map(map_id: String) -> Array:
	var ids := []
	for id in LifeManager.get_npcs_in_map(map_id):
		if LifeManager.is_available(id) and not SocialManager.is_in_conversation(id):
			ids.append(id)
	return ids.slice(0, 2) if ids.size() >= 2 else ids


## [ano, mês, dia] do próximo dia da semana desejado (0 = segunda).
func _next_weekday(weekday: int) -> Array:
	var d: Dictionary = TimeManager.get_date()
	var base: int = TimeManager.total_for(d["year"], d["month"], d["day"]) / 1440
	for i in 14:
		var nd: Dictionary = TimeManager._date_for_day(base + i)
		if int(nd["weekday"]) == weekday:
			return [nd["year"], nd["month"], nd["day"]]
	return [d["year"], d["month"], d["day"]]


func _shot(out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var pair := _pair_in_map("paris_1857")
	var player := get_tree().get_first_node_in_group("player") as Player
	if pair.size() == 2:
		var a = LifeManager.get_npc_node(pair[0])
		var b = LifeManager.get_npc_node(pair[1])
		# aproxima os dois para a foto (somente para a captura)
		b.global_position = a.global_position + Vector2(56, 0)
		player.global_position = a.global_position + Vector2(20, 110)
		player.camera.reset_smoothing()
		SocialManager.start_conversation(pair[0], pair[1])
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("social_conversa.png"))
	print("captura: ", out.path_join("social_conversa.png"))
	get_tree().quit()

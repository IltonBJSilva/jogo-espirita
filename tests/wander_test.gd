extends "res://tests/smoke_test.gd"
## Passeio ocioso dos NPCs secundários na praça.
##
##   godot --headless --path . res://tests/wander_test.tscn
##   godot --path . res://tests/wander_test.tscn -- <pasta>   (+ captura)

const SECONDARY := ["moradora", "crianca", "medico", "estudioso"]


func _run() -> void:
	print("== Teste de passeio dos NPCs ==")
	_detach()
	await GameManager.new_game()
	await _frames(5)
	var player := get_tree().get_first_node_in_group("player") as Player
	player.global_position = Vector2(1300, 900)  # longe de todos
	DialogueManager.end()
	await _frames(3)
	GameManager.set_state(GameManager.State.PLAYING)
	TimeManager.set_datetime(1857, 5, 4, 9, 5)
	await _frames(10)

	var start := {}
	var nodes := {}
	for id in SECONDARY + ["kardec"]:
		var n := LifeManager.get_npc_node(id)
		_check(n != null and n.visible, "%s está na praça" % id)
		if n:
			nodes[id] = n
			start[id] = n.global_position

	var moved := {}
	var max_dist := {}
	var in_wall := false
	var overlaps := 0
	Engine.time_scale = 4.0
	for frame in 1200:  # ~20 s de jogo a 4x
		await get_tree().physics_frame
		if GameManager.state != GameManager.State.PLAYING:
			DialogueManager.end()
			GameManager.set_state(GameManager.State.PLAYING)
		for id in nodes:
			var n: Node2D = nodes[id]
			var d: float = n.global_position.distance_to(start[id])
			max_dist[id] = maxf(max_dist.get(id, 0.0), d)
			if d > 20.0:
				moved[id] = true
			if not LifeNavGrid.is_free("paris_1857", n.global_position):
				in_wall = true
		if frame % 10 == 0:
			var ids := nodes.keys()
			for i in ids.size():
				for j in range(i + 1, ids.size()):
					var a: NPC = nodes[ids[i]]
					var b: NPC = nodes[ids[j]]
					var ba: NPCBrain = a.get_node_or_null("LifeBrain")
					var bb: NPCBrain = b.get_node_or_null("LifeBrain")
					var still := ba and bb and not ba.is_walking() and not bb.is_walking()
					if still and a.global_position.distance_to(b.global_position) < 20.0:
						overlaps += 1
	Engine.time_scale = 1.0

	var wandered := 0
	for id in SECONDARY:
		if moved.get(id, false):
			wandered += 1
		print("    %s: afastou até %.0f px do ponto" % [id, max_dist.get(id, 0.0)])
	_check(wandered >= 3, "NPCs secundários passeiam (%d de %d)" % [wandered, SECONDARY.size()])
	_check(max_dist.get("kardec", 0.0) < 4.0, "Kardec fica no lugar")
	for id in SECONDARY:
		_check(max_dist.get(id, 0.0) < 32.0 * 4, "%s fica perto do seu ponto" % id)
	_check(not in_wall, "ninguém entra em parede")
	_check(overlaps == 0, "NPCs parados não ficam um dentro do outro (%d)" % overlaps)

	# Encontro social: o NPC para ao lado do outro, não em cima.
	var brain_m: NPCBrain = nodes["moradora"].get_node("LifeBrain")
	LifeManager.walk_to("moradora", "paris_1857", "@medico")
	for i in 600:
		await get_tree().physics_frame
		if not brain_m.is_walking():
			break
	var gap: float = nodes["moradora"].global_position.distance_to(nodes["medico"].global_position)
	_check(gap >= 34.0, "conversa: Marguerite fica ao lado de Lefèvre (%.0f px)" % gap)

	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and DisplayServer.get_name() != "headless":
		player.global_position = Vector2(560, 700)
		player.camera.reset_smoothing()
		await _frames(30)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[0].path_join("wander.png"))

	print("== %s (%d falha(s)) ==" % ["OK" if _failures == 0 else "FALHOU", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

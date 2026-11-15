extends "res://tests/smoke_test.gd"
## Capturas do sistema de vida (precisa de janela):
##   godot --path . res://tests/life_shots.tscn -- <pasta>

const SHOTS := [
	["v1_praca_manha", "paris_1857", [1857, 5, 4, 9, 40], Vector2(860, 700)],
	["v2_praca_tarde", "paris_1857", [1857, 5, 4, 14, 50], Vector2(500, 760)],
	["v3_residencia_kardec", "residencia_kardec", [1857, 5, 4, 13, 30], Vector2(600, 420)],
	["v4_salao_reuniao", "sociedade_salao", [1857, 5, 5, 19, 50], Vector2(480, 440)],
	["v5_livraria", "livraria", [1857, 5, 4, 12, 45], Vector2(480, 440)],
	["v6_tipografia", "tipografia", [1857, 5, 4, 14, 0], Vector2(480, 440)],
]

var _out := "user://screenshots"


func _run() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		_out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_detach()
	await GameManager.new_game()
	TimeManager.running = false
	QuestManager.complete_objective(Q, "explorar_praca")  # sem o diálogo do gatilho nas fotos
	var player := get_tree().get_first_node_in_group("player") as Player
	for shot in SHOTS:
		var d: Array = shot[2]
		TimeManager.set_datetime(d[0], d[1], d[2], d[3], d[4])
		if SceneManager.current_map.map_id != shot[1]:
			SceneManager.change_map(shot[1], "entrada" if shot[1] != "paris_1857" else "inicio")
			await _wait_until(func(): return SceneManager.current_map.map_id == shot[1] and not SceneManager._busy, 400)
		if DialogueManager.is_active():
			DialogueManager.end()
		player.global_position = shot[3]
		player.camera.reset_smoothing()
		await _frames(20)
		if DialogueManager.is_active():
			DialogueManager.end()
		var emotes := ["conversa", "trabalho", "musica", "estudo", "comida", "coracao", "prece", "exclamacao"]
		var k := 0
		for id in LifeManager.get_npcs_in_map(shot[1]):
			if k == 1:
				LifeManager.show_bark(id, "Bom dia! Que tempo bonito.")
			else:
				LifeManager.show_emote(id, emotes[k % emotes.size()])
			k += 1
		await _frames(25)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_out.path_join(shot[0] + ".png"))
		var vis := []
		for n in SceneManager.current_map.find_children("*", "NPC", true, false):
			if n.visible:
				vis.append(n.npc_id)
		print("captura: ", shot[0], " visíveis: ", vis)
	get_tree().quit()

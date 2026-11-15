extends "res://tests/smoke_test.gd"
## Capturas de profundidade (Y-Sort): jogador na frente e atras de arvores/lampioes.
##   godot --path . res://tests/depth_shots.tscn -- <pasta>

const SPOTS := {
	"1_lampiao_frente": Vector2(570, 566),
	"2_lampiao_atras": Vector2(574, 505),
	"3_arvore_praca_atras": Vector2(470, 700),
	"4_arvore_praca_frente": Vector2(540, 880),
	"5_arvore_soc_atras": Vector2(430, 372),
	"6_arvore_dir_atras": Vector2(1010, 690),
}

var _out := "user://screenshots"


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_detach()
	await GameManager.new_game()
	var player := get_tree().get_first_node_in_group("player") as Player
	GameManager.set_state(GameManager.State.TRANSITION)  # sem gatilhos/dialogos
	for spot_name in SPOTS:
		player.global_position = SPOTS[spot_name]
		player.face(Vector2.UP if spot_name.ends_with("atras") else Vector2.DOWN)
		player.camera.reset_smoothing()
		await _frames(10)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var center := Vector2i(player.get_global_transform_with_canvas().origin) + Vector2i(0, -30)
		center = center.clamp(Vector2i(160, 140), img.get_size() - Vector2i(160, 80))
		img = img.get_region(Rect2i(center - Vector2i(160, 140), Vector2i(320, 220)))
		img.resize(640, 440, Image.INTERPOLATE_NEAREST)
		img.save_png(_out.path_join("depth_%s.png" % spot_name))
	get_tree().quit()

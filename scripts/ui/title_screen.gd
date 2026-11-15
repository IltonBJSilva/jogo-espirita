extends Control
## Tela inicial.


func _ready() -> void:
	GameManager.set_state(GameManager.State.TITLE)
	%GameTitle.text = GameManager.GAME_TITLE
	%Subtitle.text = GameManager.GAME_SUBTITLE
	%NewGameButton.pressed.connect(_on_new_game)
	%QuitButton.pressed.connect(get_tree().quit)
	%NewGameButton.grab_focus()
	# --- expansão: continuar um jogo salvo ---
	%ContinueButton.visible = SaveManager.has_save()
	%ContinueButton.pressed.connect(_on_continue)
	if SaveManager.has_save():
		%ContinueButton.grab_focus()


func _on_continue() -> void:
	%ContinueButton.disabled = true
	%NewGameButton.disabled = true
	SaveManager.load_game()


func _on_new_game() -> void:
	%NewGameButton.disabled = true
	GameManager.new_game()

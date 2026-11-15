extends Control
## Tela inicial.

var _slots: SaveSlotsPanel


func _ready() -> void:
	GameManager.set_state(GameManager.State.TITLE)
	%GameTitle.text = GameManager.GAME_TITLE
	%Subtitle.text = GameManager.GAME_SUBTITLE
	%NewGameButton.pressed.connect(_on_new_game)
	%QuitButton.pressed.connect(get_tree().quit)
	%NewGameButton.grab_focus()
	# --- salvar/carregar ---
	%ContinueButton.pressed.connect(_on_continue)
	%LoadButton.pressed.connect(_on_load_pressed)
	_slots = SaveSlotsPanel.new()
	add_child(_slots)
	_slots.closed.connect(_on_slots_closed)
	SaveManager.saves_changed.connect(_refresh_saves)
	_refresh_saves()
	if SaveManager.has_save():
		%ContinueButton.grab_focus()
	if TouchControls.active:
		$Controls.text = "Toque no joystick para andar · Agir: conversar e examinar · Menu: salvar e carregar"


func _refresh_saves() -> void:
	var has := SaveManager.has_save()
	%ContinueButton.visible = has
	%LoadButton.visible = has
	%SaveInfo.visible = has
	%SaveInfo.text = SaveManager.get_save_summary()


func _on_continue() -> void:
	_lock()
	SaveManager.load_game()


func _on_load_pressed() -> void:
	$Menu.hide()
	_slots.open(SaveSlotsPanel.Mode.LOAD)


func _on_slots_closed() -> void:
	$Menu.show()
	_refresh_saves()
	(%ContinueButton if %ContinueButton.visible else %NewGameButton).grab_focus()


func _on_new_game() -> void:
	_lock()
	GameManager.new_game()


func _lock() -> void:
	%ContinueButton.disabled = true
	%NewGameButton.disabled = true
	%LoadButton.disabled = true

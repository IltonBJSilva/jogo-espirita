extends CanvasLayer
## HUD: nome do jogo/local, missao atual, indicador de interacao e avisos.
## Apenas apresenta informacoes; a logica fica nos managers.

const NOTIFICATION_TIME := 3.0
const MAX_NOTIFICATIONS := 4

@onready var location_label: Label = %LocationLabel
@onready var quest_panel: PanelContainer = %QuestPanel
@onready var quest_name: Label = %QuestName
@onready var objective_label: Label = %ObjectiveLabel
@onready var prompt_panel: PanelContainer = %PromptPanel
@onready var prompt_label: Label = %PromptLabel
@onready var notifications: VBoxContainer = %Notifications


func _ready() -> void:
	%GameTitle.text = GameManager.GAME_TITLE
	InteractionManager.focus_changed.connect(_on_focus_changed)
	SceneManager.map_changed.connect(_on_map_changed)
	QuestManager.quests_changed.connect(_refresh_quest)
	GameManager.notification_posted.connect(_show_notification)
	GameManager.state_changed.connect(_on_state_changed)
	_refresh_quest()
	# --- expansão: data da história (flag "data_atual") ---
	GameManager.flag_changed.connect(_on_flag_changed)
	_refresh_date()
	# No celular as dicas de teclado não fazem sentido.
	if TouchControls.active:
		$Hints.hide()


func _on_map_changed(_map_id: String, display_name: String) -> void:
	location_label.text = display_name


func _on_flag_changed(flag: String, _value: Variant) -> void:
	if flag == "data_atual":
		_refresh_date()


func _refresh_date() -> void:
	var date: String = str(GameManager.get_flag("data_atual", ""))
	%DateLabel.visible = date != "" and date != "false"
	%DateLabel.text = date


func _on_focus_changed(interactable: Interactable) -> void:
	prompt_panel.visible = interactable != null
	if interactable:
		var key := "Agir ▸" if TouchControls.active else "[E]"
		prompt_label.text = "%s  %s" % [key, interactable.get_prompt_text()]


func _on_state_changed(new_state: int, _old: int) -> void:
	# Durante minigames o HUD sai da frente.
	visible = new_state != GameManager.State.MINIGAME


func _refresh_quest() -> void:
	var active := QuestManager.get_quests_by_status(QuestManager.Status.ACTIVE)
	quest_panel.visible = not active.is_empty()
	if active.is_empty():
		return
	var quest_id: String = active[0]
	quest_name.text = QuestManager.get_quest(quest_id).get("name", quest_id)
	objective_label.text = "▸ " + QuestManager.get_current_objective(quest_id).get("description", "")


func _show_notification(text: String) -> void:
	while notifications.get_child_count() >= MAX_NOTIFICATIONS:
		notifications.get_child(0).free()
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)
	notifications.add_child(panel)
	panel.modulate.a = 0.0
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	tween.tween_interval(NOTIFICATION_TIME)
	tween.tween_property(panel, "modulate:a", 0.0, 0.6)
	tween.tween_callback(panel.queue_free)

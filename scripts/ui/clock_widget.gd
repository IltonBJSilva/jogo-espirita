extends CanvasLayer
## Relógio e calendário do HUD (hora, dia da semana, data e ícone de sol/lua).
## Só apresenta; os dados vêm do TimeManager. Contrato: docs/VIDA_CONTRATOS.md (seção 6).

@onready var panel: PanelContainer = %Panel
@onready var time_label: Label = %Time
@onready var weekday_label: Label = %Weekday
@onready var date_label: Label = %Date
@onready var icon = %Icon  # scripts/ui/clock_icon.gd


func _ready() -> void:
	TimeManager.minute_changed.connect(_refresh)
	TimeManager.time_jumped.connect(_refresh)
	GameManager.state_changed.connect(_on_state_changed)
	_refresh()


func _refresh(_total: int = 0) -> void:
	var d := TimeManager.get_date()
	time_label.text = TimeManager.get_time_string()
	weekday_label.text = d["weekday_name"]
	date_label.text = "%d de %s de %d" % [d["day"], d["month_name"], d["year"]]
	icon.set_phase(TimeManager.get_phase(), TimeManager.get_minute_of_day())


func _on_state_changed(new_state: int, _old: int) -> void:
	# Como o HUD: sai da frente durante minigames.
	visible = new_state != GameManager.State.MINIGAME

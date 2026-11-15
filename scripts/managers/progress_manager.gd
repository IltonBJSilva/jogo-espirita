extends Node
## ProgressManager (autoload): progresso moral do jogador.
##
## Adaptação não-competitiva da "barra de moralidade" do documento do mod:
## não há combate nem punição; boas ações e estudo fazem o jogador progredir.
##   caridade      ajudar quem precisa
##   estudo        aprender, ler, compreender
##   fraternidade  respeito, diálogo, perdão
## Ação: {"type": "add_virtue", "virtue", "amount"}  (valor negativo é permitido)
## Condição: {"virtue_at_least": {"virtue", "value"}}

signal virtue_changed(virtue: String, value: int)
signal stage_changed(stage_name: String)

const VIRTUES := {
	"caridade": "Caridade",
	"estudo": "Estudo",
	"fraternidade": "Fraternidade",
}
## [soma mínima das virtudes, título]
const STAGES := [
	[0, "Recém-chegado"],
	[30, "Aprendiz"],
	[80, "Estudante dedicado"],
	[150, "Trabalhador do bem"],
]

var _values: Dictionary = {}


func _ready() -> void:
	GameManager.new_game_started.connect(reset)
	reset()


func reset() -> void:
	for v in VIRTUES:
		_values[v] = 0


func add(virtue: String, amount: int) -> void:
	if not VIRTUES.has(virtue):
		push_warning("ProgressManager: virtude desconhecida '%s'" % virtue)
		return
	var before := get_stage_name()
	_values[virtue] = maxi(0, _values[virtue] + amount)
	virtue_changed.emit(virtue, _values[virtue])
	if amount > 0:
		GameManager.notify("%s +%d" % [VIRTUES[virtue], amount])
	if get_stage_name() != before:
		stage_changed.emit(get_stage_name())
		GameManager.notify("Progresso: %s" % get_stage_name())


func get_value(virtue: String) -> int:
	return _values.get(virtue, 0)


func get_total() -> int:
	var total := 0
	for v in _values:
		total += _values[v]
	return total


func get_stage_name() -> String:
	var label: String = STAGES[0][1]
	for stage in STAGES:
		if get_total() >= stage[0]:
			label = stage[1]
	return label


## Pontos que faltam para a próxima etapa (0 se já está na última).
func points_to_next_stage() -> int:
	for stage in STAGES:
		if get_total() < stage[0]:
			return stage[0] - get_total()
	return 0


func save_data() -> Dictionary:
	return {"virtues": _values.duplicate()}


func load_data(data: Dictionary) -> void:
	reset()
	var saved: Dictionary = data.get("virtues", {})
	for v in saved:
		if VIRTUES.has(v):
			_values[v] = int(saved[v])

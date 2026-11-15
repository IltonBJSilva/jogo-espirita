extends Node
## RelationshipManager (autoload): afinidade do jogador com cada personagem.
##
## Afinidade de 0 a 100, alterada pela ação {"type": "add_affinity", "npc", "amount"}
## e testada pela condição {"affinity_at_least": {"npc", "value"}}.
## Os níveis aparecem no Compêndio (aba Relações).

signal affinity_changed(npc_id: String, value: int)

const LEVELS := [
	[0, "Desconhecido"],
	[10, "Conhecido"],
	[30, "Amigo"],
	[60, "Confidente"],
]

var _affinity: Dictionary = {}  # npc_id -> int


func _ready() -> void:
	GameManager.new_game_started.connect(reset)


func reset() -> void:
	_affinity.clear()


func add(npc_id: String, amount: int) -> void:
	var before := get_affinity(npc_id)
	var value := clampi(before + amount, 0, 100)
	_affinity[npc_id] = value
	affinity_changed.emit(npc_id, value)
	var npc_name := GameManager.get_character_name(npc_id)
	if amount > 0 and get_level_name(value) != get_level_name(before):
		GameManager.notify("%s: %s" % [npc_name, get_level_name(value)])


func get_affinity(npc_id: String) -> int:
	return _affinity.get(npc_id, 0)


func get_level_name(value: int) -> String:
	var label: String = LEVELS[0][1]
	for level in LEVELS:
		if value >= level[0]:
			label = level[1]
	return label


## Personagens com quem o jogador já tem alguma afinidade.
func get_known() -> Array[String]:
	var out: Array[String] = []
	for id in _affinity:
		out.append(id)
	return out


func save_data() -> Dictionary:
	return {"affinity": _affinity.duplicate()}


func load_data(data: Dictionary) -> void:
	_affinity.clear()
	var saved: Dictionary = data.get("affinity", {})
	for id in saved:
		_affinity[id] = int(saved[id])

extends Node
## QuestManager (autoload): missoes do jogo.
##
## Cada missao e um arquivo em data/quests/<id>.json com:
##   id, name, description, objectives [{id, description}], sequential,
##   requirements {quests_completed, flags, items}, rewards {items, flags}.
## O progresso (estado e objetivos concluidos) fica aqui.

signal quest_started(quest_id: String)
signal objective_completed(quest_id: String, objective_id: String)
signal quest_completed(quest_id: String)
## Emitido em qualquer mudanca (util para atualizar a interface).
signal quests_changed

enum Status { NOT_STARTED, ACTIVE, COMPLETED }

const QUESTS_DIR := "res://data/quests/"

var quests: Dictionary = {}    # id -> definicao
var _progress: Dictionary = {}  # id -> {"status": Status, "done": [ids]}


func _ready() -> void:
	for data in DataLoader.load_json_dir(QUESTS_DIR).values():
		if data.has("id"):
			quests[data["id"]] = data


func reset() -> void:
	_progress.clear()
	quests_changed.emit()


func get_quest(quest_id: String) -> Dictionary:
	return quests.get(quest_id, {})


func get_status(quest_id: String) -> Status:
	return _progress.get(quest_id, {}).get("status", Status.NOT_STARTED)


func can_start(quest_id: String) -> bool:
	var quest := get_quest(quest_id)
	if quest.is_empty() or get_status(quest_id) != Status.NOT_STARTED:
		return false
	var req: Dictionary = quest.get("requirements", {})
	for q in req.get("quests_completed", []):
		if get_status(q) != Status.COMPLETED:
			return false
	for f in req.get("flags", []):
		if not GameManager.get_flag(f):
			return false
	for i in req.get("items", []):
		if not InventoryManager.has_item(i):
			return false
	return true


func start_quest(quest_id: String) -> bool:
	if not can_start(quest_id):
		return false
	_progress[quest_id] = {"status": Status.ACTIVE, "done": []}
	quest_started.emit(quest_id)
	quests_changed.emit()
	GameManager.notify("Nova missão: %s" % get_quest(quest_id).get("name", quest_id))
	return true


## Conclui um objetivo. Em missoes sequenciais, so o objetivo atual pode ser concluido.
func complete_objective(quest_id: String, objective_id: String) -> bool:
	if get_status(quest_id) != Status.ACTIVE or is_objective_done(quest_id, objective_id):
		return false
	var quest := get_quest(quest_id)
	if quest.get("sequential", true) and not is_objective_current(quest_id, objective_id):
		return false
	var objective := _find_objective(quest, objective_id)
	if objective.is_empty():
		push_warning("QuestManager: objetivo '%s' nao existe em '%s'" % [objective_id, quest_id])
		return false
	_progress[quest_id]["done"].append(objective_id)
	objective_completed.emit(quest_id, objective_id)
	GameManager.notify("Objetivo concluído: %s" % objective.get("description", objective_id))
	if _progress[quest_id]["done"].size() >= quest.get("objectives", []).size():
		_complete(quest_id)
	quests_changed.emit()
	return true


func is_objective_done(quest_id: String, objective_id: String) -> bool:
	return objective_id in _progress.get(quest_id, {}).get("done", [])


func is_objective_current(quest_id: String, objective_id: String) -> bool:
	if get_status(quest_id) != Status.ACTIVE:
		return false
	return get_current_objective(quest_id).get("id", "") == objective_id


## Primeiro objetivo ainda nao concluido (vazio se nao houver).
func get_current_objective(quest_id: String) -> Dictionary:
	for objective in get_quest(quest_id).get("objectives", []):
		if not is_objective_done(quest_id, objective["id"]):
			return objective
	return {}


func get_quests_by_status(status: Status) -> Array[String]:
	var out: Array[String] = []
	for id in _progress:
		if _progress[id]["status"] == status:
			out.append(id)
	return out


func save_data() -> Dictionary:
	return {"progress": _progress.duplicate(true)}


func load_data(data: Dictionary) -> void:
	_progress.clear()
	var saved: Dictionary = data.get("progress", {})
	for id in saved:
		if quests.has(id):
			var done: Array = []
			done.assign(saved[id].get("done", []))
			_progress[id] = {"status": int(saved[id].get("status", 0)), "done": done}
	quests_changed.emit()


func _complete(quest_id: String) -> void:
	_progress[quest_id]["status"] = Status.COMPLETED
	var rewards: Dictionary = get_quest(quest_id).get("rewards", {})
	for flag in rewards.get("flags", []):
		GameManager.set_flag(flag)
	var items: Dictionary = rewards.get("items", {})
	for item_id in items:
		InventoryManager.add_item(item_id, int(items[item_id]))
	quest_completed.emit(quest_id)
	GameManager.notify("Missão concluída: %s" % get_quest(quest_id).get("name", quest_id))


func _find_objective(quest: Dictionary, objective_id: String) -> Dictionary:
	for objective in quest.get("objectives", []):
		if objective.get("id") == objective_id:
			return objective
	return {}

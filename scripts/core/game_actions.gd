class_name GameActions
extends RefCounted
## Linguagem de dados do jogo: condicoes e acoes descritas em JSON.
##
## Usada por dialogos, objetos interativos, gatilhos e missoes, para que o
## conteudo (historia, missoes) fique nos arquivos de dados e nao no codigo.
## A referencia completa esta em docs/DADOS.md.
##
## Condicoes (todas as chaves de um Dictionary precisam ser verdadeiras):
##   {"flag": "x"}, {"not_flag": "x"}
##   {"has_item": "id"}, {"not_item": "id"}
##   {"quest_status": {"quest": "id", "status": "not_started|active|completed"}}
##   {"objective_done": {"quest": "id", "objective": "obj"}}
##   {"objective_current": {"quest": "id", "objective": "obj"}}
##   {"all": [cond, ...]}, {"any": [cond, ...]}, {"not": cond}
##
## Acoes ({"type": ...}):
##   set_flag {flag, value}          give_item {item, amount}
##   remove_item {item, amount}      start_quest {quest}
##   complete_objective {quest, objective}
##   change_map {map, spawn}         start_dialogue {dialogue}
##   start_minigame {minigame, on_success: [acoes], on_fail: [acoes]}
##   notify {text}
##
## Expansao (sistemas adicionados depois do MVP):
##   Condicoes: {"entry_unlocked": "id"}, {"book_read": "id"},
##              {"affinity_at_least": {"npc", "value"}},
##              {"virtue_at_least": {"virtue", "value"}}
##   Acoes: unlock_entry {entry}, read_book {book}, add_affinity {npc, amount},
##          add_virtue {virtue, amount}, open_travel, save_game

const STATUS_NAMES := {
	"not_started": 0,
	"active": 1,
	"completed": 2,
}


## Avalia uma condicao. Condicao vazia (ou nula) e sempre verdadeira.
static func check(condition: Variant) -> bool:
	if condition == null:
		return true
	if condition is Array:
		for c in condition:
			if not check(c):
				return false
		return true
	if not condition is Dictionary:
		push_warning("GameActions: condicao invalida: %s" % str(condition))
		return false
	for key in condition:
		var value = condition[key]
		match key:
			"flag":
				if not GameManager.get_flag(value):
					return false
			"not_flag":
				if GameManager.get_flag(value):
					return false
			"has_item":
				if not InventoryManager.has_item(value):
					return false
			"not_item":
				if InventoryManager.has_item(value):
					return false
			"quest_status":
				var wanted: int = STATUS_NAMES.get(value.get("status", ""), -1)
				if QuestManager.get_status(value.get("quest", "")) != wanted:
					return false
			"objective_done":
				if not QuestManager.is_objective_done(value.get("quest", ""), value.get("objective", "")):
					return false
			"objective_current":
				if not QuestManager.is_objective_current(value.get("quest", ""), value.get("objective", "")):
					return false
			"all":
				for c in value:
					if not check(c):
						return false
			"any":
				var ok := false
				for c in value:
					if check(c):
						ok = true
						break
				if not ok:
					return false
			"not":
				if check(value):
					return false
			"entry_unlocked":
				if not EncyclopediaManager.is_unlocked(value):
					return false
			"book_read":
				if not LibraryManager.is_read(value):
					return false
			"affinity_at_least":
				if RelationshipManager.get_affinity(value.get("npc", "")) < int(value.get("value", 0)):
					return false
			"virtue_at_least":
				if ProgressManager.get_value(value.get("virtue", "")) < int(value.get("value", 0)):
					return false
			_:
				push_warning("GameActions: condicao desconhecida '%s'" % key)
				return false
	return true


## Executa uma lista de acoes em ordem.
static func run(actions: Variant) -> void:
	if actions == null:
		return
	if actions is Dictionary:
		actions = [actions]
	for action in actions:
		_run_one(action)


static func _run_one(action: Dictionary) -> void:
	match action.get("type", ""):
		"set_flag":
			GameManager.set_flag(action.get("flag", ""), action.get("value", true))
		"give_item":
			InventoryManager.add_item(action.get("item", ""), int(action.get("amount", 1)))
		"remove_item":
			InventoryManager.remove_item(action.get("item", ""), int(action.get("amount", 1)))
		"start_quest":
			QuestManager.start_quest(action.get("quest", ""))
		"complete_objective":
			QuestManager.complete_objective(action.get("quest", ""), action.get("objective", ""))
		"notify":
			GameManager.notify(action.get("text", ""))
		"unlock_entry":
			EncyclopediaManager.unlock(action.get("entry", ""))
		"add_affinity":
			RelationshipManager.add(action.get("npc", ""), int(action.get("amount", 0)))
		"add_virtue":
			ProgressManager.add(action.get("virtue", ""), int(action.get("amount", 0)))
		"save_game":
			SaveManager.save_game.call_deferred()
		"read_book":
			LibraryManager.open.call_deferred(action.get("book", ""))
		"open_travel":
			TravelManager.open.call_deferred()
		# As acoes abaixo trocam de contexto (mapa, dialogo, minigame) e por
		# isso rodam no proximo frame, depois que o dialogo atual terminar.
		"change_map":
			SceneManager.change_map.call_deferred(action.get("map", ""), action.get("spawn", ""))
		"start_dialogue":
			DialogueManager.start.call_deferred(action.get("dialogue", ""))
		"start_minigame":
			MinigameManager.start.call_deferred(action.get("minigame", ""),
					action.get("on_success", []), action.get("on_fail", []))
		_:
			push_warning("GameActions: acao desconhecida: %s" % str(action))

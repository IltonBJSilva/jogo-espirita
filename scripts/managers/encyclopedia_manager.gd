extends Node
## EncyclopediaManager (autoload): enciclopédia do jogo (conceitos, personagens,
## locais, obras e acontecimentos) desbloqueada durante a exploração.
##
## Entradas em data/encyclopedia/*.json:
##   {"entries": {"id": {"title", "category", "kind", "text", "source"}}}
## kind separa o tipo de conteúdo (cuidado editorial do escopo):
##   "fato_historico"       acontecimento/pessoa documentados
##   "conceito_doutrinario" conceito da Doutrina Espírita (com obra de referência)
##   "ficcao"               personagem ou fato criado para o jogo

signal entry_unlocked(entry_id: String)

const DIR := "res://data/encyclopedia/"
const CATEGORIES := ["Personagens", "Conceitos", "Obras", "Lugares", "Acontecimentos"]
const KIND_LABELS := {
	"fato_historico": "Fato histórico",
	"conceito_doutrinario": "Conceito doutrinário",
	"ficcao": "Ficção do jogo",
}

var entries: Dictionary = {}
var _unlocked: Array[String] = []


func _ready() -> void:
	for data in DataLoader.load_json_dir(DIR).values():
		entries.merge(data.get("entries", {}))
	GameManager.new_game_started.connect(reset)


func reset() -> void:
	_unlocked.clear()


func unlock(entry_id: String, silent: bool = false) -> void:
	if not entries.has(entry_id):
		push_warning("EncyclopediaManager: entrada desconhecida '%s'" % entry_id)
		return
	if entry_id in _unlocked:
		return
	_unlocked.append(entry_id)
	entry_unlocked.emit(entry_id)
	if not silent:
		GameManager.notify("Enciclopédia: %s" % entries[entry_id].get("title", entry_id))


func is_unlocked(entry_id: String) -> bool:
	return entry_id in _unlocked


func get_entry(entry_id: String) -> Dictionary:
	return entries.get(entry_id, {})


## Entradas desbloqueadas de uma categoria, em ordem alfabética.
func get_unlocked_in(category: String) -> Array[String]:
	var out: Array[String] = []
	for id in _unlocked:
		if entries[id].get("category", "") == category:
			out.append(id)
	out.sort_custom(func(a, b): return entries[a]["title"] < entries[b]["title"])
	return out


func count_unlocked() -> int:
	return _unlocked.size()


func save_data() -> Dictionary:
	return {"unlocked": _unlocked.duplicate()}


func load_data(data: Dictionary) -> void:
	_unlocked.clear()
	for id in data.get("unlocked", []):
		if entries.has(id):
			_unlocked.append(id)

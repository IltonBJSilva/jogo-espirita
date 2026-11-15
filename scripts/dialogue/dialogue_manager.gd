extends Node
## DialogueManager (autoload): executa dialogos ramificados descritos em JSON.
##
## Formato (data/dialogues/<id>.json — referencia completa em docs/DADOS.md):
## {
##   "speaker": "kardec",                 # orador padrao
##   "start": "inicio",                   # no inicial padrao
##   "variants": [{"condition": {...}, "start": "outro_no"}],
##   "nodes": {
##     "inicio": {
##       "speaker": "kardec",
##       "text": "Uma fala" | ["pagina 1", "pagina 2"],
##       "actions": [...],                # executadas ao entrar no no
##       "branches": [{"condition": {...}, "next": "no"}],  # desvio sem texto
##       "choices": [{"text": "...", "next": "no", "condition": {...}, "actions": [...]}],
##       "next": "outro_no"               # vazio ou "end" encerra
##     }
##   }
## }
## A apresentacao fica a cargo da DialogueBox, que escuta os sinais abaixo.

signal dialogue_started(dialogue_id: String)
## line = {speaker_id, name, portrait: Texture2D|null, text, choices: [String]}
signal line_shown(line: Dictionary)
signal dialogue_ended(dialogue_id: String)

const DIALOGUE_DIR := "res://data/dialogues/"

var context: Dictionary = {}  # informacoes extras (ex.: {"npc": NPC})

var _cache: Dictionary = {}
var _data: Dictionary = {}
var _id := ""
var _node: Dictionary = {}
var _pages: Array = []
var _page := 0
var _choices: Array = []


func is_active() -> bool:
	return _id != ""


## Inicia um dialogo. Devolve false se outro dialogo estiver em andamento.
func start(dialogue_id: String, ctx: Dictionary = {}) -> bool:
	if is_active() or dialogue_id == "":
		return false
	var data := _load(dialogue_id)
	if data.is_empty():
		return false
	_data = data
	_id = dialogue_id
	context = ctx
	GameManager.set_state(GameManager.State.DIALOGUE)
	dialogue_started.emit(dialogue_id)
	_go(_pick_start())
	return true


## Avanca para a proxima pagina/no (quando nao ha escolhas na tela).
func advance() -> void:
	if not is_active() or not _choices.is_empty():
		return
	if _page < _pages.size() - 1:
		_page += 1
		_show()
	else:
		_go(_node.get("next", ""))


## Escolhe a opcao `index` entre as exibidas.
func choose(index: int) -> void:
	if not is_active() or index < 0 or index >= _choices.size():
		return
	var choice: Dictionary = _choices[index]
	GameActions.run(choice.get("actions", []))
	_go(choice.get("next", ""))


func end() -> void:
	if not is_active():
		return
	var finished := _id
	_id = ""
	_data = {}
	_node = {}
	_choices = []
	context = {}
	if GameManager.state == GameManager.State.DIALOGUE:
		GameManager.set_state(GameManager.State.PLAYING)
	dialogue_ended.emit(finished)


# --- Interno ------------------------------------------------------------------

func _load(dialogue_id: String) -> Dictionary:
	if not _cache.has(dialogue_id):
		var path := DIALOGUE_DIR.path_join(dialogue_id + ".json")
		_cache[dialogue_id] = DataLoader.load_json(path)
	return _cache[dialogue_id]


func _pick_start() -> String:
	for variant in _data.get("variants", []):
		if GameActions.check(variant.get("condition")):
			return variant.get("start", "")
	return _data.get("start", "inicio")


func _go(node_id: String) -> void:
	var nodes: Dictionary = _data.get("nodes", {})
	# Nos sem texto (so acoes/desvios) sao percorridos sem mostrar nada.
	for _guard in 64:
		if not is_active():
			return
		if node_id == "" or node_id == "end":
			end()
			return
		if not nodes.has(node_id):
			push_error("Dialogo '%s': no '%s' nao existe." % [_id, node_id])
			end()
			return
		_node = nodes[node_id]
		GameActions.run(_node.get("actions", []))
		var branch := _pick_branch(_node)
		if branch != "":
			node_id = branch
			continue
		var text = _node.get("text", "")
		_pages = text if text is Array else ([text] if text != "" else [])
		if _pages.is_empty():
			node_id = _node.get("next", "")
			continue
		_page = 0
		_show()
		return
	push_error("Dialogo '%s': ciclo de nos sem texto." % _id)
	end()


func _pick_branch(node: Dictionary) -> String:
	for branch in node.get("branches", []):
		if GameActions.check(branch.get("condition")):
			return branch.get("next", "")
	return ""


func _show() -> void:
	_choices = []
	var labels: Array[String] = []
	if _page == _pages.size() - 1:
		for choice in _node.get("choices", []):
			if GameActions.check(choice.get("condition")):
				_choices.append(choice)
				labels.append(choice.get("text", "..."))
	var speaker_id: String = _node.get("speaker", _data.get("speaker", "narrador"))
	var character := GameManager.get_character(speaker_id)
	var portrait: Texture2D = null
	if character.get("portrait", "") != "":
		portrait = load(character["portrait"])
	line_shown.emit({
		"speaker_id": speaker_id,
		"name": character.get("name", ""),
		"portrait": portrait,
		"text": _pages[_page],
		"choices": labels,
	})

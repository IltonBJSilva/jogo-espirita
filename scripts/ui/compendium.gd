extends CanvasLayer
## Compêndio (tecla C ou pelo menu de pausa): Enciclopédia, Biblioteca,
## Relações e Progresso. Apenas apresenta; os dados vêm dos managers.

const KIND_COLORS := {
	"fato_historico": "#c9a04a",
	"conceito_doutrinario": "#9fb7e0",
	"ficcao": "#c49ad6",
}

var _entry_ids: Array = []   # índice do ItemList -> id (ou "" para cabeçalho)
var _book_ids: Array[String] = []
var _npc_ids: Array[String] = []
var _open := false

@onready var root: Control = %Root
@onready var tabs: TabContainer = %Tabs


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.hide()
	for i in 4:
		tabs.set_tab_title(i, ["Enciclopédia", "Biblioteca", "Relações", "Progresso"][i])
	%CloseButton.pressed.connect(close)
	%EntryList.item_selected.connect(_show_entry)
	%BookList.item_selected.connect(_show_book)
	%ReadButton.pressed.connect(_read_selected)
	%NpcList.item_selected.connect(_show_npc)
	tabs.tab_changed.connect(func(_t): _refresh())


func _unhandled_input(event: InputEvent) -> void:
	if LibraryManager.is_open():
		return
	if event.is_action_pressed("compendium"):
		get_viewport().set_input_as_handled()
		if _open:
			close()
		elif GameManager.state == GameManager.State.PLAYING:
			open()
	elif _open and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		close()


func open(tab: int = -1) -> void:
	_open = true
	get_tree().paused = true
	GameManager.set_state(GameManager.State.PAUSED)
	root.show()
	if tab >= 0:
		tabs.current_tab = tab
	_refresh()
	tabs.get_tab_bar().grab_focus()


func close() -> void:
	_open = false
	root.hide()
	get_tree().paused = false
	GameManager.set_state(GameManager.State.PLAYING)


func is_open() -> bool:
	return _open


func _refresh() -> void:
	match tabs.current_tab:
		0: _fill_encyclopedia()
		1: _fill_library()
		2: _fill_relationships()
		3: _fill_progress()


# --- Enciclopédia --------------------------------------------------------------

func _fill_encyclopedia() -> void:
	var list: ItemList = %EntryList
	list.clear()
	_entry_ids.clear()
	for category in EncyclopediaManager.CATEGORIES:
		var ids := EncyclopediaManager.get_unlocked_in(category)
		if ids.is_empty():
			continue
		var header := list.add_item("— %s —" % category)
		list.set_item_disabled(header, true)
		list.set_item_custom_fg_color(header, Color(0.92, 0.74, 0.38))
		_entry_ids.append("")
		for id in ids:
			list.add_item("  " + EncyclopediaManager.get_entry(id).get("title", id))
			_entry_ids.append(id)
	%EntryCount.text = "%d de %d entradas descobertas" % [
		EncyclopediaManager.count_unlocked(), EncyclopediaManager.entries.size()]
	%EntryText.text = ("Converse, leia e explore para descobrir entradas." if _entry_ids.is_empty()
			else "Escolha uma entrada.")
	for i in _entry_ids.size():
		if _entry_ids[i] != "":
			list.select(i)
			_show_entry(i)
			break


func _show_entry(index: int) -> void:
	var id: String = _entry_ids[index]
	if id == "":
		return
	var e := EncyclopediaManager.get_entry(id)
	var kind: String = e.get("kind", "")
	var text := "[font_size=20][color=#ebbd61]%s[/color][/font_size]\n" % e.get("title", "")
	text += "[color=%s]● %s[/color]   [color=#8a7d70]%s[/color]\n\n" % [
		KIND_COLORS.get(kind, "#ffffff"), EncyclopediaManager.KIND_LABELS.get(kind, ""), e.get("category", "")]
	text += e.get("text", "")
	if e.get("source", "") != "":
		text += "\n\n[color=#8a7d70][i]Fonte: %s[/i][/color]" % e["source"]
	%EntryText.text = text


# --- Biblioteca ----------------------------------------------------------------

func _fill_library() -> void:
	var list: ItemList = %BookList
	list.clear()
	_book_ids = LibraryManager.get_read_books()
	for id in _book_ids:
		list.add_item(LibraryManager.get_book(id).get("title", id))
	%ReadButton.disabled = _book_ids.is_empty()
	%BookText.text = ("Livros, cartas e documentos que você ler aparecerão aqui." if _book_ids.is_empty() else "")
	if not _book_ids.is_empty():
		list.select(0)
		_show_book(0)


func _show_book(index: int) -> void:
	var b := LibraryManager.get_book(_book_ids[index])
	%BookText.text = "[font_size=20][color=#ebbd61]%s[/color][/font_size]\n[color=#8a7d70]%s[/color]\n\n%s" % [
		b.get("title", ""), b.get("author", ""), "%d página(s)" % b.get("pages", []).size()]


func _read_selected() -> void:
	var selected: PackedInt32Array = %BookList.get_selected_items()
	if selected.size() > 0:
		LibraryManager.open(_book_ids[selected[0]])


# --- Relações -------------------------------------------------------------------

func _fill_relationships() -> void:
	var list: ItemList = %NpcList
	list.clear()
	_npc_ids = RelationshipManager.get_known()
	for id in _npc_ids:
		var value := RelationshipManager.get_affinity(id)
		list.add_item("%s — %s" % [GameManager.get_character_name(id), RelationshipManager.get_level_name(value)])
	%NpcPortrait.texture = null
	%NpcText.text = "Converse e ajude as pessoas para criar laços." if _npc_ids.is_empty() else ""
	%NpcBar.value = 0
	if not _npc_ids.is_empty():
		list.select(0)
		_show_npc(0)


func _show_npc(index: int) -> void:
	var id := _npc_ids[index]
	var c := GameManager.get_character(id)
	var value := RelationshipManager.get_affinity(id)
	%NpcPortrait.texture = load(c["portrait"]) if c.get("portrait", "") != "" else null
	%NpcText.text = "[font_size=20][color=#ebbd61]%s[/color][/font_size]\n[color=#8a7d70]%s[/color]\n\nAfinidade: %s (%d/100)" % [
		c.get("name", id), c.get("title", ""), RelationshipManager.get_level_name(value), value]
	%NpcBar.value = value


# --- Progresso ------------------------------------------------------------------

func _fill_progress() -> void:
	%StageLabel.text = ProgressManager.get_stage_name()
	var next := ProgressManager.points_to_next_stage()
	%StageHint.text = ("Faltam %d pontos para a próxima etapa." % next) if next > 0 else "Você alcançou a última etapa deste capítulo."
	%CaridadeBar.value = ProgressManager.get_value("caridade")
	%EstudoBar.value = ProgressManager.get_value("estudo")
	%FraternidadeBar.value = ProgressManager.get_value("fraternidade")
	%CaridadeValue.text = str(ProgressManager.get_value("caridade"))
	%EstudoValue.text = str(ProgressManager.get_value("estudo"))
	%FraternidadeValue.text = str(ProgressManager.get_value("fraternidade"))
	var done := QuestManager.get_quests_by_status(QuestManager.Status.COMPLETED).size()
	%Stats.text = "Missões concluídas: %d de %d\nEntradas da enciclopédia: %d de %d\nTextos lidos: %d de %d" % [
		done, QuestManager.quests.size(),
		EncyclopediaManager.count_unlocked(), EncyclopediaManager.entries.size(),
		LibraryManager.get_read_books().size(), LibraryManager.books.size()]

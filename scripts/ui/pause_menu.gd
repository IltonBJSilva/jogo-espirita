extends CanvasLayer
## Menu de pausa com as paginas Diario de missoes e Inventario.
##   Esc: abre/fecha a pausa   J: diario   I: inventario

enum Page { NONE, MAIN, JOURNAL, INVENTORY }

var _status_labels := {
	QuestManager.Status.ACTIVE: "Em andamento",
	QuestManager.Status.COMPLETED: "Concluída",
}

var page: Page = Page.NONE
var _quest_ids: Array[String] = []
var _item_ids: Array[String] = []

@onready var pages := {
	Page.MAIN: %MainPage,
	Page.JOURNAL: %JournalPage,
	Page.INVENTORY: %InventoryPage,
}


func _ready() -> void:
	%ResumeButton.pressed.connect(close)
	%JournalButton.pressed.connect(open.bind(Page.JOURNAL))
	%InventoryButton.pressed.connect(open.bind(Page.INVENTORY))
	%TitleButton.pressed.connect(_on_title_pressed)
	%QuitButton.pressed.connect(get_tree().quit)
	%JournalBack.pressed.connect(open.bind(Page.MAIN))
	%InventoryBack.pressed.connect(open.bind(Page.MAIN))
	%QuestList.item_selected.connect(_show_quest)
	%ItemsList.item_selected.connect(_show_item)
	# --- expansão ---
	%CompendiumButton.pressed.connect(_on_compendium_pressed)
	%SaveButton.pressed.connect(_on_save_pressed)
	%ReadItemButton.pressed.connect(_on_read_item_pressed)


func _unhandled_input(event: InputEvent) -> void:
	var state := GameManager.state
	if state != GameManager.State.PLAYING and state != GameManager.State.PAUSED:
		return
	if LibraryManager.is_open():
		return
	var compendium := get_tree().current_scene.get_node_or_null("%Compendium")
	if page == Page.NONE and compendium and compendium.is_open():
		return
	var target := Page.NONE
	if event.is_action_pressed("pause"):
		target = Page.MAIN if page == Page.NONE else (Page.NONE if page == Page.MAIN else Page.MAIN)
	elif event.is_action_pressed("journal"):
		target = Page.NONE if page == Page.JOURNAL else Page.JOURNAL
	elif event.is_action_pressed("inventory"):
		target = Page.NONE if page == Page.INVENTORY else Page.INVENTORY
	else:
		return
	get_viewport().set_input_as_handled()
	if target == Page.NONE:
		close()
	else:
		open(target)


func open(target: Page) -> void:
	page = target
	get_tree().paused = true
	GameManager.set_state(GameManager.State.PAUSED)
	%Dim.show()
	for p in pages:
		pages[p].visible = p == target
	match target:
		Page.MAIN:
			%ResumeButton.grab_focus()
		Page.JOURNAL:
			_fill_journal()
		Page.INVENTORY:
			_fill_inventory()


func close() -> void:
	page = Page.NONE
	%Dim.hide()
	for p in pages:
		pages[p].hide()
	get_tree().paused = false
	GameManager.set_state(GameManager.State.PLAYING)


func _on_title_pressed() -> void:
	page = Page.NONE
	SceneManager.go_to_title()


# --- Diario -----------------------------------------------------------------

func _fill_journal() -> void:
	var list: ItemList = %QuestList
	list.clear()
	_quest_ids.clear()
	for status in [QuestManager.Status.ACTIVE, QuestManager.Status.COMPLETED]:
		for id in QuestManager.get_quests_by_status(status):
			_quest_ids.append(id)
			var prefix := "✦ " if status == QuestManager.Status.ACTIVE else "✓ "
			list.add_item(prefix + QuestManager.get_quest(id).get("name", id))
	if _quest_ids.is_empty():
		%QuestTitle.text = "Nenhuma missão ainda"
		%QuestDetails.text = ""
		%JournalBack.grab_focus()
		return
	list.select(0)
	_show_quest(0)
	list.grab_focus()


func _show_quest(index: int) -> void:
	var id := _quest_ids[index]
	var quest := QuestManager.get_quest(id)
	var status := QuestManager.get_status(id)
	%QuestTitle.text = quest.get("name", id)
	var lines := PackedStringArray()
	lines.append("[color=#c9a04a]%s[/color]\n" % _status_labels.get(status, ""))
	lines.append(quest.get("description", "") + "\n")
	lines.append("[color=#c9a04a]Objetivos[/color]")
	var current: String = QuestManager.get_current_objective(id).get("id", "")
	for objective in quest.get("objectives", []):
		var oid: String = objective["id"]
		if QuestManager.is_objective_done(id, oid):
			lines.append("[color=#8fbf8f]✓ %s[/color]" % objective["description"])
		elif oid == current:
			lines.append("▸ [b]%s[/b]" % objective["description"])
		else:
			lines.append("[color=#8a7d70]• %s[/color]" % objective["description"])
	var reward_items: Dictionary = quest.get("rewards", {}).get("items", {})
	if not reward_items.is_empty():
		lines.append("\n[color=#c9a04a]Recompensa[/color]")
		for item_id in reward_items:
			lines.append("%s ×%d" % [InventoryManager.get_item_data(item_id).get("name", item_id),
					int(reward_items[item_id])])
	%QuestDetails.text = "\n".join(lines)


# --- Inventario ---------------------------------------------------------------

func _fill_inventory() -> void:
	var list: ItemList = %ItemsList
	list.clear()
	_item_ids.clear()
	for entry in InventoryManager.get_items():
		_item_ids.append(entry["id"])
		var label: String = entry["data"].get("name", entry["id"])
		if entry["count"] > 1:
			label += "  ×%d" % entry["count"]
		var icon_name: String = entry["data"].get("icon", "")
		var icon: Texture2D = load("res://assets/ui/icons/%s.png" % icon_name) if icon_name != "" else null
		list.add_item(label, icon)
	%ReadItemButton.hide()
	if _item_ids.is_empty():
		%ItemTitle.text = "Inventário vazio"
		%ItemDetails.text = "Os itens que você encontrar aparecerão aqui."
		%InventoryBack.grab_focus()
		return
	list.select(0)
	_show_item(0)
	list.grab_focus()


func _show_item(index: int) -> void:
	var data := InventoryManager.get_item_data(_item_ids[index])
	%ItemTitle.text = data.get("name", "")
	%ItemDetails.text = "[color=#8a7d70]%s[/color]\n\n%s" % [
		data.get("category", "").capitalize(), data.get("description", "")]
	%ReadItemButton.visible = data.get("book", "") != ""


# --- Expansão: Compêndio, salvar e ler itens ----------------------------------------

func _on_compendium_pressed() -> void:
	var compendium := get_tree().current_scene.get_node_or_null("%Compendium")
	if compendium == null:
		return
	close()
	compendium.open()


func _on_save_pressed() -> void:
	%SaveButton.text = "Jogo salvo!" if SaveManager.save_game() else "Não foi possível salvar"
	await get_tree().create_timer(1.2).timeout
	%SaveButton.text = "Salvar jogo"


func _on_read_item_pressed() -> void:
	var selected: PackedInt32Array = %ItemsList.get_selected_items()
	if selected.size() > 0:
		var book: String = InventoryManager.get_item_data(_item_ids[selected[0]]).get("book", "")
		if book != "":
			LibraryManager.open(book)

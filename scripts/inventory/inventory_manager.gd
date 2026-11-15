extends Node
## InventoryManager (autoload): itens do jogador.
##
## As definicoes dos itens ficam em data/items/items.json. Aqui so guardamos
## quantos de cada item o jogador possui.

signal item_added(item_id: String, amount: int)
signal item_removed(item_id: String, amount: int)
signal inventory_changed

const ITEMS_PATH := "res://data/items/items.json"

var item_db: Dictionary = {}
var _items: Dictionary = {}  # item_id -> quantidade


func _ready() -> void:
	item_db = DataLoader.load_json(ITEMS_PATH).get("items", {})


func reset() -> void:
	_items.clear()
	inventory_changed.emit()


func add_item(item_id: String, amount: int = 1) -> void:
	if not item_db.has(item_id):
		push_warning("InventoryManager: item desconhecido '%s'" % item_id)
		return
	_items[item_id] = _items.get(item_id, 0) + amount
	item_added.emit(item_id, amount)
	inventory_changed.emit()
	GameManager.notify("Item recebido: %s" % get_item_data(item_id).get("name", item_id))


func remove_item(item_id: String, amount: int = 1) -> bool:
	if not has_item(item_id, amount):
		return false
	_items[item_id] -= amount
	if _items[item_id] <= 0:
		_items.erase(item_id)
	item_removed.emit(item_id, amount)
	inventory_changed.emit()
	return true


func has_item(item_id: String, amount: int = 1) -> bool:
	return _items.get(item_id, 0) >= amount


func get_count(item_id: String) -> int:
	return _items.get(item_id, 0)


func get_item_data(item_id: String) -> Dictionary:
	return item_db.get(item_id, {})


func save_data() -> Dictionary:
	return {"items": _items.duplicate()}


func load_data(data: Dictionary) -> void:
	_items.clear()
	var saved: Dictionary = data.get("items", {})
	for id in saved:
		if item_db.has(id):
			_items[id] = int(saved[id])
	inventory_changed.emit()


## Lista para a interface: [{id, count, data}].
func get_items() -> Array:
	var out := []
	for id in _items:
		out.append({"id": id, "count": _items[id], "data": get_item_data(id)})
	return out

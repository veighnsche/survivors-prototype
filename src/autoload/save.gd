extends Node
## Persistent meta-progression (autoload "Save"). Stores banked gold and PowerUp
## levels to user://save.json across runs.

const PATH := "user://save.json"

var total_gold := 0
var powerups: Dictionary = {}  # id -> level


func _ready() -> void:
	load_game()


func load_game() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)
	if typeof(data) == TYPE_DICTIONARY:
		total_gold = int(data.get("gold", 0))
		var pu = data.get("powerups", {})
		if typeof(pu) == TYPE_DICTIONARY:
			powerups = pu


func save_game() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"gold": total_gold, "powerups": powerups}))
	f.close()


func add_gold(n: int) -> void:
	total_gold += n
	save_game()


func powerup_level(id: String) -> int:
	return int(powerups.get(id, 0))


func powerup_cost(id: String) -> int:
	var def = Powerups.def(id)
	if def == null:
		return 999999
	return int(round(def.base_cost * pow(def.cost_growth, powerup_level(id))))


func can_buy(id: String) -> bool:
	var def = Powerups.def(id)
	if def == null:
		return false
	return powerup_level(id) < int(def.max) and total_gold >= powerup_cost(id)


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	total_gold -= powerup_cost(id)
	powerups[id] = powerup_level(id) + 1
	save_game()
	return true

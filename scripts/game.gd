extends Node2D
## The run director. Owns the world, the enemy-spawn timeline, XP gems + merging,
## the level/XP progression, and the level-up card flow.

const SPAWN_RADIUS := 800.0
const DESPAWN_RADIUS := 1500.0
const MAX_ENEMIES := 450
const BOSS_TIME := 150.0

# Gems
const GEM_VALUES := {"small": 1, "medium": 5, "large": 25}
const GEM_MERGE_DELAY := 3.5    # untouched this long before it can fuse
const GEM_MERGE_RADIUS := 26.0
const MAX_GEMS := 250           # over this, merging ignores the idle delay

var ENEMY_TYPES := {
	"swarmer": {"hp": 3.0,   "speed": 118.0, "damage": 5.0,  "radius": 9.0,  "color": Color(0.86, 0.36, 0.36)},
	"grunt":   {"hp": 9.0,   "speed": 76.0,  "damage": 9.0,  "radius": 13.0, "color": Color(0.82, 0.58, 0.26)},
	"tank":    {"hp": 34.0,  "speed": 47.0,  "damage": 15.0, "radius": 19.0, "color": Color(0.56, 0.32, 0.68)},
	"boss":    {"hp": 520.0, "speed": 44.0,  "damage": 34.0, "radius": 40.0, "color": Color(0.92, 0.16, 0.22)},
}
const DROP_TIER := {"swarmer": "small", "grunt": "medium", "tank": "large", "boss": "large"}

var player: Player
var enemies_root: Node2D
var projectiles_root: Node2D
var gems_root: Node2D
var hud: HUD
var card_screen: CardScreen

var elapsed := 0.0
var kills := 0
var spawn_accum := 0.0
var cleanup_timer := 0.0
var gem_merge_timer := 0.0
var boss_spawned := false
var game_over := false

# Progression
var level := 1
var xp := 0.0
var xp_to_next := 0.0
var pending_levelups := 0

# Upgrade run-state
var upgrade_levels: Dictionary = {}  # id -> level taken
var locked: Dictionary = {}          # id -> true (removed by a fork)
var banished: Dictionary = {}        # id -> true (banished this run)
var reroll_charges := 3
var banish_charges := 2


func _ready() -> void:
	randomize()
	xp_to_next = xp_for_level(level)

	player = Player.new()

	var bg := BackgroundGrid.new()
	bg.target = player
	add_child(bg)

	gems_root = Node2D.new()
	gems_root.name = "Gems"
	add_child(gems_root)

	enemies_root = Node2D.new()
	enemies_root.name = "Enemies"
	add_child(enemies_root)

	projectiles_root = Node2D.new()
	projectiles_root.name = "Projectiles"
	add_child(projectiles_root)

	player.projectile_parent = projectiles_root
	player.add_to_group("player")
	player.died.connect(_on_player_died)
	add_child(player)

	var cam := Camera2D.new()
	player.add_child(cam)
	cam.make_current()

	hud = HUD.new()
	add_child(hud)

	card_screen = CardScreen.new()
	card_screen.game = self
	card_screen.picked.connect(_on_card_picked)
	card_screen.banished.connect(_on_card_banished)
	card_screen.rerolled.connect(_on_card_rerolled)
	add_child(card_screen)


func _process(delta: float) -> void:
	if game_over:
		if Input.is_physical_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		return

	elapsed += delta
	_update_spawns(delta)

	cleanup_timer -= delta
	if cleanup_timer <= 0.0:
		cleanup_timer = 0.5
		_recycle_far_enemies()

	gem_merge_timer -= delta
	if gem_merge_timer <= 0.0:
		gem_merge_timer = 0.25
		_merge_gems()

	hud.update_hud(elapsed, player.hp, player.max_hp, enemies_root.get_child_count(), kills, level, xp, xp_to_next)


# --- Spawn timeline ---------------------------------------------------------
func _current_wave() -> Dictionary:
	var t := elapsed
	if t < 20.0:
		return {"interval": 1.0,  "batch": 1, "weights": {"swarmer": 1.0}}
	elif t < 60.0:
		return {"interval": 0.7,  "batch": 1, "weights": {"swarmer": 0.75, "grunt": 0.25}}
	elif t < 120.0:
		return {"interval": 0.5,  "batch": 2, "weights": {"swarmer": 0.7,  "grunt": 0.3}}
	elif t < BOSS_TIME:
		return {"interval": 0.45, "batch": 2, "weights": {"swarmer": 0.6,  "grunt": 0.3, "tank": 0.1}}
	else:
		return {"interval": 0.5,  "batch": 2, "weights": {"swarmer": 0.55, "grunt": 0.3, "tank": 0.15}}


func _update_spawns(delta: float) -> void:
	var wave := _current_wave()
	spawn_accum += delta
	while spawn_accum >= wave.interval:
		spawn_accum -= wave.interval
		for i in wave.batch:
			if enemies_root.get_child_count() >= MAX_ENEMIES:
				break
			_spawn_enemy(_pick_type(wave.weights))

	if not boss_spawned and elapsed >= BOSS_TIME:
		boss_spawned = true
		_spawn_enemy("boss")


func _pick_type(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += weights[k]
	var roll := randf() * total
	for k in weights:
		roll -= weights[k]
		if roll <= 0.0:
			return k
	return weights.keys()[0]


func _spawn_enemy(type: String) -> void:
	var e := Enemy.new()
	e.setup(ENEMY_TYPES[type], player)
	e.is_boss = (type == "boss")
	e.xp_tier = DROP_TIER[type]
	e.global_position = player.global_position + _ring_point()
	e.died.connect(_on_enemy_died.bind(e))
	enemies_root.add_child(e)


func _ring_point() -> Vector2:
	var ang := randf() * TAU
	return Vector2(cos(ang), sin(ang)) * SPAWN_RADIUS


func _recycle_far_enemies() -> void:
	for e in enemies_root.get_children():
		if e is Enemy and not e.is_boss:
			if e.global_position.distance_to(player.global_position) > DESPAWN_RADIUS:
				e.global_position = player.global_position + _ring_point()


func _on_enemy_died(e) -> void:
	kills += 1
	if e.is_boss:
		for i in 5:
			var off := Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
			_spawn_gem(e.global_position + off, "large")
	else:
		_spawn_gem(e.global_position, e.xp_tier)


# --- Gems -------------------------------------------------------------------
func _spawn_gem(pos: Vector2, tier: String) -> void:
	var g := Gem.new()
	g.value = GEM_VALUES[tier]
	g.player = player
	g.game = self
	g.global_position = pos
	gems_root.add_child(g)


func _merge_gems() -> void:
	var gems := get_tree().get_nodes_in_group("gems")
	var over_cap := gems.size() > MAX_GEMS
	var merges := 0
	for i in gems.size():
		var a = gems[i]
		if not is_instance_valid(a) or a.collected:
			continue
		if not over_cap and a.idle_time < GEM_MERGE_DELAY:
			continue
		for j in range(i + 1, gems.size()):
			var b = gems[j]
			if not is_instance_valid(b) or b.collected:
				continue
			if not over_cap and b.idle_time < GEM_MERGE_DELAY:
				continue
			if a.global_position.distance_to(b.global_position) <= GEM_MERGE_RADIUS:
				a.absorb(b)
				merges += 1
				break
		if merges > 60:
			break


# --- Progression ------------------------------------------------------------
func xp_for_level(l: int) -> float:
	# Fast early, then accelerating cost per level.
	return 5.0 + 4.0 * (l - 1) + pow(max(l - 1, 0), 2.1)


func add_xp(amount: float) -> void:
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		pending_levelups += 1
		xp_to_next = xp_for_level(level)
	if pending_levelups > 0 and not card_screen.active:
		_open_level_up()


func _open_level_up() -> void:
	if pending_levelups <= 0:
		return
	pending_levelups -= 1
	var cards := _draw_cards(3)
	get_tree().paused = true
	card_screen.show_cards(cards)


func _draw_cards(n: int) -> Array:
	var elig: Array = []
	for def in Upgrades.pool():
		var id: String = def.id
		if banished.has(id) or locked.has(id):
			continue
		if int(upgrade_levels.get(id, 0)) >= int(def.max):
			continue
		elig.append(def)

	var chosen: Array = []
	while chosen.size() < n and elig.size() > 0:
		var total := 0.0
		for d in elig:
			total += Upgrades.weight(d.rarity)
		var roll := randf() * total
		var idx := 0
		for i in elig.size():
			roll -= Upgrades.weight(elig[i].rarity)
			if roll <= 0.0:
				idx = i
				break
		chosen.append(elig[idx])
		elig.remove_at(idx)

	if chosen.is_empty():
		# Everything maxed/locked/banished — offer a heal so the screen is never empty.
		chosen.append({"id": "heal", "name": "Field Medicine", "desc": "Heal 30 HP"})
	return chosen


func _def(id: String):
	for def in Upgrades.pool():
		if def.id == id:
			return def
	return null


func _on_card_picked(id: String) -> void:
	if id == "heal":
		player.apply_upgrade("heal")
	else:
		upgrade_levels[id] = int(upgrade_levels.get(id, 0)) + 1
		player.apply_upgrade(id)
		var def = _def(id)
		if def != null:
			for lk in def.locks:
				locked[lk] = true
	_after_choice()


func _on_card_banished(id: String) -> void:
	if banish_charges <= 0:
		return
	banish_charges -= 1
	banished[id] = true
	card_screen.show_cards(_draw_cards(3))


func _on_card_rerolled() -> void:
	if reroll_charges <= 0:
		return
	reroll_charges -= 1
	card_screen.show_cards(_draw_cards(3))


func _after_choice() -> void:
	if pending_levelups > 0:
		_open_level_up()
	else:
		card_screen.hide_cards()
		get_tree().paused = false


func _on_player_died() -> void:
	game_over = true
	hud.show_death(elapsed, kills, level)

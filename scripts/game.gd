extends Node2D
## The run director. Class-select gate at start, then owns the world, the enemy
## spawn timeline, XP gems + merging, level/XP progression, and the card flow.
## All tuning numbers come from the Config autoload.

var player: Player
var enemies_root: Node2D
var projectiles_root: Node2D
var gems_root: Node2D
var pickups_root: Node2D
var fx_root: Node2D
var hud: HUD
var card_screen: CardScreen
var class_select: ClassSelect

var run_started := false
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

# Gold / meta-progression
var run_gold := 0
var growth_mult := 1.0
var greed_mult := 1.0

# Upgrade run-state
var upgrade_levels: Dictionary = {}
var locked: Dictionary = {}
var banished: Dictionary = {}
var reroll_charges := 0
var banish_charges := 0


func _ready() -> void:
	randomize()
	xp_to_next = Config.xp_for_level(level)
	reroll_charges = Config.REROLL_CHARGES
	banish_charges = Config.BANISH_CHARGES

	player = Player.new()

	var bg := BackgroundGrid.new()
	bg.target = player
	add_child(bg)

	var obstacles := ObstacleField.new()
	obstacles.player = player
	add_child(obstacles)

	gems_root = Node2D.new()
	gems_root.name = "Gems"
	add_child(gems_root)

	pickups_root = Node2D.new()
	pickups_root.name = "Pickups"
	add_child(pickups_root)

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

	var cam := GameCamera.new()
	player.add_child(cam)
	cam.make_current()

	fx_root = Node2D.new()
	fx_root.name = "Fx"
	add_child(fx_root)
	Fx.layer = fx_root
	Fx.camera = cam

	var ind_layer := CanvasLayer.new()
	ind_layer.layer = 9
	add_child(ind_layer)
	var indicators := EdgeIndicators.new()
	indicators.player = player
	ind_layer.add_child(indicators)

	hud = HUD.new()
	add_child(hud)

	card_screen = CardScreen.new()
	card_screen.game = self
	card_screen.picked.connect(_on_card_picked)
	card_screen.banished.connect(_on_card_banished)
	card_screen.rerolled.connect(_on_card_rerolled)
	add_child(card_screen)

	# Gate the run behind class selection.
	class_select = ClassSelect.new()
	class_select.chosen.connect(_on_class_chosen)
	add_child(class_select)
	get_tree().paused = true

	# Headless auto-start (smoke tests / future balance harness, issue #65).
	if DisplayServer.get_name() == "headless":
		var tc := "melee"
		if OS.has_environment("TEST_CLASS"):
			tc = OS.get_environment("TEST_CLASS")
		call_deferred("_on_class_chosen", tc)


func _on_class_chosen(id: String) -> void:
	player.set_class(id)
	_apply_meta()
	hud.set_class(Config.CLASS[id].name)
	class_select.queue_free()
	run_started = true
	get_tree().paused = false


## Apply permanent PowerUps (bought with gold) on top of the class base stats.
func _apply_meta() -> void:
	var might := Save.powerup_level("might")
	player.projectile_damage *= (1.0 + 0.05 * might)
	player.melee_damage *= (1.0 + 0.05 * might)
	player.max_hp += 12.0 * Save.powerup_level("health")
	player.hp = player.max_hp
	player.speed *= (1.0 + 0.04 * Save.powerup_level("moveSpeed"))
	player.projectile_count += Save.powerup_level("amount")
	player.pickup_radius *= (1.0 + 0.15 * Save.powerup_level("magnet"))
	player.attack_interval *= pow(0.96, Save.powerup_level("cooldown"))
	player.armor += float(Save.powerup_level("armor"))
	player.recovery += 0.2 * Save.powerup_level("recovery")
	growth_mult = 1.0 + 0.08 * Save.powerup_level("growth")
	greed_mult = 1.0 + 0.10 * Save.powerup_level("greed")


func _process(delta: float) -> void:
	if game_over:
		if Input.is_physical_key_pressed(KEY_R):
			get_tree().change_scene_to_file("res://main_menu.tscn")
		return
	if not run_started:
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

	hud.update_hud(elapsed, player.hp, player.max_hp, enemies_root.get_child_count(), kills, level, xp, xp_to_next, run_gold)


# --- Spawn timeline ---------------------------------------------------------
func _current_wave() -> Dictionary:
	var t := elapsed
	if t < 20.0:
		return {"interval": 1.0,  "batch": 1, "weights": {"swarmer": 1.0}}
	elif t < 60.0:
		return {"interval": 0.7,  "batch": 1, "weights": {"swarmer": 0.75, "grunt": 0.25}}
	elif t < 120.0:
		return {"interval": 0.5,  "batch": 2, "weights": {"swarmer": 0.7,  "grunt": 0.3}}
	elif t < Config.BOSS_TIME:
		return {"interval": 0.45, "batch": 2, "weights": {"swarmer": 0.6,  "grunt": 0.3, "tank": 0.1}}
	else:
		return {"interval": 0.5,  "batch": 2, "weights": {"swarmer": 0.55, "grunt": 0.3, "tank": 0.15}}


func _update_spawns(delta: float) -> void:
	var wave := _current_wave()
	spawn_accum += delta
	while spawn_accum >= wave.interval:
		spawn_accum -= wave.interval
		for i in wave.batch:
			if enemies_root.get_child_count() >= Config.MAX_ENEMIES:
				break
			_spawn_enemy(_pick_type(wave.weights))

	if not boss_spawned and elapsed >= Config.BOSS_TIME:
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
	e.setup(Config.ENEMY_TYPES[type], player)
	e.is_boss = (type == "boss")
	e.xp_tier = Config.DROP_TIER[type]
	e.global_position = player.global_position + _ring_point()
	e.died.connect(_on_enemy_died.bind(e))
	enemies_root.add_child(e)


func _ring_point() -> Vector2:
	var ang := randf() * TAU
	return Vector2(cos(ang), sin(ang)) * Config.SPAWN_RADIUS


func _recycle_far_enemies() -> void:
	for e in enemies_root.get_children():
		if e is Enemy and not e.is_boss:
			if e.global_position.distance_to(player.global_position) > Config.DESPAWN_RADIUS:
				e.global_position = player.global_position + _ring_point()


func _on_enemy_died(e) -> void:
	kills += 1
	if e.is_boss:
		Fx.shake(Config.SHAKE_ON_BOSS_DEATH)
		for i in 5:
			var off := Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
			_spawn_gem(e.global_position + off, "large")
		_spawn_pickup(e.global_position + Vector2(30, 0), "heal")
		_spawn_pickup(e.global_position + Vector2(-30, 0), "bomb")
		for i in 6:
			var goff := Vector2(randf_range(-50.0, 50.0), randf_range(-50.0, 50.0))
			_spawn_gold(e.global_position + goff, int(ceil(Config.GOLD_BOSS / 6.0)))
		_spawn_chest(e.global_position + Vector2(0, 40))
	else:
		_spawn_gem(e.global_position, e.xp_tier)
		if randf() < float(Config.PICKUP_DROP_CHANCE.get(e.xp_tier, 0.0)):
			_spawn_pickup(e.global_position, _pick_pickup_kind())
		var gd = Config.GOLD_DROP.get(e.xp_tier, null)
		if gd != null and randf() < float(gd.chance):
			_spawn_gold(e.global_position, int(gd.amount))
		if e.xp_tier == "large" and randf() < Config.TANK_CHEST_CHANCE:
			_spawn_chest(e.global_position)


# --- Pickups ----------------------------------------------------------------
func _pick_pickup_kind() -> String:
	var total := 0.0
	for k in Config.PICKUP_WEIGHTS:
		total += Config.PICKUP_WEIGHTS[k]
	var roll := randf() * total
	for k in Config.PICKUP_WEIGHTS:
		roll -= Config.PICKUP_WEIGHTS[k]
		if roll <= 0.0:
			return k
	return "heal"


func _spawn_pickup(pos: Vector2, kind: String) -> void:
	var p := Pickup.new()
	p.kind = kind
	p.player = player
	p.game = self
	p.global_position = pos
	pickups_root.add_child(p)


func _spawn_gold(pos: Vector2, amount: int) -> void:
	var g := Gold.new()
	g.value = amount
	g.player = player
	g.game = self
	g.global_position = pos
	pickups_root.add_child(g)


func add_run_gold(n: int) -> void:
	run_gold += int(round(n * greed_mult))


func _spawn_chest(pos: Vector2) -> void:
	var c := Chest.new()
	c.player = player
	c.game = self
	c.global_position = pos
	pickups_root.add_child(c)


func open_chest(pos: Vector2) -> void:
	Fx.death_pop(pos, Color(0.95, 0.75, 0.25))
	Fx.shake(0.3)
	add_run_gold(Config.CHEST_GOLD)
	pending_levelups += randi_range(Config.CHEST_LEVELS_MIN, Config.CHEST_LEVELS_MAX)
	if not card_screen.active:
		_open_level_up()


func vacuum_all_gems() -> void:
	for g in gems_root.get_children():
		if g is Gem:
			g.attracting = true


func bomb() -> void:
	Fx.shake(Config.SHAKE_ON_BOMB)
	for e in enemies_root.get_children():
		if e is Enemy and e.global_position.distance_to(player.global_position) < Config.BOMB_RADIUS:
			e.take_damage(Config.BOMB_DAMAGE)


# --- Gems -------------------------------------------------------------------
func _spawn_gem(pos: Vector2, tier: String) -> void:
	var g := Gem.new()
	g.value = Config.GEM_VALUES[tier]
	g.player = player
	g.game = self
	g.global_position = pos
	gems_root.add_child(g)


func _merge_gems() -> void:
	var gems := get_tree().get_nodes_in_group("gems")
	var over_cap := gems.size() > Config.MAX_GEMS
	var merges := 0
	for i in gems.size():
		var a = gems[i]
		if not is_instance_valid(a) or a.collected:
			continue
		if not over_cap and a.idle_time < Config.GEM_MERGE_DELAY:
			continue
		for j in range(i + 1, gems.size()):
			var b = gems[j]
			if not is_instance_valid(b) or b.collected:
				continue
			if not over_cap and b.idle_time < Config.GEM_MERGE_DELAY:
				continue
			if a.global_position.distance_to(b.global_position) <= Config.GEM_MERGE_RADIUS:
				a.absorb(b)
				merges += 1
				break
		if merges > 60:
			break


# --- Progression ------------------------------------------------------------
func add_xp(amount: float) -> void:
	xp += amount * growth_mult
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		pending_levelups += 1
		xp_to_next = Config.xp_for_level(level)
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
		var tag: String = def.get("class", "any")
		if tag != "any" and tag != player.class_id:
			continue
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
	Save.add_gold(run_gold)  # bank immediately so it's never lost
	hud.show_death(elapsed, kills, level, run_gold)

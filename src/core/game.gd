extends Node2D
## The run director. Tabula-rasa start, biome map drives enemy spawns + essence,
## Insight unlocks family tiers, XP gems drive Vital character levels.

var player: Player
var enemies_root: Node2D
var projectiles_root: Node2D
var gems_root: Node2D
var pickups_root: Node2D
var fx_root: Node2D
var hud: HUD
var card_screen: CardScreen
var biome_map: BiomeMap
var bg: BackgroundGrid
var _cur_biome := ""
var boss_lock_biome := ""       # the biome the player is currently sealed inside
var warden_ref: Node2D = null   # the living Warden, for the compass
var known_gates: Array = []     # doorway positions discovered so far
var _sim_arch := ""             # SIM_ARCH: force-spawn this archetype only
var _sim_arch_biome := "commons"
var cleared_biomes: Dictionary = {}  # biome -> true once its Warden falls
var warden_timer := -1.0        # counts down to the Warden's arrival
var warden_alive := false
var _stay_timer := 0.0          # lingering in a cleared biome brings the Warden BACK
var _last_inside_pos := Vector2.ZERO
var _seal_warn_cd := 0.0

# Skill and deepening cards live with their families (src/families/ lists the
# skill files in src/skills/). Basic attacks are NOT cards — those awaken by
# surviving in biomes. Skills are always PICKED.

var run_started := false
var _shot_done := false
var elapsed := 0.0
var kills := 0
var spawn_accum := 0.0
var cleanup_timer := 0.0
var gem_merge_timer := 0.0
var game_over := false

# Progression (Vital / character level)
var level := 1
var xp := 0.0
var xp_to_next := 0.0
var pending_levelups := 0

var upgrade_levels: Dictionary = {}
var picked_skills: Array = []  # [{name, color}] — shown in the HUD spell list
var locked: Dictionary = {}
var banished: Dictionary = {}
var reroll_charges := 0
var banish_charges := 0

# Gold / meta
var run_gold := 0
var growth_mult := 1.0
var greed_mult := 1.0


func _ready() -> void:
	randomize()
	xp_to_next = Config.xp_for_level(level)
	reroll_charges = Config.REROLL_CHARGES
	banish_charges = Config.BANISH_CHARGES

	var map_seed := randi()
	if Sim.enabled and OS.has_environment("SIM_SEED"):
		map_seed = int(OS.get_environment("SIM_SEED"))
		seed(map_seed)  # deterministic runs: same seed -> same world + same rolls
	biome_map = BiomeMap.new(map_seed)
	RunLog.start(map_seed)

	player = Player.new()

	bg = BackgroundGrid.new()
	bg.target = player
	bg.biome_map = biome_map
	add_child(bg)

	var obstacles := ObstacleField.new()
	obstacles.player = player
	obstacles.world_seed = map_seed
	obstacles.biome_map = biome_map
	add_child(obstacles)

	var borders := BorderField.new()
	borders.player = player
	borders.biome_map = biome_map
	borders.world_seed = map_seed
	borders.game = self
	add_child(borders)

	var loot := LootField.new()
	loot.player = player
	loot.game = self
	loot.world_seed = map_seed
	add_child(loot)

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
	player.awakened.connect(_on_family_awakened)
	add_child(player)

	var cam := GameCamera.new()
	cam.zoom = Vector2(Config.CAMERA_ZOOM, Config.CAMERA_ZOOM)
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

	var boost_timers := BoostTimers.new()
	boost_timers.player = player
	hud.add_child(boost_timers)

	var wheel := AffinityWheel.new()
	wheel.player = player
	hud.add_child(wheel)

	var attack_panel := AttackPanel.new()
	attack_panel.player = player
	attack_panel.game = self
	hud.add_child(attack_panel)

	var compass := Compass.new()
	compass.player = player
	compass.game = self
	hud.add_child(compass)

	card_screen = CardScreen.new()
	card_screen.game = self
	card_screen.picked.connect(_on_card_picked)
	card_screen.banished.connect(_on_card_banished)
	card_screen.rerolled.connect(_on_card_rerolled)
	add_child(card_screen)

	_apply_meta()
	if Sim.enabled and Sim.family != "":
		# grant the family under test fully (awakened + all skills) for build runs
		player.add_insight(Sim.family, float(Config.INSIGHT_TIERS[Config.INSIGHT_TIERS.size() - 1]))
		for s in Families.of(Sim.family).skill_meta():
			player.unlock_skill(Sim.family, s.id)
	if Sim.enabled and OS.has_environment("SIM_BIOME"):
		# drop the bot straight into a chosen biome to test its roster directly
		var want := OS.get_environment("SIM_BIOME")
		var ok := _sim_teleport_to(want)
		boss_lock_biome = want  # lock spawns so the proof isn't contaminated
		warden_timer = -1.0
		RunLog.event("sim teleported to %s (%s)" % [want, "ok" if ok else "NOT FOUND"])
	if Sim.enabled and OS.has_environment("SIM_ARCH"):
		_sim_arch = OS.get_environment("SIM_ARCH")
		for bname in Biomes.ids():
			for r in Biomes.of(bname).roster:
				if r.arch == _sim_arch:
					_sim_arch_biome = bname
		# Stay at the wall-free spawn origin; the point-blank spawner forces the
		# enemy's biome to match here so it engages (no territory fleeing, and no
		# border walls to eat our bolts like the deep-wedge teleport did).
		warden_timer = -1.0
		RunLog.event("sim archetype proof: %s (home %s)" % [_sim_arch, _sim_arch_biome])
	run_started = true


## Move the bot to a point inside the given biome. Returns false if none found.
func _sim_teleport_to(want: String) -> bool:
	for r: float in [3000.0, 5000.0, 8000.0, 12000.0]:
		for i in 48:
			var ang: float = i * TAU / 48.0
			var p: Vector2 = Vector2(cos(ang), sin(ang)) * r
			if biome_map.biome_at(p) == want:
				player.global_position = p
				_last_inside_pos = p
				return true
	return false


func _apply_meta() -> void:
	if Sim.enabled:
		return
	Powerups.apply_meta(player, self)


func _process(delta: float) -> void:
	if game_over:
		if Input.is_physical_key_pressed(KEY_R):
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	if not run_started:
		return

	elapsed += delta
	if Sim.enabled and (elapsed >= Sim.duration or Sim.wall_capped()):
		_sim_report()
		return
	if OS.has_environment("SHOT") and not _shot_done and elapsed > 2.0:
		_shot_done = true
		_capture_shot()
		return
	_update_spawns(delta)

	cleanup_timer -= delta
	if cleanup_timer <= 0.0:
		cleanup_timer = 0.5
		_recycle_far_enemies()

	gem_merge_timer -= delta
	if gem_merge_timer <= 0.0:
		gem_merge_timer = 0.25
		_merge_gems()

	# Boss seal: while the boss lives you cannot leave its biome.
	if boss_lock_biome != "":
		_seal_warn_cd -= delta
		if biome_map.biome_at(player.global_position) != boss_lock_biome:
			player.global_position = _last_inside_pos
			if _seal_warn_cd <= 0.0:
				_seal_warn_cd = 1.0
				Fx.floating_text(player.global_position + Vector2(0, -34), "sealed in!", Color(0.92, 0.16, 0.22))
		else:
			_last_inside_pos = player.global_position

	var biome := biome_map.biome_at(player.global_position)
	player.current_biome = biome  # the brain leans toward the local biome's attack
	if biome != _cur_biome:
		_cur_biome = biome
		_stay_timer = 0.0
		var bdef := Biomes.of(biome)
		RunLog.event("entered %s (lvl %d, hp %.0f)" % [bdef.display_name, level, player.hp])
		if not cleared_biomes.has(biome):
			# an unconquered biome seals behind you until its Warden falls
			boss_lock_biome = biome
			_last_inside_pos = player.global_position
			warden_timer = Config.WARDEN_AFTER
			warden_alive = false
			hud.show_banner("Sealed in %s" % bdef.display_name, bdef.color)
			RunLog.event("sealed in %s — Warden in %.0fs" % [bdef.display_name, Config.WARDEN_AFTER])
		else:
			hud.show_banner("Entering %s (cleared)" % bdef.display_name, bdef.color)

	# The Warden approaches while you're sealed.
	if warden_timer > 0.0 and boss_lock_biome != "":
		warden_timer -= delta
		if warden_timer <= 0.0 and not warden_alive:
			_spawn_warden()
	elif boss_lock_biome == "" and not warden_alive:
		# Linger in conquered land and it stirs again: reseal + instant Warden.
		_stay_timer += delta
		if _stay_timer >= Config.WARDEN_AFTER:
			_stay_timer = 0.0
			boss_lock_biome = biome
			_last_inside_pos = player.global_position
			cleared_biomes.erase(biome)
			hud.show_banner("%s stirs — resealed!" % Biomes.of(biome).display_name, Color(0.92, 0.16, 0.22))
			RunLog.event("RESEALED %s (lingered)" % biome)
			_spawn_warden()

	# Keep the seal status unmissable on screen.
	if boss_lock_biome != "":
		if warden_alive:
			hud.set_seal("SEALED — slay the Warden")
		else:
			hud.set_seal("SEALED — Warden in %ds" % int(ceil(warden_timer)))
	else:
		hud.set_seal("")
	RunLog.t = elapsed
	RunLog.bump("time_in_biome_sec", biome, delta)
	RunLog.tick_snapshot(delta, self)
	hud.update_hud(elapsed, player.hp, player.max_hp, enemies_root.get_child_count(), kills,
		level, xp, xp_to_next, run_gold, Biomes.of(biome).display_name, _family_summary())


func _on_family_awakened(fam: String) -> void:
	hud.show_banner("%s awakened — %s" % [Families.display_name(fam), Cantrips.of(fam).display_name], Families.color(fam))


func _family_summary() -> String:
	var parts: Array = []
	for fam in Families.ids():
		if player.is_awakened(fam):
			var t: int = player.insight_tier(fam)
			parts.append("%s %s" % [Cantrips.of(fam).display_name, ["I", "II", "III"][mini(t, 3) - 1]])
	return " · ".join(parts) if not parts.is_empty() else "Force Bolt only"


# --- Spawn timeline (intensity over time; type comes from the biome) -----------
func _current_wave() -> Dictionary:
	var t := elapsed
	if t < 25.0:
		return {"interval": 1.5, "batch": 1}
	elif t < 70.0:
		return {"interval": 1.0, "batch": 1}
	elif t < 130.0:
		return {"interval": 0.7, "batch": 1}
	elif t < 190.0:
		return {"interval": 0.6, "batch": 2}
	else:
		return {"interval": 0.5, "batch": 2}


func _update_spawns(delta: float) -> void:
	var wave := _current_wave()
	spawn_accum += delta
	while spawn_accum >= wave.interval:
		spawn_accum -= wave.interval
		for i in wave.batch:
			if enemies_root.get_child_count() >= Config.MAX_ENEMIES:
				break
			_spawn_enemy_at_ring()


func _hp_scale() -> float:
	return 1.0 + (elapsed / 60.0) * Config.HP_RAMP_PER_MIN


func _spawn_enemy_at_ring() -> void:
	# SIM_ARCH: spawn ONLY this exact archetype (its home biome), for clean
	# per-enemy mechanic proofs — no biome geography, no guard contamination.
	if Sim.enabled and _sim_arch != "":
		# Point-blank spawn, forced in-biome (home = here), so the enemy always
		# engages the standing bot — no territory fleeing, no despawn, clean proof.
		var here := biome_map.biome_at(player.global_position)
		var ang := float(enemies_root.get_child_count()) * 1.7
		var pos2 := player.global_position + Vector2(cos(ang), sin(ang)) * randf_range(150.0, 240.0)
		var e2 := EnemyTypes.spawn(_sim_arch)
		e2.setup(here, player, _hp_scale())
		e2.global_position = pos2
		e2.home_pos = player.global_position
		e2.biome_map = biome_map
		e2.died.connect(_on_enemy_died.bind(e2))
		enemies_root.add_child(e2)
		return
	var pos := player.global_position + _ring_point()
	# While sealed, only the sealed biome spawns — no foreign mobs piling up at
	# the walls (gates have their standing guards instead).
	if boss_lock_biome != "":
		var tries := 6
		while biome_map.biome_at(pos) != boss_lock_biome and tries > 0:
			pos = player.global_position + _ring_point()
			tries -= 1
		if biome_map.biome_at(pos) != boss_lock_biome:
			return
	var biome := biome_map.biome_at(pos)
	var e := EnemyTypes.spawn(Biomes.of(biome).pick_arch())
	e.setup(biome, player, _hp_scale())
	e.global_position = pos
	e.home_pos = pos
	e.biome_map = biome_map
	e.died.connect(_on_enemy_died.bind(e))
	enemies_root.add_child(e)


func _spawn_warden() -> void:
	warden_alive = true
	var biome := boss_lock_biome
	var pos := player.global_position + _ring_point()
	for i in 12:  # spawn it inside the sealed biome
		if biome_map.biome_at(pos) == biome:
			break
		pos = player.global_position + _ring_point()
	var e := EnemyTypes.spawn("warden")
	e.setup(biome, player, 1.0)
	var target_hp: float = e.scale_for(cleared_biomes.size(), _hp_scale())
	e.global_position = pos
	e.died.connect(_on_enemy_died.bind(e))
	enemies_root.add_child(e)
	warden_ref = e
	hud.show_banner("The Warden of %s awakens" % Biomes.of(biome).display_name, Biomes.of(biome).color)
	RunLog.event("WARDEN spawned (%s, hp %.0f)" % [biome, target_hp])


func spawn_minion(arch: String, biome: String, pos: Vector2) -> void:
	var m := EnemyTypes.spawn(arch)
	m.setup(biome, player, _hp_scale())
	m.global_position = pos
	m.home_pos = pos
	m.biome_map = biome_map
	m.died.connect(_on_enemy_died.bind(m))
	enemies_root.add_child(m)


func _ring_point() -> Vector2:
	var ang := randf() * TAU
	return Vector2(cos(ang), sin(ang)) * Config.SPAWN_RADIUS


func _recycle_far_enemies() -> void:
	for e in enemies_root.get_children():
		if e is Enemy and not e.is_boss:
			if e.global_position.distance_to(player.global_position) > Config.DESPAWN_RADIUS:
				# replace rather than teleport, so the newcomer belongs to the
				# biome it appears in (home/archetype stay coherent)
				e.queue_free()
				_spawn_enemy_at_ring()


func _on_enemy_died(e) -> void:
	kills += 1
	RunLog.bump("kills_by_enemy", e.display_name)
	if e._outside:
		RunLog.bump("kills_special", "out_of_biome")
	e.on_death(self)  # creature-owned death effects (Bonepile/Broodmother bursts)

	var fam: String = Biomes.of(e.biome).family
	if e.is_boss:
		RunLog.event("WARDEN of %s slain (lvl %d, hp %.0f)" % [e.biome, level, player.hp])
		Fx.shake(Config.SHAKE_ON_BOSS_DEATH)
		cleared_biomes[e.biome] = true
		warden_alive = false
		warden_ref = null
		if boss_lock_biome == e.biome:
			boss_lock_biome = ""
		hud.show_banner("%s is conquered — the seal breaks" % Biomes.of(e.biome).display_name, Color(0.95, 0.9, 0.7))
		for i in 5:
			var off := Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
			_spawn_gem(e.global_position + off, "large", fam)
		for i in 6:
			var goff := Vector2(randf_range(-50.0, 50.0), randf_range(-50.0, 50.0))
			_spawn_gold(e.global_position + goff, int(ceil(Config.GOLD_BOSS / 6.0)))
		var c := Chest.new()
		c.player = player
		c.game = self
		c.global_position = e.global_position + Vector2(0, 50)
		pickups_root.add_child(c)
	else:
		if e._outside:
			# strays reward less: reduced gem, no gold
			_spawn_gem(e.global_position, e.xp_tier, fam, Config.OUT_OF_BIOME_REWARD)
		else:
			_spawn_gem(e.global_position, e.xp_tier, fam)
			var gd = Config.GOLD_DROP.get(e.xp_tier, null)
			if gd != null and randf() < float(gd.chance):
				_spawn_gold(e.global_position, int(gd.amount))


# --- Drops ----------------------------------------------------------------------
func _spawn_gem(pos: Vector2, tier: String, family: String, reward_mult: float = 1.0) -> void:
	var g := XpGem.new()
	g.value = maxi(1, int(round(XpGem.VALUES[tier] * reward_mult)))
	g.insight_value = XpGem.INSIGHT[tier] * reward_mult
	g.family = family
	g.player = player
	g.game = self
	# fling out in a random direction near the corpse, not dead-center
	var a := randf() * TAU
	g.global_position = pos + Vector2(cos(a), sin(a)) * randf_range(18.0, 46.0)
	gems_root.add_child(g)


func _spawn_gold(pos: Vector2, amount: int) -> void:
	RunLog.bump("gold", "dropped", amount)
	var g := GoldCoin.new()
	g.value = amount
	g.player = player
	g.game = self
	g.global_position = pos
	pickups_root.add_child(g)


func add_insight(family: String, amount: float) -> void:
	RunLog.bump("insight_from_gems", family, amount)
	player.add_insight(family, amount)


func add_run_gold(n: int) -> void:
	RunLog.bump("gold", "collected", n)
	run_gold += int(round(n * greed_mult))


func _merge_gems() -> void:
	var gems := get_tree().get_nodes_in_group("gems")
	var over_cap := gems.size() > XpGem.MAX_GEMS
	var merges := 0
	for i in gems.size():
		var a = gems[i]
		if not is_instance_valid(a) or a.collected:
			continue
		if not over_cap and a.idle_time < XpGem.MERGE_DELAY:
			continue
		for j in range(i + 1, gems.size()):
			var b = gems[j]
			if not is_instance_valid(b) or b.collected:
				continue
			if not over_cap and b.idle_time < XpGem.MERGE_DELAY:
				continue
			if a.global_position.distance_to(b.global_position) <= XpGem.MERGE_RADIUS:
				a.absorb(b)
				merges += 1
				break
		if merges > 60:
			break


# --- Vital progression -------------------------------------------------------------
func add_xp(amount: float) -> void:
	xp += amount * growth_mult
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		pending_levelups += 1
		xp_to_next = Config.xp_for_level(level)
		RunLog.event("level up -> %d" % level)
	if pending_levelups > 0 and not card_screen.active:
		_open_level_up()


func _open_level_up() -> void:
	if pending_levelups <= 0:
		return
	pending_levelups -= 1
	var cards := _draw_cards(3)
	_log_offer(cards)
	if Sim.enabled:
		# the bot picks like a player: Spell > Boost > first offer
		var pick = cards[0]
		for c in cards:
			if c.get("kind", "") == "Spell":
				pick = c
				break
		_apply_choice(pick.id)
		if pending_levelups > 0:
			_open_level_up()
		return
	get_tree().paused = true
	card_screen.show_cards(cards)


func _log_offer(cards: Array) -> void:
	var names: Array = []
	for c in cards:
		names.append(c.id)
	RunLog.event("cards offered: %s" % " | ".join(names))


func _draw_cards(n: int) -> Array:
	# Skill cards (gated by awakened family + insight depth) are GUARANTEED
	# offers — the affinity choice is the point. Up to n-1 so a Vital option
	# always remains.
	var chosen: Array = []
	# A build is finite: at most SKILL_LIMIT skills per run.
	var skills_owned := 0
	for uid in upgrade_levels:
		if String(uid).begins_with("skill:"):
			skills_owned += 1
	for fam in Families.ids():
		if skills_owned >= Config.SKILL_LIMIT:
			break
		if not player.is_awakened(fam):
			continue
		for s in Families.of(fam).skill_meta():
			var sid := "skill:%s:%s" % [fam, s.id]
			if banished.has(sid) or int(upgrade_levels.get(sid, 0)) > 0:
				continue
			if player.insight_tier(fam) < s.tier:
				continue
			chosen.append({"id": sid, "name": "%s — %s" % [Families.display_name(fam), s.display_name],
				"desc": s.desc, "rarity": "rare", "locks": [],
				"kind": "Spell", "color": Families.color(fam)})
			break  # one skill offer per family at a time
		if chosen.size() >= n - 1:
			break

	var elig: Array = []
	# Deepening cards for every AWAKENED family — the affinity system IS the
	# level-up system; the pool grows with your build.
	for fam in Families.ids():
		if not player.is_awakened(fam):
			continue
		for m in Families.of(fam).minors:
			var mid: String = m.id
			if banished.has(mid) or int(upgrade_levels.get(mid, 0)) >= int(m.max):
				continue
			elig.append({"id": mid, "name": "%s — %s" % [Families.display_name(fam), m.name],
				"desc": m.desc, "rarity": "common", "max": m.max, "locks": [],
				"kind": "Boost", "color": Families.color(fam)})
	for def in Upgrades.pool():
		var id: String = def.id
		if banished.has(id) or locked.has(id):
			continue
		if int(upgrade_levels.get(id, 0)) >= int(def.max):
			continue
		elig.append(def)

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


func _apply_choice(id: String) -> void:
	RunLog.event("card picked: %s" % id)
	RunLog.bump("cards_picked", id)
	if id.begins_with("skill:"):
		var parts := id.split(":")
		upgrade_levels[id] = 1
		for s in Families.of(parts[1]).skill_meta():
			if s.id == parts[2]:
				picked_skills.append({"name": s.display_name, "color": Families.color(parts[1]),
					"fam": parts[1], "key": parts[2], "id": id})
		player.unlock_skill(parts[1], parts[2])
		return
	if id == "heal":
		player.apply_upgrade("heal")
		return
	upgrade_levels[id] = int(upgrade_levels.get(id, 0)) + 1
	player.apply_upgrade(id)
	var def = _def(id)
	if def != null:
		for lk in def.locks:
			locked[lk] = true


## Forget a committed skill (clicked in the spell list): frees the slot, and
## the skill can be offered again later. Rebuild-not-reverse, so overlapping
## boosts stay correct.
func forget_skill(idx: int) -> void:
	if idx < 0 or idx >= picked_skills.size():
		return
	var s: Dictionary = picked_skills[idx]
	picked_skills.remove_at(idx)
	upgrade_levels.erase(s.id)
	player.reset_skill_state()
	for t in picked_skills:
		player.unlock_skill(t.fam, t.key, true)
	# Re-apply the deepening cards that touch skill-granted stats (each family
	# flags its own with "rebuild": true).
	for fam in Families.ids():
		for m in Families.of(fam).minors:
			if m.get("rebuild", false):
				for i in int(upgrade_levels.get(m.id, 0)):
					player.apply_upgrade(m.id)
	RunLog.event("skill FORGOTTEN: %s" % s.name)
	Fx.floating_text(player.global_position + Vector2(0, -30), "Forgot %s" % s.name, Color(1.0, 0.5, 0.4))


func grant_random_upgrade() -> String:
	# Chests auto-grant a VITAL/deepening upgrade only — skills are always the
	# player's own choice at the card screen.
	var cards := _draw_cards(5)
	for c in cards:
		if not String(c.id).begins_with("skill:") and c.get("locks", []).is_empty():
			_apply_choice(c.id)
			return c.name
	return ""


func _on_card_picked(id: String) -> void:
	_apply_choice(id)
	_after_choice()


func _on_card_banished(id: String) -> void:
	if banish_charges <= 0:
		return
	banish_charges -= 1
	banished[id] = true
	RunLog.event("card banished: %s" % id)
	var cards := _draw_cards(3)
	_log_offer(cards)
	card_screen.show_cards(cards)


func _on_card_rerolled() -> void:
	if reroll_charges <= 0:
		return
	reroll_charges -= 1
	RunLog.event("reroll")
	var cards := _draw_cards(3)
	_log_offer(cards)
	card_screen.show_cards(cards)


func _after_choice() -> void:
	if pending_levelups > 0:
		_open_level_up()
	else:
		card_screen.hide_cards()
		get_tree().paused = false


# --- Sim / tooling -------------------------------------------------------------------
func _capture_shot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OS.get_environment("SHOT"))
	get_tree().quit()


func _sim_report() -> void:
	var kps: float = kills / maxf(elapsed, 0.001)
	var dps: float = Sim.damage_dealt / maxf(elapsed, 0.001)
	var death_str := "%.0f" % Sim.death_time if Sim.death_time >= 0.0 else "survived"
	var capped := " WALL_CAPPED" if Sim.wall_capped() else ""
	print("SIM_RESULT time=%.0f lvl=%d spells=%d cleared=%d kills=%d kps=%.2f dps=%.1f dmg_taken=%.0f death_at=%s enemies=%d%s" % [
		elapsed, level, picked_skills.size(), cleared_biomes.size(), kills, kps, dps, Sim.damage_taken, death_str, enemies_root.get_child_count(), capped])
	RunLog.finish("sim end", self)
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		RunLog.finish("window closed", self)


func _on_player_died() -> void:
	game_over = true
	Save.add_gold(run_gold)
	RunLog.event("PLAYER DIED")
	RunLog.finish("death", self)
	hud.show_death(elapsed, kills, level, run_gold)

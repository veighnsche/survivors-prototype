extends Node
## Central tuning config (autoload "Config"). Every gameplay number lives here so
## balancing — especially Ranged/Melee class parity — is a single-file fast loop.
## Issue #48.

# --- Classes ----------------------------------------------------------------
var CLASS := {
	"ranged": {"name": "Ranger",  "blurb": "Ranged auto-shots.\nNimble: fast but fragile.\nSafe at range, single-target.", "max_hp": 80.0,  "speed": 232.0, "attack_interval": 0.50, "color": Color(0.35, 0.76, 0.96)},
	"melee":  {"name": "Bruiser", "blurb": "Cleaving arc swing.\nTanky: sturdy but slower.\nMust close in, hits crowds.",  "max_hp": 140.0, "speed": 186.0, "attack_interval": 0.62, "color": Color(0.95, 0.55, 0.28)},
}

# --- Ranged weapon ----------------------------------------------------------
var PROJECTILE_DAMAGE := 5.0
var PROJECTILE_SPEED := 520.0
var PROJECTILE_RANGE := 950.0
var PROJECTILE_LIFE := 1.4
var MULTISHOT_SPREAD_DEG := 14.0

# --- Melee weapon -----------------------------------------------------------
var MELEE_DAMAGE := 15.0
var MELEE_RANGE := 132.0
var MELEE_ARC_DEG := 100.0
var MELEE_KNOCKBACK := 0.0  # base; raised by the Heavy Blows card

# --- Player misc ------------------------------------------------------------
var PICKUP_RADIUS := 72.0
var CONTACT_TICK := 0.5

# --- Abilities (shared forks) ----------------------------------------------
var BLADE_SPIN := 2.6
var BLADE_ORBIT := 48.0
var AURA_TICK := 0.4

# --- Enemies ----------------------------------------------------------------
var ENEMY_TYPES := {
	"swarmer": {"hp": 3.0,   "speed": 118.0, "damage": 5.0,  "radius": 9.0,  "color": Color(0.86, 0.36, 0.36)},
	"grunt":   {"hp": 9.0,   "speed": 76.0,  "damage": 9.0,  "radius": 13.0, "color": Color(0.82, 0.58, 0.26)},
	"tank":    {"hp": 34.0,  "speed": 47.0,  "damage": 15.0, "radius": 19.0, "color": Color(0.56, 0.32, 0.68)},
	"boss":    {"hp": 520.0, "speed": 44.0,  "damage": 34.0, "radius": 40.0, "color": Color(0.92, 0.16, 0.22)},
}
var DROP_TIER := {"swarmer": "small", "grunt": "medium", "tank": "large", "boss": "large"}

# --- Spawn timeline ---------------------------------------------------------
var SPAWN_RADIUS := 800.0
var DESPAWN_RADIUS := 1500.0
var MAX_ENEMIES := 450
var BOSS_TIME := 150.0

# --- Gems -------------------------------------------------------------------
var GEM_VALUES := {"small": 1, "medium": 5, "large": 25}
var GEM_MERGE_DELAY := 3.5
var GEM_MERGE_RADIUS := 26.0
var MAX_GEMS := 250
var GEM_ATTRACT_SPEED := 580.0
var GEM_COLLECT_DIST := 15.0

# --- Progression ------------------------------------------------------------
var REROLL_CHARGES := 3
var BANISH_CHARGES := 2

# --- Gold & meta-progression -----------------------------------------------
var GOLD_DROP := {
	"small":  {"amount": 1, "chance": 0.35},
	"medium": {"amount": 2, "chance": 0.75},
	"large":  {"amount": 6, "chance": 1.0},
}
var GOLD_BOSS := 45
var GOLD_ATTRACT_SPEED := 600.0
var GOLD_COLLECT_DIST := 16.0

# Permanent PowerUps bought between runs with gold. effect applied at run start.
var POWERUPS := [
	{"id": "might",     "name": "Might",       "desc": "+5% damage",        "max": 5, "base_cost": 100, "cost_growth": 1.6},
	{"id": "health",    "name": "Max Health",  "desc": "+12 max HP",        "max": 5, "base_cost": 80,  "cost_growth": 1.5},
	{"id": "moveSpeed", "name": "Move Speed",  "desc": "+4% move speed",    "max": 5, "base_cost": 90,  "cost_growth": 1.55},
	{"id": "amount",    "name": "Amount",      "desc": "+1 projectile",     "max": 2, "base_cost": 300, "cost_growth": 2.2},
	{"id": "magnet",    "name": "Magnet",      "desc": "+15% pickup radius","max": 4, "base_cost": 70,  "cost_growth": 1.5},
	{"id": "growth",    "name": "Growth",      "desc": "+8% XP gain",       "max": 5, "base_cost": 120, "cost_growth": 1.6},
	{"id": "greed",     "name": "Greed",       "desc": "+10% gold gain",    "max": 5, "base_cost": 110, "cost_growth": 1.6},
	{"id": "cooldown",  "name": "Cooldown",    "desc": "-4% attack time",   "max": 5, "base_cost": 150, "cost_growth": 1.7},
	{"id": "armor",     "name": "Armor",       "desc": "-1 damage taken",   "max": 5, "base_cost": 100, "cost_growth": 1.6},
	{"id": "recovery",  "name": "Recovery",    "desc": "+0.2 HP/sec",       "max": 5, "base_cost": 100, "cost_growth": 1.6},
]

# --- Pickups & juice --------------------------------------------------------
var PICKUP_DROP_CHANCE := {"small": 0.006, "medium": 0.03, "large": 0.14}
var PICKUP_WEIGHTS := {"heal": 0.34, "magnet": 0.16, "bomb": 0.12, "frenzy": 0.13, "power": 0.13, "haste": 0.12}
var HEAL_AMOUNT := 40.0

# Temporary boosts (seconds)
var BOOST_DURATION := 8.0
var SHIELD_DURATION := 5.0

# Chests (elite/boss reward)
var CHEST_LEVELS_MIN := 1
var CHEST_LEVELS_MAX := 3
var CHEST_GOLD := 20
var TANK_CHEST_CHANCE := 0.08

# Obstacles / buildings
var OBSTACLE_CELL := 420.0
var OBSTACLE_VIEW_CELLS := 4
var OBSTACLE_DENSITY := 22  # percent of world cells that hold a building
var ENEMY_AVOID_DIST := 64.0  # how far ahead enemies look to steer around buildings

var BOMB_DAMAGE := 80.0
var BOMB_RADIUS := 720.0
var SHOW_DAMAGE_NUMBERS := true
var SHAKE_ON_HIT := 0.25
var SHAKE_ON_BOMB := 0.7
var SHAKE_ON_BOSS_DEATH := 0.9


func xp_for_level(l: int) -> float:
	# Fast early, then accelerating cost per level.
	return 5.0 + 4.0 * (l - 1) + pow(max(l - 1, 0), 2.1)


func powerup_def(id: String):
	for p in POWERUPS:
		if p.id == id:
			return p
	return null

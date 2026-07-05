extends Node
## Central tuning config (autoload "Config"). Every gameplay number lives here.
## See DESIGN.md — tabula rasa caster shaped by biome-taught affinities.

# --- Display ----------------------------------------------------------------
var CAMERA_ZOOM := 1.6

# --- The cantrip (tabula rasa starting attack) -------------------------------
var CANTRIP := {"damage": 3.0, "interval": 0.5, "range": 700.0, "speed": 520.0, "life": 1.4}

# --- Families (the six corners; v1 implements blast/ward/drain) ---------------
var FAMILY_COLORS := {
	"blast":   Color("#E2493B"),
	"ward":    Color("#E0A02E"),
	"drain":   Color("#6FB03A"),
	"control": Color("#3FCDE0"),
	"sight":   Color("#4C8DF0"),
	"summon":  Color("#9A54E4"),
}
var FAMILY_NAMES := {
	"blast": "Blast", "ward": "Ward", "drain": "Drain",
	"control": "Control", "sight": "Sight", "summon": "Summon",
}
# Insight needed for tier I / II / III. The wheel fills toward the last value.
var INSIGHT_TIERS := [10.0, 30.0, 60.0]

# --- Biomes (organic noise blobs; the Commons surrounds spawn) ----------------
var BIOMES := {
	"commons":    {"name": "The Commons", "color": Color("#E2493B"), "family": "blast", "archetype": "brawler"},
	"thornreach": {"name": "Thornreach",  "color": Color("#E0A02E"), "family": "ward",  "archetype": "skirmisher"},
	"barrows":    {"name": "The Barrows", "color": Color("#6FB03A"), "family": "drain", "archetype": "brute"},
}
var COMMONS_RADIUS := 900.0   # spawn area is always the Commons
var BIOME_CELL := 1600.0      # size of the Voronoi cells that make the blobs
var BIOME_WEIGHTS := {"commons": 0.2, "thornreach": 0.4, "barrows": 0.4}

# Damage-type multipliers per biome (the adaptation teeth):
# each biome resists something and is weak to its counter-family's type.
var BIOME_RESISTS := {
	"commons":    {"arcane": 1.2},                     # brawlers melt to blast
	"thornreach": {"arcane": 0.7, "reflect": 1.6},     # skirmishers shrug bolts, break on wards
	"barrows":    {"arcane": 0.55, "necrotic": 1.6},   # brutes resist burst, rot fast
}

# --- Enemy archetypes ---------------------------------------------------------
var ARCHETYPES := {
	"brawler":    {"hp": 4.0,   "speed": 122.0, "damage": 6.0,  "radius": 9.0,  "xp": "small"},
	"skirmisher": {"hp": 8.0,   "speed": 92.0,  "damage": 7.0,  "radius": 10.0, "xp": "medium",
		"shot_range": 330.0, "shot_interval": 2.4, "shot_speed": 300.0},
	"brute":      {"hp": 42.0,  "speed": 42.0,  "damage": 16.0, "radius": 20.0, "xp": "large"},
	"boss":       {"hp": 700.0, "speed": 46.0,  "damage": 30.0, "radius": 40.0, "xp": "large"},
}
var HP_RAMP_PER_MIN := 0.45   # enemy hp scales up over the run

# --- Essence (biome-colored drops that feed family Insight) -------------------
var ESSENCE_DROP_CHANCE := 0.55
var ESSENCE_VALUE := 2.0
var ESSENCE_ATTRACT_SPEED := 600.0
var ESSENCE_COLLECT_DIST := 16.0

# --- Player misc --------------------------------------------------------------
var PICKUP_RADIUS := 72.0
var CONTACT_TICK := 0.5

# --- Spawn timeline -------------------------------------------------------------
var SPAWN_RADIUS := 800.0
var DESPAWN_RADIUS := 1500.0
var MAX_ENEMIES := 450
var BOSS_TIME := 150.0

# --- Gems / XP (character level = the Vital floor) -----------------------------
var GEM_VALUES := {"small": 1, "medium": 5, "large": 25}
var GEM_MERGE_DELAY := 3.5
var GEM_MERGE_RADIUS := 26.0
var MAX_GEMS := 250
var GEM_ATTRACT_SPEED := 580.0
var GEM_COLLECT_DIST := 15.0

# --- Progression ----------------------------------------------------------------
var REROLL_CHARGES := 3
var BANISH_CHARGES := 2

# --- Gold & meta-progression ------------------------------------------------------
var GOLD_DROP := {
	"small":  {"amount": 1, "chance": 0.35},
	"medium": {"amount": 2, "chance": 0.75},
	"large":  {"amount": 6, "chance": 1.0},
}
var GOLD_BOSS := 45
var GOLD_ATTRACT_SPEED := 600.0
var GOLD_COLLECT_DIST := 16.0

var POWERUPS := [
	{"id": "might",     "name": "Might",       "desc": "+5% spell damage",  "max": 5, "base_cost": 100, "cost_growth": 1.6},
	{"id": "health",    "name": "Max Health",  "desc": "+12 max HP",        "max": 5, "base_cost": 80,  "cost_growth": 1.5},
	{"id": "moveSpeed", "name": "Move Speed",  "desc": "+4% move speed",    "max": 5, "base_cost": 90,  "cost_growth": 1.55},
	{"id": "amount",    "name": "Twin Bolt",   "desc": "+1 cantrip bolt",   "max": 2, "base_cost": 300, "cost_growth": 2.2},
	{"id": "magnet",    "name": "Magnet",      "desc": "+15% pickup radius","max": 4, "base_cost": 70,  "cost_growth": 1.5},
	{"id": "growth",    "name": "Growth",      "desc": "+8% XP gain",       "max": 5, "base_cost": 120, "cost_growth": 1.6},
	{"id": "greed",     "name": "Greed",       "desc": "+10% gold gain",    "max": 5, "base_cost": 110, "cost_growth": 1.6},
	{"id": "cooldown",  "name": "Cooldown",    "desc": "-4% cast time",     "max": 5, "base_cost": 150, "cost_growth": 1.7},
	{"id": "armor",     "name": "Armor",       "desc": "-1 damage taken",   "max": 5, "base_cost": 100, "cost_growth": 1.6},
	{"id": "recovery",  "name": "Recovery",    "desc": "+0.2 HP/sec",       "max": 5, "base_cost": 100, "cost_growth": 1.6},
]

# --- Pickups & juice ---------------------------------------------------------------
var PICKUP_DROP_CHANCE := {"small": 0.006, "medium": 0.03, "large": 0.14}
var PICKUP_WEIGHTS := {"heal": 0.34, "magnet": 0.16, "bomb": 0.12, "frenzy": 0.13, "power": 0.13, "haste": 0.12}
var HEAL_AMOUNT := 40.0

var BOOST_DURATION := 8.0
var SHIELD_DURATION := 5.0

var CHEST_GOLD := 40
var CHEST_HEAL := 25.0

# Obstacles / buildings
var OBSTACLE_CELL := 420.0
var OBSTACLE_VIEW_CELLS := 4
var OBSTACLE_DENSITY := 22
var ENEMY_AVOID_DIST := 64.0

# Off-screen loot indicators
var INDICATOR_FADE_MIN := 280.0
var INDICATOR_FADE_MAX := 850.0
var INDICATOR_MAX := 3

# Floor loot (boosters/chests)
var LOOT_CELL := 560.0
var LOOT_VIEW_CELLS := 4
var LOOT_DENSITY := 12
var LOOT_JITTER := 0.55

var BOMB_DAMAGE := 80.0
var BOMB_RADIUS := 720.0
var SHOW_DAMAGE_NUMBERS := true
var SHAKE_ON_HIT := 0.25
var SHAKE_ON_BOMB := 0.7
var SHAKE_ON_BOSS_DEATH := 0.9


func xp_for_level(l: int) -> float:
	return 5.0 + 4.0 * (l - 1) + pow(max(l - 1, 0), 2.1)


func powerup_def(id: String):
	for p in POWERUPS:
		if p.id == id:
			return p
	return null

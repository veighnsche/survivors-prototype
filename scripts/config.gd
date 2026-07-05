extends Node
## Central tuning config (autoload "Config"). Every gameplay number lives here.
## See DESIGN.md — tabula rasa caster shaped by biome-taught affinities.

# --- Display ----------------------------------------------------------------
var CAMERA_ZOOM := 1.6

# --- The cantrip (tabula rasa starting attack) -------------------------------
var CANTRIP := {"damage": 4.5, "interval": 0.45, "range": 700.0, "speed": 520.0, "life": 1.4}

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
# Insight needed for tier I / II / III. T1 auto-awakens; T2/T3 unlock as cards.
# Deliberately slow — awakening a family should feel earned, not instant.
var INSIGHT_TIERS := [16.0, 52.0, 110.0]

# --- Biomes (organic noise blobs; the Commons surrounds spawn) ----------------
# roster = the enemy archetypes that spawn here (weighted); obstacle = terrain style.
var BIOMES := {
	"commons":    {"name": "The Commons", "color": Color("#E2493B"), "family": "blast", "obstacle": "block",
		"roster": [{"arch": "brawler", "w": 0.7}, {"arch": "darter", "w": 0.3}]},
	"thornreach": {"name": "Thornreach",  "color": Color("#E0A02E"), "family": "ward",  "obstacle": "hedge",
		"roster": [{"arch": "skirmisher", "w": 0.65}, {"arch": "bramble", "w": 0.35}]},
	"barrows":    {"name": "The Barrows", "color": Color("#6FB03A"), "family": "drain", "obstacle": "tomb",
		"roster": [{"arch": "brute", "w": 0.55}, {"arch": "shambler", "w": 0.45}]},
}
var COMMONS_RADIUS := 450.0   # small guaranteed-Commons ring at spawn; blobs vary right beyond it
var BIOME_CELL := 1600.0      # size of the Voronoi cells that make the blobs
var BIOME_WEIGHTS := {"commons": 0.34, "thornreach": 0.33, "barrows": 0.33}

# Territory: enemies weaken and head home when outside their biome (no dragging
# them out to farm weak versions — they disengage instead).
var OUT_OF_BIOME_VULN := 1.6      # damage taken multiplier while outside home biome
var SELF_DEFENSE_RADIUS := 240.0  # but they still fight back if you're this close

# Damage-type multipliers per biome (the adaptation teeth):
# each biome resists something and is weak to its counter-family's type.
var BIOME_RESISTS := {
	"commons":    {"arcane": 1.2},                     # brawlers melt to blast
	"thornreach": {"arcane": 0.8, "reflect": 1.6},     # skirmishers shrug bolts, break on wards
	"barrows":    {"arcane": 0.65, "necrotic": 1.6},   # brutes resist burst, rot fast
}

# --- Enemy archetypes ---------------------------------------------------------
# name shown in the codex; behavior = how it moves/attacks.
var ARCHETYPES := {
	# Commons
	"brawler":    {"name": "Husk",         "hp": 3.5,   "speed": 118.0, "damage": 5.0,  "radius": 9.0,  "xp": "small",  "behavior": "beeline"},
	"darter":     {"name": "Stray",        "hp": 2.0,   "speed": 165.0, "damage": 3.0,  "radius": 7.0,  "xp": "small",  "behavior": "darter"},
	# Thornreach
	"skirmisher": {"name": "Slinger",      "hp": 7.0,   "speed": 90.0,  "damage": 5.0,  "radius": 10.0, "xp": "medium", "behavior": "kite",
		"shot_range": 320.0, "shot_interval": 3.4, "shot_speed": 250.0},
	"bramble":    {"name": "Bramble",      "hp": 15.0,  "speed": 40.0,  "damage": 6.0,  "radius": 15.0, "xp": "medium", "behavior": "advance_shoot",
		"shot_range": 300.0, "shot_interval": 3.8, "shot_speed": 220.0},
	# Barrows
	"brute":      {"name": "Barrow-Knight","hp": 30.0,  "speed": 42.0,  "damage": 13.0, "radius": 20.0, "xp": "large",  "behavior": "beeline"},
	"shambler":   {"name": "Grave-swarm",  "hp": 5.0,   "speed": 36.0,  "damage": 7.0,  "radius": 11.0, "xp": "small",  "behavior": "beeline"},
	# Boss
	"boss":       {"name": "Reaper",       "hp": 700.0, "speed": 46.0,  "damage": 30.0, "radius": 40.0, "xp": "large",  "behavior": "beeline"},
}
var HP_RAMP_PER_MIN := 0.30   # enemy hp scales up over the run

# --- Essence (biome-colored drops that feed family Insight) -------------------
var ESSENCE_DROP_CHANCE := 0.42
var ESSENCE_VALUE := 1.4
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

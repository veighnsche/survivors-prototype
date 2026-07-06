extends Node
## Central tuning config (autoload "Config"). Every gameplay number lives here.
## See DESIGN.md — tabula rasa caster shaped by biome-taught affinities.

# --- Display ----------------------------------------------------------------
var CAMERA_ZOOM := 1.6

# --- Basic attacks: ONE per family, awakened by surviving in its biome. -------
# The caster fires exactly one basic attack per cast cycle — whichever the
# brain computes will deal the most damage right now. "force" is the
# tabula-rasa starter every run begins with.
# kind: bolt (projectile), cleave (cone), chain (instant jumps), repulse
# (radial knockback wave), burst (big radial AoE).
# The cost of a cantrip is its COOLDOWN (tiered attacks pay +20%/tier). The
# selector normalizes scores by cooldown, so heavy AoE must earn its long cd.
var BASIC_ATTACKS := {
	"force":   {"kind": "bolt",    "name": "Force Bolt",   "cooldown": 0.45, "damage": 4.5, "range": 360.0, "speed": 520.0, "dtype": "arcane"},
	"blast":   {"kind": "bolt",    "name": "Fireball",     "cooldown": 0.80, "damage": 7.0, "range": 380.0, "speed": 460.0, "dtype": "arcane", "explode": 64.0},
	"ward":    {"kind": "repulse", "name": "Repulse",      "cooldown": 1.60, "damage": 7.0, "range": 150.0, "dtype": "reflect", "knockback": 120.0},
	"drain":   {"kind": "bolt",    "name": "Leech Bolt",   "cooldown": 0.90, "damage": 6.0, "range": 330.0, "speed": 460.0, "dtype": "necrotic", "leech": 0.22},
	"control": {"kind": "cleave",  "name": "Frost Cleave", "cooldown": 0.75, "damage": 8.0, "range": 135.0, "arc": 150.0, "dtype": "frost", "slow": 0.5},
	"sight":   {"kind": "chain",   "name": "Storm Lance",  "cooldown": 0.90, "damage": 6.0, "range": 480.0, "dtype": "precise", "jumps": 2, "jump_range": 190.0},
	"summon":  {"kind": "burst",   "name": "Soulburst",    "cooldown": 2.60, "damage": 9.0, "range": 230.0, "dtype": "physical"},
}
# GLOBAL cooldown model: casting a cantrip silences ALL cantrips for that
# cantrip's cooldown. The cooldown IS the cost — a heavy cast buys silence.
var BIOME_ATTUNE_BIAS := 1.45 # the brain leans toward the local biome's cantrip
var BOLT_LIFE := 0.75
var SCORE_CD_EXPONENT := 0.85 # score = value / cd^this (≈throughput during the lockout it causes)

# Skills are finite: a build is a CHOICE, not a collection.
var SKILL_LIMIT := 5

# Crowd contact: the strongest toucher hits full, the rest add partially. Makes
# standing still inside a horde lethal (it wasn't — max-only made crowds free).
var CONTACT_CROWD_FACTOR := 0.35
var CONTACT_CROWD_CAP := 70.0

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
var INSIGHT_TIERS := [14.0, 45.0, 100.0]

# --- Biomes (organic noise blobs; the Commons surrounds spawn) ----------------
# roster = the enemy archetypes that spawn here (weighted); obstacle = terrain style.
var BIOMES := {
	"commons":    {"name": "The Commons", "color": Color("#E2493B"), "family": "blast",   "obstacle": "block",
		"roster": [{"arch": "brawler", "w": 0.7}, {"arch": "darter", "w": 0.3}]},
	"thornreach": {"name": "Thornreach",  "color": Color("#E0A02E"), "family": "ward",    "obstacle": "hedge",
		"roster": [{"arch": "skirmisher", "w": 0.65}, {"arch": "bramble", "w": 0.35}]},
	"barrows":    {"name": "The Barrows", "color": Color("#6FB03A"), "family": "drain",   "obstacle": "tomb",
		"roster": [{"arch": "brute", "w": 0.55}, {"arch": "shambler", "w": 0.45}]},
	"wilds":      {"name": "The Wilds",   "color": Color("#3FCDE0"), "family": "control", "obstacle": "tree",
		"roster": [{"arch": "prowler", "w": 0.65}, {"arch": "stalker", "w": 0.35}]},
	"cragspire":  {"name": "Cragspire",   "color": Color("#4C8DF0"), "family": "sight",   "obstacle": "spire",
		"roster": [{"arch": "gale", "w": 0.7}, {"arch": "roc", "w": 0.3}]},
	"hollow":     {"name": "The Hollow",  "color": Color("#9A54E4"), "family": "summon",  "obstacle": "block",
		"roster": [{"arch": "mite", "w": 0.8}, {"arch": "broodmother", "w": 0.2}]},
}
var COMMONS_RADIUS := 1600.0     # the starting Commons field — a real area, not a dot
var SPAWN_FAIR_RADIUS := 14000.0 # sector wedges run from the Commons edge WAY out — each one a territory
var BIOME_CELL := 9000.0         # HUGE Voronoi blobs beyond the wedges
var BIOME_WEIGHTS := {"commons": 0.20, "thornreach": 0.16, "barrows": 0.16, "wilds": 0.16, "cragspire": 0.16, "hollow": 0.16}

# Territory: enemies weaken and head home when outside their biome (no dragging
# them out to farm weak versions — they disengage instead).
var OUT_OF_BIOME_VULN := 1.6      # damage taken multiplier while outside home biome
var OUT_OF_BIOME_DMG := 0.7       # they also hit softer away from home
var OUT_OF_BIOME_REWARD := 0.4    # and reward less (gem XP/insight scaled, no gold)
var OUT_OF_BIOME_DESPAWN := 10.0  # seconds outside before a strayed enemy fades away
var SELF_DEFENSE_RADIUS := 240.0  # but they still fight back if you're this close

# Basic attacks grow with the family's insight tier — stronger, but slower:
var TIER_DMG_BONUS := 0.30   # +30% damage per tier beyond I
var TIER_CD_PENALTY := 0.20  # +20% cooldown per tier beyond I (cheap attacks stay competitive)

# Damage-type multipliers per biome (the adaptation teeth):
# each biome resists something and is weak to its counter-family's type.
var BIOME_RESISTS := {
	"commons":    {"arcane": 1.2},                     # brawlers melt to blast
	"thornreach": {"arcane": 0.8, "reflect": 1.6},     # skirmishers shrug bolts, break on wards
	"barrows":    {"arcane": 0.65, "necrotic": 1.6},   # brutes resist burst, rot fast
	"wilds":      {"arcane": 0.85, "frost": 1.6},      # beasts evade bolts, freeze solid
	"cragspire":  {"arcane": 0.7, "precise": 1.6},     # flyers elude generic fire, crits swat them
	"hollow":     {"arcane": 0.8, "physical": 1.5},    # the tide shrugs magic, minions/zones grind it
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
	# Wilds (beast packs)
	"prowler":    {"name": "Prowler",      "hp": 5.0,   "speed": 150.0, "damage": 5.0,  "radius": 8.0,  "xp": "small",  "behavior": "darter"},
	"stalker":    {"name": "Stalker",      "hp": 14.0,  "speed": 118.0, "damage": 8.0,  "radius": 12.0, "xp": "medium", "behavior": "beeline"},
	# Cragspire (flyers: ignore terrain, swooping speed)
	"gale":       {"name": "Gale",         "hp": 5.0,   "speed": 135.0, "damage": 5.0,  "radius": 8.0,  "xp": "small",  "behavior": "flyer"},
	"roc":        {"name": "Roc",          "hp": 20.0,  "speed": 95.0,  "damage": 10.0, "radius": 16.0, "xp": "medium", "behavior": "flyer"},
	# Hollow (the endless tide)
	"mite":       {"name": "Mite",         "hp": 1.5,   "speed": 85.0,  "damage": 3.0,  "radius": 6.0,  "xp": "small",  "behavior": "beeline"},
	"broodmother":{"name": "Broodmother",  "hp": 26.0,  "speed": 38.0,  "damage": 10.0, "radius": 18.0, "xp": "large",  "behavior": "beeline"},
	# Boss
	"boss":       {"name": "Reaper",       "hp": 700.0, "speed": 46.0,  "damage": 30.0, "radius": 40.0, "xp": "large",  "behavior": "beeline"},
}
var HP_RAMP_PER_MIN := 0.30   # enemy hp scales up over the run

# --- Insight carried by gems (one drop: the biome-colored gem = XP + insight) --
var GEM_INSIGHT := {"small": 0.35, "medium": 1.0, "large": 3.0}

# --- Player misc --------------------------------------------------------------
var PICKUP_RADIUS := 72.0
var CONTACT_TICK := 0.5

# --- Spawn timeline -------------------------------------------------------------
var SPAWN_RADIUS := 800.0
var DESPAWN_RADIUS := 1500.0
var MAX_ENEMIES := 450

# --- Wardens: every biome seals you in until you kill its Warden ------------------
var WARDEN_AFTER := 90.0        # seconds inside a biome before its Warden comes (and comes AGAIN if you linger)
var WARDEN_HP := 260.0          # first Warden's hp; later ones grow
var WARDEN_DMG := 24.0
var WARDEN_CLEAR_BONUS := 0.8   # +80% Warden hp per biome already cleared
var GUARDS_PER_GATE := 2        # entrance guards posted at border gates
var GUARD_AGGRO := 340.0        # guards engage within this range, else hold their post

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
# Gold is ULTRA rare — a treasure, not confetti. Target: ~10-15 per half hour.
var GOLD_DROP := {
	"small":  {"amount": 1, "chance": 0.0015},
	"medium": {"amount": 1, "chance": 0.008},
	"large":  {"amount": 1, "chance": 0.05},
}
var GOLD_BOSS := 3
var GOLD_ATTRACT_SPEED := 600.0
var GOLD_COLLECT_DIST := 16.0

# Priced for the scarce economy: a run's haul (~5-15) buys one cheap upgrade;
# the expensive ones are multi-run savings goals.
var POWERUPS := [
	{"id": "might",     "name": "Might",       "desc": "+5% spell damage",  "max": 5, "base_cost": 8,  "cost_growth": 1.7},
	{"id": "health",    "name": "Max Health",  "desc": "+12 max HP",        "max": 5, "base_cost": 6,  "cost_growth": 1.6},
	{"id": "moveSpeed", "name": "Move Speed",  "desc": "+4% move speed",    "max": 5, "base_cost": 7,  "cost_growth": 1.6},
	{"id": "amount",    "name": "Twin Bolt",   "desc": "+1 cantrip bolt",   "max": 2, "base_cost": 30, "cost_growth": 2.2},
	{"id": "magnet",    "name": "Magnet",      "desc": "+15% pickup radius","max": 4, "base_cost": 5,  "cost_growth": 1.6},
	{"id": "growth",    "name": "Growth",      "desc": "+8% XP gain",       "max": 5, "base_cost": 9,  "cost_growth": 1.7},
	{"id": "greed",     "name": "Greed",       "desc": "+10% gold gain",    "max": 5, "base_cost": 8,  "cost_growth": 1.7},
	{"id": "cooldown",  "name": "Cooldown",    "desc": "-4% cast time",     "max": 5, "base_cost": 12, "cost_growth": 1.8},
	{"id": "armor",     "name": "Armor",       "desc": "-1 damage taken",   "max": 5, "base_cost": 8,  "cost_growth": 1.7},
	{"id": "recovery",  "name": "Recovery",    "desc": "+0.2 HP/sec",       "max": 5, "base_cost": 8,  "cost_growth": 1.7},
]

# --- Pickups & juice ---------------------------------------------------------------
var PICKUP_DROP_CHANCE := {"small": 0.006, "medium": 0.03, "large": 0.14}
var PICKUP_WEIGHTS := {"heal": 0.34, "magnet": 0.16, "bomb": 0.12, "frenzy": 0.13, "power": 0.13, "haste": 0.12}
var HEAL_AMOUNT := 40.0

var BOOST_DURATION := 8.0
var SHIELD_BARRIER := 40.0  # the Shield pickup grants a barrier that absorbs this much (no timer)

var CHEST_GOLD := 2
var CHEST_HEAL := 25.0

# Biome border walls
var WALL_GAP_PCT := 12   # percent of border gate-cells that contain a doorway
var GATE_WIDTH := 130.0  # the doorway itself is TINY — one body wide

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

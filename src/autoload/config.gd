extends Node
## Global tuning config (autoload "Config") — ONLY the numbers that span
## systems. Anything owned by a single entity lives in that entity's file:
## enemies in src/enemies/, cantrips in src/cantrips/, skills in src/skills/,
## biomes in src/biomes/, loot in src/loot/, the gold shop in src/meta/.
## See DESIGN.md — tabula rasa caster shaped by biome-taught affinities.

# --- Display ----------------------------------------------------------------
var CAMERA_ZOOM := 1.6

# --- The caster brain (cross-cantrip policy; cantrips live in src/cantrips/) --
# GLOBAL cooldown model: casting a cantrip silences ALL cantrips for that
# cantrip's cooldown. The cooldown IS the cost — a heavy cast buys silence.
var BIOME_ATTUNE_BIAS := 1.45 # the brain leans toward the local biome's cantrip
var SCORE_CD_EXPONENT := 0.85 # score = value / cd^this (≈throughput during the lockout it causes)

# Basic attacks grow with the family's insight tier — stronger, but slower:
var TIER_DMG_BONUS := 0.30   # +30% damage per tier beyond I
var TIER_CD_PENALTY := 0.20  # +20% cooldown per tier beyond I (cheap attacks stay competitive)

# Insight needed for tier I / II / III. T1 auto-awakens; T2/T3 unlock as cards.
# Deliberately slow — awakening a family should feel earned, not instant.
var INSIGHT_TIERS := [14.0, 45.0, 100.0]

# Skills are finite: a build is a CHOICE, not a collection.
var SKILL_LIMIT := 5

# Crowd contact: the strongest toucher hits full, the rest add partially. Makes
# standing still inside a horde lethal (it wasn't — max-only made crowds free).
var CONTACT_CROWD_FACTOR := 0.35
var CONTACT_CROWD_CAP := 70.0

# --- World layout (per-biome data lives in src/biomes/) ------------------------
var COMMONS_RADIUS := 1600.0     # the starting Commons field — a real area, not a dot
var SPAWN_FAIR_RADIUS := 14000.0 # sector wedges run from the Commons edge WAY out — each one a territory
var BIOME_CELL := 9000.0         # HUGE Voronoi blobs beyond the wedges

# Territory: enemies weaken and head home when outside their biome (no dragging
# them out to farm weak versions — they disengage instead).
var OUT_OF_BIOME_VULN := 1.6      # damage taken multiplier while outside home biome
var OUT_OF_BIOME_DMG := 0.7       # they also hit softer away from home
var OUT_OF_BIOME_REWARD := 0.4    # and reward less (gem XP/insight scaled, no gold)
var OUT_OF_BIOME_DESPAWN := 10.0  # seconds outside before a strayed enemy fades away

# --- Enemies (per-creature stats live in src/enemies/) --------------------------
var HP_RAMP_PER_MIN := 0.30   # enemy hp scales up over the run

# --- Player misc --------------------------------------------------------------
var PICKUP_RADIUS := 72.0
var CONTACT_TICK := 0.5

# --- Spawn timeline -------------------------------------------------------------
var SPAWN_RADIUS := 800.0
var DESPAWN_RADIUS := 1500.0
var MAX_ENEMIES := 450

# The Warden's own numbers live in src/enemies/warden.gd; the seal timing is
# the run director's rule, so it stays here.
var WARDEN_AFTER := 90.0  # seconds inside a biome before its Warden comes (and comes AGAIN if you linger)

# --- Progression ----------------------------------------------------------------
var REROLL_CHARGES := 3
var BANISH_CHARGES := 2

# --- Gold economy (the coin object lives in src/loot/gold_coin.gd) ----------------
# Gold is ULTRA rare — a treasure, not confetti. Target: ~10-15 per half hour.
var GOLD_DROP := {
	"small":  {"amount": 1, "chance": 0.0015},
	"medium": {"amount": 1, "chance": 0.008},
	"large":  {"amount": 1, "chance": 0.05},
}
var GOLD_BOSS := 3

# --- Boosts (each charm is its own class in src/loot/) ----------------------------
var BOOST_DURATION := 8.0

# Obstacles / buildings (looks are per-biome: Biome.draw_obstacle)
var OBSTACLE_CELL := 420.0
var OBSTACLE_VIEW_CELLS := 4
var OBSTACLE_DENSITY := 22

# Off-screen loot indicators
var INDICATOR_FADE_MIN := 280.0
var INDICATOR_FADE_MAX := 850.0
var INDICATOR_MAX := 3

# Floor loot (boosters/chests)
var LOOT_CELL := 560.0
var LOOT_VIEW_CELLS := 4
var LOOT_DENSITY := 12
var LOOT_JITTER := 0.55

# --- Juice -----------------------------------------------------------------------
var SHOW_DAMAGE_NUMBERS := true
var SHAKE_ON_HIT := 0.25
var SHAKE_ON_BOMB := 0.7
var SHAKE_ON_BOSS_DEATH := 0.9


func xp_for_level(l: int) -> float:
	return 5.0 + 4.0 * (l - 1) + pow(max(l - 1, 0), 2.1)

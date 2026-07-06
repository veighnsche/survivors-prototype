class_name Powerups
extends RefCounted
## The gold shop: permanent meta-progression bought between runs. This file
## owns the catalog AND how each level applies to a fresh run.
## Gold is ULTRA rare — a run's haul (~5-15) buys one cheap upgrade; the
## expensive ones are multi-run savings goals.

const POOL := [
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


static func def(id: String):
	for p in POOL:
		if p.id == id:
			return p
	return null


## Apply every bought level to a fresh run (called by the run director).
static func apply_meta(p: Player, game) -> void:
	p.damage_mult *= (1.0 + 0.05 * Save.powerup_level("might"))
	p.max_hp += 12.0 * Save.powerup_level("health")
	p.hp = p.max_hp
	p.speed *= (1.0 + 0.04 * Save.powerup_level("moveSpeed"))
	p.pickup_radius *= (1.0 + 0.15 * Save.powerup_level("magnet"))
	p.attack_speed_mult *= pow(0.96, Save.powerup_level("cooldown"))
	p.armor += float(Save.powerup_level("armor"))
	p.recovery += 0.2 * Save.powerup_level("recovery")
	p.meta_bolt_bonus = Save.powerup_level("amount")
	p.bolt_count = 1 + p.meta_bolt_bonus
	game.growth_mult = 1.0 + 0.08 * Save.powerup_level("growth")
	game.greed_mult = 1.0 + 0.10 * Save.powerup_level("greed")

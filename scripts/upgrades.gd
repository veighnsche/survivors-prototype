class_name Upgrades
extends RefCounted
## Upgrade pool, tagged by weapon. Level-up cards are drawn from the player's
## CURRENT weapon tag plus "any" (shared). Swapping weapons changes the tree you
## see. "locks" are forks that remove their alternative from the run.

static func pool() -> Array:
	return [
		# --- Shared (any weapon) ---
		{"id": "movespeed", "name": "Swiftness",       "desc": "+10% move speed",     "rarity": "common", "max": 5, "locks": [],         "weapon": "any"},
		{"id": "pickup",    "name": "Magnet",          "desc": "+25% pickup radius",  "rarity": "common", "max": 5, "locks": [],         "weapon": "any"},
		{"id": "maxhp",     "name": "Vitality",        "desc": "+20 max HP, heal 20", "rarity": "common", "max": 5, "locks": [],         "weapon": "any"},
		{"id": "quicken",   "name": "Quicken",         "desc": "+12% attack speed",   "rarity": "common", "max": 6, "locks": [],         "weapon": "any"},
		{"id": "blades",    "name": "Orbiting Blades", "desc": "Blades circle you.\nLocks Aura.",  "rarity": "rare", "max": 3, "locks": ["aura"],   "weapon": "any"},
		{"id": "aura",      "name": "Damage Aura",     "desc": "Damaging field.\nLocks Blades.",   "rarity": "rare", "max": 3, "locks": ["blades"], "weapon": "any"},
		# --- Fists ---
		{"id": "fists_dmg",       "name": "Brawler",  "desc": "+30% fist damage",  "rarity": "common", "max": 5, "locks": [],              "weapon": "fists"},
		{"id": "fists_speed",     "name": "Rapid Jab","desc": "+15% fist speed",   "rarity": "common", "max": 5, "locks": [],              "weapon": "fists"},
		{"id": "fists_lifesteal", "name": "Vampiric", "desc": "Heal a little on hit","rarity": "rare","max": 3, "locks": [],              "weapon": "fists"},
		{"id": "fists_flurry",    "name": "Flurry",   "desc": "+1 target hit.\nLocks Haymaker.",  "rarity": "rare", "max": 2, "locks": ["fists_focus"],  "weapon": "fists"},
		{"id": "fists_focus",     "name": "Haymaker", "desc": "+60% damage.\nLocks Flurry.",      "rarity": "rare", "max": 1, "locks": ["fists_flurry"], "weapon": "fists"},
		# --- Ranged ---
		{"id": "r_dmg",       "name": "Hollow Point", "desc": "+25% shot damage",  "rarity": "common", "max": 5, "locks": [], "weapon": "ranged"},
		{"id": "r_multishot", "name": "Split Shot",   "desc": "+1 projectile",     "rarity": "rare",   "max": 4, "locks": [], "weapon": "ranged"},
		{"id": "r_pierce",    "name": "Piercing",     "desc": "Shots pierce +1",   "rarity": "rare",   "max": 4, "locks": [], "weapon": "ranged"},
		{"id": "r_speed",     "name": "Velocity",     "desc": "+20% shot speed",   "rarity": "common", "max": 4, "locks": [], "weapon": "ranged"},
		# --- Melee (arc cleave) ---
		{"id": "m_dmg",       "name": "Whetstone",  "desc": "+25% cleave damage", "rarity": "common", "max": 5, "locks": [], "weapon": "melee"},
		{"id": "m_arc",       "name": "Wide Swing", "desc": "+18° arc",      "rarity": "common", "max": 4, "locks": [], "weapon": "melee"},
		{"id": "m_cleave",    "name": "Long Reach", "desc": "+18% range",         "rarity": "common", "max": 4, "locks": [], "weapon": "melee"},
		{"id": "m_knockback", "name": "Heavy Blows","desc": "Knock enemies back", "rarity": "rare",   "max": 4, "locks": [], "weapon": "melee"},
		# --- Chain Lightning ---
		{"id": "c_dmg",       "name": "Overcharge", "desc": "+25% zap damage",    "rarity": "common", "max": 5, "locks": [],           "weapon": "chain"},
		{"id": "c_jumps",     "name": "Fork",       "desc": "+1 chain jump.\nLocks Conduit.",  "rarity": "rare", "max": 4, "locks": ["c_reach"], "weapon": "chain"},
		{"id": "c_reach",     "name": "Conduit",    "desc": "+25% zap reach.\nLocks Fork.",    "rarity": "rare", "max": 4, "locks": ["c_jumps"], "weapon": "chain"},
		{"id": "c_jumprange", "name": "Arc Length", "desc": "+20% jump range",    "rarity": "common", "max": 4, "locks": [],           "weapon": "chain"},
	]

static func weight(rarity: String) -> float:
	return 3.0 if rarity == "rare" else 10.0

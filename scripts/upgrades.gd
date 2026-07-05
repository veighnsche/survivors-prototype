class_name Upgrades
extends RefCounted
## Upgrade pool. Each entry: id, name, desc, rarity (weight), max level, locks
## (fork exclusions), and class ("any" = shared, else "ranged"/"melee").

static func pool() -> Array:
	return [
		# --- Shared (any class) ---
		{"id": "dmg",       "name": "Sharpened Edge", "desc": "+25% weapon damage",  "rarity": "common", "max": 6, "locks": [], "class": "any"},
		{"id": "firerate",  "name": "Quicken",        "desc": "+15% attack speed",   "rarity": "common", "max": 6, "locks": [], "class": "any"},
		{"id": "movespeed", "name": "Swiftness",      "desc": "+10% move speed",     "rarity": "common", "max": 5, "locks": [], "class": "any"},
		{"id": "pickup",    "name": "Magnet",         "desc": "+25% pickup radius",  "rarity": "common", "max": 5, "locks": [], "class": "any"},
		{"id": "maxhp",     "name": "Vitality",       "desc": "+20 max HP, heal 20", "rarity": "common", "max": 5, "locks": [], "class": "any"},
		{"id": "blades",    "name": "Orbiting Blades","desc": "Blades circle you.\nLocks Damage Aura.",   "rarity": "rare", "max": 3, "locks": ["aura"],  "class": "any"},
		{"id": "aura",      "name": "Damage Aura",    "desc": "Damaging field.\nLocks Orbiting Blades.",  "rarity": "rare", "max": 3, "locks": ["blades"], "class": "any"},
		# --- Ranged only ---
		{"id": "multishot", "name": "Split Shot",     "desc": "+1 projectile",       "rarity": "rare",   "max": 4, "locks": [], "class": "ranged"},
		{"id": "projspeed", "name": "Velocity",       "desc": "+20% shot speed",     "rarity": "common", "max": 4, "locks": [], "class": "ranged"},
		{"id": "pierce",    "name": "Piercing Rounds","desc": "Shots pierce +1 foe", "rarity": "rare",   "max": 4, "locks": [], "class": "ranged"},
		# --- Melee only ---
		{"id": "arc",       "name": "Wider Arc",      "desc": "+18° swing arc",     "rarity": "common", "max": 4, "locks": [], "class": "melee"},
		{"id": "cleave",    "name": "Long Reach",     "desc": "+18% swing range",    "rarity": "common", "max": 4, "locks": [], "class": "melee"},
		{"id": "knockback", "name": "Heavy Blows",    "desc": "Knock enemies back",  "rarity": "rare",   "max": 4, "locks": [], "class": "melee"},
	]

static func weight(rarity: String) -> float:
	return 3.0 if rarity == "rare" else 10.0

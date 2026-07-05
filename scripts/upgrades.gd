class_name Upgrades
extends RefCounted
## Static definition of the M2 starter upgrade pool.
## Each entry: id, name, desc, rarity (weight), max level, and locks (ids this
## card removes from the pool when taken — the class-defining forks).

static func pool() -> Array:
	return [
		{"id": "dmg",       "name": "Sharpened Shots", "desc": "+25% shot damage",   "rarity": "common", "max": 6, "locks": []},
		{"id": "firerate",  "name": "Rapid Fire",      "desc": "+15% fire rate",     "rarity": "common", "max": 6, "locks": []},
		{"id": "multishot", "name": "Split Shot",      "desc": "+1 projectile",      "rarity": "rare",   "max": 4, "locks": []},
		{"id": "projspeed", "name": "Velocity",        "desc": "+20% shot speed",    "rarity": "common", "max": 4, "locks": []},
		{"id": "movespeed", "name": "Swiftness",       "desc": "+10% move speed",    "rarity": "common", "max": 5, "locks": []},
		{"id": "pickup",    "name": "Magnet",          "desc": "+25% pickup radius", "rarity": "common", "max": 5, "locks": []},
		{"id": "maxhp",     "name": "Vitality",        "desc": "+20 max HP, heal 20","rarity": "common", "max": 5, "locks": []},
		{"id": "blades",    "name": "Orbiting Blades", "desc": "Blades circle you.\nLocks Damage Aura.", "rarity": "rare", "max": 3, "locks": ["aura"]},
		{"id": "aura",      "name": "Damage Aura",     "desc": "Damaging field around you.\nLocks Orbiting Blades.", "rarity": "rare", "max": 3, "locks": ["blades"]},
	]

static func weight(rarity: String) -> float:
	return 3.0 if rarity == "rare" else 10.0

class_name Upgrades
extends RefCounted
## The Vital pool — character-level (body) upgrades. Family spells do NOT live
## here; those come from biome essence and use (Insight tiers). See DESIGN.md.

static func pool() -> Array:
	return [
		{"id": "maxhp",     "name": "Vitality",  "desc": "+20 max HP, heal 20", "rarity": "common", "max": 6, "locks": []},
		{"id": "movespeed", "name": "Swiftness", "desc": "+8% move speed",      "rarity": "common", "max": 5, "locks": []},
		{"id": "castspeed", "name": "Alacrity",  "desc": "+10% cast speed",     "rarity": "common", "max": 5, "locks": []},
		{"id": "pickup",    "name": "Magnet",    "desc": "+25% pickup radius",  "rarity": "common", "max": 5, "locks": []},
		{"id": "regen",     "name": "Mending",   "desc": "+0.3 HP per second",  "rarity": "rare",   "max": 4, "locks": []},
		{"id": "focus",     "name": "Focus",     "desc": "+10% spell damage",   "rarity": "rare",   "max": 5, "locks": []},
		{"id": "armorcard", "name": "Ironhide",  "desc": "-1 damage taken",     "rarity": "common", "max": 4, "locks": []},
		{"id": "sharpen",   "name": "Sharpen",   "desc": "+20% cantrip damage", "rarity": "common", "max": 5, "locks": []},
	]

static func weight(rarity: String) -> float:
	return 3.0 if rarity == "rare" else 10.0

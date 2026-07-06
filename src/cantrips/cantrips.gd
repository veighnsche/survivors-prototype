class_name Cantrips
extends RefCounted
## Registry of every basic attack: the "force" starter plus one per family
## (keyed by the family id that awakens it).

const _SCRIPTS := {
	"force": preload("res://src/cantrips/force_bolt.gd"),
	"blast": preload("res://src/cantrips/fireball.gd"),
	"ward": preload("res://src/cantrips/repulse.gd"),
	"drain": preload("res://src/cantrips/leech_bolt.gd"),
	"control": preload("res://src/cantrips/frost_lance.gd"),
	"sight": preload("res://src/cantrips/true_bolt.gd"),
	"summon": preload("res://src/cantrips/spirit_dart.gd"),
}

static var _cache: Dictionary = {}


static func of(id: String) -> Cantrip:
	if not _cache.has(id):
		_cache[id] = _SCRIPTS[id].new()
	return _cache[id]

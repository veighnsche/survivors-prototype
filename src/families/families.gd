class_name Families
extends RefCounted
## Registry of the six families, keyed by id.

const _SCRIPTS := {
	"blast": preload("res://src/families/blast.gd"),
	"ward": preload("res://src/families/ward.gd"),
	"drain": preload("res://src/families/drain.gd"),
	"control": preload("res://src/families/control.gd"),
	"sight": preload("res://src/families/sight.gd"),
	"summon": preload("res://src/families/summon.gd"),
}

static var _cache: Dictionary = {}


static func of(id: String) -> Family:
	if not _cache.has(id):
		_cache[id] = _SCRIPTS[id].new()
	return _cache[id]


static func ids() -> Array:
	return _SCRIPTS.keys()


static func color(id: String) -> Color:
	return of(id).color


static func display_name(id: String) -> String:
	return of(id).display_name

class_name Biomes
extends RefCounted
## Registry of every biome, keyed by id. Insertion order matters: the spawn
## pinwheel deals its six sectors in this order.

const _SCRIPTS := {
	"commons": preload("res://src/biomes/commons.gd"),
	"thornreach": preload("res://src/biomes/thornreach.gd"),
	"barrows": preload("res://src/biomes/barrows.gd"),
	"wilds": preload("res://src/biomes/wilds.gd"),
	"cragspire": preload("res://src/biomes/cragspire.gd"),
	"hollow": preload("res://src/biomes/hollow.gd"),
}

static var _cache: Dictionary = {}


static func of(id: String) -> Biome:
	if not _cache.has(id):
		_cache[id] = _SCRIPTS[id].new()
	return _cache[id]


static func ids() -> Array:
	return _SCRIPTS.keys()

class_name EnemyTypes
extends RefCounted
## Registry of every creature, keyed by arch id. Spawners go through here;
## each creature's stats and behavior live in its own file.

const SCRIPTS := {
	"husk": preload("res://src/enemies/commons/husk.gd"),
	"stray": preload("res://src/enemies/commons/stray.gd"),
	"pouncer": preload("res://src/enemies/commons/pouncer.gd"),
	"slinger": preload("res://src/enemies/thornreach/slinger.gd"),
	"bramble": preload("res://src/enemies/thornreach/bramble.gd"),
	"volleyer": preload("res://src/enemies/thornreach/volleyer.gd"),
	"barrow_knight": preload("res://src/enemies/barrows/barrow_knight.gd"),
	"grave_swarm": preload("res://src/enemies/barrows/grave_swarm.gd"),
	"bonepile": preload("res://src/enemies/barrows/bonepile.gd"),
	"prowler": preload("res://src/enemies/wilds/prowler.gd"),
	"stalker": preload("res://src/enemies/wilds/stalker.gd"),
	"howler": preload("res://src/enemies/wilds/howler.gd"),
	"gale": preload("res://src/enemies/cragspire/gale.gd"),
	"roc": preload("res://src/enemies/cragspire/roc.gd"),
	"diver": preload("res://src/enemies/cragspire/diver.gd"),
	"mite": preload("res://src/enemies/hollow/mite.gd"),
	"broodmother": preload("res://src/enemies/hollow/broodmother.gd"),
	"tunneler": preload("res://src/enemies/hollow/tunneler.gd"),
	"warden": preload("res://src/enemies/warden.gd"),
}


static func spawn(arch: String) -> Enemy:
	return SCRIPTS[arch].new()


static func known(arch: String) -> bool:
	return SCRIPTS.has(arch)

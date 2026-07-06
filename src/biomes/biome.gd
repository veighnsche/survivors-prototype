class_name Biome
extends RefCounted
## One region of the world: its look, the family (school) it teaches, the
## creatures that defend it, and which damage types it shrugs off or fears.
## Every biome is its own file in src/biomes/, registered in Biomes.

var id := ""
var display_name := ""
var color := Color.WHITE
var family := ""              # the family this biome's essence feeds
var roster: Array = []        # [{arch, w}] creature spawn weights (heaviest last)
var resists: Dictionary = {}  # damage type -> incoming damage multiplier
var weight := 0.16            # share of the deep-world Voronoi blobs


## Roll a creature from this biome's weighted roster.
func pick_arch() -> String:
	var total := 0.0
	for r in roster:
		total += r.w
	var roll := randf() * total
	for r in roster:
		roll -= r.w
		if roll <= 0.0:
			return r.arch
	return roster[0].arch


## Paint one piece of this biome's terrain (called from ObstacleBody._draw, so
## every draw_* call lands on the body). Default: a ruined block. Biomes with
## their own silhouette (tomb, hedge, tree, spire) override this.
func draw_obstacle(ob: ObstacleBody) -> void:
	var r := Rect2(-ob.size * 0.5, ob.size)
	var edge := ob.color.lightened(0.25)
	ob.draw_rect(r, ob.color)
	ob.draw_rect(r, edge, false, 2.0)
	ob.draw_line(Vector2(-ob.size.x * 0.5, ob.size.y * 0.1), Vector2(ob.size.x * 0.5, ob.size.y * 0.1), Color(0, 0, 0, 0.25), 1.5)

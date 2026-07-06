class_name Skill
extends RefCounted
## One card-picked skill. Never granted automatically: the player commits a
## finite skill slot to it at the level-up screen. Each skill is its own file
## in src/skills/<family>/, listed by its Family, and provides:
##   card metadata (id, display_name, desc, tier gate)
##   apply(p)  — stat changes when picked (re-applied on rebuild after forget)
##   tick(p)   — per-frame behavior while owned (auto-pulses, curses, wisps)

var id := ""
var display_name := ""
var desc := ""
var fam := ""
var tier := 1   # insight tier the family needs before this card is offered


func apply(_p: Player) -> void:
	pass


func tick(_p: Player, _delta: float) -> void:
	pass

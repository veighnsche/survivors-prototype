extends Node
## Balancing simulator (autoload "Sim"). Enable with env vars for a headless,
## bot-driven balance pass that prints metrics and quits:
##   SIM=1 SIM_TIME=30 godot --headless res://main.tscn
## Optional SIM_FAM=blast grants a family at full Insight, to test builds:
##   SIM=1 SIM_FAM=drain SIM_TIME=30 ...
## In sim mode the player is invincible, meta/leveling are disabled, a bot kites
## the horde. This grows into the build-viability tester from DESIGN.md.

var enabled := false
var family := ""
var duration := 30.0

var damage_dealt := 0.0
var damage_taken := 0.0


func _ready() -> void:
	enabled = OS.has_environment("SIM")
	if OS.has_environment("SIM_FAM"):
		family = OS.get_environment("SIM_FAM")
	if OS.has_environment("SIM_TIME"):
		duration = float(OS.get_environment("SIM_TIME"))
	if enabled:
		Engine.time_scale = 6.0


func reset() -> void:
	damage_dealt = 0.0
	damage_taken = 0.0

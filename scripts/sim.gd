extends Node
## Balancing simulator (autoload "Sim"). Enable with env vars to run a headless,
## bot-driven balance pass for one weapon and print metrics, then quit:
##   SIM=1 SIM_WEAPON=chain SIM_TIME=30 godot --headless res://main.tscn
## In sim mode: player is invincible, meta powerups + leveling are disabled (so
## it measures the BASE weapon), and a bot kites the horde.

var enabled := false
var weapon := "fists"
var duration := 30.0

var damage_dealt := 0.0
var damage_taken := 0.0


func _ready() -> void:
	enabled = OS.has_environment("SIM")
	if OS.has_environment("SIM_WEAPON"):
		weapon = OS.get_environment("SIM_WEAPON")
	if OS.has_environment("SIM_TIME"):
		duration = float(OS.get_environment("SIM_TIME"))


func reset() -> void:
	damage_dealt = 0.0
	damage_taken = 0.0

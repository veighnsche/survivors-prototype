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
var death_time := -1.0  # when cumulative damage would have killed a 100hp caster


func note_damage(amount: float) -> void:
	damage_taken += amount
	if death_time < 0.0 and damage_taken >= 100.0:
		death_time = RunLog.t


func _ready() -> void:
	enabled = OS.has_environment("SIM")
	if OS.has_environment("SIM_FAM"):
		family = OS.get_environment("SIM_FAM")
	if OS.has_environment("SIM_TIME"):
		duration = float(OS.get_environment("SIM_TIME"))
	if enabled:
		# Run as fast as the CPU can hold LOCKSTEP: physics is fixed-step in
		# game time, and _process() below auto-throttles time_scale whenever
		# the process clock starts outrunning executed physics ticks (heavy
		# hordes), so results stay parallel to realtime at any load.
		target_speed = 10.0
		if OS.has_environment("SIM_SPEED"):
			target_speed = float(OS.get_environment("SIM_SPEED"))
		Engine.time_scale = target_speed
		Engine.max_physics_steps_per_frame = maxi(8, int(target_speed) + 8)


var target_speed := 10.0
var _win_t := 0.0
var _win_phys0 := -1


func _process(delta: float) -> void:
	if not enabled:
		return
	if _win_phys0 < 0:
		_win_phys0 = Engine.get_physics_frames()
		return
	_win_t += delta
	if _win_t < 0.5:
		return
	# Windowed rate check: how much physics actually ran vs process time. Keeps
	# lockstep at any load, and RECOVERS speed when the horde thins out.
	var phys_win := float(Engine.get_physics_frames() - _win_phys0) / float(Engine.physics_ticks_per_second)
	var ratio := phys_win / _win_t
	if ratio < 0.92:
		Engine.time_scale = maxf(1.0, Engine.time_scale * 0.8)
	elif ratio > 0.985 and Engine.time_scale < target_speed:
		Engine.time_scale = minf(target_speed, Engine.time_scale * 1.25)
	_win_t = 0.0
	_win_phys0 = Engine.get_physics_frames()


func reset() -> void:
	damage_dealt = 0.0
	damage_taken = 0.0

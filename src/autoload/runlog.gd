extends Node
## Per-run logging (autoload "RunLog") for balancing and bug-hunting. Collects a
## timestamped event stream + aggregate counters, then writes everything to
## user://logs/run_<unixtime>.log on death/quit/sim-end and prints the summary
## (and file path) to stdout.

var t := 0.0            # current game time, driven by the run director
var run_seed := 0
var _lines: PackedStringArray = []
var _stats: Dictionary = {}   # category -> {key -> float}
var _finished := false
var _snapshot_timer := 0.0


func start(seed_value: int) -> void:
	t = 0.0
	run_seed = seed_value
	_lines = PackedStringArray()
	_stats = {}
	_finished = false
	_snapshot_timer = 0.0
	event("run start — seed %d, %s" % [seed_value, Time.get_datetime_string_from_system()])


func event(msg: String) -> void:
	_lines.append("[%s] %s" % [_fmt(t), msg])
	if OS.has_environment("DBG"):
		print("EV(", _lines.size(), ") ", msg)


func bump(category: String, key: String, amount: float = 1.0) -> void:
	if not _stats.has(category):
		_stats[category] = {}
	_stats[category][key] = float(_stats[category].get(key, 0.0)) + amount


## Periodic state snapshot (call every frame; throttles itself).
func tick_snapshot(delta: float, game) -> void:
	_snapshot_timer -= delta
	if _snapshot_timer > 0.0:
		return
	_snapshot_timer = 30.0
	var p = game.player
	var ins := ""
	for fam in p.insight:
		if float(p.insight[fam]) > 0.0:
			ins += "%s=%.1f(T%d) " % [fam, p.insight[fam], p.family_tier(fam)]
	event("snapshot: lvl=%d hp=%.0f/%.0f kills=%d gold=%d enemies=%d insight[ %s]" % [
		game.level, p.hp, p.max_hp, game.kills, game.run_gold,
		game.enemies_root.get_child_count(), ins if ins != "" else "none "])


func finish(reason: String, game) -> void:
	if _finished:
		return
	_finished = true
	var out := PackedStringArray()
	out.append("=== RUN SUMMARY — %s at %s ===" % [reason, _fmt(t)])
	out.append("seed %d · level %d · kills %d · gold %d" % [run_seed, game.level, game.kills, game.run_gold])
	for cat in _stats:
		var parts: Array = []
		var keys: Array = _stats[cat].keys()
		keys.sort_custom(func(a, b): return float(_stats[cat][b]) < float(_stats[cat][a]))
		for k in keys:
			var v: float = _stats[cat][k]
			parts.append("%s %.1f" % [k, v] if absf(v - roundf(v)) > 0.01 else "%s %d" % [k, int(v)])
		out.append("%s: %s" % [cat, ", ".join(parts)])
	out.append("--- events ---")
	out.append_array(_lines)

	var text := "\n".join(out)
	DirAccess.make_dir_recursive_absolute("user://logs")
	var path := "user://logs/run_%d.log" % int(Time.get_unix_time_from_system())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
	print(text)
	print("RUN LOG -> ", ProjectSettings.globalize_path(path))


func _fmt(secs: float) -> String:
	var s := int(secs)
	return "%02d:%02d" % [s / 60, s % 60]

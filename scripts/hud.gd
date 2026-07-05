class_name HUD
extends CanvasLayer
## On-screen readouts: XP bar + level, survival time, HP, enemy count, kills,
## and the death overlay.

var time_label: Label
var level_label: Label
var hp_label: Label
var info_label: Label
var xp_bar: ProgressBar
var death_overlay: ColorRect
var death_label: Label


func _ready() -> void:
	layer = 10

	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.min_value = 0.0
	xp_bar.max_value = 1.0
	xp_bar.value = 0.0
	xp_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	xp_bar.offset_top = 0.0
	xp_bar.offset_bottom = 12.0
	add_child(xp_bar)

	time_label = _make_label(Vector2(590, 22), 30)
	time_label.text = "00:00"
	level_label = _make_label(Vector2(600, 60), 20)
	hp_label = _make_label(Vector2(20, 22), 22)
	info_label = _make_label(Vector2(1040, 22), 22)

	death_overlay = ColorRect.new()
	death_overlay.color = Color(0, 0, 0, 0.6)
	death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_overlay.visible = false
	add_child(death_overlay)

	death_label = Label.new()
	death_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_label.add_theme_font_size_override("font_size", 40)
	death_overlay.add_child(death_label)


func _make_label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	add_child(l)
	return l


func update_hud(elapsed: float, hp: float, max_hp: float, enemy_count: int, kills: int, level: int, xp: float, xp_to_next: float) -> void:
	time_label.text = _fmt_time(elapsed)
	level_label.text = "Level %d" % level
	hp_label.text = "HP  %d / %d" % [int(ceil(hp)), int(max_hp)]
	info_label.text = "Enemies  %d\nKills  %d" % [enemy_count, kills]
	xp_bar.max_value = max(1.0, xp_to_next)
	xp_bar.value = xp


func show_death(elapsed: float, kills: int, level: int) -> void:
	death_label.text = "YOU DIED\n\nSurvived %s     Level %d     Kills %d\n\nPress R to restart" % [_fmt_time(elapsed), level, kills]
	death_overlay.visible = true


func _fmt_time(t: float) -> String:
	var s := int(t)
	return "%02d:%02d" % [s / 60, s % 60]

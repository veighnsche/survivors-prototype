class_name Warden
extends Enemy
## The biome boss: telegraphed moves, not a walking stat blob. Every biome
## seals you in until its Warden falls. All of its numbers live here — the run
## director only decides WHEN it comes (Config.WARDEN_AFTER).

const ATTACK_EVERY := 5.0   # seconds between special moves
const CHARGE_SPEED := 3.6   # x walk speed during a charge
const SLAM_RADIUS := 210.0
const CLEAR_BONUS := 0.8    # +80% hp per biome already conquered

var _wstate := "walk"        # walk | tele_charge | charging | tele_slam | summoning
var _wtimer := 0.0
var _watk_cd := 4.0
var _charge_dir := Vector2.ZERO
var _charge_hit := false


func _init() -> void:
	arch = "warden"
	display_name = "Warden"
	base_hp = 260.0
	speed = 46.0
	damage = 24.0
	radius = 40.0
	xp_tier = "large"
	is_boss = true


## Wardens grow with every biome you've already conquered. Returns the hp it
## settled on (for the run log).
func scale_for(cleared_biomes: int, hp_scale: float) -> float:
	hp = base_hp * (1.0 + CLEAR_BONUS * cleared_biomes) * hp_scale
	return hp


## The Warden fully owns its movement: a walk -> telegraph -> execute state
## machine on a cadence.
func _autonomous() -> bool:
	return true


func _tick(delta: float) -> void:
	var to_p := to_player()
	_wtimer -= delta
	match _wstate:
		"walk":
			velocity = to_p.normalized() * speed * slow_mult
			move_and_slide()
			_watk_cd -= delta
			if _watk_cd <= 0.0:
				_watk_cd = ATTACK_EVERY
				var roll := randf()
				if roll < 0.4 and to_p.length() > 180.0:
					_wstate = "tele_charge"
					_wtimer = 0.8
				elif roll < 0.75 and to_p.length() < 320.0:
					_wstate = "tele_slam"
					_wtimer = 1.0
				else:
					_wstate = "summoning"
					_wtimer = 0.9
				queue_redraw()
		"tele_charge":
			velocity = Vector2.ZERO  # plant, aim, glow
			_charge_dir = to_p.normalized()
			if _wtimer <= 0.0:
				_wstate = "charging"
				_wtimer = 0.7
				_charge_hit = false
			queue_redraw()
		"charging":
			velocity = _charge_dir * speed * CHARGE_SPEED
			move_and_slide()
			if not _charge_hit and to_p.length() < radius + 20.0:
				_charge_hit = true
				target.take_damage(damage * 1.2, "Warden (charge)")
			if _wtimer <= 0.0:
				_wstate = "walk"
				queue_redraw()
		"tele_slam":
			velocity = Vector2.ZERO
			if _wtimer <= 0.0:
				if to_p.length() <= SLAM_RADIUS:
					target.take_damage(damage, "Warden (slam)")
				var ring := RingFx.new()
				ring.max_radius = SLAM_RADIUS
				ring.color = color
				ring.global_position = global_position
				get_parent().add_child(ring)
				Fx.shake(0.5)
				_wstate = "walk"
			queue_redraw()
		"summoning":
			velocity = Vector2.ZERO
			if _wtimer <= 0.0:
				var game = get_parent().get_parent()
				if game != null and game.has_method("spawn_minion"):
					var roster: Array = Biomes.of(biome).roster
					for i in 4:
						var off := Vector2(randf_range(-70, 70), randf_range(-70, 70))
						game.spawn_minion(roster[0].arch, biome, global_position + off)
				_wstate = "walk"
				queue_redraw()


func _pre_draw() -> bool:
	# Telegraphs: read the move BEFORE it lands.
	match _wstate:
		"tele_charge":
			if target != null and is_instance_valid(target):
				var aim := to_player().normalized()
				draw_line(Vector2.ZERO, aim * 420.0, Color(1, 0.3, 0.2, 0.55), 7.0)
			draw_arc(Vector2.ZERO, radius + 8.0, 0.0, TAU, 24, Color(1, 0.3, 0.2, 0.9), 4.0)
		"charging":
			draw_arc(Vector2.ZERO, radius + 8.0, 0.0, TAU, 24, Color(1, 0.5, 0.2, 0.9), 4.0)
		"tele_slam":
			draw_circle(Vector2.ZERO, SLAM_RADIUS, Color(1, 0.25, 0.2, 0.10))
			draw_arc(Vector2.ZERO, SLAM_RADIUS, 0.0, TAU, 48, Color(1, 0.3, 0.2, 0.8), 3.0)
		"summoning":
			draw_arc(Vector2.ZERO, radius + 12.0, 0.0, TAU, 24, Color(0.8, 0.5, 1.0, 0.8), 3.0)
	return true

class_name Enemy
extends CharacterBody2D
## A beeline chaser. Stat-driven via setup(); damaged by projectiles, deals
## contact damage to the player through its hitbox Area2D.

signal died

var hp := 5.0
var speed := 100.0
var damage := 5.0
var radius := 10.0
var color := Color(0.86, 0.36, 0.36)
var is_boss := false
var xp_tier := "small"  # which gem tier this enemy drops on death

var target: Node2D
var _dead := false
var _dmg_accum := 0.0
var _dmg_cd := 0.0


func setup(stats: Dictionary, tgt: Node2D) -> void:
	hp = stats.hp
	speed = stats.speed
	damage = stats.damage
	radius = stats.radius
	color = stats.color
	target = tgt


func _ready() -> void:
	add_to_group("enemies")
	z_index = 5
	collision_layer = 0  # body itself collides with nothing
	collision_mask = 0

	# Hitbox: detected by the player's hurtbox and by projectiles (layer 2).
	var hitbox := Area2D.new()
	hitbox.collision_layer = 2
	hitbox.collision_mask = 0
	hitbox.monitoring = false  # passive; others detect it
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	cs.shape = shape
	hitbox.add_child(cs)
	add_child(hitbox)

	queue_redraw()


func _physics_process(delta: float) -> void:
	if _dmg_accum > 0.0:
		_dmg_cd -= delta
		if _dmg_cd <= 0.0:
			Fx.damage_number(global_position, _dmg_accum)
			_dmg_accum = 0.0
			_dmg_cd = 0.18
	if _dead or target == null or not is_instance_valid(target):
		return
	var dir := (target.global_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()


func take_damage(amount: float) -> void:
	if _dead:
		return
	hp -= amount
	if Config.SHOW_DAMAGE_NUMBERS:
		_dmg_accum += amount
	if hp <= 0.0:
		_dead = true
		if _dmg_accum > 0.0:
			Fx.damage_number(global_position, _dmg_accum)
		Fx.death_pop(global_position, color)
		died.emit()
		queue_free()
		return
	# quick hit flash for juice
	modulate = Color(2.2, 2.2, 2.2)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.12)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(0, 0, 0, 0.35), 2.0)

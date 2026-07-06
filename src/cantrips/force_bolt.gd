class_name ForceBolt
extends BoltCantrip
## The tabula-rasa starter every run begins with. No family, no riders — the
## baseline the awakened cantrips must out-score.


func _init() -> void:
	id = "force"
	display_name = "Force Bolt"
	cooldown = 0.45
	damage = 4.5
	reach = 360.0
	speed = 520.0
	dtype = "arcane"

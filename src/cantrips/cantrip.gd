class_name Cantrip
extends RefCounted
## One basic attack. The tabula-rasa starter ("force") or a family's awakened
## attack (id == the family id). Every cast cycle the caster brain calls
## score() on every available cantrip and casts the winner — whose cooldown
## then silences ALL cantrips (the cooldown IS the cost).
## Every cantrip is its own file in src/cantrips/, registered in Cantrips.

var id := ""
var display_name := ""
var cooldown := 0.5
var damage := 5.0
var reach := 360.0
var dtype := "arcane"


## Damage after tier scaling: deeper insight hits harder...
func dmg_for(p: Player) -> float:
	if id == "force":
		return damage * p.cantrip_mult
	var tier := maxi(p.insight_tier(id), 1)
	return damage * float(p.fam_power.get(id, 1.0)) * (1.0 + Config.TIER_DMG_BONUS * (tier - 1))


## ...but slower, so cheap low-tier attacks stay competitive in the selector.
func cd_for(p: Player) -> float:
	if id == "force":
		return cooldown
	var tier := maxi(p.insight_tier(id), 1)
	return cooldown * (1.0 + Config.TIER_CD_PENALTY * (tier - 1))


## Utility score for casting right now: expected damage plus any survival or
## healing value. Returns {"score": float, "target": Node2D?}; score 0 = pass.
## The brain applies home-turf bias and cooldown normalization afterwards.
func score(_p: Player) -> Dictionary:
	return {"score": 0.0}


func cast(_p: Player, _target) -> void:
	pass

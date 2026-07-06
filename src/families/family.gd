class_name Family
extends RefCounted
## One of the six schools the world can teach the tabula-rasa caster.
## A family owns its color and name, the skills its level-up cards can offer
## (src/skills/<id>/), and its repeatable deepening cards. Its basic attack
## lives in src/cantrips/, registered in Cantrips under this family's id.
## Every family is its own file in src/families/, registered in Families.

var id := ""
var display_name := ""
var color := Color.WHITE
var skills: Array = []    # Skill scripts in card order (tier ascending)
var minors: Array = []    # repeatable deepening cards [{id, name, desc, max}]

var _skill_meta: Array = []


## Cached Skill instances used as card metadata (id, name, desc, tier gate).
func skill_meta() -> Array:
	if _skill_meta.is_empty():
		for s in skills:
			_skill_meta.append(s.new())
	return _skill_meta


func skill_script(key: String) -> Script:
	var metas := skill_meta()
	for i in metas.size():
		if metas[i].id == key:
			return skills[i]
	return null


## Apply one of this family's deepening cards to the caster. Returns false if
## the id isn't one of ours. Each family file owns its own effects.
## Minors flagged "rebuild": true touch skill-granted stats, so the run
## director re-applies them after a skill is forgotten and the set rebuilt.
func apply_minor(_p: Player, _id: String) -> bool:
	return false

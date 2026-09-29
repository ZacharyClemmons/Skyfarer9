class_name Component extends RefCounted
## Base for all components. Components hold data and answer interaction hooks;
## systems (atmos, power, life, AI...) drive the per-tick behaviour.
##
## Interaction hooks mirror SS13's attack_hand / attackby / attack_self chain:
##   attack_hand(user)        empty-hand click
##   attackby(user, item)     clicked with `item` in the active hand
##   attack_self(user)        item used in hand (Z)
## Each returns true when it consumed the interaction.

var e: Entity

func key() -> StringName:
	return &""

func on_added() -> void:
	pass

func on_removed() -> void:
	pass

func on_moved(_from: Vector2i, _to: Vector2i) -> void:
	pass

func examine(_user: Entity, _lines: Array) -> void:
	pass

## Append {"name": String, "cb": Callable, "priority": int} dictionaries.
func verbs(_user: Entity, _out: Array) -> void:
	pass

func attack_hand(_user: Entity) -> bool:
	return false

func attackby(_user: Entity, _item: Entity) -> bool:
	return false

func attack_self(_user: Entity) -> bool:
	return false

## Damage routed to this entity. Return remaining amount not absorbed.
func take_damage(amount: float, _kind: String, _source: Entity) -> float:
	return amount

## Short tag list for AI perception ("fire_extinguisher", "food", "broken"...)
func ai_tags(_out: Dictionary) -> void:
	pass

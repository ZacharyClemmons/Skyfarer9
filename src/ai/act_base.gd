class_name ActBase extends RefCounted
## Base for NPC action primitives (see Act for the concrete actions).

enum { RUNNING, DONE, FAILED }

var label := ""

func start(_b) -> void:
	pass

func tick(_b, _dt: float) -> int:
	return DONE

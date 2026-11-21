class_name PlayerStats
extends RefCounted
## SRP: чистые данные одного бойца. Ни сети, ни UI.

var character_id: StringName = &""
var display_name: String = ""
var throws: int = 0
var hits: int = 0

func _init(p_character_id: StringName = &"", p_display_name: String = "") -> void:
	character_id = p_character_id
	display_name = p_display_name

func accuracy() -> float:
	if throws == 0:
		return 0.0
	return float(hits) / float(throws) * 100.0

func to_dict() -> Dictionary:
	return {
		"character_id": String(character_id),
		"display_name": display_name,
		"throws": throws,
		"hits": hits,
	}

func load_dict(data: Dictionary) -> void:
	character_id = StringName(data.get("character_id", ""))
	display_name = data.get("display_name", "")
	throws = int(data.get("throws", 0))
	hits = int(data.get("hits", 0))

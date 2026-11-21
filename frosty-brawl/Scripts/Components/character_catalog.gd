extends RefCounted
class_name CharacterCatalog
## SRP: только знает, какой id какому .tscn соответствует.
## OCP: новый персонаж = одна новая строка, остальной код не трогаем.
## ВАЖНО: class_name убран, чтобы избежать конфликта глобальных имен в Godot.

const DEFAULT_ID: StringName = &"knight"

const _SCENES: Dictionary = {
	&"mage": "res://Scenes/Characters/mage_player.tscn",
	&"barbarian": "res://Scenes/Characters/barbarian_player.tscn",
	&"knight": "res://Scenes/Characters/knight_player.tscn",
	&"rogue": "res://Scenes/Characters/rogue_player.tscn",
}

const _DISPLAY_NAMES: Dictionary = {
	&"mage": "Маг",
	&"barbarian": "Варвар",
	&"knight": "Рыцарь",
	&"rogue": "Воришка",
}

func has_character(id: StringName) -> bool:
	return _SCENES.has(id)

func get_scene(id: StringName) -> PackedScene:
	if not has_character(id):
		push_error("CharacterCatalog: нет персонажа с id '%s'" % id)
		return null
	return load(_SCENES[id]) as PackedScene

func get_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_SCENES.keys())
	return ids
	
func get_display_name(id: StringName) -> String:
	return _DISPLAY_NAMES.get(id, String(id))

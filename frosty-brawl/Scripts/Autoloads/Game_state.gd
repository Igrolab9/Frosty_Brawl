extends Node
## SRP: только хранит выбор персонажа. Живёт дольше любой сцены.

var selected_character_id: StringName = &""

func select_character(id: StringName) -> void:
	selected_character_id = id

func has_selection() -> bool:
	return selected_character_id != &""

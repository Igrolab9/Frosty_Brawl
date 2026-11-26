extends Node
## SRP: только хранит данные сессии. Живёт дольше любой сцены.

enum Mode { BOTS, MULTIPLAYER }

var mode: Mode = Mode.BOTS
var selected_character_id: StringName = &""
## Состав матча: peer_id -> {name, character_id, ready}. Заполняет лобби.
var roster: Dictionary = {}

func select_character(id: StringName) -> void:
	selected_character_id = id

func has_selection() -> bool:
	return selected_character_id != &""

func is_multiplayer() -> bool:
	return mode == Mode.MULTIPLAYER

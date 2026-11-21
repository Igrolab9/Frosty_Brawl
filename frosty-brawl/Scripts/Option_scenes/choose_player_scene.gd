extends CanvasLayer
## Дирижёр меню: клики кнопок → выбор в GameState → смена сцены.

@export_file("*.tscn") var game_scene_path: String = "res://Scenes/chill_zone.tscn"

@onready var _character_buttons: Dictionary[StringName, BaseButton] = {
	&"mage": $Mage_button as BaseButton,
	&"barbarian": $Barbarian_button as BaseButton,
	&"knight": $Knight_button as BaseButton,
	&"rogue": $Rough_button as BaseButton, # опечатка в имени узла, см. примечание ниже
}
@onready var _start_button: BaseButton = $Start_game_button as BaseButton

var _catalog := CharacterCatalog.new()
var _selected_id: StringName = &""

func _ready() -> void:
	for id: StringName in _character_buttons:
		_character_buttons[id].pressed.connect(_on_character_pressed.bind(id))
	_start_button.pressed.connect(_on_start_pressed)
	if GameState.has_selection(): # вернулись в меню — восстанавливаем выбор
		_selected_id = GameState.selected_character_id
	_refresh_ui()

func _on_character_pressed(id: StringName) -> void:
	if not _catalog.has_character(id):
		push_error("Меню: id '%s' отсутствует в каталоге" % id)
		return
	_selected_id = id
	_refresh_ui()

func _on_start_pressed() -> void:
	if _selected_id == &"":
		return
	GameState.select_character(_selected_id)
	var err := get_tree().change_scene_to_file(game_scene_path)
	if err != OK:
		push_error("Не удалось загрузить сцену: %s" % game_scene_path)

func _refresh_ui() -> void:
	_start_button.disabled = _selected_id == &""
	for id: StringName in _character_buttons:
		var btn := _character_buttons[id]
		btn.modulate = Color.WHITE if id == _selected_id else Color(0.55, 0.55, 0.55)

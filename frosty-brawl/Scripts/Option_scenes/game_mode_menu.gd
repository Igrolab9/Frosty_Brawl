extends CanvasLayer # если корень сцены у тебя Node — поставь extends Node
## Дирижёр: клик → режим в GameState → следующая сцена.

@export_file("*.tscn") var choose_player_path: String = "res://Scenes/Levels/choose_player_scene.tscn"
@export_file("*.tscn") var multiplayer_menu_path: String = "res://Scenes/Levels/multiplayer_menu.tscn"

@onready var _bots_button: BaseButton = $Against_bots_mode_button
@onready var _multiplayer_button: BaseButton = $Multiplayer_mode_button

func _ready() -> void:
	_bots_button.pressed.connect(_on_bots_pressed)
	_multiplayer_button.pressed.connect(_on_multiplayer_pressed)

func _on_bots_pressed() -> void:
	GameState.mode = GameState.Mode.BOTS
	get_tree().change_scene_to_file(choose_player_path)

func _on_multiplayer_pressed() -> void:
	GameState.mode = GameState.Mode.MULTIPLAYER
	get_tree().change_scene_to_file(multiplayer_menu_path)

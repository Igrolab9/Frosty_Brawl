extends CanvasLayer
## Дирижёр: имя/IP → Net.host/join → при успехе в лобби выбора персонажа.

@export_file("*.tscn") var choose_player_path: String = "res://Scenes/Levels/choose_player_scene.tscn"
@export_file("*.tscn") var mode_menu_path: String = "res://Scenes/Levels/game_mode_menu.tscn"

@onready var _name_edit: LineEdit = $Name_edit
@onready var _ip_edit: LineEdit = $Ip_edit
@onready var _host_button: BaseButton = $Host_button
@onready var _join_button: BaseButton = $Join_button
@onready var _status: Label = $Status_label

func _ready() -> void:
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	$Back_button.pressed.connect(_on_back_pressed)
	Net.connected.connect(_on_connected)
	Net.connection_failed.connect(_on_failed)

func _player_name() -> String:
	var n := _name_edit.text.strip_edges()
	return n if n != "" else "Игрок"

func _on_host_pressed() -> void:
	if Net.host_game(_player_name()) != OK:
		_status.text = "Не удалось создать сервер (порт занят?)"

func _on_join_pressed() -> void:
	_status.text = "Подключаемся..."
	_host_button.disabled = true
	_join_button.disabled = true
	var ip := _ip_edit.text.strip_edges()
	if Net.join_game(ip if ip != "" else "127.0.0.1", _player_name()) != OK:
		_on_failed()

func _on_connected() -> void:
	get_tree().change_scene_to_file(choose_player_path)

func _on_failed() -> void:
	_status.text = "Не удалось подключиться"
	_host_button.disabled = false
	_join_button.disabled = false

func _on_back_pressed() -> void:
	Net.leave()
	get_tree().change_scene_to_file(mode_menu_path)

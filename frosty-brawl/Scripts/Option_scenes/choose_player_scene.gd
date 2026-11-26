extends CanvasLayer
## Дирижёр выбора: офлайн — как раньше; онлайн — выбор через Net, старт у хоста.

@export_file("*.tscn") var game_scene_path: String = "res://Scenes/Levels/chill_zone.tscn"
@export_file("*.tscn") var mode_menu_path: String = "res://Scenes/Levels/game_mode_menu.tscn"

@onready var _character_buttons: Dictionary[StringName, BaseButton] = {
	&"mage": $Mage_button as BaseButton,
	&"barbarian": $Barbarian_button as BaseButton,
	&"knight": $Knight_button as BaseButton,
	&"rogue": $Rough_button as BaseButton,
}
@onready var _start_button: BaseButton = $Start_game_button
@onready var _ready_button: BaseButton = $Ready_button
@onready var _players_label: Label = $Players_label

var _catalog := CharacterCatalog.new()
var _lobby_view: LobbyView
var _selected_id: StringName = &""
var _is_ready := false
var _online := false

func _ready() -> void:
	_online = GameState.is_multiplayer() and Net.is_online()
	_lobby_view = LobbyView.new(_catalog, _players_label)
	for id: StringName in _character_buttons:
		_character_buttons[id].pressed.connect(_on_character_pressed.bind(id))
	_start_button.pressed.connect(_on_start_pressed)
	_ready_button.pressed.connect(_on_ready_toggled)
	_ready_button.visible = _online
	_players_label.visible = _online
	if _online:
		Net.lobby_changed.connect(_refresh_online_ui)
		Net.match_started.connect(_on_match_started)
		Net.server_closed.connect(_on_server_closed)
		_start_button.visible = multiplayer.is_server() # клиенты старт не видят
		_refresh_online_ui()
	else:
		if GameState.has_selection():
			_selected_id = GameState.selected_character_id
		_refresh_ui()

func _on_character_pressed(id: StringName) -> void:
	if not _catalog.has_character(id):
		return
	if _online:
		Net.select_character(id) # сервер проверит занятость и пришлёт снапшот
	else:
		_selected_id = id
		_refresh_ui()

func _on_ready_toggled() -> void:
	Net.set_ready(not _is_ready)

func _on_start_pressed() -> void:
	if _online:
		Net.start_match()
		return
	if _selected_id == &"":
		return
	GameState.select_character(_selected_id)
	_go_to_game()

func _on_match_started(_roster: Dictionary) -> void:
	GameState.select_character(_selected_id)
	_go_to_game()

func _on_server_closed() -> void:
	get_tree().change_scene_to_file(mode_menu_path)

func _go_to_game() -> void:
	if get_tree().change_scene_to_file(game_scene_path) != OK:
		push_error("Не удалось загрузить сцену: %s" % game_scene_path)

func _refresh_ui() -> void: # офлайн — без изменений
	_start_button.disabled = _selected_id == &""
	for id: StringName in _character_buttons:
		_character_buttons[id].modulate = Color.WHITE if id == _selected_id else Color(0.55, 0.55, 0.55)

func _refresh_online_ui() -> void:
	var players := Net.lobby.get_players()
	var me := Net.local_id()
	var my: Dictionary = players.get(me, {})
	_selected_id = my.get("character_id", &"")
	_is_ready = my.get("ready", false)
	_ready_button.text = "Отменить готовность" if _is_ready else "Готов"
	_ready_button.disabled = _selected_id == &""
	var taken: Dictionary = {}
	for pid: int in players:
		if pid != me and players[pid].character_id != &"":
			taken[players[pid].character_id] = true
	for id: StringName in _character_buttons:
		var btn := _character_buttons[id]
		btn.disabled = taken.has(id)
		btn.modulate = Color.WHITE if id == _selected_id \
			else (Color(0.3, 0.3, 0.3) if taken.has(id) else Color(0.55, 0.55, 0.55))
	_start_button.disabled = not Net.lobby.can_start()
	_lobby_view.render(players, me)

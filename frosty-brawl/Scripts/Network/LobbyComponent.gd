class_name LobbyComponent
extends RefCounted
## SRP: только состояние лобби и правила (уникальность персонажа, готовность).
## Сети тут нет — данные приходят через методы, которые вызывает Net.

signal lobby_changed

const MAX_PLAYERS: int = 4

var _catalog: CharacterCatalog
var _players: Dictionary = {} # peer_id -> {name, character_id, ready}

func _init(catalog: CharacterCatalog) -> void:
	_catalog = catalog

func add_player(peer_id: int, player_name: String) -> void:
	if _players.has(peer_id) or _players.size() >= MAX_PLAYERS:
		return
	_players[peer_id] = {"name": player_name, "character_id": &"", "ready": false}
	lobby_changed.emit()

func remove_player(peer_id: int) -> void:
	if _players.erase(peer_id):
		lobby_changed.emit()

func try_select_character(peer_id: int, id: StringName) -> bool:
	if not _players.has(peer_id) or not _catalog.has_character(id):
		return false
	for other: int in _players:
		if other != peer_id and _players[other].character_id == id:
			return false # персонаж уже занят другим игроком
	_players[peer_id].character_id = id
	_players[peer_id].ready = false # сменил персонажа — готовность сбрасываем
	lobby_changed.emit()
	return true

func set_ready(peer_id: int, value: bool) -> void:
	if not _players.has(peer_id) or _players[peer_id].character_id == &"":
		return
	_players[peer_id].ready = value
	lobby_changed.emit()

func can_start() -> bool:
	if _players.size() < 2: # для тестов хватает двоих; хочешь строго 4 — поставь == MAX_PLAYERS
		return false
	for p: Dictionary in _players.values():
		if p.character_id == &"" or not p.ready:
			return false
	return true

func get_players() -> Dictionary:
	return _players.duplicate(true)

func load_snapshot(snapshot: Dictionary) -> void: # клиенты применяют состояние от сервера
	_players = snapshot
	lobby_changed.emit()

func clear() -> void:
	_players.clear()
	lobby_changed.emit()

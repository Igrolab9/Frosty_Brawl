extends Node
## Дирижёр: тонкий RPC-слой + оркестрация компонентов.
## Все @rpc живут ЗДЕСЬ (Node в дереве), логика — в RefCounted-компонентах.

signal connected
signal connection_failed
signal server_closed
signal lobby_changed
signal match_started(roster: Dictionary)

var connection: ConnectionComponent
var lobby: LobbyComponent
var _local_name: String = "Игрок"

func _ready() -> void:
	connection = ConnectionComponent.new(multiplayer)
	lobby = LobbyComponent.new(CharacterCatalog.new())
	lobby.lobby_changed.connect(func() -> void: lobby_changed.emit())
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# ---------- публичное API для UI ----------

func host_game(player_name: String) -> Error:
	_local_name = player_name
	var err := connection.host()
	if err != OK:
		return err
	lobby.clear()
	lobby.add_player(1, player_name) # хост всегда peer_id == 1
	connected.emit()
	return OK

func join_game(ip: String, player_name: String) -> Error:
	_local_name = player_name
	return connection.join(ip)

func leave() -> void:
	connection.close()
	lobby.clear()

func is_online() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and not peer is OfflineMultiplayerPeer \
		and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func local_id() -> int:
	return multiplayer.get_unique_id()

func select_character(id: StringName) -> void:
	if multiplayer.is_server():
		lobby.try_select_character(1, id)
		_broadcast_lobby()
	else:
		_request_select_character.rpc_id(1, id)

func set_ready(value: bool) -> void:
	if multiplayer.is_server():
		lobby.set_ready(1, value)
		_broadcast_lobby()
	else:
		_request_set_ready.rpc_id(1, value)

func start_match() -> void:
	if not multiplayer.is_server() or not lobby.can_start():
		return
	_rpc_start_match.rpc(lobby.get_players())

# ---------- RPC-endpoint'ы (тонкие, вся логика в компонентах) ----------

@rpc("any_peer", "call_remote", "reliable")
func _request_join(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	lobby.add_player(multiplayer.get_remote_sender_id(), player_name)
	_broadcast_lobby() # заодно снапшот для новичка

@rpc("any_peer", "call_remote", "reliable")
func _request_select_character(id: StringName) -> void:
	if not multiplayer.is_server():
		return
	lobby.try_select_character(multiplayer.get_remote_sender_id(), id)
	_broadcast_lobby()

@rpc("any_peer", "call_remote", "reliable")
func _request_set_ready(value: bool) -> void:
	if not multiplayer.is_server():
		return
	lobby.set_ready(multiplayer.get_remote_sender_id(), value)
	_broadcast_lobby()

@rpc("authority", "call_remote", "reliable")
func _receive_lobby(snapshot: Dictionary) -> void:
	lobby.load_snapshot(snapshot)

@rpc("authority", "call_local", "reliable")
func _rpc_start_match(roster: Dictionary) -> void:
	GameState.roster = roster
	match_started.emit(roster)

# ---------- внутреннее ----------

func _broadcast_lobby() -> void:
	_receive_lobby.rpc(lobby.get_players())

func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		lobby.remove_player(peer_id)
		_broadcast_lobby()

func _on_connected_to_server() -> void:
	_request_join.rpc_id(1, _local_name)
	connected.emit()

func _on_connection_failed() -> void:
	connection.close()
	connection_failed.emit()

func _on_server_disconnected() -> void:
	connection.close()
	lobby.clear()
	server_closed.emit()

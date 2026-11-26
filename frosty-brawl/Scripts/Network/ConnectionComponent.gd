class_name ConnectionComponent
extends RefCounted
## SRP: только транспорт (ENet). Про лобби и персонажей ничего не знает.
## DIP: MultiplayerAPI инжектим — у RefCounted своего `multiplayer` нет!

const DEFAULT_PORT: int = 27015
const MAX_PLAYERS: int = 4

var _mp: MultiplayerAPI

func _init(mp: MultiplayerAPI) -> void:
	_mp = mp

func host(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1) # 3 клиента + хост = 4
	if err == OK:
		_mp.multiplayer_peer = peer
	return err

func join(ip: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err == OK:
		_mp.multiplayer_peer = peer
	return err

func close() -> void:
	_mp.multiplayer_peer = OfflineMultiplayerPeer.new()

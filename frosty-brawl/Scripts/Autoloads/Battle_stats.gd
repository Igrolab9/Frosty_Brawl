extends Node
## Дирижёр статистики. Источник правды — сервер.
## RefCounted-компонент хранит данные, этот Node — сеть и сигналы.

signal stats_changed

var _stats := BattleStatsComponent.new()

func _ready() -> void:
	_stats.stats_changed.connect(_on_stats_changed)
	multiplayer.peer_connected.connect(_on_peer_connected)

func get_stats() -> BattleStatsComponent:
	return _stats

# ─── API для геймплея (зовут chill_zone / spawner / snow_ball) ───

func register_player(key: StringName, character_id: StringName, display_name: String) -> void:
	if not _is_server():
		return # клиентам реестр придёт снапшотом
	_stats.register_player(key, character_id, display_name)

func report_throw(key: StringName) -> void:
	if _is_server():
		_stats.record_throw(key)
	else:
		_rpc_report_throw.rpc_id(1, String(key))

func report_hit(key: StringName) -> void:
	if _is_server():
		_stats.record_hit(key)
	else:
		_rpc_report_hit.rpc_id(1, String(key))

func reset_match() -> void:
	if _is_server():
		_stats.reset()

# ─── RPC ───

@rpc("any_peer", "call_remote", "reliable")
func _rpc_report_throw(key: String) -> void:
	if not _is_server():
		return
	# TODO: когда игроки будут именоваться по peer_id — проверяй,
	# что multiplayer.get_remote_sender_id() владеет этим key (античит)
	_stats.record_throw(StringName(key))

@rpc("any_peer", "call_remote", "reliable")
func _rpc_report_hit(key: String) -> void:
	if not _is_server():
		return
	_stats.record_hit(StringName(key))

@rpc("authority", "call_remote", "reliable")
func _rpc_sync(data: Dictionary) -> void:
	_stats.load_snapshot(data)

# ─── внутреннее ───

func _on_stats_changed() -> void:
	stats_changed.emit()
	if _is_server() and _has_network():
		_rpc_sync.rpc(_stats.snapshot())

func _on_peer_connected(_id: int) -> void:
	if _is_server():
		_rpc_sync.rpc(_stats.snapshot()) # новичку — полное состояние

func _is_server() -> bool:
	return not _has_network() or multiplayer.is_server()

func _has_network() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer)

class_name NetworkSyncComponent
extends RefCounted
## SRP: только репликация transform владельца остальным пирам.
## Node (MultiplayerSynchronizer) живёт в дереве, RefCounted лишь конфигурирует его.

var _sync: MultiplayerSynchronizer

func _init(owner: Node3D) -> void:
	_sync = MultiplayerSynchronizer.new()
	_sync.name = "NetSync"
	var cfg := SceneReplicationConfig.new()
	# root_path у синхронизатора по умолчанию ".." → "." = сам персонаж
	cfg.add_property(NodePath(".:position"))
	cfg.add_property(NodePath(".:rotation"))
	_sync.replication_config = cfg
	_sync.replication_interval = 0.05 # 20 Hz; для LAN можно 0.0 (каждый кадр)
	_sync.set_multiplayer_authority(owner.get_multiplayer_authority())
	owner.add_child(_sync)

extends Node3D
## Дирижёр: офлайн — локальный + боты; онлайн — по одному персонажу на пира.
## Табло создаётся и привязывается ОДИН раз в _ready, до любого спавна —
## поэтому оно больше не может остаться без данных.

var _catalog := CharacterCatalog.new()
var _spawner := CharacterSpawner.new(_catalog)
var _collector := SpawnPointCollector.new()
var _presentation := PlayerPresentation.new()

var _points: Array[Marker3D] = []
var _local_player: Node3D
var _other_players: Array[Node3D] = []
var _bots: Array[Node3D] = []
var _scoreboard: Scoreboard
var _net_spawner: MultiplayerSpawner

func _ready() -> void:
	_points = _collector.collect(self)
	if _points.is_empty():
		push_error("Chill_zone: не найдены точки Spawn_point_*")
		return
	BattleStats.reset_match()

	# Табло существует и привязано к компоненту статистики ВСЕГДА,
	# даже если бойцы ещё не приехали по сети.
	_scoreboard = Scoreboard.new()
	add_child(_scoreboard)
	_scoreboard.bind(BattleStats.get_stats(), &"")

	if GameState.is_multiplayer():
		_setup_online()
	else:
		_setup_offline()

# ─── ОФЛАЙН: локальный + боты ───
func _setup_offline() -> void:
	var local_id := GameState.selected_character_id
	if not GameState.has_selection():
		local_id = CharacterCatalog.DEFAULT_ID
	_local_player = _spawner.spawn(local_id, _points[0], self, false)
	_register_stats(_local_player, local_id)

	var other_ids := _catalog.get_ids().filter(
		func(id: StringName) -> bool: return id != local_id
	)
	for i in other_ids.size():
		var point_index := i + 1
		if point_index >= _points.size():
			break
		var other := _spawner.spawn(other_ids[i], _points[point_index], self, true)
		if other:
			_presentation.apply(other, false, true)
			_other_players.append(other)
			_bots.append(other)
			_register_stats(other, other_ids[i])

	if _local_player:
		_presentation.apply(_local_player, true, false)
		_scoreboard.set_local_key(StringName(_local_player.name))

# ─── ОНЛАЙН: без ботов, по персонажу на каждого пира ───
func _setup_online() -> void:
	_net_spawner = MultiplayerSpawner.new()
	_net_spawner.name = "NetSpawner"
	_net_spawner.spawn_path = ^".."
	_net_spawner.spawn_function = _spawn_network_player
	add_child(_net_spawner)
	# ВНИМАНИЕ: spawned стреляет ТОЛЬКО у клиентов (remote peers), не у сервера.
	_net_spawner.spawned.connect(_on_network_player_spawned)

	if multiplayer.is_server():
		var i := 0
		for peer_id: int in GameState.roster:
			var p: Dictionary = GameState.roster[peer_id]
			var node := _net_spawner.spawn({
				"peer_id": peer_id,
				"character_id": String(p.character_id),
				"point": i,
			})
			# На сервере сигнал spawned не сработает — регистрируем/оформляем сами.
			if node:
				_on_network_player_spawned(node)
			i += 1
	# Клиенты никого не спавнят — спавнер привозит персонажей с сервера.

func _spawn_network_player(data: Dictionary) -> Node:
	var player := _catalog.get_scene(StringName(data.character_id)).instantiate() as Node3D
	player.name = str(data.peer_id)
	player.is_bot = false
	player.set_multiplayer_authority(data.peer_id)
	player.set_meta("point", data.point)
	player.set_meta("character_id", data.character_id)
	return player

func _on_network_player_spawned(node: Node) -> void:
	var player := node as Node3D
	var idx: int = player.get_meta("point", 0)
	if idx < _points.size():
		player.global_transform = _points[idx].global_transform
	var is_local := player.get_multiplayer_authority() == multiplayer.get_unique_id()
	_presentation.apply(player, is_local, false)
	_register_stats(player, StringName(player.get_meta("character_id")))
	if is_local:
		_local_player = player
		_scoreboard.set_local_key(StringName(player.name))

func _register_stats(player: Node3D, id: StringName) -> void:
	if player == null:
		return
	BattleStats.register_player(player.name, id, _catalog.get_display_name(id))

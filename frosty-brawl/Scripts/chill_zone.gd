extends Node3D
## Дирижёр: расставляет персонажей по точкам спавна.
## Локальный — на первой точке, остальные — боты на свободных.

var _catalog := CharacterCatalog.new()
var _spawner := CharacterSpawner.new(_catalog) # DIP: инъекция каталога
var _collector := SpawnPointCollector.new()
var _presentation := PlayerPresentation.new()

var _local_player: Node3D
var _other_players: Array[Node3D] = [] # пригодится для логики раунда
var _bots: Array[Node3D] = [] # 🆕 отдельно храним ботов — на случай AI-менеджера

func _ready() -> void:
	var points := _collector.collect(self)
	if points.is_empty():
		push_error("Chill_zone: не найдены точки Spawn_point_*")
		return

	var local_id := GameState.selected_character_id
	if not GameState.has_selection():
		local_id = CharacterCatalog.DEFAULT_ID # запуск уровня напрямую через F6

	# 1) локальный игрок — всегда первая точка
	_local_player = _spawner.spawn(local_id, points[0], self, false) # 🆕 явно false

	# 2) остальные персонажи каталога — на оставшихся точках, КАК БОТЫ
	var other_ids := _catalog.get_ids().filter(
		func(id: StringName) -> bool: return id != local_id
	)
	for i in other_ids.size():
		var point_index := i + 1
		if point_index >= points.size():
			push_warning("Chill_zone: точек меньше, чем персонажей — '%s' пропущен" % other_ids[i])
			break
		# 🆕 as_bot = true — вот где была главная ошибка
		var other := _spawner.spawn(other_ids[i], points[point_index], self, true)
		if other:
			# 🆕 apply теперь знает, что это бот: физика включится, input — нет
			_presentation.apply(other, false, true)
			_other_players.append(other)
			_bots.append(other)

	# 3) локального включаем ПОСЛЕДНИМ: даже если чужие камеры имели
	# current = true в своих .tscn и перехватили viewport при входе в дерево,
	# финальный apply гарантированно возвращает камеру нам.
	if _local_player:
		_presentation.apply(_local_player, true, false)

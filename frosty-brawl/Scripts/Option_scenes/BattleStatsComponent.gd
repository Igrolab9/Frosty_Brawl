class_name BattleStatsComponent
extends RefCounted
## SRP: хранит статистику всех бойцов, умеет сериализоваться.
## Про RPC и UI не знает — только сигнал stats_changed (DIP).

signal stats_changed

var _entries: Dictionary = {} # StringName (имя узла игрока) -> PlayerStats

func register_player(key: StringName, character_id: StringName, display_name: String) -> void:
	if _entries.has(key):
		return
	_entries[key] = PlayerStats.new(character_id, display_name)
	stats_changed.emit()

func record_throw(key: StringName) -> void:
	var entry: PlayerStats = _entries.get(key)
	if entry == null:
		return
	entry.throws += 1
	stats_changed.emit()

func record_hit(key: StringName) -> void:
	var entry: PlayerStats = _entries.get(key)
	if entry == null:
		return
	entry.hits += 1
	stats_changed.emit()

func reset() -> void:
	for entry: PlayerStats in _entries.values():
		entry.throws = 0
		entry.hits = 0
	stats_changed.emit()

func get_entries() -> Dictionary:
	return _entries

func snapshot() -> Dictionary:
	var data: Dictionary = {}
	for key: StringName in _entries:
		data[String(key)] = _entries[key].to_dict()
	return data

func load_snapshot(data: Dictionary) -> void:
	_entries.clear()
	for key: String in data:
		var entry := PlayerStats.new()
		entry.load_dict(data[key])
		_entries[StringName(key)] = entry
	stats_changed.emit()

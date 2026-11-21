class_name AudioComponent
extends RefCounted
## Универсальный звуковой движок. Годится для игрока, снежка, ловушки, буста.
## Про геймплей не знает ничего: умеет регистрировать cue и проигрывать их.
##
## РЕГИСТРАЦИЯ: scan() обходит контейнер ($Audio) и берёт каждый
## AudioStreamPlayer3D. Имя ноды -> id: "Jump_sound" -> "jump".
##
## НАСТРОЙКИ берутся из инспектора самой ноды (stream, volume_db, bus,
## max_polyphony, unit_size). Дополнительно можно задать meta на ноде:
##   cooldown     float — мин. интервал между срабатываниями
##   pitch_jitter float — случайный разброс pitch (0.08 = ±8%)
##   loop         bool  — принудительно считать звук зацикленным
##   custom_3d    bool  — не трогать unit_size/max_distance этой ноды

signal sound_played(id: StringName)
signal sound_stopped(id: StringName)

const _SUFFIXES: Array[String] = ["_sound", "_sfx", "_audio"]

var _owner: Node
var _cues: Dictionary = {}          # StringName -> _Cue
var _muted: bool = false
var _master_db: float = 0.0


class _Cue extends RefCounted:
	var id: StringName
	var players: Array[AudioStreamPlayer3D] = []
	var base_pitch: Array[float] = []
	var base_volume: Array[float] = []
	var cooldown: float = 0.0
	var pitch_jitter: float = 0.0
	var force_loop: int = -1        # -1 авто, 0 нет, 1 да
	var last_play: float = -1000.0
	var cursor: int = 0
	var rng := RandomNumberGenerator.new()

	func _init() -> void:
		rng.randomize()

	func primary() -> AudioStreamPlayer3D:
		return players[0] if not players.is_empty() else null


func _init(owner_node: Node, container: Node = null) -> void:
	_owner = owner_node
	if container != null:
		scan(container)
	else:
		push_warning("AudioComponent: контейнер звука не найден у %s" % owner_node.name)


# ─── РЕГИСТРАЦИЯ ───

func scan(container: Node) -> void:
	for child in container.get_children():
		if child is AudioStreamPlayer3D:
			register(_id_from_name(child.name), child as AudioStreamPlayer3D)
		elif child.get_child_count() > 0:
			scan(child)
	if _cues.is_empty():
		push_warning("AudioComponent: в '%s' нет AudioStreamPlayer3D" % container.name)


func register(id: StringName, player: AudioStreamPlayer3D,
		cooldown: float = 0.0, pitch_jitter: float = 0.0) -> void:
	if player == null:
		return
	var cue: _Cue = _cues.get(id, null)
	if cue == null:
		cue = _Cue.new()
		cue.id = id
		_cues[id] = cue

	cue.players.append(player)
	cue.base_pitch.append(player.pitch_scale)
	cue.base_volume.append(player.volume_db)
	cue.cooldown = float(player.get_meta("cooldown", cooldown))
	cue.pitch_jitter = float(player.get_meta("pitch_jitter", pitch_jitter))
	if player.has_meta("loop"):
		cue.force_loop = 1 if bool(player.get_meta("loop")) else 0


func has_cue(id: StringName) -> bool:
	return _cues.has(id)


func set_cooldown(id: StringName, value: float) -> void:
	var cue: _Cue = _cues.get(id, null)
	if cue != null:
		cue.cooldown = value


func set_pitch_jitter(id: StringName, value: float) -> void:
	var cue: _Cue = _cues.get(id, null)
	if cue != null:
		cue.pitch_jitter = value


# ─── ПРОИГРЫВАНИЕ ───

## Разовый звук. Не перезапускает уже играющий, если max_polyphony = 1
## и звук ещё звучит — для шагов это нормально, для выстрелов поставь
## max_polyphony = 3 в инспекторе.
func play(id: StringName, volume_offset_db: float = 0.0) -> void:
	var cue: _Cue = _cues.get(id, null)
	if cue == null or _muted:
		return

	var now := Time.get_ticks_msec() * 0.001
	if now - cue.last_play < cue.cooldown:
		return
	cue.last_play = now

	var idx := cue.cursor % cue.players.size()
	cue.cursor += 1
	var p := cue.players[idx]
	if p == null or p.stream == null:
		return

	var pitch := cue.base_pitch[idx]
	if cue.pitch_jitter > 0.0:
		pitch *= 1.0 + cue.rng.randf_range(-cue.pitch_jitter, cue.pitch_jitter)
	p.pitch_scale = pitch
	p.volume_db = cue.base_volume[idx] + volume_offset_db + _master_db
	p.play()
	sound_played.emit(id)


## Зацикленный звук: запускается ОДИН раз и не перезапускается, пока играет.
func loop(id: StringName) -> void:
	var cue: _Cue = _cues.get(id, null)
	if cue == null or _muted:
		return
	var p := cue.primary()
	if p == null or p.stream == null or p.playing:
		return
	p.pitch_scale = cue.base_pitch[0]
	p.volume_db = cue.base_volume[0] + _master_db
	p.play()
	sound_played.emit(id)


func stop(id: StringName) -> void:
	var cue: _Cue = _cues.get(id, null)
	if cue == null:
		return
	for p in cue.players:
		if p.playing:
			p.stop()
			sound_stopped.emit(id)


func stop_all() -> void:
	for id in _cues.keys():
		stop(id)


func is_playing(id: StringName) -> bool:
	var cue: _Cue = _cues.get(id, null)
	if cue == null:
		return false
	for p in cue.players:
		if p.playing:
			return true
	return false


## Зациклен ли сам файл (по импорт-настройкам стрима).
func is_loop_stream(id: StringName) -> bool:
	var cue: _Cue = _cues.get(id, null)
	if cue == null:
		return false
	if cue.force_loop >= 0:
		return cue.force_loop == 1
	var p := cue.primary()
	return p != null and _stream_loops(p.stream)


# ─── ОБЩИЕ НАСТРОЙКИ ───

func configure_3d(unit_size: float, max_distance: float,
		attenuation: AudioStreamPlayer3D.AttenuationModel =
		AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE) -> void:
	for id in _cues.keys():
		var cue: _Cue = _cues[id]
		for p in cue.players:
			if p.has_meta("custom_3d") and bool(p.get_meta("custom_3d")):
				continue
			p.unit_size = unit_size
			p.max_distance = max_distance
			p.attenuation_model = attenuation


func set_bus(bus_name: StringName) -> void:
	for id in _cues.keys():
		var cue: _Cue = _cues[id]
		for p in cue.players:
			p.bus = bus_name


func set_muted(value: bool) -> void:
	_muted = value
	if value:
		stop_all()


func set_master_volume_db(value: float) -> void:
	_master_db = value


# ─── ВНУТРЕННЕЕ ───

func _id_from_name(node_name: StringName) -> StringName:
	var s := String(node_name).to_lower()
	for suffix in _SUFFIXES:
		if s.ends_with(suffix):
			s = s.substr(0, s.length() - suffix.length())
			break
	return StringName(s)


func _stream_loops(s: AudioStream) -> bool:
	if s is AudioStreamWAV:
		return (s as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	if s is AudioStreamOggVorbis:
		return (s as AudioStreamOggVorbis).loop
	if s is AudioStreamMP3:
		return (s as AudioStreamMP3).loop
	return false

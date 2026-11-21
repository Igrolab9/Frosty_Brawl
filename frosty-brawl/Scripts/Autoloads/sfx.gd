extends Node
## Одноразовые звуки в мире. Живут отдельно от источника,
## поэтому переживают queue_free() снежка, ловушки, буста.

const POOL_SIZE: int = 24
const SFX_BUS: StringName = &"SFX"

## id -> путь. Через RPC летит только id, не сам файл.
const PATHS: Dictionary = {
	&"snow_hit": "res://Sounds/Common_sounds/Snowball_on_target.mp3"
}

var _pool: Array[AudioStreamPlayer3D] = []
var _cache: Dictionary = {}
var _cursor: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.bus = SFX_BUS
		p.unit_size = 12.0
		p.max_distance = 45.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.panning_strength = 0.7
		add_child(p)
		_pool.append(p)


## Звук только у себя
func play(id: StringName, pos: Vector3, volume_db: float = 0.0, pitch_jitter: float = 0.08) -> void:
	var stream := _get_stream(id)
	if stream == null:
		return
	var p := _get_free_player()
	p.stream = stream
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## Звук у ВСЕХ в одной точке мира
func play_net(id: StringName, pos: Vector3, volume_db: float = 0.0) -> void:
	play(id, pos, volume_db)
	if multiplayer.get_peers().is_empty():
		return
	_rpc_play.rpc(id, pos, volume_db)


@rpc("any_peer", "call_remote", "reliable", 2)
func _rpc_play(id: StringName, pos: Vector3, volume_db: float) -> void:
	play(id, pos, volume_db)


func _get_free_player() -> AudioStreamPlayer3D:
	for p in _pool:
		if not p.playing:
			return p
	_cursor = (_cursor + 1) % _pool.size()   # все заняты — забираем по кругу
	var stolen := _pool[_cursor]
	stolen.stop()
	return stolen


func _get_stream(id: StringName) -> AudioStream:
	if _cache.has(id):
		return _cache[id]
	var path: String = PATHS.get(id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("Sfx: нет файла для id '%s'" % id)
		return null
	var s: AudioStream = load(path)
	_cache[id] = s
	return s

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F9:
		debug_test()


## Проверка "файл + вывод" БЕЗ 3D, БЕЗ пула, БЕЗ сети.
func debug_test(id: StringName = &"snow_hit") -> void:
	var s := _get_stream(id)
	print("[Sfx] TEST stream=", s, " len=", s.get_length() if s != null else -1.0)
	if s == null:
		return
	var p := AudioStreamPlayer.new()   # непозиционный — слышно всегда
	p.stream = s
	p.bus = &"Master"
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

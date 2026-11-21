class_name FootstepComponent
extends RefCounted
## Решает КОГДА звучат шаги. КАК звучат — забота AudioComponent.

enum Mode { AUTO, LOOP, STEPS }

var mode: Mode = Mode.AUTO
var cue: StringName = &"walk"
var step_interval: float = 0.35      # сек между шагами при полной скорости
var min_speed_ratio: float = 0.08

var _audio: AudioComponent
var _timer: float = 0.0
var _walking: bool = false


func _init(audio: AudioComponent, cue_id: StringName = &"walk") -> void:
	_audio = audio
	cue = cue_id


func update(delta: float, is_moving: bool, is_airborne: bool, speed_ratio: float = 1.0) -> void:
	if _audio == null or not _audio.has_cue(cue):
		return

	var walking := is_moving and not is_airborne and speed_ratio > min_speed_ratio

	if walking != _walking:
		_walking = walking
		_timer = 0.0                       # первый шаг — сразу при старте движения
		if not walking and _is_loop():
			_audio.stop(cue)

	if not walking:
		return

	if _is_loop():
		_audio.loop(cue)                   # внутри защита от перезапуска
		return

	_timer -= delta
	if _timer <= 0.0:
		_timer = step_interval / clampf(speed_ratio, 0.4, 2.0)
		_audio.play(cue)


func stop() -> void:
	_walking = false
	_timer = 0.0
	if _audio != null:
		_audio.stop(cue)


func _is_loop() -> bool:
	match mode:
		Mode.LOOP:
			return true
		Mode.STEPS:
			return false
	return _audio.is_loop_stream(cue)

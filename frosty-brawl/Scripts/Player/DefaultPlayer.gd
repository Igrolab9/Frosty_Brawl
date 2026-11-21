class_name Player
extends CharacterBody3D

@export var move_speed: float = 10.0
@export var jump_force: float = 7.0
@export var player_health: float = 10.0
@export var throw_socket_path: NodePath

# 🆕 Флаг роли: true = бот, false = человек (управляется через CharacterSpawner)
@export var is_bot: bool = false

@export_group("Audio")
@export var audio_container_path: NodePath = ^"Audio"
@export var audio_bus: StringName = &"Master"
@export var apply_3d_audio_settings: bool = true
@export var audio_unit_size: float = 12.0
@export var audio_max_distance: float = 45.0

@export_group("Footsteps")
@export var footstep_mode: FootstepComponent.Mode = FootstepComponent.Mode.AUTO
@export var step_interval: float = 0.35
@export_range(0.0, 0.3) var step_pitch_jitter: float = 0.08

var _movement: MovementComponent
var _bot_movement: BotMovementComponent # 🆕 Компонент движения для бота
var _animation: AnimationComponent
var _snowball_spawner: SnowballSpawnerComponent
var _player_health: HealthComponent
var _health_ui: HealthUIComponent
var _audio: AudioComponent
var _footsteps: FootstepComponent
var _throw_socket: Node3D

var _is_dead: bool = false
var _last_health: float = -1.0
var _prev_airborne: bool = false

# ─── Реплицированное состояние локомоции ───
var _net_is_moving: bool = false
var _net_is_airborne: bool = false
var _sent_moving: bool = false
var _sent_airborne: bool = false
var _sent_dead: bool = false

@onready var camera: Camera3D = $Camera3D
@onready var health_slider: Slider = $CanvasLayer/Health_slider
@onready var health_label: Label = $CanvasLayer/Health_label


func _ready() -> void:
	var animator := _find_animator(self)
	assert(animator != null, "Player: внутри модели нет CharacterAnimator!")

	# 🆕 ИНИЦИАЛИЗАЦИЯ В ЗАВИСИМОСТИ ОТ РОЛИ
	if is_bot:
		_bot_movement = BotMovementComponent.new(self)
		# Ботам не нужна активная камера и видимый UI
		if camera:
			camera.current = false
		$CanvasLayer.visible = false
	else:
		_movement = MovementComponent.new(self, camera)
		# HUD и камера видны только у локального игрока-человека
		$CanvasLayer.visible = is_multiplayer_authority()
		if camera:
			camera.current = is_multiplayer_authority()

	_animation = AnimationComponent.new(animator)

	# ─── ЗВУК ───
	_audio = AudioComponent.new(self, get_node_or_null(audio_container_path))
	_audio.set_bus(audio_bus)
	if apply_3d_audio_settings:
		_audio.configure_3d(audio_unit_size, audio_max_distance)
	_audio.set_pitch_jitter(&"walk", step_pitch_jitter)
	_audio.set_cooldown(&"jump", 0.20)
	_audio.set_cooldown(&"land", 0.25)
	_audio.set_cooldown(&"hurt", 0.15)

	_footsteps = FootstepComponent.new(_audio, &"walk")
	_footsteps.mode = footstep_mode
	_footsteps.step_interval = step_interval

	# ─── Здоровье ───
	_player_health = HealthComponent.new(self, player_health)
	_player_health.health_changed.connect(_on_health_changed)
	_player_health.died.connect(_on_died)

	_throw_socket = _resolve_throw_socket()
	assert(_throw_socket != null, "В Player.gd: throw_socket не найден! Проверь путь $...")

	_snowball_spawner = SnowballSpawnerComponent.new(self, camera, _throw_socket)

	_health_ui = HealthUIComponent.new(health_slider, health_label)
	_health_ui.bind(_player_health)

	add_to_group(&"damageable")


func _physics_process(delta: float) -> void:
	if is_bot and not is_multiplayer_authority():
		print("⚠️ Внимание: Я бот, но у меня НЕТ сетевого авторитета! Движение заблокировано.")
	
	# ── 1. Симуляция: только у владельца (для ботов владельцем будет хост/сервер) ──
	if is_multiplayer_authority():
		if _is_dead:
			if not is_on_floor():
				velocity += get_gravity() * delta
				move_and_slide()
		else:
			# 🆕 Разделение логики обновления движения
			if is_bot:
				_bot_movement.update(delta, move_speed, jump_force)
				# Позже здесь можно добавить: _bot_attack()
			else:
				_movement.update(delta, move_speed, jump_force)
				_attack()

		_broadcast_locomotion()

	# ── 2. Визуал и звук: у ВСЕХ, по реплицированным флагам (работает и для ботов!) ──
	_animation.update(_net_is_airborne, _net_is_moving)

	var speed_ratio := 1.0
	if is_multiplayer_authority():
		speed_ratio = Vector2(velocity.x, velocity.z).length() / maxf(move_speed, 0.01)
	_footsteps.update(delta, _net_is_moving, _net_is_airborne, speed_ratio)

	if _net_is_airborne != _prev_airborne:
		_prev_airborne = _net_is_airborne
		if not _is_dead:
			_audio.play(&"jump" if _net_is_airborne else &"land")


func get_audio() -> AudioComponent:
	return _audio


# ─── СЕТЬ ───

func _broadcast_locomotion() -> void:
	# 🆕 БЕЗОПАСНОЕ ПОЛУЧЕНИЕ СОСТОЯНИЯ из активного компонента
	var current_is_moving := false
	var current_is_jump := false
	
	if is_bot and _bot_movement != null:
		current_is_moving = _bot_movement.is_moving
		current_is_jump = _bot_movement.is_jump
	elif not is_bot and _movement != null:
		current_is_moving = _movement.is_moving
		current_is_jump = _movement.is_jump

	var moving := current_is_moving and not _is_dead
	var airborne := current_is_jump

	if moving == _sent_moving and airborne == _sent_airborne and _is_dead == _sent_dead:
		return

	_sent_moving = moving
	_sent_airborne = airborne
	_sent_dead = _is_dead

	_net_is_moving = moving
	_net_is_airborne = airborne
	_rpc_locomotion.rpc(moving, airborne, _is_dead)


@rpc("authority", "call_remote", "reliable", 2)
func _rpc_locomotion(moving: bool, airborne: bool, dead: bool) -> void:
	_net_is_moving = moving
	_net_is_airborne = airborne
	if dead:
		_on_died()


func _play_sound_net(id: StringName) -> void:
	_audio.play(id)
	if is_multiplayer_authority() and multiplayer.get_peers().size() > 0:
		_rpc_sound.rpc(id)


@rpc("authority", "call_remote", "reliable", 2)
func _rpc_sound(id: StringName) -> void:
	_audio.play(id)


func _attack() -> void:
	if Input.is_action_just_pressed("ui_throw"):
		_animation.play_throw()
		_snowball_spawner.spawn()
		_play_sound_net(&"throw")


# ─── ЗДОРОВЬЕ ───

@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: float) -> void:
	if not is_multiplayer_authority():
		return
	if _is_dead:
		return
	_player_health.take_damage(amount)


func _on_health_changed(current: float, max_health: float) -> void:
	if _last_health >= 0.0 and current < _last_health:
		_play_sound_net(&"hurt")
	_last_health = current
	print("Здоровье изменилось: ", current, " / ", max_health)


func _on_died() -> void:
	if _is_dead:
		return
	_is_dead = true
	print("Персонаж ", name, " погиб!")

	_animation.play_death()
	_footsteps.stop()
	_audio.stop_all()
	_audio.play(&"death")

	$CollisionShape3D.set_deferred("disabled", true)


# ─── ВСПОМОГАТЕЛЬНЫЕ ───

func _find_animator(node: Node) -> CharacterAnimator:
	for child in node.get_children():
		if child is CharacterAnimator:
			return child
		var found := _find_animator(child)
		if found != null:
			return found
	return null


func _resolve_throw_socket() -> Node3D:
	if not throw_socket_path.is_empty():
		var explicit := get_node_or_null(throw_socket_path)
		if explicit is Node3D:
			return explicit

	var named := find_child("ThrowSocket", true, false)
	if named is Node3D:
		return named

	var slot := find_child("handslot_r", true, false)
	if slot is Node3D:
		return slot

	return null

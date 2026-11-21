# Scripts/Components/SnowballSpawnerComponent.gd
class_name SnowballSpawnerComponent
extends RefCounted

const SNOWBALL_SCENE := preload("res://Scenes/Characters/snow_ball.tscn")

var _owner: CharacterBody3D
var _camera: Camera3D
var _throw_socket: Node3D  # ← точка в правой руке

@export var throw_force: float = 50.0
@export var hand_forward_offset: float = 0.25  # вынос вперёд от руки, чтобы не задевать её

# --- НОВОЕ: Настройка кулдауна ---
@export var cooldown_seconds: float = 1.3
var _last_spawn_time: float = 0.0

func _init(owner: CharacterBody3D, camera: Camera3D, throw_socket: Node3D) -> void:
	_owner = owner
	_camera = camera
	_throw_socket = throw_socket
	
	assert(_throw_socket != null, "SnowballSpawnerComponent: throw_socket равен null! Проверь путь в Player.gd")

func spawn() -> void:
	if not _owner.is_multiplayer_authority():
		return

	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - _last_spawn_time < cooldown_seconds:
		return

	_last_spawn_time = current_time

	await _owner.get_tree().create_timer(0.6).timeout

	if not is_instance_valid(_owner) or not is_instance_valid(_throw_socket):
		return

	var snowball: RigidBody3D = SNOWBALL_SCENE.instantiate()
	# ← НОВОЕ: запоминаем, кто бросил (для статистики).
	# Через set(), т.к. переменная объявлена в скрипте снежка, а тип тут RigidBody3D.
	snowball.set(&"thrower_key", _owner.name)
	snowball.scale = Vector3(0.25, 0.25, 0.25)

	snowball.contact_monitor = true
	snowball.max_contacts_reported = 4
	
	# ОТЛАДКА: подключаем сигнал с отладочным выводом
	snowball.body_entered.connect(func(body):
		_on_snowball_hit(body, snowball)
	)

	snowball.gravity_scale = 1.0
	snowball.linear_damp = 0.4

	_owner.get_tree().root.add_child(snowball)
	BattleStats.report_throw(_owner.name)  # ← НОВОЕ: +1 бросок (уже после кулдауна и проверок)

	var direction := -_camera.global_basis.z
	var throw_direction := (direction + Vector3.UP * 0.5).normalized()
	
	snowball.global_position = _throw_socket.global_position + throw_direction * hand_forward_offset
	snowball.add_collision_exception_with(_owner)
	snowball.apply_central_impulse(throw_direction * throw_force)

func _on_snowball_hit(body: Node3D, snowball: RigidBody3D) -> void:
	if not is_instance_valid(snowball):
		return
	if body.is_in_group("snowball"):
		return
	if snowball.get_meta("_age", 0.0) < 0.05:  # игнор первых 50 мс
		return
	snowball.queue_free()

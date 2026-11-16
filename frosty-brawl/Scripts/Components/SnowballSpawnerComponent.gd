# Scripts/Components/SnowballSpawnerComponent.gd
class_name SnowballSpawnerComponent
extends RefCounted

const SNOWBALL_SCENE := preload("res://Scenes/Characters/snow_ball.tscn")

var _owner: CharacterBody3D
var _camera: Camera3D
var _throw_socket: Node3D  # ← точка в правой руке

@export var throw_force: float = 25.0
@export var hand_forward_offset: float = 0.3  # вынос вперёд от руки, чтобы не задевать её

func _init(owner: CharacterBody3D, camera: Camera3D, throw_socket: Node3D) -> void:
	_owner = owner
	_camera = camera
	_throw_socket = throw_socket
	
	# Эта строка остановит игру с понятной ошибкой, если сокет не найден
	assert(_throw_socket != null, "SnowballSpawnerComponent: throw_socket равен null! Проверь путь в Player.gd")

func spawn() -> void:
	if not _owner.is_multiplayer_authority():
		return

	var snowball: RigidBody3D = SNOWBALL_SCENE.instantiate()
	snowball.scale = Vector3(0.25, 0.25, 0.25)  # scale локальный — до add_child можно

	# --- Детекция столкновений ---
	snowball.contact_monitor = true
	snowball.max_contacts_reported = 4
	snowball.body_entered.connect(_on_snowball_hit.bind(snowball))

	# 1. СНАЧАЛА в дерево — без этого global_position не работает
	_owner.get_tree().root.add_child(snowball)

	# 2. Теперь ставим мировую позицию из руки
	var direction := -_camera.global_basis.z
	snowball.global_position = _throw_socket.global_position + direction * hand_forward_offset

	# 3. Исключаем столкновение с бросающим (оба уже в дереве — иначе исключение не применится)
	snowball.add_collision_exception_with(_owner)

	# 4. Полёт
	snowball.apply_central_impulse(direction * throw_force)

func _on_snowball_hit(body: Node3D, snowball: RigidBody3D) -> void:
	if not is_instance_valid(snowball):
		return
	if body.is_in_group("snowball"):
		return
	if snowball.get_meta("_age", 0.0) < 0.05:  # игнор первых 50 мс
		return
	snowball.queue_free()

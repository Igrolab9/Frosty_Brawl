class_name Player
extends CharacterBody3D

@export var move_speed: float = 10.0
@export var jump_force: float = 7.0
@export var throw_socket_path: NodePath

var _movement: MovementComponent
var _animation: AnimationComponent
var _snowball_spawner: SnowballSpawnerComponent
var _throw_socket: Node3D

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	var animator := _find_animator(self)
	assert(animator != null, "Player: внутри модели нет CharacterAnimator!")

	_movement = MovementComponent.new(self, camera)
	_animation = AnimationComponent.new(animator)
	
	_throw_socket = _resolve_throw_socket()	
	# ПРОВЕРКА: раскомментируй следующую строку на время, чтобы убедиться, что сокет найден
	assert(_throw_socket != null, "В Player.gd: throw_socket не найден! Проверь путь $...")
	_snowball_spawner = SnowballSpawnerComponent.new(self, camera, _throw_socket)

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_movement.update(delta, move_speed, jump_force)
		_attack()
	_animation.update(_movement.is_jump, _movement.is_moving)

func _attack()-> void:
	if Input.is_action_just_pressed("ui_throw"):
			_animation.play_throw()
			_snowball_spawner.spawn()

func _find_animator(node: Node) -> CharacterAnimator:
	for child in node.get_children():
		if child is CharacterAnimator:
			return child
		var found := _find_animator(child)
		if found != null:
			return found
	return null

# ─── Универсальный поиск: 3 уровня запасных ───
func _resolve_throw_socket() -> Node3D:
	# 1. Явный путь из инспектора (если задан)
	if not throw_socket_path.is_empty():
		var explicit := get_node_or_null(throw_socket_path)
		if explicit is Node3D:
			return explicit

	# 2. Именованный сокет ThrowSocket (если захочешь точную подстройку)
	var named := find_child("ThrowSocket", true, false)
	if named is Node3D:
		return named

	# 3. Стандартный слот правой руки — есть у ВСЕХ моделей из ассета
	var slot := find_child("handslot_r", true, false)
	if slot is Node3D:
		return slot

	return null

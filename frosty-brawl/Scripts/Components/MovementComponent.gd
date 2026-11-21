class_name MovementComponent
extends RefCounted

var is_jump: bool = false
var is_moving: bool = false

# Настройки поворота за курсором
var look_at_cursor: bool = true
var rotation_speed: float = 1.0  # Чем больше, тем резче поворот (5-15 оптимально)

var _body: CharacterBody3D
var _camera: Camera3D

func _init(body: CharacterBody3D, camera: Camera3D = null) -> void:
	_body = body
	_camera = camera

func set_camera(camera: Camera3D) -> void:
	_camera = camera

func update(delta: float, speed: float, jump_velocity: float) -> void:
	# Гравитация
	if not _body.is_on_floor():
		_body.velocity += _body.get_gravity() * delta

	# Прыжок
	if Input.is_action_just_pressed("ui_accept") and _body.is_on_floor():
		_body.velocity.y = jump_velocity

	# Направление движения
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (_body.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction != Vector3.ZERO:
		_body.velocity.x = -direction.x * speed
		_body.velocity.z = -direction.z * speed
	else:
		_body.velocity.x = move_toward(_body.velocity.x, 0.0, speed)
		_body.velocity.z = move_toward(_body.velocity.z, 0.0, speed)

	# Поворот за курсором мыши
	if look_at_cursor and _camera != null:
		_rotate_toward_cursor(delta)

	_body.move_and_slide()

	is_jump = not _body.is_on_floor()
	is_moving = direction != Vector3.ZERO


func _rotate_toward_cursor(delta: float) -> void:
	var mouse_pos := _body.get_viewport().get_mouse_position()
	var distance := _camera.global_position.distance_to(_body.global_position)
	var target_world_pos := _camera.project_position(mouse_pos, distance)

	var to_target := target_world_pos - _body.global_position
	to_target.y = 0.0

	if to_target.length_squared() > 0.001:
		# Целевой угол
		var target_angle := atan2(to_target.x, to_target.z)
		# Текущий угол
		var current_angle := _body.rotation.y
		
		# Плавный поворот через lerp_angle
		# rotation_speed = 10.0 даёт умеренную плавность
		# rotation_speed = 5.0 — очень плавно
		# rotation_speed = 15.0 — почти мгновенно
		_body.rotation.y = lerp_angle(current_angle, target_angle, rotation_speed * delta)

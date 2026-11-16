class_name MovementComponent
extends RefCounted

var is_jump: bool = false
var is_moving: bool = false

var _body: CharacterBody3D

func _init(body: CharacterBody3D) -> void:
	_body = body

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

	_body.move_and_slide()

	# Только теперь is_on_floor() актуален для этого кадра
	is_jump = not _body.is_on_floor()
	is_moving = direction != Vector3.ZERO

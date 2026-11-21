class_name BotMovementComponent
extends RefCounted

var is_jump: bool = false
var is_moving: bool = false

var wander_radius: float = 80.0
var min_wait_time: float = 1.0
var max_wait_time: float = 3.0
var arrival_threshold: float = 1.5

var _body: CharacterBody3D
var _nav_agent: NavigationAgent3D
var _spawn_position: Vector3
var _target_position: Vector3
var _wait_timer: float = 0.0
var _is_waiting: bool = false
var _is_initialized: bool = false

var _map_min: Vector3 = Vector3(-100, 0, -100)
var _map_max: Vector3 = Vector3(100, 0, 100)

func _init(body: CharacterBody3D) -> void:
	_body = body

func update(delta: float, speed: float, jump_velocity: float) -> void:
	if not _is_initialized:
		_setup_navigation()
		_is_initialized = true
		print("🤖 Бот инициализирован в точке: ", _spawn_position)

	if not _body.is_on_floor():
		_body.velocity += _body.get_gravity() * delta

	if _is_waiting:
		_wait_timer -= delta
		if _wait_timer <= 0.0:
			_is_waiting = false
			_choose_new_target()
		
		_body.velocity.x = move_toward(_body.velocity.x, 0.0, speed)
		_body.velocity.z = move_toward(_body.velocity.z, 0.0, speed)
		is_moving = false
	else:
		if _nav_agent.is_navigation_finished():
			_is_waiting = true
			_wait_timer = randf_range(min_wait_time, max_wait_time)
			is_moving = false
		else:
			var next_position := _nav_agent.get_next_path_position()
			var direction := (_body.global_position.direction_to(next_position)).normalized()
			direction.y = 0.0
			
			var distance_to_target := _body.global_position.distance_to(_target_position)
			
			if distance_to_target <= arrival_threshold:
				_is_waiting = true
				_wait_timer = randf_range(min_wait_time, max_wait_time)
				is_moving = false
			else:
				_body.velocity.x = direction.x * speed
				_body.velocity.z = direction.z * speed
				is_moving = true
				
				var angle := atan2(direction.x, direction.z)
				_body.rotation.y = lerp_angle(_body.rotation.y, angle, 0.15)

	_body.move_and_slide()
	is_jump = not _body.is_on_floor()

func _setup_navigation() -> void:
	_nav_agent = NavigationAgent3D.new()
	_body.add_child(_nav_agent)
	
	_nav_agent.radius = 0.5
	_nav_agent.height = 1.8
	_nav_agent.max_speed = 10.0
	
	_spawn_position = _body.global_position
	_target_position = _spawn_position
	
	# 🆕 Откладываем выбор цели на следующий кадр, чтобы карта успела синхронизироваться
	call_deferred("_choose_new_target")

func _choose_new_target() -> void:
	var random_point := Vector3(
		randf_range(_map_min.x, _map_max.x),
		0.0,
		randf_range(_map_min.z, _map_max.z)
	)
	
	var nav_map := _nav_agent.get_navigation_map()
	var projected_point := NavigationServer3D.map_get_closest_point(nav_map, random_point)
	
	_target_position = projected_point
	_nav_agent.target_position = _target_position
	
	print("🎯 Бот выбрал цель: ", _target_position, " (расстояние от спавна: ", 
		  _spawn_position.distance_to(_target_position), ")")

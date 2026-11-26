class_name BotMovementComponent
extends RefCounted

# --- Настройки поведения (можно вынести в конфиг бота) ---
var wander_radius: float = 15.0       # Радиус блуждания от ТЕКУЩЕЙ позиции (делает движение естественным)
var min_wait_time: float = 1.0
var max_wait_time: float = 3.0
var arrival_threshold: float = 1.5

# --- Границы карты 85x85 (с небольшим запасом 2.5м от края, чтобы не упирать в стены) ---
var _map_min: Vector3 = Vector3(-40.0, 0.0, -40.0)
var _map_max: Vector3 = Vector3(40.0, 0.0, 40.0)

# --- Состояние ---
var is_jump: bool = false
var is_moving: bool = false 

var _body: CharacterBody3D
var _nav_agent: NavigationAgent3D
var _spawn_position: Vector3
var _target_position: Vector3

var _wait_timer: float = 0.0
var _is_waiting: bool = false
var _is_initialized: bool = false
var _nav_ready: bool = false

# --- Детекция застревания (Anti-Rails) ---
var _stuck_timer: float = 0.0
var _stuck_threshold: float = 2.5       # Если бот топчется на месте 2.5 сек, он меняет цель
var _last_position: Vector3 = Vector3.ZERO
var _min_move_distance: float = 0.5     # Минимальное расстояние, которое бот должен пройти, чтобы не считаться застрявшим

func _init(body: CharacterBody3D) -> void:
	_body = body

func update(delta: float, speed: float, jump_velocity: float) -> void:
	if not _is_initialized:
		_setup_navigation()
		_is_initialized = true
		_last_position = _body.global_position
		print("🤖 Бот инициализирован в точке: ", _spawn_position)

	if not _nav_ready:
		_check_navigation_ready()
		return

	# Гравитация
	if not _body.is_on_floor():
		_body.velocity += _body.get_gravity() * delta

	# Логика ожидания
	if _is_waiting:
		_wait_timer -= delta
		if _wait_timer <= 0.0:
			_is_waiting = false
			_choose_new_target()
		
		# Плавная остановка
		_body.velocity.x = move_toward(_body.velocity.x, 0.0, speed * delta * 5.0)
		_body.velocity.z = move_toward(_body.velocity.z, 0.0, speed * delta * 5.0)
		is_moving = false
	else:
		# 🆕 Детекция застревания
		if is_moving:
			if _body.global_position.distance_to(_last_position) < _min_move_distance:
				_stuck_timer += delta
				if _stuck_timer >= _stuck_threshold:
					print("⚠️ Бот застрял! Меняем цель.")
					_stuck_timer = 0.0
					_is_waiting = true
					_wait_timer = 0.5 # Короткая пауза перед новым выбором
					is_moving = false
			else:
				_stuck_timer = 0.0
				_last_position = _body.global_position

		# Логика навигации
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
				
				# Плавный поворот
				var angle := atan2(direction.x, direction.z)
				_body.rotation.y = lerp_angle(_body.rotation.y, angle, 10.0 * delta)

	_body.move_and_slide()
	is_jump = not _body.is_on_floor()

func _setup_navigation() -> void:
	_nav_agent = NavigationAgent3D.new()
	_body.add_child(_nav_agent)
	
	# Настройки агента под размер персонажа (подстрой под свою модель)
	_nav_agent.radius = 0.5
	_nav_agent.height = 1.8
	_nav_agent.max_speed = 10.0
	_nav_agent.path_desired_distance = 0.5
	_nav_agent.target_desired_distance = 0.5
	
	_spawn_position = _body.global_position
	_target_position = _spawn_position

func _check_navigation_ready() -> void:
	var nav_map := _nav_agent.get_navigation_map()
	if nav_map.is_valid():
		var iteration_id := NavigationServer3D.map_get_iteration_id(nav_map)
		if iteration_id > 0:
			_nav_ready = true
			_choose_new_target()
			print("✅ Навигация готова! Итерация: ", iteration_id)

func _choose_new_target() -> void:
	# 🆕 УМНЫЙ ВЫБОР ЦЕЛИ: Берем текущую позицию + случайное смещение в пределах wander_radius
	# Это предотвращает "телепортацию" взгляда бота на другой конец карты
	var random_offset := Vector3(
		randf_range(-wander_radius, wander_radius),
		0.0,
		randf_range(-wander_radius, wander_radius)
	)
	
	var desired_point := _body.global_position + random_offset
	
	# 🆕 Ограничиваем точку границами карты 85x85 (с запасом)
	desired_point.x = clamp(desired_point.x, _map_min.x, _map_max.x)
	desired_point.z = clamp(desired_point.z, _map_min.z, _map_max.z)
	
	var nav_map := _nav_agent.get_navigation_map()
	if nav_map.is_valid():
		# Проецируем точку на ближайшую поверхность NavMesh
		var projected_point := NavigationServer3D.map_get_closest_point(nav_map, desired_point)
		
		_target_position = projected_point
		_nav_agent.target_position = _target_position
		
		print("🎯 Бот выбрал локальную цель: ", _target_position, " (дистанция: ", 
			  _body.global_position.distance_to(_target_position), ")")
	else:
		print("❌ Ошибка: NavigationMap недействителен!")

# 🆕 Метод для принудительного прыжка (вызывается из главного класса-дирижера, если бот уперся в препятствие)
func try_jump(jump_velocity: float) -> void:
	if _body.is_on_floor():
		_body.velocity.y = jump_velocity
		print("⬆️ Бот выполняет прыжок!")

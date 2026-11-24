class_name HomingComponent
extends RefCounted
## Мягкое самонаведение снаряда: доворачивает вектор скорости к цели
## с ограниченной угловой скоростью, модуль скорости НЕ меняет.
## Владелец вызывает steer() из _integrate_forces().

var enabled: bool = true

var turn_rate_deg: float = 35.0      # «сила» наведения, град/с — главный параметр
var max_distance: float = 20.0       # радиус поиска цели, м
var cone_deg: float = 25.0           # конус захвата вокруг направления полёта
var start_delay: float = 0.1         # первые N секунд летим строго прямо
var stop_distance: float = 0.6       # ближе к цели доворот выключаем
var aim_height: float = 0.7          # целимся в «грудь», а не в ноги
var target_group: StringName = &"damageable"  # твоя существующая группа
var check_line_of_sight: bool = true
var los_mask: int = 1                # слой геометрии для луча видимости

var _filter: Callable                # игровые правила отбора цели (кто мне враг)
var _age: float = 0.0
var _target: Node3D = null


func _init(target_filter: Callable) -> void:
	_filter = target_filter


func steer(state: PhysicsDirectBodyState3D, self_rid: RID, tree: SceneTree) -> void:
	if not enabled:
		return
	_age += state.step
	if _age < start_delay:
		return

	var speed := state.linear_velocity.length()
	if speed < 0.5:
		return

	var origin := state.transform.origin
	var forward := state.linear_velocity / speed
	var space := state.get_space_state()

	if not _target_still_valid(origin, forward, self_rid, space):
		_target = _acquire_target(origin, forward, tree, self_rid, space)
	if _target == null:
		return

	var to_target := _aim_point(_target) - origin
	var dist := to_target.length()
	if dist < stop_distance:
		return

	var desired := to_target / dist
	var angle := forward.angle_to(desired)
	var axis := forward.cross(desired)
	if angle < 0.001 or axis.length_squared() < 1e-10:
		return

	# Ключевая строка: доворот не быстрее turn_rate_deg за секунду.
	var max_step := deg_to_rad(turn_rate_deg) * state.step
	state.linear_velocity = forward.rotated(axis.normalized(), minf(angle, max_step)) * speed


func _aim_point(body: Node3D) -> Vector3:
	return body.global_position + Vector3.UP * aim_height


func _target_still_valid(origin: Vector3, forward: Vector3, self_rid: RID,
		space: PhysicsDirectSpaceState3D) -> bool:
	if not is_instance_valid(_target) or not _filter.call(_target):
		return false
	var to_target := _aim_point(_target) - origin
	var dist := to_target.length()
	if dist > max_distance or dist < 0.001:
		return false
	# Конус удержания шире конуса захвата — цель не «отваливается» на дуге полёта.
	if forward.dot(to_target / dist) < cos(deg_to_rad(cone_deg * 1.5)):
		return false
	return _has_line_of_sight(origin, _target, self_rid, space)


func _acquire_target(origin: Vector3, forward: Vector3, tree: SceneTree,
		self_rid: RID, space: PhysicsDirectSpaceState3D) -> Node3D:
	var best: Node3D = null
	var best_dot := -1.0
	var cone_cos := cos(deg_to_rad(cone_deg))
	for node in tree.get_nodes_in_group(target_group):
		var body := node as Node3D
		if body == null or not _filter.call(body):
			continue
		var to_target := _aim_point(body) - origin
		var dist := to_target.length()
		if dist > max_distance or dist < stop_distance:
			continue
		# Из подходящих берём того, кто ближе к направлению броска (к прицелу).
		var d := forward.dot(to_target / dist)
		if d < cone_cos or d <= best_dot:
			continue
		if not _has_line_of_sight(origin, body, self_rid, space):
			continue
		best = body
		best_dot = d
	return best


func _has_line_of_sight(origin: Vector3, target: Node3D, self_rid: RID,
		space: PhysicsDirectSpaceState3D) -> bool:
	if not check_line_of_sight:
		return true
	var query := PhysicsRayQueryParameters3D.create(
		origin, _aim_point(target), los_mask, [self_rid])
	var hit := space.intersect_ray(query)
	# Луч упёрся в саму цель — это нормально, считаем видимой.
	return hit.is_empty() or hit.collider == target

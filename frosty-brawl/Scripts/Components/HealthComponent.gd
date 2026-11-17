class_name HealthComponent
extends RefCounted

signal health_changed(current_health: float, max_health: float)
signal died

var _current_health: float
var _max_health: float
var _owner: Node3D

func _init(owner: Node3D, max_health: float) -> void:
	_owner = owner
	_max_health = max_health
	_current_health = max_health

func take_damage(amount: float) -> void:
	if _current_health <= 0.0:
		return

	_current_health -= amount
	_current_health = max(0.0, _current_health) # Гарантируем, что здоровье не уйдет в минус
	
	health_changed.emit(_current_health, _max_health)

	if _current_health == 0.0:
		died.emit()

func reset(new_max_health: float = -1.0) -> void:
	# Исправлено: обновляем макс. здоровье, только если передано корректное положительное значение
	if new_max_health > 0.0:
		_max_health = new_max_health
	
	_current_health = _max_health
	health_changed.emit(_current_health, _max_health)

func get_health() -> float:
	return _current_health

func get_max_health() -> float:
	return _max_health

func is_alive() -> bool:
	# Исправлено: жив, если здоровье больше 0
	return _current_health > 0.0

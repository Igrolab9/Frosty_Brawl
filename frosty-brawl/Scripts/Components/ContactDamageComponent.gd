class_name ContactDamageComponent
extends RefCounted
## Наносит урон телам из группы "damageable", пока они в зоне.
## Не знает ничего про Area3D, ловушки и мультиплеер — чистая логика (SRP).

signal damage_dealt(target: Node3D, amount: float)

const DAMAGEABLE_GROUP: StringName = &"damageable"

var _damage_amount: float
var _tick_interval: float
var _bodies_inside: Array[Node3D] = []
var _cooldowns: Dictionary = {} # Node3D -> секунд до следующего тика

func _init(damage_amount: float, tick_interval: float = 1.0) -> void:
	_damage_amount = damage_amount
	_tick_interval = maxf(tick_interval, 0.0)

func add_body(body: Node3D) -> void:
	if not _is_damageable(body) or _bodies_inside.has(body):
		return
	_bodies_inside.append(body)
	_cooldowns[body] = 0.0 # первый урон — сразу при входе в зону

func remove_body(body: Node3D) -> void:
	_bodies_inside.erase(body)
	_cooldowns.erase(body)

func update(delta: float) -> void:
	for body in _bodies_inside.duplicate():
		if not is_instance_valid(body): # цель умерла и удалилась
			remove_body(body)
			continue
		_cooldowns[body] -= delta
		
		if _cooldowns[body] <= 0.0:
			_cooldowns[body] = _tick_interval
			body.take_damage(_damage_amount)
			damage_dealt.emit(body, _damage_amount)

func _is_damageable(body: Node3D) -> bool:
	return body.is_in_group(DAMAGEABLE_GROUP) and body.has_method(&"take_damage")

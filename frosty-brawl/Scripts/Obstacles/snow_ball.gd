extends RigidBody3D

@export var damage_amount: float = 1.0

var _spawn_time: float

func _ready() -> void:
	_spawn_time = Time.get_ticks_msec() / 1000.0

	# Обязательно для body_entered у RigidBody3D
	contact_monitor = true
	max_contacts_reported = 4

	# bind(self) дописывает снежок вторым аргументом:
	# сигнал emit(body) -> вызов _on_snowball_hit(body, self)
	body_entered.connect(_on_snowball_hit.bind(self))

	get_tree().create_timer(5.0).timeout.connect(queue_free)

func _on_snowball_hit(body: Node, snowball: RigidBody3D) -> void:
	if not is_instance_valid(snowball):
		return
	if body.is_in_group("snowball"):
		return

	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - _spawn_time < 0.05:
		return

	if not body.has_method("take_damage"):
		snowball.queue_free()
		return

	body.take_damage(damage_amount)
	snowball.queue_free()

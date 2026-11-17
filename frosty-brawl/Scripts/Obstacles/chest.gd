extends StaticBody3D
class_name Chest

var _health: HealthComponent
var _is_destroyed: bool = false

@export var chest_health: float = 5.0  # Сундук выдержит 5 ударов

func _ready() -> void:
	# Создаем компонент здоровья
	_health = HealthComponent.new(self, chest_health)
	
	# Подключаем сигналы
	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_on_died)

# Этот метод будет вызывать снежок при попадании
func take_damage(amount: float) -> void:
	if _is_destroyed:
		return
	
	print("[CHEST] Получен урон: ", amount)
	_health.take_damage(amount)

func _on_health_changed(current: float, max: float) -> void:
	print("[CHEST] Здоровье: ", current, " / ", max)

func _on_died() -> void:
	_is_destroyed = true
	print("[CHEST] Сундук разрушен!")
	
	# Отключаем коллизию
	$CollisionShape3D.set_deferred("disabled", true)
	
	# Через 2 секунды удаляем сундук полностью
	get_tree().create_timer(2.0).timeout.connect(queue_free)

class_name Player
extends CharacterBody3D

@export var move_speed: float = 10.0
@export var jump_force: float = 7.0
@export var player_health: float = 10.0
@export var throw_socket_path: NodePath

var _movement: MovementComponent
var _animation: AnimationComponent
var _snowball_spawner: SnowballSpawnerComponent
var _player_health: HealthComponent
var _health_ui: HealthUIComponent
var _throw_socket: Node3D

var _is_dead: bool = false # Флаг состояния смерти

@onready var camera: Camera3D = $Camera3D
@onready var health_slider: Slider = $CanvasLayer/Health_slider
@onready var health_label : Label = $CanvasLayer/Health_label

func _ready() -> void:
	var animator := _find_animator(self)
	assert(animator != null, "Player: внутри модели нет CharacterAnimator!")

	_movement = MovementComponent.new(self, camera)
	_animation = AnimationComponent.new(animator)
	
	# 1. Создаем компонент здоровья
	_player_health = HealthComponent.new(self, player_health)
	
	# 2. ПОДКЛЮЧАЕМ СИГНАЛЫ компонента к методам игрока
	_player_health.health_changed.connect(_on_health_changed)
	_player_health.died.connect(_on_died)
	
	_throw_socket = _resolve_throw_socket()	
	assert(_throw_socket != null, "В Player.gd: throw_socket не найден! Проверь путь $...")
	
	_snowball_spawner = SnowballSpawnerComponent.new(self, camera, _throw_socket)
	
		# HUD виден только у локального игрока, у чужих — прячем весь CanvasLayer
	# (вместе с прицелом Sprite2D — он тоже не должен торчать на чужих экранах)
	$CanvasLayer.visible = is_multiplayer_authority()

	_health_ui = HealthUIComponent.new(health_slider, health_label)
	_health_ui.bind(_player_health)
	
	add_to_group(&"damageable")

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		if _is_dead:
			# Умер в прыжке — тело падает на землю, а не висит в воздухе
			if not is_on_floor():
				velocity += get_gravity() * delta
				move_and_slide()
		else:
			_movement.update(delta, move_speed, jump_force)
			_attack()

	_animation.update(_movement.is_jump if _movement else false, _movement.is_moving if _movement else false)

func _attack() -> void:
	if Input.is_action_just_pressed("ui_throw"):
		_animation.play_throw()
		_snowball_spawner.spawn()

# ─── ЛОГИКА ЗДОРОВЬЯ ───

# Этот метод будет вызывать снежок при попадании
# Было: @rpc("any_peer", "call_local")
# Стало: добавляем "reliable" для гарантированной доставки
@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: float) -> void:
	# Дополнительная защита: применяем урон ТОЛЬКО если мы авторитет этого Player
	# Это предотвращает читерство и рассинхрон
	if not is_multiplayer_authority():
		return
		
	if _is_dead:
		return
	
	_player_health.take_damage(amount)

func _on_health_changed(current: float, max: float) -> void:
	# ЗДЕСЬ БУДЕТ ЛОГИКА ОБНОВЛЕНИЯ UI (полоска здоровья)
	# Например: UI_Manager.update_health_bar(current, max)
	print("Здоровье изменилось: ", current, " / ", max)

func _on_died() -> void:
	if _is_dead:
		return # защита от повторного вызова
	_is_dead = true
	print("Игрок ", name, " погиб!")

	_animation.play_death()

	# Сквозь тело можно проходить. Бонус: ловушка получит body_exited
	# и перестанет тикать урон по трупу.
	$CollisionShape3D.set_deferred("disabled", true)

# ─── ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ (без изменений) ───

func _find_animator(node: Node) -> CharacterAnimator:
	for child in node.get_children():
		if child is CharacterAnimator:
			return child
		var found := _find_animator(child)
		if found != null:
			return found
	return null

func _resolve_throw_socket() -> Node3D:
	if not throw_socket_path.is_empty():
		var explicit := get_node_or_null(throw_socket_path)
		if explicit is Node3D:
			return explicit

	var named := find_child("ThrowSocket", true, false)
	if named is Node3D:
		return named

	var slot := find_child("handslot_r", true, false)
	if slot is Node3D:
		return slot

	return null

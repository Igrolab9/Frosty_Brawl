class_name Player
extends CharacterBody3D

@export var move_speed: float = 10.0
@export var jump_force: float = 7.0

var _movement: MovementComponent
var _animation: AnimationComponent

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	var animator := _find_animator(self)
	assert(animator != null, "Player: внутри модели нет CharacterAnimator! Открой сцену модели и прикрепи CharacterAnimator.gd к AnimationPlayer.")

	_movement = MovementComponent.new(self, camera)
	_animation = AnimationComponent.new(animator)

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_movement.update(delta, move_speed, jump_force)
		_attack()
	_animation.update(_movement.is_jump, _movement.is_moving)

func _attack()-> void:
	if Input.is_action_just_pressed("ui_throw"):
			_animation.play_throw()

func _find_animator(node: Node) -> CharacterAnimator:
	for child in node.get_children():
		if child is CharacterAnimator:
			return child
		var found := _find_animator(child)
		if found != null:
			return found
	return null

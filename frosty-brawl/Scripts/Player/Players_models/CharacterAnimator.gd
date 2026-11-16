class_name CharacterAnimator
extends AnimationPlayer

signal throw_finished

@export var anim_idle: StringName = &"Idle"
@export var anim_walk: StringName = &"Walking_A"
@export var anim_jump: StringName = &"Jump_Full_Long"
@export var anim_throw: StringName = &"Throw"

func _ready() -> void:
	get_animation(anim_idle).loop_mode = Animation.LOOP_LINEAR
	get_animation(anim_walk).loop_mode = Animation.LOOP_LINEAR
	animation_finished.connect(_on_animation_finished)

func play_idle() -> void:
	play(anim_idle)

func play_walk() -> void:
	play(anim_walk)

func play_jump() -> void:
	play(anim_jump)

func play_throw() -> void:
	play(anim_throw)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == anim_throw:
		throw_finished.emit()

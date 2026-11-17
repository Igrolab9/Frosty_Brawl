class_name CharacterAnimator
extends AnimationPlayer

signal throw_finished
signal death_finished # пригодится для респауна "после анимации"

@export var anim_idle: StringName = &"Idle"
@export var anim_walk: StringName = &"Walking_A"
@export var anim_jump: StringName = &"Jump_Full_Long"
@export var anim_throw: StringName = &"Throw"
@export var anim_death: StringName = &"Death_B"

func _ready() -> void:
	get_animation(anim_idle).loop_mode = Animation.LOOP_LINEAR
	get_animation(anim_walk).loop_mode = Animation.LOOP_LINEAR
	# Одноразовые клипы не должны	loop'иться, иначе *_finished никогда не сработает
	get_animation(anim_throw).loop_mode = Animation.LOOP_NONE
	get_animation(anim_death).loop_mode = Animation.LOOP_NONE
	animation_finished.connect(_on_animation_finished)

func play_idle() -> void:
	play(anim_idle)

func play_walk() -> void:
	play(anim_walk)

func play_jump() -> void:
	play(anim_jump)

func play_throw() -> void:
	play(anim_throw)
	
func play_death() -> void:
	play(anim_death)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == anim_throw:
		throw_finished.emit()
	elif anim_name == anim_death:
		death_finished.emit()

class_name AnimationComponent
extends RefCounted

enum State { IDLE, WALK, JUMP, THROW }

var _animator: CharacterAnimator
var _current_state: int = -1  # -1 = ещё ни одно состояние не применено
var _is_throwing: bool = false

func _init(animator: CharacterAnimator) -> void:
	_animator = animator
	_animator.throw_finished.connect(_on_throw_finished)

## Событие: вызывается снаружи в момент броска снежка
func play_throw() -> void:
	_is_throwing = true
	_current_state = State.THROW
	_animator.play_throw()

func update(is_jump: bool, is_moving: bool) -> void:
	if _is_throwing:
		return  # бросок важнее локомоции — ждём окончания клипа

	var new_state: State
	if is_jump:
		new_state = State.JUMP
	elif is_moving:
		new_state = State.WALK
	else:
		new_state = State.IDLE

	if new_state == _current_state:
		return
	_current_state = new_state

	match new_state:
		State.IDLE: _animator.play_idle()
		State.WALK: _animator.play_walk()
		State.JUMP: _animator.play_jump()

func _on_throw_finished() -> void:
	_is_throwing = false
	# _current_state остался THROW, поэтому следующий update()
	# гарантированно применит актуальное idle/walk/jump

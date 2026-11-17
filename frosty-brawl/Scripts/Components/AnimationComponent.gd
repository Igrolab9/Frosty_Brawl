class_name AnimationComponent
extends RefCounted

enum State { IDLE, WALK, JUMP, THROW, DEATH }

var _animator: CharacterAnimator
var _current_state: int = -1
var _is_throwing: bool = false
var _is_dead: bool = false

func _init(animator: CharacterAnimator) -> void:
	_animator = animator
	_animator.throw_finished.connect(_on_throw_finished)

func play_throw() -> void:
	if _is_dead:
		return # мёртвые не бросают
	_is_throwing = true
	_current_state = State.THROW
	_animator.play_throw()

## Смерть приоритетнее всего: прерывает и бросок, и локомоцию.
func play_death() -> void:
	if _is_dead:
		return
	_is_dead = true
	_is_throwing = false
	_current_state = State.DEATH
	_animator.play_death()

## Пригодится для респауна (симметрично HealthComponent.reset())
func reset() -> void:
	_is_dead = false
	_is_throwing = false
	_current_state = State.IDLE
	_animator.play_idle()

func update(is_jump: bool, is_moving: bool) -> void:
	if _is_dead or _is_throwing:
		return # смерть и бросок важнее локомоции

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

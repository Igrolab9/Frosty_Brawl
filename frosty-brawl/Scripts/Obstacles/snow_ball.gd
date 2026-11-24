extends RigidBody3D

@export var damage_amount: float = 1.0
@export var lifetime: float = 5.0
@export var grace_period: float = 0.05
@export var hit_sfx: StringName = &"snow_hit"
## false — снежок есть на всех пирах, каждый играет звук у себя (рекомендуется)
## true  — снежок есть только у бросившего, звук рассылается по RPC
@export var broadcast_sfx: bool = false
@export var debug_log: bool = true

@export_group("Homing")
@export var homing_enabled: bool = true
@export var homing_turn_rate_deg: float = 35.0
@export var homing_max_distance: float = 20.0
@export var homing_cone_deg: float = 25.0
@export var homing_start_delay: float = 0.1
@export var homing_aim_height: float = 0.7
@export var homing_check_los: bool = true
@export var homing_los_mask: int = 1

var _homing: HomingComponent = null

var thrower_key: StringName = &""  # ← НОВОЕ: имя узла бросившего (ставит спавнер)

var _spawn_time: float = 0.0
var _has_hit: bool = false


func _ready() -> void:
	_spawn_time = Time.get_ticks_msec() * 0.001

	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true

	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	
	_homing = HomingComponent.new(_is_homing_target)
	_homing.enabled = homing_enabled
	_homing.turn_rate_deg = homing_turn_rate_deg
	_homing.max_distance = homing_max_distance
	_homing.cone_deg = homing_cone_deg
	_homing.start_delay = homing_start_delay
	_homing.aim_height = homing_aim_height
	_homing.check_line_of_sight = homing_check_los
	_homing.los_mask = homing_los_mask


func _on_body_entered(body: Node) -> void:
	if _has_hit:
		return
	if body.is_in_group(&"snowball"):
		return
	if Time.get_ticks_msec() * 0.001 - _spawn_time < grace_period:
		return

	_has_hit = true

	var pos := global_position
	var i_am_owner := is_multiplayer_authority()

	if debug_log:
		print("[Snowball] hit=", body.name, " auth=", i_am_owner,
			" owner=", get_multiplayer_authority(),
			" my_id=", multiplayer.get_unique_id())

	# ── 1. ЗВУК. Первым делом, без сетевых условий. ──
	if broadcast_sfx:
		if i_am_owner:
			Sfx.play_net(hit_sfx, pos)   # чужие пиры получат по RPC, сами не играют
	else:
		Sfx.play(hit_sfx, pos)           # каждый пир играет свой контакт у себя

	# ── 2. УРОН. Только владелец и только по цели. ──
	if i_am_owner and body.has_method(&"take_damage"):
		_deal_damage(body)
		_report_hit(body)  # ← НОВОЕ: статистика считается там же, где применяется урон

	# ── 3. СМЕРТЬ. В самом конце. ──
	get_tree().create_timer(0.6).timeout.connect(queue_free)


func _deal_damage(body: Node) -> void:
	if multiplayer.get_peers().is_empty():
		body.take_damage(damage_amount)
	else:
		body.take_damage.rpc_id(body.get_multiplayer_authority(), damage_amount)


# ← НОВОЕ: +1 попадание бросившему.
# Только по игроку (стены/пол/сундуки точность не портят и не улучшают),
# не по себе, и только если бросивший известен.
func _report_hit(body: Node) -> void:
	if thrower_key == &"":
		return
	if body is Player and body.name != thrower_key:
		BattleStats.report_hit(thrower_key)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _homing == null or _has_hit:
		return
	# Без гейта по authority — см. примечание про сеть ниже.
	_homing.steer(state, get_rid(), get_tree())


func _is_homing_target(body: Node) -> bool:
	return body is Player and body.name != thrower_key and not body.is_dead()

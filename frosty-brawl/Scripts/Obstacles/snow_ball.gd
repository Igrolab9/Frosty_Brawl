extends RigidBody3D

@export var damage_amount: float = 1.0
@export var lifetime: float = 5.0
@export var grace_period: float = 0.05
@export var hit_sfx: StringName = &"snow_hit"
## false — снежок есть на всех пирах, каждый играет звук у себя (рекомендуется)
## true  — снежок есть только у бросившего, звук рассылается по RPC
@export var broadcast_sfx: bool = false
@export var debug_log: bool = true

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

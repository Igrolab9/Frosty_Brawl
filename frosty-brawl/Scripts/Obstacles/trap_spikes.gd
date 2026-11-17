class_name TrapSpikes
extends Area3D

@export var damage_amount: float = 2.0
@export var damage_interval: float = 1.0 ## секунд между тиками урона

@onready var _damage_zone: Area3D = $"."

var _contact_damage: ContactDamageComponent

func _ready() -> void:
	_contact_damage = ContactDamageComponent.new(damage_amount, damage_interval)
	_damage_zone.body_entered.connect(_contact_damage.add_body)
	_damage_zone.body_exited.connect(_contact_damage.remove_body)
	_contact_damage.damage_dealt.connect(_on_damage_dealt)

func _physics_process(delta: float) -> void:
	# Урон считает только сервер (в оффлайне is_server() тоже вернёт true)
	if not multiplayer.is_server():
		return
	_contact_damage.update(delta)

func _on_damage_dealt(_target: Node3D, _amount: float) -> void:
	pass # сюда позже: звук, партиклы, RPC-эффект для клиентов

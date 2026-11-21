class_name CharacterSpawner
extends RefCounted
## SRP: только инстансит игрока в точке спавна. Не знает про UI и сеть.
## DIP: каталог получаем извне через конструктор (инъекция зависимости).

var _catalog: CharacterCatalog

func _init(catalog: CharacterCatalog) -> void:
	_catalog = catalog

func spawn(id: StringName, spawn_point: Node3D, parent: Node) -> Node3D:
	var scene := _catalog.get_scene(id)
	if scene == null:
		return null
	var player := scene.instantiate() as Node3D
	if player == null:
		push_error("CharacterSpawner: корень сцены '%s' не Node3D" % id)
		return null
	parent.add_child(player)
	player.global_transform = spawn_point.global_transform
	return player

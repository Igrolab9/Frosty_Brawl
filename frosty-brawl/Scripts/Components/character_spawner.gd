class_name CharacterSpawner
extends RefCounted

var _catalog: CharacterCatalog

func _init(catalog: CharacterCatalog) -> void:
	_catalog = catalog

func spawn(id: StringName, spawn_point: Node3D, parent: Node, as_bot: bool = false) -> Node3D:
	var scene := _catalog.get_scene(id)
	if scene == null:
		return null
		
	var player := scene.instantiate() as Node3D
	if player == null:
		push_error("CharacterSpawner: корень сцены '%s' не Node3D" % id)
		return null
		
	# Устанавливаем роль ДО добавления в сцену и вызова _ready()
	if player.has_method("set_is_bot"):
		player.set_is_bot(as_bot)
	else:
		player.is_bot = as_bot # Прямое присвоение, работает благодаря @export var is_bot
		
	parent.add_child(player)
	player.global_transform = spawn_point.global_transform
	
	return player

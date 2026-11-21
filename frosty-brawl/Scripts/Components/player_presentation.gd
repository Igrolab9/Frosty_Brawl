class_name PlayerPresentation
extends RefCounted
## SRP: только настраивает представление игрока.
## Локальный: камера активна, HUD виден, управление включено.
## Остальные: камера выключена, HUD скрыт, контроллер заморожен.

func apply(player: Node3D, is_local: bool) -> void:
	_setup_cameras(player, is_local)
	_setup_hud(player, is_local)
	_setup_processing(player, is_local)

func _setup_cameras(player: Node3D, is_local: bool) -> void:
	# ищем по типу, а не по имени — переименуешь узел, ничего не сломается
	for cam: Camera3D in player.find_children("*", "Camera3D", true, false):
		cam.current = is_local

func _setup_hud(player: Node3D, is_local: bool) -> void:
	for layer: CanvasLayer in player.find_children("*", "CanvasLayer", true, false):
		layer.visible = is_local

func _setup_processing(player: Node3D, is_local: bool) -> void:
	# без этого все 4 персонажа будут читать один и тот же Input и бегать синхронно
	player.set_physics_process(is_local)
	player.set_process(is_local)
	player.set_process_input(is_local)
	player.set_process_unhandled_input(is_local)
	player.set_process_unhandled_key_input(is_local)

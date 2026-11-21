class_name PlayerPresentation
extends RefCounted
## SRP: только настраивает представление игрока.
## Локальный: камера активна, HUD виден, управление включено.
## Бот: камера выключена, HUD скрыт, физика ВКЛЮЧЕНА (AI-движение), input выключен.
## Удалённый персонаж: только визуал, физика выключена (симулирует хост).

## 🆕 Новый параметр is_bot: физика нужна и локальному, и ботам.
func apply(player: Node3D, is_local: bool, is_bot: bool = false) -> void:
	_setup_cameras(player, is_local)
	_setup_hud(player, is_local)
	_setup_processing(player, is_local, is_bot)

func _setup_cameras(player: Node3D, is_local: bool) -> void:
	# ищем по типу, а не по имени — переименуешь узел, ничего не сломается
	for cam: Camera3D in player.find_children("*", "Camera3D", true, false):
		cam.current = is_local

func _setup_hud(player: Node3D, is_local: bool) -> void:
	for layer: CanvasLayer in player.find_children("*", "CanvasLayer", true, false):
		layer.visible = is_local

func _setup_processing(player: Node3D, is_local: bool, is_bot: bool) -> void:
	# 🆕 КЛЮЧЕВОЕ ИЗМЕНЕНИЕ:
	# set_physics_process нужен НЕ только локальному игроку.
	# Боты тоже должны симулировать движение (их "ввод" — AI-компонент).
	# Удалённые персонажи (не боты, не локальные) — только визуал.
	player.set_physics_process(is_local or is_bot)

	# Input читаем ТОЛЬКО локальный игрок.
	# Ботам input не нужен — иначе MovementComponent читал бы чужие WASD.
	player.set_process(is_local)
	player.set_process_input(is_local)
	player.set_process_unhandled_input(is_local)
	player.set_process_unhandled_key_input(is_local)

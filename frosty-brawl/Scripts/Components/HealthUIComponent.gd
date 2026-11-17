class_name HealthUIComponent
extends RefCounted
## Подписывается на HealthComponent и рисует HP в Slider + Label.
## Ничего не знает про игрока, урон и сеть (SRP).

var _slider: Slider
var _label: Label

func _init(slider: Slider, label: Label) -> void:
	_slider = slider
	_label = label
	# Слайдер — индикатор, а не элемент ввода:
	_slider.editable = false
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slider.min_value = 0.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func bind(health: HealthComponent) -> void:
	health.health_changed.connect(_on_health_changed)
	# HealthComponent не эмитит сигнал при создании — рисуем старт сами
	_on_health_changed(health.get_health(), health.get_max_health())

func _on_health_changed(current: float, max_hp: float) -> void:
	_slider.max_value = max_hp
	_slider.value = current
	_label.text = "%.0f / %.0f" % [current, max_hp]

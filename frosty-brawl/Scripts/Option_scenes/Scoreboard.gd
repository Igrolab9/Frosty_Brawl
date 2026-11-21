class_name Scoreboard
extends CanvasLayer
## SRP: только показывает таблицу. Данные — через bind() (DIP).
## Весь UI строится в коде — отдельная .tscn не нужна.
## Видимость переключаем у корневого Control (_root), а не у CanvasLayer.
## Ввод — опросом Input в _process: не зависит от перехвата событий.

const COLUMNS := ["Боец", "Броски", "Попадания", "Точность"]

var _stats: BattleStatsComponent
var _local_key: StringName = &""
var _grid: GridContainer
var _root: Control
var _has_action: bool = false  # ← НОВОЕ: есть ли экшен в InputMap

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_has_action = InputMap.has_action(&"ui_scoreboard")  # ← НОВОЕ
	_build_ui()
	_root.visible = false

func bind(stats: BattleStatsComponent, local_key: StringName) -> void:
	_stats = stats
	_local_key = local_key
	_stats.stats_changed.connect(_refresh)

# ← ИЗМЕНЕНО: вместо _input — опрос каждый кадр.
# Держишь Tab — таблица видна, отпустил — скрылась (как в CS).
# Input.is_action_pressed читает глобальное состояние ввода напрямую,
# поэтому работает, даже если событие перехватил другой узел или GUI.
func _process(_delta: float) -> void:
	var held := Input.is_key_pressed(KEY_TAB)  # страховка: сырой Tab
	if _has_action:
		held = held or Input.is_action_pressed(&"ui_scoreboard")
	if held == _root.visible:
		return
	_root.visible = held
	if held:
		_refresh()

func _refresh() -> void:
	if _root == null or not _root.visible or _stats == null:
		return
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

	var aligns := [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER,
		HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_CENTER]
	for i in COLUMNS.size():
		_grid.add_child(_make_label(COLUMNS[i], aligns[i], true))

	var entries := _stats.get_entries()
	var keys := entries.keys()
	# как в CS: сортировка по «очкам» — у нас по попаданиям
	keys.sort_custom(func(a, b): return entries[a].hits > entries[b].hits)

	for key: StringName in keys:
		var s: PlayerStats = entries[key]
		var is_local := key == _local_key
		var acc := "—" if s.throws == 0 else "%.1f%%" % s.accuracy()
		var texts := [s.display_name + (" (вы)" if is_local else ""),
			str(s.throws), str(s.hits), acc]
		for i in texts.size():
			var label := _make_label(texts[i], aligns[i])
			if is_local:
				label.modulate = Color(0.55, 0.85, 1.0)
			_grid.add_child(label)

func _make_label(text: String, align: HorizontalAlignment, header: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 15 if header else 18)
	if header:
		label.modulate = Color(0.65, 0.8, 1.0)
	return label

func _build_ui() -> void:
	_root = Control.new()
	_root.visible = false
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.12, 0.92)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "СТАТИСТИКА БОЯ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 32)
	_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(_grid)

	var hint := Label.new()
	hint.text = "Отпусти Tab, чтобы закрыть"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.5)
	hint.add_theme_font_size_override("font_size", 13)
	vbox.add_child(hint)

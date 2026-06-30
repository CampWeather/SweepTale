extends Control

@export var animation_duration: float = 0.18
@export var closed_offset_x: float = -260.0
@export var selection_move_duration: float = 0.16

# NEW: vertical spacing between buttons inside ButtonList. Tune this to
# match your button height (+ a little gap if you want breathing room).
@export var slot_height: float = 44.0

# "press" feedback for the Up/Down nav buttons when triggered via input map
@export var click_feedback_scale: float = 0.78
@export var click_feedback_overshoot_scale: float = 1.12
@export var click_feedback_press_duration: float = 0.07
@export var click_feedback_overshoot_duration: float = 0.1
@export var click_feedback_release_duration: float = 0.12

@export var selected_button_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var unselected_button_color: Color = Color(0.65, 0.65, 0.65, 1.0)

@export var selection_outline_color: Color = Color(1.0, 0.631, 0.277, 0.85)
@export var selection_outline_width: int = 2
@export var selection_outline_padding: float = 4.0

@onready var panels_root: Control = $Panels

@onready var side_button_area: Control = $SideButtonArea
@onready var up_button: BaseButton = $SideButtonArea/Up
@onready var down_button: BaseButton = $SideButtonArea/Down

# NEW: SelectionWindow is the fixed "frame" (Clip Contents = on) the outline
# sits on. ButtonList is what actually scrolls vertically behind it.
@onready var selection_window: Control = $SideButtonArea/SelectionWindow
@onready var button_list: Control = $SideButtonArea/SelectionWindow/ButtonList

var _selection_outline: Panel

# NEW: both arrays are now populated dynamically in _setup_side_buttons(),
# instead of being wired one button at a time — so adding a new side button
# later doesn't require touching this script.
var _side_buttons: Array[BaseButton] = []
var _side_panels: Array[Control] = []

var _selected_side_button_index: int = 0
var _active_panel_index: int = -1

# Each panel tracks its own tween (closing one panel while opening another
# must not share a tween, or the closing one gets killed mid-flight).
var _panel_tweens: Dictionary = {}

# NEW: tracks whichever panel is currently mid-close, so a panel that's
# about to OPEN can wait for it — this is what stops panels from visually
# overlapping when you switch selection quickly.
var _closing_panel_tween: Tween = null

# Tween for the button list scrolling + button color crossfade
var _button_tween: Tween

# In-flight "click feedback" tween per button (Up/Down), keyed by node
var _click_feedback_tweens: Dictionary = {}

# NEW: in-flight "hide after it's scrolled out" timer per side button,
# keyed by node. Lets us cancel a pending hide if the button scrolls back
# into view before the delay finishes.
var _button_visibility_tweens: Dictionary = {}


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	# NEW: force Clip Contents on in code, so buttons that have scrolled
	# outside SelectionWindow's rect are never rendered, even if "Clip
	# Contents" wasn't ticked on the node in the editor.
	if selection_window != null:
		selection_window.clip_contents = true

	_setup_side_buttons()
	_setup_panels()
	_create_selection_outline()
	_update_side_button_selection(false)

	get_viewport().gui_release_focus()

	# Window resize doesn't move ButtonList's children (they're pinned to a
	# plain top-left anchor, see _setup_side_buttons), but SelectionWindow
	# itself and the panels can still drift if THEY use screen-relative
	# anchors — so re-sync the outline + panel meta whenever that happens.
	get_viewport().size_changed.connect(_on_viewport_resized)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Side_Button_Up"):
		select_previous_side_button()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("Side_Button_Down"):
		select_next_side_button()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("Choose_Side_Button"):
		choose_side_button()
		get_viewport().set_input_as_handled()


func _setup_side_buttons() -> void:
	_side_buttons.clear()
	_side_panels.clear()

	# NEW: any BaseButton placed under ButtonList becomes a side button
	# automatically, in whatever order it appears in the scene tree.
	if button_list != null:
		for child in button_list.get_children():
			if child is BaseButton:
				_side_buttons.append(child)

	# NEW: each button's panel is found by naming convention —
	# button "Quest" pairs with a node named "Quest Panel" under Panels.
	# Add new side buttons by following this same pattern; no script
	# changes needed.
	for button in _side_buttons:
		var panel: Control = null
		if panels_root != null:
			panel = panels_root.get_node_or_null(button.name + " Panel")

		if panel == null:
			push_warning("QuestTab: tidak menemukan panel untuk tombol '%s' (cari node bernama '%s Panel' di bawah Panels)." % [button.name, button.name])

		_side_panels.append(panel)

	for i in _side_buttons.size():
		var button := _side_buttons[i]

		button.focus_mode = Control.FOCUS_NONE
		button.release_focus()

		# NEW: pin to a plain top-left anchor so our manual index-based
		# positioning below isn't fought by anchor recalculation later.
		button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		button.position = Vector2(0.0, i * slot_height)

		button.pressed.connect(_on_side_button_pressed.bind(i))

	if up_button != null:
		up_button.focus_mode = Control.FOCUS_NONE
		up_button.pressed.connect(select_previous_side_button)
		up_button.pivot_offset = up_button.size / 2.0

	if down_button != null:
		down_button.focus_mode = Control.FOCUS_NONE
		down_button.pressed.connect(select_next_side_button)
		down_button.pivot_offset = down_button.size / 2.0


# NEW: generic click handler for any side button (replaces the old
# hardcoded per-button .pressed callbacks for Quest / Friend List).
func _on_side_button_pressed(index: int) -> void:
	_selected_side_button_index = index
	_update_side_button_selection(true)
	choose_side_button()


func _setup_panels() -> void:
	for panel in _side_panels:
		if panel == null:
			continue

		var open_position := panel.position

		var panel_width := panel.size.x
		if panel_width <= 0.0:
			panel_width = abs(closed_offset_x)

		var closed_position := open_position + Vector2(-panel_width, 0.0)

		panel.set_meta("open_position", open_position)
		panel.set_meta("closed_position", closed_position)

		panel.visible = false
		panel.position = closed_position
		panel.modulate.a = 0.0
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_viewport_resized() -> void:
	await get_tree().process_frame

	_snap_outline_to_selection_window()
	_refresh_panel_anchor_positions()


# NEW: panels can drift the same way the old per-button outline math did,
# if they're anchored to a screen edge. Re-derive open/closed meta from
# wherever the panel actually is right now, post-resize.
func _refresh_panel_anchor_positions() -> void:
	for panel in _side_panels:
		if panel == null:
			continue

		var panel_width := panel.size.x
		if panel_width <= 0.0:
			panel_width = abs(closed_offset_x)

		var is_open := panel.modulate.a > 0.5

		var open_position: Vector2
		if is_open:
			open_position = panel.position
		else:
			open_position = panel.position + Vector2(panel_width, 0.0)

		var closed_position := open_position + Vector2(-panel_width, 0.0)

		panel.set_meta("open_position", open_position)
		panel.set_meta("closed_position", closed_position)

		if not is_open:
			panel.position = closed_position


func choose_side_button() -> void:
	if _side_buttons.is_empty():
		return

	if _selected_side_button_index < 0 or _selected_side_button_index >= _side_buttons.size():
		return

	toggle_panel_by_index(_selected_side_button_index)


func select_previous_side_button() -> void:
	if _side_buttons.is_empty():
		return

	close_active_panel()

	_selected_side_button_index -= 1

	if _selected_side_button_index < 0:
		_selected_side_button_index = _side_buttons.size() - 1

	_update_side_button_selection(true)
	_play_click_feedback(up_button)


func select_next_side_button() -> void:
	if _side_buttons.is_empty():
		return

	close_active_panel()

	_selected_side_button_index += 1

	if _selected_side_button_index >= _side_buttons.size():
		_selected_side_button_index = 0

	_update_side_button_selection(true)
	_play_click_feedback(down_button)


func toggle_panel_by_index(index: int) -> void:
	if index < 0 or index >= _side_panels.size():
		return

	if _active_panel_index == index:
		set_panel_open(_side_panels[index], false)
		_active_panel_index = -1
		return

	if _active_panel_index >= 0 and _active_panel_index < _side_panels.size():
		set_panel_open(_side_panels[_active_panel_index], false)

	_active_panel_index = index
	set_panel_open(_side_panels[index], true)


func close_active_panel() -> void:
	if _active_panel_index < 0 or _active_panel_index >= _side_panels.size():
		return

	set_panel_open(_side_panels[_active_panel_index], false)
	_active_panel_index = -1


func set_panel_open(panel: Control, open: bool) -> void:
	if panel == null:
		return

	if _panel_tweens.has(panel):
		var existing_tween: Tween = _panel_tweens[panel]
		if existing_tween != null and existing_tween.is_valid():
			existing_tween.kill()

	# NEW: if a DIFFERENT panel is still mid-close, wait for it to actually
	# finish before this one starts opening. Without this, the incoming
	# panel and the outgoing one are both visible, in the same spot, for
	# the whole overlap window — which is the "saling menimpa" you saw.
	if open and _closing_panel_tween != null and _closing_panel_tween.is_valid():
		await _closing_panel_tween.finished

	panel.visible = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var open_position: Vector2 = panel.get_meta("open_position")
	var closed_position: Vector2 = panel.get_meta("closed_position")

	var target_position := open_position if open else closed_position
	var target_alpha := 1.0 if open else 0.0

	var panel_tween := create_tween()
	_panel_tweens[panel] = panel_tween
	panel_tween.set_parallel(true)

	panel_tween.tween_property(
		panel,
		"position",
		target_position,
		animation_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	panel_tween.tween_property(
		panel,
		"modulate:a",
		target_alpha,
		animation_duration
	)

	if not open:
		_closing_panel_tween = panel_tween
		panel_tween.finished.connect(func():
			panel.visible = false
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if _closing_panel_tween == panel_tween:
				_closing_panel_tween = null
		)


func _create_selection_outline() -> void:
	if _selection_outline != null:
		_selection_outline.queue_free()
		_selection_outline = null

	_selection_outline = Panel.new()
	_selection_outline.name = "SelectionOutline"
	_selection_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_outline.z_index = 50

	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	stylebox.border_color = selection_outline_color
	stylebox.set_border_width_all(selection_outline_width)
	stylebox.corner_radius_top_left = 4
	stylebox.corner_radius_top_right = 4
	stylebox.corner_radius_bottom_left = 4
	stylebox.corner_radius_bottom_right = 4

	_selection_outline.add_theme_stylebox_override("panel", stylebox)

	add_child(_selection_outline)

	_snap_outline_to_selection_window()


# NEW: the outline no longer chases a moving button — SelectionWindow is
# the fixed frame, and the button list scrolls behind it instead. So the
# outline just needs to match SelectionWindow's rect, once at startup and
# again on resize. All the old arc/bezier "predict where the button will
# land" math is gone, since nothing is moving that needs predicting anymore.
func _snap_outline_to_selection_window() -> void:
	if _selection_outline == null or selection_window == null:
		return

	var padding: float = selection_outline_padding

	var window_global_rect: Rect2 = selection_window.get_global_rect()
	var root_global_rect: Rect2 = get_global_rect()

	var local_position: Vector2 = window_global_rect.position - root_global_rect.position

	_selection_outline.position = local_position - Vector2(padding, padding)
	_selection_outline.size = window_global_rect.size + Vector2(padding * 2.0, padding * 2.0)


func _update_side_button_selection(animate: bool = true) -> void:
	if _button_tween != null and _button_tween.is_valid():
		_button_tween.kill()

	# NEW: scroll the WHOLE list so the selected button lands at the top of
	# ButtonList's local space (which lines up with SelectionWindow's clip
	# rect) — this is what makes buttons slide up/down and get clipped out
	# of view when they're not the selected one.
	var target_list_y: float = -float(_selected_side_button_index) * slot_height

	# NEW: how tall SelectionWindow's visible area actually is, so we know
	# which buttons will land inside it once this scroll finishes. Falls
	# back to a single slot if the window hasn't been laid out yet.
	var window_height: float = slot_height
	if selection_window != null and selection_window.size.y > 0.0:
		window_height = selection_window.size.y

	if animate:
		_button_tween = create_tween()
		_button_tween.set_parallel(true)

		_button_tween.tween_property(
			button_list,
			"position:y",
			target_list_y,
			selection_move_duration
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		for i in _side_buttons.size():
			var button := _side_buttons[i]
			if button == null:
				continue

			var target_color := selected_button_color if i == _selected_side_button_index else unselected_button_color
			_button_tween.tween_property(button, "modulate", target_color, selection_move_duration)

			# NEW: a button is "in window" once it overlaps SelectionWindow's
			# [0, window_height] range after this scroll finishes.
			var final_top: float = button.position.y + target_list_y
			var final_bottom: float = final_top + slot_height
			var will_be_visible: bool = final_bottom > 0.0 and final_top < window_height

			_set_button_window_visibility(button, will_be_visible)
	else:
		button_list.position.y = target_list_y

		for i in _side_buttons.size():
			var button := _side_buttons[i]
			if button == null:
				continue

			button.modulate = selected_button_color if i == _selected_side_button_index else unselected_button_color

			var final_top: float = button.position.y + target_list_y
			var final_bottom: float = final_top + slot_height
			var will_be_visible: bool = final_bottom > 0.0 and final_top < window_height

			button.visible = will_be_visible
			button.mouse_filter = Control.MOUSE_FILTER_STOP if will_be_visible else Control.MOUSE_FILTER_IGNORE

	for button in _side_buttons:
		if button != null:
			button.release_focus()


# NEW: keeps a side button interactable + visible while it's inside (or
# still sliding through) SelectionWindow, and fully disables it — visible
# = false, no mouse input — once it has actually finished scrolling out.
# The button itself was already clipped out by SelectionWindow's
# Clip Contents before this fires, so there's no visual pop; this purely
# stops an off-screen button from eating clicks/hovers meant for nothing.
func _set_button_window_visibility(button: BaseButton, will_be_visible: bool) -> void:
	if _button_visibility_tweens.has(button):
		var existing: Tween = _button_visibility_tweens[button]
		if existing != null and existing.is_valid():
			existing.kill()
		_button_visibility_tweens.erase(button)

	if will_be_visible:
		button.visible = true
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		return

	# Stop it from intercepting input immediately, but don't hide it until
	# the slide tween has actually had time to carry it out from under the
	# clip rect.
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hide_tween := create_tween()
	_button_visibility_tweens[button] = hide_tween
	hide_tween.tween_interval(selection_move_duration)
	hide_tween.tween_callback(func():
		if is_instance_valid(button):
			button.visible = false
		_button_visibility_tweens.erase(button)
	)


# Quick "press" bounce — squashes the button down, pops it slightly PAST
# normal size, then settles back to 1.0.
func _play_click_feedback(button: BaseButton) -> void:
	if button == null:
		return

	if _click_feedback_tweens.has(button):
		var existing_tween: Tween = _click_feedback_tweens[button]
		if existing_tween != null and existing_tween.is_valid():
			existing_tween.kill()

	button.scale = Vector2.ONE

	var click_tween := create_tween()
	_click_feedback_tweens[button] = click_tween

	click_tween.tween_property(
		button,
		"scale",
		Vector2.ONE * click_feedback_scale,
		click_feedback_press_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	click_tween.tween_property(
		button,
		"scale",
		Vector2.ONE * click_feedback_overshoot_scale,
		click_feedback_overshoot_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	click_tween.tween_property(
		button,
		"scale",
		Vector2.ONE,
		click_feedback_release_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

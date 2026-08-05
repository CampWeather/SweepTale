extends Control

# Side bar UI variabel
@export_group("Side Button Area")
@export var animation_duration: float = 0.18
@export var closed_offset_x: float = -260.0
@export var selection_move_duration: float = 0.16

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

# Variabel Export Quest 
@export_group("Quest UI")

@export var empty_quest_message: String = "Belum ada quest yang dapat dikerjakan."
@export var quest_manager_missing_message: String = "QuestManager belum tersedia."
@export var quest_manager_method_missing_message: String = "QuestManager tidak memiliki method GetActiveQuestViewData()."

@export var quest_title_font_size: int = 16
@export var quest_description_font_size: int = 12
@export var objective_font_size: int = 12

@export var quest_title_color: Color = Color(1.0, 0.9, 0.65, 1.0)
@export var quest_description_color: Color = Color(0.85, 0.85, 0.85, 1.0)
@export var objective_incomplete_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var objective_completed_color: Color = Color(0.55, 1.0, 0.55, 1.0)
@export var empty_message_color: Color = Color(0.8, 0.8, 0.8, 1.0)

@export var completed_objective_prefix: String = "✓"
@export var incomplete_objective_prefix: String = "□"

@export var quest_card_spacing: float = 12.0
@export var objective_indent_x: float = 0.0

# Export Debug Quest
@export_group("Quest Debug")

@export var enable_quest_debug: bool = false
@export var auto_start_debug_quest: bool = false
@export var debug_quest_id: String = "talk_to_Dzakwan"

@export var debug_event_type: String = "talk_npc"
@export var debug_event_target_id: String = "NPC_01"
@export var debug_event_amount: int = 1

@export_group("Quest UI Animation")

@export var quest_card_enter_offset_x: float = -80.0
@export var quest_card_exit_offset_x: float = -120.0
@export var quest_card_enter_duration: float = 0.28
@export var quest_card_exit_duration: float = 0.35
@export var quest_card_complete_hold_duration: float = 0.75
@export var quest_card_enter_stagger: float = 0.06

@export var completed_quest_title_color: Color = Color(0.55, 1.0, 0.55, 1.0)
@export var completed_quest_description_color: Color = Color(0.75, 1.0, 0.75, 1.0)

@onready var panels_root: Control = $Panels
@onready var quest_panel: Control = $"Panels/Quest Panel"
@onready var quest_header_label: Label = $"Panels/Quest Panel/MarginContainer/VBoxContainer/HeaderLabel"
@onready var quest_list: VBoxContainer = $"Panels/Quest Panel/MarginContainer/VBoxContainer/ScrollContainer/QuestList"

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

var _quest_cards_by_id: Dictionary = {}
var _quest_card_tweens: Dictionary = {}
var _is_animating_quest_completion: bool = false


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	if selection_window != null:
		selection_window.clip_contents = true

	_setup_side_buttons()
	_setup_panels()
	_setup_quest_header()
	_create_selection_outline()
	_update_side_button_selection(false)
	
	_connect_quest_manager()
	_refresh_quest_panel()
	
	if enable_quest_debug and auto_start_debug_quest:
		debug_start_quest()

	get_viewport().gui_release_focus()
 # Auto Anchored
	get_viewport().size_changed.connect(_on_viewport_resized)

#Function yang menghubungkan QuestManager
func _connect_quest_manager() -> void:
	if not Engine.has_singleton("QuestManager") and not has_node("/root/QuestManager"):
		push_warning("QuestTab: QuestManager Autoload tidak ditemukan.")
		return

	var manager = get_node_or_null("/root/QuestManager")
	if manager == null:
		push_warning("QuestTab: gagal mengambil /root/QuestManager.")
		return

	if manager.has_signal("QuestStarted"):
		manager.connect("QuestStarted", _on_quest_started)

	if manager.has_signal("QuestUpdated"):
		manager.connect("QuestUpdated", _on_quest_updated)

	if manager.has_signal("QuestCompleted"):
		manager.connect("QuestCompleted", _on_quest_completed)

	if manager.has_signal("QuestListChanged"):
		manager.connect("QuestListChanged", _on_quest_list_changed)

func _refresh_quest_panel(animate_enter: bool = false) -> void:
	if quest_list == null:
		return

	if _is_animating_quest_completion:
		return

	_clear_quest_list()

	var manager = get_node_or_null("/root/QuestManager")
	if manager == null:
		_add_empty_quest_message(quest_manager_missing_message)
		return

	if not manager.has_method("GetActiveQuestViewData"):
		_add_empty_quest_message(quest_manager_method_missing_message)
		return

	var quests: Array = manager.GetActiveQuestViewData()

	if quests.is_empty():
		_add_empty_quest_message(empty_quest_message)
		return

	var index := 0
	for quest_data in quests:
		var card := _add_quest_card(quest_data)

		if animate_enter:
			_animate_quest_card_enter(card, index)

		index += 1

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

	elif event.is_action_pressed("Debug_Quest_Progress"):
		debug_report_quest_event()
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

func _setup_quest_header() -> void:
	if quest_header_label == null:
		return

	quest_header_label.text = "Quest"
	quest_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quest_header_label.add_theme_font_size_override("font_size", 20)
	quest_header_label.modulate = Color.WHITE

func _on_viewport_resized() -> void:
	await get_tree().process_frame

	_snap_outline_to_selection_window()
	_refresh_panel_anchor_positions()

# Refresh Panel Anchor
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

# Panel Tidak Saling Timpa
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


# Auto Calculated Size when the window resize
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

	var target_list_y: float = -float(_selected_side_button_index) * slot_height
  
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
	# the slide tween has actually had time to carry it out from under the clip rect.
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hide_tween := create_tween()
	_button_visibility_tweens[button] = hide_tween
	hide_tween.tween_interval(selection_move_duration)
	hide_tween.tween_callback(func():
		if is_instance_valid(button):
			button.visible = false
		_button_visibility_tweens.erase(button)
	)


# Bounce Feel when click Side Button Area
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
	

# Signal From QuestManager.cs
func _on_quest_started(_quest_id: String) -> void:
	_refresh_quest_panel(true)


func _on_quest_updated(_quest_id: String) -> void:
	if not _is_animating_quest_completion:
		_refresh_quest_panel(false)


func _on_quest_completed(quest_id: String) -> void:
	_play_quest_completed_animation(quest_id)


func _on_quest_list_changed() -> void:
	if not _is_animating_quest_completion:
		_refresh_quest_panel(false)

func _clear_quest_list() -> void:
	for tween in _quest_card_tweens.values():
		if tween != null and tween.is_valid():
			tween.kill()

	_quest_card_tweens.clear()
	_quest_cards_by_id.clear()

	for child in quest_list.get_children():
		child.queue_free()

#Untuk Membuat Quest Massage:
func _add_empty_quest_message(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", quest_description_font_size)
	label.modulate = empty_message_color
	quest_list.add_child(label)

# Membuat Quest Card Label berisi Tittle, description, objectives
func _add_quest_card(quest_data: Dictionary) -> Control:
	var quest_id: String = str(quest_data.get("id", ""))

	var card := VBoxContainer.new()
	card.name = "QuestCard_%s" % quest_id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.modulate.a = 1.0
	card.set_meta("quest_id", quest_id)

	quest_list.add_child(card)

	if not quest_id.is_empty():
		_quest_cards_by_id[quest_id] = card

	var title := Label.new()
	title.name = "Title"
	title.text = str(quest_data.get("title", "Untitled Quest"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", quest_title_font_size)
	title.modulate = quest_title_color
	card.add_child(title)

	var description := Label.new()
	description.name = "Description"
	description.text = str(quest_data.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", quest_description_font_size)
	description.modulate = quest_description_color
	card.add_child(description)

	var objectives: Array = quest_data.get("objectives", [])

	for objective_data in objectives:
		_add_objective_row_to_card(card, objective_data)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, quest_card_spacing)
	card.add_child(spacer)

	return card
	

# Membuat Baris status Objective Quest
func _add_objective_row(objective_data: Dictionary) -> void:
	var is_completed: bool = bool(objective_data.get("is_completed", false))
	var description: String = str(objective_data.get("description", "Objective"))
	var progress_text: String = str(objective_data.get("progress_text", ""))

	var label := Label.new()
	var checkbox := completed_objective_prefix if is_completed else incomplete_objective_prefix

	if progress_text.is_empty():
		label.text = "%s %s" % [checkbox, description]
	else:
		label.text = "%s %s  %s" % [checkbox, description, progress_text]

	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", objective_font_size)

	if objective_indent_x > 0.0:
		label.position.x = objective_indent_x

	if is_completed:
		label.modulate = objective_completed_color
	else:
		label.modulate = objective_incomplete_color

	quest_list.add_child(label)

func debug_start_quest() -> void:
	if not enable_quest_debug:
		return
	var manager = get_node_or_null("/root/QuestManager")
	if manager != null and manager.has_method("StartQuest"):
		manager.StartQuest(debug_quest_id)

func debug_report_quest_event() -> void:
	if not enable_quest_debug:
		return
	var manager = get_node_or_null("/root/QuestManager")
	if manager != null and manager.has_method("ReportEvent"):
		manager.ReportEvent(debug_event_type, debug_event_target_id, debug_event_amount)

func _add_objective_row_to_card(card: Control, objective_data: Dictionary) -> Label:
	var is_completed: bool = bool(objective_data.get("is_completed", false))
	var description: String = str(objective_data.get("description", "Objective"))
	var progress_text: String = str(objective_data.get("progress_text", ""))

	var label := Label.new()
	label.name = "Objective"
	var checkbox := completed_objective_prefix if is_completed else incomplete_objective_prefix

	if progress_text.is_empty():
		label.text = "%s %s" % [checkbox, description]
	else:
		label.text = "%s %s  %s" % [checkbox, description, progress_text]

	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", objective_font_size)

	if objective_indent_x > 0.0:
		label.position.x = objective_indent_x

	label.modulate = objective_completed_color if is_completed else objective_incomplete_color

	card.add_child(label)

	return label
	

func _animate_quest_card_enter(card: Control, index: int = 0) -> void:
	if card == null:
		return

	card.visible = true
	card.modulate.a = 0.0
	card.position.x = quest_card_enter_offset_x

	var tween := create_tween()
	_quest_card_tweens[card] = tween

	tween.set_parallel(true)

	if index > 0:
		tween.tween_interval(quest_card_enter_stagger * float(index))

	tween.tween_property(
		card,
		"position:x",
		0.0,
		quest_card_enter_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		card,
		"modulate:a",
		1.0,
		quest_card_enter_duration
	)
	
func _play_quest_completed_animation(quest_id: String) -> void:
	if quest_id.is_empty():
		_refresh_quest_panel(true)
		return

	var card: Control = _quest_cards_by_id.get(quest_id, null)

	if card == null or not is_instance_valid(card):
		_refresh_quest_panel(true)
		return

	_is_animating_quest_completion = true

	if _quest_card_tweens.has(card):
		var existing: Tween = _quest_card_tweens[card]
		if existing != null and existing.is_valid():
			existing.kill()

	_mark_quest_card_completed(card)

	var tween := create_tween()
	_quest_card_tweens[card] = tween

	tween.tween_interval(quest_card_complete_hold_duration)

	tween.set_parallel(true)

	tween.tween_property(
		card,
		"position:x",
		quest_card_exit_offset_x,
		quest_card_exit_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	tween.tween_property(
		card,
		"modulate:a",
		0.0,
		quest_card_exit_duration
	)

	tween.finished.connect(func():
		_is_animating_quest_completion = false
		_refresh_quest_panel(true)
	)
 
func _mark_quest_card_completed(card: Control) -> void:
	if card == null:
		return

	for child in card.get_children():
		if child is Label:
			if child.name == "Title":
				child.modulate = completed_quest_title_color
			elif child.name == "Description":
				child.modulate = completed_quest_description_color
			elif child.name == "Objective":
				var label := child as Label
				label.modulate = objective_completed_color

				if label.text.begins_with(incomplete_objective_prefix):
					label.text = completed_objective_prefix + label.text.substr(incomplete_objective_prefix.length())

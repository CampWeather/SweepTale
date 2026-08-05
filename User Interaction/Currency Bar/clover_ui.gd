@tool
extends Control

@export_group("Behavior")
@export var start_collapsed := true

@export_group("Timing")
@export var expanded_duration := 2.4
@export var bar_open_time := 0.42
@export var bar_close_time := 0.32
@export var gain_pop_time := 0.9
@export var wiggle_time := 0.62

@export_group("Icon")
@export var icon_base_rotation_degrees := 0.0

@export_group("Testing")
@export var test_reward_on_start := false
@export var test_reward_repeat := false
@export var test_reward_delay := 10.0
@export var test_reward_amount := 12


@onready var reward_widget: Control = $SafeArea/TopRightAnchor/RewardWidget
@onready var reward_bar: PanelContainer = $SafeArea/TopRightAnchor/RewardWidget/RewardBar
@onready var gain_label: Label = $SafeArea/TopRightAnchor/RewardWidget/RewardBar/BarContent/GainLabel
@onready var total_label: Label = $SafeArea/TopRightAnchor/RewardWidget/RewardBar/BarContent/TotalLabel
@onready var icon_button: PanelContainer = $SafeArea/TopRightAnchor/RewardWidget/CloverIconButton
@onready var sparkles: Control = $SafeArea/TopRightAnchor/RewardWidget/Sparkles
@onready var sparkle_a: TextureRect = $SafeArea/TopRightAnchor/RewardWidget/Sparkles/SparkleA
@onready var sparkle_b: TextureRect = $SafeArea/TopRightAnchor/RewardWidget/Sparkles/SparkleB
@onready var sparkle_c: TextureRect = $SafeArea/TopRightAnchor/RewardWidget/Sparkles/SparkleC

var _main_tween: Tween
var _running_tweens: Array[Tween] = []
var _total := 128

var _gain_base_position := Vector2.ZERO
var _gain_base_scale := Vector2.ONE
var _icon_base_position := Vector2.ZERO
var _icon_base_scale := Vector2.ONE
var _sparkles_base_modulate := Color.WHITE
var _sparkle_positions: Dictionary = {}

const CLOVER_REWARD_SIGNAL := &"CloverRewardGranted"

func _ready() -> void:
	if not Engine.is_editor_hint():
		await get_tree().process_frame

	_cache_base_state()
	_prepare_pivots()

	# Use the editor value as the initial fallback value.
	_total = (
		int(total_label.text)
		if total_label.text.is_valid_int()
		else _total
	)

	total_label.text = str(_total)

	if not Engine.is_editor_hint():
		_connect_quest_manager()

	if start_collapsed and not Engine.is_editor_hint():
		_set_collapsed()
	else:
		_set_expanded_preview()

	if test_reward_on_start and not Engine.is_editor_hint():
		_start_test_reward()

func play_reward(amount: int, final_total: int = -1) -> void:
	if Engine.is_editor_hint():
		return

	if amount <= 0:
		return

	_prepare_pivots()
	_kill_running_tweens()

	var next_total := final_total if final_total >= 0 else _total + amount

	gain_label.text = "+%d" % amount
	total_label.text = str(_total)

	_set_collapsed()

	_main_tween = _track_tween(create_tween())
	_animate_bar_open(_main_tween)
	_animate_gain()
	_animate_icon_wiggle()
	_animate_sparkles()

	_main_tween.tween_interval(0.56)
	_main_tween.tween_callback(func():
		_total = next_total
		total_label.text = str(_total)
		_animate_total_pop() #edisi 2 (Bisa dimatikan jika)
	)

	_main_tween.tween_interval(max(expanded_duration - 0.56, 0.1))
	_main_tween.tween_callback(func():
		_animate_close()
	)

func _animate_total_pop() -> void:
	var base_scale := total_label.scale
	var total_tween := _track_tween(create_tween())
	total_tween.tween_property(total_label, "scale", base_scale * 1.12, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	total_tween.tween_property(total_label, "scale", base_scale, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func set_total(value: int) -> void:
	_total = value
	if is_node_ready():
		total_label.text = str(_total)

func _start_test_reward() -> void:
	await get_tree().process_frame

	while test_reward_on_start and not Engine.is_editor_hint():
		await get_tree().create_timer(test_reward_delay).timeout
		play_reward(test_reward_amount)

		if not test_reward_repeat:
			break

func _connect_quest_manager() -> void:
	var quest_manager = get_node_or_null("/root/QuestManager")

	if quest_manager == null:
		push_error(
			"CloverHUD could not find the QuestManager autoload."
		)
		return

	if not quest_manager.has_signal(CLOVER_REWARD_SIGNAL):
		push_error(
			"QuestManager does not contain the CloverRewardGranted signal."
		)
		return

	var callback := Callable(
		self,
		"_on_clover_reward_granted"
	)

	if not quest_manager.is_connected(
		CLOVER_REWARD_SIGNAL,
		callback
	):
		quest_manager.connect(
			CLOVER_REWARD_SIGNAL,
			callback
		)

	set_total(quest_manager.GetCloverLeaves())

@warning_ignore("unused_parameter")
func _on_clover_reward_granted(quest_id: String, amount: int, new_total: int) -> void:
	play_reward(amount, new_total)


func collapse_now() -> void:
	_kill_running_tweens()
	_set_collapsed()


func expand_preview() -> void:
	_kill_running_tweens()
	_set_expanded_preview()


func _cache_base_state() -> void:
	_gain_base_position = gain_label.position
	_gain_base_scale = gain_label.scale
	_icon_base_position = icon_button.position
	_icon_base_scale = icon_button.scale
	_sparkles_base_modulate = sparkles.modulate

	_sparkle_positions = {
		sparkle_a: sparkle_a.position,
		sparkle_b: sparkle_b.position,
		sparkle_c: sparkle_c.position,
	}


func _prepare_pivots() -> void:
	reward_bar.pivot_offset = Vector2(reward_bar.size.x, reward_bar.size.y * 0.5)
	icon_button.pivot_offset = icon_button.size * 0.5

	for sparkle in [sparkle_a, sparkle_b, sparkle_c]:
		sparkle.pivot_offset = sparkle.size * 0.5


func _track_tween(tween: Tween) -> Tween:
	_running_tweens.append(tween)
	return tween


func _kill_running_tweens() -> void:
	for tween in _running_tweens:
		if is_instance_valid(tween):
			tween.kill()

	_running_tweens.clear()
	_main_tween = null


func _set_collapsed() -> void:
	reward_bar.visible = true
	reward_bar.scale = Vector2(0.0, 1.0)
	reward_bar.modulate.a = 0.0

	gain_label.modulate.a = 0.0
	gain_label.position = _gain_base_position
	gain_label.scale = _gain_base_scale

	icon_button.position = _icon_base_position
	icon_button.rotation_degrees = icon_base_rotation_degrees
	icon_button.scale = _icon_base_scale

	sparkles.modulate = _sparkles_base_modulate
	sparkles.modulate.a = 0.0

	for sparkle in [sparkle_a, sparkle_b, sparkle_c]:
		sparkle.modulate.a = 0.0
		sparkle.scale = Vector2(0.1, 0.1)

		if _sparkle_positions.has(sparkle):
			sparkle.position = _sparkle_positions[sparkle]


func _set_expanded_preview() -> void:
	reward_bar.visible = true
	reward_bar.scale = Vector2.ONE
	reward_bar.modulate.a = 1.0

	gain_label.modulate.a = 1.0
	gain_label.position = _gain_base_position
	gain_label.scale = _gain_base_scale

	icon_button.position = _icon_base_position
	icon_button.rotation_degrees = icon_base_rotation_degrees
	icon_button.scale = _icon_base_scale

	sparkles.modulate = _sparkles_base_modulate
	sparkles.modulate.a = 1.0

	for sparkle in [sparkle_a, sparkle_b, sparkle_c]:
		sparkle.modulate.a = 1.0
		sparkle.scale = Vector2.ONE

		if _sparkle_positions.has(sparkle):
			sparkle.position = _sparkle_positions[sparkle]


func _animate_bar_open(tween: Tween) -> void:
	tween.set_parallel(true)
	tween.tween_property(reward_bar, "scale:x", 1.0, bar_open_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(reward_bar, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)


func _animate_gain() -> void:
	gain_label.position = _gain_base_position + Vector2(0.0, 10.0)
	gain_label.scale = Vector2(0.85, 0.85)
	gain_label.modulate.a = 0.0

	var gain_tween := _track_tween(create_tween())
	gain_tween.set_parallel(true)
	gain_tween.tween_property(gain_label, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	gain_tween.tween_property(gain_label, "position", _gain_base_position, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	gain_tween.tween_property(gain_label, "scale", Vector2(1.14, 1.14), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	gain_tween.set_parallel(false)
	gain_tween.tween_interval(gain_pop_time * 0.62)
	gain_tween.tween_property(gain_label, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	gain_tween.parallel().tween_property(gain_label, "position", _gain_base_position + Vector2(0.0, -10.0), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	gain_tween.parallel().tween_property(gain_label, "scale", Vector2(0.96, 0.96), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _animate_icon_wiggle() -> void:
	icon_button.position = _icon_base_position
	icon_button.rotation_degrees = icon_base_rotation_degrees
	icon_button.scale = _icon_base_scale

	var r := icon_base_rotation_degrees

	var icon_tween := _track_tween(create_tween())
	icon_tween.tween_property(icon_button, "rotation_degrees", r - 8.0, wiggle_time * 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	icon_tween.tween_property(icon_button, "rotation_degrees", r + 8.0, wiggle_time * 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	icon_tween.tween_property(icon_button, "rotation_degrees", r - 5.0, wiggle_time * 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	icon_tween.tween_property(icon_button, "rotation_degrees", r + 4.0, wiggle_time * 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	icon_tween.tween_property(icon_button, "rotation_degrees", r, wiggle_time * 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	var scale_tween := _track_tween(create_tween())
	scale_tween.tween_property(icon_button, "scale", _icon_base_scale * 1.07, wiggle_time * 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(icon_button, "scale", _icon_base_scale, wiggle_time * 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	#bisa diubah nanti (just Polished)
	#var position_tween := _track_tween(create_tween())
	#position_tween.tween_property(icon_button, "position", _icon_base_position + Vector2(2, -1), wiggle_time * 0.14)
	#position_tween.tween_property(icon_button, "position", _icon_base_position + Vector2(-2, 1), wiggle_time * 0.14)
	#position_tween.tween_property(icon_button, "position", _icon_base_position + Vector2(1, -1), wiggle_time * 0.14)
	#position_tween.tween_property(icon_button, "position", _icon_base_position, wiggle_time * 0.14)



func _animate_sparkles() -> void:
	sparkles.modulate = _sparkles_base_modulate
	sparkles.modulate.a = 1.0

	_play_one_sparkle(sparkle_a, Vector2(-4.0, -5.0), 0.0)
	_play_one_sparkle(sparkle_b, Vector2(-4.0, -5.0), 0.11)
	_play_one_sparkle(sparkle_c, Vector2(8.0, -14.0), 0.22)


func _play_one_sparkle(sparkle: TextureRect, drift: Vector2, delay: float) -> void:
	if not _sparkle_positions.has(sparkle):
		return

	var start_position: Vector2 = _sparkle_positions[sparkle]

	sparkle.position = start_position
	sparkle.scale = Vector2(0.1, 0.1)
	sparkle.modulate.a = 0.0

	var sparkle_tween := _track_tween(create_tween())
	sparkle_tween.tween_interval(delay)
	sparkle_tween.tween_property(sparkle, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	sparkle_tween.parallel().tween_property(sparkle, "scale", Vector2(1.1, 1.1), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sparkle_tween.parallel().tween_property(sparkle, "position", start_position + drift, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	sparkle_tween.tween_property(sparkle, "modulate:a", 0.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	sparkle_tween.parallel().tween_property(sparkle, "scale", Vector2(0.2, 0.2), 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	sparkle_tween.parallel().tween_property(sparkle, "position", start_position + drift + Vector2(8.0, -14.0), 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _animate_close() -> void:
	var close_tween := _track_tween(create_tween())
	close_tween.set_parallel(true)
	close_tween.tween_property(reward_bar, "scale:x", 0.0, bar_close_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	close_tween.tween_property(reward_bar, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	close_tween.tween_property(gain_label, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	close_tween.tween_property(sparkles, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	close_tween.tween_property(icon_button, "rotation_degrees", icon_base_rotation_degrees, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	close_tween.tween_property(icon_button, "scale", _icon_base_scale, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	close_tween.set_parallel(false)
	close_tween.tween_callback(func():
		_set_collapsed()
	)

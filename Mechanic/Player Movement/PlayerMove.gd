extends CharacterBody3D

@onready var actionable_finder = $Neck/Camera3D/ActionableFinder

@export_group("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var acceleration: float = 12.0
@export var air_acceleration: float = 4.0

@export_group("Mouse Look")
@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -80.0
@export var max_pitch: float = 80.0

@export_group("Node Paths")
@export var neck_path: NodePath = "Neck"
@export var camera_path: NodePath = "Neck/Camera3D"

@onready var neck: Node3D = get_node(neck_path)
@onready var camera: Camera3D = get_node(camera_path)
@onready var dust_hit_effect = $Neck/DustHitEffect

var is_in_dialogue: bool = false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var pitch: float = 0.0

# --- TAMBAHAN: Variabel untuk Tween & Data Kamera ---
var default_camera_transform: Transform3D
var camera_tween: Tween
# ----------------------------------------------------

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	
	if camera:
		default_camera_transform = camera.transform # Menyimpan local transform kamera bawaan

func _on_dialogue_ended(_resource: DialogueResource) -> void:
	set_dialogue_state(false)

func _unhandled_input(event: InputEvent) -> void:
	if is_in_dialogue:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
		neck.rotation.x = pitch

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().paused = true
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_tree().paused = false

	if event.is_action_pressed("interact"):
		var actionables = actionable_finder.get_overlapping_areas()
		if actionables.size() > 0:
			var target = actionables[0] # Ambil referensi target secara spesifik
			var should_freeze = target.action()
			if should_freeze:
				set_dialogue_state(true, target) # Oper target NPC ke fungsi
				get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	
	if is_in_dialogue:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		move_and_slide()
		return
		
	handle_jump()
	handle_movement(delta)
	move_and_slide()

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

func handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

func handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var accel := acceleration if is_on_floor() else air_acceleration
	
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * target_speed, accel * delta)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

func play_dust_hit_effect() -> void:
	if dust_hit_effect and dust_hit_effect.has_method("play_dust_hit_effect"):
		dust_hit_effect.play_dust_hit_effect()

# --- MODIFIKASI: Ditambah parameter state dan animasi kamera ---
func set_dialogue_state(state: bool, target: Node3D = null) -> void:
	is_in_dialogue = state
	if is_in_dialogue:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		# Animasi kunci kamera ke posisi NPC
		if target and target.has_method("get_dialog_camera_point"):
			var cam_point = target.get_dialog_camera_point()
			if cam_point != null:
				if camera_tween and camera_tween.is_valid():
					camera_tween.kill()
				camera_tween = create_tween()
				camera_tween.set_parallel(true)
				camera_tween.set_ease(Tween.EASE_IN_OUT)
				camera_tween.set_trans(Tween.TRANS_SINE)
				camera_tween.tween_property(camera, "global_position", cam_point.global_position, 0.6)
				camera_tween.tween_property(camera, "global_rotation", cam_point.global_rotation, 0.6)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		# Animasi kembalikan kamera ke tubuh Player
		if camera_tween and camera_tween.is_valid():
			camera_tween.kill()
		camera_tween = create_tween()
		camera_tween.set_parallel(true)
		camera_tween.set_ease(Tween.EASE_IN_OUT)
		camera_tween.set_trans(Tween.TRANS_SINE)
		camera_tween.tween_property(camera, "position", default_camera_transform.origin, 0.6)
		camera_tween.tween_property(camera, "rotation", default_camera_transform.basis.get_euler(), 0.6)

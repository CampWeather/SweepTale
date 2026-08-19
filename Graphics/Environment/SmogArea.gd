extends Area3D

@export var max_depth_distance: float = 35.0
@export var player_group_name: String = "player"

var _player: Node3D
var _total_initial_trash: int = 0
var _screen_effect_node: Node
var _world_env: WorldEnvironment # Node untuk ngatur Kabut 3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Tunggu frame pertama agar semua node siap
	await get_tree().process_frame
	_total_initial_trash = get_tree().get_nodes_in_group("PileTrash").size()
	
	# Deteksi kalau player ter-spawn di dalam area
	for body in get_overlapping_bodies():
		if body.is_in_group(player_group_name):
			_player = body

func _process(_delta: float) -> void:
	# 1. Pastikan script memegang node UI dan Node Lingkungan (Kabut)
	if _screen_effect_node == null:
		_screen_effect_node = get_tree().get_first_node_in_group("screen_effect")
	if _world_env == null:
		var env_nodes = get_tree().get_nodes_in_group("environment")
		if env_nodes.size() > 0:
			_world_env = env_nodes[0]

	# 2. Hitung Sisa Sampah (Dari 0.0 sampai 1.0)
	var current_trash: int = get_tree().get_nodes_in_group("PileTrash").size()
	var trash_ratio: float = 0.0
	if _total_initial_trash > 0:
		trash_ratio = float(current_trash) / float(_total_initial_trash)

	# ==========================================
	# ALGORITMA 1: SIFAT KABUT (FOG 3D)
	# Kabut menipis tergantung jumlah tumpukan sampah
	# ==========================================
	if _world_env and _world_env.environment:
		# Angka 0.05 ini adalah ketebalan maksimal kabut (bisa kamu ubah sesuka hati)
		_world_env.environment.volumetric_fog_density = trash_ratio * 0.05

	# ==========================================
	# ALGORITMA 2: SIFAT LAYAR (UI SCREEN)
	# Layar menggelap kalau player masuk lebih dalam
	# ==========================================
	if _player and _screen_effect_node:
		var distance_to_center: float = global_position.distance_to(_player.global_position)
		var depth_factor: float = clamp(1.0 - (distance_to_center / max_depth_distance), 0.0, 1.0)
		
		# Tembakkan nilainya ke script UI (DustHitEffect.gd)
		if _screen_effect_node.has_method("update_smog_effect"):
			_screen_effect_node.update_smog_effect(trash_ratio, depth_factor)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(player_group_name):
		_player = body

func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player = null
		# Kalau player kabur dari area, langsung bersihkan layar UI-nya
		if _screen_effect_node and _screen_effect_node.has_method("update_smog_effect"):
			_screen_effect_node.update_smog_effect(0.0, 0.0)

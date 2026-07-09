extends Area3D

@export var player_group_name: String = "player"
@export var particle_node_name: String = "ExplosiveDebu"
@export var trigger_once: bool = false

@export var quest_id: String = "clean_trash_01"
@export var quest_event_type: String = "clean_trash"
@export var quest_target_group: String = "PileTrash"
@export var amount: int = 1

var explosive_debu: GPUParticles3D
var has_triggered: bool = false

var cleaned: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = true

	explosive_debu = _find_particle_by_name(self, particle_node_name)

	if explosive_debu == null:
		push_warning("Particle '%s' tidak ditemukan." % particle_node_name)
		return

	explosive_debu.emitting = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var player_root := _get_player_root(body)

	if player_root == null:
		return

	_trigger_particle()

	if player_root.has_method("play_dust_hit_effect"):
		player_root.play_dust_hit_effect()


func _trigger_particle() -> void:
	if trigger_once and has_triggered:
		return

	has_triggered = true

	explosive_debu.emitting = false
	explosive_debu.restart()
	explosive_debu.emitting = true


func _get_player_root(body: Node) -> Node:
	if body == null:
		return null

	if body.is_in_group(player_group_name):
		return body

	var parent := body.get_parent()

	while parent != null:
		if parent.is_in_group(player_group_name):
			return parent

		parent = parent.get_parent()

	return null


func _find_particle_by_name(root: Node, target_name: String) -> GPUParticles3D:
	if root is GPUParticles3D and root.name == target_name:
		return root

	for child in root.get_children():
		var found := _find_particle_by_name(child, target_name)
		if found != null:
			return found

	return null

func action() -> bool:
	if cleaned:
		return false
	var manager = get_node_or_null("/root/QuestManager")
	if manager == null:
		push_warning("QuestManager not found at /root/QuestManager")
		return false
	if manager.has_method("IsQuestActive") and not manager.IsQuestActive(quest_id):
		print("Clean Trash quest is not active yet.")
		return false
	var target := _get_quest_target_group()
	if manager.has_method("ReportEvent"):
		manager.ReportEvent(quest_event_type, target, amount)
		print("Reported quest event: ", quest_event_type, " / ", target)
	cleaned = true
	queue_free()
	return true

func _get_quest_target_group() -> String:
	if is_in_group("PileTrash"):
		return "PileTrash"
	return quest_target_group

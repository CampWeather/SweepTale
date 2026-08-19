extends Area3D

@export var dialogue_resource: DialogueResource
@export var dialogue_start: String = "start"

@export var dialogue_turn_in_start: String = "clean_trash_turn_in"
@export var dialogue_quest_active_start: String = "clean_trash_active"
@export var dialogue_after_turn_in_start: String = "after_clean_trash"

@export var quest_marker: Node3D 
@export var bubble_dialog: Label3D
@export var bubble_text: String = "Ada yang bisa saya bantu lagi?"

@export var npc_id: String = "NPC_01"
@export var talk_quest_id: String = "talk_to_Kola"

@export var reports_talk_objective: bool = true
@export var gives_follow_up_quest: bool = true

@export var required_completed_quest_id: String = "talk_to_Kola"
@export var follow_up_quest_id: String = "clean_trash_01"
@export var turn_in_quest_id: String = "clean_trash_01"
@export_group("Dialog Camera Position")
@export var dialog_camera_point: Node3D
@export var player_stand_point: Node3D #

var has_interacted: bool = false

const BalloonScene = preload("res://Dialog/Balloon.tscn")


func get_dialog_camera_point() -> Node3D:
	return dialog_camera_point
	
func get_player_stand_point() -> Node3D:
	return player_stand_point
	
func action() -> bool:
	if dialogue_resource == null:
		printerr("GAGAL: Objek ini tidak punya file Dialogue Resource!")
		return false

	if not has_interacted:
		has_interacted = true

		if quest_marker:
			quest_marker.hide()

	var start_key := _get_dialogue_start_key()

	var balloon = BalloonScene.instantiate()
	get_tree().current_scene.add_child(balloon)

	if balloon.has_method("start"):
		balloon.start(dialogue_resource, start_key, [self])
		return true

	return false


func _get_dialogue_start_key() -> String:
	var manager = _get_quest_manager()

	if manager == null:
		return dialogue_start

	if manager.has_method("CanTurnInQuest") and manager.CanTurnInQuest(turn_in_quest_id):
		return dialogue_turn_in_start

	if manager.has_method("IsQuestActive") and manager.IsQuestActive(follow_up_quest_id):
		return dialogue_quest_active_start

	if manager.has_method("IsQuestCompleted") and manager.IsQuestCompleted(turn_in_quest_id):
		return dialogue_after_turn_in_start

	return dialogue_start


func complete_talk_and_start_clean_trash() -> void:
	print("Dialogue command called: complete_talk_and_start_clean_trash")

	var did_report := _report_talk_objective_if_needed()
	var did_start_follow_up := _try_start_follow_up_quest()

	print("Talk quest reported: ", did_report)
	print("Follow-up quest started: ", did_start_follow_up)


func turn_in_follow_up_quest() -> bool:
	var manager = _get_quest_manager()

	if manager == null:
		push_warning("QuestManager not found at /root/QuestManager")
		return false

	if not manager.has_method("CanTurnInQuest"):
		push_warning("QuestManager does not have CanTurnInQuest method.")
		return false

	if not manager.CanTurnInQuest(turn_in_quest_id):
		print("Quest cannot be turned in yet: ", turn_in_quest_id)
		return false

	if not manager.has_method("TurnInQuest"):
		push_warning("QuestManager does not have TurnInQuest method.")
		return false

	manager.TurnInQuest(turn_in_quest_id)
	print("Turned in quest: ", turn_in_quest_id)

	return true


func can_turn_in_follow_up_quest() -> bool:
	var manager = _get_quest_manager()

	if manager == null:
		return false

	if not manager.has_method("CanTurnInQuest"):
		return false

	return manager.CanTurnInQuest(turn_in_quest_id)


func is_follow_up_quest_active() -> bool:
	var manager = _get_quest_manager()

	if manager == null:
		return false

	if not manager.has_method("IsQuestActive"):
		return false

	return manager.IsQuestActive(follow_up_quest_id)


func is_follow_up_quest_completed() -> bool:
	var manager = _get_quest_manager()

	if manager == null:
		return false

	if not manager.has_method("IsQuestCompleted"):
		return false

	return manager.IsQuestCompleted(turn_in_quest_id)


func _get_quest_manager() -> Node:
	return get_node_or_null("/root/QuestManager")


func _report_talk_objective_if_needed() -> bool:
	if not reports_talk_objective:
		return false

	var manager = _get_quest_manager()

	if manager == null:
		push_warning("QuestManager not found at /root/QuestManager")
		return false

	if manager.has_method("IsQuestActive") and not manager.IsQuestActive(talk_quest_id):
		return false

	if manager.has_method("ReportEvent"):
		manager.ReportEvent("talk_npc", npc_id, 1)
		print("Reported talk_npc event for: ", npc_id)
		return true

	return false


func _try_start_follow_up_quest() -> bool:
	if not gives_follow_up_quest:
		return false

	var manager = _get_quest_manager()

	if manager == null:
		push_warning("QuestManager not found at /root/QuestManager")
		return false

	if manager.has_method("IsQuestCompleted") and not manager.IsQuestCompleted(required_completed_quest_id):
		return false

	if manager.has_method("IsQuestActive") and manager.IsQuestActive(follow_up_quest_id):
		return false

	if manager.has_method("IsQuestCompleted") and manager.IsQuestCompleted(follow_up_quest_id):
		return false

	if manager.has_method("StartQuest"):
		manager.StartQuest(follow_up_quest_id)
		print("Started follow-up quest: ", follow_up_quest_id)
		return true

	return false

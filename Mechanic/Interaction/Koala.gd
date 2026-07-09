extends Area3D

@export var dialogue_resource: DialogueResource
@export var dialogue_start: String = "start"

@export var quest_marker: Node3D 
@export var bubble_dialog: Label3D
@export var bubble_text: String = "Ada yang bisa saya bantu lagi?"

@export var npc_id: String = "NPC_01"

@export var talk_quest_id: String = "talk_to_Dzakwan"
@export var reports_talk_objective: bool = true

@export var gives_follow_up_quest: bool = true
@export var required_completed_quest_id: String = "talk_to_Dzakwan"
@export var follow_up_quest_id: String = "clean_trash_01"

var has_interacted: bool = false

const BalloonScene = preload("res://Dialog/Balloon.tscn")


func action() -> bool:
	if not has_interacted:
		has_interacted = true

		if quest_marker:
			quest_marker.hide()

		if dialogue_resource == null:
			printerr("GAGAL: Objek ini tidak punya file Dialogue Resource!")
			return false

		var balloon = BalloonScene.instantiate()
		get_tree().current_scene.add_child(balloon)

		if balloon.has_method("start"):
			# Penting: kirim [self] supaya dialogue bisa memanggil method di Koala.gd
			balloon.start(dialogue_resource, dialogue_start, [self])

		return true

	else:
		if bubble_dialog:
			bubble_dialog.text = bubble_text
			bubble_dialog.show()
			get_tree().create_timer(3.0).timeout.connect(func(): bubble_dialog.hide())

		return false


func complete_talk_and_start_clean_trash() -> void:
	print("Dialogue command called: complete_talk_and_start_clean_trash")

	var did_report := _report_talk_objective_if_needed()

	# Setelah ReportEvent, QuestManager seharusnya langsung menyelesaikan talk quest.
	# Baru setelah itu kita coba mulai follow-up quest.
	var did_start_follow_up := _try_start_follow_up_quest()

	print("Talk quest reported: ", did_report)
	print("Follow-up quest started: ", did_start_follow_up)


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

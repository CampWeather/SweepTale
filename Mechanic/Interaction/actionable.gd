extends Area3D

@export var dialogue_resource: DialogueResource
@export var dialogue_start: String = "start"
@export var quest_marker: Node3D 

@export var bubble_dialog: Label3D
@export var bubble_text: String = "Ada yang bisa saya bantu lagi?"

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
			balloon.start(dialogue_resource, dialogue_start)
			
		return true
		
	else:
		if bubble_dialog:
			bubble_dialog.text = bubble_text
			bubble_dialog.show()
			
			get_tree().create_timer(3.0).timeout.connect(func(): bubble_dialog.hide())
			
		return false

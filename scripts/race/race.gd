extends Node3D
## Prototype race: one swan on a flat beach, no obstacles.

const WARDROBE_SCENE := "res://scenes/wardrobe.tscn"


func _ready() -> void:
	Scenery.add_environment(self)
	Scenery.add_beach(self, 1234)

	var swan := Swan.new()
	swan.brain = PlayerInput.new()
	swan.look = Profile.look
	add_child(swan)

	var camera := ChaseCamera.new()
	camera.target = swan
	add_child(camera)
	camera.make_current()

	var hud := Hud.new()
	hud.swan = swan
	add_child(hud)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().change_scene_to_file(WARDROBE_SCENE)

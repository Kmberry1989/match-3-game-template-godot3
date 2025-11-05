extends Node

const GAME_SCENE_PATH = "res://Scenes/Game.tscn"

func _ready():
	print("[Loading.gd] _ready: Switching to Game scene.")
	# Small defer to let the loading scene appear briefly
	yield(get_tree().create_timer(0.05), "timeout")
	var err = get_tree().change_scene(GAME_SCENE_PATH)
	if err != OK:
		push_error("[Loading.gd] Failed to change scene to: " + GAME_SCENE_PATH)

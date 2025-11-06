extends Node

onready var trophy_notification = $CanvasLayer/TrophyNotification
onready var PlayerManager = get_node_or_null("/root/PlayerManager")
onready var AudioManager = get_node_or_null("/root/AudioManager")

func _ready():
	print("[Game.gd] _ready: Starting.")
	# Ensure Milestone plugin points to our Godot 3 achievements
	if ProjectSettings.has_setting("milestone/general/achievements_path") == false or String(ProjectSettings.get_setting("milestone/general/achievements_path")) != "res://Assets/Trophies/Achievements":
		ProjectSettings.set_setting("milestone/general/achievements_path", "res://Assets/Trophies/Achievements")
		var am = get_node_or_null("/root/AchievementManager")
		if am and am.has_method("load_achievements"):
			# Reload achievements from the corrected path
			am.load_achievements()
	if PlayerManager != null:
		PlayerManager.connect("trophy_unlocked", self, "_on_trophy_unlocked")
	var am2 = get_node_or_null("/root/AchievementManager")
	if am2:
		am2.connect("achievement_unlocked", self, "_on_achievement_unlocked")
	if AudioManager != null:
		print("[Game.gd] _ready: Playing in-game music.")
		AudioManager.play_music("ingame")
	print("[Game.gd] _ready: Finished.")

func _on_trophy_unlocked(trophy_resource):
	print("[Game.gd] _on_trophy_unlocked: A trophy was unlocked.")
	trophy_notification.show_notification(trophy_resource)

func _on_achievement_unlocked(achievement_id):
	var am = get_node_or_null("/root/AchievementManager")
	if am and am.has_method("get_achievement_resource"):
		var achievement_resource = am.get_achievement_resource(achievement_id)
		if achievement_resource != null:
			trophy_notification.show_notification(achievement_resource)

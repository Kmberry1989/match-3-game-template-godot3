extends Node

onready var trophy_notification = $CanvasLayer/TrophyNotification

func _ready():
	print("[Game.gd] _ready: Starting.")
	if PlayerManager != null:
		PlayerManager.connect("trophy_unlocked", self, "_on_trophy_unlocked")
	if Engine.has_singleton("AchievementManager") or (typeof(AchievementManager) != TYPE_NIL):
		AchievementManager.connect("achievement_unlocked", self, "_on_achievement_unlocked")
	if AudioManager != null:
		print("[Game.gd] _ready: Playing in-game music.")
		AudioManager.play_music("ingame")
	print("[Game.gd] _ready: Finished.")

func _on_trophy_unlocked(trophy_resource):
	print("[Game.gd] _on_trophy_unlocked: A trophy was unlocked.")
	trophy_notification.show_notification(trophy_resource)

func _on_achievement_unlocked(achievement_id):
	var achievement_resource = AchievementManager.get_achievement_resource(achievement_id)
	if achievement_resource != null:
		trophy_notification.show_notification(achievement_resource)

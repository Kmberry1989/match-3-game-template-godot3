extends Node

## The achievements available in the game.
var achievements_list = {}

## How many achievements are available.
var achievements_number = 0

## How many hidden achievements are available.
var hidden_achievements_number = 0

## How many achievements are unlocked.
var unlocked_achievements_number = 0

## The achievements the player has unlocked/progressed.
var achievements = {}

signal achievement_unlocked(achievement_id)
signal achievement_progressed(achievement_id, progress_amount)
signal achievement_reset(achievement_id)

signal achievements_reset
signal achievements_loaded

func _ready():
	load_achievements()
	achievements_list = get_achievements()
	achievements_number = achievements_list.size()
	hidden_achievements_number = get_hidden_achievements().size()

	if OS.is_debug_build() and ProjectSettings.has_setting("milestone/debug/print_output") and ProjectSettings.get_setting("milestone/debug/print_output") == true:
		print("[Milestone] Loaded %s achievements!" % achievements_number)

func get_achievement_resource(achievement_id):
	if not ProjectSettings.has_setting("milestone/general/achievements_path"):
		return null
	var base = str(ProjectSettings.get_setting("milestone/general/achievements_path"))
	var path = base + "/" + achievement_id + ".tres"
	var achievement = load(path)

	if achievement is Achievement:
		return achievement
	else:
		return null


## Unlocks the achievement with the given ID.
func unlock_achievement(achievement_id, save_on_unlock=true):
	var achievement = get_achievement_resource(achievement_id)
	if achievement:
		if not achievements.has(achievement_id):
			achievements[achievement_id] = {
				"unlocked": false,
				"unlocked_date": 0,
				"progress": 0,
			}
		if achievements[achievement_id]["unlocked"] == false:
			achievements[achievement_id]["progress"] = achievement.progress_goal
			achievements[achievement_id]["unlocked"] = true
			achievements[achievement_id]["unlocked_date"] = Time.get_unix_time_from_system()

			emit_signal("achievement_unlocked", achievement_id)

		if OS.is_debug_build() and ProjectSettings.has_setting("milestone/debug/print_output") and ProjectSettings.get_setting("milestone/debug/print_output") == true:
			print("[Milestone] Achievement '%s' was unlocked!" % achievement_id)
			print("[Milestone] Unlocked %s/%s achievements" % [get_unlocked_achievements().size(), achievements_number])
		if save_on_unlock:
			save_achievements()
	else:
		if OS.is_debug_build() and ProjectSettings.has_setting("milestone/debug/print_errors") and ProjectSettings.get_setting("milestone/debug/print_errors") == true:
			push_error("[Milestone] Could not find achievement with ID '%s'" % achievement_id)

## Progresses the achievement with the given ID using the specified progress amount.
func progress_achievement(achievement_id, progress_amount=1):
	var achievement = get_achievement_resource(achievement_id)
	if achievement:
		if not achievements.has(achievement_id):
			achievements[achievement_id] = {
				"unlocked": false,
				"unlocked_date": 0,
				"progress": 0,
			}

		if achievements[achievement_id]["unlocked"]:
			return

		if achievement.progressive:
			achievements[achievement_id]["progress"] = int(min(achievements[achievement_id]["progress"] + progress_amount, achievement.progress_goal))

			if achievements[achievement_id]["progress"] >= achievement.progress_goal:
				achievements[achievement_id]["unlocked"] = true
				achievements[achievement_id]["unlocked_date"] = Time.get_unix_time_from_system()

				emit_signal("achievement_unlocked", achievement_id)

			if OS.is_debug_build() and ProjectSettings.has_setting("milestone/debug/print_output") and ProjectSettings.get_setting("milestone/debug/print_output") == true:
				print("[Milestone] Achievement '%s' was unlocked! (%s/%s)" % [achievement_id, achievements[achievement_id]["progress"], achievement.progress_goal])
				print("[Milestone] Unlocked %s/%s achievements" % [get_unlocked_achievements().size(), achievements_number])
			else:
				emit_signal("achievement_progressed", achievement_id, progress_amount)

			if OS.is_debug_build() and ProjectSettings.has_setting("milestone/debug/print_output") and ProjectSettings.get_setting("milestone/debug/print_output") == true:
				print("[Milestone] Achievement '%s' progressed to (%s/%s)" % [achievement_id, achievements[achievement_id]["progress"], achievement.progress_goal])
		else:
			achievements[achievement_id]["unlocked"] = true
			achievements[achievement_id]["unlocked_date"] = Time.get_unix_time_from_system()

			emit_signal("achievement_unlocked", achievement_id)

			if OS.is_debug_build() and ProjectSettings.has_setting("milestone/debug/print_output") and ProjectSettings.get_setting("milestone/debug/print_output") == true:
				print("[Milestone] Achievement '%s' was unlocked!" % achievement_id)
				print("[Milestone] Unlocked %s/%s achievements" % [unlocked_achievements_number, achievements_number])
		save_achievements()
	else:
		if ProjectSettings.get_setting("milestone/debug/print_errors") == true and OS.is_debug_build():
			push_error("[Milestone] Could not find achievement with ID '%s'" % achievement_id)

## Progresses all achievements in the specified group by the given amount.
func progress_group(group_id, amount = 1) :
	for achievement_id in achievements_list.keys():
		var achievement_res = get_achievement_resource(achievement_id)
		if achievement_res and achievement_res.group == group_id and not is_unlocked(achievement_id):
			progress_achievement(achievement_id, amount)
	
## Returns an achievement dictionary.
func get_achievement(achievement_id) :
	if not achievements.has(achievement_id) and achievements_list.has(achievement_id):
		achievements[achievement_id] = {
			"unlocked": false,
			"unlocked_date": 0,
			"progress": 0,
		}
		return achievements[achievement_id]
	elif achievements.has(achievement_id) and achievements_list.has(achievement_id):
		return achievements[achievement_id]
	else:
		if ProjectSettings.get_setting("milestone/debug/print_errors") == true and OS.is_debug_build():
			print("[Milestone] Couldn't find an achievement with the ID: %s" % achievement_id)
		return {}
	
## Returns an array of achievement resources belonging to the given group.
func get_achievements_by_group(group_id):
	var group_achievements = []

	for achievement_id in achievements_list.keys():
		var achievement_res = get_achievement_resource(achievement_id)
		if achievement_res.group:
			if achievement_res and achievement_res.group == group_id:
				group_achievements.append(achievement_res)

	if group_achievements.empty():
		if ProjectSettings.get_setting("milestone/debug/print_errors") == true and OS.is_debug_build():
			print("[Milestone] Couldn't find any achievements in the group: %s" % group_id)

	return group_achievements
	
## Resets all achievements.
func reset_achievements():
	if achievements.empty():
		return
	achievements.clear()
	save_achievements()
	emit_signal("achievements_reset")
	if ProjectSettings.get_setting("milestone/debug/print_output") == true and OS.is_debug_build():
		print("[Milestone] Reset all achievements!")

## Unlocks all achievements.
func unlock_all_achievements():
	for i in achievements_list:
		unlock_achievement(i, false)
	
	save_achievements()

## Returns true if the achievement is unlocked.
func is_unlocked(achievement_id) -> bool:
	if achievements.has(achievement_id):
		return achievements[achievement_id]["unlocked"]
	else:
		return false

## Returns the progress of the achievement.
func get_progress(achievement_id) -> int:
	if achievements.has(achievement_id) and achievements_list.has(achievement_id):
		return achievements[achievement_id].progress
	elif !achievements.has(achievement_id) and achievements_list.has(achievement_id):
		if ProjectSettings.get_setting("milestone/debug/print_errors") == true and OS.is_debug_build():
			print("[Milestone] Couldn't find an achievement with the ID: %s" % achievement_id)
		return 0
	else:
		if ProjectSettings.get_setting("milestone/debug/print_errors") == true and OS.is_debug_build():
			print("[Milestone] Couldn't find an achievement with the ID: %s" % achievement_id)
		return 0

func reset_achievement(achievement_id) :
	achievements.erase(achievement_id)
	save_achievements()
	emit_signal("achievement_reset", achievement_id)
	if ProjectSettings.get_setting("milestone/debug/print_output") == true and OS.is_debug_build():
		print("[Milestone] Cleared achievement %s!" % achievement_id)

func get_unlocked_achievements():
	var _achievements = {}
	for achievement_id in achievements:
		if achievements[achievement_id]["unlocked"]:
			_achievements[achievement_id] = achievements[achievement_id]
	return _achievements

func get_hidden_achievements():
	var _achievements = {}
	for achievement_id in achievements_list:
		if achievements_list[achievement_id]["hidden"]:
			_achievements[achievement_id] = achievements_list[achievement_id]
	return _achievements

func get_achievements():
	var _achievements = {}
	if not ProjectSettings.has_setting("milestone/general/achievements_path"):
		return _achievements
	var base_path = str(ProjectSettings.get_setting("milestone/general/achievements_path"))
	var dir = Directory.new()
	if dir.open(base_path) != OK:
		return _achievements
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if not dir.current_is_dir():
			var fname = file.replace(".remap", "")
			var ext = fname.get_extension()
			if ext == "tres" or ext == "res":
				var resource = load(base_path + "/" + fname)
				if resource is Achievement:
					_achievements[resource.id] = resource
		file = dir.get_next()
	dir.list_dir_end()
	return _achievements

## Saves all achievements to user://achievements.json. It's recommended to encrypt achievements if you don't want an average user to be able to modify them.
func save_achievements():
	if ProjectSettings.has_setting("milestone/general/save_as_json") and ProjectSettings.get_setting("milestone/general/save_as_json") == true:
		var f = File.new()
		if f.open("user://achievements.json", File.WRITE) == OK:
			f.store_string(JSON.print(achievements))
			f.close()


## Loads all achievements from user://achievements.json. It's recommended to encrypt achievements if you don't want an average user to be able to modify them.
func load_achievements():
	if ProjectSettings.has_setting("milestone/general/save_as_json") and ProjectSettings.get_setting("milestone/general/save_as_json") == true:
		var f = File.new()
		if f.file_exists("user://achievements.json"):
			if f.open("user://achievements.json", File.READ) == OK:
				var json_text = f.get_as_text()
				f.close()
				if json_text != "":
					var parsed = JSON.parse(json_text)
					if parsed.error == OK and typeof(parsed.result) == TYPE_DICTIONARY:
						achievements = parsed.result
						call_deferred("emit_signal", "achievements_loaded")

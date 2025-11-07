extends Node

# Built-in achievement/trophy manager (no external plugin dependency at runtime)

signal achievement_unlocked(id)

var achievements = {} # id -> { id, name, description, progressive, goal, interval, icon_path, locked_icon_path }
var progress = {} # id -> int

onready var PlayerManager = get_node_or_null("/root/PlayerManager")

func _ready():
	_load_achievements()
	# Load persisted progress if PlayerManager has it
	if PlayerManager != null and typeof(PlayerManager.player_data) == TYPE_DICTIONARY:
		progress = PlayerManager.player_data.get("achievement_progress", {})

func _load_achievements():
	achievements.clear()
	var dir = Directory.new()
	if dir.open("res://Assets/Trophies/Achievements") != OK:
		return
	dir.list_dir_begin()
	var fn = dir.get_next()
	while fn != "":
		if not dir.current_is_dir() and fn.to_lower().ends_with(".tres"):
			var id = fn.substr(0, fn.length() - 5) # remove .tres
			var data = _build_achievement_from_id(id)
			achievements[id] = data
		fn = dir.get_next()
	dir.list_dir_end()

func _build_achievement_from_id(id: String) -> Dictionary:
	# Fallback default values; try to enrich from the .tres if it loads
	var base = id.replace("_", " ")
	var name = _title_case(base)
	var icon_base = id.replace("_", "")
	var icon_path = "res://Assets/Trophies/trophy_" + icon_base + ".png"
	var locked_path = "res://Assets/Trophies/trophy_" + icon_base + "_locked.png"
	var d: Dictionary = {
		"id": id,
		"name": name,
		"description": "",
		"progressive": false,
		"goal": 0,
		"interval": 0,
		"icon_path": icon_path,
		"locked_icon_path": locked_path
	}
	# If the .tres can be loaded, use its metadata (optional, safe)
	var tres_path = "res://Assets/Trophies/Achievements/" + id + ".tres"
	if ResourceLoader.exists(tres_path):
		var res = load(tres_path)
		if res != null:
			if res.has_method("get"): # generic Object supports get()
				var v
				v = res.get("id"); if v != null: d.id = String(v)
				v = res.get("name"); if v != null: d.name = _title_case(String(v))
				v = res.get("description"); if v != null: d.description = String(v)
				v = res.get("progressive"); if v != null: d.progressive = bool(v)
				v = res.get("progress_goal"); if v != null: d.goal = int(v)
				v = res.get("indicate_progress_interval"); if v != null: d.interval = int(v)
				v = res.get("icon")
				if v != null and v is Resource and v.has_method("get_path"):
					# In Godot 3 textures expose resource_path
					var ip = String(v.resource_path)
					if ip != "":
						d.icon_path = ip
				v = res.get("unachieved_icon")
				if v != null and v is Resource and v.has_method("get_path"):
					var lp = String(v.resource_path)
					if lp != "":
						d.locked_icon_path = lp
	return d

func _title_case(s: String) -> String:
	var text = String(s).strip_edges()
	if text == "":
		return text
	var words = text.to_lower().split(" ")
	var out = []
	for w in words:
		if w.length() == 0:
			continue
		out.append(w.substr(0,1).to_upper() + w.substr(1))
	return String(" ").join(out)

func get_all_trophies() -> Array:
	# Return a stable, sorted list of achievement dicts
	var ids = achievements.keys()
	ids.sort()
	var arr = []
	for id in ids:
		arr.append(achievements[id])
	return arr

func get_achievements() -> Array:
	# Compatibility for Showcase.gd: return list of IDs
	var ids = achievements.keys()
	ids.sort()
	return ids

func get_achievement_resource(id: String):
	# Compatibility for Showcase.gd: return the .tres resource if available
	var tres_path = "res://Assets/Trophies/Achievements/" + id + ".tres"
	if ResourceLoader.exists(tres_path):
		return load(tres_path)
	return null

func is_unlocked(id: String) -> bool:
	if PlayerManager == null:
		return false
	var unlocked: Array = PlayerManager.player_data.get("unlocks", {}).get("trophies", [])
	return unlocked.has(id)

func get_progress(id: String) -> int:
	return int(progress.get(id, 0))

func get_goal(id: String) -> int:
	if achievements.has(id):
		return int(achievements[id].get("goal", 0))
	return 0

func is_progressive(id: String) -> bool:
	if achievements.has(id):
		return bool(achievements[id].get("progressive", false))
	return false

func progress_achievement(id: String, amount: int) -> void:
	if amount == 0:
		return
	if not achievements.has(id):
		return
	var cur = int(progress.get(id, 0)) + int(amount)
	progress[id] = cur
	# Persist progress for durability
	_save_progress()
	# Auto-unlock if progressive and meets goal
	var ach = achievements[id]
	if bool(ach.get("progressive", false)) and int(ach.get("goal", 0)) > 0 and cur >= int(ach.get("goal", 0)):
		unlock_achievement(id)

func unlock_achievement(id: String) -> void:
	if PlayerManager == null:
		return
	# Ensure trophy list exists
	if not PlayerManager.player_data.has("unlocks"):
		PlayerManager.player_data["unlocks"] = {"trophies": [], "frames": [], "aliases": []}
	if not PlayerManager.player_data["unlocks"].has("trophies"):
		PlayerManager.player_data["unlocks"]["trophies"] = []
	var trophies: Array = PlayerManager.player_data["unlocks"]["trophies"]
	if not id in trophies:
		trophies.append(id)
		PlayerManager.player_data["unlocks"]["trophies"] = trophies
		PlayerManager.save_player_data()
		emit_signal("achievement_unlocked", id)
		_show_unlock_toast(id)

func _save_progress():
	if PlayerManager != null:
		var pd = PlayerManager.player_data
		pd["achievement_progress"] = progress
		PlayerManager.player_data = pd
		PlayerManager.save_player_data()

func _show_unlock_toast(id: String) -> void:
	var ach = achievements.get(id, null)
	var scene = get_tree().current_scene
	if scene == null:
		return
	var layer = CanvasLayer.new()
	layer.name = "AchievementToast_" + id
	scene.add_child(layer)

	var root = Control.new()
	root.anchor_left = 1
	root.anchor_right = 1
	root.anchor_top = 0
	root.anchor_bottom = 0
	root.margin_right = -16
	root.margin_top = 16
	layer.add_child(root)

	var panel = PanelContainer.new()
	panel.add_stylebox_override("panel", _make_panel_style())
	root.add_child(panel)

	var h = HBoxContainer.new()
	h.add_constant_override("separation", 12)
	panel.add_child(h)

	var icon = TextureRect.new()
	icon.expand = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path = ""
	if ach != null:
		icon_path = String(ach.get("icon_path", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	h.add_child(icon)

	var v = VBoxContainer.new()
	h.add_child(v)

	var title = Label.new()
	title.text = "Achievement Unlocked!"
	title.add_color_override("font_color", Color(1,1,0.6))
	v.add_child(title)

	var name = Label.new()
	if ach != null:
		name.text = _title_case(String(ach.get("name", id)))
	else:
		name.text = _title_case(id.replace("_", " "))
	v.add_child(name)

	# Play a short sound (prefer plugin asset if present)
	var sound_path = "res://addons/milestone/sounds/achievement_unlocked.wav"
	if ResourceLoader.exists(sound_path):
		var asp = AudioStreamPlayer.new()
		asp.stream = load(sound_path)
		layer.add_child(asp)
		asp.play()

	# Start slide-in, then fade-out
	panel.rect_min_size = Vector2(360, 88)
	panel.rect_scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(panel, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(panel, "rect_scale", Vector2(1,1), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	yield(t, "finished")

	var hold = create_tween()
	yield(hold.tween_interval(1.2), "finished")

	var t2 = create_tween()
	t2.set_parallel(true)
	t2.tween_property(panel, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t2.tween_property(panel, "rect_scale", Vector2(0.96,0.96), 0.3)
	yield(t2, "finished")
	layer.queue_free()

func _make_panel_style() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0,0,0,0.8)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(1,1,1,0.15)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

extends Panel

onready var tab_container = $VBoxContainer/TabContainer
onready var trophy_grid = $VBoxContainer/TabContainer/Trophies/Scroll/TrophyGrid
onready var viewer_overlay = $ViewerOverlay
onready var viewer_image = $ViewerOverlay/Center/VBox/LargeImage
onready var viewer_label = $ViewerOverlay/Center/VBox/ItemLabel
var viewer_desc: Label = null

var achievements: Array = [] # [{id, path, unlocked_icon, locked_icon, name, unlocked, description}]
var current_index: int = -1

var _drag_active = false
var _drag_start = Vector2.ZERO

func _ready():
	# Only show achievements in the showcase
	load_achievements()
	# Refresh when an achievement unlocks at runtime
	var am = get_node_or_null("/root/AchievementManager")
	if am != null and not am.is_connected("achievement_unlocked", self, "_on_achievement_unlocked"):
		am.connect("achievement_unlocked", self, "_on_achievement_unlocked")
	# Make tabs and back button larger for easier tapping
	tab_container.rect_scale = Vector2(1.4, 1.4)
	# Hide/disable any Frames tab if present in the scene
	var frames_tab = tab_container.get_node_or_null("Frames")
	if frames_tab:
		frames_tab.visible = false
		frames_tab.queue_free()
	# Make back button behavior/layout match Shop
	var root_vbox = tab_container.get_parent() as VBoxContainer
	if root_vbox != null:
		root_vbox.alignment = BoxContainer.ALIGN_CENTER
		var back_btn: Button = root_vbox.get_node_or_null("BackButton")
		if back_btn == null:
			back_btn = Button.new()
			back_btn.name = "BackButton"
			back_btn.text = "Back"
			back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			root_vbox.add_child(back_btn)
		else:
			back_btn.text = "Back"
			back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		# Enlarge the back button
		back_btn.rect_scale = Vector2(2.0, 2.0)
		back_btn.rect_min_size = Vector2(180, 64)
		if not back_btn.is_connected("pressed", self, "_on_back_button_pressed"):
			back_btn.connect("pressed", self, "_on_back_button_pressed")
	# Ensure a description label exists under the viewer name label
	if is_instance_valid(viewer_label):
		var vb = viewer_label.get_parent()
		if vb != null:
			viewer_desc = vb.get_node_or_null("DescLabel")
			if viewer_desc == null:
				viewer_desc = Label.new()
				viewer_desc.name = "DescLabel"
				viewer_desc.align = Label.ALIGN_CENTER
				# Optional: wrap long descriptions
				viewer_desc.autowrap = true
				vb.add_child(viewer_desc)

func load_achievements():
	# Populate from AchievementManager if present; otherwise scan filesystem and show locked images
	achievements.clear()
	for child in trophy_grid.get_children():
		child.queue_free()

	var am = get_node_or_null("/root/AchievementManager")
	var pm = get_node_or_null("/root/PlayerManager")
	var unlocked_ids: Array = []
	if pm != null and typeof(pm.player_data) == TYPE_DICTIONARY:
		unlocked_ids = pm.player_data.get("unlocks", {}).get("trophies", [])

	var ids: Array = []
	if am != null and am.has_method("get_achievements"):
		ids = am.get_achievements()
	# Fallback: scan the achievements folder for .tres files
	if ids.size() == 0:
		var d = Directory.new()
		if d.open("res://Assets/Trophies/Achievements") == OK:
			d.list_dir_begin()
			var fn = d.get_next()
			while fn != "":
				if not d.current_is_dir() and fn.to_lower().ends_with(".tres"):
					ids.append(fn.substr(0, fn.length() - 5))
				fn = d.get_next()
			d.list_dir_end()
	ids.sort()

	for achievement_id in ids:
		var id: String = String(achievement_id)
		var res = null
		if am != null and am.has_method("get_achievement_resource"):
			res = am.get_achievement_resource(id)
		if res == null:
			var p = "res://Assets/Trophies/Achievements/" + id + ".tres"
			if ResourceLoader.exists(p):
				res = load(p)
		var display: String = id.replace("_", " ")
		var unlocked := false
		if am != null and am.has_method("is_unlocked"):
			unlocked = am.is_unlocked(id)
		elif unlocked_ids != null:
			unlocked = unlocked_ids.has(id)

		var unlocked_icon = null
		var locked_icon = null
		if typeof(res) == TYPE_OBJECT and res != null:
			if res.has_method("get"):
				var dv = res.get("name")
				if dv != null:
					display = String(dv)
				var ui = res.get("icon")
				if ui != null:
					unlocked_icon = ui
				var li = res.get("unachieved_icon")
				if li != null:
					locked_icon = li
		if unlocked_icon == null or locked_icon == null:
			var base = id.replace("_", "")
			var upath = "res://Assets/Trophies/trophy_" + base + ".png"
			var lpath = "res://Assets/Trophies/trophy_" + base + "_locked.png"
			if unlocked_icon == null and ResourceLoader.exists(upath):
				unlocked_icon = load(upath)
			if locked_icon == null and ResourceLoader.exists(lpath):
				locked_icon = load(lpath)

		var display_icon = unlocked_icon if unlocked else locked_icon
		if display_icon == null:
			display_icon = unlocked_icon
		if display_icon == null:
			continue

		display = _title_case(display)
		var desc_text = ""
		if res != null and res.has_method("get"):
			var dv2 = res.get("description")
			if dv2 != null:
				desc_text = String(dv2)
		# Pull progress/goal from AchievementManager if available
		var cur = 0
		var goal = 0
		var progressive = false
		if am != null:
			if am.has_method("get_progress"):
				cur = int(am.get_progress(id))
			if am.has_method("get_goal"):
				goal = int(am.get_goal(id))
			if am.has_method("is_progressive"):
				progressive = bool(am.is_progressive(id))
		var item = {
			"id": id,
			"unlocked_icon": unlocked_icon,
			"locked_icon": locked_icon,
			"name": display,
			"unlocked": unlocked,
			"description": desc_text,
			"progress": cur,
			"goal": goal,
			"progressive": progressive
		}
		var idx = achievements.size()
		achievements.append(item)
		_add_thumbnail(trophy_grid, display_icon, display, unlocked, idx)

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

# Frames are no longer shown here; Showcase is trophy-only

func _add_thumbnail(container: GridContainer, tex: Texture, label_text: String, unlocked: bool, idx):
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var thumb = TextureRect.new()
	thumb.texture = tex
	thumb.rect_min_size = Vector2(128, 128)
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.mouse_filter = Control.MOUSE_FILTER_STOP
	thumb.connect("gui_input", self, "_on_thumb_gui_input", [idx])
	var lbl = Label.new()
	lbl.text = label_text
	lbl.align = Label.ALIGN_CENTER
	var status_text = ("UNLOCKED" if unlocked else "LOCKED")
	lbl.hint_tooltip = status_text
	thumb.hint_tooltip = status_text
	vb.add_child(thumb)
	vb.add_child(lbl)
	container.add_child(vb)

func _on_thumb_gui_input(event, idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		_open_viewer(int(idx))

func _open_viewer(index: int):
	current_index = index
	_update_viewer()
	viewer_overlay.visible = true

func _close_viewer():
	viewer_overlay.visible = false
	current_index = -1

func _update_viewer():
	if current_index < 0:
		return
	if current_index >= 0 and current_index < achievements.size():
		var item = achievements[current_index]
		var unlocked = item.get("unlocked", false)
		
		var display_icon = item["unlocked_icon"] if unlocked else item["locked_icon"]
		if display_icon == null:
			display_icon = item["unlocked_icon"]
		
		viewer_image.texture = display_icon
		var status_text = ("UNLOCKED" if unlocked else "LOCKED")
		viewer_label.text = item["name"]
		if viewer_desc != null:
			var lines = []
			var desc = String(item.get("description", ""))
			if desc != "":
				lines.append(desc)
			var progressive = bool(item.get("progressive", false))
			var goal = int(item.get("goal", 0))
			var cur = int(item.get("progress", 0))
			if progressive and goal > 0:
				lines.append("Progress: %d / %d" % [cur, goal])
			lines.append("Status: " + status_text)
			viewer_desc.text = "\n".join(lines)
			viewer_desc.hint_tooltip = status_text
		viewer_label.hint_tooltip = status_text
		viewer_image.hint_tooltip = status_text

func _on_achievement_unlocked(_id):
	load_achievements()

func _viewer_next():
	if achievements.size() == 0:
		return
	current_index = (current_index + 1) % achievements.size()
	_update_viewer()

func _viewer_prev():
	if achievements.size() == 0:
		return
	current_index = (current_index - 1 + achievements.size()) % achievements.size()
	_update_viewer()

func _input(event):
	if not viewer_overlay.visible:
		return
	if event is InputEventMouseButton:
		# Close viewer when tapping outside the large image
		if event.button_index == BUTTON_LEFT and event.pressed:
			var r = Rect2(viewer_image.rect_global_position, viewer_image.rect_size)
			if not r.has_point(event.position):
				_close_viewer()
				accept_event()
				return
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				_drag_active = true
				_drag_start = event.position
			else:
				if _drag_active:
					var delta = event.position - _drag_start
					_drag_active = false
					if abs(delta.x) > 60:
						if delta.x > 0:
							_viewer_prev()
						else:
							_viewer_next()
					else:
						_viewer_next()
	elif event is InputEventScreenTouch:
		# Close viewer when tapping outside the large image
		if event.pressed:
			var r2 = Rect2(viewer_image.rect_global_position, viewer_image.rect_size)
			if not r2.has_point(event.position):
				_close_viewer()
				accept_event()
				return
		if event.pressed:
			_drag_active = true
			_drag_start = event.position
		else:
			if _drag_active:
				var delta = event.position - _drag_start
				_drag_active = false
				if abs(delta.x) > 60:
					if delta.x > 0:
						_viewer_prev()
					else:
						_viewer_next()
				else:
					_viewer_next()
	elif event.is_action_pressed("ui_right"):
		_viewer_next()
	elif event.is_action_pressed("ui_left"):
		_viewer_prev()
	elif event.is_action_pressed("ui_cancel"):
		_close_viewer()

func _on_back_button_pressed():
	get_tree().change_scene("res://Scenes/Menu.tscn")


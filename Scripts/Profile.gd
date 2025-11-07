extends Control

onready var player_name_label = $MarginContainer/VBoxContainer/PlayerNameLabel
onready var time_played_label = $MarginContainer/VBoxContainer/TimePlayedLabel
onready var level_label = $MarginContainer/VBoxContainer/LevelLabel
onready var xp_label = $MarginContainer/VBoxContainer/XpLabel
onready var best_combo_label = $MarginContainer/VBoxContainer/BestComboLabel
onready var lines_cleared_label = $MarginContainer/VBoxContainer/LinesClearedLabel
onready var avatar_texture_rect = $MarginContainer/VBoxContainer/HBoxContainer/AvatarFrame/Avatar
onready var avatar_frame_rect = $MarginContainer/VBoxContainer/HBoxContainer/AvatarFrame
onready var file_dialog = $FileDialog
onready var objectives_container = $MarginContainer/VBoxContainer/ObjectivesContainer
onready var trophies_container = $MarginContainer/VBoxContainer/TrophiesContainer
onready var frame_selection_button = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/FrameSelection
onready var change_avatar_button = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/ChangeAvatarButton
onready var back_button = $MarginContainer/VBoxContainer/BackButton

onready var PlayerManager = get_node_or_null("/root/PlayerManager")

# Gallery state for built-in avatars
var _avatar_paths: Array = []
var _avatar_index: int = 0
var _avatar_label: Label = null
var _frame_overlay: TextureRect = null

func _ready():
	# Build cyclable gallery of avatar options from Assets/Dots/*avatar.png first
	_build_avatar_gallery()
	# Then populate labels and preview, guarding for missing PlayerManager
	display_player_data()
	# Ensure a frame overlay exists so the frame draws on top of the avatar
	_ensure_frame_overlay()
	# Refresh trophies when achievements unlock mid-session
	var AchMgr = get_node_or_null("/root/AchievementManager")
	if AchMgr != null and not AchMgr.is_connected("achievement_unlocked", self, "_on_achievement_unlocked"):
		AchMgr.connect("achievement_unlocked", self, "_on_achievement_unlocked")
	# Rebuild UI: add Prev/Next and a label below
	var right_box = change_avatar_button.get_parent()
	var insert_at = 0
	if right_box != null:
		# Create nav row (Prev | Next)
		var nav = HBoxContainer.new()
		nav.add_constant_override("separation", 8)
		var prev_btn = Button.new()
		prev_btn.text = "\u25C0 Prev"
		prev_btn.connect("pressed", self, "_on_prev_avatar")
		# Reuse existing ChangeAvatarButton as Next
		change_avatar_button.text = "Next \u25B6"
		if change_avatar_button.is_connected("pressed", self, "_on_change_avatar_pressed"):
			change_avatar_button.disconnect("pressed", self, "_on_change_avatar_pressed")
		if not change_avatar_button.is_connected("pressed", self, "_on_cycle_avatar"):
			change_avatar_button.connect("pressed", self, "_on_cycle_avatar")
		insert_at = right_box.get_children().find(change_avatar_button)
		right_box.remove_child(change_avatar_button)
		nav.add_child(prev_btn)
		nav.add_child(change_avatar_button)
		right_box.add_child(nav)
		right_box.move_child(nav, max(0, insert_at))
		# Add label just below nav and above frame selector
		_avatar_label = Label.new()
		_avatar_label.align = Label.ALIGN_CENTER
		right_box.add_child(_avatar_label)
		var frame_idx = right_box.get_children().find(frame_selection_button)
		if frame_idx != -1:
			right_box.move_child(_avatar_label, frame_idx)

	back_button.connect("pressed", self, "_on_back_button_pressed")
	# Enlarge back button for easier taps
	if is_instance_valid(back_button):
		back_button.rect_scale = Vector2(2.0, 2.0)
		back_button.rect_min_size = Vector2(180, 64)
	frame_selection_button.connect("item_selected", self, "_on_frame_selected")

func display_player_data():
	# Fallback path if PlayerManager is unavailable
	if PlayerManager == null:
		player_name_label.text = "Name: Player"
		time_played_label.text = "Time Played: 00:00:00"
		level_label.text = "Level: 1"
		xp_label.text = "XP: 0/0"
		best_combo_label.text = "Best Combo: 0"
		lines_cleared_label.text = "Dots Cleared: 0"
		# Preview first built-in avatar if available
		if _avatar_paths.size() > 0:
			var p = _avatar_paths[_avatar_index]
			_preview_avatar_res(p)
			_update_avatar_label_from_path(p)
		# Disable frame selection without PlayerManager
		if is_instance_valid(frame_selection_button):
			frame_selection_button.disabled = true
		# Set default frame visual on overlay (draw above avatar)
		_set_profile_frame_texture("res://Assets/Visuals/Avatar Frames/avatar_frame_2.png")
		return

	# Normal path with PlayerManager available
	var data = PlayerManager.player_data
	player_name_label.text = "Name: " + data["player_name"]
	# Ensure integer seconds for modulo ops
	var time_played: int = int(round(float(data.get("time_played", 0))))
	var hours = int(time_played / 3600)
	var minutes = int((time_played % 3600) / 60)
	var seconds = time_played % 60
	time_played_label.text = "Time Played: %02d:%02d:%02d" % [hours, minutes, seconds]
	level_label.text = "Level: " + str(data["current_level"])
	xp_label.text = "XP: " + str(data["current_xp"]) + "/" + str(PlayerManager.get_xp_for_next_level())
	best_combo_label.text = "Best Combo: " + str(data["best_combo"])
	lines_cleared_label.text = "Dots Cleared: " + str(data["total_lines_cleared"])
	
	# Load avatar
	var avatar_path = "user://avatars/" + _get_player_name_fallback() + ".png"
	if File.new().file_exists(avatar_path):
		var img = Image.new()
		if img.load(avatar_path) == OK:
			var tex = ImageTexture.new()
			tex.create_from_image(img)
			avatar_texture_rect.texture = tex
	elif _avatar_paths.size() > 0:
		# Preview first built-in if no user avatar yet
		var p = _avatar_paths[_avatar_index]
		_preview_avatar_res(p)
		_update_avatar_label_from_path(p)

	# Display Objectives
	for child in objectives_container.get_children():
		child.queue_free()
	for objective_name in data["objectives"]:
		var objective_label = Label.new()
		var status = "[In Progress]"
		if data["objectives"][objective_name]:
			status = "[Completed]"
		objective_label.text = objective_name.replace("_", " ").capitalize() + ": " + status
		objectives_container.add_child(objective_label)

	# Display Trophies: full gallery with locked/unlocked variants
	for child in trophies_container.get_children():
		child.queue_free()
	# Grid columns for thumbnails
	if trophies_container.has_method("set"):
		trophies_container.columns = 4
	# Build list from AchievementManager (preferred) or from filesystem
	var all_trophies: Array = []
	var AchMgr = get_node_or_null("/root/AchievementManager")
	if AchMgr != null and AchMgr.has_method("get_all_trophies"):
		all_trophies = AchMgr.get_all_trophies()
	else:
		var d = Directory.new()
		if d.open("res://Assets/Trophies/Achievements") == OK:
			d.list_dir_begin()
			var fn = d.get_next()
			while fn != "":
				if not d.current_is_dir() and fn.to_lower().ends_with(".tres"):
					var id = fn.substr(0, fn.length() - 5)
					var base = id.replace("_", "")
					all_trophies.append({
						"id": id,
						"name": _title_case(id.replace("_", " ")),
						"icon_path": "res://Assets/Trophies/trophy_" + base + ".png",
						"locked_icon_path": "res://Assets/Trophies/trophy_" + base + "_locked.png"
					})
				fn = d.get_next()
			d.list_dir_end()
	# Sort by id
	all_trophies.sort_custom(self, "_cmp_trophy")
	var unlocked: Array = data.get("unlocks", {}).get("trophies", [])
	for t in all_trophies:
		var tid: String = String(t.get("id"))
		var is_unlocked: bool = unlocked.has(tid)
		var path: String = ""
		if is_unlocked:
			path = String(t.get("icon_path"))
		else:
			path = String(t.get("locked_icon_path"))
		if not ResourceLoader.exists(path):
			continue
		var thumb = TextureRect.new()
		thumb.expand = true
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.rect_min_size = Vector2(120, 120)
		thumb.texture = load(path)
		var tip = String(t.get("name", tid))
		tip = _title_case(tip)
		thumb.hint_tooltip = tip
		thumb.mouse_filter = Control.MOUSE_FILTER_STOP
		thumb.connect("gui_input", self, "_on_trophy_thumb_gui_input", [t, is_unlocked])
		trophies_container.add_child(thumb)
	# Prepare popup viewer for enlarged preview
	_ensure_trophy_popup()

	# Populate Frame Selection
	frame_selection_button.clear()
	var current_frame_index = 0
	for i in range(data["unlocks"]["frames"].size()):
		var frame_name = data["unlocks"]["frames"][i]
		var display_name = String(frame_name).replace("_", " ")
		if display_name.length() > 0:
			display_name = display_name.substr(0,1).to_upper() + display_name.substr(1)
		frame_selection_button.add_item(display_name)
		if frame_name == PlayerManager.get_current_frame():
			current_frame_index = i
	frame_selection_button.select(current_frame_index)
	update_avatar_frame()

func update_avatar_frame():
	var frame_path = "res://Assets/Visuals/Avatar Frames/avatar_frame_2.png" # Default matches in-game
	if PlayerManager != null:
		var frame_name = PlayerManager.get_current_frame()
		if frame_name != "default":
			frame_path = "res://Assets/Visuals/Avatar Frames/avatar_" + frame_name + ".png"
	_set_profile_frame_texture(frame_path)

func _ensure_frame_overlay() -> void:
	if _frame_overlay != null and is_instance_valid(_frame_overlay):
		return
	if not is_instance_valid(avatar_frame_rect):
		return
	var ov: TextureRect = avatar_frame_rect.get_node_or_null("FrameOverlay")
	if ov == null:
		ov = TextureRect.new()
		ov.name = "FrameOverlay"
		ov.expand = true
		ov.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Full-rect anchors
		ov.anchor_left = 0
		ov.anchor_top = 0
		ov.anchor_right = 1
		ov.anchor_bottom = 1
		ov.margin_left = 0
		ov.margin_top = 0
		ov.margin_right = 0
		ov.margin_bottom = 0
		avatar_frame_rect.add_child(ov)
	# Ensure overlay draws above avatar
	var last = max(avatar_frame_rect.get_child_count() - 1, 0)
	avatar_frame_rect.move_child(ov, last)
	_frame_overlay = ov

func _set_profile_frame_texture(path: String) -> void:
	_ensure_frame_overlay()
	if _frame_overlay == null:
		return
	if ResourceLoader.exists(path):
		_frame_overlay.texture = load(path)

func _on_frame_selected(index):
	var frame_name = frame_selection_button.get_item_text(index).to_lower().replace(" ", "_")
	if PlayerManager != null:
		PlayerManager.set_current_frame(frame_name)
		PlayerManager.save_player_data()
	update_avatar_frame()

# For desktop platforms, this function opens a file dialog.
# For mobile, a native plugin would be needed to open the photo gallery.
# You would then call _on_file_selected with the path from the native plugin.
func _on_change_avatar_pressed():
	# Legacy hook; use cycler instead
	_on_cycle_avatar()

func _build_avatar_gallery() -> void:
	_avatar_paths.clear()
	var dir = Directory.new()
	if dir.open("res://Assets/Dots") != OK:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var lower = fname.to_lower()
			if lower.ends_with("avatar.png"):
				_avatar_paths.append("res://Assets/Dots/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	_avatar_paths.sort()
	_avatar_index = 0

func _on_cycle_avatar():
	if _avatar_paths.size() == 0:
		return
	_avatar_index = (_avatar_index + 1) % _avatar_paths.size()
	var path: String = _avatar_paths[_avatar_index]
	# Save selected avatar to user storage to keep rest of the game logic unchanged
	_apply_avatar_from_res(path)
	_update_avatar_label_from_path(path)

func _on_prev_avatar():
	if _avatar_paths.size() == 0:
		return
	_avatar_index = (_avatar_index - 1 + _avatar_paths.size()) % _avatar_paths.size()
	var path: String = _avatar_paths[_avatar_index]
	_apply_avatar_from_res(path)
	_update_avatar_label_from_path(path)

func _preview_avatar_res(path: String) -> void:
	var tex = load(path)
	if tex is Texture:
		avatar_texture_rect.texture = tex

func _apply_avatar_from_res(path: String) -> void:
	var img = Image.new()
	var ok = img.load(path)
	if ok == OK:
		img = _crop_to_square(img)
		img.resize(512, 512, Image.INTERPOLATE_LANCZOS)
		var avatars_dir: String = "user://avatars"
		var d = Directory.new()
		if d.open("user://") == OK:
			d.make_dir_recursive("avatars")
		var save_path: String = avatars_dir + "/" + _get_player_name_fallback() + ".png"
		var err: int = img.save_png(save_path)
		if err != OK:
			push_warning("Failed to save avatar: " + str(err))
		else:
			# Persist path to player data for quick lookup and cross-scene consistency
			if PlayerManager != null:
				PlayerManager.player_data["avatar"] = save_path
				PlayerManager.save_player_data()
		# Update preview
		var tex = ImageTexture.new()
		tex.create_from_image(img)
		avatar_texture_rect.texture = tex
		# Notify game UI to refresh
		if PlayerManager != null and PlayerManager.has_method("notify_avatar_changed"):
			PlayerManager.notify_avatar_changed()

func _update_avatar_label_from_path(path: String) -> void:
	if _avatar_label == null:
		return
	var fname: String = String(path).get_file()
	fname = fname.replace(".png", "")
	if fname.ends_with("avatar"):
		fname = fname.substr(0, fname.length() - 6)
	if fname.length() == 0:
		_avatar_label.text = ""
		return
	var nice = fname.substr(0,1).to_upper() + fname.substr(1).to_lower()
	_avatar_label.text = "Avatar: " + nice

func _cmp_trophy(a, b):
	return int(String(a.get("id")).naturalnocasecmp_to(String(b.get("id"))))

var _trophy_popup: PopupPanel = null
var _trophy_popup_tex: TextureRect = null
var _trophy_popup_label: Label = null

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

func _ensure_trophy_popup() -> void:
	if _trophy_popup != null:
		return
	_trophy_popup = PopupPanel.new()
	_trophy_popup.name = "TrophyViewer"
	_trophy_popup.rect_min_size = Vector2(420, 420)
	add_child(_trophy_popup)
	var vb = VBoxContainer.new()
	vb.add_constant_override("separation", 8)
	vb.alignment = BoxContainer.ALIGN_CENTER
	_trophy_popup.add_child(vb)
	_trophy_popup_label = Label.new()
	_trophy_popup_label.align = Label.ALIGN_CENTER
	_trophy_popup_label.valign = Label.VALIGN_CENTER
	_trophy_popup_label.name = "TitleLabel"
	vb.add_child(_trophy_popup_label)
	_trophy_popup_tex = TextureRect.new()
	_trophy_popup_tex.expand = true
	_trophy_popup_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_trophy_popup_tex.rect_min_size = Vector2(380, 360)
	_trophy_popup_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(_trophy_popup_tex)
	var close = Button.new()
	close.text = "Close"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.connect("pressed", _trophy_popup, "hide")
	vb.add_child(close)

func _on_trophy_thumb_pressed(t: Dictionary, is_unlocked: bool) -> void:
	var path = ""
	if is_unlocked:
		path = String(t.get("icon_path"))
	else:
		path = String(t.get("locked_icon_path"))
	if ResourceLoader.exists(path):
		_trophy_popup_tex.texture = load(path)
		if _trophy_popup_label != null:
			var title = _title_case(String(t.get("name", String(t.get("id", "")))))
			_trophy_popup_label.text = title
		_trophy_popup_tex.rect_scale = Vector2(0.85, 0.85)
		_trophy_popup.popup_centered()
		var tw = create_tween()
		tw.tween_property(_trophy_popup_tex, "rect_scale", Vector2(1,1), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_trophy_thumb_gui_input(event, t: Dictionary, is_unlocked: bool) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		_on_trophy_thumb_pressed(t, is_unlocked)

func _on_achievement_unlocked(_id: String) -> void:
	# When a trophy unlocks mid-session, refresh the gallery
	display_player_data()

func _on_file_selected(path):
	# Validate selection: only allow res://Assets/Dots/*avatar.png
	var p = String(path)
	if not p.begins_with("res://Assets/Dots/") or not p.to_lower().ends_with("avatar.png"):
		push_warning("Please select a character avatar PNG from Assets/Dots (…avatar.png)")
		return
	var img = Image.new()
	var load_err = img.load(path)
	if load_err == OK:
		# Center-crop to square and scale to 512x512 for consistent quality
		img = _crop_to_square(img)
		img.resize(512, 512, Image.INTERPOLATE_LANCZOS)
		# Save to user storage
		var avatars_dir: String = "user://avatars"
		var d = Directory.new()
		if d.open("user://") == OK:
			d.make_dir_recursive("avatars")
		var save_path: String = avatars_dir + "/" + _get_player_name_fallback() + ".png"
		var err: int = img.save_png(save_path)
		if err != OK:
			push_warning("Failed to save avatar: " + str(err))
		else:
			if PlayerManager != null:
				PlayerManager.player_data["avatar"] = save_path
				PlayerManager.save_player_data()
		# Update preview
		var tex = ImageTexture.new()
		tex.create_from_image(img)
		avatar_texture_rect.texture = tex
		# Notify game UI to refresh (emit from PlayerManager to avoid UNUSED_SIGNAL)
		if PlayerManager != null and PlayerManager.has_method("notify_avatar_changed"):
			PlayerManager.notify_avatar_changed()

func _get_player_name_fallback() -> String:
	if PlayerManager != null and PlayerManager.has_method("get_player_name"):
		return String(PlayerManager.get_player_name())
	return "Player"

func _on_back_button_pressed():
	get_tree().change_scene("res://Scenes/Menu.tscn")

# Helper: center-crop to a 1:1 square
func _crop_to_square(img: Image) -> Image:
	var w: int = img.get_width()
	var h: int = img.get_height()
	if w == h:
		return img
	var side: int = min(w, h)
	var x: int = int((w - side) / 2)
	var y: int = int((h - side) / 2)
	var cropped = Image.new()
	cropped.create(side, side, false, img.get_format())
	cropped.blit_rect(img, Rect2(x, y, side, side), Vector2(0,0))
	return cropped

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

# Gallery state for built-in avatars
var _avatar_paths: Array = []
var _avatar_index: int = 0
var _avatar_label: Label = null

func _ready():
	display_player_data()
	
	# Build cyclable gallery of avatar options from Assets/Dots/*avatar.png
	_build_avatar_gallery()
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
	frame_selection_button.connect("item_selected", self, "_on_frame_selected")

func display_player_data():
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
	var avatar_path = "user://avatars/" + PlayerManager.get_player_name() + ".png"
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

	# Display Trophies
	for child in trophies_container.get_children():
		child.queue_free()
	for trophy_name in data["unlocks"]["trophies"]:
		var trophy_texture = load("res://Assets/Visuals/Trophies/" + trophy_name + ".png")
		var trophy_rect = TextureRect.new()
		trophy_rect.texture = trophy_texture
		trophy_rect.rect_min_size = Vector2(592, 592)
		trophy_rect.expand = true
		trophies_container.add_child(trophy_rect)

	# Populate Frame Selection
	frame_selection_button.clear()
	var current_frame_index = 0
	for i in range(data["unlocks"]["frames"].size()):
		var frame_name = data["unlocks"]["frames"][i]
		frame_selection_button.add_item(frame_name.capitalize())
		if frame_name == PlayerManager.get_current_frame():
			current_frame_index = i
	frame_selection_button.select(current_frame_index)
	update_avatar_frame()

func update_avatar_frame():
	var frame_name = PlayerManager.get_current_frame()
	var frame_path = "res://Assets/Visuals/avatar_frame_2.png" # Default matches in-game
	if frame_name != "default":
		frame_path = "res://Assets/Visuals/avatar_" + frame_name + ".png"
	avatar_frame_rect.texture = load(frame_path)

func _on_frame_selected(index):
	var frame_name = frame_selection_button.get_item_text(index).to_lower()
	PlayerManager.set_current_frame(frame_name)
	update_avatar_frame()
	PlayerManager.save_player_data()

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
		var save_path: String = avatars_dir + "/" + PlayerManager.get_player_name() + ".png"
		var err: int = img.save_png(save_path)
		if err != OK:
			push_warning("Failed to save avatar: " + str(err))
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
		var save_path: String = avatars_dir + "/" + PlayerManager.get_player_name() + ".png"
		var err: int = img.save_png(save_path)
		if err != OK:
			push_warning("Failed to save avatar: " + str(err))
		# Update preview
		var tex = ImageTexture.new()
		tex.create_from_image(img)
		avatar_texture_rect.texture = tex
		# Notify game UI to refresh (emit from PlayerManager to avoid UNUSED_SIGNAL)
		if PlayerManager != null and PlayerManager.has_method("notify_avatar_changed"):
			PlayerManager.notify_avatar_changed()

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

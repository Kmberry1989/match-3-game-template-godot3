extends Control

# Visual overlays can make the board appear "shrunk" at the edges on some displays.
# Toggle this to enable/disable the decorative gold border overlay.
const GOLD_BORDER_ENABLED := false

onready var PlayerManager = get_node_or_null("/root/PlayerManager")
onready var AudioManager = get_node_or_null("/root/AudioManager")

onready var player_name_label = $MarginContainer/HBoxContainer/PlayerInfo/HBox/AvatarFrame/PlayerNameLabel
onready var level_label = $MarginContainer/HBoxContainer/PlayerInfo/HBox/AvatarFrame/LevelLabel
onready var xp_label = $MarginContainer/HBoxContainer/PlayerInfo/HBox/AvatarFrame/XpLabel
onready var coins_label = $MarginContainer/HBoxContainer/PlayerInfo/HBox/AvatarFrame/CoinsLabel
# Pause button is looked up safely at runtime to avoid errors when missing
onready var frame_sprite = $MarginContainer/HBoxContainer/PlayerInfo/HBox/AvatarFrame/AvatarFrame2
onready var player_avatar = $MarginContainer/HBoxContainer/PlayerInfo/HBox/AvatarFrame/PlayerAvatar
var _avatar_photo = null
var _avatar_nudged: bool = false
var _xp_convert_overlay: TextureRect = null
var _xp_convert_tween = null


# MEANER METER UI reference
var _meaner_bar = null
var _meaner_label = null

# Lightweight HUD elements for level objectives/moves
var _hud_root: Control = null
var _goal_label: Label = null
var _goal_count_label: Label = null
var _test_toggle_button: Button = null
var _test_panel: Panel = null
var _test_status_label: Label = null
var _test_busy: bool = false
var _test_overlay_layer: CanvasLayer = null
var _test_overlay_root: Control = null
var _autoplay_badge: Panel = null
var _autoplay_badge_label: Label = null
const LevelManagerScript = preload("res://Scripts/LevelManager.gd")
const BONUS_GAME_SCENES: Dictionary = {
	"slot_machine": "res://Scenes/BonusSlotMachine.tscn",
	"shelf_sort": "res://Scenes/BonusShelfSort.tscn",
	"memory_pairs": "res://Scenes/BonusMemoryPairs.tscn"
}

func _set_mouse_filters_for_passthrough(root: Node) -> void:
	if root == null:
		return
	if root is Control:
		var c = root as Control
		if c is Button:
			c.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in root.get_children():
		_set_mouse_filters_for_passthrough(child)

func _ready():
	# Safely initialize from PlayerManager autoload if present
	if PlayerManager == null:
		PlayerManager = get_node_or_null("/root/PlayerManager")
	# Refresh AudioManager reference if needed
	if AudioManager == null:
		AudioManager = get_node_or_null("/root/AudioManager")
	if PlayerManager != null:
		set_player_name(PlayerManager.get_player_name())
		update_level_label(PlayerManager.get_current_level())
		update_xp_label()
		if PlayerManager.is_connected("level_up", self, "update_level_label"):
			PlayerManager.disconnect("level_up", self, "update_level_label")
		if not PlayerManager.is_connected("level_up", self, "_on_level_up"):
			PlayerManager.connect("level_up", self, "_on_level_up")
		if not PlayerManager.is_connected("coins_changed", self, "_on_coins_changed"):
			PlayerManager.connect("coins_changed", self, "_on_coins_changed")
		if not PlayerManager.is_connected("frame_changed", self, "_on_frame_changed"):
			PlayerManager.connect("frame_changed", self, "_on_frame_changed")
		_on_coins_changed(PlayerManager.get_coins())
		_apply_current_frame()
	else:
		# Fallback display until PlayerManager becomes available
		update_xp_label()
	# Optional decorative overlay; disabled by default to avoid affecting perceived grid area
	if GOLD_BORDER_ENABLED:
		_add_gold_border()
	else:
		# Ensure any existing gold border layer is removed if present
		var _gb = get_node_or_null("GoldBorderLayer")
		if _gb != null:
			_gb.queue_free()

	# Ensure non-interactive UI does not block board input
	_set_mouse_filters_for_passthrough(self)
	# Add MEANER METER UI and connect signals
	_add_meaner_meter_ui()
	if PlayerManager != null:
		if not PlayerManager.is_connected("meaner_meter_changed", self, "_on_meaner_meter_changed"):
			PlayerManager.connect("meaner_meter_changed", self, "_on_meaner_meter_changed")
		if not PlayerManager.is_connected("meaner_meter_filled", self, "_on_meaner_meter_filled"):
			PlayerManager.connect("meaner_meter_filled", self, "_on_meaner_meter_filled")
		# Initialize bar to current value
		_on_meaner_meter_changed(PlayerManager.get_meaner_meter_current(), PlayerManager.get_meaner_meter_max())
	# Ensure pause/home/shop buttons are clickable above other UI (guard if not found)
	_wire_button("PauseButton", "_on_pause_pressed")
	_wire_button("HomeButton", "_on_home_pressed")
	_wire_button("ShopButton", "_on_shop_pressed")
	# React to avatar changes
	if PlayerManager != null and PlayerManager.has_signal("avatar_changed") and not PlayerManager.is_connected("avatar_changed", self, "_on_avatar_changed"):
		PlayerManager.connect("avatar_changed", self, "_on_avatar_changed")
	# Name-gated autoplay status badge.
	if _is_otto_player():
		_add_autoplay_badge()
	# Name-gated test tools for QA/dev profile only.
	if _is_test_player():
		_add_test_menu()
	_update_autoplay_badge_state()

func _normalized_player_name() -> String:
	if PlayerManager != null and PlayerManager.has_method("get_player_name"):
		return String(PlayerManager.get_player_name()).strip_edges().to_lower()
	return ""

func _is_otto_player() -> bool:
	return _normalized_player_name() == "otto"

func _is_test_player() -> bool:
	return _normalized_player_name() == "test"

func _ensure_test_overlay_root() -> Control:
	var root_scene = get_tree().get_current_scene()
	if root_scene == null:
		return self
	if _test_overlay_layer == null or not is_instance_valid(_test_overlay_layer):
		_test_overlay_layer = root_scene.get_node_or_null("TestMenuLayer")
		if _test_overlay_layer == null:
			_test_overlay_layer = CanvasLayer.new()
			_test_overlay_layer.name = "TestMenuLayer"
			root_scene.add_child(_test_overlay_layer)
		_test_overlay_layer.layer = 2100
	if _test_overlay_root == null or not is_instance_valid(_test_overlay_root):
		_test_overlay_root = _test_overlay_layer.get_node_or_null("TestMenuRoot")
		if _test_overlay_root == null:
			_test_overlay_root = Control.new()
			_test_overlay_root.name = "TestMenuRoot"
			_test_overlay_root.anchor_left = 0.0
			_test_overlay_root.anchor_top = 0.0
			_test_overlay_root.anchor_right = 1.0
			_test_overlay_root.anchor_bottom = 1.0
			_test_overlay_root.margin_left = 0.0
			_test_overlay_root.margin_top = 0.0
			_test_overlay_root.margin_right = 0.0
			_test_overlay_root.margin_bottom = 0.0
			_test_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_test_overlay_layer.add_child(_test_overlay_root)
	return _test_overlay_root

func _add_autoplay_badge() -> void:
	if _autoplay_badge != null and is_instance_valid(_autoplay_badge):
		return
	_autoplay_badge = Panel.new()
	_autoplay_badge.name = "AutoplayBadge"
	_autoplay_badge.anchor_left = 0.0
	_autoplay_badge.anchor_top = 0.0
	_autoplay_badge.anchor_right = 0.0
	_autoplay_badge.anchor_bottom = 0.0
	_autoplay_badge.margin_left = 12
	_autoplay_badge.margin_top = 22
	_autoplay_badge.margin_right = 230
	_autoplay_badge.margin_bottom = 60
	_autoplay_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _autoplay_badge.has_method("set_z_index"):
		_autoplay_badge.set_z_index(3002)
	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.12, 0.42, 0.18, 0.95)
	badge_style.border_color = Color(1, 1, 1, 0.45)
	badge_style.border_width_left = 2
	badge_style.border_width_right = 2
	badge_style.border_width_top = 2
	badge_style.border_width_bottom = 2
	badge_style.corner_radius_top_left = 8
	badge_style.corner_radius_top_right = 8
	badge_style.corner_radius_bottom_left = 8
	badge_style.corner_radius_bottom_right = 8
	_autoplay_badge.add_stylebox_override("panel", badge_style)
	add_child(_autoplay_badge)

	_autoplay_badge_label = Label.new()
	_autoplay_badge_label.text = "AUTOPLAY ACTIVE"
	_autoplay_badge_label.align = Label.ALIGN_CENTER
	_autoplay_badge_label.valign = Label.VALIGN_CENTER
	_autoplay_badge_label.anchor_left = 0.0
	_autoplay_badge_label.anchor_top = 0.0
	_autoplay_badge_label.anchor_right = 1.0
	_autoplay_badge_label.anchor_bottom = 1.0
	_autoplay_badge_label.margin_left = 8
	_autoplay_badge_label.margin_top = 2
	_autoplay_badge_label.margin_right = -8
	_autoplay_badge_label.margin_bottom = -2
	_autoplay_badge.add_child(_autoplay_badge_label)
	_update_autoplay_badge_state()

func _update_autoplay_badge_state() -> void:
	if (_autoplay_badge == null or not is_instance_valid(_autoplay_badge)) and _is_otto_player():
		_add_autoplay_badge()
		return
	if _autoplay_badge == null or not is_instance_valid(_autoplay_badge):
		return
	_autoplay_badge.visible = _is_otto_player() and not get_tree().paused

func _process(_delta: float) -> void:
	_update_autoplay_badge_state()

func _add_test_menu() -> void:
	if _test_panel != null and is_instance_valid(_test_panel):
		return
	var overlay_root = _ensure_test_overlay_root()
	if overlay_root == null:
		overlay_root = self
	_test_toggle_button = Button.new()
	_test_toggle_button.name = "TestToggleButton"
	_test_toggle_button.text = "TEST"
	_test_toggle_button.anchor_left = 1.0
	_test_toggle_button.anchor_top = 0.0
	_test_toggle_button.anchor_right = 1.0
	_test_toggle_button.anchor_bottom = 0.0
	_test_toggle_button.margin_left = -130
	_test_toggle_button.margin_top = 96
	_test_toggle_button.margin_right = -12
	_test_toggle_button.margin_bottom = 136
	_test_toggle_button.rect_min_size = Vector2(118, 40)
	_test_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if _test_toggle_button.has_method("set_z_index"):
		_test_toggle_button.set_z_index(3001)
	_test_toggle_button.connect("pressed", self, "_on_test_toggle_pressed")
	overlay_root.add_child(_test_toggle_button)

	_test_panel = Panel.new()
	_test_panel.name = "TestMenuPanel"
	_test_panel.anchor_left = 1.0
	_test_panel.anchor_top = 0.0
	_test_panel.anchor_right = 1.0
	_test_panel.anchor_bottom = 0.0
	_test_panel.margin_left = -330
	_test_panel.margin_top = 142
	_test_panel.margin_right = -12
	_test_panel.margin_bottom = 540
	_test_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_test_panel.visible = false
	if _test_panel.has_method("set_z_index"):
		_test_panel.set_z_index(3000)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	sb.border_color = Color(1, 1, 1, 0.2)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	_test_panel.add_stylebox_override("panel", sb)
	overlay_root.add_child(_test_panel)

	var vb = VBoxContainer.new()
	vb.anchor_left = 0
	vb.anchor_top = 0
	vb.anchor_right = 1
	vb.anchor_bottom = 1
	vb.margin_left = 10
	vb.margin_top = 10
	vb.margin_right = -10
	vb.margin_bottom = -10
	vb.add_constant_override("separation", 8)
	_test_panel.add_child(vb)

	var title = Label.new()
	title.text = "Testing Menu"
	title.align = Label.ALIGN_CENTER
	vb.add_child(title)

	var b_slot = Button.new()
	b_slot.text = "Play Slot Mini-Game"
	b_slot.rect_min_size = Vector2(0, 42)
	b_slot.connect("pressed", self, "_on_test_play_bonus_pressed", ["slot_machine"])
	vb.add_child(b_slot)

	var b_shelf = Button.new()
	b_shelf.text = "Play Shelf Sort"
	b_shelf.rect_min_size = Vector2(0, 42)
	b_shelf.connect("pressed", self, "_on_test_play_bonus_pressed", ["shelf_sort"])
	vb.add_child(b_shelf)

	var b_memory = Button.new()
	b_memory.text = "Play Memory Pairs"
	b_memory.rect_min_size = Vector2(0, 42)
	b_memory.connect("pressed", self, "_on_test_play_bonus_pressed", ["memory_pairs"])
	vb.add_child(b_memory)

	var b_queue = Button.new()
	b_queue.text = "Queue Bonus Token"
	b_queue.rect_min_size = Vector2(0, 40)
	b_queue.connect("pressed", self, "_on_test_queue_token_pressed")
	vb.add_child(b_queue)

	var b_meter = Button.new()
	b_meter.text = "Fill Meaner Meter"
	b_meter.rect_min_size = Vector2(0, 40)
	b_meter.connect("pressed", self, "_on_test_fill_meter_pressed")
	vb.add_child(b_meter)

	var b_reward = Button.new()
	b_reward.text = "Grant 200 Coins + XP"
	b_reward.rect_min_size = Vector2(0, 40)
	b_reward.connect("pressed", self, "_on_test_add_resources_pressed")
	vb.add_child(b_reward)

	var b_lvl = Button.new()
	b_lvl.text = "Force Level Up"
	b_lvl.rect_min_size = Vector2(0, 40)
	b_lvl.connect("pressed", self, "_on_test_level_up_pressed")
	vb.add_child(b_lvl)

	var b_queue_run = Button.new()
	b_queue_run.text = "Run Bonus Queue Now"
	b_queue_run.rect_min_size = Vector2(0, 40)
	b_queue_run.connect("pressed", self, "_on_test_run_bonus_queue_pressed")
	vb.add_child(b_queue_run)

	_test_status_label = Label.new()
	_test_status_label.text = "Ready."
	_test_status_label.autowrap = true
	_test_status_label.align = Label.ALIGN_CENTER
	vb.add_child(_test_status_label)

func _set_test_status(msg: String) -> void:
	if _test_status_label != null and is_instance_valid(_test_status_label):
		_test_status_label.text = msg

func _on_test_toggle_pressed() -> void:
	if _test_panel == null:
		return
	_test_panel.visible = not _test_panel.visible

func _on_test_play_bonus_pressed(game_id: String) -> void:
	if _test_busy:
		_set_test_status("Busy...")
		return
	_test_busy = true
	_set_test_status("Launching %s..." % game_id)
	var result = play_bonus_game(game_id)
	if result is GDScriptFunctionState:
		result = yield(result, "completed")
	var status = "completed"
	if typeof(result) == TYPE_DICTIONARY:
		status = String(result.get("status", "completed"))
	_set_test_status("Mini-game finished: %s" % status)
	_test_busy = false

func _on_test_queue_token_pressed() -> void:
	if PlayerManager != null and PlayerManager.has_method("queue_bonus_game_token"):
		PlayerManager.queue_bonus_game_token("test_menu")
		_set_test_status("Queued 1 bonus token.")
	else:
		_set_test_status("queue_bonus_game_token unavailable.")

func _on_test_fill_meter_pressed() -> void:
	if PlayerManager != null and PlayerManager.has_method("add_to_meaner_meter"):
		var cur = 0
		var mx = 100
		if PlayerManager.has_method("get_meaner_meter_current"):
			cur = int(PlayerManager.get_meaner_meter_current())
		if PlayerManager.has_method("get_meaner_meter_max"):
			mx = int(PlayerManager.get_meaner_meter_max())
		PlayerManager.add_to_meaner_meter(max(1, mx - cur))
		_set_test_status("Meaner meter filled.")
	else:
		_set_test_status("add_to_meaner_meter unavailable.")

func _on_test_add_resources_pressed() -> void:
	if PlayerManager != null and PlayerManager.has_method("apply_bonus_reward"):
		PlayerManager.apply_bonus_reward({"coins": 200, "xp": 200}, "test_menu")
		_set_test_status("Granted 200 coins + 200 XP.")
		return
	if PlayerManager != null:
		if PlayerManager.has_method("add_coins"):
			PlayerManager.add_coins(200)
		if PlayerManager.has_method("add_xp"):
			PlayerManager.add_xp(200)
		_set_test_status("Granted 200 coins + 200 XP (fallback).")
		return
	_set_test_status("PlayerManager unavailable.")

func _on_test_level_up_pressed() -> void:
	if PlayerManager == null or not PlayerManager.has_method("complete_level"):
		_set_test_status("complete_level unavailable.")
		return
	var lvl := 1
	if PlayerManager.has_method("get_current_level"):
		lvl = int(PlayerManager.get_current_level())
	PlayerManager.complete_level(lvl, 9999, 3)
	_set_test_status("Forced level-up from level %d." % lvl)

func _on_test_run_bonus_queue_pressed() -> void:
	if _test_busy:
		_set_test_status("Busy...")
		return
	var root = get_tree().get_current_scene()
	if root == null:
		_set_test_status("No scene.")
		return
	var grid = root.get_node_or_null("Grid")
	if grid == null or not grid.has_method("_run_interlevel_bonus_queue"):
		_set_test_status("Grid bonus queue unavailable.")
		return
	_test_busy = true
	_set_test_status("Running queue (milestone + token check)...")
	var next_level := 2
	if PlayerManager != null and PlayerManager.has_method("get_current_level"):
		next_level = int(PlayerManager.get_current_level()) + 1
	var st = grid.call("_run_interlevel_bonus_queue", 3, next_level)
	if st is GDScriptFunctionState:
		yield(st, "completed")
	_set_test_status("Queue run completed.")
	_test_busy = false

func _ensure_level_hud():
	if _hud_root != null and is_instance_valid(_hud_root):
		return
	_hud_root = Control.new()
	_hud_root.name = "LevelHUD"
	# Place near the top-left overlay area
	_hud_root.anchor_left = 0
	_hud_root.anchor_top = 0
	_hud_root.anchor_right = 0
	_hud_root.anchor_bottom = 0
	_hud_root.margin_left = 19
	_hud_root.margin_top = 95
	add_child(_hud_root)
	var vb = VBoxContainer.new()
	vb.name = "VBox"
	vb.add_constant_override("separation", 2)
	_hud_root.add_child(vb)
	_goal_label = Label.new()
	_goal_label.name = "GoalLabel"
	_goal_label.text = "Goal: --"
	vb.add_child(_goal_label)
	_goal_count_label = Label.new()
	_goal_count_label.name = "GoalCountLabel"
	_goal_count_label.text = "Remaining: --"
	vb.add_child(_goal_count_label)

# Called from Grid.gd
# Called from Grid.gd with dictionary from LevelManager
func set_level_goal(level_data: Dictionary) -> void:
	_ensure_level_hud()
	var goal_text = level_data.get("goal_text", "")
	if goal_text == "":
		var gt = level_data.get("goal_type", LevelManagerScript.GoalType.SCORE)
		match gt:
			LevelManagerScript.GoalType.SCORE:
				goal_text = "Reach the target score!"
			LevelManagerScript.GoalType.DOWN_TO_EARTH:
				goal_text = "Collect all keys!"
			LevelManagerScript.GoalType.JAILBREAK:
				goal_text = "Break the avatar out!"
			LevelManagerScript.GoalType.EXTERMINATE:
				goal_text = "Defeat the boss!"
			LevelManagerScript.GoalType.TOO_COOL:
				goal_text = "Match the Too Cool dot!"
			_:
				goal_text = "Complete the objective"
	if _goal_label:
		_goal_label.text = "Goal: " + str(goal_text)
	# Default remaining label init
	if _goal_count_label:
		_goal_count_label.text = "Remaining: --"

# Called from Grid.gd whenever the remaining objective count changes
func update_goal_count(count: int) -> void:
	_ensure_level_hud()
	if _goal_count_label:
		_goal_count_label.text = "Remaining: " + str(count)

# Called from Grid.gd to show remaining moves for move-limited levels


# Ensure label node references exist (handles alternate scene structures)
func _ensure_core_labels():
	if player_name_label == null:
		player_name_label = find_node("PlayerNameLabel", true, false)
	if level_label == null:
		level_label = find_node("LevelLabel", true, false)
	if xp_label == null:
		xp_label = find_node("XpLabel", true, false)
	if coins_label == null:
		coins_label = find_node("CoinsLabel", true, false)

func set_player_name(p_name):
	_ensure_core_labels()
	if player_name_label != null:
		player_name_label.text = p_name

func update_level_label(level):
	_ensure_core_labels()
	if level_label != null:
		level_label.text = "Level: " + str(level)

func update_xp_label():
	# Guard against PlayerManager being unavailable in some scenes
	if PlayerManager == null:
		PlayerManager = get_node_or_null("/root/PlayerManager")
	var current_xp = 0
	if PlayerManager != null:
		current_xp = PlayerManager.get_current_xp()
	_ensure_core_labels()
	if xp_label != null:
		xp_label.text = "XP: " + str(current_xp)

func _on_coins_changed(new_amount):
	_ensure_core_labels()
	if coins_label != null:
		coins_label.text = "Coins: " + str(new_amount)

func _on_avatar_changed():
	# Refresh the player avatar texture when notified by PlayerManager
	_update_avatar_photo()

func _on_frame_changed(_frame_name):
	_apply_current_frame()

func _apply_current_frame():
	if PlayerManager == null:
		PlayerManager = get_node_or_null("/root/PlayerManager")
	var frame_name = "default"
	if PlayerManager != null and PlayerManager.has_method("get_current_frame"):
		frame_name = PlayerManager.get_current_frame()
	var tex_path = _frame_to_texture_path(frame_name)
	var tex = load(tex_path)
	if tex and frame_sprite != null:
		frame_sprite.texture = tex
		# Ensure the frame overlay is visible if the scene default is hidden
		frame_sprite.visible = true
		# Some Control derivatives may not expose z_index in older Godot builds; guard the call
		if frame_sprite.has_method("set_z_index"):
			frame_sprite.set_z_index(1000)
		_fit_sprite_to_height(frame_sprite, 160.0)
		_update_avatar_photo()
		_ensure_avatar_layering()

func _frame_to_texture_path(frame_name):
	var base = "res://Assets/Visuals/Avatar Frames/"
	# Discover available frames automatically
	var available = []
	var dir = Directory.new()
	if dir.open(base) == OK:
		dir.list_dir_begin(true, true)
		var fn = dir.get_next()
		while fn != "":
			if not dir.current_is_dir():
				var lower = fn.to_lower()
				if lower.begins_with("avatar_frame_") and lower.ends_with(".png"):
					available.append(lower)
			fn = dir.get_next()
		dir.list_dir_end()
	available.sort()
	if frame_name == "default" and available.size() > 0:
		return base + available[0]
	var target = ""
	if frame_name.begins_with("avatar_frame_"):
		target = frame_name + ".png"
	elif frame_name.begins_with("frame_"):
		target = "avatar_" + frame_name + ".png" # frame_2 -> avatar_frame_2.png
	else:
		target = "avatar_frame_" + frame_name + ".png"
	if available.has(target.to_lower()):
		return base + target
	# Fallbacks
	var fallback = base + "avatar_frame_2.png"
	if ResourceLoader.exists(fallback):
		return fallback
	return base + target

func _fit_sprite_to_height(sprite, target_h):
	if sprite == null or sprite.texture == null:
		return
	var tex = sprite.texture
	var h = float(tex.get_height())
	if h <= 0.0:
		return
	# Do not upscale frames; only downscale if larger than target height
	var sf = target_h / h
	if sf > 1.0:
		sf = 1.0
	# Sprite (Node2D) supports scale; Control/TextureRect uses rect size and stretch
	if sprite is Sprite:
		sprite.scale = Vector2(sf, sf)
	elif sprite is TextureRect:
		# Force a 150x150 square area for the avatar
		sprite.expand = true
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.rect_min_size = Vector2(150, 150)
		sprite.rect_size = Vector2(150, 150)

func _ensure_avatar_photo_node():
	# Use the existing PlayerAvatar TextureRect from the scene
	if player_avatar != null and is_instance_valid(player_avatar):
		_avatar_photo = player_avatar
		_avatar_photo.expand = true
		_avatar_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_avatar_photo.rect_min_size = Vector2(150, 150)
		_avatar_photo.rect_size = Vector2(150, 150)
		_ensure_avatar_layering()
		
		# Create XP conversion overlay if missing
		if _xp_convert_overlay == null:
			_xp_convert_overlay = TextureRect.new()
			_xp_convert_overlay.name = "XPConvertOverlay"
			_xp_convert_overlay.texture = load("res://Assets/Visuals/xp_gold_convert.png")
			_xp_convert_overlay.expand = true
			_xp_convert_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_xp_convert_overlay.rect_min_size = Vector2(150, 150)
			_xp_convert_overlay.rect_size = Vector2(150, 150)
			_xp_convert_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_xp_convert_overlay.modulate = Color(1, 1, 1, 0.0)
			_xp_convert_overlay.visible = false
			# Add as sibling to be drawn on top (or child of frame parent)
			player_avatar.get_parent().add_child(_xp_convert_overlay)
			# Position it same as avatar
			_xp_convert_overlay.rect_position = player_avatar.rect_position
			if _xp_convert_overlay.has_method("set_z_index"):
				_xp_convert_overlay.set_z_index(2000)
			_xp_convert_overlay.raise()
		return

func show_xp_conversion():
	_ensure_avatar_photo_node()
	if _xp_convert_overlay != null:
		_xp_convert_overlay.rect_position = player_avatar.rect_position
		_xp_convert_overlay.visible = true
		_xp_convert_overlay.raise()
		_xp_convert_overlay.modulate = Color(1, 1, 1, 0.0)
		_xp_convert_overlay.rect_scale = Vector2(0.7, 0.7)
		if _xp_convert_tween != null and is_instance_valid(_xp_convert_tween):
			if _xp_convert_tween.has_method("kill"):
				_xp_convert_tween.kill()
		_xp_convert_tween = create_tween()
		_xp_convert_tween.set_parallel(true)
		_xp_convert_tween.tween_property(_xp_convert_overlay, "rect_scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_xp_convert_tween.tween_property(_xp_convert_overlay, "modulate:a", 1.0, 0.2)
		_xp_convert_tween.set_parallel(false)
		_xp_convert_tween.tween_interval(0.45)
		_xp_convert_tween.tween_property(_xp_convert_overlay, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_xp_convert_tween.connect("finished", self, "hide_xp_conversion")

func hide_xp_conversion():
	if _xp_convert_overlay != null:
		_xp_convert_overlay.modulate = Color(1, 1, 1, 0.0)
		_xp_convert_overlay.visible = false

func _on_level_up(new_level):
	update_level_label(new_level)

func _update_avatar_photo():
	_ensure_avatar_photo_node()
	if _avatar_photo == null:
		return
	var tex = null
	# Preferred: explicit avatar path saved in player data (may be user://)
	if PlayerManager != null and typeof(PlayerManager.player_data) == TYPE_DICTIONARY and PlayerManager.player_data.has("avatar"):
		var saved_path = String(PlayerManager.player_data.get("avatar"))
		tex = _load_texture_any(saved_path)
	# Fallback: per-user avatar file
	if tex == null:
		var uname = "player"
		if PlayerManager != null and PlayerManager.has_method("get_player_name"):
			uname = String(PlayerManager.get_player_name())
		var path1 = "user://avatars/" + uname + ".png"
		tex = _load_texture_any(path1)
	# Fallback: legacy single avatar path
	if tex == null:
		var path2 = "user://avatar.png"
		tex = _load_texture_any(path2)
	# Final fallback: default in-game avatar
	if tex == null:
		var fallback = "res://Assets/Dots/vickieavatar.png"
		if ResourceLoader.exists(fallback):
			tex = load(fallback)
	_avatar_photo.texture = tex
	if tex != null:
		# Fit just inside the frame so it doesn't get blocked too much
		_fit_sprite_to_height(_avatar_photo, 150.0)
		_avatar_photo.visible = true
	else:
		_avatar_photo.visible = false
	# Raise the avatar slightly within the frame (apply once)
	_raise_avatar_by(10)

func _load_texture_any(path: String):
	if path == null:
		return null
	var p = String(path)
	if p == "":
		return null
	if p.begins_with("user://"):
		var f = File.new()
		if f.file_exists(p):
			var img = Image.new()
			if img.load(p) == OK:
				var it = ImageTexture.new()
				it.create_from_image(img)
				return it
		return null
	else:
		if ResourceLoader.exists(p):
			return load(p)
	return null

func _ensure_avatar_layering() -> void:
	# Ensure the avatar draws just beneath the frame and above other siblings
	if _avatar_photo == null or frame_sprite == null:
		return
	var parent_node = frame_sprite.get_parent()
	if parent_node == null:
		return
	# Prefer z_index where available
	var set_ok = false
	if _avatar_photo.has_method("set_z_index") and frame_sprite.has_method("get_z_index"):
		var fz = int(frame_sprite.get_z_index())
		_avatar_photo.set_z_index(max(fz - 1, -100))
		set_ok = true
	# Also adjust sibling order as a fallback so avatar is before frame (drawn underneath)
	var f_idx = frame_sprite.get_index()
	var a_idx = _avatar_photo.get_index()
	if a_idx > f_idx:
		parent_node.move_child(_avatar_photo, f_idx)
	# Optionally raise both relative to other UI when z_index is unsupported
	if not set_ok:
		# Move frame to the end and avatar just before it
		var last = parent_node.get_child_count() - 1
		parent_node.move_child(frame_sprite, last)
		parent_node.move_child(_avatar_photo, max(last - 1, 0))

func _raise_avatar_by(pixels: int) -> void:
	if _avatar_nudged:
		return
	if _avatar_photo != null and _avatar_photo is Control:
		# Move up by reducing top/bottom margins equally to preserve height
		_avatar_photo.margin_top -= pixels
		_avatar_photo.margin_bottom -= pixels
		_avatar_nudged = true

func _on_pause_pressed():
	var root = get_tree().get_current_scene()
	if root == null:
		return
	# Find or create the CanvasLayer to host overlays
	var layer = root.get_node_or_null("CanvasLayer")
	if layer == null:
		layer = root.find("CanvasLayer", true, false)
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "CanvasLayer"
		root.add_child(layer)

	var existing = layer.get_node_or_null("PauseMenu")
	if existing != null:
		if existing.has_method("show_menu"):
			existing.call("show_menu")
		return
	var pause_menu = preload("res://Scenes/PauseMenu.tscn").instance()
	pause_menu.name = "PauseMenu"
	layer.add_child(pause_menu)
	if pause_menu.has_method("show_menu"):
		pause_menu.call("show_menu")

func _unhandled_input(event):
	# Fallback: allow Esc/back to open pause
	if event is InputEventKey and event.pressed and not event.echo:
		if event.scancode == KEY_ESCAPE:
			_on_pause_pressed()

func get_xp_anchor_pos():
	if is_instance_valid(xp_label):
		return xp_label.get_global_transform().origin
	return Vector2.ZERO

func _wire_button(node_name, handler):
	var n = get_node_or_null(node_name)
	if n == null:
		n = find_node(node_name, true, false)
	var c = n as Control
	if c != null:
		if c.has_method("set_z_index"):
			c.set_z_index(1000)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
	var b = n as Button
	if b != null and not b.is_connected("pressed", self, handler):
		b.connect("pressed", self, handler)

func _on_home_pressed():
	if AudioManager != null:
		AudioManager.play_sound("ui_click")
	get_tree().change_scene("res://Scenes/Menu.tscn")

func _on_shop_pressed():
	if AudioManager != null:
		AudioManager.play_sound("ui_click")
	get_tree().change_scene("res://Scenes/Shop.tscn")

# MEANER METER: when filled, queue an interlevel bonus token
func _on_meaner_meter_filled():
	# Test profile uses interlevel bonus tokens; all other players keep legacy wildcard behavior.
	if not _is_test_player():
		var root = get_tree().get_current_scene()
		var grid = null
		if root != null:
			grid = root.get_node_or_null("Grid")
			if grid == null:
				grid = root.find_node("Grid", true, false)
		if grid != null and grid.has_method("spawn_wildcard_safely"):
			grid.call("spawn_wildcard_safely")
		if PlayerManager != null and PlayerManager.has_method("reset_meaner_meter"):
			PlayerManager.reset_meaner_meter()
		return

	if PlayerManager != null and PlayerManager.has_method("queue_bonus_game_token"):
		PlayerManager.queue_bonus_game_token("meaner_meter")
	if PlayerManager != null and PlayerManager.has_method("reset_meaner_meter"):
		PlayerManager.reset_meaner_meter()

func _ensure_canvas_layer():
	var root = get_tree().get_current_scene()
	if root == null:
		return null
	var layer = root.get_node_or_null("CanvasLayer")
	if layer == null:
		layer = root.find_node("CanvasLayer", true, false)
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "CanvasLayer"
		root.add_child(layer)
	return layer

func _show_bonus_slot():
	var layer = _ensure_canvas_layer()
	if layer == null:
		return
	var existing = layer.get_node_or_null("BonusSlot")
	if existing != null:
		return
	var slot_scene = preload("res://Scenes/BonusSlotMachine.tscn")
	var slot = slot_scene.instance()
	# Safety: ensure the correct script is attached in case the scene was saved with a wrong script
	var expected_script_path = "res://Scripts/BonusSlotMachine.gd"
	# Force-attach the correct script to avoid stale/cached wrong scripts
	slot.set_script(load(expected_script_path))
	slot.name = "BonusSlot"
	# On iOS Safari, a topmost CanvasLayer can sometimes swallow touches
	# despite MOUSE_FILTER_IGNORE. Ensure the bonus slot's layer sits above
	# any decorative overlays (e.g., GoldBorderLayer) for reliable input.
	if layer is CanvasLayer:
		# Put bonus UI clearly on top
		layer.layer = 2001

	if slot.has_signal("finished"):
		slot.connect("finished", self, "_on_bonus_slot_closed")
	layer.add_child(slot)

func _on_bonus_slot_closed(_result = null):
	# Reset the meter after the bonus has been played
	if PlayerManager != null and PlayerManager.has_method("reset_meaner_meter"):
		PlayerManager.reset_meaner_meter()
	# Track frequent flyer achievement progress
	if PlayerManager != null and PlayerManager.has_method("increment_bonus_spins"):
		PlayerManager.increment_bonus_spins()

func play_bonus_game(game_id: String) -> Dictionary:
	if not _is_test_player():
		return {"game_id": game_id, "status": "blocked", "skipped": true, "error": "test_mode_only"}
	var layer = _ensure_canvas_layer()
	if layer == null:
		return {"game_id": game_id, "status": "error", "skipped": true, "error": "missing_canvas_layer"}
	if not BONUS_GAME_SCENES.has(game_id):
		return {"game_id": game_id, "status": "error", "skipped": true, "error": "unknown_game_id"}

	var scene_path: String = String(BONUS_GAME_SCENES[game_id])
	var packed = load(scene_path)
	if packed == null:
		return {"game_id": game_id, "status": "error", "skipped": true, "error": "load_failed", "scene": scene_path}

	var existing = layer.get_node_or_null("ActiveBonusGame")
	if existing != null:
		existing.queue_free()

	var instance = packed.instance()
	if instance == null:
		return {"game_id": game_id, "status": "error", "skipped": true, "error": "instance_failed", "scene": scene_path}

	instance.name = "ActiveBonusGame"
	layer.add_child(instance)
	if not instance.has_signal("finished"):
		instance.queue_free()
		return {"game_id": game_id, "status": "error", "skipped": true, "error": "missing_finished_signal"}

	var sig = yield(instance, "finished")
	var payload: Dictionary = {}
	if typeof(sig) == TYPE_DICTIONARY:
		payload = sig
	elif typeof(sig) == TYPE_ARRAY and sig.size() > 0 and typeof(sig[0]) == TYPE_DICTIONARY:
		payload = sig[0]
	if not payload.has("game_id"):
		payload["game_id"] = game_id
	if not payload.has("status"):
		if bool(payload.get("skipped", false)):
			payload["status"] = "skipped"
		else:
			payload["status"] = "completed"
	if not payload.has("skipped"):
		payload["skipped"] = String(payload.get("status", "")) == "skipped"
	return payload

func _on_meaner_meter_changed(cur, mx):
	if _meaner_bar != null:
		_meaner_bar.max_value = float(mx)
		_meaner_bar.value = float(cur)
	# Gauge already conveys percentage; keep label simple
	if _meaner_label != null:
		_meaner_label.text = "MEANER METER"
		# Ensure the bar encapsulates the label text height
		call_deferred("_size_meaner_meter_to_text")

func _add_meaner_meter_ui():
	# Avoid duplicates
	if get_node_or_null("MeanerMeterPanel") != null:
		return
	# Container (no visible frame) for top-center placement
	var panel = Control.new()
	panel.name = "MeanerMeterPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if panel.has_method("set_z_index"):
		panel.set_z_index(1004)
	# Top-center anchored bar
	panel.anchor_left = 0.5
	panel.anchor_top = 0.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.0
	panel.margin_left = -220.0
	panel.margin_right = 220.0
	panel.margin_top = 20.0
	panel.margin_bottom = 80.0
	add_child(panel)

	var vb = VBoxContainer.new()
	vb.anchor_left = 0
	vb.anchor_top = 0
	vb.anchor_right = 1
	vb.anchor_bottom = 1
	vb.margin_left = 10
	vb.margin_top = 6
	vb.margin_right = -10
	vb.margin_bottom = -6
	panel.add_child(vb)

	var pb = ProgressBar.new()
	pb.min_value = 0
	pb.max_value = 100
	pb.value = 0
	# Hide built-in percentage readout
	if pb.has_method("set_percent_visible") or pb.has_method("set"):
		# Godot 3 exposes property percent_visible
		pb.percent_visible = false
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Style the fill and background for visibility
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	pb.add_stylebox_override("bg", sb_bg)
	var sb_fill = StyleBoxFlat.new()
	sb_fill.bg_color = Color(1.0, 0.84, 0.0, 1.0)
	pb.add_stylebox_override("fg", sb_fill)
	vb.add_child(pb)
	_meaner_bar = pb

	# Centered label inside the meter itself
	var center_lbl = Label.new()
	center_lbl.text = "MEANER METER"
	center_lbl.align = Label.ALIGN_CENTER
	center_lbl.valign = Label.VALIGN_CENTER
	center_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_lbl.anchor_left = 0
	center_lbl.anchor_top = 0
	center_lbl.anchor_right = 1
	center_lbl.anchor_bottom = 1
	center_lbl.margin_left = 0
	center_lbl.margin_right = 0
	center_lbl.margin_top = 0
	center_lbl.margin_bottom = 0
	pb.add_child(center_lbl)
	_meaner_label = center_lbl

	# Ensure the meter height comfortably wraps the label text
	call_deferred("_size_meaner_meter_to_text")

func _size_meaner_meter_to_text():
	if _meaner_bar == null or _meaner_label == null:
		return
	# Measure the label's text height using its font and add padding
	var font = _meaner_label.get_font("font")
	var text_h = 0.0
	if font != null:
		# get_height is ascent + descent (line height) in Godot 3
		text_h = float(font.get_height())
	if text_h <= 0.0:
		# Fallback: try measured string height or a sensible default
		var sz = _meaner_label.get_font("font").get_string_size(_meaner_label.text) if _meaner_label.get_font("font") != null else Vector2(0, 24)
		text_h = sz.y if sz.y > 0.0 else 24.0
	var padding = max(6.0, text_h * 0.25)
	var min_sz = _meaner_bar.rect_min_size
	min_sz.y = text_h + padding
	_meaner_bar.rect_min_size = min_sz

# Adds a gold border to the outside edge of the display.
# Implemented as a full-screen Panel with a StyleBoxFlat border.
func _add_gold_border():
	# Ensure a dedicated topmost CanvasLayer for the border
	var layer: CanvasLayer = get_node_or_null("GoldBorderLayer") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "GoldBorderLayer"
		layer.layer = 1000
		add_child(layer)
	else:
		layer.layer = 1000

	# Avoid duplicates if _ready is called again
	var existing = layer.get_node_or_null("GoldBorderPanel")
	if existing != null:
		return

	var panel = Panel.new()
	panel.name = "GoldBorderPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if panel.has_method("set_z_index"):
		panel.set_z_index(1000)
	# Full-rect anchors
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.margin_left = 0.0
	panel.margin_top = 0.0
	panel.margin_right = 0.0
	panel.margin_bottom = 0.0
	# Gold-looking color and thickness
	var border_thickness = 8
	var gold = Color(1.0, 0.84, 0.0, 1.0)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0) # transparent center
	sb.border_color = gold
	sb.border_width_top = border_thickness
	sb.border_width_bottom = border_thickness
	sb.border_width_left = border_thickness
	sb.border_width_right = border_thickness
	# Optional rounded corners for a polished look
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	panel.add_stylebox_override("panel", sb)
	add_child(panel)

	# Very thin black inside stroke around the inner edge of the gold border
	var inner = Panel.new()
	inner.name = "GoldBorderInnerStroke"
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if inner.has_method("set_z_index"):
		inner.set_z_index(1001)
	# Anchor full, then inset by the gold thickness so the stroke hugs the inner edge
	inner.anchor_left = 0.0
	inner.anchor_top = 0.0
	inner.anchor_right = 1.0
	inner.anchor_bottom = 1.0
	inner.margin_left = border_thickness
	inner.margin_top = border_thickness
	inner.margin_right = -border_thickness
	inner.margin_bottom = -border_thickness
	var inner_sb = StyleBoxFlat.new()
	inner_sb.bg_color = Color(0, 0, 0, 0)
	inner_sb.border_color = Color(0, 0, 0, 1)
	# Thicker inner stroke
	var inner_w = 3
	inner_sb.border_width_top = inner_w
	inner_sb.border_width_bottom = inner_w
	inner_sb.border_width_left = inner_w
	inner_sb.border_width_right = inner_w
	# Match corner radius to sit inside the outer radius
	# Rounder inner corners to better match the outer border
	var inner_radius = 8
	inner_sb.corner_radius_top_left = inner_radius
	inner_sb.corner_radius_top_right = inner_radius
	inner_sb.corner_radius_bottom_left = inner_radius
	inner_sb.corner_radius_bottom_right = inner_radius
	inner.add_stylebox_override("panel", inner_sb)
	panel.add_child(inner)

	# Gold border gradient: fade from gold at the outer edge to white toward the inner edge
	var grad = ColorRect.new()
	grad.name = "GoldBorderGradient"
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Place above panel and stroke; will not cover stroke due to inner cut below
	if grad.has_method("set_z_index"):
		grad.set_z_index(1003)
	grad.anchor_left = 0.0
	grad.anchor_top = 0.0
	grad.anchor_right = 1.0
	grad.anchor_bottom = 1.0
	grad.margin_left = 0.0
	grad.margin_top = 0.0
	grad.margin_right = 0.0
	grad.margin_bottom = 0.0
	var min_dim = min(get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y)
	var thickness_norm = 0.06
	var inner_cut_norm = 0.0
	if min_dim > 0.0:
		thickness_norm = float(border_thickness) / min_dim
		inner_cut_norm = float(inner_w) / min_dim
	var gsh = Shader.new()
	gsh.code = "shader_type canvas_item;\n"
	gsh.code += "uniform float thickness = 0.06;\n"
	gsh.code += "uniform float inner_cut = 0.0;\n"
	gsh.code += "uniform vec4 outer_color : hint_color = vec4(1.0, 0.84, 0.0, 1.0);\n"
	gsh.code += "uniform vec4 inner_color : hint_color = vec4(1.0, 1.0, 1.0, 1.0);\n"
	gsh.code += "void fragment() {\n"
	gsh.code += "    vec2 uv = UV;\n"
	gsh.code += "    float d = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));\n"
	gsh.code += "    float usable = max(thickness - inner_cut, 0.0);\n"
	gsh.code += "    float a = step(d, usable);\n"
	gsh.code += "    float denom = max(usable, 1e-6);\n"
	gsh.code += "    float t = clamp(d / denom, 0.0, 1.0);\n"
	gsh.code += "    vec4 col = mix(outer_color, inner_color, t);\n"
	gsh.code += "    COLOR = vec4(col.rgb, col.a * a);\n"
	gsh.code += "}\n"
	var gmat = ShaderMaterial.new()
	gmat.shader = gsh
	gmat.set_shader_param("thickness", thickness_norm)
	gmat.set_shader_param("inner_cut", inner_cut_norm)
	gmat.set_shader_param("outer_color", gold)
	gmat.set_shader_param("inner_color", Color(1, 1, 1, 1))
	grad.material = gmat
	panel.add_child(grad)

	# Subtle black inner glow vignette inside the inner stroke
	var glow = ColorRect.new()
	glow.name = "GoldBorderInnerGlow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if glow.has_method("set_z_index"):
		glow.set_z_index(1002)
	# Inset so the glow starts at the inner stroke edge
	glow.anchor_left = 0.0
	glow.anchor_top = 0.0
	glow.anchor_right = 1.0
	glow.anchor_bottom = 1.0
	var inset = float(border_thickness + inner_w)
	glow.margin_left = inset
	glow.margin_top = inset
	glow.margin_right = -inset
	glow.margin_bottom = -inset
	# CanvasItem shader to draw a soft inner black glow using UV distance to edges
	var sh = Shader.new()
	sh.code = "shader_type canvas_item;\n"
	sh.code += "uniform float thickness : hint_range(0.0, 0.2) = 0.03;\n"
	sh.code += "uniform float strength : hint_range(0.0, 1.0) = 0.5;\n"
	sh.code += "void fragment() {\n"
	sh.code += "    vec2 uv = UV;\n"
	sh.code += "    float d = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));\n"
	sh.code += "    float a = smoothstep(thickness, 0.0, d) * strength;\n"
	sh.code += "    COLOR = vec4(0.0, 0.0, 0.0, a);\n"
	sh.code += "}\n"
	var mat = ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_param("thickness", 0.03)
	mat.set_shader_param("strength", 0.5)
	glow.material = mat
	panel.add_child(glow)

	# Add the panel to the topmost CanvasLayer so it renders above everything
	layer.add_child(panel)

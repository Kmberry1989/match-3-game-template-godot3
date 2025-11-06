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
	# Populate from achievement resources if the autoload exists
	achievements.clear()
	for child in trophy_grid.get_children():
		child.queue_free()

	var am = get_node_or_null("/root/AchievementManager")
	if am == null:
		return

	var achievement_list = []
	if am.has_method("get_achievements"):
		achievement_list = am.get_achievements()
	for achievement_id in achievement_list:
		var achievement_res = null
		if am.has_method("get_achievement_resource"):
			achievement_res = am.get_achievement_resource(achievement_id)
		if typeof(achievement_res) == TYPE_OBJECT and achievement_res != null:
			var id: String = achievement_res.id
			var display: String = achievement_res.name
			var unlocked := false
			if am.has_method("is_unlocked"):
				unlocked = am.is_unlocked(id)

			var unlocked_icon = achievement_res.icon
			var locked_icon = achievement_res.unachieved_icon

			var display_icon = unlocked_icon if unlocked else locked_icon
			if display_icon == null: # Fallback for missing locked_icon
				display_icon = unlocked_icon

			var item = {"id": id, "unlocked_icon": unlocked_icon, "locked_icon": locked_icon, "name": display, "unlocked": unlocked, "description": achievement_res.description}
			var idx = achievements.size()
			achievements.append(item)
			_add_thumbnail(trophy_grid, display_icon, display, unlocked, idx)

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
			viewer_desc.text = String(item.get("description", ""))
			viewer_desc.hint_tooltip = status_text
		viewer_label.hint_tooltip = status_text
		viewer_image.hint_tooltip = status_text

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


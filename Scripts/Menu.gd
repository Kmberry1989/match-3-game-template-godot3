extends Control

var status_label
var offline_button
var profile_button
var showcase_button
var shop_button
var logout_button
var multiplayer_button
onready var firebase = get_node("/root/Firebase") if has_node("/root/Firebase") else null

# Preload button textures so they're included in export bundles
onready var _tex_play = preload("res://Assets/Visuals/PLAY.png")
onready var _tex_profile = preload("res://Assets/Visuals/PROFILE.png")
onready var _tex_showcase = preload("res://Assets/Visuals/SHOWCASE.png")
onready var _tex_shop = preload("res://Assets/Visuals/SHOP.png")

func _ready():
	status_label = Label.new()
	offline_button = TextureButton.new()
	profile_button = TextureButton.new()
	showcase_button = TextureButton.new()
	shop_button = TextureButton.new()
	logout_button = TextureButton.new()
	multiplayer_button = TextureButton.new()

	var bg = TextureRect.new()
	bg.texture = load("res://Assets/Visuals/main_menu_background.png")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.expand = true
	bg.anchor_left = 0
	bg.anchor_top = 0
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	bg.margin_left = 0
	bg.margin_top = 0
	bg.margin_right = 0
	bg.margin_bottom = 0
	add_child(bg)
	move_child(bg, 0)

	var center_container = CenterContainer.new()
	center_container.anchor_left = 0
	center_container.anchor_top = 0
	center_container.anchor_right = 1
	center_container.anchor_bottom = 1
	center_container.margin_left = 0
	center_container.margin_top = 0
	center_container.margin_right = 0
	center_container.margin_bottom = 0
	add_child(center_container)

	var offset_container = MarginContainer.new()
	offset_container.add_constant_override("margin_top", 200)
	center_container.add_child(offset_container)

	var vbox = VBoxContainer.new()
	vbox.add_constant_override("separation", 24)
	offset_container.add_child(vbox)

	var title = Label.new()
	title.text = " "
	title.align = Label.ALIGN_CENTER
	vbox.add_child(title)

	var margin = Control.new()
	margin.rect_min_size = Vector2(0, 40)
	vbox.add_child(margin)

	var normal_tex = load("res://Assets/Visuals/button_normal.svg")
	var hover_tex = load("res://Assets/Visuals/button_hover.svg")
	var pressed_tex = load("res://Assets/Visuals/button_pressed.svg")

	offline_button.set_normal_texture(_tex_play)
	offline_button.set_pressed_texture(_tex_play)
	offline_button.set_hover_texture(_tex_play)
	offline_button.connect("pressed", self, "_on_offline_button_pressed")
	# Enlarge the entire button so its label scales up when no font is present
	offline_button.rect_scale = Vector2(2.5, 2.5)
	vbox.add_child(offline_button)

	var offline_label = Label.new()
	offline_label.text = "Play"
	offline_label.anchor_left = 0
	offline_label.anchor_top = 0
	offline_label.anchor_right = 1
	offline_label.anchor_bottom = 1
	offline_label.margin_left = 0
	offline_label.margin_top = 0
	offline_label.margin_right = 0
	offline_label.margin_bottom = 0
	offline_label.align = Label.ALIGN_CENTER
	offline_label.valign = Label.VALIGN_CENTER
	# Keep centered inside the button; font size handled via _apply_big_font()
	offline_label.align = Label.ALIGN_CENTER
	offline_label.valign = Label.VALIGN_CENTER
	_apply_big_font(offline_label, 56)
	offline_label.visible = false
	offline_button.add_child(offline_label)

	profile_button.set_normal_texture(_tex_profile)
	profile_button.set_pressed_texture(_tex_profile)
	profile_button.set_hover_texture(_tex_profile)
	profile_button.connect("pressed", self, "_on_profile_button_pressed")
	profile_button.rect_scale = Vector2(2.5, 2.5)
	vbox.add_child(profile_button)

	var profile_label = Label.new()
	profile_label.text = "Profile"
	profile_label.anchor_left = 0
	profile_label.anchor_top = 0
	profile_label.anchor_right = 1
	profile_label.anchor_bottom = 1
	profile_label.margin_left = 0
	profile_label.margin_top = 0
	profile_label.margin_right = 0
	profile_label.margin_bottom = 0
	profile_label.align = Label.ALIGN_CENTER
	profile_label.valign = Label.VALIGN_CENTER
	profile_label.align = Label.ALIGN_CENTER
	profile_label.valign = Label.VALIGN_CENTER
	_apply_big_font(profile_label, 48)
	profile_label.visible = false
	profile_button.add_child(profile_label)

	# Hints removed

	showcase_button.set_normal_texture(_tex_showcase)
	showcase_button.set_pressed_texture(_tex_showcase)
	showcase_button.set_hover_texture(_tex_showcase)
	showcase_button.connect("pressed", self, "_on_showcase_button_pressed")
	showcase_button.rect_scale = Vector2(2.5, 2.5)
	vbox.add_child(showcase_button)

	var showcase_label = Label.new()
	showcase_label.text = "Showcase"
	showcase_label.anchor_left = 0
	showcase_label.anchor_top = 0
	showcase_label.anchor_right = 1
	showcase_label.anchor_bottom = 1
	showcase_label.margin_left = 0
	showcase_label.margin_top = 0
	showcase_label.margin_right = 0
	showcase_label.margin_bottom = 0
	showcase_label.align = Label.ALIGN_CENTER
	showcase_label.valign = Label.VALIGN_CENTER
	showcase_label.align = Label.ALIGN_CENTER
	showcase_label.valign = Label.VALIGN_CENTER
	_apply_big_font(showcase_label, 48)
	showcase_label.visible = false
	showcase_button.add_child(showcase_label)

	shop_button.set_normal_texture(_tex_shop)
	shop_button.set_pressed_texture(_tex_shop)
	shop_button.set_hover_texture(_tex_shop)
	shop_button.connect("pressed", self, "_on_shop_button_pressed")
	shop_button.rect_scale = Vector2(2.5, 2.5)
	vbox.add_child(shop_button)

	var shop_label = Label.new()
	shop_label.text = "Shop"
	shop_label.anchor_left = 0
	shop_label.anchor_top = 0
	shop_label.anchor_right = 1
	shop_label.anchor_bottom = 1
	shop_label.margin_left = 0
	shop_label.margin_top = 0
	shop_label.margin_right = 0
	shop_label.margin_bottom = 0
	shop_label.align = Label.ALIGN_CENTER
	shop_label.valign = Label.VALIGN_CENTER
	shop_label.align = Label.ALIGN_CENTER
	shop_label.valign = Label.VALIGN_CENTER
	_apply_big_font(shop_label, 48)
	shop_label.visible = false
	shop_button.add_child(shop_label)

	multiplayer_button.set_normal_texture(normal_tex)
	multiplayer_button.set_pressed_texture(pressed_tex)
	multiplayer_button.set_hover_texture(hover_tex)
	multiplayer_button.connect("pressed", self, "_on_multiplayer_button_pressed")
	multiplayer_button.rect_scale = Vector2(2.5, 2.5)
	vbox.add_child(multiplayer_button)

	var mp_label = Label.new()
	mp_label.text = "Multiplayer"
	mp_label.anchor_left = 0
	mp_label.anchor_top = 0
	mp_label.anchor_right = 1
	mp_label.anchor_bottom = 1
	mp_label.margin_left = 0
	mp_label.margin_top = 0
	mp_label.margin_right = 0
	mp_label.margin_bottom = 0
	mp_label.align = Label.ALIGN_CENTER
	mp_label.valign = Label.VALIGN_CENTER
	mp_label.align = Label.ALIGN_CENTER
	mp_label.valign = Label.VALIGN_CENTER
	_apply_big_font(mp_label, 42)
	multiplayer_button.add_child(mp_label)
	# Hide multiplayer for this build
	multiplayer_button.visible = false

	logout_button.set_normal_texture(normal_tex)
	logout_button.set_pressed_texture(pressed_tex)
	logout_button.set_hover_texture(hover_tex)
	logout_button.connect("pressed", self, "_on_logout_button_pressed")
	logout_button.rect_scale = Vector2(2.5, 2.5)
	vbox.add_child(logout_button)

	var logout_label = Label.new()
	logout_label.text = "Logout"
	logout_label.anchor_left = 0
	logout_label.anchor_top = 0
	logout_label.anchor_right = 1
	logout_label.anchor_bottom = 1
	logout_label.margin_left = 0
	logout_label.margin_top = 0
	logout_label.margin_right = 0
	logout_label.margin_bottom = 0
	logout_label.align = Label.ALIGN_CENTER
	logout_label.valign = Label.VALIGN_CENTER
	logout_label.align = Label.ALIGN_CENTER
	logout_label.valign = Label.VALIGN_CENTER
	_apply_big_font(logout_label, 42)
	logout_button.add_child(logout_label)

 

	_update_logout_visibility()

	status_label.text = ""
	status_label.align = Label.ALIGN_CENTER
	status_label.rect_min_size = Vector2(300, 50)
	status_label.rect_scale = Vector2(1.8, 1.8)
	vbox.add_child(status_label)

	AudioManager.play_music("menu")

	if firebase != null:
		firebase.Auth.connect("login_succeeded", self, "_update_logout_visibility")
		firebase.Auth.connect("logged_out", self, "_update_logout_visibility")

func _on_offline_button_pressed():
	print("[Menu.gd] Play button pressed.")
	AudioManager.play_sound("ui_click")
	_start_game()

func _on_profile_button_pressed():
	AudioManager.play_sound("ui_click")
	get_tree().change_scene("res://Scenes/Profile.tscn")

func _on_showcase_button_pressed():
	AudioManager.play_sound("ui_click")
	get_tree().change_scene("res://Scenes/Showcase.tscn")

func _on_shop_button_pressed():
	AudioManager.play_sound("ui_click")
	get_tree().change_scene("res://Scenes/Shop.tscn")

func _on_multiplayer_button_pressed():
	AudioManager.play_sound("ui_click")
	get_tree().change_scene("res://Scenes/MultiplayerLobby.tscn")

func _start_game():
	print("[Menu.gd] _start_game: Stopping music and playing sound.")
	AudioManager.stop_music()
	AudioManager.play_sound("game_start")
	print("[Menu.gd] _start_game: Setting session mode to single-player.")
	if Engine.has_singleton("MultiplayerManager"):
		MultiplayerManager.session_mode = "singleplayer"
	print("[Menu.gd] _start_game: Changing to intermediate Loading scene.")
	get_tree().change_scene("res://Scenes/Loading.tscn")

func _update_logout_visibility():
	var logout_visible = false
	if firebase != null:
		logout_visible = firebase.Auth.is_logged_in()
	logout_button.visible = logout_visible

func _on_logout_button_pressed():
	AudioManager.play_sound("ui_click")
	if firebase != null:
		firebase.Auth.logout()
	PlayerManager.player_uid = ""
	get_tree().change_scene("res://Scenes/Login.tscn")

func _apply_big_font(lbl: Label, size: int) -> void:
	# Use a DynamicFont if one exists under Assets/Fonts; otherwise keep default theme
	var base = "res://Assets/Fonts"
	var font_path = ""
	var preferred = [
		base + "/Menu.ttf",
		base + "/menu.ttf",
		base + "/Menu.otf",
		base + "/menu.otf"
	]
	for p in preferred:
		if ResourceLoader.exists(p):
			font_path = p
			break
	if font_path == "":
		var dir = Directory.new()
		if dir.open(base) == OK:
			dir.list_dir_begin(true, true)
			var fn = dir.get_next()
			while fn != "":
				if not dir.current_is_dir():
					var lower = fn.to_lower()
					if lower.ends_with(".ttf") or lower.ends_with(".otf"):
						font_path = base + "/" + fn
						break
				fn = dir.get_next()
			dir.list_dir_end()
	if font_path != "":
		var df = DynamicFont.new()
		var dfd = DynamicFontData.new()
		dfd.font_path = font_path
		df.font_data = dfd
		df.size = size
		lbl.add_font_override("font", df)

# Hints removed

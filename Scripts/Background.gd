extends TextureRect

export(Array, Texture) var textures = []

export(float) var fade_duration = 1.0
export(float) var hold_duration = 5.0
export(float) var hue_shift_speed = 0.05

var current_texture_index = 0
var tween = null
var time = 0.0
onready var PlayerManager = get_node_or_null("/root/PlayerManager")
const CosmeticsCatalog = preload("res://Scripts/CosmeticsCatalog.gd")

func _ready():
    # Discover any bg*.jpg files in Assets and build a playlist
    var found = []
    var dir = Directory.new()
    if dir.open("res://Assets") == OK:
        dir.list_dir_begin(true, true)
        var fn = dir.get_next()
        while fn != "":
            if not dir.current_is_dir():
                var lower = fn.to_lower()
                if lower.begins_with("bg") and lower.ends_with(".jpg"):
                    found.append(fn)
            fn = dir.get_next()
        dir.list_dir_end()
    found.sort()
    if found.size() > 0:
        textures.clear()
        for name in found:
            var path = "res://Assets/" + name
            var tex = load(path)
            if tex is Texture:
                textures.append(tex)
    # Fallback if none discovered
    if textures.size() == 0:
        var defaults = [
            "res://Assets/bg1.jpg",
            "res://Assets/bg2.jpg",
            "res://Assets/bg3.jpg",
            "res://Assets/bg4.jpg"
        ]
        for p in defaults:
            if ResourceLoader.exists(p):
                var t = load(p)
                if t is Texture:
                    textures.append(t)
    if textures.size() == 0:
        return
    texture = textures[current_texture_index]
    modulate = Color(1, 1, 1, 0) # Start transparent for the first fade-in
    _apply_current_theme()
    cycle_background()

    if PlayerManager != null and PlayerManager.has_method("get_equipped_cosmetic"):
        if not PlayerManager.is_connected("cosmetic_equipped", self, "_on_cosmetic_equipped"):
            PlayerManager.connect("cosmetic_equipped", self, "_on_cosmetic_equipped")

func cycle_background():
	if tween:
		tween.queue_free()
	
	tween = Tween.new()
	add_child(tween)

	change_texture()

	# Fade in
	tween.interpolate_property(self, "modulate", Color(1, 1, 1, 0), Color(1, 1, 1, 1), fade_duration, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)

	# Fade out (with delay)
	var fade_out_delay = fade_duration + hold_duration
	tween.interpolate_property(self, "modulate", Color(1, 1, 1, 1), Color(1, 1, 1, 0), fade_duration, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, fade_out_delay)

	tween.start()
	tween.connect("tween_all_completed", self, "cycle_background")

func change_texture():
	current_texture_index = (current_texture_index + 1) % textures.size()
	texture = textures[current_texture_index]

func _apply_current_theme() -> void:
	if PlayerManager != null and PlayerManager.has_method("get_equipped_cosmetic"):
		var theme_id = String(PlayerManager.get_equipped_cosmetic("board_theme"))
		apply_board_theme(theme_id)

func apply_board_theme(theme_id: String) -> void:
	var item = CosmeticsCatalog.get_item("board_theme", theme_id)
	var visual = item.get("visual", {})
	var tint = visual.get("modulate", Color(1, 1, 1, 1))
	self_modulate = tint

func _on_cosmetic_equipped(category: String, id: String) -> void:
	if category == "board_theme":
		apply_board_theme(id)

func _process(_delta):
	#time += delta * hue_shift_speed
	#var hue = fmod(time, 1.0)
	#modulate = Color.from_hsv(hue, 0.5, 1.0)
	pass

func _exit_tree():
	if tween:
		tween.queue_free()
		tween = null

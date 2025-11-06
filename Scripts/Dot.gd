extends Node2D

const PULSE_SCALE_MAX = Vector2(0.2725, 0.2725)
const PULSE_SCALE_MIN = Vector2(0.2575, 0.2575)
const DOT_SCALE = 2.0 # Global multiplier to enlarge dot visuals
const REFERENCE_DOT_PX = 512.0

export var color = ""
onready var sprite = get_node("Sprite")
var matched = false
var scale_multiplier = 1.0
var is_wildcard = false

# Emitted when the match fade-out finishes; used to trigger XP orbs immediately.
signal match_faded(global_pos, color_name)

var pulse_tween = null
var float_tween = null
var shadow = null
var glasses_overlay = null
var has_glasses = false
var jail_overlay: Sprite = null
var is_arrested: bool = false
var wildcard_glow: Sprite = null
var wildcard_glow_tween = null
var jailed_scale_mult: float = 1.0

# Whether an XP orb has already been spawned for this dot in the current match.
var orb_spawned = false

# Visual Effects
onready var flash_texture = preload("res://Assets/Visuals/bright_flash.png")

# Animation state and textures
var animation_state = "normal"  # normal, blinking, sad, idle, surprised
var normal_texture
var blink_texture
var sad_texture
var sleepy_texture
var surprised_texture
var yawn_texture

var last_yawn_time = 0
const YAWN_COOLDOWN = 2500 # 2.5 seconds in milliseconds

onready var blink_timer = Timer.new()
onready var wildcard_timer = Timer.new()
var wildcard_textures = []
var _wildcard_index = 0

# Mapping from color to character name
var color_to_character = {
	"yellow": "bethany",
	"brown": "caleb",
	"gray": "eric",
	"pink": "kristen",
	"green": "kyle",
	"purple": "connie",
	"red": "rochelle",
	"blue": "vickie",
	"orange": "maia"
}

# Mapping from color to pulse duration
var color_to_pulse_duration = {
	"red": 1,
	"orange": 1,
	"yellow": 1,
	"green": 1,
	"blue": 1,
	"purple": 1,
	"pink": 1,
	"brown": 1,
	"gray": 1
}

var mouse_inside = false

func _ready():
	load_textures()
	# Adjust dot scale based on texture size so in-game size stays consistent
	if sprite and sprite.texture:
		var tex_w = float(sprite.texture.get_width())
		var tex_h = float(sprite.texture.get_height())
		var max_dim = max(tex_w, tex_h)
		if max_dim > 0.0:
			scale_multiplier = (REFERENCE_DOT_PX / max_dim) * DOT_SCALE
	create_shadow()
	setup_blink_timer()
	setup_wildcard_timer()
	start_floating()
	start_pulsing()
	
	var area = Area2D.new()
	add_child(area)
	area.connect("mouse_entered", self, "_on_mouse_entered")
	area.connect("mouse_exited", self, "_on_mouse_exited")

	# Wait for the sprite texture to be loaded
	yield(get_tree(), "idle_frame")

	var texture = sprite.texture
	if texture:
		var collision_shape = CollisionShape2D.new()
		var square_shape = RectangleShape2D.new()
		var max_dimension = max(texture.get_width(), texture.get_height())
		var target_scale = max(PULSE_SCALE_MAX.x, PULSE_SCALE_MAX.y) * scale_multiplier
		var side_length = max_dimension * target_scale
		square_shape.extents = Vector2(side_length, side_length) / 2.0
		collision_shape.shape = square_shape
		area.add_child(collision_shape)

func _process(_delta):
	if mouse_inside:
		pass

func _on_mouse_entered():
	mouse_inside = true
	if pulse_tween:
		pulse_tween.stop_all()
	
	# Set scale to the largest size from the pulse animation
	sprite.scale = PULSE_SCALE_MAX * scale_multiplier
	play_surprised_animation()

func _on_mouse_exited():
	mouse_inside = false
	sprite.scale = PULSE_SCALE_MIN * scale_multiplier # Reset scale
	start_pulsing()
	set_normal_texture()

func play_surprised_animation():
	if animation_state == "normal":
		AudioManager.play_sound("surprised")
		animation_state = "surprised"
		sprite.texture = surprised_texture

func play_drag_sad_animation():
	animation_state = "sad"
	sprite.texture = sad_texture

func move(new_position, duration = 0.2):
	var tween = Tween.new()
	add_child(tween)
	tween.interpolate_property(self, "position", position, new_position, duration, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	return tween

func play_match_animation(delay):
	var tween = Tween.new()
	add_child(tween)
	tween.interpolate_callback(self, delay, "show_flash")
	tween.interpolate_property(self, "scale", scale, scale * 1.5, 0.3, Tween.TRANS_SINE, Tween.EASE_OUT, delay)
	tween.interpolate_property(self, "modulate:a", 1.0, 0.0, 0.3, Tween.TRANS_SINE, Tween.EASE_OUT, delay)
	tween.start()
	tween.connect("tween_all_completed", self, "_on_match_fade_finished")

func _on_match_fade_finished():
	if not orb_spawned:
		orb_spawned = true
		emit_signal("match_faded", global_position, color)

func show_flash():
	var flash = Sprite.new()
	flash.texture = flash_texture
	flash.centered = true
	flash.modulate = Color(1,1,1,0.7)
	add_child(flash)
	var tween = Tween.new()
	add_child(tween)
	tween.interpolate_property(flash, "scale", Vector2(1,1), Vector2(2,2), 0.3, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.interpolate_property(flash, "modulate:a", 0.7, 0.0, 0.3, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.interpolate_callback(flash, 0.3, "queue_free")
	tween.start()

func play_sad_animation():
	animation_state = "sad"
	sprite.texture = sad_texture

func play_surprised_for_a_second():
	if animation_state == "normal":
		AudioManager.play_sound("surprised")
		animation_state = "surprised"
		sprite.texture = surprised_texture
		var timer = Timer.new()
		add_child(timer)
		timer.one_shot = true
		timer.wait_time = 1.0
		timer.start()
		yield(timer, "timeout")
		timer.queue_free()
		if animation_state == "surprised":
			set_normal_texture()

func create_shadow():
	shadow = Sprite.new()
	var gradient = Gradient.new()
	gradient.colors = [Color(0,0,0,0.4), Color(0,0,0,0)] # Black center, transparent edge
	var gradient_tex = GradientTexture.new()
	gradient_tex.gradient = gradient
	gradient_tex.width = 64
	shadow.texture = gradient_tex
	shadow.scale = Vector2(1, 0.5) # Make it oval
	shadow.z_index = -1
	shadow.position = Vector2(0, 35)
	add_child(shadow)
	# Hide shadow to remove it visually
	shadow.visible = false
	shadow.modulate.a = 0.0

func load_textures():
	var character = color_to_character.get(color, "bethany") # Default to bethany if color not found
	
	# Construct texture paths to use the 'Dots' subfolder.
	var base_path = "res://Assets/Dots/" + character + "avatar"
	normal_texture = load(base_path + ".png")
	blink_texture = load(base_path + "blink.png")
	sad_texture = load(base_path + "sad.png")
	sleepy_texture = load(base_path + "sleepy.png")
	surprised_texture = load(base_path + "surprised.png")
	yawn_texture = load(base_path + "yawn.png")
	
	sprite.texture = normal_texture

func set_normal_texture():
	if is_wildcard:
		return
	animation_state = "normal"
	sprite.texture = normal_texture
	clear_jail_overlay()

func reset_to_normal_state():
	if is_wildcard:
		return
	set_normal_texture()

func apply_glasses_overlay() -> void:
	has_glasses = true
	if glasses_overlay == null:
		glasses_overlay = Sprite.new()
		glasses_overlay.centered = true
		var tex = load("res://Assets/Visuals/avatar_glasses.png")
		if tex is Texture:
			glasses_overlay.texture = tex
		glasses_overlay.z_index = 6
		add_child(glasses_overlay)
	# Animated introduction: quick fade/scale pop and tiny wiggle
	glasses_overlay.modulate.a = 0.0
	glasses_overlay.scale = sprite.scale * 0.4
	var tw = get_tree().create_tween()
	tw.set_parallel(true)
	tw.tween_property(glasses_overlay, "modulate:a", 1.0, 0.18)
	tw.tween_property(glasses_overlay, "scale", sprite.scale * 1.15, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(glasses_overlay, "rotation_degrees", 6.0, 0.09)
	tw.tween_property(glasses_overlay, "rotation_degrees", -4.0, 0.08)
	tw.tween_property(glasses_overlay, "rotation_degrees", 0.0, 0.07)
	# Ensure final alignment
	var tw2 = get_tree().create_tween()
	tw2.tween_property(glasses_overlay, "scale", sprite.scale, 0.1)

func clear_glasses_overlay() -> void:
	has_glasses = false
	if glasses_overlay != null and is_instance_valid(glasses_overlay):
		glasses_overlay.queue_free()
	glasses_overlay = null
	_stop_wildcard_glow()

func setup_blink_timer():
	blink_timer.connect("timeout", self, "_on_blink_timer_timeout")
	blink_timer.set_one_shot(true)
	add_child(blink_timer)
	blink_timer.start(rand_range(4.0, 12.0))

func setup_wildcard_timer():
	add_child(wildcard_timer)
	wildcard_timer.one_shot = false
	wildcard_timer.wait_time = 0.12
	wildcard_timer.connect("timeout", self, "_on_wildcard_tick")

func _on_wildcard_tick():
	if not is_wildcard:
		wildcard_timer.stop()
		return
	if wildcard_textures.size() == 0:
		return
	_wildcard_index = (_wildcard_index + 1) % wildcard_textures.size()
	sprite.texture = wildcard_textures[_wildcard_index]

func set_wildcard(enable = true):
	is_wildcard = enable
	if enable:
		animation_state = "wildcard"
		# Build a list of normal textures across all characters/colors
		wildcard_textures.clear()
		for col in color_to_character.keys():
			var character = color_to_character[col]
			var base_path = "res://Assets/Dots/" + character + "avatar"
			var tex = load(base_path + ".png")
			if tex:
				wildcard_textures.append(tex)
		if wildcard_textures.size() > 0:
			_wildcard_index = 0
			sprite.texture = wildcard_textures[_wildcard_index]
			wildcard_timer.start()
		# Make the shadow slightly brighter for wildcard
		if shadow:
			shadow.modulate = Color(0.2,0.2,0.2,0.6)
		_ensure_wildcard_glow()
		_start_wildcard_glow()
	else:
		wildcard_timer.stop()
		animation_state = "normal"
		set_normal_texture()
		_stop_wildcard_glow()

func start_floating():
	if float_tween:
		float_tween.stop_all()
	float_tween = Tween.new()
	add_child(float_tween)
	float_tween.interpolate_property(sprite, "position:y", 5, -5, 1.5, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	float_tween.interpolate_property(sprite, "position:y", -5, 5, 1.5, Tween.TRANS_SINE, Tween.EASE_IN_OUT, 1.5)
	float_tween.start()
	float_tween.connect("tween_all_completed", self, "start_floating")

func start_pulsing(sync_pulse = true):
	if pulse_tween:
		pulse_tween.stop_all()
		if is_instance_valid(pulse_tween):
			pulse_tween.queue_free()
		pulse_tween = null

	var pulse_duration = color_to_pulse_duration.get(color, 1.5) # Default to 1.5 if color not found

	# Smoothly align to the baseline before starting the synchronized loop
	if sync_pulse:
		var align = Tween.new()
		add_child(align)
		var target_min = PULSE_SCALE_MIN * scale_multiplier * jailed_scale_mult
		align.interpolate_property(sprite, "scale", sprite.scale, target_min, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT)
		if jail_overlay != null:
			align.interpolate_property(jail_overlay, "scale", jail_overlay.scale, target_min, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT)
		if wildcard_glow != null:
			align.interpolate_property(wildcard_glow, "scale", wildcard_glow.scale, target_min * 1.3, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT)
		align.start()
		align.connect("tween_all_completed", self, "_do_pulse_cycle", [pulse_duration])
	else:
		_do_pulse_cycle(pulse_duration)

func _start_pulsing_no_sync():
	start_pulsing(false)

func _do_pulse_cycle(pulse_duration):
	if pulse_tween:
		pulse_tween.stop_all()
		if is_instance_valid(pulse_tween):
			pulse_tween.queue_free()
		pulse_tween = null
	pulse_tween = Tween.new()
	add_child(pulse_tween)
	pulse_tween.interpolate_property(sprite, "scale", PULSE_SCALE_MIN * scale_multiplier * jailed_scale_mult, PULSE_SCALE_MAX * scale_multiplier * jailed_scale_mult, pulse_duration, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	pulse_tween.interpolate_property(sprite, "scale", PULSE_SCALE_MAX * scale_multiplier * jailed_scale_mult, PULSE_SCALE_MIN * scale_multiplier * jailed_scale_mult, pulse_duration, Tween.TRANS_SINE, Tween.EASE_IN_OUT, pulse_duration)
	if jail_overlay != null:
		pulse_tween.interpolate_property(jail_overlay, "scale", PULSE_SCALE_MIN * scale_multiplier * jailed_scale_mult, PULSE_SCALE_MAX * scale_multiplier * jailed_scale_mult, pulse_duration, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		pulse_tween.interpolate_property(jail_overlay, "scale", PULSE_SCALE_MAX * scale_multiplier * jailed_scale_mult, PULSE_SCALE_MIN * scale_multiplier * jailed_scale_mult, pulse_duration, Tween.TRANS_SINE, Tween.EASE_IN_OUT, pulse_duration)
	if glasses_overlay != null:
		pulse_tween.interpolate_property(glasses_overlay, "scale", PULSE_SCALE_MIN * scale_multiplier, PULSE_SCALE_MAX * scale_multiplier, pulse_duration, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		pulse_tween.interpolate_property(glasses_overlay, "scale", PULSE_SCALE_MAX * scale_multiplier, PULSE_SCALE_MIN * scale_multiplier, pulse_duration, Tween.TRANS_SINE, Tween.EASE_IN_OUT, pulse_duration)
	if wildcard_glow != null:
		pulse_tween.interpolate_property(wildcard_glow, "scale", PULSE_SCALE_MIN * scale_multiplier * 1.2, PULSE_SCALE_MAX * scale_multiplier * 1.4, pulse_duration, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		pulse_tween.interpolate_property(wildcard_glow, "scale", PULSE_SCALE_MAX * scale_multiplier * 1.4, PULSE_SCALE_MIN * scale_multiplier * 1.2, pulse_duration, Tween.TRANS_SINE, Tween.EASE_IN_OUT, pulse_duration)
	pulse_tween.start()
	pulse_tween.connect("tween_all_completed", self, "_start_pulsing_no_sync")

# Rainbow glow for wildcards
func _ensure_wildcard_glow() -> void:
	if wildcard_glow != null:
		return
	wildcard_glow = Sprite.new()
	wildcard_glow.centered = true
	wildcard_glow.texture = flash_texture
	wildcard_glow.modulate = Color(1,0,0,0.55)
	wildcard_glow.z_index = -2
	wildcard_glow.scale = Vector2(1.2, 1.2) * scale_multiplier
	add_child(wildcard_glow)

func _start_wildcard_glow() -> void:
	_stop_wildcard_glow()
	if wildcard_glow == null:
		return
	var seq = [
		Color(1,0,0,0.55),
		Color(1,0.6,0,0.55),
		Color(1,1,0,0.55),
		Color(0,1,0,0.55),
		Color(0,1,1,0.55),
		Color(0,0.4,1,0.55),
		Color(1,0,1,0.55)
	]
	wildcard_glow_tween = get_tree().create_tween()
	wildcard_glow_tween.set_loops()
	for c in seq:
		wildcard_glow_tween.tween_property(wildcard_glow, "modulate", c, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_wildcard_glow() -> void:
	if wildcard_glow_tween != null:
		if wildcard_glow_tween.has_method("kill"):
			wildcard_glow_tween.kill()
		elif wildcard_glow_tween.has_method("stop_all"):
			wildcard_glow_tween.stop_all()
		if is_instance_valid(wildcard_glow_tween):
			wildcard_glow_tween.queue_free()
		wildcard_glow_tween = null
	if wildcard_glow != null and is_instance_valid(wildcard_glow):
		wildcard_glow.queue_free()
	wildcard_glow = null

func apply_jail_overlay(stage: int) -> void:
	is_arrested = true
	if jail_overlay == null:
		jail_overlay = Sprite.new()
		jail_overlay.centered = true
		jail_overlay.z_index = 5
		add_child(jail_overlay)
	var tex_path = "res://Assets/Visuals/avatar_injail" + str(stage) + ".png"
	var tex = load(tex_path)
	if tex is Texture:
		jail_overlay.texture = tex
	# Ensure overlay is above the dot and both are scaled down to 0.75 while jailed
	var behind_z = int(jail_overlay.z_index) - 1
	if sprite is CanvasItem:
		sprite.z_index = behind_z
	jailed_scale_mult = 0.75
	jail_overlay.scale = sprite.scale
	start_pulsing(true)

func update_jail_overlay(stage: int) -> void:
	if jail_overlay == null:
		return
	var tex_path = "res://Assets/Visuals/avatar_injail" + str(stage) + ".png"
	var tex = load(tex_path)
	if tex is Texture:
		jail_overlay.texture = tex

func show_jailbreak_then_clear() -> void:
	if jail_overlay == null:
		return
	var tex = load("res://Assets/Visuals/avatar_jailbreak.png")
	if tex is Texture:
		jail_overlay.texture = tex
	# Scale pop on break and fade away overlay
	var t = get_tree().create_tween()
	t.set_parallel(true)
	t.tween_property(sprite, "scale", sprite.scale * 1.25, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(jail_overlay, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	yield(t, "finished")
	clear_jail_overlay()
	reset_to_normal_state()
	# Remove this dot entirely after the break animation
	queue_free()

func clear_jail_overlay() -> void:
	if jail_overlay != null:
		if is_instance_valid(jail_overlay):
			jail_overlay.queue_free()
	jail_overlay = null
	is_arrested = false
	jailed_scale_mult = 1.0

func play_shake(duration := 0.18, magnitude := 6.0) -> void:
	# Brief positional shake around current position
	var base_pos = position
	var tw = get_tree().create_tween()
	tw.tween_property(self, "position", base_pos + Vector2(magnitude, 0), duration * 0.25)
	tw.tween_property(self, "position", base_pos + Vector2(-magnitude, 0), duration * 0.25)
	tw.tween_property(self, "position", base_pos + Vector2(0, magnitude), duration * 0.25)
	tw.tween_property(self, "position", base_pos, duration * 0.25)

func _on_blink_timer_timeout():
	if animation_state == "normal":
		animation_state = "blinking"
		sprite.texture = blink_texture
		var timer = Timer.new()
		add_child(timer)
		timer.one_shot = true
		timer.wait_time = 0.15
		timer.start()
		yield(timer, "timeout")
		timer.queue_free()
		if animation_state == "blinking": # Ensure state wasn't changed by a higher priority animation
			set_normal_texture()
	
	blink_timer.start(rand_range(4.0, 12.0))

func play_idle_animation():
	var current_time = OS.get_ticks_msec()
	if current_time - last_yawn_time < YAWN_COOLDOWN:
		return # Cooldown is active, so we do nothing.

	if animation_state != "normal":
		return

	last_yawn_time = current_time
	animation_state = "idle"
	sprite.texture = sleepy_texture
	var timer = Timer.new()
	add_child(timer)
	timer.one_shot = true
	timer.wait_time = 2.5
	timer.start()
	yield(timer, "timeout")
	timer.queue_free()
	
	if animation_state == "idle": # Make sure we weren't interrupted
		sprite.texture = yawn_texture
		AudioManager.play_sound("yawn")
		
		var original_pos = self.position
		var original_shadow_scale = shadow.scale
		var original_shadow_opacity = shadow.modulate.a
		
		if pulse_tween:
			pulse_tween.stop_all()
		if float_tween:
			float_tween.stop_all()
			
		var tween = Tween.new()
		add_child(tween)
		# Lift and inflate over 1.5 seconds
		tween.interpolate_property(self, "position", original_pos, original_pos + Vector2(0, -15), 1.5, Tween.TRANS_QUINT, Tween.EASE_OUT)
		tween.interpolate_property(sprite, "scale", sprite.scale, (PULSE_SCALE_MIN * 1.5) * scale_multiplier, 1.5, Tween.TRANS_QUINT, Tween.EASE_OUT)
		tween.interpolate_property(shadow, "scale", original_shadow_scale, original_shadow_scale * 2.5, 1.5, Tween.TRANS_QUINT, Tween.EASE_OUT)
		tween.interpolate_property(shadow, "modulate:a", original_shadow_opacity, 0.0, 1.5, Tween.TRANS_QUINT, Tween.EASE_OUT)
		tween.start()
		yield(tween, "tween_all_completed")

		if animation_state == "idle":
			var down_tween = Tween.new()
			add_child(down_tween)
			down_tween.interpolate_property(self, "position", position, original_pos, 1.0)
			down_tween.interpolate_property(sprite, "scale", sprite.scale, PULSE_SCALE_MIN * scale_multiplier, 1.0)
			down_tween.interpolate_property(shadow, "scale", shadow.scale, original_shadow_scale, 1.0)
			down_tween.interpolate_property(shadow, "modulate:a", shadow.modulate.a, original_shadow_opacity, 1.0)
			down_tween.start()
			yield(down_tween, "tween_all_completed")
			set_normal_texture()
			start_pulsing()

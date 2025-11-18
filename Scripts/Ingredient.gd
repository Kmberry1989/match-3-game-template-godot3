# This script is for the "Down to Earth" item.
# It inherits from Dot.gd to get all its movement properties.
extends "res://Scripts/Dot.gd"

func _ready():
	# This node IS an ingredient
	is_ingredient = true
	
	# This node cannot be swapped horizontally
	# We use is_arrested to block horizontal swaps in the Grid
	is_arrested = true 
	
	# This node cannot be part of a match
	color = "ingredient"
	is_wildcard = false
	
	# Stop all avatar animations
	var blink_timer = get_node_or_null("BlinkTimer")
	if blink_timer: blink_timer.stop()
	var anim_timer = get_node_or_null("AnimationTimer")
	if anim_timer: anim_timer.stop()
	var idle_timer = get_node_or_null("IdleTimer")
	if idle_timer: idle_timer.stop()
	
	# Set the texture to the ingredient sprite
	# --- YOU MUST CREATE THIS ASSET ---
	sprite.texture = preload("res://Assets/Visuals/ingredient_key.png") 
	
	# Hide avatar-specific nodes
	if jail_overlay: jail_overlay.visible = false
	if wildcard_glow: _stop_wildcard_glow()
	if glasses_overlay: clear_glasses_overlay()
	
	# Override scale to be consistent
	sprite.scale = PULSE_SCALE_MIN * scale_multiplier
	
	# Restart a simple float
	start_floating()

# Override pulsing to do nothing
func start_pulsing(sync_pulse = true):
	pass

# Override animations to do nothing
func play_sad_animation():
	pass
	
func play_surprised_animation():
	pass
	
func play_idle_animation():
	pass

func set_normal_texture():
	pass

func reset_to_normal_state():
	pass
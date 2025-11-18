# This script controls the 2x2 Boss.
# Attach it to your new 'BossMeaner.tscn' scene's root node.
extends Node2D

signal boss_defeated

var total_health = 20
var current_health = 20
var grid_pos = Vector2.ZERO # Top-left corner

var is_hurt = false
var is_defeated = false
var is_active = false

# --- NEW: Animation Frame Arrays ---
# Load all 12 of your new frames
var idle_frames = [
	preload("res://Assets/Visuals/Mister Meaner/boss_idle_1.png"),
	preload("res://Assets/Visuals/Mister Meaner/boss_idle_2.png"),
	preload("res://Assets/Visuals/Mister Meaner/boss_idle_3.png"),
	preload("res://Assets/Visuals/Mister Meaner/boss_idle_4.png")
]
var hurt_frames = [
	preload("res://Assets/Visuals/Mister Meaner/boss_hurt_1.png"),
	preload("res://Assets/Visuals/Mister Meaner/boss_hurt_2.png"),
	preload("res://Assets/Visuals/Mister Meaner/boss_hurt_3.png"),
	preload("res://Assets/Visuals/Mister Meaner/boss_hurt_4.png")
]
var defeated_frames = [
	preload("res://Assets/Visuals/Mister Meaner/boss_defeated_1.png"),
	preload("res://Assets/Visuals/Mister Meaner/boss_defeated_2.png"),
	preload("res://Assets/Visuals/Mister Meaner/boss_defeated_3.png"),
	preload("res://Assets/Visuals/Mister Meaner/boss_defeated_4.png")
]

# Track which frame we are on
var current_idle_frame = 0
var current_hurt_frame = 0
# ------------------------------------

onready var sprite = $BossSprite
onready var anim_player = $AnimationPlayer
onready var health_bar = $HealthBar
onready var hit_tween = $HitTween
onready var anim_timer = $AnimationTimer # This timer controls the idle/hurt loop

func _ready():
	# Set initial state
	sprite.texture = idle_frames[0]
	anim_timer.connect("timeout", self, "_on_AnimationTimer_timeout")
	# We'll set health from Grid.gd

# Called from Grid.gd to make the boss appear
func activate_boss(start_pos, health):
	grid_pos = start_pos
	set_health(health)
	is_active = true
	anim_timer.start()
	show() # Make sure the boss is visible


# Set the boss's starting health
func set_health(value):
	total_health = value
	current_health = value
	health_bar.max_value = total_health
	health_bar.value = current_health
	check_health_state() # Update visual just in case

# This function loops the idle or hurt animation
func _on_AnimationTimer_timeout():
	if not is_active or is_defeated:
		return # Stop animating if not active or defeated
		
	if is_hurt:
		# Cycle through hurt frames
		current_hurt_frame = (current_hurt_frame + 1) % hurt_frames.size()
		sprite.texture = hurt_frames[current_hurt_frame]
	else:
		# Cycle through idle frames
		current_idle_frame = (current_idle_frame + 1) % idle_frames.size()
		sprite.texture = idle_frames[current_idle_frame]

func position_health_bar(grid_node):
	if not is_instance_valid(grid_node):
		return

	# Center the health bar horizontally on the screen
	var screen_width = get_viewport().get_visible_rect().size.x
	var health_bar_width = health_bar.rect_size.x
	var grid_world_pos = grid_node.global_position
	
	# The health bar's position is relative to the BossMeaner node.
	# We want it at the screen center, so we need to calculate that in local coordinates.
	var desired_global_x = (screen_width - health_bar_width) / 2
	var local_x = desired_global_x - global_position.x
	
	# Position it below the grid
	var grid_bottom_y = grid_node.y_start
	var desired_global_y = grid_bottom_y + 80 # 80px margin
	
	# The y is also relative to the BossMeaner node
	var local_y = desired_global_y - global_position.y
	
	health_bar.rect_position = Vector2(local_x, local_y)

# Called from Grid.gd when an adjacent match is made
func take_damage(amount):
	if not is_active or is_defeated:
		return # Can't take damage if not active or already defeated
		
	current_health = max(0, current_health - amount)
	health_bar.value = current_health
	
	play_hit_effect()
	check_health_state()

# Check if we need to change from idle to hurt, or from hurt to defeated
func check_health_state():
	if not is_active or is_defeated:
		return

	if current_health <= 0:
		# --- DEFEATED ---
		is_defeated = true
		is_hurt = false
		anim_timer.stop() # Stop the idle/hurt loop
		play_death_animation()
		
	elif current_health <= total_health * 0.5 and not is_hurt:
		# --- HURT (First time crossing 50%) ---
		is_hurt = true
		current_hurt_frame = 0 # Start hurt animation from frame 0
		sprite.texture = hurt_frames[0]
		
	elif current_health > total_health * 0.5 and is_hurt:
		# --- HEALED? (If you add healing) ---
		is_hurt = false
		current_idle_frame = 0 # Go back to idle animation
		sprite.texture = idle_frames[0]

# This is the "take damage" visual flash/shake
func play_hit_effect():
	if not is_active:
		return
	# Flash the sprite red
	sprite.modulate = Color(3,1,1) # Tint red
	hit_tween.interpolate_property(sprite, "modulate", Color(3,1,1), Color(1,1,1), 0.3)
	hit_tween.start()
	
	# Play shake animation
	var shake_anim = Animation.new()
	shake_anim.add_track(Animation.TYPE_VALUE)
	shake_anim.track_set_path(0, ".:position")
	var p = position
	shake_anim.track_insert_key(0, 0.0, p)
	shake_anim.track_insert_key(0, 0.05, p + Vector2(10, 0))
	shake_anim.track_insert_key(0, 0.1, p + Vector2(-10, 0))
	shake_anim.track_insert_key(0, 0.15, p + Vector2(10, 0))
	shake_anim.track_insert_key(0, 0.2, p)
	anim_player.add_animation("shake", shake_anim)
	anim_player.play("shake")

# Called from Grid.gd
func play_attack_animation():
	if not is_active:
		return
	# Play an animation (e.g., flash red)
	var attack_anim = Animation.new()
	attack_anim.add_track(Animation.TYPE_VALUE)
	attack_anim.track_set_path(0, ".:modulate")
	attack_anim.track_insert_key(0, 0.0, Color(1,1,1))
	attack_anim.track_insert_key(0, 0.1, Color(3,1,1)) # Flash red
	attack_anim.track_insert_key(0, 0.3, Color(1,1,1))
	anim_player.add_animation("attack", attack_anim)
	anim_player.play("attack")

# This is the new one-shot defeat animation
func play_death_animation():
	if not is_active:
		return
	var death_anim = Animation.new()
	death_anim.add_track(Animation.TYPE_VALUE)
	death_anim.track_set_path(0, "sprite:texture")
	death_anim.length = 1.0 # 1 second total, 0.25s per frame
	
	# Set keyframes for each defeated texture
	death_anim.track_insert_key(0, 0.0, defeated_frames[0])
	death_anim.track_insert_key(0, 0.25, defeated_frames[1])
	death_anim.track_insert_key(0, 0.5, defeated_frames[2])
	death_anim.track_insert_key(0, 0.75, defeated_frames[3])
	
	# Add a fade-out track
	death_anim.add_track(Animation.TYPE_VALUE)
	death_anim.track_set_path(1, ":modulate:a")
	death_anim.track_insert_key(1, 0.5, 1.0) # Start fading at 0.5s
	death_anim.track_insert_key(1, 1.0, 0.0) # Fully faded at 1.0s
	
	anim_player.add_animation("defeated", death_anim)
	anim_player.play("defeated")
	
	# Wait for the animation to finish
	yield(anim_player, "animation_finished")
	
	# Tell the grid we are done
	emit_signal("boss_defeated")
	
	# Remove the boss
	queue_free()

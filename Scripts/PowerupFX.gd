# This script plays an animation for a powerup and then frees itself.
# Attach it to your new 'PowerupFX.tscn' scene's root node.
extends Node2D

onready var particles = $CPUParticles2D
onready var anim_player = $AnimationPlayer
onready var streak_sprite = $Sprite
onready var AudioManager = get_node_or_null("/root/AudioManager")

func _ready():
	streak_sprite.visible = false
	# Use your bright_flash.png as the base for the streak
	streak_sprite.texture = preload("res://Assets/Visuals/bright_flash.png") 
	streak_sprite.modulate = Color(1,1,1,0.5) # Make it semi-transparent

func play_bomb(pos):
	self.position = pos
	
	# Configure particles for an explosion
	particles.emitting = true
	
	# Simple fade/scale animation for the particles
	var anim = Animation.new()
	anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(0, ".:modulate")
	anim.track_insert_key(0, 0.0, Color(1,1,1,1))
	anim.track_insert_key(0, 0.5, Color(1,1,1,0))
	anim_player.add_animation("explode", anim)
	anim_player.play("explode")
	
	if AudioManager: AudioManager.play_sound("match_pop") # You have a good sound for this
	
	yield(anim_player, "animation_finished")
	queue_free()

func play_rocket_h(pos):
	self.position = pos
	streak_sprite.visible = true
	streak_sprite.scale = Vector2(100, 1) # Long horizontal streak
	
	var anim = Animation.new()
	anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(0, ".:modulate")
	anim.track_insert_key(0, 0.0, Color(1,1,1,1))
	anim.track_insert_key(0, 0.3, Color(1,1,1,0))
	anim_player.add_animation("streak", anim)
	anim_player.play("streak")
	
	if AudioManager: AudioManager.play_sound("line_clear") # Use your sound
	
	yield(anim_player, "animation_finished")
	queue_free()

func play_rocket_v(pos):
	self.position = pos
	streak_sprite.visible = true
	streak_sprite.scale = Vector2(1, 100) # Long vertical streak
	
	var anim = Animation.new()
	anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(0, ".:modulate")
	anim.track_insert_key(0, 0.0, Color(1,1,1,1))
	anim.track_insert_key(0, 0.3, Color(1,1,1,0))
	anim_player.add_animation("streak", anim)
	anim_player.play("streak")
	
	if AudioManager: AudioManager.play_sound("line_clear") # Use your sound
	
	yield(anim_player, "animation_finished")
	queue_free()
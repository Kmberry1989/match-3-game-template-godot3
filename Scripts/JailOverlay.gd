# This script controls the 'Jail' visual.
# Attach it to your new 'JailOverlay.tscn' scene's root node.
extends Node2D

var health = 1
var grid_pos = Vector2.ZERO

onready var main_sprite = $MainSprite # The avatar_injail1.png sprite
onready var damage_sprite = $DamageSprite # The avatar_injail2.png sprite

func _ready():
	# Ensure damage sprite is hidden
	if damage_sprite:
		damage_sprite.visible = false

# Set the health and update visuals
func set_health(value):
	health = value
	if health > 1:
		if damage_sprite: damage_sprite.visible = false
		if main_sprite: main_sprite.visible = true
	elif health == 1:
		if damage_sprite: damage_sprite.visible = true
		if main_sprite: main_sprite.visible = false

# Called by Grid.gd when an adjacent match is made
# Returns true if the jail was destroyed
func take_damage(amount):
	health -= amount
	
	if health <= 0:
		# I'm destroyed!
		queue_free()
		return true # Return true to signal destruction
	elif health == 1:
		# Show damage
		if damage_sprite: damage_sprite.visible = true
		if main_sprite: main_sprite.visible = false
		
	return false # Not destroyed
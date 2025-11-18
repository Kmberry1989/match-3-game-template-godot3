extends Node2D

export var max_health := 2
var health := 2
var grid_pos := Vector2.ZERO

onready var layer1: Sprite = get_node_or_null("SpriteLayer1")
onready var layer2: Sprite = get_node_or_null("SpriteLayer2")

func _ready():
	if max_health < 1:
		max_health = 1
	health = max_health
	_update_layers()

func set_health(value):
	health = int(value)
	_update_layers()

# Returns true if destroyed (cleared)
func take_damage(amount := 1) -> bool:
	health -= amount
	if health <= 0:
		queue_free()
		return true
	_update_layers()
	return false

func _update_layers() -> void:
	if layer1 != null:
		layer1.visible = health >= 2
	if layer2 != null:
		layer2.visible = health == 1


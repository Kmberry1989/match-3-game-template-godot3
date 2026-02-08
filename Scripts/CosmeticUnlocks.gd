extends Node
class_name CosmeticUnlocks

static func get_unlocks() -> Dictionary:
	# achievement_id -> Array of {category, id}
	return {
		"on_a_roll": [
			{"category": "combo_style", "id": "gold"}
		],
		"on_the_board": [
			{"category": "dot_skin", "id": "pastel"}
		],
		"first_chapter": [
			{"category": "board_theme", "id": "cool_blue"}
		]
	}

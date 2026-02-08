extends Node
class_name CosmeticsCatalog

static func get_catalog() -> Dictionary:
	return {
		"dot_skin": {
			"classic": {
				"id": "classic",
				"name": "Classic",
				"price": 0,
				"unlock": {"type": "default"},
				"visual": {"palette": {}}
			},
			"pastel": {
				"id": "pastel",
				"name": "Pastel",
				"price": 250,
				"unlock": {"type": "achievement", "id": "on_the_board"},
				"visual": {
					"palette": {
						"red": Color(1.0, 0.7, 0.7),
						"orange": Color(1.0, 0.8, 0.6),
						"yellow": Color(1.0, 0.98, 0.7),
						"green": Color(0.7, 1.0, 0.8),
						"blue": Color(0.7, 0.85, 1.0),
						"purple": Color(0.85, 0.75, 1.0),
						"pink": Color(1.0, 0.75, 0.9),
						"brown": Color(0.8, 0.7, 0.6),
						"gray": Color(0.9, 0.9, 0.9),
						"white": Color(1.0, 1.0, 1.0)
					}
				}
			},
			"neon": {
				"id": "neon",
				"name": "Neon",
				"price": 300,
				"unlock": {"type": "coins"},
				"visual": {
					"palette": {
						"red": Color(1.0, 0.2, 0.35),
						"orange": Color(1.0, 0.55, 0.15),
						"yellow": Color(1.0, 1.0, 0.25),
						"green": Color(0.3, 1.0, 0.45),
						"blue": Color(0.2, 0.7, 1.0),
						"purple": Color(0.8, 0.35, 1.0),
						"pink": Color(1.0, 0.3, 0.8),
						"brown": Color(0.9, 0.6, 0.35),
						"gray": Color(0.95, 0.95, 0.95),
						"white": Color(1.0, 1.0, 1.0)
					}
				}
			}
		},
		"board_theme": {
			"classic": {
				"id": "classic",
				"name": "Classic",
				"price": 0,
				"unlock": {"type": "default"},
				"visual": {"modulate": Color(1, 1, 1, 1)}
			},
			"cool_blue": {
				"id": "cool_blue",
				"name": "Cool Blue",
				"price": 200,
				"unlock": {"type": "achievement", "id": "first_chapter"},
				"visual": {"modulate": Color(0.85, 0.92, 1.0, 1)}
			},
			"sunset": {
				"id": "sunset",
				"name": "Sunset",
				"price": 200,
				"unlock": {"type": "coins"},
				"visual": {"modulate": Color(1.0, 0.87, 0.78, 1)}
			}
		},
		"particle_pack": {
			"classic": {
				"id": "classic",
				"name": "Classic",
				"price": 0,
				"unlock": {"type": "default"},
				"visual": {"amount_multiplier": 1.0, "spread": 180.0, "initial_velocity": 80.0, "scale": 0.2}
			},
			"sparkle": {
				"id": "sparkle",
				"name": "Sparkle",
				"price": 250,
				"unlock": {"type": "coins"},
				"visual": {"amount_multiplier": 1.2, "spread": 220.0, "initial_velocity": 110.0, "scale": 0.25}
			}
		},
		"combo_style": {
			"classic": {
				"id": "classic",
				"name": "Classic",
				"price": 0,
				"unlock": {"type": "default"},
				"visual": {"color": Color(1.0, 0.8, 0.4, 1.0)}
			},
			"gold": {
				"id": "gold",
				"name": "Gold",
				"price": 200,
				"unlock": {"type": "achievement", "id": "on_a_roll"},
				"visual": {"color": Color(1.0, 0.9, 0.3, 1.0)}
			},
			"ice": {
				"id": "ice",
				"name": "Ice",
				"price": 200,
				"unlock": {"type": "coins"},
				"visual": {"color": Color(0.6, 0.85, 1.0, 1.0)}
			}
		}
	}

static func get_categories() -> Array:
	return ["dot_skin", "board_theme", "particle_pack", "combo_style"]

static func get_item(category: String, item_id: String) -> Dictionary:
	var cat = get_catalog().get(category, {})
	if cat.has(item_id):
		return cat[item_id]
	return {}

static func get_category_ids(category: String) -> Array:
	var out: Array = []
	var cat = get_catalog().get(category, {})
	for k in cat.keys():
		out.append(k)
	out.sort()
	return out

static func get_default_equipped() -> Dictionary:
	return {
		"dot_skin": "classic",
		"board_theme": "classic",
		"particle_pack": "classic",
		"combo_style": "classic"
	}

static func get_default_unlocks() -> Dictionary:
	return {
		"dot_skin": ["classic"],
		"board_theme": ["classic"],
		"particle_pack": ["classic"],
		"combo_style": ["classic"]
	}

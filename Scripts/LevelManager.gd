# This is a new script.
# Add it to your project's Autoloads (Project > Project Settings > Autoload)
# Path: res://Scripts/LevelManager.gd
# Name: LevelManager

extends Node

# Define goal types
enum GoalType {
	SCORE,
	JAILBREAK, # This is "Meaner's Mischief"
	DOWN_TO_EARTH, # This is "Down to Earth"
	EXTERMINATE,
	AVATAR_RESCUE,
	TOO_COOL
	# Add SLIME, BOSS here later
}

# Store all level data here
# We will only define levels for Score, Jailbreak, and Down to Earth
const LEVELS = {
	1: {
		"moves": 30,
		"goal_type": GoalType.SCORE,
		"goal_text": "Reach 1,000 points!",
		"target_score": 1000
	},
	2: {
		"moves": 25,
		"goal_type": GoalType.DOWN_TO_EARTH,
		"goal_text": "Collect 3 Ingredients!",
		"ingredient_positions": [ [1, 0], [3, 0], [5, 0] ] # Spawn 3 ingredients at top
	},
	3: {
		"moves": 30,
		"goal_type": GoalType.JAILBREAK,
		"goal_text": "Break the Avatar out of jail!",
		"initial_jail_color": "red" # Trigger Meaner's Mischief for 'red' at start
	},
	4: {
		"moves": 40,
		"goal_type": GoalType.EXTERMINATE,
		"goal_text": "Defeat Mister Meaner!",
		"boss_position": [2, 2], # Top-left corner of the 2x2 boss
		"boss_health": 20
	},
	5: {
		"moves": 1,
		"goal_type": GoalType.AVATAR_RESCUE,
		"goal_text": "Match the Cool Dot!"
	},
	6: {
		"moves": 25,
		"goal_type": GoalType.TOO_COOL,
		"goal_text": "Too Cool! Match the dot with glasses."
	}
	# ... (add more levels here) ...
}

# Function to get level data
func get_level_data(level_num):
	var level_number := 1
	if level_num != null:
		level_number = int(level_num)
	if level_number < 1:
		level_number = 1

	var num_levels = LEVELS.size()
	var level_to_load = ((level_number - 1) % num_levels) + 1

	if not LEVELS.has(level_to_load):
		# This should not happen with the logic above, but as a fallback
		return LEVELS[1].duplicate(true)

	# Create a copy so the original data isn't modified
	return LEVELS[level_to_load].duplicate(true)

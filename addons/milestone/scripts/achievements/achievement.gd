class_name Achievement
extends Resource

# General

## The ID of the achievement used when unlocking/progressing. Must be unique from other achievements, and be the same as the file name. Use the Milestone workspace to change it.
export(String) var id = "achievement_id"
## The icon of the achievement.
export(Texture) var icon = null
## The filter the icon should use (not used in Godot 3; kept as integer for compatibility).
export(int) var icon_filter = 0
## The unachieved icon (optional).
export(Texture) var unachieved_icon = null
## The hidden icon of the achievement.
export(Texture) var hidden_icon = null
## The group ID, used for grouping achievements.
export(String) var group = ""
## Name of the achievement.
export(String) var name = "Achievement Name"
## Description of the achievement.
export(String) var description = "Achievement Description"
## Is the achievement hidden/a secret?
export(bool) var hidden = false
## Is the achievement considered rare? If true, adds a glow around the border once unlocked.
export(bool) var considered_rare = false

## Progression

## Whether the achievement is progressive or not.
export(bool) var progressive = false
## The progress goal of the achievement.
export(int) var progress_goal = 0
## Number of increments between each popup display.
## For example, set to 3 to show the popup every 3 increments.
export(int) var indicate_progress_interval = 1

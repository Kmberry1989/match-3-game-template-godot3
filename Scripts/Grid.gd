extends Node2D

enum {wait, move}
var state: int

onready var PlayerManager = get_node_or_null("/root/PlayerManager")

export var width: int
export var height: int
export var offset: int
export var grid_scale: float = 1.0
export var grid_nudge: Vector2 = Vector2.ZERO # pixel offset applied after centering
export var y_offset: int
export var AUTO_RESHUFFLE: bool = true

var x_start: float
var y_start: float
onready var game_ui = get_node("../GameUI")
onready var AudioManager = get_node_or_null("/root/AudioManager")
onready var WebsocketClient = get_node_or_null("/root/WebsocketClient")
onready var MultiplayerManager = get_node_or_null("/root/MultiplayerManager")
onready var LevelManager = get_node_or_null("/root/LevelManager")

export var empty_spaces = PoolVector2Array()

# --- NEW: Level Management ---
var level_data = null
var current_level_num = 1
var current_goal_type = -1 # Will be set from LevelManager
var objective_goal_count = 0
var target_score = 10000 # Default for score levels
var moves_left = 30
# -----------------------------

# Preload scenes for dots and new visual effects
onready var possible_dots = [
	preload("res://Scenes/Dots/blue_dot.tscn"),
	preload("res://Scenes/Dots/green_dot.tscn"),
	preload("res://Scenes/Dots/pink_dot.tscn"),
	preload("res://Scenes/Dots/red_dot.tscn"),
	preload("res://Scenes/Dots/yellow_dot.tscn"),
	preload("res://Scenes/Dots/purple_dot.tscn"),
	preload("res://Scenes/Dots/orange_dot.tscn"),
	preload("res://Scenes/Dots/brown_dot.tscn"),
	preload("res://Scenes/Dots/gray_dot.tscn"),
	preload("res://Scenes/Dots/white_dot.tscn")
]
onready var match_particles: PackedScene = preload("res://Scenes/MatchParticles.tscn")
onready var match_label_scene: PackedScene = preload("res://Scenes/MatchLabel.tscn")
onready var xp_orb_texture = preload("res://Assets/Visuals/xp_orb.png")
onready var stage_banner_texture = preload("res://Assets/Visuals/stage_banner.png")
onready var chest_closed_texture = preload("res://Assets/Visuals/chest_closed.png")
onready var chest_open_texture = preload("res://Assets/Visuals/chest_open.png")
onready var coin_texture = preload("res://Assets/Visuals/coin.png")
onready var anvil_texture = preload("res://Assets/Visuals/anvil.png")
var xp_orb_colors: Dictionary = {
	"red": Color(1.0, 0.25, 0.25),
	"orange": Color(1.0, 0.6, 0.2),
	"yellow": Color(1.0, 0.94, 0.3),
	"green": Color(0.3, 1.0, 0.5),
	"blue": Color(0.3, 0.6, 1.0),
	"purple": Color(0.7, 0.4, 1.0),
	"pink": Color(1.0, 0.5, 0.8),
	"brown": Color(0.6, 0.4, 0.3),
	"gray": Color(0.7, 0.7, 0.7),
	"white": Color(1.0, 1.0, 1.0)
}

# --- NEW: Preload Objective Scenes ---
# Preload the script for constants/enums; use Autoload instance for methods
const LevelManagerScript = preload("res://Scripts/LevelManager.gd")
const IngredientScene = preload("res://Scenes/Ingredient.tscn") # You must create this scene
const BossScene = preload("res://Scenes/BossMeaner.tscn")
# -----------------------------------

var destroy_timer: Timer = Timer.new()
var collapse_timer: Timer = Timer.new()
var refill_timer: Timer = Timer.new()
var idle_timer: Timer = Timer.new()
var inactivity_timer: Timer = Timer.new()

var all_dots: Array = []

var dot_one: Node2D = null
var dot_two: Node2D = null
var last_place = Vector2(0,0)
var last_direction = Vector2(0,0)
var move_checked: bool = false

# Dragging variables
var is_dragging: bool = false
var dragged_dot: Node2D = null
var drag_start_position: Vector2 = Vector2.ZERO
var drag_start_grid: Vector2 = Vector2(-1, -1)

# Score variables
var score: int = 0
var combo_counter: int = 1

var possible_colors: Array = []
var _color_rotation_index: int = 0
const MAX_ACTIVE_COLORS = 6
var idle_hint_count: int = 0

var _xp_mult_value: int = 1
var _xp_mult_remaining: int = 0

# Track unsuccessful player attempts
var _failed_attempts: int = 0

# Arrest mini-game state (This is "Meaner's Mischief")
var _arrest_active: bool = false
var _arrested_color: String = ""
var _arrested_dot = null
var _arrest_stage: int = 0 # 3 -> 2 -> 1 -> 0 then jailbreak
var _match_events: int = 0 # count of successful match resolutions
var _siren_played: bool = false
var _glasses_active: bool = false
var _glasses_target = null
var _matches_since_glasses: int = 0
var _too_cool_dot = null
var _too_cool_active: bool = false
var _ingredient_reward_playing: bool = false

# --- NEW: Boss Battle ---
const ANVIL_RESPAWN_DELAY = 6.0
const ANVIL_FALL_DURATION = 1.4
const ANVIL_DAMAGE = 15
var boss = null # Will hold the instance of the boss
var boss_tiles = [] # Will hold the positions of the boss tiles
var _anvil_spawn_timer: Timer = Timer.new()
var _anvil_node = null
var _anvil_active: bool = false
# ------------------------

func _ready():
	state = wait # Lock state until board is ready
	setup_timers()
	_clear_too_cool_state()
	_clear_anvil()
	randomize()
	# Apply grid-only scale by adjusting the cell size (offset).
	if grid_scale != 1.0:
		offset = int(round(offset * clamp(grid_scale, 0.5, 2.0)))
	
	for dot_scene in possible_dots:
		var dot_instance = dot_scene.instance()
		possible_colors.append(dot_instance.color)
		dot_instance.queue_free()
	
	_recalc_start()
	var vp = get_viewport()
	if vp != null:
		vp.connect("size_changed", self, "_on_viewport_size_changed")
	
	all_dots = make_2d_array()

	# --- NEW: Level Setup ---
	if PlayerManager:
		current_level_num = PlayerManager.get_current_level()
	# Make sure LevelManager is in Autoload
	if LevelManager == null:
		push_error("LevelManager (autoload) not found!")
		return
	level_data = LevelManager.get_level_data(current_level_num)
	
	current_goal_type = level_data.get("goal_type", LevelManagerScript.GoalType.SCORE)
	moves_left = level_data.get("moves", 30) # Default to 30 moves
	
	game_ui.update_moves(moves_left) # We assume GameUI has update_moves(int)
	game_ui.update_xp_label() # This is your existing score update
	game_ui.set_level_goal(level_data) # We assume GameUI has set_level_goal(Dictionary)
	
	# Setup goals
	if current_goal_type == LevelManagerScript.GoalType.SCORE:
		target_score = level_data.get("target_score", 10000)
		objective_goal_count = target_score
	elif current_goal_type == LevelManagerScript.GoalType.DOWN_TO_EARTH:
		objective_goal_count = level_data.get("ingredient_positions", []).size()
	elif current_goal_type == LevelManagerScript.GoalType.JAILBREAK:
		# For jailbreak, the goal is to free 1 avatar
		objective_goal_count = 1 
	elif current_goal_type == LevelManagerScript.GoalType.TOO_COOL:
		objective_goal_count = 1
	
	game_ui.update_goal_count(objective_goal_count) # We assume GameUI has update_goal_count(int)
	# -------------------------

	spawn_dots()
	
	# --- NEW: Setup Objectives AFTER spawning dots ---
	setup_objectives()
	# -----------------------------------------------

	for i in range(width):
		for j in range(height):
			if all_dots[i][j] != null and all_dots[i][j].has_method("start_pulsing"):
				all_dots[i][j].start_pulsing()
				
	_apply_pending_bonus()
	
	if AUTO_RESHUFFLE:
		yield(ensure_moves_available(), "completed")
		_restart_idle_timers()

	yield(get_tree(), "idle_frame")
	if PlayerManager != null:
		PlayerManager.connect("level_up", self, "_on_level_up")
	
	_restart_idle_timers()
	
	state = move # Unlock state
	_synchronize_after_move()


# --- NEW: Objective Setup Functions ---

func setup_objectives():
	_clear_too_cool_state()
	if current_goal_type == LevelManagerScript.GoalType.DOWN_TO_EARTH:
		setup_down_to_earth()
	elif current_goal_type == LevelManagerScript.GoalType.JAILBREAK:
		# "Meaner's Mischief" from level data
		if level_data.has("initial_jail_color"):
			_trigger_arrest_event(level_data.get("initial_jail_color"))
	elif current_goal_type == LevelManagerScript.GoalType.EXTERMINATE:
		setup_exterminate()
	elif current_goal_type == LevelManagerScript.GoalType.TOO_COOL:
		_spawn_too_cool_dot()

func _level_position_to_grid(pos_array):
	if typeof(pos_array) != TYPE_ARRAY or pos_array.size() < 2:
		return Vector2(0, 0)
	var column = clamp(int(pos_array[0]), 0, width - 1)
	var row_from_top = clamp(int(pos_array[1]), 0, height - 1)
	var row = clamp(height - 1 - row_from_top, 0, height - 1)
	return Vector2(column, row)

func setup_down_to_earth():
	var ingredient_positions = level_data.get("ingredient_positions", [])
	for pos_array in ingredient_positions:
		var vec_pos = _level_position_to_grid(pos_array)
		var col = int(vec_pos.x)
		var row = int(vec_pos.y)
		if is_in_grid(Vector2(col, row)):
			# Destroy any dot that's already there
			if all_dots[col][row] != null:
				all_dots[col][row].queue_free()
			
			# Instance the Ingredient scene
			var dot = IngredientScene.instance()
			
			var base_z = height - row
			dot.z_index = base_z
			add_child(dot)
			dot.position = grid_to_pixel(col, row)
			all_dots[col][row] = dot
			dot.set_meta("base_z", base_z)
			
			# The Ingredient's _ready() function will call make_ingredient()
			
			# Connect signals
			dot.connect("match_faded", self, "_on_dot_match_faded")

func setup_exterminate():
	var boss_raw = level_data.get("boss_position", [0,0])
	var boss_pos = _level_position_to_grid(boss_raw)
	boss_tiles.clear()
	_clear_anvil()
	
	var boss_col = int(boss_pos.x)
	var boss_row = int(boss_pos.y)

	# Clear the 2x2 area for the boss
	for i in range(boss_col, boss_col + 2):
		for j in range(boss_row, boss_row + 2):
			if is_in_grid(Vector2(i,j)):
				if all_dots[i][j] != null:
					all_dots[i][j].queue_free()
					all_dots[i][j] = null
				boss_tiles.append(Vector2(i,j))
				
	# Instance and add the boss
	boss = BossScene.instance()
	add_child(boss)
	var center_pos = Vector2(boss_pos.x + 0.5, boss_pos.y + 0.5)
	boss.position = grid_to_pixel(center_pos.x, center_pos.y)
	boss.z_index = height * 2
	
	# Activate the boss
	var boss_health = level_data.get("boss_health", 20)
	boss.activate_boss(Vector2(boss_col, boss_row), boss_health)
	boss.position_health_bar(self)
	
	# Connect to the boss's defeated signal
	boss.connect("boss_defeated", self, "_on_boss_defeated")
	_schedule_anvil_spawn(ANVIL_RESPAWN_DELAY * 0.5)

func _clear_too_cool_state():
	if _too_cool_dot != null and is_instance_valid(_too_cool_dot):
		_too_cool_dot.is_too_cool = false
		if _too_cool_dot.has_method("clear_glasses_overlay"):
			_too_cool_dot.clear_glasses_overlay()
	_too_cool_dot = null
	_too_cool_active = false

func _clear_anvil():
	if _anvil_node != null and is_instance_valid(_anvil_node):
		_anvil_node.queue_free()
	_anvil_node = null
	_anvil_active = false
	if _anvil_spawn_timer != null:
		_anvil_spawn_timer.stop()

func _play_ingredient_chest(count: int):
	if _ingredient_reward_playing:
		yield(get_tree().create_timer(0.4), "timeout")
		return

	_ingredient_reward_playing = true
	var overlay_nodes = []
	var layer = get_parent().get_node_or_null("CanvasLayer")
	var viewport_size = get_viewport().get_visible_rect().size
	var chest_node: Node2D = null
	var chest_sprite: Sprite = null
	if layer != null and chest_closed_texture != null:
		chest_node = Node2D.new()
		chest_sprite = Sprite.new()
		chest_sprite.texture = chest_closed_texture
		chest_sprite.centered = true
		chest_sprite.scale = Vector2(1, 1)
		chest_node.add_child(chest_sprite)
		chest_node.position = viewport_size * 0.5
		chest_node.z_index = 1000
		layer.add_child(chest_node)
		overlay_nodes.append(chest_node)
		var rumble = get_tree().create_tween()
		rumble.tween_property(chest_node, "rotation_degrees", 5.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		rumble.tween_property(chest_node, "rotation_degrees", -5.0, 0.09)
		rumble.tween_property(chest_node, "rotation_degrees", 0.0, 0.08)
		rumble.parallel().tween_property(chest_sprite, "scale", Vector2(1.04, 1.04), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		yield(get_tree().create_timer(0.25), "timeout")

	yield(get_tree().create_timer(0.7), "timeout")

	if chest_sprite != null and is_instance_valid(chest_sprite) and chest_open_texture != null:
		chest_sprite.texture = chest_open_texture
		chest_sprite.scale = Vector2(1, 1)
		chest_node.rotation_degrees = 0.0
	var chest_center = viewport_size * 0.5
	if chest_node != null and is_instance_valid(chest_node):
		chest_center = chest_node.position

	var coin_nodes = []
	if layer != null and coin_texture != null:
		var coin_count = clamp(count + 2, 3, 6)
		for i in range(coin_count):
			var coin = Sprite.new()
			coin.texture = coin_texture
			coin.centered = true
			coin.scale = Vector2(0.45, 0.45)
			coin.z_index = 1100
			coin.global_position = chest_center
			layer.add_child(coin)
			coin_nodes.append(coin)
			var target = chest_center + Vector2(rand_range(-60, 60), rand_range(-140, -80))
			var coin_tween = get_tree().create_tween()
			coin_tween.tween_property(coin, "global_position", target, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			coin_tween.parallel().tween_property(coin, "modulate:a", 0.0, 0.6).set_delay(0.3)

	var reward_base = int(rand_range(8, 16))
	var reward_amount = reward_base * max(1, count)
	_award_ingredient_coins(reward_amount)

	yield(get_tree().create_timer(1.0), "timeout")

	for node in overlay_nodes:
		if node != null and is_instance_valid(node):
			node.queue_free()
	for coin in coin_nodes:
		if coin != null and is_instance_valid(coin):
			coin.queue_free()

	_ingredient_reward_playing = false

func _award_ingredient_coins(amount: int) -> void:
	if amount <= 0:
		return
	if PlayerManager != null:
		if PlayerManager.has_method("add_coins"):
			PlayerManager.add_coins(amount)
			return
		var coins = PlayerManager.player_data.get("coins", 0)
		coins += amount
		PlayerManager.player_data["coins"] = coins
		PlayerManager.emit_signal("coins_changed", coins)
		if PlayerManager.has_method("save_player_data"):
			PlayerManager.save_player_data()

func _schedule_anvil_spawn(delay = ANVIL_RESPAWN_DELAY):
	if boss == null or not boss.is_active:
		return
	if _anvil_active:
		return
	if _anvil_spawn_timer != null:
		_anvil_spawn_timer.set_wait_time(delay)
		_anvil_spawn_timer.start()

func _on_anvil_spawn_timeout():
	_spawn_anvil()

func _spawn_anvil():
	if boss == null or not boss.is_active:
		return
	if _anvil_active:
		return
	var columns: Array = []
	for pos in boss_tiles:
		var col = int(pos.x)
		if not columns.has(col):
			columns.append(col)
	if columns.size() == 0:
		return
	columns.shuffle()
	var drop_col = columns[0]
	var start_pos = grid_to_pixel(drop_col, height)
	var target_pos = boss.global_position
	var anvil_node = Node2D.new()
	var sprite = Sprite.new()
	sprite.texture = anvil_texture
	sprite.centered = true
	anvil_node.add_child(sprite)
	anvil_node.position = start_pos
	anvil_node.z_index = height * 2 + 10
	add_child(anvil_node)
	_anvil_node = anvil_node
	_anvil_active = true
	var tween = get_tree().create_tween()
	tween.tween_property(anvil_node, "position", target_pos, ANVIL_FALL_DURATION).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tween.connect("finished", self, "_on_anvil_impact")

func _on_anvil_impact():
	if boss != null and boss.is_active:
		boss.take_damage(ANVIL_DAMAGE)
	# Remove anvil now that it hit
	if _anvil_node != null and is_instance_valid(_anvil_node):
		_anvil_node.queue_free()
	_anvil_node = null
	_anvil_active = false
	_schedule_anvil_spawn()

func _spawn_too_cool_dot():
	var candidates: Array = []
	for x in range(width):
		for y in range(height):
			var dot = all_dots[x][y]
			if dot != null and not dot.is_ingredient:
				candidates.append(dot)
	if candidates.size() == 0:
		return
	candidates.shuffle()
	var chosen = candidates[0]
	if not is_instance_valid(chosen):
		return
	_too_cool_dot = chosen
	_too_cool_dot.is_too_cool = true
	if _too_cool_dot.has_method("apply_glasses_overlay"):
		_too_cool_dot.apply_glasses_overlay()
	if _too_cool_dot.has_method("start_pulsing"):
		_too_cool_dot.start_pulsing()
	_too_cool_active = true

func _mark_too_cool_lines(pos: Vector2) -> void:
	var col = int(pos.x)
	var row = int(pos.y)
	if col < 0 or row < 0:
		return
	for x in range(width):
		var dot = all_dots[x][row]
		if dot != null and not dot.is_ingredient:
			dot.matched = true
	for y in range(height):
		var dot = all_dots[col][y]
		if dot != null and not dot.is_ingredient:
			dot.matched = true

func _verify_render_logic():
	var tolerance = 16.0
	for x in range(width):
		for y in range(height):
			var dot = all_dots[x][y]
			if dot == null or not is_instance_valid(dot):
				continue
			var expected_pos = grid_to_pixel(x, y)
			if dot.position.distance_squared_to(expected_pos) > tolerance:
				dot.position = expected_pos
			var expected_z = height - y
			if dot.z_index != expected_z:
				dot.z_index = expected_z

func _resync_idle_pulses():
	for x in range(width):
		for y in range(height):
			var dot = all_dots[x][y]
			if dot == null or not is_instance_valid(dot):
				continue
			if dot == dragged_dot:
				continue
			if dot.animation_state == "idle":
				continue
			if dot.has_method("start_pulsing"):
				dot.start_pulsing(true)

func _synchronize_after_move():
	_verify_render_logic()
	_resync_idle_pulses()

func _on_boss_defeated():
	_clear_anvil()
	boss_tiles.clear()
	boss = null
	objective_goal_count = 0
	game_ui.update_goal_count(0)
	check_game_over_conditions(true) # Force a win check

# --- End New Functions ---


func _recalc_start():
	var s: Vector2 = get_viewport().get_visible_rect().size
	x_start = (s.x - float(width) * float(offset)) / 2.0 + float(offset) / 2.0
	y_start = (s.y + float(height) * float(offset)) / 2.0 - float(offset) / 2.0
	x_start += grid_nudge.x
	y_start += grid_nudge.y

func _on_viewport_size_changed():
	_recalc_start()

func update_score_display():
	game_ui.update_xp_label()

func setup_timers():
	destroy_timer.connect("timeout", self, "destroy_matches")
	destroy_timer.set_one_shot(true)
	destroy_timer.set_wait_time(0.6)
	add_child(destroy_timer)
	
	collapse_timer.connect("timeout", self, "collapse_columns")
	collapse_timer.set_one_shot(true)
	collapse_timer.set_wait_time(0.2)
	add_child(collapse_timer)

	refill_timer.connect("timeout", self, "refill_columns")
	refill_timer.set_one_shot(true)
	refill_timer.set_wait_time(0.1)
	add_child(refill_timer)
	
	idle_timer.connect("timeout", self, "_on_idle_timer_timeout")
	idle_timer.set_one_shot(true)
	idle_timer.set_wait_time(5.0)
	add_child(idle_timer)

	if AUTO_RESHUFFLE:
		inactivity_timer.connect("timeout", self, "_on_inactivity_timeout")
		inactivity_timer.set_one_shot(true)
		inactivity_timer.set_wait_time(25.0)
		add_child(inactivity_timer)

	_anvil_spawn_timer.connect("timeout", self, "_on_anvil_spawn_timeout")
	_anvil_spawn_timer.set_one_shot(true)
	_anvil_spawn_timer.set_wait_time(ANVIL_RESPAWN_DELAY)
	add_child(_anvil_spawn_timer)

func _restart_idle_timers() -> void:
	if idle_timer != null:
		idle_timer.start()
	if AUTO_RESHUFFLE and inactivity_timer != null:
		inactivity_timer.start()

func restricted_fill(place):
	if is_in_array(empty_spaces, place):
		return true
	return false
	
func is_in_array(array, item):
	for i in range(array.size()):
		if array[i] == item:
			return true
	return false

func make_2d_array():
	var array = []
	for i in range(width):
		array.append([])
		for j in range(height):
			array[i].append(null)
	return array

func spawn_dots():
	for i in range(width):
		for j in range(height):
			# --- MODIFIED: Don't spawn if an ingredient is there ---
			if all_dots[i][j] != null and all_dots[i][j].is_ingredient:
				continue
			# ----------------------------------------------------
			if !restricted_fill(Vector2(i, j)) and not boss_tiles.has(Vector2(i,j)):
				var pool = possible_colors.duplicate()
				if _arrest_active and pool.has(_arrested_color):
					for _w in range(3):
						pool.append(_arrested_color)
				var rand = floor(rand_range(0, pool.size()))
				var color = pool[rand]
				var loops = 0
				while (match_at(i, j, color) && loops < 100):
					rand = floor(rand_range(0, pool.size()))
					color = pool[rand]
					loops += 1
				
				var dot_scene_to_use = null
				for dot_scene in possible_dots:
					var dot_instance = dot_scene.instance()
					if dot_instance.color == color:
						dot_scene_to_use = dot_scene
						dot_instance.queue_free()
						break
					dot_instance.queue_free()

				var dot = dot_scene_to_use.instance()
				var base_z = height - j
				dot.z_index = base_z
				add_child(dot)
				dot.position = grid_to_pixel(i, j)
				all_dots[i][j] = dot
				dot.set_meta("base_z", base_z)
				_apply_arrest_overlay_if_needed(dot)
				
				# --- NEW: Connect signals to new dots ---
				dot.add_to_group("dots")
				dot.connect("match_faded", self, "_on_dot_match_faded")
				# ----------------------------------------
			
func match_at(i, j, color):
	# --- MODIFIED: Ingredients don't match ---
	if i > 1:
		if all_dots[i - 1][j] != null && all_dots[i - 2][j] != null:
			if !all_dots[i-1][j].is_ingredient and !all_dots[i-2][j].is_ingredient:
				if all_dots[i - 1][j].color == color && all_dots[i - 2][j].color == color:
					return true
	if j > 1:
		if all_dots[i][j - 1] != null && all_dots[i][j - 2] != null:
			if !all_dots[i][j-1].is_ingredient and !all_dots[i][j-2].is_ingredient:
				if all_dots[i][j - 1].color == color && all_dots[i][j - 2].color == color:
					return true
	return false
	# -----------------------------------------

func grid_to_pixel(column, row):
	var new_x = x_start + offset * column
	var new_y = y_start + -offset * row
	return Vector2(new_x, new_y)
	
func pixel_to_grid(pixel_x,pixel_y):
	var new_x = round((pixel_x - x_start) / offset)
	var new_y = round((pixel_y - y_start) / -offset)
	return Vector2(new_x, new_y)

func is_in_grid(grid_position):
	if grid_position.x >= 0 and grid_position.x < width:
		if grid_position.y >= 0 and grid_position.y < height:
			return true
	return false

# -------------------------------------

func _get_closest_dot_to_cursor():
	var mouse_pos = get_global_mouse_position()
	var space_state = get_world_2d().direct_space_state
	var results = space_state.intersect_point(mouse_pos, 32, [], 2147483647, true, true)
	
	var closest_dot = null
	var min_dist_sq = 10000000
	
	for result in results:
		if result.collider is Area2D:
			var dot = result.collider.get_parent()
			if dot != null and dot.is_in_group("dots"):
				var dist_sq = mouse_pos.distance_squared_to(dot.global_position)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest_dot = dot
	return closest_dot

func _input(event):
	if state != move:
		# If we are dragging, but state changes (e.g. match), cancel drag
		if is_dragging and dragged_dot != null:
			var start_grid_pos = drag_start_grid
			if is_in_grid(start_grid_pos):
				dragged_dot.move(grid_to_pixel(start_grid_pos.x, start_grid_pos.y))
			# Reset tug visuals and z-index
			var spr = dragged_dot.get_node_or_null("Sprite")
			if spr != null:
				spr.position = Vector2.ZERO
			if dragged_dot.has_meta("base_z"):
				dragged_dot.z_index = int(dragged_dot.get_meta("base_z"))
			if dragged_dot != null and dragged_dot.has_method("set_normal_texture"):
				dragged_dot.set_normal_texture()
			is_dragging = false
			dragged_dot = null
		return

	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.is_pressed():
			var dot = _get_closest_dot_to_cursor()
			if dot != null:
				if state != move or dot.is_arrested:
					return
				
				_restart_idle_timers()
				idle_hint_count = 0
				
				dragged_dot = dot
				dragged_dot.z_index = 100 # Bring to front
				drag_start_position = dot.position
				drag_start_grid = pixel_to_grid(dot.position.x, dot.position.y)
				is_dragging = true
				dragged_dot.play_drag_sad_animation()
		elif not event.is_pressed(): # Mouse Button Released
			if is_dragging and dragged_dot != null:
				var end_lp = to_local(get_global_mouse_position())
				var end_grid_pos = pixel_to_grid(end_lp.x, end_lp.y)
				
				var start_grid_pos = pixel_to_grid(drag_start_position.x, drag_start_position.y)
				
				var performed_swap = false
				if is_in_grid(start_grid_pos) and is_in_grid(end_grid_pos):
					var difference = end_grid_pos - start_grid_pos
					if abs(difference.x) + abs(difference.y) == 1:
						_restart_idle_timers()
						var dot1 = all_dots[start_grid_pos.x][start_grid_pos.y]
						var dot2 = all_dots[end_grid_pos.x][end_grid_pos.y]
						if dot1 != null and dot2 != null:
							if not ((dot1.is_ingredient and difference.x != 0) or (dot2.is_ingredient and difference.x != 0)):
								var swap_state = swap_dots(start_grid_pos.x, start_grid_pos.y, end_grid_pos.x, end_grid_pos.y)
								var swap_result = swap_state
								if typeof(swap_result) == TYPE_OBJECT and swap_result is GDScriptFunctionState:
									swap_result = yield(swap_result, "completed")
								if bool(swap_result):
									performed_swap = true
				
				# Cleanup drag state
				is_dragging = false
				if not performed_swap and is_in_grid(start_grid_pos) and is_instance_valid(dragged_dot):
						var move_tween = dragged_dot.move(grid_to_pixel(start_grid_pos.x, start_grid_pos.y))
						yield(move_tween, "finished")
				# Reset tug visuals and z-index
				if is_instance_valid(dragged_dot):
						dragged_dot.z_index = height - start_grid_pos.y
						if dragged_dot.has_method("set_normal_texture"):
								dragged_dot.set_normal_texture()
				dragged_dot = null
				_restart_idle_timers()

func swap_dots(col1, row1, col2, row2) -> bool:
	if not is_instance_valid(all_dots[col1][row1]) or not is_instance_valid(all_dots[col2][row2]):
		return false
	var first_dot = all_dots[col1][row1]
	var other_dot = all_dots[col2][row2]
	
	if first_dot != null && other_dot != null:
		# --- NEW: Block swaps with boss tiles ---
		if boss_tiles.has(Vector2(col1,row1)) or boss_tiles.has(Vector2(col2,row2)):
			return false
		# --- NEW: Block swaps with ingredients/arrested dots ---
		if first_dot.is_arrested or other_dot.is_arrested:
			return false
		if first_dot.is_ingredient or other_dot.is_ingredient:
			if not _swap_creates_match(col1, row1, col2, row2):
				return false
		# -----------------------------------------------------

		first_dot.reset_to_normal_state()
		other_dot.reset_to_normal_state()
		
		store_info(first_dot, other_dot, Vector2(col1, row1), Vector2(col2, row2))
		state = wait
		all_dots[col1][row1] = other_dot
		all_dots[col2][row2] = first_dot
		
		first_dot.z_index = height - row2
		other_dot.z_index = height - row1
		
		var tween1 = first_dot.move(grid_to_pixel(col2, row2))
		var tween2 = other_dot.move(grid_to_pixel(col1, row1))

		yield(tween1, "finished")
		yield(tween2, "finished")

		if !move_checked:
			find_matches()
		return true
	return false
		
func _swap_creates_match(col1, row1, col2, row2) -> bool:
	var dot1 = all_dots[col1][row1]
	var dot2 = all_dots[col2][row2]
	if dot1 == null or dot2 == null:
		return false
	all_dots[col1][row1] = dot2
	all_dots[col2][row2] = dot1
	var creates_match = false
	if dot2 != null and not dot2.is_ingredient:
		creates_match = match_at(col1, row1, dot2.color)
	if not creates_match and dot1 != null and not dot1.is_ingredient:
		creates_match = match_at(col2, row2, dot1.color)
	all_dots[col1][row1] = dot1
	all_dots[col2][row2] = dot2
	return creates_match
		
func store_info(first_dot, other_dot, place1, place2):
	dot_one = first_dot
	dot_two = other_dot
	last_place = place1
	last_direction = place2
		
func swap_back():
	print("Swapping back")
	if dot_one != null && dot_two != null and is_instance_valid(dot_one) and is_instance_valid(dot_two):
		
		all_dots[last_place.x][last_place.y] = dot_one
		all_dots[last_direction.x][last_direction.y] = dot_two
		
		dot_one.move(grid_to_pixel(last_place.x, last_place.y))
		dot_two.move(grid_to_pixel(last_direction.x, last_direction.y))

		var temp_z = dot_one.z_index
		dot_one.z_index = dot_two.z_index
		dot_two.z_index = temp_z
		
	state = move
	move_checked = false
	combo_counter = 1
	_failed_attempts += 1
	if AUTO_RESHUFFLE and _failed_attempts >= 3:
		_failed_attempts = 0
		yield(reshuffle_board(), "completed")
		yield(ensure_moves_available(), "completed")
		var group = find_potential_match_group()
		if group.size() >= 3:
			var target_color = group[0].color
			var trio: Array = []
			for d in group:
				if d != null and d.color == target_color:
					trio.append(d)
			if trio.size() >= 3:
				for d in trio:
					d.play_idle_animation()
		_restart_idle_timers()

	_synchronize_after_move()
	
func _process(_delta):
	if is_dragging and dragged_dot != null:
		dragged_dot.global_position = get_global_mouse_position()


func _maybe_trigger_arrest_event() -> void:
	if _arrest_active:
		return
		
	# --- MODIFIED: Only trigger jail in SCORE mode ---
	if current_goal_type != LevelManagerScript.GoalType.SCORE:
		return
	# ---------------------------------------------
		
	if randi() % 100 < 6:
		var present: Array = []
		for i in range(width):
			for j in range(height):
				var d = all_dots[i][j]
				if d != null and not d.is_ingredient and not present.has(d.color):
					present.append(d.color)
		if present.size() == 0:
			return
		present.shuffle()
		_trigger_arrest_event(String(present[0]))

func _trigger_arrest_event(col: String) -> void:
	_arrest_active = true
	_arrested_color = col
	_arrest_stage = 3
	_flash_siren_overlay()
	var candidates: Array = []
	for i in range(width):
		for j in range(height):
			var d = all_dots[i][j]
			if d != null and String(d.color) == _arrested_color:
				candidates.append(Vector2(i,j))
	if candidates.size() == 0:
		_arrest_active = false
		return
	candidates.shuffle()
	var pick: Vector2 = candidates[0]
	_arrested_dot = all_dots[int(pick.x)][int(pick.y)]
	if _arrested_dot != null:
		_arrested_dot.play_sad_animation()
		if _arrested_dot.has_method("apply_jail_overlay"):
			_arrested_dot.apply_jail_overlay(_arrest_stage)
		var base = int(_arrested_dot.get_meta("base_z")) if _arrested_dot.has_meta("base_z") else _arrested_dot.z_index
		_arrested_dot.z_index = base - 1
	if AudioManager != null and not _siren_played:
		AudioManager.play_sound("siren")
		_siren_played = true

func _apply_arrest_overlay_if_needed(d) -> void:
	if _arrest_active and d == _arrested_dot and d.has_method("apply_jail_overlay"):
		d.play_sad_animation()
		d.apply_jail_overlay(_arrest_stage)
		var base = int(d.get_meta("base_z")) if d.has_meta("base_z") else d.z_index
		d.z_index = base - 1

func _update_arrest_overlays() -> void:
	if _arrested_dot != null and _arrested_dot.has_method("update_jail_overlay"):
		_arrested_dot.update_jail_overlay(_arrest_stage)

func _jailbreak_release() -> void:
	if _arrested_dot != null and _arrested_dot.has_method("show_jailbreak_then_clear"):
		_arrested_dot.show_jailbreak_then_clear()
		_arrested_dot.matched = true
		for ii in range(width):
			for jj in range(height):
				if all_dots[ii][jj] == _arrested_dot:
					all_dots[ii][jj] = null
					break
	if PlayerManager != null and PlayerManager.has_method("increment_jailbreak_for_color"):
		PlayerManager.increment_jailbreak_for_color(_arrested_color)
	_arrest_active = false
	_arrested_color = ""
	_arrest_stage = 0
	_siren_played = false
	if AudioManager != null:
		AudioManager.play_sound("jail_break")
	
	# --- NEW: Check if this was the level goal ---
	if current_goal_type == LevelManagerScript.GoalType.JAILBREAK:
		objective_goal_count = 0 # Goal complete!
		game_ui.update_goal_count(0)
		check_game_over_conditions(true) # Force a win check
	# -------------------------------------------

func _flash_siren_overlay() -> void:
	var layer = get_parent().get_node_or_null("CanvasLayer")
	if layer == null:
		return
	var cr = ColorRect.new()
	cr.name = "SirenFlash"
	cr.color = Color(0,0,1,0.0)
	cr.anchor_left = 0
	cr.anchor_top = 0
	cr.anchor_right = 1
	cr.anchor_bottom = 1
	cr.margin_left = 0
	cr.margin_top = 0
	cr.margin_right = 0
	cr.margin_bottom = 0
	layer.add_child(cr)
	var t = get_tree().create_tween()
	t.tween_property(cr, "color", Color(0,0,1,0.35), 0.25)
	t.tween_property(cr, "color", Color(1,0,0,0.35), 0.25)
	t.tween_property(cr, "color", Color(0,0,1,0.35), 0.25)
	t.tween_property(cr, "modulate:a", 0.0, 0.2)
	t.connect("finished", cr, "queue_free")

func spawn_wildcard_safely() -> bool:
	var candidates: Array = []
	for i in range(width):
		for j in range(height):
			if all_dots[i][j] != null and not all_dots[i][j].is_ingredient: # Can't spawn on ingredient
				candidates.append(Vector2(i, j))
	candidates.shuffle()
	for p in candidates:
		var i = int(p.x)
		var j = int(p.y)
		var d = all_dots[i][j]
		if d == null:
			continue
		var was_wild = false
		if d.has_method("set_wildcard"):
			was_wild = bool(d.get("is_wildcard")) if d.has_method("get") else false
			d.set_wildcard(true)
			var unsafe = false
			var groups = _compute_match_groups()
			for g in groups:
				var pos: Array = g["positions"]
				for q in pos:
					if int(q.x) == i and int(q.y) == j:
						unsafe = true
						break
				if unsafe:
					break
			if unsafe:
				d.set_wildcard(was_wild)
				continue
			if AudioManager != null:
				AudioManager.play_sound("wildcard_spawn")
			if PlayerManager != null and PlayerManager.has_method("achievement_unlock"):
				PlayerManager.achievement_unlock("justify_the_means")
			return true
	return false
	
func find_matches():
	var groups = _compute_match_groups()
	var matched_dots = _apply_specials_and_collect(groups)
	if matched_dots.size() > 0:
		print("Matches found: ", matched_dots.size())
		for dot in matched_dots:
			var grid_pos = pixel_to_grid(dot.position.x, dot.position.y)
			print("  - Dot at ", grid_pos, " with color ", dot.color)
		
		# --- NEW: Decrement moves on valid match ---
		moves_left -= 1
		game_ui.update_moves(moves_left)
		# -----------------------------------------
		
		process_match_animations(matched_dots)
		destroy_timer.start()
	else:
		swap_back()


func process_match_animations(dots_in_match):
	var unique_dots = []
	for dot in dots_in_match:
		if dot != null and not dot in unique_dots:
			unique_dots.append(dot)

	unique_dots.sort_custom(self, "_less_by_pos")

	var delay = 0.0
	var matched_color = ""
	for dot in unique_dots:
		if not dot.matched:
			dot.matched = true
			if not dot.is_connected("match_faded", self, "_on_dot_match_faded"):
				dot.connect("match_faded", self, "_on_dot_match_faded")
			dot.play_match_animation(delay)
			delay += 0.05
			if matched_color == "":
				matched_color = dot.color

	for i in range(width):
		for j in range(height):
			var current_dot = all_dots[i][j]
			if current_dot != null and not current_dot.matched:
				current_dot.play_surprised_for_a_second()

func _less_by_pos(a, b):
	if a == null and b == null:
		return false
	if a == null:
		return true
	if b == null:
		return false
	var ax = a.position.x
	var ay = a.position.y
	var bx = b.position.x
	var by = b.position.y
	if ax == bx:
		return ay < by
	return ax < bx

func destroy_matches():
	var was_matched = false
	var points_earned = 0
	var match_center = Vector2.ZERO
	var match_count = 0
	var glasses_triggered: bool = false
	var glasses_center: Vector2 = Vector2.ZERO
	var colors_matched := {}
	var too_cool_hit: bool = false
	var too_cool_pos := Vector2(-1, -1)

	# --- NEW: Boss Battle Damage ---
	if boss != null and boss.is_active:
		var damage_to_boss = 0
		var boss_rect = Rect2(boss.grid_pos, Vector2(2,2))
		for i in range(width):
			for j in range(height):
				if all_dots[i][j] != null and all_dots[i][j].matched:
					# Check adjacency to the 2x2 boss
					var adjacent = false
					for x_offset in range(-1, 3):
						for y_offset in range(-1, 3):
							# Skip corners of the check area
							if (x_offset == -1 and y_offset == -1) or \
							   (x_offset == 2 and y_offset == -1) or \
							   (x_offset == -1 and y_offset == 2) or \
							   (x_offset == 2 and y_offset == 2):
							   continue
							
							var check_pos = boss.grid_pos + Vector2(x_offset, y_offset)
							if Vector2(i,j) == check_pos:
								adjacent = true
								break
						if adjacent:
							break
					
					if adjacent:
						damage_to_boss += 1
		
		if damage_to_boss > 0:
			boss.take_damage(damage_to_boss)
	# -----------------------------
	
	# --- MODIFIED: "Meaner's Mischief" Logic ---
	# This logic is perfect for the objective.
	if _arrest_active and _arrested_dot != null:
		var arrested_pos = pixel_to_grid(_arrested_dot.position.x, _arrested_dot.position.y)
		var neighbors = [
			arrested_pos + Vector2.UP,
			arrested_pos + Vector2.DOWN,
			arrested_pos + Vector2.LEFT,
			arrested_pos + Vector2.RIGHT
		]
		var damage_jail = false
		for i in range(width):
			for j in range(height):
				if all_dots[i][j] != null and all_dots[i][j].matched:
					if Vector2(i,j) in neighbors:
						damage_jail = true
						break
			if damage_jail:
				break
		
		if damage_jail:
			_arrest_stage -= 1
			if _arrest_stage > 0:
				_update_arrest_overlays()
				if _arrested_dot != null and _arrested_dot.has_method("play_shake"):
					_arrested_dot.play_shake(0.18, 6.0)
				if AudioManager != null:
					AudioManager.play_sound("jail_progress")
			else:
				_jailbreak_release() # This will free the dot
	# -----------------------------------------------------------------

	for i in range(width):
		for j in range(height):
			var dot = all_dots[i][j]
			if dot != null and dot.matched:
				if dot == _arrested_dot:
					dot.matched = false
					continue

				var is_too_cool_match = false
				if current_goal_type == LevelManagerScript.GoalType.TOO_COOL and dot.has_method("get"):
					is_too_cool_match = bool(dot.get("is_too_cool"))
					if is_too_cool_match and too_cool_pos.x < 0:
						too_cool_pos = Vector2(i, j)
						_mark_too_cool_lines(too_cool_pos)
				if is_too_cool_match:
					too_cool_hit = true

				print("Destroying dot at (", i, ", ", j, ")")
				was_matched = true
				points_earned += 10 * combo_counter
				match_center += dot.position
				match_count += 1
				colors_matched[dot.color] = true

				var has_glasses_overlay = dot.has_method("get") and bool(dot.get("has_glasses"))
				if has_glasses_overlay and not is_too_cool_match:
					glasses_triggered = true
					glasses_center = dot.global_position
				
				var particles = match_particles.instance()
				particles.position = dot.position
				add_child(particles)
				if not dot.orb_spawned:
					_spawn_xp_orb(dot.global_position, dot.color)
				if dot.float_tween:
					dot.float_tween.stop_all()
				if dot.pulse_tween:
					dot.pulse_tween.stop_all()
				dot.queue_free()
				all_dots[i][j] = null
	
	if points_earned > 0:
		if (Engine.has_singleton("MultiplayerManager") or (typeof(MultiplayerManager) != TYPE_NIL)) and (typeof(WebsocketClient) != TYPE_NIL):
			var ng = get_tree().get_current_scene().get_node_or_null("NetGame")
			if ng != null and ng.has_method("report_local_score"):
				ng.call("report_local_score", points_earned)
			else:
				WebsocketClient.send_game_event("score", {"delta": points_earned})
		if PlayerManager != null and PlayerManager.has_method("achievement_unlock"):
			PlayerManager.achievement_unlock("beginners_luck")
		if match_count >= 5:
			AudioManager.play_sound("match_fanfare")
		elif match_count == 4:
			AudioManager.play_sound("match_chime")
		else:
			AudioManager.play_sound("match_pop")
		score += points_earned
		PlayerManager.add_xp(points_earned)
		PlayerManager.add_to_meaner_meter(match_count * 2)
		if _xp_mult_remaining > 0:
			var boosted: int = int(points_earned * _xp_mult_value)
			if boosted > points_earned:
				PlayerManager.add_xp(boosted - points_earned)
			_xp_mult_remaining -= 1
		PlayerManager.add_lines_cleared(match_count)
		PlayerManager.update_best_combo(combo_counter)
		combo_counter += 1
		_failed_attempts = 0
		_restart_idle_timers()
		update_score_display()
		
		# --- NEW: Update SCORE objective ---
		if current_goal_type == LevelManagerScript.GoalType.SCORE:
			# For score, the "goal count" is the remaining score
			var remaining_score = max(0, target_score - score)
			objective_goal_count = remaining_score
			game_ui.update_goal_count(objective_goal_count)
		# -----------------------------------
		
		if match_count > 0:
			match_center /= match_count

			var match_label = match_label_scene.instance()
			match_label.text = "+" + str(points_earned)
			get_parent().get_node("CanvasLayer").add_child(match_label)
			var screen_pos = to_global(match_center - Vector2(0, 20))
			if match_label is Control:
				match_label.rect_global_position = screen_pos
			else:
				match_label.global_position = screen_pos
	
	move_checked = true
	if glasses_triggered:
		_glasses_active = false
		_glasses_target = null
		_on_sunglasses_broken(glasses_center)
		return
	if was_matched:
		collapse_timer.start()
#	else:
#		swap_back()
#		check_game_over_conditions() # Check for loss if swap was invalid and no moves left

	# Your existing "Meaner's Mischief" logic (as event) is fine
	if was_matched:
		_match_events += 1
		_matches_since_glasses += 1
		if (_matches_since_glasses >= 25) and not _glasses_active:
			_matches_since_glasses = 0
			_spawn_glasses_on_random_dot()
		# --- MODIFIED: Only trigger random arrest in SCORE mode ---
		if (_match_events % 20) == 0 and not _arrest_active and current_goal_type == LevelManagerScript.GoalType.SCORE:
			var present: Array = []
			for i in range(width):
				for j in range(height):
					var d = all_dots[i][j]
					if d != null and not d.is_ingredient and not present.has(d.color):
						present.append(d.color)
			if present.size() > 0:
				present.shuffle()
				_trigger_arrest_event(String(present[0]))
	
	if was_matched:
		if too_cool_hit:
			objective_goal_count = 0
			game_ui.update_goal_count(objective_goal_count)
			_too_cool_active = false
			_too_cool_dot = null
			check_game_over_conditions(true)
			return
		check_game_over_conditions()

	
func _dots_match(a, b) -> bool:
	if a == null or b == null:
		return false
	# --- MODIFIED: Ingredients don't match ---
	if a.is_ingredient or b.is_ingredient:
		return false
	# -----------------------------------------
	if a.has_method("set_wildcard") and a.get("is_wildcard"):
		return true
	if b.has_method("set_wildcard") and b.get("is_wildcard"):
		return true
	return a.color == b.color

func _spawn_glasses_on_random_dot() -> void:
	var candidates: Array = []
	for i in range(width):
		for j in range(height):
			var d = all_dots[i][j]
			if d != null and d.has_method("apply_glasses_overlay") and not d.is_ingredient:
				candidates.append(d)
	if candidates.size() == 0:
		return
	candidates.shuffle()
	var d0 = candidates[0]
	d0.apply_glasses_overlay()
	_glasses_active = true
	_glasses_target = d0

func _on_sunglasses_broken(center_pos: Vector2) -> void:
	if AudioManager != null:
		AudioManager.play_sound("clear_board")
	if PlayerManager != null and PlayerManager.has_method("increment_broken_sunglasses"):
		PlayerManager.increment_broken_sunglasses()
	state = wait
	var tweens: Array = []
	for i in range(width):
		for j in range(height):
			var d = all_dots[i][j]
			if d == null:
				continue
			# --- MODIFIED: Don't destroy ingredients with glasses ---
			if d.is_ingredient:
				continue
			# ------------------------------------------------------
			var dist = d.global_position.distance_to(center_pos)
			var delay = clamp(dist / 600.0, 0.0, 0.5)
			var t = get_tree().create_tween()
			t.set_parallel(true)
			t.tween_property(d, "scale", d.scale * 1.4, 0.25).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(d, "modulate:a", 0.0, 0.25).set_delay(delay)
			tweens.append(t)
	if tweens.size() > 0:
		yield(tweens.back(), "finished")
	for i in range(width):
		for j in range(height):
			# --- MODIFIED: Don't destroy ingredients ---
			if all_dots[i][j] != null and not all_dots[i][j].is_ingredient:
			# -----------------------------------------
				all_dots[i][j].queue_free()
				all_dots[i][j] = null
				
	# --- MODIFIED: Re-spawn dots, not full array reset ---
	# This preserves ingredients that were on the board
	spawn_dots() 
	
	# --- NEW: Must re-run objective setup after clearing board ---
	setup_objectives()
	# -----------------------------------------------------------
	# -------------------------------------------------

	for i in range(width):
		for j in range(height):
			if all_dots[i][j] != null and all_dots[i][j].has_method("start_pulsing"):
				all_dots[i][j].start_pulsing()
	yield(ensure_moves_available(), "completed")
	state = move
	_synchronize_after_move()

func _apply_pending_bonus() -> void:
	if typeof(PlayerManager.player_data) != TYPE_DICTIONARY:
		return
	var pending: Dictionary = PlayerManager.player_data.get("pending_bonus", {})
	if typeof(pending) != TYPE_DICTIONARY or pending.size() == 0:
		return
	if pending.has("wildcards"):
		var count: int = int(pending["wildcards"])
		_apply_wildcards(count)
	if pending.has("clear_rows"):
		_apply_clear_rows(int(pending["clear_rows"]))
	if pending.has("clear_cols"):
		_apply_clear_cols(int(pending["clear_cols"]))
	if pending.has("xp_multiplier"):
		var mult_data = pending["xp_multiplier"]
		if typeof(mult_data) == TYPE_DICTIONARY:
			_xp_mult_value = int(mult_data.get("mult", 1))
			_xp_mult_remaining = int(mult_data.get("matches", 0))
	PlayerManager.player_data["pending_bonus"] = {}
	PlayerManager.save_player_data()
	if destroy_timer != null:
		destroy_timer.start()

func _apply_wildcards(count):
	var positions = []
	for i in range(width):
		for j in range(height):
			if all_dots[i][j] != null and not all_dots[i][j].is_ingredient:
				positions.append(Vector2(i, j))
	positions.shuffle()
	var applied: int = 0
	for p in positions:
		if applied >= count:
			break
		var d = all_dots[p.x][p.y]
		if d != null and d.has_method("set_wildcard"):
			d.set_wildcard(true)
			applied += 1

func _apply_clear_rows(num):
	var rows = []
	for j in range(height):
		rows.append(j)
	rows.shuffle()
	for k in range(min(num, rows.size())):
		var row = rows[k]
		for x in range(width):
			# --- MODIFIED: Don't destroy ingredients ---
			if all_dots[x][row] != null and not all_dots[x][row].is_ingredient:
				all_dots[x][row].matched = true
			# -----------------------------------------

func _apply_clear_cols(num):
	var cols = []
	for i in range(width):
		cols.append(i)
	cols.shuffle()
	for k in range(min(num, cols.size())):
		var col = cols[k]
		for y in range(height):
			# --- MODIFIED: Don't destroy ingredients ---
			if all_dots[col][y] != null and not all_dots[col][y].is_ingredient:
				all_dots[col][y].matched = true
			# -----------------------------------------

func _compute_match_groups() -> Array:
	var groups: Array = []
	for j in range(height):
		var i = 0
		while i < width:
			var run: Array = []
			var start_i = i
			if all_dots[i][j] == null or all_dots[i][j].is_ingredient: # Ingredients don't match
				i += 1
				continue
			run.append(Vector2(i, j))
			var k = i + 1
			while k < width and all_dots[k][j] != null and not all_dots[k][j].is_ingredient and _dots_match(all_dots[k-1][j], all_dots[k][j]):
				run.append(Vector2(k, j))
				k += 1
			if run.size() >= 3:
				groups.append({"positions": run.duplicate(), "orientation": "h"})
			i = k if k > start_i else i + 1
	for i in range(width):
		var j = 0
		while j < height:
			var run2: Array = []
			var start_j = j
			if all_dots[i][j] == null or all_dots[i][j].is_ingredient: # Ingredients don't match
				j += 1
				continue
			run2.append(Vector2(i, j))
			var k2 = j + 1
			while k2 < height and all_dots[i][k2] != null and not all_dots[i][k2].is_ingredient and _dots_match(all_dots[i][k2-1], all_dots[i][k2]):
				run2.append(Vector2(i, k2))
				k2 += 1
			if run2.size() >= 3:
				groups.append({"positions": run2.duplicate(), "orientation": "v"})
			j = k2 if k2 > start_j else j + 1
	return groups

func _apply_specials_and_collect(groups: Array) -> Array:
	# --- MODIFIED: Removed all powerup creation logic ---
	var to_match: Array = []
	for g in groups:
		var pos: Array = g["positions"]
		# Standard triple (or larger) – match all in this run
		for p3 in pos:
			var d3 = all_dots[p3.x][p3.y]
			if d3 != null and not d3 in to_match:
				# Wildcards get matched, but not destroyed
				if d3.is_wildcard:
					d3.play_surprised_for_a_second()
				else:
					to_match.append(d3)
	return to_match
	# ----------------------------------------------------

# --- REMOVED powerup VFX functions ---
func _get_white_tex():
	# This function is no longer needed as _spawn_row_sweep is removed
	pass

func _spawn_row_sweep(row: int) -> void:
	pass # Removed

func _spawn_col_sweep(col: int) -> void:
	pass # Removed
# -------------------------------------

func _spawn_xp_orb(from_global_pos: Vector2, color_name: String = ""):
	var layer = get_parent().get_node("CanvasLayer")
	var orb = Sprite.new()
	orb.texture = xp_orb_texture
	orb.scale = Vector2(0.45, 0.45)
	orb.global_position = from_global_pos
	var tint = xp_orb_colors.get(color_name, Color(1,1,1))
	orb.modulate = tint
	layer.add_child(orb)
	var target = game_ui.get_xp_anchor_pos()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	target.x = vp_size.x * 0.5

	var to_target = (target - from_global_pos)
	var perp = Vector2(-to_target.y, to_target.x).normalized()
	var cp1 = from_global_pos + to_target * 0.33 + perp * 60.0
	var cp2 = from_global_pos + to_target * 0.66 - perp * 40.0

	var t = get_tree().create_tween()
	t.tween_property(orb, "global_position", cp1, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(orb, "global_position", cp2, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(orb, "global_position", target, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(orb, "rotation_degrees", orb.rotation_degrees + 360.0, 0.5)
	t.parallel().tween_property(orb, "modulate:a", 0.0, 0.15).set_delay(0.45)
	t.connect("finished", orb, "queue_free")

func _on_dot_match_faded(pos: Vector2, color_name: String):
	# --- MODIFIED: color_name might be "ingredient" ---
	if color_name != "ingredient":
		_spawn_xp_orb(pos, color_name)
	# ------------------------------------------------

func collapse_columns():
	for i in range(width):
		for j in range(height):
			if all_dots[i][j] == null and not restricted_fill(Vector2(i,j)) and not boss_tiles.has(Vector2(i,j)):
				for k in range(j + 1, height):
					if all_dots[i][k] != null:
						var d = all_dots[i][k]
						var base = height - j
						d.set_meta("base_z", base)
						if bool(d.get("is_arrested") if d.has_method("get") else false):
							d.z_index = base - 1
						else:
							d.z_index = base
						d.move(grid_to_pixel(i, j))
						all_dots[i][j] = d
						all_dots[i][k] = null
						break
	refill_timer.start()

func refill_columns():
	for i in range(width):
		for j in range(height):
			if all_dots[i][j] == null and not restricted_fill(Vector2(i,j)) and not boss_tiles.has(Vector2(i,j)):
				# --- MODIFIED: Do not spawn ingredients here ---
				# Ingredients are only spawned by setup_down_to_earth
				# -----------------------------------------------
				var pool = possible_colors.duplicate()
				if _arrest_active and pool.has(_arrested_color):
					for _w in range(3):
						pool.append(_arrested_color)
				var rand = floor(rand_range(0, pool.size()))
				var desired_color = pool[rand]
				var dot_scene_to_use = null
				for dot_scene in possible_dots:
					var probe = dot_scene.instance()
					if probe.color == desired_color:
						dot_scene_to_use = dot_scene
						probe.queue_free()
						break
					probe.queue_free()
				var dot = dot_scene_to_use.instance()
				var loops = 0
				while (match_at(i, j, dot.color) && loops < 100):
					var pr = dot
					pr.queue_free()
					rand = floor(rand_range(0, pool.size()))
					desired_color = pool[rand]
					dot_scene_to_use = null
					for dot_scene in possible_dots:
						var probe2 = dot_scene.instance()
						if probe2.color == desired_color:
							dot_scene_to_use = dot_scene
							probe2.queue_free()
							break
						probe2.queue_free()
					dot = dot_scene_to_use.instance()
					loops += 1
				var base2 = height - j
				dot.set_meta("base_z", base2)
				if bool(dot.get("is_arrested") if dot.has_method("get") else false):
					dot.z_index = base2 - 1
				else:
					dot.z_index = base2
				add_child(dot)
				dot.position = grid_to_pixel(i, j - y_offset)
				var move_tween = dot.move(grid_to_pixel(i,j), 0.12)
				all_dots[i][j] = dot
				
				# --- NEW: Connect signals to new dots ---
				dot.add_to_group("dots")
				dot.connect("match_faded", self, "_on_dot_match_faded")
				# ----------------------------------------
				
				yield(move_tween, "finished")
				AudioManager.play_sound("dot_land")
	after_refill()
				
func after_refill():
	for i in range(width):
		for j in range(height):
			if all_dots[i][j] != null:
				all_dots[i][j].start_pulsing()

	state = wait
	yield(get_tree().create_timer(0.5), "timeout")
	
	# --- NEW: Check for collected ingredients ---
	if current_goal_type == LevelManagerScript.GoalType.DOWN_TO_EARTH:
		var bottom_row = height - 1
		var collected_count = 0
		for x in range(width):
			var dot = all_dots[x][bottom_row]
			if dot != null and dot.is_ingredient:
				dot.play_match_animation(0.0) # Play its simple fade
				dot.queue_free()
				all_dots[x][bottom_row] = null # Remove from grid
				
				objective_goal_count -= 1
				game_ui.update_goal_count(objective_goal_count)
				AudioManager.play_sound("coin") # Use a collect sound
				collected_count += 1
		
		if collected_count > 0:
			var chest_state = _play_ingredient_chest(collected_count)
			yield(chest_state, "completed")
			collapse_timer.start() # Start another collapse/refill cycle
			return # Don't check for matches yet
	# ---------------------------------------------
	
	var needs_another_pass = false
	for i in range(width):
		for j in range(height):
			if all_dots[i][j] != null:
				# --- MODIFIED: Check for ingredients ---
				if not all_dots[i][j].is_ingredient and match_at(i, j, all_dots[i][j].color):
				# ---------------------------------------
					needs_another_pass = true
					break
			if needs_another_pass:
				break
			
	if needs_another_pass:
		find_matches_after_refill()
	else:
		state = move
		move_checked = false
		_synchronize_after_move()
		# --- MODIFIED: Check for win/loss *after* everything settles ---
		if not check_game_over_conditions():
			# If game is not over, check for moves
			yield(ensure_moves_available(), "completed")
			state = move
			_synchronize_after_move()
		# -------------------------------------------------------------

func find_matches_after_refill():
	var groups = _compute_match_groups()
	var matched_dots = _apply_specials_and_collect(groups)
	if matched_dots.size() > 0:
		# --- NEW: Decrement moves on cascade ---
		moves_left -= 1
		game_ui.update_moves(moves_left)
		# -------------------------------------
		process_match_animations(matched_dots)
		destroy_timer.start()

# --- NEW: Game Over Logic ---
# Returns true if the game is over, false otherwise
func check_game_over_conditions(force_win_check = false):
	if state == wait and not force_win_check: # Don't check if board is busy
		return false
		
	var win = false
	match current_goal_type:
		LevelManagerScript.GoalType.SCORE:
			if score >= target_score:
				win = true
		LevelManagerScript.GoalType.DOWN_TO_EARTH:
			if objective_goal_count <= 0:
				win = true
		LevelManagerScript.GoalType.JAILBREAK:
			# Win if the jail is gone (_arrest_active is false AND stage is 0)
			# And we have moves left (or just won on the last move)
			if not _arrest_active and _arrest_stage == 0:
				win = true
		LevelManagerScript.GoalType.EXTERMINATE:
			if objective_goal_count <= 0:
				win = true
		LevelManagerScript.GoalType.TOO_COOL:
			if objective_goal_count <= 0:
				win = true
		
	if win:
		game_over(true)
		return true

	# If no win, check for loss (out of moves)
	if moves_left <= 0:
		game_over(false) # Pass false for loss
		return true
	
	return false # Game is not over

func game_over(win):
	state = wait
	_clear_anvil()
	if AudioManager: AudioManager.stop_music()
	
	if win:
		print("LEVEL COMPLETE!")
		if AudioManager: AudioManager.play_sound("Music_fx_victory")
		if PlayerManager:
			if PlayerManager.has_method("complete_level"):
				PlayerManager.complete_level(current_level_num, score, 3) # 3 stars placeholder
			else:
				print("ERROR: PlayerManager does not have complete_level method.")
	else:
		print("GAME OVER - Out of moves!")
		# You can play a failure sound here
	
	yield(get_tree().create_timer(2.0), "timeout")
	if get_tree() and not win:
		get_tree().change_scene("res://Scenes/Menu.tscn")
# --- End Game Over Logic ---

func _on_idle_timer_timeout():
	var dot_to_yawn = find_potential_match()
	if dot_to_yawn != null:
		dot_to_yawn.play_idle_animation()
	if idle_timer != null:
		idle_timer.start()

func _on_inactivity_timeout():
	if not AUTO_RESHUFFLE:
		return
	yield(reshuffle_board(), "completed")
	yield(ensure_moves_available(), "completed")
	var group = find_potential_match_group()
	if group.size() >= 3:
		var target_color = group[0].color
		var trio = []
		for d in group:
			if d != null and d.color == target_color:
				trio.append(d)
		if trio.size() >= 3:
			for d in trio:
				d.play_idle_animation()
	_restart_idle_timers()

func find_potential_match():
	for i in range(width):
		for j in range(height):
			if all_dots[i][j] == null: continue
			
			if i < width - 1 and all_dots[i+1][j] != null:
				var match_color = can_move_create_match(i, j, Vector2.RIGHT)
				if match_color != null:
					if all_dots[i][j].color == match_color:
						return all_dots[i][j]
					else:
						return all_dots[i+1][j]
		
			if j < height - 1 and all_dots[i][j+1] != null:
				var match_color = can_move_create_match(i, j, Vector2.DOWN)
				if match_color != null:
					if all_dots[i][j].color == match_color:
						return all_dots[i][j]
					else:
						return all_dots[i][j+1]
	return null

func find_potential_match_group():
	for i in range(width):
		for j in range(height):
			if all_dots[i][j] == null:
				continue
			if i < width - 1 and all_dots[i+1][j] != null:
				# --- MODIFIED: Check for ingredient block ---
				if (all_dots[i][j].is_ingredient or all_dots[i+1][j].is_ingredient) and Vector2.RIGHT.x != 0:
					continue
				# ----------------------------------------
				if can_move_create_match(i, j, Vector2.RIGHT):
					var pos = _compute_yawn_group_for_swap(i, j, Vector2.RIGHT)
					if pos.size() >= 3:
						var nodes = []
						for p in pos:
							if all_dots[p.x][p.y] != null:
								nodes.append(all_dots[p.x][p.y])
						return nodes
			if j < height - 1 and all_dots[i][j+1] != null:
				# --- MODIFIED: Check for ingredient block ---
				# (Vertical swaps are allowed, so no check here)
				# ----------------------------------------
				if can_move_create_match(i, j, Vector2.DOWN):
					var pos2 = _compute_yawn_group_for_swap(i, j, Vector2.DOWN)
					if pos2.size() >= 3:
						var nodes2 = []
						for p2 in pos2:
							if all_dots[p2.x][p2.y] != null:
								nodes2.append(all_dots[p2.x][p2.y])
						return nodes2
	return []

func _compute_match_triplet_after_swap(i, j, direction):
	var di: int = int(direction.x)
	var dj: int = int(direction.y)
	var other_i: int = i + di
	var other_j: int = j + dj
	if other_i < 0 or other_i >= width or other_j < 0 or other_j >= height:
		return []
	if all_dots[i][j] == null or all_dots[other_i][other_j] == null:
		return []
	# --- MODIFIED: Block ingredient swaps ---
	if (all_dots[i][j].is_ingredient or all_dots[other_i][other_j].is_ingredient) and direction.x != 0:
		return []
	# --------------------------------------

	var original_color = all_dots[i][j].color
	var other_color = all_dots[other_i][other_j].color

	var temp_all_dots = []
	for x in range(width):
		temp_all_dots.append([])
		for y in range(height):
			if all_dots[x][y] != null:
				# --- MODIFIED: Check ingredient ---
				if all_dots[x][y].is_ingredient:
					temp_all_dots[x].append("ingredient") # Use a placeholder
				else:
					temp_all_dots[x].append(all_dots[x][y].color)
				# ----------------------------------
			else:
				temp_all_dots[x].append(null)

	temp_all_dots[i][j] = other_color
	temp_all_dots[other_i][other_j] = original_color

	if other_i > 0 and other_i < width - 1:
		if temp_all_dots[other_i - 1][other_j] == other_color and temp_all_dots[other_i + 1][other_j] == other_color:
			return [Vector2(other_i - 1, other_j), Vector2(other_i, other_j), Vector2(other_i + 1, other_j)]
	if other_j > 0 and other_j < height - 1:
		if temp_all_dots[other_i][other_j - 1] == other_color and temp_all_dots[other_i][other_j + 1] == other_color:
			return [Vector2(other_i, other_j - 1), Vector2(other_i, other_j), Vector2(other_i, other_j + 1)]

	if i > 0 and i < width - 1:
		if temp_all_dots[i - 1][j] == other_color and temp_all_dots[i + 1][j] == other_color:
			return [Vector2(i - 1, j), Vector2(i, j), Vector2(i + 1, j)]
	if j > 0 and j < height - 1:
		if temp_all_dots[i][j - 1] == other_color and temp_all_dots[i][j + 1] == other_color:
			return [Vector2(i, j - 1), Vector2(i, j), Vector2(i, j + 1)]

	return []

func _compute_yawn_group_for_swap(i, j, direction):
	var di: int = int(direction.x)
	var dj: int = int(direction.y)
	var other_i: int = i + di
	var other_j: int = j + dj
	if other_i < 0 or other_i >= width or other_j < 0 or other_j >= height:
		return []
	if all_dots[i][j] == null or all_dots[other_i][other_j] == null:
		return []
	# --- MODIFIED: Block ingredient swaps ---
	if (all_dots[i][j].is_ingredient or all_dots[other_i][other_j].is_ingredient) and direction.x != 0:
		return []
	# --------------------------------------

	var original_color = all_dots[i][j].color
	var other_color = all_dots[other_i][other_j].color

	var temp_all_dots = []
	for x in range(width):
		temp_all_dots.append([])
		for y in range(height):
			if all_dots[x][y] != null:
				# --- MODIFIED: Check ingredient ---
				if all_dots[x][y].is_ingredient:
					temp_all_dots[x].append("ingredient")
				else:
					temp_all_dots[x].append(all_dots[x][y].color)
				# ----------------------------------
			else:
				temp_all_dots[x].append(null)

	temp_all_dots[i][j] = other_color
	temp_all_dots[other_i][other_j] = original_color

	if other_i > 0 and other_i < width - 1:
		if temp_all_dots[other_i - 1][other_j] == other_color and temp_all_dots[other_i + 1][other_j] == other_color:
			return [Vector2(other_i - 1, other_j), Vector2(other_i, other_j), Vector2(other_i + 1, other_j)]
	if other_j > 0 and other_j < height - 1:
		if temp_all_dots[other_i][other_j - 1] == other_color and temp_all_dots[other_i][other_j + 1] == other_color:
			return [Vector2(other_i, other_j - 1), Vector2(other_i, other_j), Vector2(other_i, other_j + 1)]

	if i > 0 and i < width - 1:
		if temp_all_dots[i - 1][j] == other_color and temp_all_dots[i + 1][j] == other_color:
			return [Vector2(i - 1, j), Vector2(i + 1, j), Vector2(other_i, other_j)]
	if j > 0 and j < height - 1:
		if temp_all_dots[i][j - 1] == other_color and temp_all_dots[i][j + 1] == other_color:
			return [Vector2(i, j - 1), Vector2(i, j + 1), Vector2(other_i, other_j)]

	return []

func ensure_moves_available(max_attempts = 10):
	yield(get_tree(), "idle_frame")
	var attempts = 0
	while find_potential_match() == null and attempts < max_attempts:
		attempts += 1
		var shuffled = yield(reshuffle_board(), "completed")
		if not shuffled:
			break

	if find_potential_match() == null:
		push_warning("Unable to find a valid move after reshuffling.")

	_restart_idle_timers()

func _matrix_has_immediate_match(matrix: Array) -> bool:
	for j in range(height):
		for i in range(width - 2):
			var a = matrix[i][j]
			var b = matrix[i + 1][j]
			var c = matrix[i + 2][j]
			if a != null and b != null and c != null:
				# --- MODIFIED: Check ingredients ---
				if a.is_ingredient or b.is_ingredient or c.is_ingredient:
					continue
				# ---------------------------------
				if a.color == b.color and b.color == c.color:
					return true
	for i in range(width):
		for j in range(height - 2):
			var a2 = matrix[i][j]
			var b2 = matrix[i][j + 1]
			var c2 = matrix[i][j + 2]
			if a2 != null and b2 != null and c2 != null:
				# --- MODIFIED: Check ingredients ---
				if a2.is_ingredient or b2.is_ingredient or c2.is_ingredient:
					continue
				# ---------------------------------
				if a2.color == b2.color and b2.color == c2.color:
					return true
	return false

func reshuffle_board() -> bool:
	var dots: Array = []
	var occupied_cells: Array = []
	for i in range(width):
		for j in range(height):
			if all_dots[i][j] != null:
				# --- MODIFIED: Don't reshuffle ingredients or boss tiles ---
				if all_dots[i][j].is_ingredient or boss_tiles.has(Vector2(i,j)):
					continue
				# -------------------------------------------
				dots.append(all_dots[i][j])
				occupied_cells.append(Vector2(i, j))

	if dots.size() <= 1:
		return false

	is_dragging = false
	dragged_dot = null

	state = wait
	if AudioManager != null:
		AudioManager.play_sound("shuffle")



	var valid_matrix: Array = []
	var target_cells: Array
	var final_target_cells: Array = []
	var attempts: int = 0
	var max_attempts: int = 200
	while attempts < max_attempts:
		attempts += 1
		target_cells = occupied_cells.duplicate()
		target_cells.shuffle()
		var candidate = make_2d_array()
		
		# --- MODIFIED: Add ingredients back in first ---
		for i in range(width):
			for j in range(height):
				if all_dots[i][j] != null and all_dots[i][j].is_ingredient:
					candidate[i][j] = all_dots[i][j]
		# -------------------------------------------

		for idx in range(dots.size()):
			var dot = dots[idx]
			var target_cell: Vector2 = target_cells[idx]
			candidate[target_cell.x][target_cell.y] = dot
			
		if _matrix_has_immediate_match(candidate):
			continue
		valid_matrix = candidate
		final_target_cells = target_cells.duplicate()
		break

	if valid_matrix.size() == 0:
		valid_matrix = make_2d_array()
		# --- MODIFIED: Add ingredients back in first ---
		for i in range(width):
			for j in range(height):
				if all_dots[i][j] != null and all_dots[i][j].is_ingredient:
					valid_matrix[i][j] = all_dots[i][j]
		# -------------------------------------------
		var tc = occupied_cells.duplicate()
		tc.shuffle()
		for idx in range(dots.size()):
			var d = dots[idx]
			var cell: Vector2 = tc[idx]
			valid_matrix[cell.x][cell.y] = d
		final_target_cells = tc

	var tweens: Array = []
	var offset_range = offset * 0.3
	
	# --- MODIFIED: Create a new all_dots array ---
	var new_all_dots = make_2d_array()
	for i in range(width):
		for j in range(height):
			if all_dots[i][j] != null and all_dots[i][j].is_ingredient:
				new_all_dots[i][j] = all_dots[i][j] # Keep ingredient in place
	# -------------------------------------------

	for idx in range(dots.size()):
		var dot2 = dots[idx]
		var target_cell2 = final_target_cells[idx]
		dot2.matched = false
		dot2.z_index = height - target_cell2.y
		var start_pos = dot2.position
		var target_pos = grid_to_pixel(target_cell2.x, target_cell2.y)
		var tween = get_tree().create_tween()
		var random_offset = Vector2(rand_range(-offset_range, offset_range), rand_range(-offset_range, offset_range))
		tween.tween_property(dot2, "position", start_pos + random_offset, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(dot2, "position", target_pos, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tweens.append(tween)
		
		new_all_dots[target_cell2.x][target_cell2.y] = dot2 # Add to new grid

	all_dots = new_all_dots # Assign the new grid
	move_checked = false

	if tweens.size() > 0:
		yield(tweens.back(), "finished")

	state = move
	_synchronize_after_move()
	for ii in range(width):
		for jj in range(height):
			var dnode = all_dots[ii][jj]
			if dnode == null:
				continue
			if dnode.has_method("start_floating"):
				dnode.start_floating()
			if dnode.has_method("start_pulsing"):
				dnode.start_pulsing()
	return true

func can_move_create_match(i, j, direction):
	var di: int = int(direction.x)
	var dj: int = int(direction.y)
	var other_i: int = i + di
	var other_j: int = j + dj
	if other_i < 0 or other_i >= width or other_j < 0 or other_j >= height:
		return null

	if all_dots[i][j] == null or all_dots[other_i][other_j] == null:
		return null
		
	# --- MODIFIED: Block ingredient swaps ---
	if (all_dots[i][j].is_ingredient or all_dots[other_i][other_j].is_ingredient):
		# Exception: allow vertical swaps for ingredients
		if direction.x != 0:
			return null
	# --------------------------------------

	var original_color = all_dots[i][j].color
	var other_color = all_dots[other_i][other_j].color

	var temp_all_dots = []
	for x in range(width):
		temp_all_dots.append([])
		for y in range(height):
			if all_dots[x][y] != null:
				# --- MODIFIED: Check ingredient ---
				if all_dots[x][y].is_ingredient:
					temp_all_dots[x].append("ingredient")
				else:
					temp_all_dots[x].append(all_dots[x][y].color)
				# ----------------------------------
			else:
				temp_all_dots[x].append(null)

	temp_all_dots[i][j] = other_color
	temp_all_dots[other_i][other_j] = original_color

	for x in range(width):
		for y in range(height):
			var color = temp_all_dots[x][y]
			if color == null or color == "ingredient": continue # Ingredients don't match
			if x < width - 2 and temp_all_dots[x+1][y] == color and temp_all_dots[x+2][y] == color:
				return color
			if y < height - 2 and temp_all_dots[x][y+1] == color and temp_all_dots[x][y+2] == color:
				return color
	return null

func _on_level_up(new_level):
	print("Level up to: " + str(new_level))
	yield(celebrate_stage_transition(new_level), "completed")
	
	for i in range(width):
		for j in range(height):
			if all_dots[i][j] != null:
				all_dots[i][j].queue_free()
	all_dots = make_2d_array()
	_clear_too_cool_state()
	_clear_anvil()
	
	# --- NEW: Reload level data on level up ---
	current_level_num = new_level
	# Re-fetch for stage transitions or reloads using the autoload instance
	if LevelManager != null:
		level_data = LevelManager.get_level_data(current_level_num)
	current_goal_type = level_data.get("goal_type", LevelManagerScript.GoalType.SCORE)
	moves_left = level_data.get("moves", 30)
	
	game_ui.update_moves(moves_left)
	game_ui.set_level_goal(level_data)
	
	if current_goal_type == LevelManagerScript.GoalType.SCORE:
		target_score = level_data.get("target_score", 10000)
		objective_goal_count = target_score
	elif current_goal_type == LevelManagerScript.GoalType.DOWN_TO_EARTH:
		objective_goal_count = level_data.get("ingredient_positions", []).size()
	elif current_goal_type == LevelManagerScript.GoalType.JAILBREAK:
		objective_goal_count = 1
	elif current_goal_type == LevelManagerScript.GoalType.EXTERMINATE:
		objective_goal_count = 1 # The boss is the one goal
	elif current_goal_type == LevelManagerScript.GoalType.TOO_COOL:
		objective_goal_count = 1
	
	game_ui.update_goal_count(objective_goal_count)
	# ------------------------------------------
	
	spawn_dots()
	
	# --- NEW: Setup objectives for new level ---
	setup_objectives()
	# -----------------------------------------

	yield(ensure_moves_available(), "completed")
	state = move
	_synchronize_after_move()

func celebrate_stage_transition(new_level):
	state = wait
	yield(play_wave_animation(), "completed")
	yield(play_dance_animation(), "completed")
	yield(show_stage_banner(new_level), "completed")
	state = move
	_synchronize_after_move()

func play_wave_animation():
	var delay_per_column = 0.08
	var row_phase_offset = 0.015
	var rise = 0.12
	var fall = 0.12
	var height_px = 14.0
	var max_delay = 0.0
	for i in range(width):
		for j in range(height):
			var dot = all_dots[i][j]
			if dot == null:
				continue
			var delay = i * delay_per_column + j * row_phase_offset
			var tween = get_tree().create_tween()
			tween.tween_interval(delay)
			var up_pos = dot.position + Vector2(0, -height_px)
			tween.tween_property(dot, "position", up_pos, rise).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(dot, "position", dot.position, fall).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			if delay > max_delay:
				max_delay = delay
	yield(get_tree().create_timer(max_delay + rise + fall), "timeout")
	for i in range(width):
		for j in range(height):
			var dot = all_dots[i][j]
			if dot == null:
				continue
			var tw = get_tree().create_tween()
			tw.tween_property(dot, "rotation_degrees", 0.0, 0.12)

func play_dance_animation():
	var max_duration = 0.6
	for i in range(width):
		for j in range(height):
			var dot = all_dots[i][j]
			if dot == null:
				continue
			var tween = get_tree().create_tween()
			tween.tween_property(dot, "rotation_degrees", 8, 0.15)
			tween.parallel().tween_property(dot, "scale", dot.scale * 1.08, 0.15)
			tween.tween_property(dot, "rotation_degrees", -8, 0.15)
			tween.parallel().tween_property(dot, "scale", dot.scale, 0.15)
	yield(get_tree().create_timer(max_duration), "timeout")

func show_stage_banner(new_level):
	var layer = get_parent().get_node("CanvasLayer")
	var tex = stage_banner_texture
	var vp = get_viewport().get_visible_rect().size
	var size = tex.get_size()
	var margin_y = 40.0

	var root = Control.new()
	root.name = "StageBanner"
	root.rect_size = size
	root.rect_position = Vector2((vp.x - size.x) * 0.5, vp.y - size.y - margin_y)
	layer.add_child(root)

	var banner = TextureRect.new()
	banner.texture = tex
	banner.anchor_left = 0
	banner.anchor_top = 0
	banner.anchor_right = 1
	banner.anchor_bottom = 1
	banner.margin_left = 0
	banner.margin_top = 0
	banner.margin_right = 0
	banner.margin_bottom = 0
	banner.modulate.a = 0.0
	root.add_child(banner)

	var text = Label.new()
	text.text = "LEVEL UP!" # You could change this to "LEVEL " + str(new_level)
	text.align = Label.ALIGN_CENTER
	text.valign = Label.VALIGN_CENTER
	text.modulate = Color(1, 1, 1, 0.0)
	text.anchor_left = 0
	text.anchor_top = 0
	text.anchor_right = 1
	text.anchor_bottom = 1
	text.margin_left = 0
	text.margin_top = 0
	text.margin_right = 0
	text.margin_bottom = 0
	root.add_child(text)

	var t = get_tree().create_tween()
	t.tween_property(banner, "modulate:a", 1.0, 0.25)
	t.parallel().tween_property(text, "modulate:a", 1.0, 0.25)
	yield(t, "finished")
	yield(get_tree().create_timer(0.9), "timeout")
	var t2 = get_tree().create_tween()
	t2.tween_property(banner, "modulate:a", 0.0, 0.3)
	t2.parallel().tween_property(text, "modulate:a", 0.0, 0.3)
	yield(t2, "finished")
	root.queue_free()

func _exit_tree():
	for t in [destroy_timer, collapse_timer, refill_timer, idle_timer, inactivity_timer]:
		if t != null:
			t.stop()

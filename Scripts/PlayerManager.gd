extends Node

onready var firebase = get_node_or_null("/root/Firebase")
onready var SaveManager = get_node_or_null("/root/SaveManager")
onready var AudioManager = get_node_or_null("/root/AudioManager")

signal level_up(new_level)
signal frame_changed(new_frame)
signal coins_changed(new_amount)
signal avatar_changed
signal meaner_meter_changed(current, max_value)
signal meaner_meter_filled()

var player_uid = ""
var last_user_info: Dictionary = {}
var player_data = {
	"player_name": "",
	"time_played": 0,
	"current_level": 1,
	"current_xp": 0,
	"coins": 0,
	"best_combo": 0,
	"total_lines_cleared": 0,
	"bonus_spins": 0,
	"broken_sunglasses": 0,
	"current_frame": "default",
	"meaner_meter": {"current": 0, "max": 100},
	"unlocks": {
		"trophies": [],
		"frames": ["default", "frame_2"],
		"aliases": []
	},
	"jailbreaks": {},
	"objectives": {
		"time_played_1hr": false
	}
}

func _ready():
	if firebase == null:
		print("Firebase not available: running offline (cloud save disabled).")
		# Load local save if present
		if SaveManager.has_player():
			var local = SaveManager.load_player()
			if typeof(local) == TYPE_DICTIONARY and local.size() > 0:
				player_data = local
		return

func load_player_data(user_info):
	if firebase == null:
		return

	last_user_info = user_info if typeof(user_info) == TYPE_DICTIONARY else {}
	var uid = ""
	if last_user_info.has("uid"):
		uid = str(last_user_info.get("uid"))
	elif last_user_info.has("localid"):
		uid = str(last_user_info.get("localid"))
	elif last_user_info.has("userid"):
		uid = str(last_user_info.get("userid"))
	elif last_user_info.has("user_id"):
		uid = str(last_user_info.get("user_id"))
	player_uid = uid
	if player_uid:
		var coll = firebase.Firestore.collection("players")
		var doc = yield(coll.get_doc(player_uid), "completed")
		if doc != null:
			print("Player data loaded from Firestore.")
			# Convert Firestore fields to a plain Dictionary
			player_data = Utilities.fields2dict({"fields": doc.document})
		else:
			print("New player. Creating default data.")
			var display = ""
			if typeof(last_user_info) == TYPE_DICTIONARY:
				display = str(last_user_info.get("displayname", last_user_info.get("displayName", "")))
			if display == "":
				display = "Player"
			player_data["player_name"] = display
			yield(coll.add(player_uid, player_data), "completed")
	else:
		print("No UID found in user_info")

func save_player_data():
	if firebase == null or player_uid == "":
		# Fallback: persist locally
		SaveManager.save_player(player_data)
		return
	var coll = firebase.Firestore.collection("players")
	var doc = yield(coll.get_doc(player_uid), "completed")
	if doc == null:
		yield(coll.add(player_uid, player_data), "completed")
	else:
		# Update fields in existing document
		for key in player_data.keys():
			doc.add_or_update_field(key, player_data[key])
		yield(coll.update(doc), "completed")

func _on_document_saved():
	print("Player data saved to Firestore.")


func get_player_name():
	return player_data["player_name"]

func add_time_played(seconds):
	player_data["time_played"] += seconds
	check_objectives()
	# Progress time-based achievement (First Hour Down)
	achievement_progress("first_hour_down", int(seconds))
	save_player_data()

const BASE_XP = 180
const XP_GROWTH = 1.35 # multiplicative growth per level
const COIN_CONVERSION_RATE = 50 # XP per 1 coin awarded at level-up

func get_xp_for_level(level: int) -> int:
	return int(round(BASE_XP * pow(XP_GROWTH, max(level - 1, 0)))) * 2

func get_xp_for_next_level() -> int:
	return get_xp_for_level(player_data["current_level"]) 

func add_xp(amount):
	player_data["current_xp"] += amount
	var _leveled: bool = false
	while player_data["current_xp"] >= get_xp_for_next_level():
		var threshold: int = get_xp_for_next_level()
		player_data["current_xp"] -= threshold
		player_data["current_level"] += 1
		# Convert part of the stage XP into coins at each level-up
		var coins_awarded: int = int(threshold / float(COIN_CONVERSION_RATE))
		if coins_awarded > 0:
			player_data["coins"] += coins_awarded
			emit_signal("coins_changed", player_data["coins"])
			_show_xp_conversion_animation()
		_leveled = true
		emit_signal("level_up", player_data["current_level"])
	# Achievements for reaching certain levels (safe wrappers)
	if player_data["current_level"] >= 2:
		achievement_unlock("first_chapter")
	if player_data["current_level"] >= 10:
		achievement_unlock("youve_finally")
	save_player_data()

func _show_xp_conversion_animation():
	var scene = get_tree().current_scene
	if not is_instance_valid(scene):
		return

	var layer = CanvasLayer.new()
	layer.name = "XpToGoldAnim"
	scene.add_child(layer)

	var icon = TextureRect.new()
	icon.texture = load("res://Assets/Visuals/xp_gold_convert.png")
	icon.anchor_left = 0.5
	icon.anchor_top = 0.5
	icon.anchor_right = 0.5
	icon.anchor_bottom = 0.5
	icon.margin_left = 0
	icon.margin_top = 0
	icon.margin_right = 0
	icon.margin_bottom = 0
	icon.modulate.a = 0.0
	layer.add_child(icon)

	if AudioManager != null:
		AudioManager.play_sound("coin.ogg")

	# Initialize start state explicitly for Godot 3 Control properties
	icon.rect_scale = Vector2.ZERO
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(icon, "rect_scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "modulate:a", 1.0, 0.2)
	yield(tween, "finished")

	var pulse_tween = create_tween().set_loops(2)
	pulse_tween.set_parallel(true)
	pulse_tween.tween_property(icon, "rect_scale", Vector2(1.4, 1.4), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(icon, "rect_scale", Vector2(1.2, 1.2), 0.4).set_delay(0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	yield(pulse_tween, "finished")

	var end_tween = create_tween()
	end_tween.set_parallel(true)
	end_tween.tween_property(icon, "rect_scale", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	end_tween.tween_property(icon, "modulate:a", 0.0, 0.3)
	yield(end_tween, "finished")

	layer.queue_free()

func update_best_combo(new_combo):
	if new_combo > player_data["best_combo"]:
		player_data["best_combo"] = new_combo
		# Achievement: On a Roll (combo 10)
		if new_combo >= 10:
			achievement_progress("on_a_roll", 1)
			achievement_unlock("on_a_roll")
		save_player_data()

func add_lines_cleared(lines):
	player_data["total_lines_cleared"] += lines
	# Progress: On the Board (clear 100 dots)
	achievement_progress("on_the_board", int(lines))
	save_player_data()

func get_coins():
	return player_data.get("coins", 0)

func can_spend(amount):
	return get_coins() >= amount

func spend_coins(amount):
	if not can_spend(amount):
		return false
	player_data["coins"] -= amount
	emit_signal("coins_changed", player_data["coins"])
	save_player_data()
	return true

func check_objectives():
	# Check for time played
	if player_data["time_played"] >= 3600 and not player_data["objectives"]["time_played_1hr"]:
		player_data["objectives"]["time_played_1hr"] = true
		unlock_trophy("time_played_1hr_trophy")

signal trophy_unlocked(trophy_resource)

func unlock_trophy(trophy_id):
	if not trophy_id in player_data["unlocks"]["trophies"]:
		player_data["unlocks"]["trophies"].append(trophy_id)
		var trophy_resource = load("res://Assets/Trophies/" + trophy_id + ".tres")
		emit_signal("trophy_unlocked", trophy_resource)

func set_current_frame(frame_name):
	player_data["current_frame"] = frame_name
	emit_signal("frame_changed", frame_name)
	save_player_data()

func unlock_frame(frame_name):
	if not player_data.has("unlocks"):
		player_data["unlocks"] = {"frames": [], "trophies": [], "aliases": []}
	if not player_data["unlocks"].has("frames"):
		player_data["unlocks"]["frames"] = []
	if not frame_name in player_data["unlocks"]["frames"]:
		player_data["unlocks"]["frames"].append(frame_name)
		save_player_data()

func get_current_frame():
	return player_data["current_frame"]

func get_current_xp():
	return player_data["current_xp"]

func get_current_level():
	return player_data["current_level"]

# External callers (e.g., Profile.gd) should call this when avatar image changes
func notify_avatar_changed() -> void:
	emit_signal("avatar_changed")
	# Achievement: I Remember My... (set an avatar)
	achievement_unlock("i_remember_my")

func increment_bonus_spins() -> void:
	player_data["bonus_spins"] = int(player_data.get("bonus_spins", 0)) + 1
	achievement_progress("frequent_flyer", 1)
	if player_data["bonus_spins"] >= 5:
		achievement_unlock("frequent_flyer")
	save_player_data()

func increment_broken_sunglasses() -> void:
	player_data["broken_sunglasses"] = int(player_data.get("broken_sunglasses", 0)) + 1
	save_player_data()

# Safe Achievement helpers
func achievement_unlock(id: String) -> void:
	# Use autoload if present, otherwise no-op
	var am = get_node_or_null("/root/AchievementManager")
	if am and am.has_method("unlock_achievement"):
		am.unlock_achievement(id)

func achievement_progress(id: String, amount: int) -> void:
	# Use autoload if present, otherwise no-op
	var am = get_node_or_null("/root/AchievementManager")
	if am and am.has_method("progress_achievement"):
		am.progress_achievement(id, amount)

# MEANER METER API
func get_meaner_meter_current() -> int:
	if typeof(player_data) == TYPE_DICTIONARY:
		var meter = player_data.get("meaner_meter", {})
		if typeof(meter) == TYPE_DICTIONARY:
			return int(meter.get("current", 0))
	return 0

func get_meaner_meter_max() -> int:
	if typeof(player_data) == TYPE_DICTIONARY:
		var meter = player_data.get("meaner_meter", {})
		if typeof(meter) == TYPE_DICTIONARY:
			return int(meter.get("max", 100))
	return 100

func add_to_meaner_meter(delta: int) -> void:
	if delta <= 0:
		return
	var meter = player_data.get("meaner_meter", {"current": 0, "max": 100})
	var cur: int = int((meter.get("current", 0)))
	var mx: int = int((meter.get("max", 100)))
	cur += delta
	var filled_now: bool = false
	if cur >= mx:
		cur = mx
		filled_now = true
	meter["current"] = cur
	player_data["meaner_meter"] = meter
	emit_signal("meaner_meter_changed", cur, mx)
	if filled_now:
		emit_signal("meaner_meter_filled")
	save_player_data()

func reset_meaner_meter() -> void:
	var meter = player_data.get("meaner_meter", {"current": 0, "max": 100})
	meter["current"] = 0
	player_data["meaner_meter"] = meter
	emit_signal("meaner_meter_changed", 0, int(meter.get("max", 100)))
	save_player_data()

func increment_jailbreak_for_color(color: String) -> void:
	if not player_data.has("jailbreaks"):
		player_data["jailbreaks"] = {}
	var jb = player_data["jailbreaks"]
	jb[color] = int(jb.get(color, 0)) + 1
	player_data["jailbreaks"] = jb
	save_player_data()

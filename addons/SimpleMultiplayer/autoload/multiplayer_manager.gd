extends Node

export(String) var player_scene_path = "res://Scenes/NetPlayer.tscn"

var _players = {}
var _local_id = ""
var session_mode = ""
var session_target = 0
var session_seed = 0

func _ready():
	if Engine.has_singleton("WebsocketClient") or (typeof(WebsocketClient) != TYPE_NIL):
		WebsocketClient.connect("connection_succeeded", self, "_on_connected")
		WebsocketClient.connect("room_joined", self, "_on_room_joined")
		WebsocketClient.connect("room_state", self, "_on_room_state")
		WebsocketClient.connect("player_joined", self, "_on_player_joined")
		WebsocketClient.connect("player_left", self, "_on_player_left")
		WebsocketClient.connect("message_received", self, "_on_message")
		WebsocketClient.connect("start_game", self, "_on_start_game")

func _on_connected():
	# No-op
	pass

func _on_room_joined(_code, id):
	_local_id = id

func _on_room_state(players):
	# Spawn any listed players (including local)
	for pid in players:
		_ensure_player(String(pid))

func _on_player_joined(pid):
	_ensure_player(pid)

func _on_player_left(pid):
	if _players.has(pid):
		var n = _players[pid]
		if is_instance_valid(n):
			n.queue_free()
		_players.erase(pid)

func _on_start_game(payload = {}):
	# Ensure all current players exist
	if Engine.has_singleton("WebsocketClient") or (typeof(WebsocketClient) != TYPE_NIL):
		# Spawn local player explicitly
		if _local_id != "":
			_ensure_player(_local_id)
	# Stash session config
	session_mode = String(payload.get("mode", session_mode if session_mode != "" else "coop"))
	session_target = int(payload.get("target", session_target if session_target > 0 else 100))
	session_seed = int(payload.get("seed", session_seed if session_seed > 0 else OS.get_unix_time()))

func _on_message(msg):
	var t = String(msg.get("type", ""))
	if t == "state":
		var pid = String(msg.get("id", ""))
		if pid == "":
			return
		var pos = Vector2(msg.get("x", 0.0), msg.get("y", 0.0))
		var p = _players.get(pid, null)
		if p != null and is_instance_valid(p):
			if p.has_method("apply_remote_state"):
				p.call("apply_remote_state", pos)

func _ensure_player(pid):
	if _players.has(pid) and is_instance_valid(_players[pid]):
		return
	var cont = _get_player_container()
	if cont == null:
		push_warning("MultiplayerManager: Node 'PlayerContainer' not found in the current scene.")
		return
	var scene = load(player_scene_path)
	if scene == null:
		push_error("MultiplayerManager: player scene missing at: " + player_scene_path)
		return
	var inst = scene.instance()
	inst.name = "Player_" + pid
	cont.add_child(inst)
	var local = (pid == _local_id)
	if inst.has_method("set_is_local"):
		inst.call("set_is_local", local)
	_players[pid] = inst

func _get_player_container():
	var scene_root = get_tree().get_current_scene()
	if scene_root == null:
		return null
	var cont = scene_root.get_node_or_null("PlayerContainer")
	if cont == null:
		cont = scene_root.find_node("PlayerContainer", true, false)
	return cont

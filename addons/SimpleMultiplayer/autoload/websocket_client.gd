extends Node

signal connection_succeeded
signal connection_failed
signal disconnected
signal room_created(code)
signal room_joined(code, player_id)
signal room_state(players)
signal player_joined(player_id)
signal player_left(player_id)
signal start_game(payload)
signal message_received(msg)
signal game_event(payload)
signal match_found(code, player_id)

var url = ""
var _peer = null # WebSocketClient
var _connected = false
var _player_id = ""
var _room_code = ""

func _ready() -> void:
	var setting = null
	if ProjectSettings.has_setting("simple_multiplayer/server_url"):
		setting = ProjectSettings.get_setting("simple_multiplayer/server_url")
	if setting == null or String(setting) == "":
		url = "ws://127.0.0.1:9090"
	else:
		url = String(setting)
	_connect_to_server()
	set_process(true)

func _connect_to_server() -> void:
	_peer = WebSocketClient.new()
	var err = _peer.connect_to_url(url)
	if err != OK:
		emit_signal("connection_failed")

func is_ws_connected() -> bool:
	return _connected and _peer != null and _peer.get_connection_status() == WebSocketClient.CONNECTION_CONNECTED

func disconnect_from_server() -> void:
	if _peer != null and _peer.get_connection_status() != WebSocketClient.CONNECTION_DISCONNECTED:
		_peer.disconnect_from_host()

func _process(_delta) -> void:
	if _peer == null:
		return
	_peer.poll()
	var state = _peer.get_connection_status()
	if not _connected and state == WebSocketClient.CONNECTION_CONNECTED:
		_connected = true
		emit_signal("connection_succeeded")
	elif state == WebSocketClient.CONNECTION_DISCONNECTED and _connected:
		_connected = false
		emit_signal("disconnected")
	if _peer.get_connection_status() == WebSocketClient.CONNECTION_CONNECTED:
		while _peer.get_peer(1).get_available_packet_count() > 0:
			var pkt = _peer.get_peer(1).get_packet()
			var txt = pkt.get_string_from_utf8()
			var parsed = JSON.parse(txt)
			if parsed.error != OK:
				continue
			var msg = parsed.result
			if typeof(msg) != TYPE_DICTIONARY:
				continue
			_handle_message(msg)

func _handle_message(msg: Dictionary) -> void:
	var t: String = String(msg.get("type", ""))
	match t:
		"welcome":
			_player_id = String(msg.get("id", ""))
		"room_created":
			_room_code = String(msg.get("code", ""))
			emit_signal("room_created", _room_code)
		"room_joined":
			_room_code = String(msg.get("code", ""))
			_player_id = String(msg.get("id", _player_id))
			emit_signal("room_joined", _room_code, _player_id)
		"match_found":
			_room_code = String(msg.get("code", ""))
			_player_id = String(msg.get("id", _player_id))
			emit_signal("match_found", _room_code, _player_id)
		"room_state":
			var players = msg.get("players", [])
			emit_signal("room_state", players)
		"player_joined":
			emit_signal("player_joined", String(msg.get("id", "")))
		"player_left":
			emit_signal("player_left", String(msg.get("id", "")))
		"start_game":
			emit_signal("start_game", msg)
		"game":
			emit_signal("game_event", msg)
		"state":
			emit_signal("message_received", msg)
		_:
			emit_signal("message_received", msg)

func _send(obj) -> void:
	if not is_ws_connected():
		return
	var txt = JSON.print(obj)
	_peer.get_peer(1).put_packet(txt.to_utf8())

# API: rooms
func create_room(code: String = "") -> void:
	_send({"type": "create_room", "code": code})

func join_room(code: String) -> void:
	_send({"type": "join_room", "code": code})

func leave_room() -> void:
	_send({"type": "leave_room"})

func find_match(data: Dictionary) -> void:
	_send({"type": "find_match", "mode": data.mode})

func cancel_match() -> void:
	_send({"type": "cancel_match"})

func send_ready() -> void:
	_send({"type": "ready"})

func request_start_game(payload: Dictionary = {}) -> void:
	var msg = payload.duplicate()
	msg["type"] = "start_game"
	_send(msg)

func send_state(payload: Dictionary) -> void:
	payload["type"] = "state"
	_send(payload)

func send_game_event(event: String, data: Dictionary = {}) -> void:
	var msg = data.duplicate()
	msg["type"] = "game"
	msg["event"] = event
	if _player_id != "":
		msg["id"] = _player_id
	_send(msg)

func get_player_id() -> String:
	return _player_id

func get_room_code() -> String:
	return _room_code

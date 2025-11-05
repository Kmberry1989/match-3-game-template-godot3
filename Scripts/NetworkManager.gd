extends Node

# Emitted when the server confirms a match has been found and the game should start.
signal game_started
# Emitted when the initial WebSocket connection fails.
signal connection_failed
# Emitted when the WebSocket connection is successfully established.
signal connection_succeeded
# Emitted when the connection to the server is lost.
signal server_disconnected
# Emitted when the opponent's score is received from the server.
signal opponent_score_updated(score)
# Emitted when the server tells us we are waiting for an opponent.
signal waiting_for_opponent

var peer

func _process(_delta):
	# We must poll the peer regularly to process incoming messages.
	if peer == null:
		return
	peer.poll()
	var state = peer.get_connection_status()
	if state == WebSocketClient.CONNECTION_CONNECTED:
		while peer.get_peer(1).get_available_packet_count() > 0:
			var message = peer.get_peer(1).get_packet().get_string_from_utf8()
			var parse = JSON.parse(message)
			if parse.error == OK:
				var data = parse.result
				if typeof(data) == TYPE_DICTIONARY and data.has("type"):
					handle_server_message(data)
	elif state == WebSocketClient.CONNECTION_DISCONNECTED:
		server_disconnected_handler()

# Handles the JSON messages received from the server.
func handle_server_message(data):
	var type = data.get("type")
	if type == "game_started":
		emit_signal("game_started")
	elif type == "waiting":
		emit_signal("waiting_for_opponent")
	elif type == "opponent_disconnected":
		server_disconnected_handler()
	elif type == "score_update":
		emit_signal("opponent_score_updated", int(data.get("score", 0)))

# Connects to the given WebSocket server URL.
func connect_to_server(url):
	peer = WebSocketClient.new()
	var err = peer.connect_to_url(url)
	if err != OK:
		print("Failed to create WebSocket client.")
		emit_signal("connection_failed")
		return
	# Set a timer to check for successful connection (no inline lambdas in Godot 3).
	var t = get_tree().create_timer(0.1)
	if t:
		t.connect("timeout", self, "_on_connect_check_timeout")

func _on_connect_check_timeout():
	if peer != null and peer.get_connection_status() == WebSocketClient.CONNECTION_CONNECTED:
		emit_signal("connection_succeeded")

# Sends the player's score to the server.
func send_score_update(score):
	if peer != null and peer.get_connection_status() == WebSocketClient.CONNECTION_CONNECTED:
		var payload = {
			"type": "score_update",
			"score": score
		}
		var txt = JSON.print(payload)
		peer.get_peer(1).put_packet(txt.to_utf8())

# Handles disconnection from the server.
func server_disconnected_handler():
	if peer != null:
		peer.disconnect_from_host()
		peer = null
		print("Disconnected from server.")
		emit_signal("server_disconnected")

func _exit_tree():
	if peer != null:
		peer.disconnect_from_host()
		peer = null

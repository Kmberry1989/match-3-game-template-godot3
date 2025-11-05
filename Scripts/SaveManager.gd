extends Node

const SAVE_PATH = "user://player.json"

func has_player() -> bool:
	var f = File.new()
	return f.file_exists(SAVE_PATH)

func load_player() -> Dictionary:
	if not has_player():
		return {}
	var f = File.new()
	if f.open(SAVE_PATH, File.READ) != OK:
		return {}
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse(text)
	if parsed.error == OK and typeof(parsed.result) == TYPE_DICTIONARY:
		return parsed.result
	return {}

func save_player(data: Dictionary) -> bool:
	var f = File.new()
	if f.open(SAVE_PATH, File.WRITE) != OK:
		return false
	f.store_string(JSON.print(data))
	f.close()
	return true

# Optional lightweight localStorage helpers for Web (HTML5)
func web_save_json(key: String, data) -> void:
	if OS.has_feature("HTML5"):
		var s = JSON.print(data)
		# JavaScript API is only available in HTML5 export
		JavaScript.eval("localStorage.setItem(" + JSON.print(key) + "," + JSON.print(s) + ")", true)

func web_load_json(key: String, default_val = {}):
	if OS.has_feature("HTML5"):
		var s = JavaScript.eval("localStorage.getItem(" + JSON.print(key) + ")", true)
		if s != null:
			var parsed = JSON.parse(str(s))
			if parsed.error == OK:
				return parsed.result
	return default_val

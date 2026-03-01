extends Control

signal finished(result)

onready var AudioManager = get_node_or_null("/root/AudioManager")

const GAME_ID = "memory_pairs"
const SUCCESS_REWARD = {
	"coins": 30,
	"xp": 80,
	"pending_bonus": {"xp_multiplier": {"mult": 2, "matches": 1}}
}

const CARD_TEXTURES := [
	"res://Assets/Dots/kyleavatar.png",
	"res://Assets/Dots/maiaavatar.png",
	"res://Assets/Dots/vickieavatar.png",
	"res://Assets/BonusSlot/symbol_coin.png",
	"res://Assets/BonusSlot/symbol_xp.png",
	"res://Assets/BonusSlot/symbol_wildcard.png"
]

var _done: bool = false
var _interactions_locked: bool = true
var _hint_cooldown: bool = false

var _panel: Panel = null
var _grid: GridContainer = null
var _status_label: Label = null
var _hint_button: Button = null
var _skip_button: Button = null

var _cards: Array = []
var _first_pick: Button = null
var _second_pick: Button = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_spawn_cards()
	_start_preview_phase()

func _notification(what):
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_layout_panel_for_viewport()
		_layout_card_sizes()

func _build_ui() -> void:
	var dimmer := ColorRect.new()
	dimmer.anchor_right = 1.0
	dimmer.anchor_bottom = 1.0
	dimmer.color = Color(0, 0, 0, 0.65)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	_panel = Panel.new()
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_layout_panel_for_viewport()

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.11, 0.15, 0.22, 0.96)
	panel_style.corner_radius_top_left = 18
	panel_style.corner_radius_top_right = 18
	panel_style.corner_radius_bottom_left = 18
	panel_style.corner_radius_bottom_right = 18
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(1, 1, 1, 0.2)
	_panel.add_stylebox_override("panel", panel_style)

	var root := VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.margin_left = 18
	root.margin_top = 18
	root.margin_right = -18
	root.margin_bottom = -18
	root.add_constant_override("separation", 10)
	_panel.add_child(root)

	var title := Label.new()
	title.text = "Memory Pair Bonus"
	title.align = Label.ALIGN_CENTER
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Find all matching pairs. No timer, take your time."
	subtitle.align = Label.ALIGN_CENTER
	subtitle.autowrap = true
	root.add_child(subtitle)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_constant_override("hseparation", 10)
	_grid.add_constant_override("vseparation", 10)
	root.add_child(_grid)

	_status_label = Label.new()
	_status_label.text = "Previewing cards..."
	_status_label.align = Label.ALIGN_CENTER
	_status_label.autowrap = true
	root.add_child(_status_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGN_CENTER
	actions.add_constant_override("separation", 18)
	root.add_child(actions)

	_hint_button = Button.new()
	_hint_button.text = "Hint"
	_hint_button.rect_min_size = Vector2(150, 52)
	_hint_button.connect("pressed", self, "_on_hint_pressed")
	actions.add_child(_hint_button)

	_skip_button = Button.new()
	_skip_button.text = "Skip"
	_skip_button.rect_min_size = Vector2(150, 52)
	_skip_button.connect("pressed", self, "_on_skip_pressed")
	actions.add_child(_skip_button)

func _layout_panel_for_viewport() -> void:
	if _panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var panel_w := clamp(vp.x - 26.0, 420.0, 920.0)
	var panel_h := clamp(vp.y - 36.0, 760.0, 1320.0)
	_panel.margin_left = -panel_w * 0.5
	_panel.margin_right = panel_w * 0.5
	_panel.margin_top = -panel_h * 0.5
	_panel.margin_bottom = panel_h * 0.5

func _spawn_cards() -> void:
	_cards.clear()
	for child in _grid.get_children():
		child.queue_free()

	var deck: Array = []
	for pair_id in range(CARD_TEXTURES.size()):
		deck.append(pair_id)
		deck.append(pair_id)
	deck.shuffle()

	for pair_id in deck:
		var card := _create_card_button(pair_id)
		_cards.append(card)
		_grid.add_child(card)

	_layout_card_sizes()

func _layout_card_sizes() -> void:
	if _grid == null:
		return
	var panel_w: float = abs(_panel.margin_right - _panel.margin_left)
	var card_w: float = clamp((panel_w - 140.0) / 3.0, 96.0, 152.0)
	var card_h: float = card_w + 18.0
	for card in _cards:
		if is_instance_valid(card):
			card.rect_min_size = Vector2(card_w, card_h)

func _create_card_button(pair_id: int) -> Button:
	var btn := Button.new()
	btn.text = "?"
	btn.clip_text = true
	btn.align = Button.ALIGN_CENTER
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.set_meta("pair_id", pair_id)
	btn.set_meta("matched", false)
	btn.set_meta("face_up", false)

	var front := TextureRect.new()
	front.name = "Front"
	front.anchor_left = 0.0
	front.anchor_top = 0.0
	front.anchor_right = 1.0
	front.anchor_bottom = 1.0
	front.margin_left = 8
	front.margin_top = 8
	front.margin_right = -8
	front.margin_bottom = -8
	front.expand = true
	front.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex_path: String = CARD_TEXTURES[pair_id]
	if ResourceLoader.exists(tex_path):
		front.texture = load(tex_path)
	btn.add_child(front)

	var back := ColorRect.new()
	back.name = "Back"
	back.anchor_right = 1.0
	back.anchor_bottom = 1.0
	back.color = Color(0.2, 0.24, 0.34, 0.96)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(back)

	var q := Label.new()
	q.name = "BackLabel"
	q.text = "?"
	q.align = Label.ALIGN_CENTER
	q.valign = Label.VALIGN_CENTER
	q.anchor_right = 1.0
	q.anchor_bottom = 1.0
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(q)

	_set_card_face(btn, false)
	btn.connect("pressed", self, "_on_card_pressed", [btn])
	return btn

func _start_preview_phase() -> void:
	for card in _cards:
		_set_card_face(card, true)
	_status_label.text = "Memorize the card positions..."
	yield(get_tree().create_timer(2.0), "timeout")
	for card in _cards:
		if not _is_card_matched(card):
			_set_card_face(card, false)
	_interactions_locked = false
	_status_label.text = "Find all 6 pairs."

func _on_card_pressed(card: Button) -> void:
	if _done or _interactions_locked or card == null:
		return
	if _is_card_matched(card) or _is_card_face_up(card):
		return
	_set_card_face(card, true)
	if AudioManager != null:
		AudioManager.play_sound("ui_click")

	if _first_pick == null:
		_first_pick = card
		return

	_second_pick = card
	_interactions_locked = true

	if _pair_id(_first_pick) == _pair_id(_second_pick):
		_set_card_matched(_first_pick, true)
		_set_card_matched(_second_pick, true)
		_first_pick = null
		_second_pick = null
		_interactions_locked = false
		_status_label.text = "Nice match."
		if AudioManager != null:
			AudioManager.play_sound("match_chime")
		_check_complete()
		return

	_status_label.text = "No match. Try again."
	if AudioManager != null:
		AudioManager.play_sound("slot_fail")
	yield(get_tree().create_timer(0.7), "timeout")
	if _first_pick != null and not _is_card_matched(_first_pick):
		_set_card_face(_first_pick, false)
	if _second_pick != null and not _is_card_matched(_second_pick):
		_set_card_face(_second_pick, false)
	_first_pick = null
	_second_pick = null
	_interactions_locked = false

func _check_complete() -> void:
	for card in _cards:
		if not _is_card_matched(card):
			return
	_complete_game()

func _complete_game() -> void:
	if _done:
		return
	_interactions_locked = true
	_status_label.text = "All pairs found! Reward granted."
	if AudioManager != null:
		AudioManager.play_sound("slot_win")
	yield(get_tree().create_timer(0.8), "timeout")
	_finish_with_payload({
		"game_id": GAME_ID,
		"status": "completed",
		"skipped": false,
		"reward": SUCCESS_REWARD.duplicate(true)
	})

func _on_hint_pressed() -> void:
	if _done or _interactions_locked or _hint_cooldown:
		return
	var pair := _find_unmatched_pair()
	if pair.size() < 2:
		_status_label.text = "No hint available right now."
		return
	_hint_cooldown = true
	_hint_button.disabled = true
	_status_label.text = "Hint shown for one pair."
	var a: Button = pair[0]
	var b: Button = pair[1]
	var was_a_face_up := _is_card_face_up(a)
	var was_b_face_up := _is_card_face_up(b)
	_set_card_face(a, true)
	_set_card_face(b, true)
	yield(get_tree().create_timer(1.0), "timeout")
	if not _done and not _is_card_matched(a) and not was_a_face_up and a != _first_pick and a != _second_pick:
		_set_card_face(a, false)
	if not _done and not _is_card_matched(b) and not was_b_face_up and b != _first_pick and b != _second_pick:
		_set_card_face(b, false)
	yield(get_tree().create_timer(4.0), "timeout")
	_hint_cooldown = false
	if _hint_button != null and is_instance_valid(_hint_button):
		_hint_button.disabled = false
		_hint_button.text = "Hint"

func _find_unmatched_pair() -> Array:
	var grouped := {}
	for card in _cards:
		if card == null or _is_card_matched(card):
			continue
		var pid: int = _pair_id(card)
		if not grouped.has(pid):
			grouped[pid] = []
		grouped[pid].append(card)
	for pid in grouped.keys():
		var arr: Array = grouped[pid]
		if arr.size() >= 2:
			arr.shuffle()
			return [arr[0], arr[1]]
	return []

func _set_card_face(card: Button, face_up: bool) -> void:
	if card == null:
		return
	card.set_meta("face_up", face_up)
	var front: TextureRect = card.get_node_or_null("Front")
	var back: ColorRect = card.get_node_or_null("Back")
	if front != null:
		front.visible = face_up
	if back != null:
		back.visible = not face_up
	if face_up:
		card.text = ""
	else:
		card.text = "?"

func _set_card_matched(card: Button, matched: bool) -> void:
	if card == null:
		return
	card.set_meta("matched", matched)
	card.disabled = matched
	if matched:
		card.modulate = Color(1, 1, 1, 0.78)

func _is_card_matched(card: Button) -> bool:
	return bool(card.get_meta("matched", false))

func _is_card_face_up(card: Button) -> bool:
	return bool(card.get_meta("face_up", false))

func _pair_id(card: Button) -> int:
	return int(card.get_meta("pair_id", -1))

func _on_skip_pressed() -> void:
	if _done:
		return
	_finish_with_payload({
		"game_id": GAME_ID,
		"status": "skipped",
		"skipped": true
	})

func _finish_with_payload(payload: Dictionary) -> void:
	if _done:
		return
	_done = true
	emit_signal("finished", payload)
	queue_free()

extends Control

signal finished(result)

onready var AudioManager = get_node_or_null("/root/AudioManager")

const GAME_ID = "shelf_sort"
const CARD_SIZE = Vector2(100, 114)
const SUCCESS_REWARD = {
	"coins": 30,
	"xp": 80,
	"pending_bonus": {"clear_rows": 1}
}

const CATEGORY_CONFIG := [
	{
		"id": "tools",
		"name": "Tools",
		"color": Color(0.95, 0.78, 0.27, 1.0),
		"textures": [
			"res://Assets/Visuals/anvil.png",
			"res://Assets/Visuals/ingredient_key.png",
			"res://Assets/Visuals/coin.png"
		]
	},
	{
		"id": "avatars",
		"name": "Avatars",
		"color": Color(0.45, 0.74, 0.96, 1.0),
		"textures": [
			"res://Assets/Dots/kyleavatar.png",
			"res://Assets/Dots/maiaavatar.png",
			"res://Assets/Dots/vickieavatar.png"
		]
	},
	{
		"id": "powers",
		"name": "Powerups",
		"color": Color(0.85, 0.55, 0.96, 1.0),
		"textures": [
			"res://Assets/BonusSlot/symbol_coin.png",
			"res://Assets/BonusSlot/symbol_xp.png",
			"res://Assets/BonusSlot/symbol_wildcard.png"
		]
	}
]

var _done: bool = false
var _interactions_locked: bool = false

var _panel: Panel = null
var _status_label: Label = null
var _hint_button: Button = null
var _skip_button: Button = null
var _bank_panel: Panel = null
var _card_layer: Control = null
var _shelf_panels: Array = []

var _cards: Array = []
var _bank_cards: Array = []
var _shelf_cards: Array = [[], [], []]

var _drag_card: Control = null
var _drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_spawn_cards()
	call_deferred("_layout_cards", false)

func _notification(what):
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_layout_panel_for_viewport()
		_layout_cards(false)

func _input(event: InputEvent) -> void:
	if _drag_card == null:
		return
	if event is InputEventMouseMotion:
		_drag_card.rect_global_position = event.global_position - _drag_offset
		return
	if event is InputEventScreenDrag:
		_drag_card.rect_global_position = event.position - _drag_offset
		return
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed:
		_finish_drag(event.global_position)
		return
	if event is InputEventScreenTouch and not event.pressed:
		_finish_drag(event.position)

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
	panel_style.bg_color = Color(0.1, 0.14, 0.2, 0.96)
	panel_style.corner_radius_top_left = 18
	panel_style.corner_radius_top_right = 18
	panel_style.corner_radius_bottom_left = 18
	panel_style.corner_radius_bottom_right = 18
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(1, 1, 1, 0.22)
	_panel.add_stylebox_override("panel", panel_style)

	var root := VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.margin_left = 18
	root.margin_top = 18
	root.margin_right = -18
	root.margin_bottom = -18
	root.add_constant_override("separation", 12)
	_panel.add_child(root)

	var title := Label.new()
	title.text = "Shelf Sort Bonus"
	title.align = Label.ALIGN_CENTER
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Drag cards onto shelves so each shelf has exactly one category."
	subtitle.align = Label.ALIGN_CENTER
	subtitle.autowrap = true
	root.add_child(subtitle)

	var shelf_row := HBoxContainer.new()
	shelf_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelf_row.add_constant_override("separation", 10)
	root.add_child(shelf_row)

	for i in range(3):
		var shelf_col := VBoxContainer.new()
		shelf_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shelf_col.add_constant_override("separation", 4)
		shelf_row.add_child(shelf_col)

		var shelf_label := Label.new()
		shelf_label.text = "Shelf %d" % (i + 1)
		shelf_label.align = Label.ALIGN_CENTER
		shelf_col.add_child(shelf_label)

		var shelf_panel := Panel.new()
		shelf_panel.rect_min_size = Vector2(0, 190)
		shelf_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shelf_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shelf_style := StyleBoxFlat.new()
		shelf_style.bg_color = Color(0.12, 0.18, 0.26, 0.88)
		shelf_style.corner_radius_top_left = 12
		shelf_style.corner_radius_top_right = 12
		shelf_style.corner_radius_bottom_left = 12
		shelf_style.corner_radius_bottom_right = 12
		shelf_style.border_width_left = 2
		shelf_style.border_width_right = 2
		shelf_style.border_width_top = 2
		shelf_style.border_width_bottom = 2
		shelf_style.border_color = Color(1, 1, 1, 0.16)
		shelf_panel.add_stylebox_override("panel", shelf_style)
		shelf_col.add_child(shelf_panel)
		_shelf_panels.append(shelf_panel)

	_bank_panel = Panel.new()
	_bank_panel.rect_min_size = Vector2(0, 370)
	_bank_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bank_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bank_style := StyleBoxFlat.new()
	bank_style.bg_color = Color(0.08, 0.11, 0.16, 0.95)
	bank_style.corner_radius_top_left = 12
	bank_style.corner_radius_top_right = 12
	bank_style.corner_radius_bottom_left = 12
	bank_style.corner_radius_bottom_right = 12
	bank_style.border_width_left = 2
	bank_style.border_width_right = 2
	bank_style.border_width_top = 2
	bank_style.border_width_bottom = 2
	bank_style.border_color = Color(1, 1, 1, 0.12)
	_bank_panel.add_stylebox_override("panel", bank_style)
	root.add_child(_bank_panel)

	_status_label = Label.new()
	_status_label.text = "Need help? Use Hint to highlight a good move."
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

	_card_layer = Control.new()
	_card_layer.name = "CardLayer"
	_card_layer.anchor_right = 1.0
	_card_layer.anchor_bottom = 1.0
	_card_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_card_layer)
	_card_layer.raise()

func _layout_panel_for_viewport() -> void:
	if _panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var panel_w := clamp(vp.x - 26.0, 420.0, 980.0)
	var panel_h := clamp(vp.y - 36.0, 760.0, 1400.0)
	_panel.margin_left = -panel_w * 0.5
	_panel.margin_right = panel_w * 0.5
	_panel.margin_top = -panel_h * 0.5
	_panel.margin_bottom = panel_h * 0.5

func _spawn_cards() -> void:
	_cards.clear()
	_bank_cards.clear()
	_shelf_cards = [[], [], []]

	for category_index in range(CATEGORY_CONFIG.size()):
		var cat = CATEGORY_CONFIG[category_index]
		var paths: Array = cat.get("textures", [])
		for tex_path in paths:
			var card := _create_card(category_index, String(cat.get("name", "")), String(tex_path), cat.get("color", Color(1, 1, 1)))
			_cards.append(card)
			_bank_cards.append(card)
			_card_layer.add_child(card)

	_bank_cards.shuffle()

func _create_card(category_index: int, category_name: String, tex_path: String, accent: Color) -> Control:
	var card := Panel.new()
	card.rect_size = CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.set_meta("category", category_index)
	card.set_meta("category_name", category_name)
	card.set_meta("accent", accent)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.16, 0.2, 0.28, 1.0)
	card_style.corner_radius_top_left = 12
	card_style.corner_radius_top_right = 12
	card_style.corner_radius_bottom_left = 12
	card_style.corner_radius_bottom_right = 12
	card_style.border_width_left = 3
	card_style.border_width_right = 3
	card_style.border_width_top = 3
	card_style.border_width_bottom = 3
	card_style.border_color = accent
	card.add_stylebox_override("panel", card_style)

	var icon := TextureRect.new()
	icon.anchor_left = 0.0
	icon.anchor_top = 0.0
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.margin_left = 8
	icon.margin_top = 8
	icon.margin_right = -8
	icon.margin_bottom = -32
	icon.expand = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(tex_path):
		icon.texture = load(tex_path)
	card.add_child(icon)

	var tag := Label.new()
	tag.text = category_name
	tag.align = Label.ALIGN_CENTER
	tag.anchor_left = 0.0
	tag.anchor_top = 1.0
	tag.anchor_right = 1.0
	tag.anchor_bottom = 1.0
	tag.margin_left = 4
	tag.margin_top = -26
	tag.margin_right = -4
	tag.margin_bottom = -6
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(tag)

	card.connect("gui_input", self, "_on_card_gui_input", [card])
	return card

func _on_card_gui_input(event: InputEvent, card: Control) -> void:
	if _interactions_locked or _done:
		return
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		_start_drag(card, event.global_position)
		accept_event()
		return
	if event is InputEventScreenTouch and event.pressed:
		_start_drag(card, event.position)
		accept_event()

func _start_drag(card: Control, pointer: Vector2) -> void:
	if _drag_card != null or card == null:
		return
	_remove_card_from_all_collections(card)
	_drag_card = card
	card.rect_scale = Vector2.ONE
	_drag_offset = pointer - card.rect_global_position
	card.raise()

func _finish_drag(pointer: Vector2) -> void:
	if _drag_card == null:
		return
	var target_shelf: int = _find_shelf_at(pointer)
	if target_shelf >= 0 and _shelf_cards[target_shelf].size() < 3:
		_shelf_cards[target_shelf].append(_drag_card)
	else:
		_bank_cards.append(_drag_card)
	_drag_card = null
	_layout_cards(true)
	_check_completion()

func _find_shelf_at(pointer: Vector2) -> int:
	for i in range(_shelf_panels.size()):
		var shelf: Control = _shelf_panels[i]
		var rect := Rect2(shelf.rect_global_position, shelf.rect_size)
		if rect.has_point(pointer):
			return i
	return -1

func _remove_card_from_all_collections(card: Control) -> void:
	while _bank_cards.has(card):
		_bank_cards.erase(card)
	for shelf_cards in _shelf_cards:
		while shelf_cards.has(card):
			shelf_cards.erase(card)

func _layout_cards(animated: bool = true) -> void:
	if _bank_panel == null:
		return
	_layout_shelf_cards(animated)
	_layout_bank_cards(animated)

func _layout_shelf_cards(animated: bool) -> void:
	for i in range(_shelf_panels.size()):
		var shelf: Control = _shelf_panels[i]
		var cards: Array = _shelf_cards[i]
		if cards.size() == 0:
			continue
		var mini_scale := Vector2(0.56, 0.56)
		var mini_h: float = CARD_SIZE.y * mini_scale.y
		var spacing: float = 6.0
		var total_h: float = cards.size() * mini_h + max(cards.size() - 1, 0) * spacing
		var x: float = shelf.rect_global_position.x + (shelf.rect_size.x - CARD_SIZE.x * mini_scale.x) * 0.5
		var start_y: float = shelf.rect_global_position.y + (shelf.rect_size.y - total_h) * 0.5
		for idx in range(cards.size()):
			var card: Control = cards[idx]
			if card == _drag_card:
				continue
			var target := Vector2(x, start_y + idx * (mini_h + spacing))
			_move_card(card, target, animated, mini_scale)

func _layout_bank_cards(animated: bool) -> void:
	var columns := 3
	var spacing := 10.0
	var origin := _bank_panel.rect_global_position + Vector2(14, 14)
	for idx in range(_bank_cards.size()):
		var card: Control = _bank_cards[idx]
		if card == _drag_card:
			continue
		var row: int = int(idx / columns)
		var col: int = idx % columns
		var target := origin + Vector2(col * (CARD_SIZE.x + spacing), row * (CARD_SIZE.y + spacing))
		_move_card(card, target, animated, Vector2.ONE)

func _move_card(card: Control, target_global: Vector2, animated: bool, target_scale: Vector2) -> void:
	if card == null:
		return
	if animated:
		var tw = create_tween()
		tw.tween_property(card, "rect_global_position", target_global, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(card, "rect_scale", target_scale, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		card.rect_global_position = target_global
		card.rect_scale = target_scale

func _check_completion() -> void:
	var shelf_categories: Array = []
	for shelf_cards in _shelf_cards:
		if shelf_cards.size() != 3:
			return
		var first_cat: int = int(shelf_cards[0].get_meta("category", -1))
		if first_cat < 0:
			return
		for card in shelf_cards:
			if int(card.get_meta("category", -1)) != first_cat:
				return
		shelf_categories.append(first_cat)
	var uniques := []
	for cat in shelf_categories:
		if not uniques.has(cat):
			uniques.append(cat)
	if uniques.size() != 3:
		return
	_complete_game()

func _complete_game() -> void:
	if _done:
		return
	_interactions_locked = true
	_status_label.text = "Great sorting! Reward granted."
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
	if _interactions_locked or _done:
		return
	var pick := _find_hint_candidate()
	if pick.empty():
		_status_label.text = "Try grouping matching categories on one shelf."
		return
	var card: Control = pick.get("card", null)
	var shelf_idx: int = int(pick.get("shelf", -1))
	if card == null or shelf_idx < 0 or shelf_idx >= _shelf_panels.size():
		return
	_status_label.text = "Hint: place this card on Shelf %d." % (shelf_idx + 1)
	_flash_control(card, Color(1.0, 1.0, 1.0, 1.0))
	_flash_control(_shelf_panels[shelf_idx], Color(0.7, 1.0, 0.7, 1.0))

func _find_hint_candidate() -> Dictionary:
	var all_cards: Array = _bank_cards.duplicate()
	for shelf_cards in _shelf_cards:
		for card in shelf_cards:
			all_cards.append(card)
	for card in all_cards:
		if card == null:
			continue
		var cat: int = int(card.get_meta("category", -1))
		if cat < 0:
			continue
		var current_score: int = _best_shelf_score_for_category(cat, _current_shelf_for_card(card))
		var best_shelf := -1
		var best_score := -999
		for i in range(_shelf_cards.size()):
			if _shelf_cards[i].size() >= 3 and not _shelf_cards[i].has(card):
				continue
			var score := _best_shelf_score_for_category(cat, i)
			if score > best_score:
				best_score = score
				best_shelf = i
		if best_shelf >= 0 and best_score > current_score:
			return {"card": card, "shelf": best_shelf}
	return {}

func _best_shelf_score_for_category(category: int, shelf_idx: int) -> int:
	if shelf_idx < 0 or shelf_idx >= _shelf_cards.size():
		return -999
	var shelf_cards: Array = _shelf_cards[shelf_idx]
	if shelf_cards.size() >= 3:
		return -999
	var same := 0
	var other := 0
	for card in shelf_cards:
		if int(card.get_meta("category", -1)) == category:
			same += 1
		else:
			other += 1
	return same * 3 - other

func _current_shelf_for_card(card: Control) -> int:
	for i in range(_shelf_cards.size()):
		if _shelf_cards[i].has(card):
			return i
	return -1

func _flash_control(ctrl: CanvasItem, tint: Color) -> void:
	if ctrl == null:
		return
	var original: Color = ctrl.modulate
	var tw = create_tween()
	tw.tween_property(ctrl, "modulate", tint, 0.14)
	tw.tween_property(ctrl, "modulate", original, 0.22)

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

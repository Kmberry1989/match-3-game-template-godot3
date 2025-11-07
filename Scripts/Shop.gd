extends Control

onready var back_button: Button = Button.new()
onready var coins_label: Label = Label.new()
onready var PlayerManager = get_node_or_null("/root/PlayerManager")
onready var AudioManager = get_node_or_null("/root/AudioManager")

var _cards_row: HBoxContainer
var _scroll: ScrollContainer
var _prev_button: Button
var _next_button: Button
var _dots: HBoxContainer
var _snap_timer: Timer
var _is_animating: bool = false
var _frame_ids: Array = []
var _confirm: ConfirmationDialog = null
var _pending_frame_id: String = ""
var _pending_price: int = 0

const BADGE_H = 24
const CARD_W = 220.0
const CARD_SEP = 10.0
const THUMB_H = 320.0 # normalized preview area height

var frames_catalog = {
	"frame_2": {"price": 100, "display": "res://Assets/Visuals/Avatar Frames/avatar_frame_2.png"},
	"frame_3": {"price": 150, "display": "res://Assets/Visuals/Avatar Frames/avatar_frame_3.png"},
	"frame_4": {"price": 200, "display": "res://Assets/Visuals/Avatar Frames/avatar_frame_4.png"},
	"frame_5": {"price": 220, "display": "res://Assets/Visuals/Avatar Frames/avatar_frame_5.png"},
	"frame_6": {"price": 240, "display": "res://Assets/Visuals/Avatar Frames/avatar_frame_6.png"},
	"frame_7": {"price": 260, "display": "res://Assets/Visuals/Avatar Frames/avatar_frame_7.png"},
	"frame_8": {"price": 280, "display": "res://Assets/Visuals/Avatar Frames/avatar_frame_8.png"},
	"frame_9": {"price": 300, "display": "res://Assets/Visuals/Avatar Frames/avatar_frame_9.png"},
	"frame_10": {"price": 350, "display": "res://Assets/Visuals/Avatar Frames/avatar_frame_10.png"},
	"frame_11": {"price": 400, "display": "res://Assets/Visuals/Avatar Frames/avatar_frame_11.png"}
}

func _ready():
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	margin_left = 0
	margin_top = 0
	margin_right = 0
	margin_bottom = 0

	_load_dynamic_frames()
	_build_ui()

	if typeof(PlayerManager) == TYPE_OBJECT and PlayerManager != null:
		PlayerManager.connect("coins_changed", self, "_on_coins_changed")
		PlayerManager.connect("frame_changed", self, "_on_frame_changed")

	_refresh()
	call_deferred("_post_build_layout")

func _build_ui():
	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0
	vbox.anchor_top = 0
	vbox.anchor_right = 1
	vbox.anchor_bottom = 1
	vbox.margin_left = 0
	vbox.margin_top = 0
	vbox.margin_right = 0
	vbox.margin_bottom = 0
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGN_CENTER
	vbox.add_constant_override("separation", 12)
	add_child(vbox)

	var title = Label.new()
	title.text = "Avatar Frame Shop"
	title.align = Label.ALIGN_CENTER
	vbox.add_child(title)

	coins_label.align = Label.ALIGN_CENTER
	vbox.add_child(coins_label)

	var nav = HBoxContainer.new()
	nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_constant_override("separation", 6)
	vbox.add_child(nav)

	_prev_button = Button.new()
	_prev_button.text = "\u25C0"
	_prev_button.rect_min_size = Vector2(40, 40)
	_prev_button.connect("pressed", self, "_on_prev_pressed")
	nav.add_child(_prev_button)

	_scroll = ScrollContainer.new()
	# Godot 3: no scroll_mode enums; manage bars directly
	var _hbar = _scroll.get_h_scrollbar()
	if _hbar:
		_hbar.show()
	var _vbar = _scroll.get_v_scrollbar()
	if _vbar:
		_vbar.hide()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(_scroll)

	var bar = _scroll.get_h_scrollbar()
	if bar:
		bar.connect("value_changed", self, "_on_scroll_changed")

	_next_button = Button.new()
	_next_button.text = "\u25B6"
	_next_button.rect_min_size = Vector2(40, 40)
	_next_button.connect("pressed", self, "_on_next_pressed")
	nav.add_child(_next_button)

	_cards_row = HBoxContainer.new()
	_cards_row.add_constant_override("separation", 10)
	_cards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_cards_row)

	_frame_ids = _get_sorted_frame_ids()
	for frame_id in _frame_ids:
		var card = _make_frame_card(frame_id)
		_cards_row.add_child(card)

	_dots = HBoxContainer.new()
	_dots.add_constant_override("separation", 6)
	_dots.alignment = BoxContainer.ALIGN_CENTER
	vbox.add_child(_dots)

	# Purchase confirmation dialog
	_confirm = ConfirmationDialog.new()
	_confirm.name = "ConfirmPurchase"
	_confirm.window_title = "Confirm Purchase"
	if _confirm.has_method("get_ok"):
		_confirm.get_ok().text = "Buy"
	if _confirm.has_method("get_cancel"):
		_confirm.get_cancel().text = "Cancel"
	_confirm.connect("confirmed", self, "_on_purchase_confirmed")
	add_child(_confirm)

	back_button.text = "Back"
	back_button.connect("pressed", self, "_on_back_pressed")
	vbox.add_child(back_button)

func _post_build_layout():
	if not is_inside_tree():
		return
	_update_card_widths()
	_rebuild_dots()
	_update_pager_by_scroll()

# Scan res://Assets/Visuals/Avatar Frames for avatar_*.png and add frames not already listed
func _load_dynamic_frames() -> void:
	var root = "res://Assets/Visuals/Avatar Frames"
	var dir = Directory.new()
	if dir.open(root) != OK:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.to_lower().ends_with(".png"):
			if fname.begins_with("avatar_"):
				if fname == "avatar_frame_2.png":
					fname = dir.get_next()
					continue
				var id = fname.get_basename().replace("avatar_", "")
				if not frames_catalog.has(id):
					var price = 250
					var m = RegEx.new()
					m.compile(".*?(\\d+)")
					var res = m.search(id)
					if res != null:
						var n = int(res.get_string(1))
						price = max(150, 100 + n * 20)
					frames_catalog[id] = {"price": price, "display": root + "/" + fname}
		fname = dir.get_next()
	dir.list_dir_end()


func _make_frame_card(frame_id: String) -> Control:
	var data = frames_catalog[frame_id]
	var price: int = data["price"]
	var display_path: String = String(data["display"]) # full res:// path

	var panel = PanelContainer.new()
	panel.rect_min_size = Vector2(400, 480)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vb = VBoxContainer.new()
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_constant_override("separation", 6)
	vb.alignment = BoxContainer.ALIGN_CENTER
	panel.add_child(vb)

	var thumb = Control.new()
	# Reserved area for preview; we will not upscale above native texture size
	thumb.rect_min_size = Vector2(0, THUMB_H)
	thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(thumb)

	var cc = CenterContainer.new()
	cc.anchor_left = 0
	cc.anchor_top = 0
	cc.anchor_right = 1
	cc.anchor_bottom = 1
	cc.margin_left = 0
	cc.margin_top = 0
	cc.margin_right = 0
	cc.margin_bottom = 0
	thumb.add_child(cc)

	var ttex = load(display_path)
	var tex = TextureRect.new()
	tex.texture = ttex
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Compute a display size that never exceeds the native texture size; downscale if taller than THUMB_H
	var nat_w = 0.0
	var nat_h = 0.0
	if ttex != null:
		if ttex.has_method("get_width"):
			nat_w = float(ttex.get_width())
		if ttex.has_method("get_height"):
			nat_h = float(ttex.get_height())
	var target_h = THUMB_H
	if nat_h > 0.0:
		target_h = min(THUMB_H, nat_h)
	var target_w = nat_w
	if nat_w > 0.0 and nat_h > 0.0:
		target_w = target_h * (nat_w / nat_h)
		# Never exceed native width
		target_w = min(target_w, nat_w)
	tex.expand = true
	if target_w > 0.0 and target_h > 0.0:
		tex.rect_min_size = Vector2(target_w, target_h)
		tex.rect_size = tex.rect_min_size
	tex.hint_tooltip = ""
	cc.add_child(tex)

	var badge_bg = ColorRect.new()
	badge_bg.color = Color(0, 0, 0, 0.6)
	badge_bg.rect_min_size = Vector2(0, BADGE_H)
	vb.add_child(badge_bg)

	var badge = Label.new()
	badge.align = Label.ALIGN_CENTER
	badge.valign = Label.VALIGN_CENTER
	badge.rect_min_size = Vector2(0, BADGE_H)
	badge.anchor_left = 0
	badge.anchor_top = 0
	badge.anchor_right = 1
	badge.anchor_bottom = 1
	badge.margin_left = 0
	badge.margin_top = 0
	badge.margin_right = 0
	badge.margin_bottom = 0
	badge_bg.add_child(badge)

	var name_label = Label.new()
	var display_name = frame_id.replace("_", " ")
	if display_name.length() > 0:
		display_name = display_name.substr(0,1).to_upper() + display_name.substr(1)
	name_label.text = display_name
	name_label.align = Label.ALIGN_CENTER
	vb.add_child(name_label)

	var price_label = Label.new()
	price_label.text = "Price: %d" % price
	price_label.align = Label.ALIGN_CENTER
	vb.add_child(price_label)

	var btn = Button.new()
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(btn)

	var owned: bool = false
	if typeof(PlayerManager) == TYPE_OBJECT and PlayerManager != null:
		owned = frame_id in (PlayerManager.player_data.get("unlocks", {}).get("frames", []) as Array)
	if owned and typeof(PlayerManager) == TYPE_OBJECT:
		if PlayerManager.get_current_frame() == frame_id:
			btn.text = "Equipped"
			btn.disabled = true
			badge.text = "Equipped"
			badge_bg.color = Color(0.2, 0.6, 1.0, 0.7)
		else:
			btn.text = "Equip"
			btn.disabled = false
			btn.connect("pressed", self, "_on_card_button_pressed", [frame_id, price, true])
			badge.text = "Owned"
			badge_bg.color = Color(0.2, 0.8, 0.2, 0.7)
	else:
		btn.text = "Buy"
		if typeof(PlayerManager) == TYPE_OBJECT and PlayerManager != null:
			btn.disabled = not PlayerManager.can_spend(price)
			btn.connect("pressed", self, "_on_card_button_pressed", [frame_id, price, false])
		badge.text = "Price: %d" % price
		badge_bg.color = Color(1.0, 0.84, 0.0, 0.7)

	return panel

func _refresh():
	if typeof(PlayerManager) == TYPE_OBJECT and PlayerManager != null:
		coins_label.text = "Coins: %d" % PlayerManager.get_coins()
	else:
		coins_label.text = ""
	_frame_ids = _get_sorted_frame_ids()
	if is_instance_valid(_cards_row):
		for c in _cards_row.get_children():
			c.queue_free()
		for frame_id in _frame_ids:
			_cards_row.add_child(_make_frame_card(frame_id))
	_rebuild_dots()
	_update_pager_by_scroll()

func _get_sorted_frame_ids() -> Array:
	var ids: Array = []
	if typeof(PlayerManager) != TYPE_OBJECT or PlayerManager == null:
		for k in frames_catalog.keys():
			ids.append(k)
		return ids
	var owned_frames: Array = PlayerManager.player_data.get("unlocks", {}).get("frames", [])
	var equipped: String = str(PlayerManager.get_current_frame())
	var owned_list: Array = []
	var unowned_list: Array = []
	for k in frames_catalog.keys():
		if k == equipped:
			continue
		if k in owned_frames:
			owned_list.append(k)
		else:
			unowned_list.append(k)
	_sort_by_price(owned_list)
	_sort_by_price(unowned_list)
	if equipped in frames_catalog:
		ids.append(equipped)
	for a in owned_list:
		ids.append(a)
	for b in unowned_list:
		ids.append(b)
	return ids

func _sort_by_price(arr: Array) -> void:
	for i in range(arr.size()):
		var min_i = i
		for j in range(i + 1, arr.size()):
			if int(frames_catalog[arr[j]]["price"]) < int(frames_catalog[arr[min_i]]["price"]):
				min_i = j
		if min_i != i:
			var tmp = arr[i]
			arr[i] = arr[min_i]
			arr[min_i] = tmp

func _on_prev_pressed():
	_scroll_by_pages(-1)

func _on_next_pressed():
	_scroll_by_pages(1)

func _scroll_by_pages(dir: int):
	if _scroll == null:
		return
	var bar = _scroll.get_h_scrollbar()
	if bar == null:
		return
	var step = _card_step()
	var page_cards: int = int(max(1, int(floor(bar.page / step))))
	var current = int(round(bar.value / step))
	_animate_scroll_to(current + dir * page_cards)

func _on_back_pressed():
	get_tree().change_scene("res://Scenes/Menu.tscn")

func _on_coins_changed(_amt):
	_refresh()

func _on_frame_changed(_frame):
	_refresh()

func _on_scroll_changed(_v):
	if not is_inside_tree() or _scroll == null:
		return
	if _is_animating:
		return
	if _snap_timer == null:
		_snap_timer = Timer.new()
		_snap_timer.one_shot = true
		add_child(_snap_timer)
		_snap_timer.connect("timeout", self, "_snap_to_nearest")
	_snap_timer.start(0.2)
	_update_pager_by_scroll()

func _snap_to_nearest():
	if not is_inside_tree():
		return
	var bar = _scroll.get_h_scrollbar()
	if bar == null:
		return
	var step = _card_step()
	if step <= 0:
		return
	var idx = int(round(bar.value / step))
	_animate_scroll_to(idx)

func _animate_scroll_to(index: int):
	if not is_inside_tree():
		return
	var bar = _scroll.get_h_scrollbar()
	if bar == null:
		return
	var step = _card_step()
	var max_index: int = int(max(0, _frame_ids.size() - 1))
	index = int(clamp(index, 0, max_index))
	var target: float = float(clamp(index * step, 0.0, float(bar.max_value)))
	_is_animating = true
	var t = get_tree().create_tween()
	t.tween_property(bar, "value", target, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	yield(t, "finished")
	_is_animating = false
	_highlight_dot(index)

func _card_step() -> float:
	var step = CARD_W + CARD_SEP
	if is_instance_valid(_cards_row) and _cards_row.get_child_count() > 0:
		var first = _cards_row.get_child(0)
		if first is Control:
			step = float(first.rect_size.x) + CARD_SEP
			if step <= 0:
				step = CARD_W + CARD_SEP
	return step

func _rebuild_dots():
	if _dots == null:
		return
	for c in _dots.get_children():
		c.queue_free()
	for i in range(_frame_ids.size()):
		var dot = ColorRect.new()
		dot.rect_min_size = Vector2(8, 8)
		dot.color = Color(0.5, 0.5, 0.5, 0.9)
		_dots.add_child(dot)
	_update_pager_by_scroll()

func _update_pager_by_scroll():
	var bar = _scroll.get_h_scrollbar()
	if bar == null or _dots == null:
		return
	var step = _card_step()
	var idx = int(round(bar.value / step))
	_highlight_dot(idx)

func _highlight_dot(index: int):
	if _dots == null:
		return
	for i in range(_dots.get_child_count()):
		var c = _dots.get_child(i)
		if i == index:
			c.color = Color(1, 1, 1, 1)
			c.rect_min_size = Vector2(10, 10)
		else:
			c.color = Color(0.5, 0.5, 0.9, 0.9)
			c.rect_min_size = Vector2(8, 8)

func _update_card_widths():
	if not is_inside_tree():
		return
	if _scroll == null or _cards_row == null:
		return
	var avail_w: float = _scroll.rect_size.x
	var avail_h: float = _scroll.rect_size.y
	if avail_w <= 0.0 or avail_h <= 0.0:
		return
	for child in _cards_row.get_children():
		if child is Control:
			var panel = child as Control
			panel.rect_min_size = Vector2(avail_w, avail_h)

func _notification(what):
	if what == Control.NOTIFICATION_RESIZED:
		_update_card_widths()

func _on_card_button_pressed(frame_id: String, price: int, owned: bool):
	if owned:
		PlayerManager.set_current_frame(frame_id)
		_refresh()
		return
	# Ask for confirmation before purchasing
	if PlayerManager == null or not PlayerManager.can_spend(price):
		_show_toast("Not enough coins")
		return
	_pending_frame_id = frame_id
	_pending_price = price
	if _confirm != null:
		_confirm.dialog_text = "Buy this frame for %d coins?" % price
		_confirm.popup_centered_minsize(Vector2(360, 0))
	else:
		# Fallback: proceed without dialog
		_perform_purchase(frame_id, price)

func _on_purchase_confirmed():
	if _pending_frame_id == "" or _pending_price <= 0:
		return
	_perform_purchase(_pending_frame_id, _pending_price)
	_pending_frame_id = ""
	_pending_price = 0

func _perform_purchase(frame_id: String, price: int):
	if PlayerManager == null:
		return
	if not PlayerManager.can_spend(price):
		return
	if PlayerManager.spend_coins(price):
		PlayerManager.unlock_frame(frame_id)
		PlayerManager.set_current_frame(frame_id)
		if AudioManager != null:
			AudioManager.play_sound("purchase")
		_refresh()
		# Show a brief toast then return to menu
		_show_toast("New Frame Equipped!")
		yield(get_tree().create_timer(1.1), "timeout")
		get_tree().change_scene("res://Scenes/Menu.tscn")

func _show_toast(text: String) -> void:
	var root: Node = get_tree().get_current_scene()
	if root == null:
		return
	var layer: Node = root.get_node("CanvasLayer") if root.has_node("CanvasLayer") else null
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "CanvasLayer"
		root.add_child(layer)
	var toast_panel = PanelContainer.new()
	toast_panel.name = "ShopToast"
	toast_panel.modulate = Color(1,1,1,0.0)
	toast_panel.anchor_left = 0.5
	toast_panel.anchor_right = 0.5
	toast_panel.anchor_top = 0.1
	toast_panel.anchor_bottom = 0.1
	toast_panel.margin_left = -220
	toast_panel.margin_right = 220
	toast_panel.margin_top = -24
	toast_panel.margin_bottom = 24
	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGN_CENTER
	var lbl = Label.new()
	lbl.align = Label.ALIGN_CENTER
	lbl.text = text
	box.add_child(lbl)
	toast_panel.add_child(box)
	layer.add_child(toast_panel)
	var t = get_tree().create_tween()
	t.tween_property(toast_panel, "modulate:a", 1.0, 0.2)
	t.tween_interval(0.65)
	t.tween_property(toast_panel, "modulate:a", 0.0, 0.2)


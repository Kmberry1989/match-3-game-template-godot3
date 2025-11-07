extends Node

# Autoload: scales Back buttons and tabs across all scenes for better tap targets.

func _ready():
    if not get_tree().is_connected("node_added", self, "_on_node_added"):
        get_tree().connect("node_added", self, "_on_node_added")
    _apply_to_tree(get_tree().root)

func _on_node_added(n: Node) -> void:
    _apply(n)

func _apply_to_tree(root: Node) -> void:
    if root == null:
        return
    _apply(root)
    for c in root.get_children():
        _apply_to_tree(c)

func _apply(n: Node) -> void:
    if n == null:
        return
    # Enlarge Back buttons by name or label match
    if n is Button:
        var b = n as Button
        var name_lower = String(b.name).to_lower()
        var text_lower = String(b.text).to_lower()
        if name_lower.find("back") != -1 or text_lower.find("back") != -1:
            if b.rect_scale.x < 2.0 or b.rect_scale.y < 2.0:
                b.rect_scale = Vector2(2.0, 2.0)
            if b.rect_min_size.x < 180 or b.rect_min_size.y < 64:
                b.rect_min_size = Vector2(180, 64)
    # Enlarge tabs globally
    if n is TabContainer:
        var tc = n as TabContainer
        if tc.rect_scale.x < 1.4 or tc.rect_scale.y < 1.4:
            tc.rect_scale = Vector2(1.4, 1.4)


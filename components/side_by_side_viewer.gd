class_name SideBySideViewer
extends ColorRect

# --- SIGNALS ---
signal request_save_text(path: String, content: String)
signal closed

# --- NODES ---
@onready var close_btn: Button = $MarginContainer/VBoxContainer/TopBar/CloseBtn

# Left Panel
@onready var col_select_left: OptionButton = %ColSelectLeft
@onready var img_left: TextureRect = $MarginContainer/VBoxContainer/SplitView/LeftPanel/ContentContainer/ImageRect
@onready var txt_left: CodeEdit = $MarginContainer/VBoxContainer/SplitView/LeftPanel/ContentContainer/TextEdit

# Right Panel
@onready var col_select_right: OptionButton = %ColSelectRight
@onready var img_right: TextureRect = $MarginContainer/VBoxContainer/SplitView/RightPanel/ContentContainer/ImageRect
@onready var txt_right: CodeEdit = $MarginContainer/VBoxContainer/SplitView/RightPanel/ContentContainer/TextEdit

# Nav
@onready var btn_prev_row: Button = %BtnPrevRow
@onready var btn_next_row: Button = %BtnNextRow
@onready var position_label: Label = %PositionLabel

# --- ASSETS ---
const CURSOR_MAGNIFIER = preload("res://assets/magnifying_glass.svg")
const CURSOR_HOTSPOT = Vector2(21, 21)

# --- SETTINGS ---
const ZOOM_LEVEL: float = 3.0
const DRAG_THRESHOLD: float = 5.0

# --- STATE ---
var _dataset: Dictionary = {}
var _stems: Array = [] 
var _current_index: int = 0
var _columns: Array[String] = []

# Zoom/Pan State
var _dragging_left: bool = false
var _dragging_right: bool = false
var _drag_start_mouse_pos: Vector2
var _drag_start_img_pos: Vector2
var _has_dragged_significantly: bool = false

func _ready() -> void:
	hide()
	close_btn.pressed.connect(_close)
	btn_prev_row.pressed.connect(_nav_row.bind(-1))
	btn_next_row.pressed.connect(_nav_row.bind(1))
	
	# Connect Column Selectors
	col_select_left.item_selected.connect(func(_idx): _refresh_panel(true))
	col_select_right.item_selected.connect(func(_idx): _refresh_panel(false))
	
	# Connect Text Saving
	txt_left.focus_exited.connect(_save_left)
	txt_right.focus_exited.connect(_save_right)
	
	# ZOOM: Connect Input and Cursor Logic
	var left_container = img_left.get_parent()
	var right_container = img_right.get_parent()
	
	left_container.gui_input.connect(_handle_image_input.bind(img_left))
	right_container.gui_input.connect(_handle_image_input.bind(img_right))
	
	# Cursor Updates
	left_container.mouse_entered.connect(_update_cursor.bind(img_left))
	right_container.mouse_entered.connect(_update_cursor.bind(img_right))
	left_container.mouse_exited.connect(_reset_cursor)
	right_container.mouse_exited.connect(_reset_cursor)

func open(dataset: Dictionary, stems_list: Array, start_stem: String, cols: Array, start_col_name: String = "") -> void:
	_dataset = dataset
	_stems = stems_list
	_columns = cols
	
	_current_index = _stems.find(start_stem)
	if _current_index == -1: _current_index = 0
	
	col_select_left.clear()
	col_select_right.clear()
	for c in _columns:
		col_select_left.add_item(c.to_upper())
		col_select_right.add_item(c.to_upper())
	
	var start_col_idx = 0
	if start_col_name != "":
		start_col_idx = _columns.find(start_col_name)
		if start_col_idx == -1: start_col_idx = 0
	
	if not _columns.is_empty():
		col_select_left.selected = start_col_idx
		if _columns.size() > 1:
			if start_col_idx < _columns.size() - 1:
				col_select_right.selected = start_col_idx + 1
			else:
				col_select_right.selected = start_col_idx - 1
		else:
			col_select_right.selected = start_col_idx

	$MarginContainer/VBoxContainer/SplitView.split_offset = 0
	_update_view()
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP

func _nav_row(direction: int) -> void:
	_save_left()
	_save_right()
	var new_index = _current_index + direction
	if new_index >= 0 and new_index < _stems.size():
		_current_index = new_index
		_update_view()

func _update_view() -> void:
	btn_prev_row.disabled = (_current_index <= 0)
	btn_next_row.disabled = (_current_index >= _stems.size() - 1)
	position_label.text = "%d / %d" % [_current_index + 1, _stems.size()]
	
	var current_stem = _stems[_current_index]
	$MarginContainer/VBoxContainer/TopBar/TitleLabel.text = "Comparing: " + current_stem
	
	_refresh_panel(true)
	_refresh_panel(false)

func _refresh_panel(is_left: bool) -> void:
	var stem = _stems[_current_index]
	var col_idx = col_select_left.selected if is_left else col_select_right.selected
	if col_idx == -1: return
	
	var col_name = _columns[col_idx]
	var img_node = img_left if is_left else img_right
	var txt_node = txt_left if is_left else txt_right
	
	# Reset State
	img_node.texture = null
	img_node.hide()
	txt_node.hide()
	_reset_zoom(img_node)
	
	var files = _dataset.get(stem, {}).get(col_name, [])
	if files.is_empty(): return 
		
	var file_path = files[0]
	var ext = file_path.get_extension().to_lower()
	
	if ext in ["png", "jpg", "jpeg", "webp"]:
		_load_image(img_node, file_path)
	elif ext in ["txt", "md", "json"]:
		_load_text(txt_node, file_path)

func _load_image(node: TextureRect, path: String) -> void:
	node.show()
	var img = Image.load_from_file(path)
	if img:
		node.texture = ImageTexture.create_from_image(img)
	_reset_zoom(node)

func _load_text(node: CodeEdit, path: String) -> void:
	node.show()
	node.set_meta("file_path", path)
	node.text = ""
	
	var f = FileAccess.open(path, FileAccess.READ)
	if f:
		var content = f.get_as_text()
		node.text = content
		node.set_meta("original_content", content) 
		node.clear_undo_history()

# --- TEXT SAVING ---

func _save_left() -> void: _perform_save(txt_left)
func _save_right() -> void: _perform_save(txt_right)

func _perform_save(editor: CodeEdit) -> void:
	if not editor.visible or not editor.has_meta("file_path"): return
	if editor.has_meta("original_content") and editor.text == editor.get_meta("original_content"):
		return
	request_save_text.emit(editor.get_meta("file_path"), editor.text)
	editor.set_meta("original_content", editor.text)

func _close() -> void:
	_save_left()
	_save_right()
	closed.emit()
	hide()

# --- ZOOM & PAN LOGIC (MATCHING IMAGEVIEWER) ---

func _handle_image_input(event: InputEvent, node: TextureRect) -> void:
	if not node.texture: return
	if not node.visible: return

	var is_left = (node == img_left)
	var is_zoomed = (node.stretch_mode == TextureRect.STRETCH_SCALE)
	
	# Update Cursor continuously
	if event is InputEventMouseMotion:
		_update_cursor(node)
		
		# Handle Panning
		var is_active_drag = _dragging_left if is_left else _dragging_right
		
		if is_active_drag and is_zoomed:
			var diff = event.global_position - _drag_start_mouse_pos
			if diff.length() > DRAG_THRESHOLD:
				_has_dragged_significantly = true
			
			node.position = _clamp_position(node, _drag_start_img_pos + diff)

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# MOUSE DOWN
			if is_zoomed:
				# Start Pan
				if is_left: _dragging_left = true
				else: _dragging_right = true
				_drag_start_mouse_pos = event.global_position
				_drag_start_img_pos = node.position
				_has_dragged_significantly = false
			else:
				# Check if clicking on actual image or void
				var container = node.get_parent()
				var mouse_pos = container.get_local_mouse_position()
				if _get_draw_rect(node).has_point(mouse_pos):
					_zoom_in(node, mouse_pos)
		
		else:
			# MOUSE UP
			var was_dragging = _dragging_left if is_left else _dragging_right
			
			if is_left: _dragging_left = false
			else: _dragging_right = false
			
			if was_dragging and not _has_dragged_significantly:
				_zoom_out(node)

func _zoom_in(node: TextureRect, pivot: Vector2) -> void:
	# Calculate relative position before resizing
	var visual_rect = _get_draw_rect(node)
	var relative_x = (pivot.x - visual_rect.position.x) / visual_rect.size.x
	var relative_y = (pivot.y - visual_rect.position.y) / visual_rect.size.y
	
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.size = visual_rect.size * ZOOM_LEVEL
	
	# Position based on mouse pivot
	var target_x = pivot.x - (node.size.x * relative_x)
	var target_y = pivot.y - (node.size.y * relative_y)
	
	node.position = _clamp_position(node, Vector2(target_x, target_y))
	_update_cursor(node)

func _zoom_out(node: TextureRect) -> void:
	_reset_zoom(node)
	_update_cursor(node)

func _reset_zoom(node: TextureRect) -> void:
	if is_instance_valid(node) and is_instance_valid(node.get_parent()):
		node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		node.size = node.get_parent().size
		node.position = Vector2.ZERO

# --- HELPERS ---

func _clamp_position(node: TextureRect, target_pos: Vector2) -> Vector2:
	var container_size = node.get_parent().size
	var min_x = container_size.x - node.size.x
	var min_y = container_size.y - node.size.y
	
	if node.size.x < container_size.x:
		target_pos.x = (container_size.x - node.size.x) / 2.0
	else:
		target_pos.x = clampf(target_pos.x, min_x, 0.0)
		
	if node.size.y < container_size.y:
		target_pos.y = (container_size.y - node.size.y) / 2.0
	else:
		target_pos.y = clampf(target_pos.y, min_y, 0.0)
	return target_pos

func _get_draw_rect(node: TextureRect) -> Rect2:
	if not node.texture: return Rect2()
	var container_size = node.get_parent().size
	var tex_size = node.texture.get_size()
	var tex_aspect = tex_size.x / tex_size.y
	var cont_aspect = container_size.x / container_size.y
	
	var final_size = Vector2()
	if cont_aspect > tex_aspect:
		final_size.y = container_size.y
		final_size.x = final_size.y * tex_aspect
	else:
		final_size.x = container_size.x
		final_size.y = final_size.x / tex_aspect
		
	var pos = (container_size - final_size) / 2.0
	return Rect2(pos, final_size)

func _update_cursor(node: TextureRect) -> void:
	if not node.visible: 
		Input.set_custom_mouse_cursor(null)
		return

	var is_zoomed = (node.stretch_mode == TextureRect.STRETCH_SCALE)
	var container = node.get_parent()
	var mouse_pos = container.get_local_mouse_position()
	
	var is_over_image = false
	if is_zoomed:
		# If zoomed, the TextureRect covers the image area
		is_over_image = node.get_rect().has_point(mouse_pos)
	else:
		# If not zoomed, check against the visual draw rect
		is_over_image = _get_draw_rect(node).has_point(mouse_pos)
	
	if is_over_image:
		Input.set_custom_mouse_cursor(CURSOR_MAGNIFIER, Input.CURSOR_ARROW, CURSOR_HOTSPOT)
	else:
		Input.set_custom_mouse_cursor(null)

func _reset_cursor() -> void:
	Input.set_custom_mouse_cursor(null)

class_name ImageViewer
extends ColorRect

# --- NODES ---
@onready var image_container: Control = %ImageContainer
@onready var full_image: TextureRect = %ImageContainer/FullImage
@onready var prev_btn: Button = %PrevBtn
@onready var next_btn: Button = %NextBtn
@onready var close_btn: Button = $CloseBtn

# --- ASSETS ---
const CURSOR_MAGNIFIER = preload("res://assets/magnifying_glass.svg")
const CURSOR_HOTSPOT = Vector2(21, 21)

# --- SETTINGS ---
const ZOOM_LEVEL: float = 3.0
const DRAG_THRESHOLD: float = 5.0

# --- STATE ---
var _current_paths: Array[String] = []
var _current_index: int = 0

var _is_zoomed: bool = false
var _is_dragging_active: bool = false
var _drag_start_mouse_pos: Vector2
var _drag_start_img_pos: Vector2
var _has_dragged_significantly: bool = false

func _ready() -> void:
	hide()
	close_btn.pressed.connect(hide)
	prev_btn.pressed.connect(_nav.bind(-1))
	next_btn.pressed.connect(_nav.bind(1))
	
	image_container.gui_input.connect(_on_container_input)
	image_container.mouse_entered.connect(_update_cursor_visuals)
	image_container.mouse_exited.connect(_reset_cursor)

# --- CURSOR LOGIC ---

func _update_cursor_visuals() -> void:
	var is_over_image = false
	var mouse_pos = image_container.get_local_mouse_position()
	
	if _is_zoomed:
		# When zoomed, the 'full_image' node Is the correct visual representation
		# We just check if the mouse is inside its rect
		is_over_image = full_image.get_rect().has_point(mouse_pos)
	else:
		# When NOT zoomed, we check the calculated "draw rect" (the fitted box)
		is_over_image = _get_draw_rect().has_point(mouse_pos)
	
	if is_over_image:
		# Always use Magnifier when over the image (Zoomed or Not)
		Input.set_custom_mouse_cursor(CURSOR_MAGNIFIER, Input.CURSOR_ARROW, CURSOR_HOTSPOT)
	else:
		# Reset to default system arrow when in the black void
		Input.set_custom_mouse_cursor(null)

func _reset_cursor() -> void:
	Input.set_custom_mouse_cursor(null)

# --- INPUT HANDLING ---

func _on_container_input(event: InputEvent) -> void:
	if not full_image.texture: return

	# Update cursor continuously as we move (to switch between void/image)
	if event is InputEventMouseMotion:
		_update_cursor_visuals()
		
		# Handle Panning
		if _is_dragging_active and _is_zoomed:
			var diff = event.global_position - _drag_start_mouse_pos
			if diff.length() > DRAG_THRESHOLD:
				_has_dragged_significantly = true
			full_image.position = _clamp_position(_drag_start_img_pos + diff)

	# Handle Clicks
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# --- MOUSE DOWN ---
			if _is_zoomed:
				_is_dragging_active = true
				_drag_start_mouse_pos = event.global_position
				_drag_start_img_pos = full_image.position
				_has_dragged_significantly = false
				# Note: We do NOT switch cursor here anymore. It stays Magnifier.
			else:
				var mouse_pos = image_container.get_local_mouse_position()
				if _get_draw_rect().has_point(mouse_pos):
					_zoom_in(mouse_pos)
				else:
					hide()
					get_viewport().set_input_as_handled()
		else:
			# --- MOUSE UP ---
			if _is_dragging_active:
				_is_dragging_active = false
				if not _has_dragged_significantly:
					_zoom_out()

# --- ZOOM LOGIC ---

func _zoom_in(pivot: Vector2) -> void:
	_is_zoomed = true
	
	var visual_rect = _get_draw_rect()
	var relative_x = (pivot.x - visual_rect.position.x) / visual_rect.size.x
	var relative_y = (pivot.y - visual_rect.position.y) / visual_rect.size.y
	
	full_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	full_image.stretch_mode = TextureRect.STRETCH_SCALE
	full_image.size = visual_rect.size * ZOOM_LEVEL
	
	# --- THE FIX IS HERE ---
	# Old Math: Target was Container Center - (Image Offset)
	# New Math: Target is Mouse Pivot - (Image Offset)
	var target_x = pivot.x - (full_image.size.x * relative_x)
	var target_y = pivot.y - (full_image.size.y * relative_y)
	
	full_image.position = _clamp_position(Vector2(target_x, target_y))
	
	prev_btn.hide()
	next_btn.hide()
	_update_cursor_visuals()

func _zoom_out() -> void:
	_is_zoomed = false
	_is_dragging_active = false
	
	full_image.position = Vector2.ZERO
	full_image.size = image_container.size 
	full_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	full_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	prev_btn.visible = _current_paths.size() > 1
	next_btn.visible = _current_paths.size() > 1
	_update_cursor_visuals()

# --- DISPLAY / HELPERS ---

func _get_draw_rect() -> Rect2:
	if not full_image.texture: return Rect2()
	var container_size = image_container.size
	var tex_size = full_image.texture.get_size()
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

func _clamp_position(target_pos: Vector2) -> Vector2:
	var min_x = image_container.size.x - full_image.size.x
	var min_y = image_container.size.y - full_image.size.y
	
	if full_image.size.x < image_container.size.x:
		target_pos.x = (image_container.size.x - full_image.size.x) / 2.0
	else:
		target_pos.x = clampf(target_pos.x, min_x, 0.0)
		
	if full_image.size.y < image_container.size.y:
		target_pos.y = (image_container.size.y - full_image.size.y) / 2.0
	else:
		target_pos.y = clampf(target_pos.y, min_y, 0.0)
	return target_pos

func show_gallery(paths: Array[String], start_path: String) -> void:
	_current_paths = paths
	_current_index = _current_paths.find(start_path)
	if _current_index == -1: _current_index = 0
	_update_display()
	show()
	move_to_front()

func _nav(direction: int) -> void:
	if _current_paths.is_empty(): return
	_current_index += direction
	if _current_index < 0: _current_index = _current_paths.size() - 1
	elif _current_index >= _current_paths.size(): _current_index = 0
	_update_display()

func _update_display() -> void:
	if _is_zoomed: _zoom_out()
	var path = _current_paths[_current_index]
	var img = Image.load_from_file(path)
	if img:
		full_image.texture = ImageTexture.create_from_image(img)
	prev_btn.visible = _current_paths.size() > 1
	next_btn.visible = _current_paths.size() > 1

func _input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed("ui_cancel"):
		if _is_zoomed: _zoom_out()
		else: hide()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") and not _is_zoomed:
		_nav(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") and not _is_zoomed:
		_nav(1)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if not visible: _reset_cursor()

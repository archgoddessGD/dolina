class_name TextEditor
extends ColorRect

signal request_save(path: String, content: String)
signal closed 

@onready var title_label: Label = %TitleLabel
@onready var editor: CodeEdit = %Editor
@onready var save_btn: Button = %SaveBtn
@onready var close_btn: Button = %CloseBtn
@onready var status_label: Label = %StatusLabel
@onready var sheet: PanelContainer = $Sheet

var _current_path: String = ""
var _autosave_enabled: bool = false
var _autosave_timer: Timer

func _ready() -> void:
	hide()
	
	close_btn.pressed.connect(_close)
	save_btn.pressed.connect(_manual_save)
	
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = 2.0
	_autosave_timer.one_shot = true
	_autosave_timer.add_to_group("autosave_timers")
	add_child(_autosave_timer)
	
	_autosave_timer.timeout.connect(_on_autosave_trigger)
	
	editor.text_changed.connect(func():
		if _autosave_enabled:
			status_label.text = "Typing..."
			_autosave_timer.start()
	)
	
	# Listen for input on the background (ColorRect)
	gui_input.connect(_on_background_input)
	editor.gui_input.connect(_on_editor_input)
	
	# Add escape key support globally for this view
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func open(path: String, content: String, autosave_on: bool) -> void:
	_current_path = path
	_autosave_enabled = autosave_on
	
	# Get folder name + file name (e.g., "column_name/file.txt")
	var folder = path.get_base_dir().get_file()
	var file = path.get_file()
	title_label.text = "%s / %s" % [folder, file]
	# --------------------
	
	editor.text = content
	status_label.text = "Ready"
	
	_autosave_timer.stop()
	
	show()
	editor.grab_focus()

func _manual_save() -> void:
	_perform_save("Saved!")
	_autosave_timer.stop()

func _on_autosave_trigger() -> void:
	if visible:
		_perform_save("Autosaved")

func _perform_save(success_msg: String) -> void:
	request_save.emit(_current_path, editor.text)
	status_label.text = success_msg
	status_label.modulate = Color("41f095")
	var tween = create_tween()
	tween.tween_property(status_label, "modulate", Color(1,1,1,0.7), 1.5)

func _close() -> void:
	if not _autosave_timer.is_stopped():
		_perform_save("Saved on close")
	hide()
	closed.emit()

func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# --- CLICK OFF FIX ---
		# We check if the mouse click was NOT inside the sheet's global rectangle.
		if not sheet.get_global_rect().has_point(get_global_mouse_position()):
			_close()

func _on_editor_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_S:
		if event.is_command_or_control_pressed():
			get_viewport().set_input_as_handled()
			_manual_save()

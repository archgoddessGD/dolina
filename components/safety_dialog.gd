class_name SafetyDialog
extends ConfirmationDialog

# --- UI NODES ---
@onready var thumbnail: TextureRect = %Thumbnail
@onready var prompt_label: Label = %PromptLabel
# NEW: Reference the input
@onready var input_line: LineEdit = %InputLine 
@onready var btn_perm: Button = %BtnPerm
@onready var btn_main: Button = %BtnMain
@onready var btn_cancel: Button = %BtnCancel

# --- STATE ---
var _on_main_action: Callable
var _on_perm_action: Callable

func _ready() -> void:
	btn_main.pressed.connect(_on_main_pressed)
	btn_perm.pressed.connect(_on_perm_pressed)
	btn_cancel.pressed.connect(hide)
	
	get_ok_button().hide()
	get_cancel_button().hide()
	
	btn_cancel.text = "Cancel"

# --- PUBLIC API ---

# Mode 1: Delete File
func open_delete(text: String, texture_path: String, on_recycle: Callable, on_perm: Callable) -> void:
	prompt_label.text = text
	_on_main_action = on_recycle
	_on_perm_action = on_perm
	
	btn_perm.show()
	btn_perm.text = "PERMANENTLY DELETE"
	btn_perm.modulate = Color(1, 0.4, 0.4)
	
	btn_main.text = "Move to Deleted"
	btn_cancel.text = "Cancel"
	
	input_line.hide() # Ensure input is hidden
	_load_thumbnail(texture_path)
	
	min_size = Vector2i(0, 0)
	size = Vector2i(0, 0)
	popup_centered()
	btn_main.grab_focus()

# Mode 2: Generic Confirmation
func open_confirm(text: String, on_confirm: Callable) -> void:
	prompt_label.text = text
	_on_main_action = on_confirm
	_on_perm_action = Callable()
	
	btn_perm.hide()
	thumbnail.hide()
	input_line.hide() # Ensure input is hidden
	
	btn_main.text = "Yes"
	btn_cancel.text = "Cancel"
	
	min_size = Vector2i(0, 0)
	size = Vector2i(0, 0)
	popup_centered()
	btn_main.grab_focus()

# Mode 3: Fill with Text Option
func open_fill(text: String, on_confirm: Callable) -> void:
	prompt_label.text = text
	_on_main_action = on_confirm
	_on_perm_action = Callable()
	
	btn_perm.hide()
	thumbnail.hide()
	
	# Show and Reset Input
	input_line.show()
	input_line.text = "" 
	input_line.placeholder_text = "Optional: Text to write in files..."
	
	btn_main.text = "Create Files"
	btn_cancel.text = "Cancel"
	
	min_size = Vector2i(0, 0)
	size = Vector2i(0, 0)
	popup_centered()
	input_line.grab_focus() # Focus the input so they can type immediately

# Helper to retrieve text
func get_input_text() -> String:
	return input_line.text

# --- INTERNAL LOGIC ---
# (Rest of the file remains exactly the same as before)
func _on_main_pressed() -> void:
	if _on_main_action: _on_main_action.call()
	_cleanup()

func _on_perm_pressed() -> void:
	if _on_perm_action: _on_perm_action.call()
	_cleanup()

func _cleanup() -> void:
	_on_main_action = Callable()
	_on_perm_action = Callable()
	hide()

func _load_thumbnail(path: String) -> void:
	if path == "":
		thumbnail.hide()
		return
	var img = Image.load_from_file(path)
	if img:
		var aspect = float(img.get_width()) / float(img.get_height())
		var h = 180
		img.resize(int(h * aspect), h, Image.INTERPOLATE_BILINEAR)
		thumbnail.texture = ImageTexture.create_from_image(img)
		thumbnail.custom_minimum_size.y = 180
		thumbnail.show()
	else:
		thumbnail.hide()

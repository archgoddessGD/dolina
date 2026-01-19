class_name SettingsDialog
extends AcceptDialog

signal settings_changed(new_page_size: int, new_row_height: int)

@onready var rows_input: SpinBox = %RowsInput
@onready var height_input: SpinBox = %HeightInput

func _ready() -> void:
	confirmed.connect(_on_apply)
	
	# 1. Access the internal LineEdit nodes
	var rows_le = rows_input.get_line_edit()
	var height_le = height_input.get_line_edit()
	
	var original_style = rows_le.get_theme_stylebox("normal")
	var red_style = original_style.duplicate()
	
	if red_style is StyleBoxFlat:
		red_style.bg_color = Color("#692c2c")
	
	rows_le.add_theme_stylebox_override("normal", red_style)
	height_le.add_theme_stylebox_override("normal", red_style)

	rows_le.add_theme_stylebox_override("focus", red_style)
	height_le.add_theme_stylebox_override("focus", red_style)
	
func open(current_page_size: int, current_row_height: int) -> void:
	# Pre-fill with current values
	rows_input.value = current_page_size
	height_input.value = current_row_height
	popup_centered()

func _on_apply() -> void:
	# Emit the new values back to Main
	settings_changed.emit(int(rows_input.value), int(height_input.value))

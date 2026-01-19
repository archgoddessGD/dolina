class_name SettingsDialog
extends AcceptDialog

signal settings_changed(new_page_size: int, new_row_height: int)

@onready var rows_input: SpinBox = %RowsInput
@onready var height_input: SpinBox = %HeightInput

func _ready() -> void:
	# Connect the built-in "confirmed" signal (from the OK button)
	confirmed.connect(_on_apply)

func open(current_page_size: int, current_row_height: int) -> void:
	# Pre-fill with current values
	rows_input.value = current_page_size
	height_input.value = current_row_height
	popup_centered()

func _on_apply() -> void:
	# Emit the new values back to Main
	settings_changed.emit(int(rows_input.value), int(height_input.value))

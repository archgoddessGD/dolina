class_name ErrorState
extends CenterContainer

# Define a signal so the parent (Main) knows when the action happens
signal setup_requested

@onready var setup_btn: Button = %SetupBtn

func _ready() -> void:
	# Forward the button's press to the custom signal
	setup_btn.pressed.connect(func(): setup_requested.emit())

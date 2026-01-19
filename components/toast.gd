extends PanelContainer

func show_message(text: String, duration: float = 2.0) -> void:
	$Message.text = text
	
	# Start slightly transparent and offset
	modulate.a = 0.0
	position.y += 20
	
	# Animate In
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_property(self, "position:y", position.y - 20, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Wait
	tween.chain().tween_interval(duration)
	
	# Animate Out
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free) # Destroy self after fade out

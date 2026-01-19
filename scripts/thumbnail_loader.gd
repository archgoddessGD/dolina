class_name ThumbnailLoader
extends Node

# A cache to store images we've already loaded (makes going back to previous pages instant!)
static var cache: Dictionary = {}

static func request_thumbnail(path: String, target_height: int, on_complete: Callable) -> void:
	# 1. Check Cache first
	if cache.has(path):
		on_complete.call(cache[path])
		return

	# 2. If not in cache, run the loading task in the background
	WorkerThreadPool.add_task(func(): _load_in_background(path, target_height, on_complete))

static func _load_in_background(path: String, target_height: int, on_complete: Callable) -> void:
	var img = Image.load_from_file(path)
	var texture: ImageTexture = null
	
	if img:
		var orig_size = img.get_size()
		# Resize logic (same as before)
		if orig_size.y > target_height:
			var aspect = float(orig_size.x) / float(orig_size.y)
			var target_w = int(target_height * aspect)
			img.resize(target_w, target_height, Image.INTERPOLATE_BILINEAR)
		
		# Create texture from image
		texture = ImageTexture.create_from_image(img)
		
		# Store in cache
		# Note: We should be careful with memory, but for <1000 images it's usually fine.
		cache[path] = texture
	
	# 3. Send the result back to the Main Thread (UI cannot be touched from a background thread!)
	on_complete.call_deferred(texture)

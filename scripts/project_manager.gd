class_name ProjectManager
extends Node

# --- SIGNALS ---
signal project_loaded
signal error_occurred(message: String)
signal toast_requested(message: String)

# --- DATA STATE ---
var current_project_name: String = ""
var current_dataset: Dictionary = {} 
var current_columns: Array[String] = []

# --- PATHS ---
var datasets_root_path: String = ""
var deleted_root_path: String = ""
var _base_data_path: String = ""

func _ready() -> void:
	_setup_paths()
	# Optional: Create folders immediately on ready
	_ensure_directories_exist()

# --- INITIALIZATION ---

func _setup_paths() -> void:
	if OS.has_feature("editor"):
		_base_data_path = ProjectSettings.globalize_path("res://examples/data")
	else:
		_base_data_path = OS.get_executable_path().get_base_dir() + "/data"
		if OS.get_name() == "macOS":
			if _base_data_path.contains(".app"):
				_base_data_path = OS.get_executable_path().get_base_dir().get_base_dir().get_base_dir().get_base_dir() + "/data"
	
	datasets_root_path = _base_data_path + "/datasets"
	deleted_root_path = _base_data_path + "/deleted_files"

func _ensure_directories_exist() -> void:
	var dir = DirAccess.open(_base_data_path)
	if not dir: 
		dir = DirAccess.open(OS.get_executable_path().get_base_dir())
		if dir: dir.make_dir_recursive(datasets_root_path)
	else:
		if not DirAccess.dir_exists_absolute(datasets_root_path):
			DirAccess.make_dir_recursive_absolute(datasets_root_path)
		if not DirAccess.dir_exists_absolute(deleted_root_path):
			DirAccess.make_dir_recursive_absolute(deleted_root_path)

# --- CORE ACTIONS ---

func scan_projects() -> Array[String]:
	var dir = DirAccess.open(datasets_root_path)
	if not dir: 
		error_occurred.emit("Data Folder Missing!")
		return []

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var found_projects: Array[String] = []
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			found_projects.append(file_name)
		file_name = dir.get_next()
	found_projects.sort()
	
	return found_projects

func load_project(project_name: String) -> void:
	current_project_name = project_name
	current_dataset.clear()
	current_columns.clear()
	
	var proj_path = datasets_root_path + "/" + project_name
	var dir = DirAccess.open(proj_path)
	if not dir: 
		error_occurred.emit("Could not open project folder.")
		return

	# 1. Scan Columns (Folders)
	dir.list_dir_begin()
	var item = dir.get_next()
	while item != "":
		if dir.current_is_dir() and not item.begins_with("."):
			current_columns.append(item)
		item = dir.get_next()
	current_columns.sort()
	
	# 2. Scan Files inside Columns
	for col in current_columns:
		var col_path = proj_path + "/" + col
		var col_dir = DirAccess.open(col_path)
		if col_dir:
			col_dir.list_dir_begin()
			var file = col_dir.get_next()
			while file != "":
				if not col_dir.current_is_dir() and not file.begins_with(".") and not file.ends_with(".import"):
					var stem = file.get_basename() 
					if not current_dataset.has(stem):
						current_dataset[stem] = {}
						for c in current_columns: 
							current_dataset[stem][c] = []
					
					# Ensure the column array exists (for safety)
					if not current_dataset[stem].has(col):
						current_dataset[stem][col] = []
						
					current_dataset[stem][col].append(col_path + "/" + file)
				file = col_dir.get_next()

	project_loaded.emit()

# --- FILE OPERATIONS ---

func create_text_file(stem: String, col_name: String) -> void:
	var folder_path = datasets_root_path + "/" + current_project_name + "/" + col_name
	var file_path = folder_path + "/" + stem + ".txt"
	var f = FileAccess.open(file_path, FileAccess.WRITE)
	if f:
		f.store_string("")
		f.close()
		load_project(current_project_name) # Reload to show changes

func save_text_file(path: String, content: String) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(content)
		f.close()
		toast_requested.emit("SAVED!")

func delete_file_permanently(path: String) -> void:
	var dir = DirAccess.open(path.get_base_dir())
	if dir and dir.remove(path.get_file()) == OK:
		toast_requested.emit("Permanently Deleted")
		load_project(current_project_name)
	else:
		error_occurred.emit("Failed to delete file.")

func move_file_to_trash(source_path: String) -> void:
	# 1. Identify structure
	var relative_path = source_path.replace(datasets_root_path + "/", "")
	var relative_dir = relative_path.get_base_dir()
	var file_name = relative_path.get_file()
	
	# 2. Prepare Target
	var target_dir = deleted_root_path + "/" + relative_dir
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)
	
	# 3. Handle Conflicts
	var target_path = target_dir + "/" + file_name
	var extension = file_name.get_extension()
	var basename = file_name.get_basename()
	var counter = 1
	
	while FileAccess.file_exists(target_path):
		target_path = target_dir + "/" + basename + " (%d)." % counter + extension
		counter += 1
		
	# 4. Move
	var dir = DirAccess.open(datasets_root_path)
	if dir:
		var err = dir.rename(source_path, target_path)
		if err == OK:
			toast_requested.emit("Moved to Trash")
			load_project(current_project_name)
		else:
			error_occurred.emit("Error moving file: " + str(err))

func populate_empty_files(col_name: String, content: String = "") -> void:
	var folder_path = datasets_root_path + "/" + current_project_name + "/" + col_name
	var stems_to_fill = []
	
	for stem in current_dataset:
		if current_dataset[stem].get(col_name, []).is_empty():
			stems_to_fill.append(stem)
			
	for stem in stems_to_fill:
		var file_path = folder_path + "/" + stem + ".txt"
		var f = FileAccess.open(file_path, FileAccess.WRITE)
		if f: 
			# Use the provided content!
			f.store_string(content)
			f.close()
			
	load_project(current_project_name)

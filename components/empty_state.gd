class_name EmptyState
extends CenterContainer

signal examples_imported

# Use the RAW version of the link for direct download
const DOWNLOAD_URL = "https://github.com/kierarkia/dolina/raw/main/examples/data/datasets/dolina_examples.zip"

@onready var download_btn: Button = %DownloadBtn
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var label: Label = $VBoxContainer/Label

var _target_folder: String = ""

func _ready() -> void:
	download_btn.pressed.connect(_on_download_pressed)
	http_request.request_completed.connect(_on_request_completed)
	
	# Enable threading for responsiveness
	http_request.use_threads = true 
	
	# Disable processing initially (we only need it during download)
	set_process(false)

func _process(_delta: float) -> void:
	# Poll the request for status
	var body_size = http_request.get_body_size()
	var downloaded_bytes = http_request.get_downloaded_bytes()
	
	if body_size > 0:
		var percent = (float(downloaded_bytes) / float(body_size)) * 100
		progress_bar.value = percent

func setup(target_folder_path: String) -> void:
	_target_folder = target_folder_path

func _on_download_pressed() -> void:
	if _target_folder == "": return
	
	download_btn.disabled = true
	download_btn.text = "Downloading..."
	
	progress_bar.value = 0
	progress_bar.show()
	
	# Start polling for progress
	set_process(true)
	
	# WINDOWS FIX: Use path_join for OS-safe separators
	var temp_path = OS.get_cache_dir().path_join("dolina_temp.zip")
	
	# WINDOWS FIX: Ensure the file doesn't already exist/isn't locked
	if FileAccess.file_exists(temp_path):
		var err = DirAccess.remove_absolute(temp_path)
		if err != OK:
			print("Warning: Could not delete old temp file. Error: ", err)
	
	http_request.download_file = temp_path
	
	# WINDOWS FIX: Capture the error if the request fails to start
	
	# Create "unsafe" TLS options to bypass Windows certificate issues
	var tls_options = TLSOptions.client_unsafe()
	
	http_request.set_tls_options(tls_options)
	
	# Now call request with standard arguments (or just the URL if defaults are fine)
	var error = http_request.request(DOWNLOAD_URL)
	
	if error != OK:
		_handle_error("Request Start Failed", error)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	# Stop polling
	set_process(false)
	
	# WINDOWS FIX 4: Detailed debug info
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("Download Error Debug:")
		print("Result (Godot Internal): ", result) 
		print("Response Code (HTTP): ", response_code)
		
		var msg = "Download Failed!"
		
		# Corrected Error Checking
		if result == HTTPRequest.RESULT_CANT_CONNECT:
			msg = "Connection Failed"
		elif result == HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			msg = "SSL/TLS Handshake Error"
		elif result == HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			msg = "Cannot Open File (Write Error)"
		elif result == HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			msg = "File Write Error"
		
		_handle_error(msg, response_code)
		return

	download_btn.text = "Unzipping..."
	progress_bar.value = 100 
	
	await get_tree().process_frame
	
	var zip_path = http_request.download_file
	var success = _unzip_and_install(zip_path)
	
	# Cleanup
	DirAccess.remove_absolute(zip_path)
	
	if success:
		examples_imported.emit()
		download_btn.disabled = false
		download_btn.text = "Download Examples"
		progress_bar.hide()
	else:
		_handle_error("Error Unzipping Files", 0)

# Helper to consolidate error UI reset
func _handle_error(msg: String, code: int) -> void:
	label.text = "%s (Code: %d)" % [msg, code]
	download_btn.text = "Retry"
	download_btn.disabled = false
	progress_bar.hide()
	set_process(false)

func _unzip_and_install(zip_path: String) -> bool:
	var reader = ZIPReader.new()
	var err = reader.open(zip_path)
	if err != OK: return false
	
	var files = reader.get_files()
	for file_path in files:
		if file_path.ends_with("/"): continue
			
		var content = reader.read_file(file_path)
		# Ensure we use path_join here too
		var final_path = _target_folder.path_join(file_path)
		
		var base_dir = final_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(base_dir):
			DirAccess.make_dir_recursive_absolute(base_dir)
			
		var f = FileAccess.open(final_path, FileAccess.WRITE)
		if f:
			f.store_buffer(content)
			f.close()
			
	reader.close()
	return true

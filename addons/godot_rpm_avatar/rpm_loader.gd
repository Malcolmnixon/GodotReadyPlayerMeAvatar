extends Node


## ReadyPlayerMe Loader Node
##
## This node loads ReadyPlayerMe avatars from either the web or files. The
## avatars are processed in worker threads to prevent stalling the renderer.


## Signal invoked when an avatar finishes loading
signal load_complete(id : String, avatar : Node3D)

## Signal invoked when an avatar load fails
signal load_failed(id : String, reason : String)


# Import flags to generate tangent arrays and use named skin bindings
const _GLTF_FLAGS : int = 0x18

# ReadyPlayerMe URL
const _RPM_URL := \
	"https://models.readyplayer.me/{id}.glb" + \
	"?quality={quality}" + \
	"&pose=T" + \
	"&morphTargets={morph}"

# ReadyPlayerMe quality strings
const _QUALITY : Array[String] = [
	"low",
	"medium",
	"high"
]


# ReadyPlayerMe Download Request
class RpmDownloadRequest:
	var id : String
	var url : String
	var settings : RpmSettings

	func _init(
			_id : String,
			_url : String,
			_settings : RpmSettings) -> void:
		# Save the parameters
		id = _id
		url = _url
		settings = _settings


# HTTP Request instance
var _http_request : HTTPRequest

# Queue of download requests
var _queue : Array[RpmDownloadRequest] = []

# Current download request
var _current : RpmDownloadRequest


## Called when the node is ready
func _ready() -> void:
	# Construct the HTTP Request
	_http_request = HTTPRequest.new()
	add_child(_http_request)

	# Subscribe to the request completed event and start the first download.
	_http_request.request_completed.connect(_on_http_request_completed)
	_download_next()


## Queue loading an avatar from the web.
func load_web(
		id : String,
		settings : RpmSettings) -> void:
	# Construct the ReadyPlayerMe download URL
	var url := _RPM_URL.format({
		"id": id,
		"quality": _QUALITY[settings.quality],
		"morph": "ARKit" if settings.face_tracker else "Default"
	})

	# Construct the request
	print_verbose("RpmLoader: load_web - id=", id, " url=", url)
	_queue.push_back(RpmDownloadRequest.new(id, url, settings))
	_download_next()


## Queue loading an avatar from file.
func load_file(
		id : String,
		file_name : String,
		settings : RpmSettings) -> void:
	# Load in a worker thread
	print_verbose("RpmLoader: load_file - id=", id, " file=", file_name)
	WorkerThreadPool.add_task(
		_threaded_load_file.bind(
			id,
			file_name,
			settings))


# Start the next download if possible
func _download_next() -> void:
	# Skip if busy or not started
	if _current or not _http_request:
		return

	# Start the next download
	_current = _queue.pop_front()
	if _current:
		print_verbose("RpmLoader: downloading - id=", _current.id, " url=", _current.url)
		_http_request.request(_current.url)


# Handle downloading of the avatar
func _on_http_request_completed(
		result : int,
		response_code : int,
		_headers : PackedStringArray,
		body : PackedByteArray) -> void:
	# Handle completion
	if response_code != 200:
		# Report the download failure
		print_verbose("RpmLoader: download-failed - id=", _current.id, " response=", response_code)
		_load_failed.call_deferred(_current.id, "Download Failed")
	elif result != HTTPRequest.RESULT_SUCCESS:
		# Report the download failure
		print_verbose("RpmLoader: download-failed - id=", _current.id, " result=", result)
		_load_failed.call_deferred(_current.id, "Download Failed")
	else:
		# Load in a worker thread
		print_verbose("RpmLoader: loading - id=", _current.id)
		WorkerThreadPool.add_task(
			_threaded_load_buffer.bind(
				_current.id,
				body,
				_current.settings))

	# Start the next download
	_current = null
	_download_next()


# Load the avatar file
func _threaded_load_file(
		id : String,
		file_name : String,
		settings : RpmSettings) -> void:
	# Load the GLTF document from file
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	state.set_handle_binary_image(GLTFState.HANDLE_BINARY_EMBED_AS_BASISU)
	doc.append_from_file(file_name, state, _GLTF_FLAGS)

	# Load the avatar
	_load_gltf(id, doc, state, settings)


# Load the avatar buffer
func _threaded_load_buffer(
		id : String,
		buffer : PackedByteArray,
		settings : RpmSettings) -> void:
	# Load the GLTF document from buffer
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	state.set_handle_binary_image(GLTFState.HANDLE_BINARY_EMBED_AS_BASISU)
	doc.append_from_buffer(buffer, "", state, _GLTF_FLAGS)

	# Load the avatar
	_load_gltf(id, doc, state, settings)


# Load the avatar
func _load_gltf(
		id : String,
		doc : GLTFDocument,
		state : GLTFState,
		settings : RpmSettings) -> void:
	# Generate the scene
	print_verbose("RpmLoader: generating - id=", id)
	var scene := doc.generate_scene(state)
	if not scene:
		_load_failed.call_deferred(id, "Corrupt Avatar")
		return

	# Find the skeleton
	var skeletons := scene.find_children("*", "Skeleton3D")
	if skeletons.size() != 1:
		_load_failed.call_deferred(id, "Corrupt Avatar")
		return

	# Find the mesh
	var meshes := scene.find_children("*", "MeshInstance3D")
	if meshes.size() != 1:
		_load_failed.call_deferred(id, "Corrupt Avatar")
		return

	# Construct the nodes
	var skeleton := skeletons[0] as Skeleton3D
	var mesh := meshes[0] as MeshInstance3D

	# Retarget the skeleton to Godot Humanoid
	RpmBody.retarget(skeleton)

	# Construct the XRNode3D (root)
	var xr_node := XRNode3D.new()
	xr_node.tracker = settings.body_tracker
	xr_node.add_child(scene)

	# Construct the XRBodyModifier3D (under skeleton)
	var body_modifier := XRBodyModifier3D.new()
	skeleton.add_child(body_modifier)
	body_modifier.body_tracker = settings.body_tracker
	body_modifier.bone_update = XRBodyModifier3D.BONE_UPDATE_ROTATION_ONLY

	# Construct and append the XRFaceModifier3D
	if settings.face_tracker != "":
		var face_modifier := XRFaceModifier3D.new()
		xr_node.add_child(face_modifier)
		face_modifier.face_tracker = settings.face_tracker
		face_modifier.target = face_modifier.get_path_to(mesh)

	# Report the load completed
	print_verbose("RpmLoader: loaded - id=", id)
	_load_complete.call_deferred(id, xr_node)


# Report load complete
func _load_complete(id : String, avatar : Node3D) -> void:
	load_complete.emit(id, avatar)


# Report load failed
func _load_failed(id : String, reason : String) -> void:
	load_failed.emit(id, reason)

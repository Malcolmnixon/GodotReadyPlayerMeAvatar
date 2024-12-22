extends Node3D


@export var rpm_settings : RpmSettings


# Current avatar
var _avatar : Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	RpmLoader.load_complete.connect(_on_load_complete)
	RpmLoader.load_failed.connect(_on_load_failed)


func _on_load_button_pressed() -> void:
	if %AvatarID.text == "":
		return

	# Queue the download
	%Status.text = "Downloading ..."
	RpmLoader.load_web(%AvatarID.text, rpm_settings)


func _on_load_complete(_id : String, avatar : Node3D) -> void:
	# Free the old avatar
	if _avatar:
		_avatar.queue_free()

	# Add the avatar to this scene
	_avatar = avatar
	add_child(_avatar)
	%Status.text = "Success"


func _on_load_failed(_id : String, reason : String) -> void:
	%Status.text = reason

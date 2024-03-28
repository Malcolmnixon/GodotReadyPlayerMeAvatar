@tool
extends EditorPlugin


func _enter_tree():
	# Register our autoload downloader object
	add_autoload_singleton(
			"RpmLoader",
			"res://addons/godot_rpm_avatar/rpm_loader.gd")

class_name RpmSettings
extends Resource


## ReadyPlayerMe Settings Resource
##
## This resource defines the settings for reading ReadyPlayerMe avatars.


## Avatar Quality Options
enum Quality {
	QUALITY_LOW,		## Low Quality Avatar
	QUALITY_MEDIUM,		## Medium Quality Avatar
	QUALITY_HIGH		## High Quality Avatar
}


## Body tracker name
@export var body_tracker : String = ""

## Face tracker name
@export var face_tracker : String = ""

## Avatar quality
@export var quality : Quality = Quality.QUALITY_MEDIUM

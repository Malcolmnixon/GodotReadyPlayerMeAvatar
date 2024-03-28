class_name RpmBody


## ReadyPlayerMe Body Script
##
## This script converts ReadyPlayerMe avatars into Godot Humanoid format by
## renaming and rotating the bones.


# Mapping from RPM to Godot Humanoid bones
const _RPM_TO_HUMANOID = {
	"Hips" : "Hips",
	"Spine" : "Spine",
	"Spine1" : "Chest",
	"Spine2" : "UpperChest",
	"Neck" : "Neck",
	"Head" : "Head",
	"LeftEye" : "LeftEye",
	"RightEye" : "RightEye",
	"LeftShoulder" : "LeftShoulder",
	"LeftArm" : "LeftUpperArm",
	"LeftForeArm" : "LeftLowerArm",
	"LeftHand" : "LeftHand",
	"LeftHandThumb1" : "LeftThumbMetacarpal",
	"LeftHandThumb2" : "LeftThumbProximal",
	"LeftHandThumb3" : "LeftThumbDistal",
	"LeftHandIndex1" : "LeftIndexProximal",
	"LeftHandIndex2" : "LeftIndexIntermediate",
	"LeftHandIndex3" : "LeftIndexDistal",
	"LeftHandMiddle1" : "LeftMiddleProximal",
	"LeftHandMiddle2" : "LeftMiddleIntermediate",
	"LeftHandMiddle3" : "LeftMiddleDistal",
	"LeftHandRing1" : "LeftRingProximal",
	"LeftHandRing2" : "LeftRingIntermediate",
	"LeftHandRing3" : "LeftRingDistal",
	"LeftHandPinky1" : "LeftLittleProximal",
	"LeftHandPinky2" : "LeftLittleIntermediate",
	"LeftHandPinky3" : "LeftLittleDistal",
	"RightShoulder" : "RightShoulder",
	"RightArm" : "RightUpperArm",
	"RightForeArm" : "RightLowerArm",
	"RightHand" : "RightHand",
	"RightHandThumb1" : "RightThumbMetacarpal",
	"RightHandThumb2" : "RightThumbProximal",
	"RightHandThumb3" : "RightThumbDistal",
	"RightHandIndex1" : "RightIndexProximal",
	"RightHandIndex2" : "RightIndexIntermediate",
	"RightHandIndex3" : "RightIndexDistal",
	"RightHandMiddle1" : "RightMiddleProximal",
	"RightHandMiddle2" : "RightMiddleIntermediate",
	"RightHandMiddle3" : "RightMiddleDistal",
	"RightHandRing1" : "RightRingProximal",
	"RightHandRing2" : "RightRingIntermediate",
	"RightHandRing3" : "RightRingDistal",
	"RightHandPinky1" : "RightLittleProximal",
	"RightHandPinky2" : "RightLittleIntermediate",
	"RightHandPinky3" : "RightLittleDistal",
	"LeftUpLeg" : "LeftUpperLeg",
	"LeftLeg" : "LeftLowerLeg",
	"LeftFoot" : "LeftFoot",
	"LeftToeBase" : "LeftToes",
	"RightUpLeg" : "RightUpperLeg",
	"RightLeg" : "RightLowerLeg",
	"RightFoot" : "RightFoot",
	"RightToeBase" : "RightToes"
}


## Retarget a skeleton mesh to conform to the Godot Humanoid standard
static func retarget(src_skeleton : Skeleton3D) -> void:
	# Rename the bones to Godot Humanoid
	_rename_bones(src_skeleton)

	# Save the original skeleton global rest
	var original_global_rest : Array[Transform3D] = []
	for i in src_skeleton.get_bone_count():
		original_global_rest.append(src_skeleton.get_bone_global_rest(i))

	# Rotate the bones
	_rotate_bones(src_skeleton)

	# Fix the skin to counteract the bone rotation
	for mesh : MeshInstance3D in src_skeleton.find_children("*", "MeshInstance3D"):
		var skin := mesh.skin
		if not skin: continue
		for i in skin.get_bind_count():
			var bone_name := skin.get_bind_name(i)
			var bone_idx := src_skeleton.find_bone(bone_name)
			if bone_idx < 0: continue
			var adjust_transform := \
				src_skeleton.get_bone_global_rest(bone_idx).affine_inverse() * \
				original_global_rest[bone_idx]
			skin.set_bind_pose(i, adjust_transform * skin.get_bind_pose(i))

	# Move skeleton to rest
	_to_rest(src_skeleton)


# This method renames the bones in the skeleton to the Godot Humanoid standard
static func _rename_bones(src_skeleton : Skeleton3D) -> void:
	# Rename bones from RPM to Godot Humanoid
	for i in src_skeleton.get_bone_count():
		var old_name := src_skeleton.get_bone_name(i)
		var new_name := _RPM_TO_HUMANOID.get(old_name, "")
		if new_name != "":
			src_skeleton.set_bone_name(i, new_name)

	# Rename skin binds to match the new bone names
	for mesh : MeshInstance3D in src_skeleton.find_children("*", "MeshInstance3D"):
		var skin := mesh.skin
		if not skin: continue
		for i in skin.get_bind_count():
			var old_name := skin.get_bind_name(i)
			var new_name := _RPM_TO_HUMANOID.get(old_name, "")
			if new_name != "":
				skin.set_bind_name(i, new_name)


# This method rotates the bones as defined in the Godot Humanoid standard
static func _rotate_bones(src_skeleton : Skeleton3D) -> void:
	# Build the Godot Humanoid profile skeleton
	var profile := SkeletonProfileHumanoid.new()
	var prof_skeleton := Skeleton3D.new()
	for i in profile.bone_size:			# Create bones
		prof_skeleton.add_bone(profile.get_bone_name(i))
		prof_skeleton.set_bone_rest(i, profile.get_reference_pose(i))
	for i in profile.bone_size:			# Set bone parents
		var parent := profile.find_bone(profile.get_bone_parent(i))
		if parent >= 0:
			prof_skeleton.set_bone_parent(i, parent)

	# Save the diffs when rotating
	var diffs : Array[Basis] = []
	diffs.resize(src_skeleton.get_bone_count())
	diffs.fill(Basis.IDENTITY)

	# Overwrite the axes
	var bones_to_process := src_skeleton.get_parentless_bones()
	while bones_to_process.size():	# Walk bones from root to leaf
		var src_idx := bones_to_process[0]
		bones_to_process.remove_at(0)
		bones_to_process.append_array(src_skeleton.get_bone_children(src_idx))

		# Get the parent global rest
		var src_pg := Basis.IDENTITY
		var src_parent_idx := src_skeleton.get_bone_parent(src_idx)
		if src_parent_idx >= 0:
			src_pg = src_skeleton.get_bone_global_rest(src_parent_idx).basis

		# Get the rotation as defined by the profile
		var tgt_rot := Basis.IDENTITY
		var prof_idx := profile.find_bone(src_skeleton.get_bone_name(src_idx))
		if prof_idx >= 0:
			tgt_rot = src_pg.inverse() * prof_skeleton.get_bone_global_rest(prof_idx).basis

		# Save the differences for each bone
		if src_parent_idx >= 0:
			diffs[src_idx] = \
				tgt_rot.inverse() * \
				diffs[src_parent_idx] * \
				src_skeleton.get_bone_rest(src_idx).basis
		else:
			diffs[src_idx] = tgt_rot.inverse() * src_skeleton.get_bone_rest(src_idx).basis

		var diff := Basis.IDENTITY
		if src_parent_idx >= 0:
			diff = diffs[src_parent_idx]

		src_skeleton.set_bone_rest(
			src_idx,
			Transform3D(
				tgt_rot,
				diff * src_skeleton.get_bone_rest(src_idx).origin))


# This method moves the skeleton pose to the rest pose
static func _to_rest(src_skeleton : Skeleton3D) -> void:
	# Init skeleton pose to new rest
	for i in src_skeleton.get_bone_count():
		var fixed_rest := src_skeleton.get_bone_rest(i)
		src_skeleton.set_bone_pose_position(i, fixed_rest.origin)
		src_skeleton.set_bone_pose_rotation(i, fixed_rest.basis.get_rotation_quaternion())

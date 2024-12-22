# Godot ReadyPlayerMe Avatar

![GitHub forks](https://img.shields.io/github/forks/Malcolmnixon/GodotReadyPlayerMeAvatar?style=plastic)
![GitHub Repo stars](https://img.shields.io/github/stars/Malcolmnixon/GodotReadyPlayerMeAvatar?style=plastic)
![GitHub contributors](https://img.shields.io/github/contributors/Malcolmnixon/GodotReadyPlayerMeAvatar?style=plastic)
![GitHub](https://img.shields.io/github/license/Malcolmnixon/GodotReadyPlayerMeAvatar?style=plastic)

This repository contains a [Ready Player Me](https://readyplayer.me/) avatar loader for Godot that can load avatars at runtime from the internet or local files, and can configure them to be driven through the XR tracker system.

![Avatar Demo](/docs/avatar_demo.png)

## Versions

Official releases are tagged and can be found [here](https://github.com/Malcolmnixon/GodotReadyPlayerMeAvatar/releases).

The following branches are in active development:
|  Branch   |  Description                  |  Godot version   |
|-----------|-------------------------------|------------------|
|  master   | Current development branch    |  Godot 4.3       |

## Overview

Ready Player Me is an avatar system for games, apps, and VR/AR experiences. Avatars can be created online through the web interface; and then downloaded over a REST interface.

The Godot ReadyPlayerMe Avatar plugin supports downloading avatars given their avatar ID. The avatars are downloaded and parsed in the background and then provided to the user code as nodes ready for adding to a scene.

## Usage

The following steps show how to add the Godot ReadyPlayerMe Avatar plugin to a project.

### Enable Plugin

The addon files need to be copied to the `/addons/godot_rpm_avatar` folder of the Godot project, and then enabled in the Plugins under the Project Settings:
![Enable Plugin](/docs/enable_plugin.png)

Once enabled, the `rpm_loader.gd` script will be configured as an autoload node called `RpmLoader`.

### Configuring Avatars

An `RpmSettings` resource is used to configure how avatars are loaded:
![RPM Settings](/docs/rpm_settings.png)
* `body_tracker` - The name of the [XRBodyTracker](https://docs.godotengine.org/en/latest/classes/class_xrbodytracker.html#class-xrbodytracker) to drive the avatar
* `face_tracker` - The name of the [XRFaceTracker](https://docs.godotengine.org/en/latest/classes/class_xrfacetracker.html) to drive the avatar
* `quality` - Quality of the avatar to load

### Load Signals

The `RpmLoader` signals are emitted to report load events:
```gdscript
# Subscribe to load events
RpmLoader.load_complete.connect(_on_load_complete)
RpmLoader.load_failed.connect(_on_load_failed)

# Handle load success
func _on_load_complete(id : String, avatar : Node3D) -> void:
    add_child(avatar)

# Handle load failed
func _on_load_failed(id : String, reason : String) -> void:
    print("Failed to load avatar ", id, " because ", reason)
```

### Load Methods

The `RpmLoader` exposes methods to load the avatars:
```gdscript
# Start loading avatar "65fa409029044c117cbd3e3c" from the web
RpmLoader.load_web("65fa409029044c117cbd3e3c")

# Start loading avatar "66039f031791600d6e5147b0" from file
RpmLoader.load_file("C:/temp/66039f031791600d6e5147b0.glb", "66039f031791600d6e5147b0")
```

### Avatar Format

All avatars must be in the `T` pose or the avatar will be corrupted. The `load_web` method provides the following download parameters:

| Parameter | Value |
| :---- | :---- |
| `quality` | `low` / `medium` / `high` |
| `pose` | `T` |
| `morphTargets` | `Default` / `ARKit` |

See the [ReadyPlayerMe 3D Avatars Rest API](https://docs.readyplayer.me/ready-player-me/api-reference/rest-api/avatars/get-3d-avatars) documentation for a complete list of parameters.

## Licensing

Code in this repository is licensed under the MIT license.

## About this repository

This repository was created by Malcolm Nixon

It is primarily maintained by:
- [Malcolm Nixon](https://github.com/Malcolmnixon/)

For further contributors please see `CONTRIBUTORS.md`

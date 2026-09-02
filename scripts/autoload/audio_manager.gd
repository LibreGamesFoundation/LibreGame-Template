extends Node
## Global manager for one-shot audio playback.
##
## Spawns temporary [AudioStreamPlayer]/[AudioStreamPlayer3D] instances, plays them,
## and frees them automatically when finished. Autoloaded as [code]AudioManager[/code];
## call from anywhere without needing a reference to a specific node.
##

signal audio_started(stream : AudioStream)
signal audio_finished(stream : AudioStream)

@export_category("Debug")
@export var debug : bool = false

#----------------#
# Public Methods #
#----------------#

## Plays a non-positional [param stream] (UI sounds, music stingers, etc.).
## [param volume_linear] is a linear energy scale where 1.0 = 0 dB.
func play_audio(stream : AudioStream, volume_linear : float = 1.0, bus : StringName = "Master") -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(volume_linear)
	player.bus = bus

	player.finished.connect(_on_audio_finished.bind(player, stream))
	add_child(player)
	player.play()

	if debug: print("AudioManager: playing '%s' at %.2f linear volume on bus '%s'" % [stream.resource_path, volume_linear, bus])
	audio_started.emit(stream)


## Plays a positional [param stream] at [param position] in 3D space (footsteps,
## impacts, world SFX). [param volume_linear] is a linear energy scale where
## 1.0 = 0 dB.
func play_audio_3d(stream : AudioStream, position : Vector3, volume_linear : float = 1.0, unit_size : float = 10.0, bus : StringName = "Master") -> void:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.position = position
	player.volume_db = linear_to_db(volume_linear)
	player.unit_size = unit_size
	player.bus = bus

	player.finished.connect(_on_audio_finished.bind(player, stream))
	add_child(player)
	player.play()

	if debug: print("AudioManager: playing '%s' at %.2f linear volume, position %s, bus '%s'" % [stream.resource_path, volume_linear, position, bus])
	audio_started.emit(stream)

#-----------------#
# Private Methods #
#-----------------#

func _on_audio_finished(player : Node, stream : AudioStream) -> void:
	if debug: print("AudioManager: finished '%s', freeing player" % stream.resource_path)
	audio_finished.emit(stream)
	player.queue_free()

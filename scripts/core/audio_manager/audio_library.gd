extends Resource
class_name AudioLibrary


@export var tracks: Dictionary [String, AudioStream] = {}


func get_stream(track_name: String) -> AudioStream:
	if tracks.has(track_name):
		return tracks[track_name]
	push_warning("[AudioLibrary] Track '%s' not found" % track_name)
	return null

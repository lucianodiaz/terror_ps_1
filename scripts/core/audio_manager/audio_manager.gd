extends Node

# Configuration

const BGM_BUS : String = "BGM"
const SFX_BUS : String = "SFX"
const POOL_SIZE : int = 12
const FADE_TIME : float = 0.8


var audio_library: AudioLibrary = preload("res://assets/audio/audio_library.tres")

# Private Variables

var _bgm_player_a : AudioStreamPlayer
var _bgm_player_b : AudioStreamPlayer
var _active_bgm : AudioStreamPlayer
var _sfx_pool : Array[AudioStreamPlayer] = []
var _tween : Tween

## When set, `finished` on this player will raise `_pending_underlay_player` to full BGM volume.
var _underlay_primary_player : AudioStreamPlayer
var _pending_underlay_player : AudioStreamPlayer
var _pending_underlay_fade_up : float = FADE_TIME


var _max_bgm_volume : float = 0.0
var _max_sfx_volume : float = 0.0

#public variables

var bgm_volume : float = 0.0 #dB
var sfx_volume : float = 0.0 #dB
var is_mute: bool = false

# initialization

func _ready() -> void:
	_assert_bus_exists(BGM_BUS)
	_assert_bus_exists(SFX_BUS)
	_setup_bgm_players()
	_setup_sfx_pool()


func _assert_bus_exists(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) < 0:
		push_error(
			(
				"[AudioManager] Audio bus '%s' is missing. "
				+ "Add it in Project Settings → Audio → Buses (default_bus_layout.tres). "
				+ "Web export will fail with invalid bus index -1."
			)
			% bus_name
		)

func _setup_bgm_players() -> void:
	_bgm_player_a = _make_bgm_player("BGM_A")
	_bgm_player_b = _make_bgm_player("BGM_B")
	_active_bgm = _bgm_player_a

func _make_bgm_player(node_name:String) -> AudioStreamPlayer:
	var p : AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = node_name
	p.bus = BGM_BUS
	p.volume_db = -80.0
	add_child(p)
	return p

func _setup_sfx_pool() -> void:
	for i in POOL_SIZE:
		var p : AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "SFX_%d" % i
		p.bus = SFX_BUS
		add_child(p)
		_sfx_pool.append(p)


# Mute/Unmute all audio
func mute(muted:bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(BGM_BUS), muted)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX_BUS), muted)
	is_mute = muted

# BGM

func play_bgm(stream_or_name:Variant, _fade: float = FADE_TIME) -> void:
	_clear_bgm_underlay_mode()

	var stream := _resolve(stream_or_name)
	if not stream:
		push_warning("[AudioManager] - play_bgm : Invalid stream or name")
		return

	if _active_bgm.stream == stream and _active_bgm.playing:
		return # already playing, don't interrupt

	var next : AudioStreamPlayer = _get_inactive_bgm()
	next.stream = stream
	next.volume_db = -80.0

	next.play()

	_crossfade(_active_bgm, next, _fade)
	_active_bgm = next


## Stop actual music with fade out (both BGM players if layered playback is active).
func stop_bgm(_fade: float = FADE_TIME) -> void:
	_clear_bgm_underlay_mode()
	if _tween:
		_tween.kill()
	if not _bgm_player_a.playing and not _bgm_player_b.playing:
		return
	_tween = create_tween().set_parallel(true)
	if _bgm_player_a.playing:
		_tween.tween_property(_bgm_player_a, "volume_db", -80.0, _fade).set_trans(Tween.TRANS_SINE)
	if _bgm_player_b.playing:
		_tween.tween_property(_bgm_player_b, "volume_db", -80.0, _fade).set_trans(Tween.TRANS_SINE)
	_tween.chain().tween_callback(
		func() -> void:
			_bgm_player_a.stop()
			_bgm_player_b.stop()
	)


## pause/resume BGM
func pause_bgm(paused: bool) -> void:
	_bgm_player_a.stream_paused = paused
	_bgm_player_b.stream_paused = paused


## Volume BUS 
func set_bgm_volume(db:float) -> void:

	bgm_volume = clamp(db, -80.0, _max_bgm_volume)
	var idx : int = AudioServer.get_bus_index(BGM_BUS)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, bgm_volume)


## Play two BGMs together: [primary] at normal volume, [underlay] ducked. When [primary] ends
## (non-looping stream), [underlay] fades up to `bgm_volume` and becomes the active BGM.
## Note: `finished` only fires when the stream does not loop.
func play_bgm_with_underlay(
	primary_stream_or_name: Variant,
	underlay_stream_or_name: Variant,
	underlay_volume_db_offset: float = -12.0,
	fade_up_underlay: float = FADE_TIME
) -> void:
	var s_primary := _resolve(primary_stream_or_name)
	var s_underlay := _resolve(underlay_stream_or_name)
	if not s_primary or not s_underlay:
		push_warning("[AudioManager] - play_bgm_with_underlay : Invalid stream or name")
		return

	_clear_bgm_underlay_mode()
	if _tween:
		_tween.kill()

	var primary_player := _active_bgm
	var underlay_player := _get_inactive_bgm()

	primary_player.stop()
	underlay_player.stop()

	primary_player.stream = s_primary
	underlay_player.stream = s_underlay

	primary_player.volume_db = bgm_volume
	underlay_player.volume_db = bgm_volume + underlay_volume_db_offset

	underlay_player.play()
	primary_player.play()

	_underlay_primary_player = primary_player
	_pending_underlay_player = underlay_player
	_pending_underlay_fade_up = fade_up_underlay
	primary_player.finished.connect(_on_underlay_primary_finished, CONNECT_ONE_SHOT)


# SFX

func play_sfx(stream_or_name:Variant, volume_db:float = 0.0, pitch:float = 1.0) -> void:
	var stream := _resolve(stream_or_name)
	if not stream:
		push_warning("[AudioManager] - play_sfx : Invalid stream or name")
		return

	var player : AudioStreamPlayer = _get_free_sfx_player()

	if not player:
		push_warning("[AudioManager] - play_sfx : No free SFX players available")
		return

	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()

func play_sfx_varied(stream: AudioStream, pitch_range:float = 0.1) -> void:
	var pitch : float = 1.0 + randf_range(-pitch_range, pitch_range)
	play_sfx(stream, 0.0, pitch)


func set_sfx_volume(db:float) -> void:
	sfx_volume = db
	sfx_volume = clamp(db, -80.0, _max_sfx_volume)
	var idx := AudioServer.get_bus_index(SFX_BUS)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, sfx_volume)



#Helpers

func _resolve(stream_or_name:Variant) -> AudioStream:
	if stream_or_name is String:
		return audio_library.get_stream(stream_or_name)
	if stream_or_name is AudioStream:
		return stream_or_name
	push_warning("[AudioManager] - _resolve : Invalid stream or name")
	return null

func _get_inactive_bgm() -> AudioStreamPlayer:
	return _bgm_player_b if _active_bgm == _bgm_player_a else _bgm_player_a


func _clear_bgm_underlay_mode() -> void:
	if _underlay_primary_player and is_instance_valid(_underlay_primary_player):
		if _underlay_primary_player.finished.is_connected(_on_underlay_primary_finished):
			_underlay_primary_player.finished.disconnect(_on_underlay_primary_finished)
	_underlay_primary_player = null
	_pending_underlay_player = null


func _on_underlay_primary_finished() -> void:
	var underlay := _pending_underlay_player
	_underlay_primary_player = null
	_pending_underlay_player = null
	if not underlay or not is_instance_valid(underlay):
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(underlay, "volume_db", bgm_volume, _pending_underlay_fade_up).set_trans(
		Tween.TRANS_SINE
	)
	_active_bgm = underlay


func _crossfade(from:AudioStreamPlayer, to: AudioStreamPlayer, duration:float) -> void:
	_clear_bgm_underlay_mode()
	if _tween:
		_tween.kill()

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(from, "volume_db", -80.0,duration).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(to, "volume_db", bgm_volume,duration).set_trans(Tween.TRANS_SINE)

	# Stop player after fade
	var stop_from := func() -> void:
		if from.volume_db <= -79.0:
			from.stop()
	_tween.chain().tween_callback(stop_from)


func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	return null
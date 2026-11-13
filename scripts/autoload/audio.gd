extends Node
## Sound effects and music (autoload "Audio").
##
## Effects are SoundCue resources in res://resources/sounds/, played by id.
## Music is MusicPlaylist resources in res://resources/music/.
## Volumes are set per bus (Music, SFX, Ambience) in default_bus_layout.tres.

const CUE_DIR := "res://resources/sounds"
const PLAYLIST_DIR := "res://resources/music"
const SFX_BUS := &"SFX"
const MUSIC_BUS := &"Music"
## How many effects can overlap before the oldest is cut off.
const VOICES := 8
const MUSIC_FADE_SECONDS := 1.2
const SILENT_DB := -60.0
## Quiet after waking up before the day's music starts.
const MORNING_MUSIC_DELAY := 3.0
## Seconds between the bird chirps that greet a new day.
const MORNING_CHIRPS: Array[float] = [0.5, 0.75, 1.3]

## How many times each cue has played. For tests and debugging.
var play_counts: Dictionary[StringName, int] = {}

var _cues: Dictionary[StringName, SoundCue] = {}
var _playlists: Dictionary[StringName, MusicPlaylist] = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _last_slot: int = 0

var _music: AudioStreamPlayer
var _playlist: MusicPlaylist
var _track: MusicTrack
## Times the current track still has to play before the next one.
var _plays_left: int = 0
var _music_fade: Tween
## Counts up on every music change, so a waiting timer can tell it is stale.
var _music_ticket: int = 0


func _ready() -> void:
	# The inventory and the night both pause the game; sound carries on.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for res: Resource in ResourceFolder.load_all(CUE_DIR):
		var cue := res as SoundCue
		if cue != null:
			_cues[cue.id] = cue
	for res: Resource in ResourceFolder.load_all(PLAYLIST_DIR):
		var playlist := res as MusicPlaylist
		if playlist != null:
			_playlists[playlist.id] = playlist

	for i: int in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = SFX_BUS
		add_child(voice)
		_voices.append(voice)
	_music = AudioStreamPlayer.new()
	_music.bus = MUSIC_BUS
	_music.finished.connect(_on_track_finished)
	add_child(_music)

	EventBus.hotbar_slot_selected.connect(_on_hotbar_slot_selected)
	EventBus.sleep_requested.connect(_on_sleep_requested)
	EventBus.shipment_paid.connect(_on_shipment_paid)
	EventBus.day_started.connect(_on_day_started)


# --- Sound effects ---

## Plays the cue with this id. An empty id does nothing, so data can leave a
## sound field blank.
func play(id: StringName) -> void:
	if id == &"":
		return
	var cue: SoundCue = _cues.get(id)
	if cue == null:
		push_warning("Audio: no sound cue '%s'" % id)
		return
	play_counts[id] = play_counts.get(id, 0) + 1
	if cue.streams.is_empty():
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	voice.stream = cue.streams.pick_random()
	voice.volume_db = cue.volume_db
	voice.pitch_scale = randf_range(cue.pitch_min, cue.pitch_max)
	voice.play()


func has_cue(id: StringName) -> bool:
	return _cues.has(id)


func cue_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_cues.keys())
	return ids


# --- Music ---

## Starts a playlist, fading out whatever was playing. Asking for the one
## already playing changes nothing.
func play_music(id: StringName) -> void:
	var playlist: MusicPlaylist = _playlists.get(id)
	if playlist == null:
		push_warning("Audio: no music playlist '%s'" % id)
		return
	if playlist == _playlist:
		return
	_playlist = playlist
	_start_next_track()


## Fades the music out. `resume_music` brings the same playlist back.
func pause_music() -> void:
	_music_ticket += 1
	_fade_music_to(SILENT_DB).tween_callback(_music.stop)


func resume_music(delay: float = 0.0) -> void:
	if _playlist == null:
		return
	_music_ticket += 1
	var ticket := _music_ticket
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if ticket != _music_ticket:
			return
	_start_next_track()


func is_music_playing() -> bool:
	return _music.playing


## Name of the playlist that is set, or an empty name.
func current_playlist() -> StringName:
	return _playlist.id if _playlist != null else &""


func _start_next_track() -> void:
	_music_ticket += 1
	if _playlist == null or _playlist.tracks.is_empty():
		_music.stop()
		return
	# Never the same track twice running, when there is a choice.
	var choices := _playlist.tracks.filter(func(t: MusicTrack) -> bool: return t != _track)
	_track = (choices if not choices.is_empty() else _playlist.tracks).pick_random()
	_plays_left = _playlist.plays_per_track
	_play_track()
	_music.volume_db = SILENT_DB
	_fade_music_to(_track.volume_db)


func _play_track() -> void:
	_plays_left -= 1
	_music.stream = _track.stream
	_music.volume_db = _track.volume_db
	_music.play()


func _on_track_finished() -> void:
	if _playlist == null:
		return
	if _plays_left > 0:
		_play_track()
		return
	var ticket := _music_ticket
	await get_tree().create_timer(_playlist.gap_seconds).timeout
	if ticket == _music_ticket:
		_start_next_track()


func _fade_music_to(volume_db: float) -> Tween:
	if _music_fade != null:
		_music_fade.kill()
	_music_fade = create_tween()
	_music_fade.tween_property(_music, "volume_db", volume_db, MUSIC_FADE_SECONDS)
	return _music_fade


# --- Game events that always sound the same ---

func _on_hotbar_slot_selected(index: int) -> void:
	if index != _last_slot:
		_last_slot = index
		play(&"select")


func _on_sleep_requested() -> void:
	play(&"sleep")
	pause_music()


func _on_shipment_paid(total: int) -> void:
	if total > 0:
		play(&"payout")


func _on_day_started(_day: int) -> void:
	resume_music(MORNING_MUSIC_DELAY)
	for wait: float in MORNING_CHIRPS:
		await get_tree().create_timer(wait).timeout
		play(&"morning")

extends CanvasLayer
## Global manager for scene transitions.
##
## Autoloaded as [code]SceneManager[/code]. Loads scenes asynchronously via
## [ResourceLoader], always fades through black, and optionally shows a loading
## screen for slower loads. Call [method change_scene] and either [code]await[/code]
## it or listen to its signals.
##
## Integrates softly with [code]GamestateManager[/code] if present: pass a
## [param target_game_state] to [method change_scene] and it will be applied once
## the new scene is ready, via duck-typed [code]change_state()[/code] — no hard
## dependency on [code]GamestateManager[/code]'s specific enum.

signal scene_load_started(scene_path : String)
signal scene_load_progress(scene_path : String, progress : float)
signal scene_load_completed(scene_path : String)
signal scene_load_failed(scene_path : String, error : Error)

@export_category("Transition Settings")
@export var fade_duration : float = 0.3
@export var fade_color : Color = Color.BLACK
## Scene shown while loading, if the load takes longer than [member loading_screen_delay].
## Must have a script that implements [code]set_progress(value : float) -> void[/code]
## (optional — skipped if absent).
@export var loading_screen_scene : PackedScene
## Seconds to wait before showing [member loading_screen_scene]. Prevents a flash
## of loading UI on near-instant loads. Ignored if [member loading_screen_scene] is unset.
@export var loading_screen_delay : float = 0.2
## Minimum seconds the loading screen stays up once shown, even if loading finishes
## sooner, to avoid an unpleasantly brief flash.
@export var loading_screen_min_duration : float = 0.5

@export_category("Debug")
@export var debug : bool = false

var _is_loading : bool = false
var _transition_params : Dictionary = {}
var _fade_rect : ColorRect
var _loading_screen : Node


func _ready() -> void:
	layer = 128  # Render above gameplay and most UI.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_fade_rect()

#----------------#
# Public Methods #
#----------------#

## Loads and switches to the scene at [param scene_path]. Fades out, loads
## asynchronously (showing [member loading_screen_scene] if the load is slow),
## swaps the scene, fades back in, then optionally applies [param target_game_state]
## via a duck-typed [code]GamestateManager.change_state()[/code] call.
##
## [param params] is stored and available to the new scene via [method take_params]
## (e.g. a spawn point ID, which save slot to load).
##
## Can be [code]await[/code]ed for completion, or ignored in favor of listening to
## [signal scene_load_completed] / [signal scene_load_failed].
func change_scene(scene_path : String, params : Dictionary = {}, target_game_state = null) -> void:
	if _is_loading:
		push_warning("SceneManager: change_scene called while already loading; ignoring.")
		return

	_is_loading = true
	_transition_params = params
	scene_load_started.emit(scene_path)
	if debug: print("SceneManager: loading '%s'" % scene_path)

	await _fade_out()

	var loaded_scene := await _load_async(scene_path)
	if loaded_scene == null:
		_is_loading = false
		await _fade_in()
		return

	get_tree().current_scene.free()
	var new_scene_instance := loaded_scene.instantiate()
	get_tree().root.add_child(new_scene_instance)
	get_tree().current_scene = new_scene_instance

	await _hide_loading_screen()
	await _fade_in()

	if target_game_state != null:
		_apply_target_game_state(target_game_state)

	if debug: print("SceneManager: '%s' ready" % scene_path)
	scene_load_completed.emit(scene_path)
	_is_loading = false


## Returns and clears the params dictionary passed to the [method change_scene] call
## that loaded the current scene. Call once from the new scene's [code]_ready()[/code].
func take_params() -> Dictionary:
	var params := _transition_params
	_transition_params = {}
	return params


## Returns true if a scene change is currently in progress.
func is_loading() -> bool:
	return _is_loading

#-----------------#
# Private Methods #
#-----------------#

func _build_fade_rect() -> void:
	_fade_rect = ColorRect.new()
	_fade_rect.color = fade_color
	_fade_rect.anchor_right = 1.0
	_fade_rect.anchor_bottom = 1.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.modulate.a = 0.0
	add_child(_fade_rect)


func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, fade_duration)
	await tween.finished


func _fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 0.0, fade_duration)
	await tween.finished


func _load_async(scene_path : String) -> PackedScene:
	var error := ResourceLoader.load_threaded_request(scene_path)
	if error != OK:
		push_error("SceneManager: failed to start loading '%s' (error %d)." % [scene_path, error])
		scene_load_failed.emit(scene_path, error)
		return null

	var elapsed := 0.0
	var loading_screen_shown := false

	while true:
		var status := ResourceLoader.load_threaded_get_status(scene_path)

		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				var progress : Array = []
				ResourceLoader.load_threaded_get_status(scene_path, progress)
				var fraction : float = progress[0] if not progress.is_empty() else 0.0
				scene_load_progress.emit(scene_path, fraction)
				if _loading_screen != null and _loading_screen.has_method("set_progress"):
					_loading_screen.set_progress(fraction)

				if not loading_screen_shown and elapsed >= loading_screen_delay:
					_show_loading_screen()
					loading_screen_shown = true

			ResourceLoader.THREAD_LOAD_LOADED:
				return ResourceLoader.load_threaded_get(scene_path)

			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("SceneManager: failed to load '%s' (status %d)." % [scene_path, status])
				scene_load_failed.emit(scene_path, ERR_CANT_ACQUIRE_RESOURCE)
				return null

		elapsed += get_process_delta_time()
		await get_tree().process_frame

	return null


func _show_loading_screen() -> void:
	if loading_screen_scene == null or _loading_screen != null:
		return
	_loading_screen = loading_screen_scene.instantiate()
	add_child(_loading_screen)
	if debug: print("SceneManager: showing loading screen")
	_loading_screen_shown_at = Time.get_ticks_msec() / 1000.0


var _loading_screen_shown_at : float = 0.0


func _hide_loading_screen() -> void:
	if _loading_screen == null:
		return

	var shown_duration := (Time.get_ticks_msec() / 1000.0) - _loading_screen_shown_at
	var remaining := loading_screen_min_duration - shown_duration
	if remaining > 0.0:
		await get_tree().create_timer(remaining).timeout

	_loading_screen.queue_free()
	_loading_screen = null
	if debug: print("SceneManager: hid loading screen")


func _apply_target_game_state(target_game_state) -> void:
	var game_state_manager := get_node_or_null("/root/GamestateManager")
	if game_state_manager == null:
		push_warning("SceneManager: target_game_state provided but GamestateManager autoload not found.")
		return
	if not game_state_manager.has_method("change_state"):
		push_warning("SceneManager: GamestateManager found but has no change_state() method.")
		return

	game_state_manager.change_state(target_game_state)
	if debug: print("SceneManager: applied target game state")

extends Node
## Global manager for collecting, writing, and restoring game save data.
##
## Autoloaded as [code]SaveManager[/code]. Discovers save participants via the
## "saveable" group ([SaveComponent]) rather than direct references.
##
## Non-persistent components are grouped by [member SaveComponent.save_category]
## and written to per-slot files under [member save_directory] (e.g.
## [code]user://saves/slot_1/player.json[/code]). Persistent components (settings,
## controls, etc.) are written once to [member settings_directory], shared across
## all slots and unaffected by [method delete_save].

signal save_started(slot_name : String)
signal save_completed(slot_name : String, success : bool)
signal load_started(slot_name : String)
signal load_completed(slot_name : String, success : bool)
signal settings_saved(success : bool)
signal settings_loaded(success : bool)

@export_category("Save Configuration")
@export var save_directory : String = "user://saves/"
@export var default_slot_name : String = "slot_1"

@export_category("Settings Configuration")
@export var settings_directory : String = "user://settings/"

@export_category("Debug")
@export var debug : bool = false

#----------------#
# Public Methods #
#----------------#

## Writes every non-persistent [SaveComponent]'s data, grouped by category,
## to [param slot_name]. Returns true on success.
func save_game(slot_name : String = default_slot_name) -> bool:
	save_started.emit(slot_name)

	var slot_dir := _get_slot_dir(slot_name)
	DirAccess.make_dir_recursive_absolute(slot_dir)

	var categories := _group_by_category(false)
	var success := true

	for category in categories:
		var category_data := _collect_category_data(categories[category])
		success = _write_json(slot_dir.path_join(String(category) + ".json"), category_data) and success

	_write_json(slot_dir.path_join("metadata.json"), _build_metadata())

	if debug: print("SaveManager: save '%s' %s (%d categories)" % [slot_name, "succeeded" if success else "failed", categories.size()])
	save_completed.emit(slot_name, success)
	return success


## Reads every category file in [param slot_name] and forwards each entry's data to
## the matching [SaveComponent] (matched by [member SaveComponent.save_id]).
## Returns true on success.
func load_game(slot_name : String = default_slot_name) -> bool:
	load_started.emit(slot_name)

	var slot_dir := _get_slot_dir(slot_name)
	if not DirAccess.dir_exists_absolute(slot_dir):
		push_warning("SaveManager: no save slot found at '%s'." % slot_dir)
		load_completed.emit(slot_name, false)
		return false

	var merged_data := _read_all_category_files(slot_dir)
	var loaded_count := _apply_to_saveables(merged_data, false)

	if debug: print("SaveManager: load '%s' restored %d component(s)" % [slot_name, loaded_count])
	load_completed.emit(slot_name, true)
	return true


## Writes every persistent [SaveComponent]'s data, grouped by category, to
## [member settings_directory]. Not tied to any save slot. Returns true on success.
func save_settings() -> bool:
	DirAccess.make_dir_recursive_absolute(settings_directory)

	var categories := _group_by_category(true)
	var success := true

	for category in categories:
		var category_data := _collect_category_data(categories[category])
		success = _write_json(settings_directory.path_join(String(category) + ".json"), category_data) and success

	if debug: print("SaveManager: settings save %s" % ("succeeded" if success else "failed"))
	settings_saved.emit(success)
	return success


## Reads every category file in [member settings_directory] and forwards data to
## matching persistent [SaveComponent]s. Returns true on success. Call this at
## game boot, independent of [method load_game].
func load_settings() -> bool:
	if not DirAccess.dir_exists_absolute(settings_directory):
		settings_loaded.emit(false)
		return false

	var merged_data := _read_all_category_files(settings_directory)
	var loaded_count := _apply_to_saveables(merged_data, true)

	if debug: print("SaveManager: settings load restored %d component(s)" % loaded_count)
	settings_loaded.emit(true)
	return true


## Returns true if [param slot_name] exists on disk.
func save_exists(slot_name : String = default_slot_name) -> bool:
	return DirAccess.dir_exists_absolute(_get_slot_dir(slot_name))


## Deletes [param slot_name] and all its category files. Does not affect
## [member settings_directory].
func delete_save(slot_name : String = default_slot_name) -> void:
	var slot_dir := _get_slot_dir(slot_name)
	if not DirAccess.dir_exists_absolute(slot_dir):
		return
	_delete_directory_recursive(slot_dir)
	if debug: print("SaveManager: deleted save '%s'" % slot_name)


## Returns the names of all existing save slots under [member save_directory].
func list_saves() -> Array[String]:
	var slots : Array[String] = []
	var dir := DirAccess.open(save_directory)
	if dir == null:
		return slots

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			slots.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()

	return slots


## Returns [param slot_name]'s metadata (timestamp, scene, etc.) without loading
## and applying the full save. Returns an empty [Dictionary] if the slot has no
## metadata file.
func get_save_metadata(slot_name : String = default_slot_name) -> Dictionary:
	return _read_json(_get_slot_dir(slot_name).path_join("metadata.json"))

#-----------------#
# Private Methods #
#-----------------#

func _get_slot_dir(slot_name : String) -> String:
	return save_directory.path_join(slot_name)


func _group_by_category(persistent_filter : bool) -> Dictionary:
	var categories : Dictionary = {}
	for saveable in get_tree().get_nodes_in_group("saveable"):
		if not saveable is SaveComponent:
			continue
		if saveable.persistent != persistent_filter:
			continue
		if saveable.save_id.is_empty():
			push_warning("SaveManager: skipping a SaveComponent with no save_id.")
			continue

		if not categories.has(saveable.save_category):
			categories[saveable.save_category] = []
		categories[saveable.save_category].append(saveable)

	return categories


func _collect_category_data(saveables : Array) -> Dictionary:
	var category_data : Dictionary = {}
	for saveable in saveables:
		category_data[saveable.save_id] = saveable.get_save_data()
	return category_data


func _read_all_category_files(directory : String) -> Dictionary:
	var merged : Dictionary = {}
	var dir := DirAccess.open(directory)
	if dir == null:
		return merged

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".json") and entry != "metadata.json":
			var category_data := _read_json(directory.path_join(entry))
			merged.merge(category_data)
		entry = dir.get_next()
	dir.list_dir_end()

	return merged


func _apply_to_saveables(merged_data : Dictionary, persistent_filter : bool) -> int:
	var loaded_count := 0
	for saveable in get_tree().get_nodes_in_group("saveable"):
		if not saveable is SaveComponent:
			continue
		if saveable.persistent != persistent_filter:
			continue
		if not merged_data.has(saveable.save_id):
			continue
		saveable.load_save_data(merged_data[saveable.save_id])
		loaded_count += 1
	return loaded_count


func _build_metadata() -> Dictionary:
	return {
		"timestamp": Time.get_datetime_string_from_system(),
		"scene": get_tree().current_scene.scene_file_path if get_tree().current_scene else "",
	}


func _write_json(path : String, data : Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: failed to open '%s' for writing (error %d)." % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func _read_json(path : String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: failed to open '%s' for reading (error %d)." % [path, FileAccess.get_open_error()])
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if parsed == null or not parsed is Dictionary:
		push_error("SaveManager: '%s' does not contain valid save data." % path)
		return {}

	return parsed


func _delete_directory_recursive(path : String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var entry_path := path.path_join(entry)
		if dir.current_is_dir() and not entry.begins_with("."):
			_delete_directory_recursive(entry_path)
		elif not dir.current_is_dir():
			DirAccess.remove_absolute(entry_path)
		entry = dir.get_next()
	dir.list_dir_end()

	DirAccess.remove_absolute(path)

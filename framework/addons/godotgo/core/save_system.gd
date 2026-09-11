class_name SaveSystem
extends RefCounted
## JSON save slots under [code]user://saves/[/code], stamped with a schema
## version so old files can be detected instead of crashing a load.
##
## [codeblock]
## SaveSystem.store("progress", {"level": 3, "best": 1200})
## var data := SaveSystem.fetch("progress", {"level": 1, "best": 0})
## [/codeblock]

const DIR := "user://saves"
## Bumped when the envelope format changes. Slots written by a newer version are
## refused rather than misread.
const VERSION := 1

const _ALLOWED_SLOT_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789-_"


## Absolute [code]user://[/code] path of a slot's file.
static func path_for(slot: String) -> String:
	return "%s/%s.json" % [DIR, sanitize(slot)]


## Lower-cases a slot name and strips anything that is not a safe filename character.
static func sanitize(slot: String) -> String:
	var out := ""
	for c in slot.to_lower():
		out += c if _ALLOWED_SLOT_CHARS.contains(c) else "_"
	return out if not out.is_empty() else "default"


## Writes [param data] to a slot. Returns [constant OK] or the file error.
static func store(slot: String, data: Dictionary) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(DIR)
	if err != OK and err != ERR_ALREADY_EXISTS:
		return err
	var file := FileAccess.open(path_for(slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var envelope := {
		"version": VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"data": data,
	}
	file.store_string(JSON.stringify(envelope, "\t"))
	file.close()
	return OK


## Reads a slot. Returns [param fallback] when the slot is missing, unreadable,
## malformed, or written by a newer [constant VERSION].
static func fetch(slot: String, fallback: Dictionary = {}) -> Dictionary:
	var path := path_for(slot)
	if not FileAccess.file_exists(path):
		return fallback
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("SaveSystem: cannot open %s" % path)
		return fallback
	var text := file.get_as_text()
	file.close()
	# JSON.new().parse() reports malformed input by return code; the static
	# JSON.parse_string() would also print an engine error for every bad file.
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		push_warning("SaveSystem: %s is not a JSON object" % path)
		return fallback
	var envelope: Dictionary = json.data
	var version := int(envelope.get("version", 0))
	if version > VERSION:
		push_warning(
			(
				"SaveSystem: %s was written by version %d, this build reads %d"
				% [path, version, VERSION]
			)
		)
		return fallback
	var data: Variant = envelope.get("data", {})
	return data if data is Dictionary else fallback


static func has_slot(slot: String) -> bool:
	return FileAccess.file_exists(path_for(slot))


## Deletes a slot. Returns [constant OK] when the slot is gone afterwards.
static func erase(slot: String) -> Error:
	var path := path_for(slot)
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Slot names currently on disk, sorted.
static func slots() -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return found
	for file_name in dir.get_files():
		if file_name.ends_with(".json"):
			found.append(file_name.get_basename())
	found.sort()
	return found

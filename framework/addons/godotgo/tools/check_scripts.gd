extends SceneTree
## Loads scripts, scenes and resources to validate them, then exits 1 if any
## failed. Unlike [code]godot --check-only[/code] this runs inside a live
## SceneTree, so autoload singletons resolve, [code]class_name[/code] lookups
## work and .tscn/.tres files are validated as well. It is also the only form
## that reports failure on macOS, where --check-only always exits 0.
##
## Usage:
##   godot --headless --path <project> --script res://addons/godotgo/tools/check_scripts.gd
##   godot --headless --path <project> --script res://addons/godotgo/tools/check_scripts.gd \
##       -- scripts/level.gd scenes/main.tscn
##
## With no file arguments it scans the whole project, skipping SKIPPED_DIRS.
## Callers that want the shared addon checked (the framework project does) pass
## files explicitly; tools/check.sh always does.

const SKIPPED_DIRS: Array[String] = [".godot", ".git", "addons"]
const CHECKED_EXTENSIONS: Array[String] = ["gd", "tscn", "tres"]


func _initialize() -> void:
	var targets := _targets_from_args()
	if targets.is_empty():
		targets = _scan("res://")
	var failed: PackedStringArray = []
	for path in targets:
		if not _loads(path):
			failed.append(path)
			printerr("FAIL %s" % path)
	print("checked %d files, %d failed" % [targets.size(), failed.size()])
	quit(1 if not failed.is_empty() else 0)


func _targets_from_args() -> PackedStringArray:
	var targets: PackedStringArray = []
	for arg in OS.get_cmdline_user_args():
		var path: String = arg
		if not path.begins_with("res://"):
			path = "res://" + path.trim_prefix("./")
		targets.append(path)
	return targets


func _scan(root: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(root)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var path := root.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with(".") and not SKIPPED_DIRS.has(entry):
				found.append_array(_scan(path))
		elif CHECKED_EXTENSIONS.has(entry.get_extension()):
			found.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	found.sort()
	return found


## True when the resource loads and, for scripts, compiles to something usable.
func _loads(path: String) -> bool:
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		printerr("%s: file not found" % path)
		return false
	var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if res == null:
		return false
	if res is Script:
		return (res as Script).can_instantiate()
	return true

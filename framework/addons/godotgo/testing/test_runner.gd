extends SceneTree
## Zero-dependency headless test runner.
##
## Usage:
##   tools/godot.sh --headless --path . --script res://tests/test_runner.gd
##   tools/godot.sh --headless --path . --script res://tests/test_runner.gd -- --filter=player
##
## Discovers tests/unit/**/test_*.gd, instantiates each (must extend GodotGoTest),
## runs every test_* method, prints a summary, and exits 1 on any failure.

const TEST_ROOT := "res://tests/unit"

var _filter := ""
var _total := 0
var _failed := 0
var _skipped := 0


func _initialize() -> void:
	_parse_args()
	_run_all()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			_filter = arg.trim_prefix("--filter=")


func _run_all() -> void:
	# Let the tree finish initializing: nodes added before the first frame are
	# not inside the tree yet, so global transforms would error.
	await process_frame
	var scripts := _discover(TEST_ROOT)
	for path in scripts:
		await _run_script(path)
	# A project with no tests must not report success: an empty suite looks
	# identical to a passing one, which is how a game ships unverified.
	# A filter that matches nothing is a different thing and only warns.
	if _total == 0:
		if _filter.is_empty():
			printerr("FAILED: no tests found under %s" % TEST_ROOT)
			quit(1)
			return
		push_warning("No test matched the filter %s" % _filter)
	# Drain the deletion queue so nodes freed by the last test are actually gone
	# before the tree shuts down; otherwise Godot reports them as leaks at exit.
	for i in 3:
		await process_frame
	print("")
	if _failed == 0:
		print("PASSED: %d tests (%d skipped)" % [_total, _skipped])
	else:
		printerr("FAILED: %d of %d tests" % [_failed, _total])
	quit(1 if _failed > 0 else 0)


func _discover(root: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(root)
	if dir == null:
		return found
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		var path := root.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				found.append_array(_discover(path))
		elif name.begins_with("test_") and name.ends_with(".gd"):
			found.append(path)
		name = dir.get_next()
	dir.list_dir_end()
	found.sort()
	return found


func _run_script(path: String) -> void:
	var script: GDScript = load(path)
	if script == null:
		_report_failure(path, "<load>", ["script failed to load"])
		return
	var suite_filter_hit := _filter.is_empty() or path.get_file().contains(_filter)
	for method in script.get_script_method_list():
		var method_name: String = method.name
		if not method_name.begins_with("test_"):
			continue
		if not suite_filter_hit and not method_name.contains(_filter):
			continue
		await _run_test(script, path, method_name)


func _run_test(script: GDScript, path: String, method_name: String) -> void:
	var test: GodotGoTest = script.new()
	if test == null:
		_report_failure(path, method_name, ["test scripts must extend GodotGoTest"])
		return
	test.tree = self
	_total += 1
	await test.before_each()
	await test.call(method_name)
	await test.after_each()
	test._teardown()
	if not test._skip_reason.is_empty():
		_skipped += 1
		print("  skip %s::%s (%s)" % [path.get_file(), method_name, test._skip_reason])
	elif test._failures.is_empty():
		print("  ok   %s::%s (%d asserts)" % [path.get_file(), method_name, test._assert_count])
	else:
		_report_failure(path, method_name, test._failures)


func _report_failure(path: String, method_name: String, messages: PackedStringArray) -> void:
	_failed += 1
	printerr("  FAIL %s::%s" % [path.get_file(), method_name])
	for msg in messages:
		printerr("       - %s" % msg)

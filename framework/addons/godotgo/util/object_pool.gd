class_name ObjectPool
extends Node
## Reuses instances of a [PackedScene] instead of allocating one per spawn.
##
## Spare instances are held outside the scene tree; [method acquire] hands one
## back for the caller to add wherever it likes, and [method release] takes it
## out of the tree and returns it to the pool.
##
## [codeblock]
## var bullet := pool.acquire()
## if bullet:
##     add_child(bullet)
##     bullet.global_position = muzzle.global_position
## # later
## pool.release(bullet)
## [/codeblock]
##
## A pooled scene may implement [code]pool_acquired()[/code] and
## [code]pool_released()[/code] to reset its own state; the pool calls them when
## they exist.

signal acquired(node: Node)
signal released(node: Node)

## The scene instantiated for every pooled object.
@export var scene: PackedScene
## Instances created up front in [method _ready].
@export_range(0, 512, 1) var initial_size := 0
## Refuse to create more than this many live instances. 0 means no ceiling.
@export_range(0, 4096, 1) var max_size := 0

var _free: Array[Node] = []
var _in_use: Dictionary[int, Node] = {}
var _created := 0


func _ready() -> void:
	prewarm(initial_size)


func _exit_tree() -> void:
	for node in _free:
		if is_instance_valid(node):
			node.free()
	_free.clear()
	# An instance that was handed out but never released and never added to the
	# tree has no other owner, so the pool frees it rather than leaking it.
	# Anything the caller did parent stays theirs to free.
	for node in _in_use.values():
		if is_instance_valid(node) and node.get_parent() == null:
			node.free()
	_in_use.clear()


## Creates instances ahead of time so the first spawns do not allocate.
func prewarm(count: int) -> void:
	for i in count:
		var node := _instantiate()
		if node == null:
			return
		_free.append(node)


## Returns a ready instance that is not in the tree, or null when [member scene]
## is unset or [member max_size] is reached.
func acquire() -> Node:
	var node: Node
	if not _free.is_empty():
		node = _free.pop_back()
	else:
		node = _instantiate()
	if node == null:
		return null
	_in_use[node.get_instance_id()] = node
	if node.has_method(&"pool_acquired"):
		node.call(&"pool_acquired")
	acquired.emit(node)
	return node


## Removes [param node] from the tree and returns it to the pool. Releasing a
## node twice, or one from another pool, is reported and ignored.
func release(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var id := node.get_instance_id()
	if not _in_use.has(id):
		push_error("ObjectPool: released a node that this pool did not hand out: %s" % node)
		return
	_in_use.erase(id)
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	if node.has_method(&"pool_released"):
		node.call(&"pool_released")
	_free.append(node)
	released.emit(node)


## Releases everything currently handed out.
func release_all() -> void:
	for node in _in_use.values().duplicate():
		release(node)


## Instances currently handed out.
func in_use() -> int:
	return _in_use.size()


## Spare instances ready to hand out.
func available() -> int:
	return _free.size()


## Instances this pool has ever created.
func created() -> int:
	return _created


func _instantiate() -> Node:
	if scene == null:
		push_error("ObjectPool: no scene assigned on %s" % get_path())
		return null
	if max_size > 0 and _created >= max_size:
		return null
	_created += 1
	return scene.instantiate()

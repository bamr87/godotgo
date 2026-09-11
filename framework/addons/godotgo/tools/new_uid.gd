extends SceneTree
## Prints a fresh Godot resource UID for use in hand-written .tscn/.tres files.
## Usage: tools/godot.sh --headless --path . --script res://scripts/tools/new_uid.gd


func _initialize() -> void:
	print(ResourceUID.id_to_text(ResourceUID.create_id()))
	quit()

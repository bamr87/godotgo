class_name MaterialMakerLoader
extends RefCounted
## Loads a Material Maker Godot export (StandardMaterial3D .tres) or builds
## one from PBR maps sitting next to the material.
##
## Usage:
## [codeblock]
## var mat := MaterialMakerLoader.load_material("res://materials/rust", "rust")
## $MeshInstance3D.material_override = mat
## [/codeblock]

## StandardMaterial3D texture property -> candidate file names, tried in order.
## "%s" is replaced with the material stem (the .tres name without extension).
const MAP_CANDIDATES: Dictionary[String, Array] = {
	"albedo_texture": ["%s_albedo.png", "albedo.png", "%s_diffuse.png"],
	"normal_texture": ["%s_normal.png", "normal.png", "%s_nrm.png"],
	"roughness_texture": ["%s_roughness.png", "roughness.png", "%s_rough.png"],
	"metallic_texture": ["%s_metallic.png", "metallic.png", "%s_metal.png"],
	"ao_texture": ["%s_ao.png", "ao.png", "%s_occlusion.png"],
	"emission_texture": ["%s_emission.png", "emission.png", "%s_emit.png"],
	"heightmap_texture": ["%s_heightmap.png", "%s_height.png", "height.png", "%s_disp.png"],
}

## Packed occlusion/roughness/metallic map as written by Material Maker's
## "Godot 4 Standard" export. Used when the separate maps are absent.
const ORM_CANDIDATES: Array = ["%s_orm.png", "orm.png"]

## ORM channel layout (glTF convention): R = ambient occlusion, G = roughness, B = metallic.
const ORM_CHANNELS: Dictionary[String, BaseMaterial3D.TextureChannel] = {
	"ao_texture": BaseMaterial3D.TEXTURE_CHANNEL_RED,
	"roughness_texture": BaseMaterial3D.TEXTURE_CHANNEL_GREEN,
	"metallic_texture": BaseMaterial3D.TEXTURE_CHANNEL_BLUE,
}

## Texture properties whose feature toggle must be switched on for the map to render.
const FEATURE_FLAGS: Dictionary[String, String] = {
	"normal_texture": "normal_enabled",
	"ao_texture": "ao_enabled",
	"emission_texture": "emission_enabled",
	"heightmap_texture": "heightmap_enabled",
}


## Returns the exported .tres at [code]material_dir/material_name.tres[/code] when it
## exists, otherwise a StandardMaterial3D assembled from whichever PBR maps are present.
## [param material_name] defaults to the directory name.
static func load_material(material_dir: String, material_name: String = "") -> StandardMaterial3D:
	var dir := material_dir.trim_suffix("/")
	var stem := material_name if not material_name.is_empty() else dir.get_file()
	var tres_path := "%s/%s.tres" % [dir, stem]
	if ResourceLoader.exists(tres_path):
		var loaded := load(tres_path)
		if loaded is StandardMaterial3D:
			return loaded
	return _from_maps(dir, stem)


## Lists which maps [method load_material] would pick up for a material, keyed by
## StandardMaterial3D property. A packed ORM map is reported under the key "orm".
## Useful for tooling and tests.
static func find_maps(material_dir: String, stem: String) -> Dictionary[String, String]:
	var dir := material_dir.trim_suffix("/")
	var found: Dictionary[String, String] = {}
	for property in MAP_CANDIDATES:
		var path := _first_existing(dir, stem, MAP_CANDIDATES[property])
		if not path.is_empty():
			found[property] = path
	var orm := _first_existing(dir, stem, ORM_CANDIDATES)
	if not orm.is_empty():
		found["orm"] = orm
	return found


static func _from_maps(dir: String, stem: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var maps := find_maps(dir, stem)
	for property in maps:
		if property == "orm":
			continue
		var texture := load(maps[property])
		if not texture is Texture2D:
			continue
		material.set(property, texture)
		if FEATURE_FLAGS.has(property):
			material.set(FEATURE_FLAGS[property], true)
	if maps.has("orm"):
		_apply_orm(material, load(maps["orm"]))
	if material.metallic_texture != null:
		material.metallic = 1.0
	return material


## Assigns one packed ORM texture to the AO, roughness and metallic slots with the
## right channel selectors, without overriding maps that were found separately.
static func _apply_orm(material: StandardMaterial3D, texture: Texture2D) -> void:
	if texture == null:
		return
	for property in ORM_CHANNELS:
		if material.get(property) != null:
			continue
		material.set(property, texture)
		material.set(property + "_channel", ORM_CHANNELS[property])
		if FEATURE_FLAGS.has(property):
			material.set(FEATURE_FLAGS[property], true)


static func _first_existing(dir: String, stem: String, patterns: Array) -> String:
	for pattern: String in patterns:
		var path := "%s/%s" % [dir, pattern % stem if pattern.contains("%s") else pattern]
		if ResourceLoader.exists(path):
			return path
	return ""

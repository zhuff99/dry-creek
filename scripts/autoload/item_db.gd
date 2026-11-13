extends Node
## Index of every item and crop resource by id (autoload "ItemDB").
##
## Anything that needs to persist (inventory, farm plots) stores ids and looks
## the resource up here, so save files never contain object references.

const ITEM_DIR := "res://resources/items"
const CROP_DIR := "res://resources/crops"

var _items: Dictionary[StringName, ItemData] = {}
var _crops: Dictionary[StringName, CropData] = {}


func _ready() -> void:
	for res: Resource in _load_all(ITEM_DIR):
		var item := res as ItemData
		if item != null:
			_items[item.id] = item
	for res: Resource in _load_all(CROP_DIR):
		var crop := res as CropData
		if crop != null:
			_crops[crop.id] = crop


func get_item(id: StringName) -> ItemData:
	var item: ItemData = _items.get(id)
	if item == null:
		push_error("ItemDB: unknown item id '%s'" % id)
	return item


func get_crop(id: StringName) -> CropData:
	var crop: CropData = _crops.get(id)
	if crop == null:
		push_error("ItemDB: unknown crop id '%s'" % id)
	return crop


func _load_all(dir_path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("ItemDB: cannot open %s" % dir_path)
		return out
	for file: String in dir.get_files():
		# Exported builds list resources as "name.tres.remap".
		var clean := file.trim_suffix(".remap")
		if clean.ends_with(".tres") or clean.ends_with(".res"):
			out.append(load(dir_path.path_join(clean)))
	for sub: String in dir.get_directories():
		out.append_array(_load_all(dir_path.path_join(sub)))
	return out

extends Node
## Index of every item, crop and debris resource by id (autoload "ItemDB").
##
## Anything that needs to persist (inventory, farm plots) stores ids and looks
## the resource up here, so save files never contain object references.

const ITEM_DIR := "res://resources/items"
const CROP_DIR := "res://resources/crops"
const DEBRIS_DIR := "res://resources/debris"

var _items: Dictionary[StringName, ItemData] = {}
var _crops: Dictionary[StringName, CropData] = {}
var _debris: Dictionary[StringName, DebrisData] = {}


func _ready() -> void:
	for res: Resource in ResourceFolder.load_all(ITEM_DIR):
		var item := res as ItemData
		if item != null:
			_items[item.id] = item
	for res: Resource in ResourceFolder.load_all(CROP_DIR):
		var crop := res as CropData
		if crop != null:
			_crops[crop.id] = crop
	for res: Resource in ResourceFolder.load_all(DEBRIS_DIR):
		var debris := res as DebrisData
		if debris != null:
			_debris[debris.id] = debris


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


func get_debris(id: StringName) -> DebrisData:
	var debris: DebrisData = _debris.get(id)
	if debris == null:
		push_error("ItemDB: unknown debris id '%s'" % id)
	return debris

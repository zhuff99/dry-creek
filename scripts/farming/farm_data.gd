class_name FarmData
extends RefCounted
## All tilled plots on the ranch, which debris has been cleared, and the rules
## for changing them.
##
## Holds no nodes. FarmGrid draws it when the farm scene is loaded, but
## advance_day() works without a scene, so crops keep growing (or drying out)
## while the player is elsewhere.

## A plot was added, changed, or needs redrawing.
signal plot_changed(cell: Vector2i)
## A rock, tree or patch of brush was removed for good.
signal debris_cleared(cell: Vector2i)

var plots: Dictionary[Vector2i, FarmPlot] = {}
## Cells whose debris is gone. The map itself is never edited, so this is what
## a save needs to remember. Used as a set; the value is always true.
var cleared_debris: Dictionary[Vector2i, bool] = {}
## Hits landed so far on debris that takes more than one.
var debris_damage: Dictionary[Vector2i, int] = {}


func get_plot(cell: Vector2i) -> FarmPlot:
	return plots.get(cell)


func is_tilled(cell: Vector2i) -> bool:
	return plots.has(cell)


## The crop planted at `cell`, or null.
func get_crop(cell: Vector2i) -> CropData:
	var plot := get_plot(cell)
	if plot == null or not plot.has_crop():
		return null
	return ItemDB.get_crop(plot.crop_id)


func till(cell: Vector2i) -> bool:
	if plots.has(cell):
		return false
	plots[cell] = FarmPlot.new()
	plot_changed.emit(cell)
	return true


func water(cell: Vector2i) -> bool:
	var plot := get_plot(cell)
	if plot == null or plot.watered:
		return false
	plot.watered = true
	plot_changed.emit(cell)
	return true


func can_plant(cell: Vector2i) -> bool:
	var plot := get_plot(cell)
	return plot != null and not plot.has_crop()


func plant(cell: Vector2i, crop: CropData) -> bool:
	if not can_plant(cell):
		return false
	var plot := get_plot(cell)
	plot.crop_id = crop.id
	plot.days_grown = 0
	plot_changed.emit(cell)
	return true


func can_harvest(cell: Vector2i) -> bool:
	var crop := get_crop(cell)
	return crop != null and crop.is_mature(get_plot(cell).days_grown)


## Picks the ripe crop at `cell` and returns what it yielded, or null.
func harvest(cell: Vector2i) -> ItemStack:
	if not can_harvest(cell):
		return null
	var plot := get_plot(cell)
	var crop := get_crop(cell)
	var amount := randi_range(crop.harvest_min, crop.harvest_max)
	if crop.regrow_days > 0:
		# Step growth back so it needs regrow_days more watered days.
		plot.days_grown = maxi(0, crop.days_to_mature - crop.regrow_days)
	else:
		plot.crop_id = &""
		plot.days_grown = 0
	plot_changed.emit(cell)
	return ItemStack.new(crop.harvest_item, amount)


## Lands one tool hit on the debris at `cell`, which takes `hits_needed` in
## total. Returns true if this hit removed it.
func hit_debris(cell: Vector2i, hits_needed: int) -> bool:
	var damage: int = debris_damage.get(cell, 0) + 1
	if damage < hits_needed:
		debris_damage[cell] = damage
		return false
	debris_damage.erase(cell)
	cleared_debris[cell] = true
	debris_cleared.emit(cell)
	return true


## Overnight update: watered crops grow a day, then all soil dries out.
func advance_day() -> void:
	for cell: Vector2i in plots:
		var plot: FarmPlot = plots[cell]
		if plot.has_crop() and plot.watered:
			plot.days_grown += 1
		plot.watered = false
		plot_changed.emit(cell)

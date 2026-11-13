class_name ResourceFolder
## Loads every .tres/.res under a folder. The databases (ItemDB, Audio) use
## this so adding a resource file is all it takes to add an item or a sound.


static func load_all(dir_path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("ResourceFolder: cannot open %s" % dir_path)
		return out
	for file: String in dir.get_files():
		# Exported builds list resources as "name.tres.remap".
		var clean := file.trim_suffix(".remap")
		if clean.ends_with(".tres") or clean.ends_with(".res"):
			out.append(load(dir_path.path_join(clean)))
	for sub: String in dir.get_directories():
		out.append_array(load_all(dir_path.path_join(sub)))
	return out

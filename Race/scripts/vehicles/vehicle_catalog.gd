extends RefCounted

static func all() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/vehicles.json"))

static func get_vehicle(id: String) -> Dictionary:
	for entry in all():
		if entry.id == id: return entry.duplicate(true)
	return all()[12].duplicate(true)

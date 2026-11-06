extends RefCounted
## Local save. Records are partitioned by vehicle, aids, weather, direction and upgrades.
var data = {"credits":0,"xp":0,"upgrades":{},"records":{},"daily":{},"settings":{}}
var path = "user://race_profile.json"
func load_profile():
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			for key in data:
				if not parsed.has(key): continue
				if key in ["credits","xp"] and (parsed[key] is float or parsed[key] is int):data[key]=maxi(0,int(parsed[key]))
				elif typeof(parsed[key]) == typeof(data[key]): data[key] = parsed[key]
func save() -> bool:
	var file = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data)); file.close()
	return DirAccess.rename_absolute(path+".tmp",path) == OK
func level(vehicle: String, component: String) -> int:
	return int(data.upgrades.get(vehicle,{}).get(component,0))
func buy(vehicle: String, component: String) -> bool:
	if component not in ["motor","grip","brakes"]: return false
	var current = level(vehicle,component); var cost = 500*(current+1)
	if current >= 3 or data.credits < cost: return false
	var snapshot=data.duplicate(true)
	data.credits -= cost
	if not data.upgrades.has(vehicle): data.upgrades[vehicle] = {}
	data.upgrades[vehicle][component] = current+1
	if not save():
		data=snapshot
		return false
	return true
func reward(credits: int, xp: int):
	data.credits += maxi(0,credits); data.xp += maxi(0,xp); save()
func record(key: String, seconds: float) -> bool:
	if seconds <= 0: return false
	if data.records.has(key) and float(data.records[key]) <= seconds: return false
	data.records[key] = seconds; save(); return true

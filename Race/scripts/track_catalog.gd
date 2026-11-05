extends RefCounted
## Catalogue metadata and map points; no 3D track loads while browsing.
const SIERRA_SCENE = "res://assets/tracks/sierra/sierra_mobile.glb"
const BASE_ENTRIES = [
	{"id":"lab", "name":"GT77 Proving Ground", "tag":"CONTROL / APRENDIZAJE", "location":"Centro de pruebas · trazado plano", "preview":"res://assets/tracks/previews/lab.jpg", "length":584.4, "width":16.0, "straight":110, "elevation":0, "bank":0, "difficulty":"INICIACIÓN", "surface":"Asfalto · césped", "description":"Domina el GT77: dos rectas, curvas de radio constante y una zona central de eslalon y suspensión.", "accent":Color("64e6c6")},
	{"id":"sierra", "name":"Circuito de la Sierra", "tag":"VELOCIDAD / MONTAÑA", "location":"Valle semiárido · autódromo de día", "preview":"res://assets/tracks/previews/sierra.jpg", "length":4200.0, "width":14.0, "straight":900, "elevation":120, "bank":8, "difficulty":"TÉCNICO", "surface":"Asfalto · pianos · grava", "description":"Una recta de 900 m, horquilla de frenada y enlazadas en ascenso. Domina el descenso y sus peraltes.", "accent":Color("ffb16b")}
]
static var ENTRIES:Array=build_entries()
static func build_entries()->Array:
	var entries:Array=BASE_ENTRIES.duplicate(true)
	var extra=JSON.parse_string(FileAccess.get_file_as_string("res://data/tracks.json"))
	for row in extra:
		row.merge({"tag":"RACE ORIGINAL / "+str(row.biome).to_upper(),"location":"Circuito original · geometría procedural","preview":"","width":16,"straight":0,"elevation":0,"bank":0,"difficulty":"INTERMEDIO","surface":"Grava" if row.biome=="desert" else "Nieve" if row.biome=="snow" else "Asfalto","description":"Trazado original para competición offline. Barreras, parrilla y puntos de control integrados.","accent":Color("59e8c9")})
		entries.append(row)
	return entries

static func get_entry(id:String)->Dictionary:
	for entry in ENTRIES:
		if entry.id==id:return entry
	return ENTRIES[0]
static func lab_points()->PackedVector3Array:
	var pts=PackedVector3Array()
	for i in range(56):pts.append(Vector3(-58,.025,55-i*2.0))
	for i in range(1,92):
		var a=PI+i*PI/91.0;pts.append(Vector3(58*cos(a),.025,-55+58*sin(a)))
	for i in range(1,56):pts.append(Vector3(58,.025,-55+i*2.0))
	for i in range(1,91):
		var a=i*PI/91.0;pts.append(Vector3(58*cos(a),.025,55+58*sin(a)))
	return pts
static func points_for(id:String)->PackedVector3Array:
	if id=="lab":return lab_points()
	if id!="sierra":
		var entry=get_entry(id);var pts=PackedVector3Array()
		var phase=float(entry.seed)*.63
		for i in range(360):
			var a=TAU*i/360.0
			var radius=1.0+float(entry.variation)*sin(3*a+phase)+.08*cos(5*a+phase)
			pts.append(Vector3(cos(a)*radius,.025,sin(a)*radius*(.62+float(int(entry.seed)%3)*.15)))
		var distance=0.0
		for i in range(pts.size()):distance+=pts[i].distance_to(pts[(i+1)%pts.size()])
		for i in range(pts.size()):pts[i]=Vector3(pts[i].x*float(entry.length)/distance,.025,pts[i].z*float(entry.length)/distance)
		return pts
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/tracks/sierra/centerline.json"))
	var pts=PackedVector3Array()
	for p in data.points:pts.append(Vector3(p[0],p[1]-.2,p[2]))
	return pts
static func map_transform(pts:PackedVector3Array,rect:Rect2)->Transform2D:
	var lo=Vector2(INF,INF);var hi=Vector2(-INF,-INF)
	for p in pts:
		lo=lo.min(Vector2(p.x,p.z));hi=hi.max(Vector2(p.x,p.z))
	var extent=(hi-lo).max(Vector2.ONE)
	var scale_=minf(rect.size.x/extent.x,rect.size.y/extent.y)
	return Transform2D(Vector2(scale_,0),Vector2(0,scale_),rect.get_center()-(lo+hi)*.5*scale_)

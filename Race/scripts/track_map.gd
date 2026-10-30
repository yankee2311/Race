extends Control
const Catalog=preload("res://scripts/track_catalog.gd")
var points=PackedVector3Array()
var accent=Color("ffb16b")
var track_id="sierra"
func set_track(id:String):
	track_id=id;points=Catalog.points_for(id);accent=Catalog.get_entry(id).accent;queue_redraw()
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw():
	if points.is_empty():return
	var rect=Rect2(Vector2(24,18),size-Vector2(48,36))
	var transform_=Catalog.map_transform(points,rect)
	var line=PackedVector2Array()
	for p in points:line.append(transform_*Vector2(p.x,p.z))
	line.append(line[0])
	for x in range(0,int(size.x),30):draw_line(Vector2(x,0),Vector2(x,size.y),Color(1,1,1,.025))
	for y in range(0,int(size.y),30):draw_line(Vector2(0,y),Vector2(size.x,y),Color(1,1,1,.025))
	draw_polyline(line,Color(.01,.025,.035),12,true)
	draw_polyline(line,accent,4,true)
	var start=53 if track_id=="sierra" else 3
	var pos=line[start];var forward=(line[(start+2)%points.size()]-pos).normalized()
	var side=forward.orthogonal()*8
	draw_line(pos-side,pos+side,Color.WHITE,3,true)
	draw_circle(pos+forward*17,3,Color.WHITE)

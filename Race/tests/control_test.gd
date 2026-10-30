extends SceneTree
func _initialize():call_deferred("run")
func run():
	var c=load("res://scripts/controls.gd").new();root.add_child(c);c.active=true
	await process_frame
	await process_frame
	c.make_zones();print("VIEWPORT ",root.get_visible_rect()," zones ",c.zones," input ",c.is_processing_input())
	var a=InputEventScreenTouch.new();a.index=0;a.pressed=true;a.position=c.zones.gas.get_center()
	var b=InputEventScreenTouch.new();b.index=1;b.pressed=true;b.position=c.zones.left.get_center()
	root.push_input(a,true);root.push_input(b,true)
	print("IMMEDIATE ",c.pointers)
	for i in range(30):await process_frame
	print("AFTER ",c.pointers," throttle ",c.throttle," steering ",c.steering)
	var passed=c.throttle>0.9 and c.steering<-.2
	var out=FileAccess.open("res://tests/control_results.json",FileAccess.WRITE);out.store_string(JSON.stringify({"passed":passed,"pointers":c.pointers,"throttle":c.throttle,"steering":c.steering},"  "));out.close()
	c.queue_free();await process_frame;quit(0 if passed else 1)

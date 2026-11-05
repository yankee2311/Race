extends RefCounted
## Display safe-area pixels -> canvas coordinates, including viewport stretch.
static func rect(control:Control)->Rect2:
	var full=control.get_viewport_rect()
	if OS.get_name() not in ["Android","iOS"]:return full
	var pixels=DisplayServer.get_display_safe_area()
	if pixels.size.x<=0 or pixels.size.y<=0:return full
	var transform=control.get_viewport().get_screen_transform().affine_inverse()
	var start=transform*Vector2(pixels.position)
	var end=transform*Vector2(pixels.end)
	return full.intersection(Rect2(start,end-start))

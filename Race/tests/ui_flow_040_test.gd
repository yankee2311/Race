extends SceneTree
## Regression of the new standalone RACE mobile shell, preserving legacy tests.
const UX=preload("res://scripts/ui/race_ui.gd")
const Catalog=preload("res://scripts/track_catalog.gd")
const Vehicles=preload("res://scripts/vehicles/vehicle_catalog.gd")
var errors:Array=[]
func _initialize():call_deferred("run")
func check(ok:bool,label_:String)->void:
	print(("PASS " if ok else "FAIL ")+label_)
	if not ok:errors.append(label_)
func step(n:int)->void:
	for i in range(n):await process_frame
func run():
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await step(5)
	var shell=UX.new()
	shell.game=game
	shell.theme=game.base_theme
	game.ui.add_child(shell)
	game.ux=shell
	game.selector.hide()
	await step(3)
	check(shell.page in ["home","welcome"],"onboarding/home available")
	for name_ in ["home","modes","prepare","tracks","garage","vehicle","paint","upgrades","review","progress","records","championship","settings","controls","layout_editor","handling","graphics","audio","interface","help","support","gallery","pause","results"]:
		shell._tab(name_)
		await step(1)
		check(shell.body.get_child_count()>0,"screen renders: "+name_)
	check(Vehicles.all().size()==24,"all 24 car catalog entries available")
	check(Catalog.ENTRIES.size()==12,"all 12 racing tracks available")
	check(game.selector.session_mode.item_count==10,"ten racing modes still accessible")
	game.selector.session_mode.select(8)
	shell._tab("prepare")
	check(game.selector.session_mode.selected==8,"Drag preserved as mode 8")
	game.selector.session_mode.select(3)
	shell._tab("prepare")
	check(game.championship_tracks.size()==3,"three championship stops preserved")
	game.selector.session_mode.select(0)
	game.selector.select_track("sierra")
	game.selector.select_vehicle("gt77")
	shell.selected_paint=1
	shell._tab("paint")
	check(shell.selected_paint==1,"GT77 three real paint layouts selectable")
	shell._tab("layout_editor")
	shell.control_zone="gas"
	shell._nudge(Vector2(12,0))
	check(game.controls.zone_offsets.has("gas"),"touch layout editor offsets work")
	var encoded=shell._serialize_offsets()
	check(encoded.has("gas") and encoded.gas.size()==2,"layout offsets serialize")
	shell._tab("modes")
	shell._to("prepare")
	shell.back()
	check(shell.page=="modes","back navigation preserves origin")
	for resolution in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(1024,768)]:
		root.size=resolution
		await step(4)
		check(shell.safe_root.size.x>0 and shell.safe_root.size.y>0,"safe area at "+str(resolution))
	shell.hide()
	game.queue_free()
	await step(2)
	print("UI_040_RESULT ",JSON.stringify({"passed":errors.is_empty(),"errors":errors}))
	quit(0 if errors.is_empty() else 1)

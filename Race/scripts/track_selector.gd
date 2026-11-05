extends Control
const Catalog=preload("res://scripts/track_catalog.gd")
const Vehicles=preload("res://scripts/vehicles/vehicle_catalog.gd")
const Rules=preload("res://scripts/gameplay/race_rules.gd")
const Map=preload("res://scripts/track_map.gd")
const Safe=preload("res://scripts/ui/safe_area.gd")
signal selected(id:String)
signal vehicle_selected(id:String)
signal start_requested
signal settings_requested
signal upgrade_requested(component:String)
signal preview_requested
var selected_id="sierra"
var vehicle_id="gt77"
var session_mode:OptionButton
var track_choice:OptionButton
var vehicle_choice:OptionButton
var weather_choice:OptionButton
var difficulty_choice:OptionButton
var paint_choice:OptionButton
var reverse_choice:CheckButton
var start_button:Button
var title:Label
var vehicle_stats:Label
var description:Label
var wallet:Label
var map:Control
var root_margin:MarginContainer
var loading:Label
var upgrades:Array=[]
var profile
var paint_colors=[Color("ef4551"),Color("29c5dd"),Color("f4bd55"),Color("e8edf5"),Color("785fe8"),Color("71dcaa")]
func label_(parent:Node,text_:String,font_size:int=18,color:Color=Color.WHITE)->Label:
	var label=Label.new();label.text=text_;label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",color);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(label);return label
func choose(parent:Node,caption:String,items:Array)->OptionButton:
	label_(parent,caption,12,Color("a5b8cb"))
	var control=OptionButton.new();control.fit_to_longest_item=false;control.clip_text=true;control.custom_minimum_size.y=44;control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for item in items:control.add_item(str(item))
	parent.add_child(control);return control
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg=ColorRect.new();bg.color=Color(.025,.045,.075,.87);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(bg)
	root_margin=MarginContainer.new();add_child(root_margin)
	for side in ["left","top","right","bottom"]:root_margin.add_theme_constant_override("margin_"+side,24)
	var outer=VBoxContainer.new();outer.add_theme_constant_override("separation",12);root_margin.add_child(outer)
	var header=HBoxContainer.new();outer.add_child(header)
	var logo=label_(header,"RACE",40);logo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	wallet=label_(header,"OFFLINE  /  0.3.0",15,Color("59e8c9"));wallet.custom_minimum_size.x=300
	var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;outer.add_child(scroll)
	var columns=HBoxContainer.new();columns.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_theme_constant_override("separation",24);scroll.add_child(columns)
	var setup=VBoxContainer.new();setup.size_flags_horizontal=Control.SIZE_EXPAND_FILL;setup.size_flags_stretch_ratio=.9;setup.add_theme_constant_override("separation",8);columns.add_child(setup)
	label_(setup,"01  /  TU EVENTO",22,Color("59e8c9"))
	session_mode=choose(setup,"MODALIDAD",Rules.MODES)
	var names=[]
	for entry in Catalog.ENTRIES:names.append(entry.name)
	track_choice=choose(setup,"CIRCUITO",names);track_choice.item_selected.connect(func(index):select_track(Catalog.ENTRIES[index].id))
	weather_choice=choose(setup,"CONDICIONES",["Seco · día","Mojado · adherencia reducida","Atardecer","Noche"])
	difficulty_choice=choose(setup,"RIVALES · IA DE TRAYECTORIA SIN COLISIONES",["Accesible","Competitivo","Experto"])
	reverse_choice=CheckButton.new();reverse_choice.text="Recorrido inverso";reverse_choice.custom_minimum_size.y=40;setup.add_child(reverse_choice)
	label_(setup,"Drag: recta exclusiva de 402 m.\nSprint / Rally: 75 % del trazado seleccionado.",13,Color("a5b8cb"))
	var garage=VBoxContainer.new();garage.size_flags_horizontal=Control.SIZE_EXPAND_FILL;garage.add_theme_constant_override("separation",8);columns.add_child(garage)
	label_(garage,"02  /  GARAJE",22,Color("59e8c9"))
	names=[]
	for entry in Vehicles.all():names.append(entry.vehicle_class+"  /  "+entry.name)
	vehicle_choice=choose(garage,"24 VEHÍCULOS · CATÁLOGO ORIGINAL",names);vehicle_choice.item_selected.connect(func(index):select_vehicle(Vehicles.all()[index].id))
	var orbit=Button.new();orbit.text="VER AUTO 360°";orbit.custom_minimum_size.y=40;orbit.pressed.connect(func():preview_requested.emit());garage.add_child(orbit)
	vehicle_stats=label_(garage,"",16);vehicle_stats.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	paint_choice=choose(garage,"PINTURA",["Racing red","Arctic cyan","Solar gold","Pearl white","Ultraviolet","Mint"])
	paint_choice.item_selected.connect(func(_index):vehicle_selected.emit(vehicle_id))
	for component in ["motor","grip","brakes"]:
		var b=Button.new();b.custom_minimum_size.y=40;b.pressed.connect(func():upgrade_requested.emit(component));garage.add_child(b);upgrades.append(b)
	label_(garage,"Mejoras: motor +5 %, agarre +3 %, frenos +5 % por nivel.\nGana créditos completando eventos y vueltas válidas.",13,Color("a5b8cb")).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var preview=VBoxContainer.new();preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(preview)
	title=label_(preview,"",22);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	map=Map.new();map.custom_minimum_size=Vector2(220,240);map.size_flags_horizontal=Control.SIZE_EXPAND_FILL;preview.add_child(map)
	description=label_(preview,"",15,Color("b8c9d7"));description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var actions=HBoxContainer.new();outer.add_child(actions)
	var settings=Button.new();settings.text="AJUSTES";settings.custom_minimum_size=Vector2(180,54);settings.pressed.connect(func():settings_requested.emit());actions.add_child(settings)
	start_button=Button.new();start_button.text="SALIR A PISTA  →";start_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;start_button.custom_minimum_size.y=54;start_button.pressed.connect(func():start_requested.emit());actions.add_child(start_button)
	var style=StyleBoxFlat.new();style.bg_color=Color("db3d53");style.set_corner_radius_all(8);start_button.add_theme_stylebox_override("normal",style)
	loading=label_(outer,"",17,Color("59e8c9"));loading.hide()
	select_track(selected_id);select_vehicle(vehicle_id);refresh_profile()
func select_track(id:String):
	selected_id=Catalog.get_entry(id).id
	if not is_node_ready():return
	var entry=Catalog.get_entry(selected_id)
	for i in range(Catalog.ENTRIES.size()):
		if Catalog.ENTRIES[i].id==id:track_choice.select(i)
	title.text=entry.name;map.set_track(selected_id)
	description.text="%.2f km  /  %s\n\n%s\n\nDESAFÍOS DIARIOS\nVuelta válida · +200 CR\n150 km/h durante 10 s · +250 CR\nDerrapar 500 m · +300 CR"%[float(entry.length)/1000,entry.surface,entry.description]
	selected.emit(selected_id)
func select_vehicle(id:String):
	vehicle_id=id
	if not is_node_ready():return
	var data=Vehicles.get_vehicle(id)
	for i in range(Vehicles.all().size()):
		if Vehicles.all()[i].id==id:vehicle_choice.select(i)
	vehicle_stats.text="%s · %s\n%d kg  /  %d Nm\n%s"%[data.family,data.drive,data.mass,data.torque,"Modelo GT77" if id=="gt77" else "Carrocería procedural original"]
	refresh_profile();vehicle_selected.emit(id)
func refresh_profile():
	if not is_node_ready() or profile==null:return
	wallet.text="%d CR  /  NIVEL %d  /  OFFLINE"%[profile.data.credits,1+int(profile.data.xp)/500]
	for i in range(upgrades.size()):
		var component=["motor","grip","brakes"][i];var level=profile.level(vehicle_id,component);var cost=500*(level+1)
		upgrades[i].text="%s  %d/3  ·  %s"%[["MOTOR","NEUMÁTICOS","FRENOS"][i],level,"MÁXIMO" if level>=3 else str(cost)+" CR"]
		upgrades[i].disabled=level>=3 or profile.data.credits<cost
func set_loading(value:bool,message:String="PREPARANDO PISTA…"):
	loading.visible=value;loading.text=message;start_button.disabled=value
func _process(_dt):
	var safe=Safe.rect(self);root_margin.position=safe.position;root_margin.size=safe.size

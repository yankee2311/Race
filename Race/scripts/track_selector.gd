extends Control
const Catalog=preload("res://scripts/track_catalog.gd")
const Map=preload("res://scripts/track_map.gd")
const UiTheme=preload("res://scripts/ui_theme.gd")
signal selected(id:String)
signal start_requested
signal settings_requested
var selected_id="sierra"
var session_mode:OptionButton
var cards=[]
var hero:TextureRect
var title:Label
var location_label:Label
var tag_label:Label
var description:Label
var stats=[]
var map:Control
var map_panel:Panel
var details:Panel
var start_button:Button
var settings_button:Button
var footer:Label
var header:Label
var count_label:Label
var hero_panel:Panel
var loading:Panel
var loading_text:Label
var last_size=Vector2.ZERO

func style(color:Color,radius:int=14,border:Color=Color.TRANSPARENT)->StyleBoxFlat:
	return UiTheme.card(color,radius,border)
func label_(parent:Node,text_:String,size_:int,color:Color=Color.WHITE)->Label:
	var l=Label.new();l.text=text_;l.add_theme_font_size_override("font_size",size_);l.add_theme_color_override("font_color",color);l.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(l);return l
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg=ColorRect.new();bg.color=UiTheme.BG;bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(bg)
	header=label_(self,"RACE",35);header.position=Vector2(28,15)
	label_(self,"GT77  /  DRIVE LAB",13,UiTheme.MINT_SOFT).position=Vector2(143,35)
	label_(self,"ELIGE TU PRÓXIMA VUELTA",14,UiTheme.TEXT_MUTED).position=Vector2(30,66)
	count_label=label_(self,"02 CIRCUITOS  ·  0.2.1",12,UiTheme.TEXT_DIM)
	session_mode=OptionButton.new()
	session_mode.add_item("MODO LIBRE",0)
	session_mode.add_theme_color_override("font_color",UiTheme.MINT_SOFT)
	session_mode.tooltip_text="Próximamente: contrarreloj, carreras y desafíos"
	add_child(session_mode)
	for entry in Catalog.ENTRIES:
		var card=Button.new();card.flat=false;card.focus_mode=Control.FOCUS_ALL;card.clip_contents=true
		card.pressed.connect(func():select_track(entry.id));add_child(card)
		var image=TextureRect.new();image.texture=load(entry.preview);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(image);image.name="Image"
		var n=label_(card,"01  PROVING GROUND" if entry.id=="lab" else "02  CIRCUITO DE LA SIERRA",13);n.name="Name"
		var meta=label_(card,"%.2f km  /  %s"%[entry.length/1000,entry.difficulty],12,entry.accent);meta.name="Meta"
		cards.append(card)
	hero_panel=Panel.new();hero_panel.add_theme_stylebox_override("panel",style(UiTheme.PANEL,14,UiTheme.HUD_LINE));hero_panel.clip_contents=true;add_child(hero_panel)
	hero=TextureRect.new();hero.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;hero.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;hero.mouse_filter=Control.MOUSE_FILTER_IGNORE;hero_panel.add_child(hero)
	tag_label=label_(hero_panel,"",12,UiTheme.AMBER_TEXT)
	title=label_(hero_panel,"",29)
	location_label=label_(hero_panel,"",13,UiTheme.TEXT_MUTED)
	description=label_(self,"",17,UiTheme.TEXT_SOFT);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	details=Panel.new();details.add_theme_stylebox_override("panel",style(UiTheme.PANEL_MID));add_child(details)
	label_(details,"FICHA DEL CIRCUITO",13,UiTheme.TEXT_MUTED).position=Vector2(20,16)
	for key in ["LONGITUD","ANCHO","RECTA PRINCIPAL","DESNIVEL","PERALTE MÁXIMO","SUPERFICIE"]:
		var k=label_(details,key,10,UiTheme.TEXT_DIM);var v=label_(details,"",20);stats.append([k,v])
	map_panel=Panel.new();map_panel.add_theme_stylebox_override("panel",style(UiTheme.PANEL_DEEP));add_child(map_panel)
	label_(map_panel,"MAPA DEL TRAZADO",12,UiTheme.TEXT_MUTED).position=Vector2(18,12)
	map=Map.new();map_panel.add_child(map)
	var map_note=label_(map_panel,"Línea blanca: salida / meta",10,UiTheme.TEXT_FAINT);map_note.name="Legend"
	settings_button=Button.new();settings_button.text="AJUSTES DE CONDUCCIÓN";settings_button.pressed.connect(func():settings_requested.emit());add_child(settings_button)
	start_button=Button.new();start_button.pressed.connect(func():start_requested.emit());start_button.add_theme_font_size_override("font_size",19);start_button.add_theme_color_override("font_color",UiTheme.ON_ACCENT);add_child(start_button)
	footer=label_(self,"GT77 · CONDUCCIÓN LIBRE · MEJOR VUELTA POR CIRCUITO",11,UiTheme.TEXT_FAINT)
	loading=Panel.new();loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);loading.add_theme_stylebox_override("panel",style(UiTheme.OVERLAY,14));add_child(loading);loading.hide()
	loading_text=label_(loading,"PREPARANDO PISTA…",24);loading_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	select_track(selected_id)
func select_track(id:String):
	selected_id=Catalog.get_entry(id).id
	var entry=Catalog.get_entry(selected_id)
	if not is_node_ready():return
	hero.texture=load(entry.preview);title.text=entry.name;tag_label.text=entry.tag;tag_label.modulate=entry.accent;location_label.text=entry.location;description.text=entry.description
	var values=["%.2f km"%(entry.length/1000),"%d m"%entry.width,"%d m"%entry.straight,"%d m"%entry.elevation,"%d %%"%entry.bank,"Asfalto / grava" if selected_id=="sierra" else "Asfalto / césped"]
	for i in range(stats.size()):stats[i][1].text=values[i]
	stats[5][1].add_theme_font_size_override("font_size",14)
	map.set_track(selected_id)
	start_button.text="CONDUCIR EN SIERRA  →" if selected_id=="sierra" else "SALIR A PROVING GROUND  →"
	start_button.add_theme_stylebox_override("normal",style(entry.accent,12));start_button.add_theme_stylebox_override("hover",style(entry.accent.lightened(.1),12));start_button.add_theme_stylebox_override("pressed",style(entry.accent.darkened(.15),12))
	for i in range(cards.size()):
		var e=Catalog.ENTRIES[i];var c=cards[i]
		c.add_theme_stylebox_override("normal",style(UiTheme.PANEL_CARD_ACTIVE if e.id==selected_id else UiTheme.PANEL_CARD,12,e.accent if e.id==selected_id else UiTheme.BORDER))
		c.add_theme_stylebox_override("focus",style(Color.TRANSPARENT,12,Color.WHITE))
	selected.emit(selected_id)
func set_loading(value:bool,message:String="PREPARANDO PISTA…"):
	loading.visible=value;loading_text.text=message;start_button.disabled=value
func _process(_dt):
	if size!=last_size:last_size=size;_layout()
func _layout():
	var w=size.x;var h=size.y;var pad=28.0;var gap=18.0
	# Safe area: márgenes mínimos en pantallas con notch o gestos del sistema.
	var ins=UiTheme.safe_insets(get_viewport());var il=ins.x;var it=ins.y;var ir=ins.z;var ib=ins.w
	var left=224.0;var side=294.0;var center_w=w-pad*2-left-side-gap*2
	var top=104.0+it;var content_h=h-top-106-ib
	count_label.position=Vector2(w-208-ir,it+35)
	session_mode.position=Vector2(maxf(270,w*.42),24+it)
	session_mode.size=Vector2(185,42)
	for i in range(cards.size()):
		var c=cards[i];c.position=Vector2(pad+il,top+i*201);c.size=Vector2(left,183)
		c.get_node("Image").position=Vector2(8,8);c.get_node("Image").size=Vector2(left-16,105)
		c.get_node("Name").position=Vector2(12,124);c.get_node("Meta").position=Vector2(12,151)
	var cx=pad+left+gap;var sx=w-pad-side-ir
	hero_panel.position=Vector2(cx,top);hero_panel.size=Vector2(center_w,content_h-87)
	var image_h=hero_panel.size.y-108
	hero.position=Vector2(2,2);hero.size=Vector2(center_w-4,image_h)
	tag_label.position=Vector2(18,image_h+13);title.position=Vector2(18,image_h+34);title.add_theme_font_size_override("font_size",25 if center_w<550 else 29)
	location_label.position=Vector2(18,image_h+76)
	description.position=Vector2(cx,top+content_h-69);description.size=Vector2(center_w,70)
	map_panel.position=Vector2(sx,top);map_panel.size=Vector2(side,content_h*.48)
	map.position=Vector2(8,38);map.size=Vector2(side-16,map_panel.size.y-67)
	map_panel.get_node("Legend").position=Vector2(18,map_panel.size.y-23)
	details.position=Vector2(sx,top+map_panel.size.y+gap);details.size=Vector2(side,content_h-map_panel.size.y-gap)
	for i in range(stats.size()):
		var x=20+(i%2)*137;var y=48+floori(i/2.0)*59
		stats[i][0].position=Vector2(x,y);stats[i][1].position=Vector2(x,y+16)
	settings_button.position=Vector2(pad+il,h-77-ib);settings_button.size=Vector2(286,51)
	start_button.position=Vector2(w-pad-370-ir,h-80-ib);start_button.size=Vector2(370,57)
	footer.position=Vector2(336,h-59-ib)
	footer.visible=w>=1250
	loading.position=Vector2.ZERO;loading.size=Vector2(w,h)
	loading_text.position=Vector2(w*.15,h*.5-25);loading_text.size=Vector2(w*.7,100)

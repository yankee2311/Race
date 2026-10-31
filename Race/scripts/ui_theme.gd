extends RefCounted
## Sistema de diseño de GT77: paleta centralizada, tipografía y styleboxes compartidos.
## Todo color / estilo de UI debe salir de aquí, nunca hard-coded en los scripts.

const FONT_PATH="res://assets/regular.ttf"
const MONO_PATH="res://assets/mono.ttf"

# --- Fondos y paneles ---
const BG=Color("0c151d")
const PANEL=Color("15222c")
const PANEL_MID=Color("13212b")
const PANEL_DEEP=Color("101d26")
const PANEL_CARD=Color("111e28")
const PANEL_CARD_ACTIVE=Color("192a36")
const MENU_PANEL=Color(.025,.045,.07,.94)
const OVERLAY=Color(.035,.06,.08,.97)
const BORDER=Color("243745")
const BORDER_SOFT=Color("2c3d4d")

# --- Controles (botones, selects) ---
const CONTROL_BG=Color("263543")
const CONTROL_HOVER=Color("394f5f")
const CONTROL_PRESSED=Color("1e2b37")

# --- Acentos ---
const MINT=Color("59e8c9")
const MINT_SOFT=Color("64e6c6")
const MINT_GLOW=Color("63efce")
const TACH_GREEN=Color("57dfc0")
const AMBER=Color("e6bd61")
const AMBER_TEXT=Color("ffb16b")
const RED=Color("dd3847")
const RED_BRIGHT=Color("ef4551")
const RED_WARN=Color("ed5463")
const TACH_RED=Color("f64c5e")
const RED_BRAKE=Color(.75,.15,.2,.9)

# --- Texto ---
const TEXT=Color("f2f6fa")
const TEXT_MUTED=Color("a9bac9")
const TEXT_DIM=Color("8296a5")
const TEXT_FAINT=Color("7e97a9")
const TEXT_SOFT=Color("bccbd5")
const TEXT_SUB=Color("afc1cf")
const TEXT_LABEL=Color("91a7b9")
const ON_ACCENT=Color("10202b")

# --- HUD (translúcidos) ---
const HUD_PANEL=Color(.035,.06,.09,.78)
const HUD_CLUSTER=Color(.03,.05,.075,.89)
const HUD_CHRONO=Color(.03,.05,.08,.92)
const HUD_TOAST=Color(.04,.08,.11,.94)
const HUD_LINE=Color(1,1,1,.06)

# --- Táctil / misc ---
const TOUCH_ZONE=Color(.06,.09,.13,.78)
const TOUCH_ACTIVE=Color(.12,.6,.54,.9)
const PAUSED_DIM=Color(.015,.025,.04,.87)
const MAP_TRACK=Color(.55,.65,.73,.55)


## Fábrica de StyleBoxFlat para paneles/tarjetas.
static func card(bg:Color,radius:int=14,border:Color=Color.TRANSPARENT,border_width:int=2)->StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=bg
	s.set_corner_radius_all(radius)
	if border.a>0.0:
		s.set_border_width_all(border_width)
		s.border_color=border
	return s


## Construye el Theme completo del juego (botones, selects + su popup, checks, slider).
static func make_theme()->Theme:
	var t=Theme.new()
	t.default_font=load(FONT_PATH)
	t.default_font_size=18
	for type in ["Button","OptionButton"]:
		t.set_color("font_color",type,TEXT)
		t.set_color("font_hover_color",type,Color.WHITE)
		t.set_color("font_pressed_color",type,TEXT_MUTED)
		t.set_color("font_disabled_color",type,TEXT_FAINT)
		t.set_color("font_focus_color",type,TEXT)
		var backgrounds={"normal":CONTROL_BG,"hover":CONTROL_HOVER,"pressed":CONTROL_PRESSED,"disabled":CONTROL_BG,"focus":CONTROL_BG}
		for state in backgrounds:
			var s=card(backgrounds[state],9)
			s.set_content_margin_all(0)
			s.content_margin_left=16;s.content_margin_right=16;s.content_margin_top=10;s.content_margin_bottom=10
			if state=="disabled":s.bg_color.a=.55
			t.set_stylebox(state,type,s)
	# Popup desplegable de los OptionButton (antes heredaba el tema gris default de Godot).
	var popup=card(Color("16242f"),12,BORDER_SOFT)
	popup.content_margin_left=8;popup.content_margin_right=8;popup.content_margin_top=8;popup.content_margin_bottom=8
	t.set_stylebox("panel","PopupMenu",popup)
	t.set_stylebox("hover","PopupMenu",card(CONTROL_HOVER,8))
	t.set_stylebox("pressed","PopupMenu",card(CONTROL_PRESSED,8))
	t.set_color("font_color","PopupMenu",TEXT)
	t.set_color("font_hover_color","PopupMenu",Color.WHITE)
	t.set_color("font_pressed_color","PopupMenu",MINT)
	t.set_color("font_disabled_color","PopupMenu",TEXT_FAINT)
	t.set_constant("v_separation","PopupMenu",10)
	t.set_constant("h_separation","PopupMenu",10)
	# CheckButton / HSlider / Label
	t.set_color("font_color","CheckButton",TEXT)
	t.set_color("font_hover_color","CheckButton",Color.WHITE)
	var groove=card(Color(1,1,1,.10),3);groove.content_margin_top=4;groove.content_margin_bottom=4
	t.set_stylebox("slider","HSlider",groove)
	t.set_stylebox("grabber_area","HSlider",card(Color(MINT.r,MINT.g,MINT.b,.55),3))
	t.set_stylebox("grabber_area_highlight","HSlider",card(MINT,3))
	t.set_color("font_color","Label",TEXT)
	return t


## Label de UI: ignora el mouse y usa la fuente del theme del proyecto.
static func label(parent:Node,text_:String,size_:int=18,color:Color=TEXT)->Label:
	var l=Label.new()
	l.text=text_
	l.add_theme_font_size_override("font_size",size_)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Botón de UI con estado de foco desactivado y acción conectada.
static func button(parent:Node,text_:String,callable:Callable)->Button:
	var b=Button.new()
	b.text=text_
	b.focus_mode=Control.FOCUS_NONE
	b.pressed.connect(callable)
	parent.add_child(b)
	return b


## Insets de safe area (notch / barras del sistema) convertidos a unidades de viewport.
## Devuelve Vector4(izquierda, arriba, derecha, abajo).
static func safe_insets(viewport:Viewport)->Vector4:
	var win=DisplayServer.window_get_size()
	if win.x<1 or win.y<1:return Vector4.ZERO
	var visible=viewport.get_visible_rect().size
	if visible.x<1:return Vector4.ZERO
	var factor=float(win.x)/visible.x
	if not (factor>0.0) or not is_finite(factor):return Vector4.ZERO
	var area=DisplayServer.window_get_safe_area()
	var left=maxf(0.0,float(area.position.x))/factor
	var top=maxf(0.0,float(area.position.y))/factor
	var right=maxf(0.0,float(win.x-area.end.x))/factor
	var bottom=maxf(0.0,float(win.y-area.end.y))/factor
	return Vector4(left,top,right,bottom)

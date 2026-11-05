extends RefCounted
const MODES=["Libre","Contrarreloj","Carrera rápida","Campeonato","Drift","Sprint","Rally","Eliminación","Drag","Academia"]
var mode=0
var elapsed=0.0
var countdown=3.0
var completed=false
var laps=0
var score=0.0
var combo=1.0
var drift_distance=0.0
var travel=0.0
var previous=0.0
var length_m=1.0
var checkpoint=1
var valid=true
var offroad=0.0
var sectors=[]
var last_sector_time=0.0
var position=1
var elimination_at=30.0
var target_laps=3
var message=""
var academy_step=0
var academy_hold=0.0
var started=false

func begin(mode_:int,length_:float,progress:float):
	mode=mode_;length_m=length_;previous=progress;countdown=0 if mode in [0,1,4,6,9] else 3.0
	elapsed=0;completed=false;laps=0;score=0;combo=1;drift_distance=0;travel=0;checkpoint=1;valid=true;offroad=0;sectors.clear();last_sector_time=0;position=1;elimination_at=30;message="";academy_step=0;academy_hold=0;started=countdown<=0

func invalidate():
	valid=false;message="Vuelta invalidada · vuelve a cruzar la meta"

func tick(dt:float,progress:float,on_road:bool,speed:float,angle:float,throttle:float,brake:float):
	if completed:return
	if countdown>0:
		countdown=maxf(0,countdown-dt);previous=progress
		if countdown==0:started=true
		return
	elapsed+=dt
	var delta=fposmod(progress-previous+length_m*.5,length_m)-length_m*.5
	previous=progress
	if absf(delta)>maxf(15,dt*150):invalidate();delta=0
	travel+=delta
	if not on_road:
		offroad+=dt
		if offroad>1.0:invalidate()
	else:offroad=0
	if mode==4:
		if on_road and speed>25 and absf(angle)>.13 and absf(angle)<1.2:
			combo=minf(5,combo+dt*.12);score+=speed*absf(angle)*combo*dt;drift_distance+=speed/3.6*dt
		else:combo=maxf(1,combo-dt*2)
		if elapsed>=90:completed=true;message="Sesión de drift completada"
	if mode in [5,6] and travel>=length_m*.75 and valid:completed=true;message="Tramo completado"
	if mode==8 and travel>=402 and valid:completed=true;message="402 metros completados"
	if mode==9:
		match academy_step:
			0:
				message="1/3 · Acelera hasta 60 km/h"
				if speed>=60:academy_step=1
			1:
				message="2/3 · Frena hasta detenerte"
				if brake>.3 and speed<3:academy_step=2
			2:
				message="3/3 · Mantén 30–80 km/h en pista durante 10 s"
				academy_hold=academy_hold+dt if on_road and speed>30 and speed<80 else 0.0
				if academy_hold>=10:completed=true;message="Academia completada"
	if mode in [2,3] and laps>=target_laps:completed=true;message="Carrera terminada"
	# A timeout always lets the player finish a failed trial rather than becoming stuck.
	if mode in [5,6,8] and elapsed>600:completed=true;message="Tiempo agotado"

func checkpoint_passed(index:int):
	if index==checkpoint:
		sectors.append(elapsed-last_sector_time);last_sector_time=elapsed;checkpoint+=1

func finish_lap()->bool:
	var accepted=valid
	if accepted:laps+=1
	valid=true;checkpoint=1;last_sector_time=elapsed
	return accepted

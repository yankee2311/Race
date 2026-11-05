extends AudioStreamPlayer

var car
var phase=0.0
var phase2=0.0
var noise=0.0
var enabled=true
var active=false
var playback:AudioStreamGeneratorPlayback

func _ready():
	var generator=AudioStreamGenerator.new()
	generator.mix_rate=22050
	generator.buffer_length=.12
	stream=generator
	volume_db=-16
	_sync_playback()

func set_enabled(value:bool)->void:
	enabled=value
	_sync_playback()

func set_active(value:bool)->void:
	active=value
	_sync_playback()

func _sync_playback()->void:
	if not is_inside_tree():return
	var should_run=enabled and active
	if not should_run:
		set_process(false)
		if playing:stop()
		playback=null
		return
	if not playing:play()
	playback=get_stream_playback()
	set_process(playback!=null)

func _process(_dt):
	if not playback or not is_instance_valid(car):return
	var count=playback.get_frames_available()
	var frequency=car.rpm/60.0*2.0*float(car.vehicle_data.get("pitch",1.0))
	var gain=.20+.65*car.throttle
	for i in range(count):
		phase=fmod(phase+TAU*frequency/22050.0,TAU)
		phase2=fmod(phase2+TAU*frequency*.5/22050.0,TAU)
		noise=lerpf(noise,randf_range(-1,1),.25)
		var sample=(sin(phase)*.40+sin(phase*2)*.17+sin(phase*3)*.08+noise*.10)*gain
		if car.speed_kmh>20:sample+=noise*clampf((car.worst_slip-.18)*.3,0,.16)*gain
		playback.push_frame(Vector2(sample,sample))

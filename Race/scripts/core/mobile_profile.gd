extends RefCounted
## 0.3.1: safe defaults for the original Galaxy A05, not A05s/A05 5G.
static func is_galaxy_a05(model_name:String)->bool:
	var name=model_name.to_upper()
	return name.contains("SM-A055") or name.contains("GALAXY A05") and not name.contains("A05S")

static func apply_lite_defaults(config:ConfigFile)->void:
	# Apply once so that later deliberate user changes remain persistent.
	if bool(config.get_value("stability","lite_031_applied",false)):return
	config.set_value("drive","quality",0)
	config.set_value("drive","fps",0)
	config.set_value("drive","shadows",false)
	config.set_value("drive","vibration",false)
	config.set_value("stability","lite_031_applied",true)
	# Caller decides when to persist settings; unit tests remain isolated.

static func configure_engine(lite:bool)->void:
	if lite:
		Engine.physics_ticks_per_second=60
		Engine.max_physics_steps_per_frame=8

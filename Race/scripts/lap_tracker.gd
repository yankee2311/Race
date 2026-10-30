extends RefCounted
## Direction-aware checkpoints independent of track coordinates or size.
var length_m=1.0
var previous=0.0
var next_checkpoint=1
var armed=false
var crossed_start=false
func reset(length_:float,progress:float):
	length_m=length_;previous=fposmod(progress,length_m);next_checkpoint=1;armed=false;crossed_start=false
func update(progress:float)->bool:
	var p=fposmod(progress,length_m)
	var delta=fposmod(p-previous+length_m*.5,length_m)-length_m*.5
	crossed_start=false
	var last=previous;previous=p
	if absf(delta)>minf(100.0,length_m*.2):
		next_checkpoint=1;armed=false;return false
	if delta<=0:return false
	if p<last:
		crossed_start=true
		var complete=armed and next_checkpoint==4
		armed=true;next_checkpoint=1
		return complete
	if armed and next_checkpoint<=3:
		var gate=length_m*next_checkpoint/4.0
		if last<gate and p>=gate:next_checkpoint+=1
	return false

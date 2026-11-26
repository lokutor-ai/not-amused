class_name Leak
extends RefCounted
## Whether the microphone hears the king: whether his voice comes out of speakers. While he greets the jester, the loudness of
## the microphone is compared with that of his voice, at every delay up to half a second. Somebody else talking does not
## rise and fall with him.

const STEP := 0.02                        # seconds
const LONGEST := 25                       # steps of delay
const ALIKE := 0.4                        # correlation: 0.9 with speakers, 0.0 to 0.35 with headphones
const NOISE := 0.004                      # quieter than this, the server would not hear it either

var _mic: PackedFloat32Array = []
var _voice: PackedFloat32Array = []
var _time := 0.0


func hear(mic: float, voice: float, seconds: float) -> void:
	_time += seconds
	while _time >= STEP:
		_time -= STEP
		_mic.append(mic)
		_voice.append(voice)


func found() -> bool:
	return likeness() > ALIKE


## The best correlation, 0 to 1.
func likeness() -> float:
	var n := _mic.size() - LONGEST
	if n < 50:                            # less than a second of him
		return 0.0
	var loud := 0.0
	for x in _mic:
		loud = maxf(loud, x)
	if loud < NOISE:
		return 0.0
	var best := 0.0
	for delay in LONGEST + 1:
		var a := _mic.slice(delay, delay + n)
		var b := _voice.slice(0, n)
		var ma := _mean(a)
		var mb := _mean(b)
		var ab := 0.0
		var aa := 0.0
		var bb := 0.0
		for i in n:
			ab += (a[i] - ma) * (b[i] - mb)
			aa += (a[i] - ma) * (a[i] - ma)
			bb += (b[i] - mb) * (b[i] - mb)
		if aa > 0.0 and bb > 0.0:
			best = maxf(best, ab / sqrt(aa * bb))
	return best


func _mean(x: PackedFloat32Array) -> float:
	var sum := 0.0
	for v in x:
		sum += v
	return sum / x.size()

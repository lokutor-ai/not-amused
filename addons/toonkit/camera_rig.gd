class_name CameraRig
extends Node3D
## A camera that frames shots by name, breathes a little, and never jerks.

## name -> [position, what it looks at, field of view, where the sun comes from (degrees round)]
var shots := {}
var camera: Camera3D
var shot := ""
var sun_turn := 34.0
var _from := []
var _t := 1.0
var _seconds := 1.0
var _time := 0.0
var _shake := 0.0
var _drift := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	camera = Camera3D.new()
	camera.near = 0.1
	camera.far = 60.0
	add_child(camera)
	_noise.frequency = 0.35


## Goes to a shot: at once, or easing over `seconds`.
func go(new_shot: String, seconds := 0.0) -> void:
	if new_shot == shot:
		return
	assert(shots.has(new_shot), "no shot called " + new_shot)
	_from = _state()
	shot = new_shot
	_drift = 0.0
	_seconds = seconds
	_t = 0.0 if seconds > 0.0 else 1.0


func shake(amount := 0.06) -> void:
	_shake = maxf(_shake, amount)


func _state() -> Array:
	if shot == "":
		return []
	var to: Array = shots[shot]
	if _t >= 1.0 or _from.is_empty():
		return to
	var u := _t * _t * _t * (_t * (_t * 6.0 - 15.0) + 10.0)
	return [(_from[0] as Vector3).lerp(to[0], u), (_from[1] as Vector3).lerp(to[1], u), lerpf(_from[2], to[2], u), lerpf(_from[3], to[3], u)]


func _process(delta: float) -> void:
	if shot == "":
		return
	_time += delta
	_t = minf(1.0, _t + delta / maxf(_seconds, 0.001))
	_shake = maxf(0.0, _shake - delta * _shake * 5.0)
	_drift += delta
	var s := _state()
	var at: Vector3 = s[0]
	var to: Vector3 = s[1]
	# A slow push in, so that a held shot is alive.
	at = at.lerp(to, 0.05 * (1.0 - exp(-_drift * 0.12)))
	var n := Vector3(_noise.get_noise_2d(_time, 0.0), _noise.get_noise_2d(_time, 50.0), _noise.get_noise_2d(_time, 90.0))
	var k := Vector3(sin(_time * 61.0), cos(_time * 73.0), sin(_time * 47.0)) * _shake
	camera.look_at_from_position(at + n * 0.05 + k, to + n.rotated(Vector3.UP, 1.0) * 0.03 + k * 0.6, Vector3.UP)
	camera.fov = s[2]
	sun_turn = s[3]

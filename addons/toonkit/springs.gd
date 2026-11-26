class_name JellySprings
extends SkeletonModifier3D
## Secondary motion: bones that lag, swing and wobble behind the animation (belly, crown, hat tips, plumes). Runs after the
## AnimationPlayer, so it reacts to blends and to the game, not only to what was animated.

## Bones that swing: bone name -> [stiffness, damping, gravity, limit in degrees].
@export var swing := {}
## Bones that shift, like a belly: bone name -> [stiffness, damping, limit in metres].
@export var soft := {}

var _state := {}

const STEPS := 4
const ARM := 0.35


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var dt := minf(get_process_delta_time(), 0.05)
	var world := sk.global_transform
	var back := world.affine_inverse()
	for b in swing:
		var i := sk.find_bone(b)
		if i < 0:
			continue
		var k: Array = swing[b]
		var pose := world * sk.get_bone_global_pose(i)
		var from := pose.basis.y.normalized()
		var rest := pose.origin + from * ARM
		var s: Array = _step(b, rest, k[0], k[1], Vector3.DOWN * k[2], dt)
		var dir: Vector3 = (s[0] - pose.origin).normalized()
		s[0] = pose.origin + dir * ARM
		var axis := from.cross(dir)
		if axis.length() > 1e-5:
			var angle := minf(from.angle_to(dir), deg_to_rad(k[3]))
			sk.set_bone_global_pose(i, back * Transform3D(Basis(axis.normalized(), angle) * pose.basis, pose.origin))
	for b in soft:
		var i := sk.find_bone(b)
		if i < 0:
			continue
		var k: Array = soft[b]
		var pose := world * sk.get_bone_global_pose(i)
		var s: Array = _step(b, pose.origin, k[0], k[1], Vector3.ZERO, dt)
		var off: Vector3 = (s[0] - pose.origin).limit_length(k[2])
		s[0] = pose.origin + off
		sk.set_bone_global_pose(i, back * Transform3D(pose.basis, s[0]))


func _step(bone: String, rest: Vector3, stiffness: float, damping: float, force: Vector3, dt: float) -> Array:
	if not _state.has(bone) or _state[bone][0].distance_to(rest) > 1.2:       # new, or teleported
		_state[bone] = [rest, Vector3.ZERO]
	var s: Array = _state[bone]
	for n in STEPS:
		var h := dt / STEPS
		s[1] += ((rest - s[0]) * stiffness - s[1] * damping + force) * h
		s[0] += s[1] * h
	return s

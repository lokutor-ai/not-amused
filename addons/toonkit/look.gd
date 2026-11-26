class_name HeadLook
extends SkeletonModifier3D
## Turns a head towards something on top of its clip, and nods it with the voice. Put it before JellySprings, so the
## springs feel it.

## The bone that turns, and one below it that takes part of the turn ("" = none).
@export var bone := "head"
@export var support := "chest"
## What to look at, in the world. Vector3.INF = nothing.
@export var target := Vector3.INF
@export var limit_degrees := Vector2(48, 26)          # sideways, up and down
@export_range(0.0, 1.0) var weight := 0.85
## How fast it follows (1/s).
@export var follow := 7.0
## Extra turn: yaw, pitch and roll in degrees. The game adds nods and tilts here.
var offset := Vector3.ZERO

var _aim := Vector2.ZERO
var _extra := Vector3.ZERO


func _process_modification() -> void:
	var sk := get_skeleton()
	var i := sk.find_bone(bone) if sk else -1
	if i < 0:
		return
	var dt := minf(get_process_delta_time(), 0.05)
	var want := Vector2.ZERO
	var pose := sk.get_bone_global_pose(i)
	if target != Vector3.INF:
		var d := (sk.global_transform.affine_inverse() * target) - pose.origin          # the model faces +Z
		want.x = clampf(rad_to_deg(atan2(d.x, maxf(d.z, 0.001))), -limit_degrees.x, limit_degrees.x) * weight
		want.y = clampf(rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length())), -limit_degrees.y, limit_degrees.y) * weight
	_aim = _aim.lerp(want, 1.0 - exp(-dt * follow))
	_extra = _extra.lerp(offset, 1.0 - exp(-dt * 18.0))
	if support != "":
		_turn(sk, sk.find_bone(support), 0.28)
	_turn(sk, i, 0.72 if support != "" else 1.0)


func _turn(sk: Skeleton3D, i: int, share: float) -> void:
	if i < 0:
		return
	var pose := sk.get_bone_global_pose(i)
	var r := (_aim + Vector2(_extra.x, _extra.y)) * share
	var turn := Basis(Vector3.UP, deg_to_rad(r.x)) * Basis(Vector3.RIGHT, deg_to_rad(-r.y)) * Basis(Vector3.BACK, deg_to_rad(_extra.z * share))
	sk.set_bone_global_pose(i, Transform3D(turn * pose.basis, pose.origin))

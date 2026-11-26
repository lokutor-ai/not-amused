class_name Stage
extends Node3D
## The room, the cast in their places and the camera.

## See CameraRig.
const SHOTS := {
	"title": [Vector3(0.0, 2.2, 7.6), Vector3(0.0, 2.75, 0.0), 42.0, 34.0],
	"play": [Vector3(2.0, 2.45, 9.9), Vector3(0.35, 1.7, 0.0), 37.0, 34.0],
	"king": [Vector3(0.55, 2.55, 7.2), Vector3(0.0, 2.38, 0.0), 37.0, 34.0],
	"king_close": [Vector3(0.95, 2.75, 4.7), Vector3(0.02, 2.80, 0.0), 30.0, 34.0],
	"jester": [Vector3(-0.75, 1.55, 1.35), Vector3(0.10, 1.12, 4.9), 33.0, 212.0],
	"jester_close": [Vector3(0.55, 1.35, 2.9), Vector3(0.0, 1.10, 4.9), 33.0, 212.0],
	"guard_l": [Vector3(-1.2, 1.05, 4.7), Vector3(-2.35, 1.42, 1.7), 34.0, 34.0],
	"guard_r": [Vector3(1.2, 1.05, 4.7), Vector3(2.35, 1.55, 1.7), 34.0, 34.0],
	"lever": [Vector3(0.5, 2.6, 5.0), Vector3(-0.55, 2.3, 0.2), 36.0, 34.0],
	"trap": [Vector3(1.7, 2.6, 1.2), Vector3(0.0, 0.75, 4.9), 40.0, 212.0],
	"card": [Vector3(-1.2, 2.35, 10.0), Vector3(2.15, 1.75, 0.0), 40.0, 34.0],
	"party": [Vector3(0.0, 2.55, 9.9), Vector3(0.0, 1.95, 0.0), 42.0, 34.0],
}

const COLOURS: Array[Dictionary] = [{},
	{"left": Color("#e8446a"), "right": Color("#3f6fd1"), "horn3": Color("#ffd23f"), "skin": Color("#b97a50"), "nose": Color("#a3624a"), "face_lid": Color("#a56a44"), "hair": Color("#2e2430")},
	{"left": Color("#7a52c7"), "right": Color("#8ac926"), "horn3": Color("#ff7a3d"), "skin": Color("#ffe0c4"), "face_lid": Color("#f6cfae"), "hair": Color("#e2b34a")},
	{"left": Color("#ffb02e"), "right": Color("#c2233a"), "horn3": Color("#22b8a5"), "skin": Color("#8a5536"), "nose": Color("#7a4530"), "face_lid": Color("#7a4a2f"), "hair": Color("#1d1620")}]

var room: ThroneRoom
var king: Actor
var guard_l: Actor
var guard_r: Actor
var jester: Actor
var rig: CameraRig
## The ones who wait for their turn. You see them when you turn round.
var queue: Array[Actor] = []


func _ready() -> void:
	process_priority = 10                             # after the camera has moved
	room = ThroneRoom.new()
	add_child(room)
	king = _cast("king", ThroneRoom.SEAT + Vector3(0, 0.05, 0.06), 0.0, "bored", "bored")
	guard_l = _cast("guard_round", Vector3(-2.55, 0, 1.75), 24.0, "stand", "neutral")
	guard_r = _cast("guard_tall", Vector3(2.55, 0, 1.75), -24.0, "stand", "neutral")
	jester = _cast("jester", ThroneRoom.TRAP, 180.0, "idle", "happy")
	for i in 3:
		var next := _cast("jester", Vector3([0.16, -0.14, 0.1][i], 0, 6.75 + i * 1.15), 180.0, "nervous", ["scared", "sad", "scared"][i], i + 1)
		queue.append(next)
	rig = CameraRig.new()
	rig.shots = SHOTS
	add_child(rig)
	look_around()


func _cast(kind: String, at: Vector3, turn: float, clip: String, mood: String, colours := 0) -> Actor:
	var a := Actor.create(kind)
	a.colours = COLOURS[colours]
	add_child(a)
	a.position = at
	a.rotation_degrees.y = turn
	a.idle(clip, 0.0)
	a.anim.seek(randf() * 1.5, true)
	a.mood(mood)
	return a


## Everyone minds their business: the king looks at the jester, the jester at the king.
func look_around() -> void:
	king.look.target = jester.position + Vector3(0, 1.1, 0)
	jester.look.target = king.position + Vector3(0, 1.5, 0)
	for g in [guard_l, guard_r]:
		g.look.target = Vector3.INF


func _process(_delta: float) -> void:
	room.sun.rotation_degrees.y = rig.sun_turn
	var behind := rig.camera.position.z < 6.0 and rig.camera.global_basis.z.z < 0.0       # looking back at the door
	room.back.visible = behind
	for q in queue:
		q.visible = behind


func guards() -> Array[Actor]:
	return [guard_l, guard_r]


func everyone() -> Array[Actor]:
	return [king, guard_l, guard_r, jester]

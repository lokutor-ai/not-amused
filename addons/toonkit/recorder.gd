class_name Recorder
extends Node
## Records the game as it is played, picture and sound, in real time. A conversation happens in real time, so a movie writer
## that stretches seconds cannot film one: here frames are read from the GPU without waiting and compressed on other
## threads, and the sound is what the Master bus played.
##
##   var rec := Recorder.new(); add_child(rec); rec.start("C:/take")    ...    await rec.stop()
##
## It leaves frames.bin, frames.json and audio.wav. pipeline/blender/encode.py turns the folder into an MP4.

var fps := 60
var quality := 0.88
## The window while recording: exactly this size, with no borders. Vector2i.ZERO leaves it as it is.
var size := Vector2i(1920, 1080)
var recording := false

var _folder := ""
var _file: FileAccess
var _index: Array = []                        # [seconds, offset, size]
var _started := 0
var _next := 0.0
var _rd: RenderingDevice
var _size := Vector2i.ZERO
var _jobs := {}                               # number -> [seconds, jpeg]
var _todo: Array = []
var _lock := Mutex.new()
var _more := Semaphore.new()
var _threads: Array[Thread] = []
var _number := 0
var _written := 0
var _pending := 0
var _dropped := 0
var _record: AudioEffectRecord
var _offset := 0.0
var _max_fps := 0
var _vsync := DisplayServer.VSYNC_ENABLED

## Frames waiting to be compressed, 8 MB each.
const QUEUE := 120


func start(folder: String) -> void:
	_folder = folder
	DirAccess.make_dir_recursive_absolute(folder)
	_file = FileAccess.open(folder.path_join("frames.bin"), FileAccess.WRITE)
	_rd = RenderingServer.get_rendering_device()
	_max_fps = Engine.max_fps
	_vsync = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0                               # the limiter is coarse: run free and keep a frame every 1/fps
	if size != Vector2i.ZERO:
		get_window().mode = Window.MODE_WINDOWED
		get_window().borderless = true
		get_window().size = size
		get_window().position = Vector2i.ZERO
	_record = AudioEffectRecord.new()
	_record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, _record)
	_record.set_recording_active(true)
	_started = Time.get_ticks_usec()
	# What is mixed now is heard, and shown by anything that follows the voice, a little later.
	_offset = AudioServer.get_output_latency() + AudioServer.get_time_to_next_mix()
	_next = 0.0
	recording = true
	for i in clampi(OS.get_processor_count() - 3, 2, 8):
		var t := Thread.new()
		t.start(_work)
		_threads.append(t)
	RenderingServer.frame_post_draw.connect(_grab)


func stop() -> Dictionary:
	if not recording:
		return {}
	recording = false
	RenderingServer.frame_post_draw.disconnect(_grab)
	_record.set_recording_active(false)
	var wav := _record.get_recording()
	var waited := 0
	while _pending > 0 and waited < 3000:
		await get_tree().process_frame
		waited += 1
	for t in _threads:
		_more.post()
	for t in _threads:
		t.wait_to_finish()
	_threads.clear()
	_file.close()
	if wav:
		wav.save_to_wav(_folder.path_join("audio.wav"))
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) == _record:
			AudioServer.remove_bus_effect(0, i)
			break
	var info := {"width": _size.x, "height": _size.y, "fps": fps, "frames": _index, "audio_offset": _offset, "dropped": _dropped}
	var f := FileAccess.open(_folder.path_join("frames.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(info))
	f.close()
	Engine.max_fps = _max_fps
	DisplayServer.window_set_vsync_mode(_vsync)
	print("RECORDED %d frames, %.1f s, %d dropped -> %s" % [_index.size(), _index[-1][0] if _index.size() else 0.0, _dropped, _folder])
	return info


func _grab() -> void:
	var now := (Time.get_ticks_usec() - _started) / 1000000.0
	if now < _next:
		return
	_next = maxf(_next + 1.0 / fps, now - 1.0 / fps)
	if _pending >= QUEUE:
		_dropped += 1
		return
	var tex := get_viewport().get_texture()
	_size = tex.get_size()
	var rid := RenderingServer.texture_get_rd_texture(tex.get_rid())
	var n := _number
	_number += 1
	_pending += 1
	var fmt := _rd.texture_get_format(rid)
	var size := Vector2i(fmt.width, fmt.height)
	var half := fmt.format == RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	var ten := fmt.format == RenderingDevice.DATA_FORMAT_A2B10G10R10_UNORM_PACK32
	_rd.texture_get_data_async(rid, 0, func(data: PackedByteArray):
		_lock.lock()
		_todo.append([n, now, data, size, half, ten])
		_lock.unlock()
		_more.post())


func _work() -> void:
	while true:
		_more.wait()
		_lock.lock()
		var job: Array = _todo.pop_front() if not _todo.is_empty() else []
		_lock.unlock()
		if job.is_empty():                               # told to stop
			return
		_compress.callv(job)


func _compress(n: int, at: float, data: PackedByteArray, size: Vector2i, half: bool, ten: bool) -> void:
	var img: Image
	if ten:
		push_error("Recorder: turn HDR 2D off to record.")
		img = Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	else:
		img = Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBAH if half else Image.FORMAT_RGBA8, data)
	img.convert(Image.FORMAT_RGB8)
	var jpeg := img.save_jpg_to_buffer(quality)
	_lock.lock()                                     # whoever has the next one writes it: the game never waits for the disk
	_jobs[n] = [at, jpeg]
	while _jobs.has(_written):
		var j: Array = _jobs[_written]
		_jobs.erase(_written)
		_index.append([j[0], _file.get_position(), (j[1] as PackedByteArray).size()])
		_file.store_buffer(j[1])
		_written += 1
		_pending -= 1
	_lock.unlock()

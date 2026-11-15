extends SceneTree
## Capturas de tela ampliadas 4x (precisa de janela, não rodar com --headless):
##   Godot.exe --path . -s tests/shot.gd -- <pasta de saída>
## Gera cada sala no estado inicial e alguns estados intermediários.

const Levels := preload("res://scripts/levels.gd")

var main
var step := 0
var out_dir := "user://shots"
var plan: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in Levels.ROOMS.size():
		plan.append({"name": "room_%d" % (i + 1), "room": i, "mode": ""})
	plan.append({"name": "room_1_gate_open", "room": 0, "mode": "fill_gate"})
	plan.append({"name": "room_2_rotated", "room": 1, "mode": "rotate"})
	plan.append({"name": "room_5_top", "room": 4, "mode": "top"})
	plan.append({"name": "room_4_pads", "room": 3, "mode": "rotate"})


func _process(_delta: float) -> bool:
	step += 1
	var phase := step % 60
	var i: int = step / 60
	if i >= plan.size():
		quit()
		return false
	var item: Dictionary = plan[i]
	var r = main.room
	if phase == 1:
		main._load_room(item["room"])
	elif phase == 6:
		if item["mode"] == "fill_gate":
			for k in r.sockets.size():
				if r.socket_group[k] == 1:
					r.boxes[1].pos = r.sockets[k].position
		elif item["mode"] == "rotate":
			r.step({"rotate": 1})
		elif item["mode"] == "top":
			r.rabbit.pos = Vector2i(60, 116)
			r.cam = r._cam_target()
	elif phase == 50:
		var img := root.get_viewport().get_texture().get_image()
		img.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
		img.save_png("%s/%s.png" % [out_dir, item["name"]])
	return false

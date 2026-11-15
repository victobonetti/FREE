extends SceneTree
## Capturas de tela ampliadas 4x (precisa de janela, não rodar com --headless):
##   Godot.exe --path . -s tests/shot.gd -- <pasta de saída>
## Gera: cada sala no estado inicial, a sala 1 com a porta aberta e a sala 3 recarregando o giro.

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
	plan.append({"name": "door_open", "room": 0, "mode": "open"})
	plan.append({"name": "cooldown", "room": 2, "mode": "rotate"})
	plan.append({"name": "win_fx", "room": 0, "mode": "win"})
	plan.append({"name": "sensor_fx", "room": 0, "mode": "open", "at": 11})
	plan.append({"name": "door_open_ceiling", "room": 2, "mode": "open"})


func _process(_delta: float) -> bool:
	step += 1
	var phase := step % 40
	var i: int = step / 40
	if i >= plan.size():
		quit()
		return false
	var item: Dictionary = plan[i]
	if phase == 1:
		main._load_room(item["room"])
	elif phase == 6:
		if item["mode"] == "open":
			main.room.boxes[0].pos = main.room.sockets[0].position
		elif item["mode"] == "rotate":
			main.room.step({"rotate": 1})
		elif item["mode"] == "win":
			main.room.boxes[0].pos = main.room.sockets[0].position
			main.room.rabbit.pos = main.room.door.position + Vector2i(2, 20)
	elif phase == item.get("at", 34):
		var img := root.get_viewport().get_texture().get_image()
		img.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
		img.save_png("%s/%s.png" % [out_dir, item["name"]])
	return false

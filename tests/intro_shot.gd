extends SceneTree
## Capturas da abertura, ampliadas 4x (precisa de janela):
##   Godot.exe --path . -s tests/intro_shot.gd -- <pasta de saída>

var main
var n := 0
var out_dir := "user://shots"
# quadro de física (aprox.) em que cada captura é tirada, contado a partir do Enter
var shots := {
	-30: "intro_1_titulo", 40: "intro_2_susto", 95: "intro_3_caindo", 130: "intro_4_vazio",
	260: "intro_5_queda", 395: "intro_6_pouso", 440: "intro_7_expande", 500: "intro_8_lados",
	585: "intro_9_porta", 640: "intro_10_sala",
}
var pressed_at := -1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _physics_process(_delta: float) -> bool:
	n += 1
	if n == 60 and main.intro != null:
		main.intro.step(true)  # aperta Enter
		pressed_at = n
	var rel := n - (pressed_at if pressed_at >= 0 else 60)
	if shots.has(rel):
		var img := root.get_viewport().get_texture().get_image()
		img.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
		img.save_png("%s/%s.png" % [out_dir, shots[rel]])
	if rel > 650:
		quit()
	return false

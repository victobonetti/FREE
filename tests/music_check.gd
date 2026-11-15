extends SceneTree
## Confere a música: Godot_console.exe --headless --path . -s tests/music_check.gd

var main
var t := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += 1
	if t == 180:
		var s = main.music.stream
		print("tocando: ", main.music.playing)
		print("faixa: ", main.music_path)
		print("tipo: ", s.get_class() if s else "nenhum", "  loop: ", s.loop if s else "-")
		print("duração: %.1f s" % (s.get_length() if s else 0.0))
		print("volume: %.1f dB" % main.music.volume_db)
		main._load_room(1)
	if t == 200:
		print("depois de trocar de sala, continua a mesma faixa: ", main.music.playing and main.music_path != "")
		quit()
	return false

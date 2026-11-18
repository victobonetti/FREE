extends SceneTree
## Refaz o replay de uma fase da campanha a partir da rota do robô, sem mexer no arquivo da fase
## (que pode ter campos postos à mão, como "music"). Só grava se o replay vencer. Uso:
##   godot --headless --path . -s tools/update_replay.gd -- <id na campanha>=<id da rota> ...
## (a rota é tests/fixtures/route-<id da rota>.json)

const Levels := preload("res://scripts/levels.gd")
const LevelData := preload("res://scripts/level_data.gd")
const Replay := preload("res://scripts/replay.gd")


func _initialize() -> void:
	var bad := 0
	for a in OS.get_cmdline_user_args():
		if not a.contains("="):
			continue
		var cid: String = a.split("=")[0]
		var rid: String = a.split("=")[1]
		var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/route-%s.json" % rid))
		var runs: Array = []
		for r in route["runs"]:
			var k: Array = r[1]
			Replay.record_n(runs, int(r[0]), {"move": float(k[0]), "jump_pressed": int(k[1]) == 1, "jump_held": int(k[2]) == 1, "rotate": int(k[3])})
		var raw := FileAccess.get_file_as_string(Levels.level_path(cid))
		var data: RefCounted = LevelData.from_json(raw)
		var def: Dictionary = Levels.by_id(cid)
		load("res://scripts/boss_gatsby.gd").intro_seen = false
		var rep := Replay.pack(runs, data.content_hash(), Replay.capture_state(def))
		var res: Dictionary = Replay.run(def, rep)
		if not res["won"]:
			print("%s: o replay NÃO vence; nada gravado" % cid)
			bad += 1
			continue
		Replay.save_file(Levels.replay_path(cid), rep)
		print("%s: replay refeito (vence no quadro %d)" % [cid, res["frame"]])
	quit(1 if bad > 0 else 0)

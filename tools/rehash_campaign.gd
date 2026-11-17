extends SceneTree
## Atualiza o hash dos replays da campanha quando o cálculo do hash muda sem mudar a jogabilidade
## (por exemplo, um campo passou a ser só aparência). Só atualiza se o replay continuar vencendo.
##   godot --headless --path . -s tools/rehash_campaign.gd

const Levels := preload("res://scripts/levels.gd")
const LevelData := preload("res://scripts/level_data.gd")
const Replay := preload("res://scripts/replay.gd")


func _initialize() -> void:
	var bad := 0
	for id in Levels.ids():
		var raw := FileAccess.get_file_as_string(Levels.level_path(id))
		var d: Dictionary = JSON.parse_string(raw)
		var data: RefCounted = LevelData.from_json(raw)
		var h: String = data.content_hash()
		var old_vh := str(d.get("verified_hash", ""))
		var rp := Levels.replay_path(id)
		if FileAccess.file_exists(rp):
			var rep: Dictionary = Replay.load_file(rp)
			if str(rep.get("hash", "")) != h:
				var res: Dictionary = Replay.run(Levels.by_id(id), rep)
				if not res["won"]:
					print("%s: o replay NÃO vence; não mudei nada" % id)
					bad += 1
					continue
				var was := str(rep["hash"])
				rep["hash"] = h
				Replay.save_file(rp, rep)
				print("%s: replay atualizado (vence no quadro %d)" % [id, res["frame"]])
				if old_vh == was:
					d["verified_hash"] = h
		if d.get("verified", false) and old_vh != h and str(d.get("verified_hash", "")) != h:
			d["verified_hash"] = h
			print("%s: verified_hash atualizado" % id)
		if str(d.get("verified_hash", "")) != old_vh:
			var f := FileAccess.open(Levels.level_path(id), FileAccess.WRITE)
			f.store_string(raw.replace(old_vh, str(d["verified_hash"])))
			f.close()
	quit(1 if bad > 0 else 0)

extends SceneTree
## A regra do giro (D121) nas fases da campanha: do começo à porta, com e sem giro.
##   godot --headless --path . -s tools/world/check_levels.gd [-- id ...]

const Check := preload("res://scripts/world_check.gd")


func _init() -> void:
	var ids: Array = Array(OS.get_cmdline_user_args())
	if ids.is_empty():
		var order = JSON.parse_string(FileAccess.get_file_as_string("res://levels/campaign/ordem.json"))
		ids = order if order is Array else order.get("ordem", [])
	for id in ids:
		var path := "res://levels/campaign/%s.json" % id
		if not FileAccess.file_exists(path):
			path = "res://levels/wip/%s.json" % id
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		var t0 := Time.get_ticks_msec()
		var r := Check.level_skip(d)
		if r.is_empty():
			print("%-20s (sem começo ou porta)" % id)
			continue
		var flag := ""
		if r["dist"] >= Check.SKIP_MIN_DIST and float(r["rot"]) < Check.SKIP_RATIO * r["dist"] and float(r["rot"]) < Check.SKIP_VS_UP * r["up"]:
			flag = "  <-- PULA"
		print("%-20s dist %4d  com giro %6s  sem giro %6s  (%d ms)%s" % [id, r["dist"], str(r["rot"]) if r["rot"] < Check.INF else "-", str(r["up"]) if r["up"] < Check.INF else "-", Time.get_ticks_msec() - t0, flag])
	quit()

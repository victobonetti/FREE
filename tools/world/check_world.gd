extends SceneTree
## Confere o mundo (D120, D121): o mapa fecha, nenhuma sala se atravessa só girando, e dá para
## chegar a tudo na ordem do plano (progressão).
##   godot --headless --path . -s tools/world/check_world.gd [-- sala ...]   (com salas: só o giro delas, detalhado)

const World := preload("res://scripts/world.gd")
const Check := preload("res://scripts/world_check.gd")


func _init() -> void:
	var w := World.load_world()
	var only: Array = Array(OS.get_cmdline_user_args())
	if not only.is_empty() and only[0] == "trace":
		# trace <sala> <entrada> <alvo> [habilidades...]
		var ab2 := {}
		for a in only.slice(4):
			ab2[a] = true
		var tg = only[3]
		if String(tg).is_valid_int():
			tg = int(tg)
		for st in Check.trace_path(World.load_room_def(only[1]), ab2, int(only[2]), tg):
			print("  giro %d  (%d, %d)  %s" % [st[0], st[1], st[2], ["chão", "ar", "ar2"][st[3]]])
		quit()
		return
	if not only.is_empty() and only[0] == "reach":
		# reach <sala> [habilidades...]: de cada saída, aonde se chega (modo alcance)
		var ab := {}
		for a in only.slice(2):
			ab[a] = true
		var def := World.load_room_def(only[1])
		var p := Check.paths(def, ab, {}, true, true)
		for e in p:
			print("  de %d: %s" % [e, str(p[e])])
		quit()
		return
	var bad := 0
	if only.is_empty():
		var probs := World.problems(w)
		print("mapa: %d problemas" % probs.size())
		for p in probs:
			print("  ", p)
		bad += probs.size()
	var t0 := Time.get_ticks_msec()
	var skips := 0
	for r in World.rooms(w):
		var id := str(r["id"])
		if not only.is_empty() and not only.has(id):
			continue
		var def := World.load_room_def(id)
		var sk := Check.flip_skips(def)
		for s in sk:
			print("  GIRO PULA %s: saída %d -> %d (distância %d; com giro %d, sem giro %s)" % [id, s["from"], s["to"], s["dist"], s["rot"],
				str(s["up"]) if int(s["up"]) < Check.INF else "não passa"])
			skips += 1
	print("giro: %d pulos (%d ms)" % [skips, Time.get_ticks_msec() - t0])
	bad += skips
	if only.is_empty():
		t0 = Time.get_ticks_msec()
		var pr := Check.progression(w)
		var i := 0
		for wv in pr["waves"]:
			i += 1
			print("onda %d: %d salas; ganha %s" % [i, wv["rooms"], ", ".join(wv["gains"])])
		print("faltam %d salas: %s (%d ms)" % [pr["missing"].size(), str(pr["missing"]), Time.get_ticks_msec() - t0])
	print("TOTAL: %d problemas" % bad)
	quit(1 if bad > 0 else 0)

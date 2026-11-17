extends SceneTree
## Canoniza as fases de levels/wip na campanha, logo depois de uma fase (padrão: jeffrey), usando a
## rota do robô (tests/fixtures/route-<id>.json) como replay. Uso:
##
##   godot --headless --path . -s tools/canonize_levels.gd -- jeffrey montagem esteiras prensas dutos forca
##
## O primeiro argumento é a fase depois da qual inserir; os demais são os ids em levels/wip, na ordem.
## A rota é tests/fixtures/route-<id>.json (ou <id>-route.json). Um id com "bot:" na frente entra sem
## replay (luta de boss provada por um teste-bot em tests/run_tests.gd, como o Jeffrey): o teste
## test_campaign_proof exige que ele esteja em BOT_IDS.
## Se já houver na campanha uma fase com o mesmo nome, ela é substituída no mesmo lugar.

const Levels := preload("res://scripts/levels.gd")
const LevelData := preload("res://scripts/level_data.gd")
const CampaignStore := preload("res://scripts/campaign_store.gd")
const Replay := preload("res://scripts/replay.gd")


func _initialize() -> void:
	var args: Array = []
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			args.append(a)
	var after: String = args[0]
	var at: int = Levels.ids().find(after) + 1
	if at <= 0:
		print("fase '%s' não está na campanha" % after)
		quit(1)
		return
	var bad := 0
	for i in range(1, args.size()):
		var wip: String = args[i]
		var by_bot := wip.begins_with("bot:")
		wip = wip.trim_prefix("bot:")
		var raw := FileAccess.get_file_as_string("res://levels/wip/%s.json" % wip)
		var data: RefCounted = LevelData.from_json(raw)
		if data == null:
			print("%s: JSON inválido" % wip)
			bad += 1
			continue
		if by_bot:
			var bid := _canonize_bot(data, at)
			if bid == "":
				bad += 1
				continue
			print("%s -> campanha '%s' na posição %d (prova: bot)" % [wip, bid, at + 1])
			at += 1
			continue
		var rpath := "res://tests/fixtures/route-%s.json" % wip
		if not FileAccess.file_exists(rpath):
			rpath = "res://tests/fixtures/%s-route.json" % wip
		var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(rpath))
		var runs: Array = []
		for r in route["runs"]:
			var k: Array = r[1]
			Replay.record_n(runs, int(r[0]), {"move": float(k[0]), "jump_pressed": int(k[1]) == 1, "jump_held": int(k[2]) == 1, "rotate": int(k[3])})
		var def: Dictionary = JSON.parse_string(raw)
		load("res://scripts/boss_gatsby.gd").intro_seen = false
		var replay := Replay.pack(runs, data.content_hash(), Replay.capture_state(def))
		var res: Dictionary = Replay.run(def, replay)
		if not res["won"]:
			print("%s: o replay não vence" % wip)
			bad += 1
			continue
		data.mark_verified()
		# a mesma fase (mesmo nome) já está na campanha: substitui no lugar
		var same := ""
		for cid in Levels.ids():
			if str(Levels.by_id(cid).get("name", "")) == data.name:
				same = cid
		var out: Dictionary = CampaignStore.canonize(data, replay, same, at)
		if out.has("erro"):
			print("%s: %s" % [wip, out["erro"]])
			bad += 1
			continue
		print("%s -> campanha '%s' (%s; vence no quadro %d)" % [wip, out["id"], "substituída" if same != "" else "posição %d" % (at + 1), res["frame"]])
		if same == "":
			at += 1
	quit(1 if bad > 0 else 0)


## Fase sem replay (boss provado por bot): grava a fase marcada como verificada e a põe na ordem.
func _canonize_bot(data: RefCounted, at: int) -> String:
	if not data.errors().is_empty():
		print("Corrija: %s" % data.errors()[0]["msg"])
		return ""
	data.mark_verified()
	var ids: Array = Levels.ids()
	var id: String = ""
	for cid in ids:
		if str(Levels.by_id(cid).get("name", "")) == data.name:
			id = cid
	if id == "":
		id = CampaignStore.free_id(data.name)
		ids.insert(clampi(at, 0, ids.size()), id)
	var f := FileAccess.open(Levels.level_path(id), FileAccess.WRITE)
	f.store_string(data.to_json() + "\n")
	f.close()
	CampaignStore._save_order(ids)
	return id

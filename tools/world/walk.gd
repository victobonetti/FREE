extends SceneTree
## O robô do mundo (D124) no caminho do jogo: atravessa cada sala nova (as que não são fases da
## campanha) na física de verdade, na ordem do jogo e com as habilidades de cada ponto, e grava as
## rotas em tests/fixtures/world/walk-<sala>-<de>-<para>.json (o teste do mundo roda de novo).
##
##   godot --headless --path . -s tools/world/walk.gd [-- sala ...]   (com salas: só os trechos delas)

const World := preload("res://scripts/world.gd")
const Check := preload("res://scripts/world_check.gd")
const Walker := preload("res://scripts/world_walker.gd")
const RoomScript := preload("res://scripts/room.gd")
const Route := preload("res://tools/world/route.gd")

var w: Dictionary


func _init() -> void:
	w = World.load_world()
	var only: Array = Array(OS.get_cmdline_user_args())
	var ok := 0
	var bad: Array = []
	for seg in Route.SEGMENTS:
		if not only.is_empty() and not only.has(seg[0]):
			continue
		var res := run_segment(seg)
		if res == "":
			ok += 1
		else:
			bad.append("%s: %s" % [Route.name_of(seg), res])
	for b in bad:
		print("  FALHOU ", b)
	print("trechos: %d passaram, %d falharam" % [ok, bad.size()])
	quit(0 if bad.is_empty() else 1)


## Roda um trecho e grava a rota. "" se passou; senão, o motivo.
func run_segment(seg: Array) -> String:
	var id: String = seg[0]
	var entry: int = Route.exit_index(w, id, seg[1])
	var targets: Array = seg[2]
	var ab: Dictionary = Route.abilities(seg[3])
	var def := Route.world_def(w, id, entry, ab, seg[4] if seg.size() > 4 else {})
	var room: Node2D = RoomScript.new()
	room.setup(def)
	var wk := Walker.new()
	wk.debug = int(OS.get_environment("WALK_DEBUG")) if OS.get_environment("WALK_DEBUG") != "" else 0
	for t in targets:
		var tgt = Route.target(w, id, t)
		var done: Callable
		if typeof(tgt) == TYPE_STRING and String(tgt).contains("@"):
			var ko := String(tgt).split("@")
			done = func(): return room.state == "exit" and room.exit_index == int(ko[0]) and posmod(room.exit_orient, 4) == int(ko[1])
		elif typeof(tgt) == TYPE_STRING:
			var idx := int(String(tgt).substr(1))
			done = func(): return room.pickups[idx]["taken"]
		else:
			done = func(): return room.state == "exit" and room.exit_index == int(tgt)
		if not wk.drive(room, room.def, ab, tgt, done):
			var msg := "rumo a %s: %s" % [str(t), wk.log]
			room.free()
			return msg
	var frames := 0
	for r in wk.runs:
		frames += int(r[0])
	var f := FileAccess.open(Route.fixture(seg), FileAccess.WRITE)
	f.store_string(JSON.stringify({"frames": frames, "runs": wk.runs}) + "\n")
	f.close()
	print("  ok %s (%d quadros)" % [Route.name_of(seg), frames])
	room.free()
	return ""

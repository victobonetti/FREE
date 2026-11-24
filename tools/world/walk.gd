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
	wk.room = room
	wk.debug = int(OS.get_environment("WALK_DEBUG")) if OS.get_environment("WALK_DEBUG") != "" else 0
	for t in targets:
		if String(t).begins_with("do:"):
			# um trecho à mão (empurrar caixa): as funções abaixo, com realimentação
			var why: String = call("_do_" + String(t).substr(3), room, wk)
			if why != "":
				room.free()
				return "%s: %s" % [t, why]
			continue
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


# ---------------------------------------------------------------- trechos à mão (caixas)

func _act(room: Node2D, wk, cond: Callable, inp: Callable, limit: int) -> bool:
	for f in limit:
		if cond.call():
			return true
		if room.state == "dead":
			return false
		wk._tick(inp.call(f))
	return cond.call()


func _x(room) -> float:
	return float(room.rabbit.pos.x) + 6.0


## Pula para o lado `dir` segurando o pulo, até pousar.
func _hop(room: Node2D, wk, dir: float) -> bool:
	wk._tick({"move": dir, "jump_pressed": true, "jump_held": true})
	return _act(room, wk, func(): return room.rabbit.on_ground, func(f): return {"move": dir, "jump_held": f < 12}, 120)


## Primeiros passos: o degrau da entrada, a caixa até a parede, sobe na caixa e na parede.
func _do_r1_box(room: Node2D, wk) -> String:
	if not _act(room, wk, func(): return _x(room) < 26 * 8 + 4, func(_f): return {"move": -1.0}, 400):
		return "não chegou ao degrau"
	_hop(room, wk, -1.0)
	var b = room.boxes[0]
	if not _act(room, wk, func(): return b.pos.x <= 7 * 8 and b.settled, func(_f): return {"move": -1.0}, 600):
		return "não empurrou a caixa até a parede (caixa em %s)" % str(b.pos)
	_act(room, wk, func(): return _x(room) > b.pos.x + 16 + 10, func(_f): return {"move": 1.0}, 120)
	_hop(room, wk, -1.0)
	if room.rabbit.pos.y + 12 > b.pos.y + 1:
		return "não subiu na caixa (coelho %s, caixa %s)" % [str(room.rabbit.pos), str(b.pos)]
	_hop(room, wk, -1.0)
	return "" if room.rabbit.pos.y + 12 <= 13 * 8 else "não subiu na parede (coelho %s)" % str(room.rabbit.pos)


## Raiz torta: empurra a caixa da prateleira para o vão, dá a volta por baixo da prateleira, empurra a
## caixa até a parede, sobe nela e na parede.
func _do_r3_box(room: Node2D, wk) -> String:
	var b = room.boxes[0]
	# sobe da entrada até a prateleira, andando e pulando os degraus (parado contra um: pulo inteiro)
	var blocked := 0
	var last_x := -1
	for f in 1500:
		if b.pos.y > 14 * 8 or room.state == "dead":
			break
		if room.rabbit.on_ground and room.rabbit.pos.x == last_x:
			blocked += 1
		else:
			blocked = 0
		last_x = room.rabbit.pos.x
		if blocked >= 3:
			_hop(room, wk, -1.0)
			blocked = 0
		else:
			wk._tick({"move": -1.0})
	if b.pos.y <= 14 * 8:
		return "a caixa não caiu da prateleira (caixa em %s, coelho %s)" % [str(b.pos), str(room.rabbit.pos)]
	_act(room, wk, func(): return b.settled and room.rabbit.on_ground, func(_f): return {}, 120)
	if OS.get_environment("WALK_DEBUG") != "":
		print("    caixa caiu: caixa %s, coelho %s" % [str(b.pos), str(room.rabbit.pos)])
	# do lado direito da caixa (embaixo da prateleira): ainda na prateleira, desce na caixa; em cima
	# dela, anda para a direita e desce; se ficou à esquerda, sobe nela antes
	if room.rabbit.pos.y + 12 <= 14 * 8:
		_act(room, wk, func(): return not room.rabbit.on_ground, func(_f): return {"move": -0.5}, 120)
		_act(room, wk, func(): return room.rabbit.on_ground, func(_f): return {}, 120)
	if room.rabbit.pos.y + 12 > b.pos.y + 1 and _x(room) < b.pos.x + 8:
		_act(room, wk, func(): return _x(room) < b.pos.x - 10, func(_f): return {"move": -1.0}, 60)
		_hop(room, wk, 1.0)
	_act(room, wk, func(): return _x(room) > b.pos.x + 16 + 8 and room.rabbit.on_ground and room.rabbit.pos.y + 12 > b.pos.y + 8,
		func(_f): return {"move": 1.0}, 120)
	if OS.get_environment("WALK_DEBUG") != "":
		print("    do lado: caixa %s, coelho %s" % [str(b.pos), str(room.rabbit.pos)])
	if not _act(room, wk, func(): return b.pos.x <= 33 * 8 + 1 and b.settled, func(_f): return {"move": -1.0}, 600):
		return "não empurrou a caixa até a parede (caixa em %s, coelho %s)" % [str(b.pos), str(room.rabbit.pos)]
	_act(room, wk, func(): return _x(room) > b.pos.x + 16 + 10, func(_f): return {"move": 1.0}, 120)
	_hop(room, wk, -1.0)
	if room.rabbit.pos.y + 12 > b.pos.y + 1:
		return "não subiu na caixa (coelho %s, caixa %s)" % [str(room.rabbit.pos), str(b.pos)]
	_hop(room, wk, -1.0)
	return "" if room.rabbit.pos.y + 12 <= 14 * 8 else "não subiu na parede (coelho %s)" % str(room.rabbit.pos)

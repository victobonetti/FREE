extends SceneTree
## Robô genérico: joga uma fase de levels/wip seguindo um roteiro de passos (tools/plans/<id>.json,
## escrito por tools/levelkit.py junto com a fase) e, se vencer sem morrer, grava a rota quadro a
## quadro em tests/fixtures/route-<id>.json. É a prova de que a fase tem solução; os testes rodam
## essa rota. Uso:
##
##   godot --headless --path . -s tools/robot.gd -- <id> [--dry]
##
## Passos (cada um é uma lista; posições em px do centro do coelho, na sala como foi desenhada):
##   ["run_to", x]                       corre no chão até x
##   ["edge_jump", dir, hold, x0, x1, linha, seguro]   corre até sair da beirada, pula e dirige para
##                                       pousar em [x0, x1], na superfície da `linha` (o robô confere os
##                                       dois; linha -1 = não conferir a altura, p.ex. em elevador).
##                                       `seguro` (opcional): pula quando o centro do corpo passa
##                                       da beirada, e não no último instante (perto de ácido)
##   ["walk_off", dir, x0, x1, linha]    anda até cair e dirige para pousar
##   ["jump_in_place", dir, hold, x0, x1, linha] pula já, sem esperar a beirada
##   ["wait", quadros]
##   ["wait_mover", i, "off"|"on", min_restante]   espera o conector i encaixado ali, com pelo menos
##                                       `min_restante` quadros até ele sair
##   ["wait_vent", i, min_fechado]       espera o jato i fechado, com pelo menos esse tempo até abrir
##   ["wait_vent_future", i, em, janela] espera até o jato i estar fechado daqui a `em` quadros e
##                                       continuar fechado por `janela` quadros (para uma subida que
##                                       vai cruzar o jato mais tarde)
##   ["wait_cutscene"]                   espera a cena da alavanca acabar
##   ["wait_until", "box_settled"]       espera a caixa da calha pousar
##   ["push_box", x_alvo]                empurra a caixa (da esquerda) até a posição x_alvo (px do canto)
##   ["hold_move", dir, quadros]         anda um tempo, sem olhar o chão
##   ["lift", x, y_topo]                 entra na coluna de ar e sobe até y (centro) com `jump` solto
##   ["to_door"]                         corre até a porta e entra
##   ["mark", rótulo]

const RoomScript := preload("res://scripts/room.gd")

var id := ""
var room: Node2D
var runs: Array = []
var frame := 0
var dead := false
var failed := ""
var step_i := 0
var plan: Array = []
var deaths_at := -1
var min_crusher_gap := 1e9


func _initialize() -> void:
	var dry := false
	for a in OS.get_cmdline_user_args():
		if a == "--dry":
			dry = true
		elif not a.begins_with("--"):
			id = a
	var def: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/wip/%s.json" % id))
	plan = JSON.parse_string(FileAccess.get_file_as_string("res://tools/plans/%s.json" % id))["steps"]
	room = RoomScript.new()
	room.setup(def)
	for s in plan:
		if dead or failed != "":
			break
		_run_step(s)
		step_i += 1
	var ok: bool = not dead and failed == "" and (room.state == "won" or room.state == "done")
	var bats := "%d/%d baterias" % [room.bat_got, room.batteries.size()]
	if min_crusher_gap < 1e8:
		bats += ", menor folga para a parede: %.0f px" % min_crusher_gap
	print("%s: %s no quadro %d (%.1f s), %s%s" % [id, "VENCEU" if ok else "NÃO VENCEU (%s)" % room.state, frame, frame / 60.0, bats, "  FALHA: " + failed if failed != "" else ""])
	if ok and not dry:
		var f := FileAccess.open("res://tests/fixtures/route-%s.json" % id, FileAccess.WRITE)
		f.store_string(JSON.stringify({"frames": frame, "note": "rota do robô (tools/robot.gd): [quadros, [move, jump_pressed, jump_held, rotate]]", "runs": runs}) + "\n")
		f.close()
		print("  rota gravada em tests/fixtures/route-%s.json" % id)
	quit(0 if ok else 1)


# ---------------------------------------------------------------- primitivas

func tick(move := 0.0, jp := false, jh := false, rot := 0) -> void:
	if dead or failed != "":
		return
	var k := [snappedf(move, 0.01), 1 if jp else 0, 1 if jh else 0, rot]
	if not runs.is_empty() and runs[-1][1] == k:
		runs[-1][0] += 1
	else:
		runs.append([1, k])
	room.step({"move": move, "jump_pressed": jp, "jump_held": jh, "rotate": rot})
	frame += 1
	for c in room.crushers:
		if c["wait"] == 0 and c["adv"] > 0.0 and room.overlaps(room.rabbit.rect, c["lane"]):
			min_crusher_gap = minf(min_crusher_gap, room.crusher_gap(c))
	if room.state == "dead":
		dead = true
		print("  MORREU no quadro %d, passo %d %s, em %s" % [frame, step_i, str(plan[step_i]), str(room.rabbit.pos)])


func cx() -> float:
	return float(room.rabbit.pos.x) + 6.0


func grounded() -> bool:
	return room.rabbit.on_ground


func fail(msg: String) -> void:
	if failed == "":
		failed = "passo %d %s: %s (coelho em %s, no chão: %s, vel %s)" % [step_i, str(plan[step_i]), msg, str(room.rabbit.pos), str(grounded()), str(room.rabbit.vel)]
		for i in room.movers.size():
			var m: Dictionary = room.movers[i]
			failed += "\n    conector %d em %s, quer ligar: %s, encaixado: %s" % [i, str(m["r"].position), str(room.mover_wants_on(m)), str(room.mover_docked(m))]


func wait(n: int) -> void:
	for i in n:
		tick()


func until(cond: Callable, limit: int, what: String) -> bool:
	var n := 0
	while not dead and failed == "" and not cond.call() and n < limit:
		tick()
		n += 1
	if n >= limit:
		fail("esperou %d quadros por: %s" % [limit, what])
		return false
	return true


## No ar: dirige para o meio de [x0, x1] até pousar. `hold` quadros com o botão de pulo apertado.
func air(x0: float, x1: float, hold: int, limit := 160) -> void:
	var tgt := (x0 + x1) / 2.0
	var held := 0
	for i in limit:
		if dead or failed != "":
			return
		var d := tgt - cx()
		var mv := clampf(d / 10.0, -1.0, 1.0)
		if absf(d) < 2.0:
			mv = 0.0
		tick(mv, false, held < hold)
		held += 1
		if i > 3 and grounded():
			return
	fail("não pousou")


func landed_in(x0: float, x1: float, row: int) -> void:
	if failed != "" or dead:
		return
	if not grounded():
		tick()
	if cx() < x0 - 3.0 or cx() > x1 + 3.0:
		fail("pousou fora de [%d, %d]: x=%.0f" % [x0, x1, cx()])
	elif row >= 0 and absi(room.rabbit.pos.y + 12 - row * 8) > 2:
		fail("pousou na altura errada: pés em y=%d, a linha %d fica em y=%d" % [room.rabbit.pos.y + 12, row, row * 8])


# ---------------------------------------------------------------- passos

func _run_step(s: Array) -> void:
	match s[0]:
		"run_to":
			var x: float = s[1]
			var n := 0
			while not dead and absf(cx() - x) > 1.5 and n < 800:
				tick(1.0 if cx() < x else -1.0)
				n += 1
			wait(2)
		"edge_jump":
			var dir: float = s[1]
			var safe: bool = s.size() > 6 and bool(s[6])
			var n := 0
			while not dead and grounded() and n < 800:
				if safe and not room.solid_static(Rect2i(int(cx()) , room.rabbit.pos.y + 12, 1, 1)):
					break
				tick(dir)
				n += 1
			if n >= 800:
				fail("não chegou à beirada")
				return
			tick(dir, true, true)
			air(s[3], s[4], int(s[2]))
			landed_in(s[3], s[4], int(s[5]))
		"jump_in_place":
			var dir: float = s[1]
			tick(dir, true, true)
			air(s[3], s[4], int(s[2]))
			landed_in(s[3], s[4], int(s[5]))
		"walk_off":
			var dir: float = s[1]
			var n := 0
			while not dead and grounded() and n < 800:
				tick(dir)
				n += 1
			air(s[2], s[3], 0)
			landed_in(s[2], s[3], int(s[4]))
		"wait":
			wait(int(s[1]))
		"wait_mover":
			var m: Dictionary = room.movers[int(s[1])]
			var want_on: bool = s[2] == "on"
			until(func(): return room.mover_docked(m) and room.mover_wants_on(m) == want_on and _dock_left(m) >= int(s[3]), 1200, "conector %d em '%s'" % [s[1], s[2]])
		"wait_vent_future":
			var vf: Dictionary = room.vents[int(s[1])]
			until(func(): return _vent_closed_at(vf, int(s[2]), int(s[3])), 1500, "jato %d fechado daqui a %d quadros" % [s[1], s[2]])
		"wait_vent":
			var v: Dictionary = room.vents[int(s[1])]
			until(func(): return not v["active"] and not v["warn"] and _vent_closed_left(v) >= int(s[2]), 1200, "jato %d fechado" % s[1])
		"wait_cutscene":
			until(func(): return not room.input_lock and (room.lever == null or room.lever["t"] < 0 or room.lever["t"] >= room.LEVER_PAN + room.LEVER_PULL + room.LEVER_WATCH), 900, "a cena da alavanca")
		"wait_until":
			if s[1] == "box_settled":
				until(func(): return not room.boxes.is_empty() and room.boxes[0].settled, 900, "a caixa pousar")
			elif s[1] == "door_open":
				until(func(): return room.door_open, int(s[2]) if s.size() > 2 else 1500, "a porta abrir (a caixa chegar ao compartimento)")
		"push_box":
			_push_box(float(s[1]))
		"hold_move":
			for i in int(s[2]):
				tick(float(s[1]))
		"lift":
			_lift(float(s[1]), float(s[2]))
		"to_door":
			var d: Rect2i = room.door
			var tx := float(d.position.x) + float(d.size.x) / 2.0
			var n := 0
			while not dead and room.state == "play" and n < 900:
				tick(1.0 if cx() < tx - 1.0 else (-1.0 if cx() > tx + 1.0 else 0.0))
				n += 1
				if absf(cx() - tx) <= 1.5 and room.door_open:
					tick()
			if room.state == "play":
				fail("não entrou na porta (porta aberta: %s)" % str(room.door_open))
		"dbg_mover":
			var m: Dictionary = room.movers[int(s[1])]
			print("  mover %d: r=%s want=%s docked=%s t=%d left=%d rabbit=%s ground=%s" % [s[1], str(m["r"]), str(m["want"]), str(room.mover_docked(m)), room.cycle_t, _dock_left(m), str(room.rabbit.pos), str(grounded())])
		"mark":
			print("  %-22s q %4d  pos %-12s bat %d" % [s[1], frame, str(room.rabbit.pos), room.bat_got])
		_:
			fail("passo desconhecido")


func _dock_left(m: Dictionary) -> int:
	var P: int = m["cycle"]
	if P <= 0:
		return 100000
	return P - ((room.cycle_t + m["phase"]) % P)


## O jato estará fechado entre daqui a `em` e `em + janela` quadros?
func _vent_closed_at(v: Dictionary, em: int, janela: int) -> bool:
	var t: int = (room.cycle_t + em + v["phase"]) % v["period"]
	var open_at: int = v["period"] - v["on"]
	return t + janela < open_at - 20


func _vent_closed_left(v: Dictionary) -> int:
	var t: int = (room.cycle_t + v["phase"]) % v["period"]
	var open_at: int = v["period"] - v["on"]
	return open_at - t if t < open_at else 0


## Empurra a caixa (que está à direita do coelho) até o canto dela chegar a x_alvo.
func _push_box(x_target: float) -> void:
	var n := 0
	while not dead and failed == "" and n < 900:
		var b = room.boxes[0]
		if absf(float(b.pos.x) - x_target) <= 1.0 and b.settled:
			return
		var dirv := 1.0 if float(b.pos.x) < x_target else -1.0
		# anda para o lado em que a caixa precisa ir, empurrando-a
		var behind := float(b.pos.x) - 10.0 if dirv > 0.0 else float(b.pos.x) + Box_SIZE + 10.0
		if absf(cx() - behind) > 3.0 and not _touching_box(b, dirv):
			tick(1.0 if cx() < behind else -1.0)
		else:
			tick(dirv)
		n += 1
	fail("não conseguiu empurrar a caixa até x=%d" % int(x_target))


const Box_SIZE := 16.0


func _touching_box(b, dirv: float) -> bool:
	var r: Rect2i = room.rabbit.rect
	var br: Rect2i = b.rect
	return r.end.y > br.position.y and r.position.y < br.end.y and (r.end.x >= br.position.x - 1 if dirv > 0.0 else r.position.x <= br.end.x + 1)


## Entra na coluna de ar do ventilador e sobe até o centro do coelho passar de y_topo.
func _lift(x: float, y_top: float) -> void:
	var n := 0
	while not dead and failed == "" and absf(cx() - x) > 2.0 and n < 400:
		tick(1.0 if cx() < x else -1.0)
		n += 1
	n = 0
	while not dead and failed == "" and float(room.rabbit.pos.y) + 6.0 > y_top and n < 600:
		tick(clampf((x - cx()) / 6.0, -0.3, 0.3))
		n += 1
	if n >= 600:
		fail("o ar não levou o coelho até y=%d" % int(y_top))

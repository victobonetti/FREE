extends SceneTree
## Robô que joga a fase do Gatsby e grava a rota (tests/fixtures/gatsby-route.json), a prova de
## que a fase tem solução. Rodar depois de mudar a fase (tools/gatsby_level.py):
##
##   godot --headless --path . -s tools/gatsby_robot.gd
##
## O plano está em _plan(), trecho a trecho, com comandos simples (correr até um x, pular,
## esperar, girar). As posições são em px, na orientação em que a sala está naquele momento.

const RoomScript := preload("res://scripts/room.gd")
const Gatsby := preload("res://scripts/boss_gatsby.gd")
const LEVEL := "res://levels/wip/gatsby.json"
const OUT := "res://tests/fixtures/gatsby-route.json"

var room: Node2D
var runs: Array = []
var frame := 0
var dead := false
var min_gap := [1e9, 1e9]
var min_at := [0, 0]
var gatsby_min := 1e9
var marks: Array = []


func _initialize() -> void:
	var def: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEVEL))
	Gatsby.intro_seen = false
	room = RoomScript.new()
	room.setup(def)
	_plan()
	var ok: bool = not dead and (room.state == "won" or room.state == "done")
	print("resultado: %s no quadro %d (%.1f s)" % ["VENCEU" if ok else "NÃO VENCEU (%s)" % room.state, frame, frame / 60.0])
	print("menor folga para a placa: poço %.0f px (quadro %d), corredor %.0f px (quadro %d); menor distância do Gatsby: %.0f px" % [min_gap[0], min_at[0], min_gap[1], min_at[1], gatsby_min])
	if ok and not OS.get_cmdline_user_args().has("--dry"):
		var f := FileAccess.open(OUT, FileAccess.WRITE)
		f.store_string(JSON.stringify({"frames": frame, "note": "rota do robô (tools/gatsby_robot.gd): [quadros, [move, jump_pressed, jump_held, rotate]]", "runs": runs}) + "\n")
		f.close()
		print("rota gravada em ", OUT)
	Gatsby.intro_seen = false
	quit(0 if ok else 1)


# ---------------------------------------------------------------- comandos

func tick(move := 0.0, jp := false, jh := false, rot := 0) -> void:
	if dead:
		return
	var k := [move, 1 if jp else 0, 1 if jh else 0, rot]
	if not runs.is_empty() and runs[-1][1] == k:
		runs[-1][0] += 1
	else:
		runs.append([1, k])
	room.step({"move": move, "jump_pressed": jp, "jump_held": jh, "rotate": rot})
	frame += 1
	if room.state == "dead":
		dead = true
		print("  MORREU no quadro %d em %s (orientação %d)" % [frame, str(room.rabbit.pos), room.orientation])
		return
	for i in room.crushers.size():
		var c: Dictionary = room.crushers[i]
		# só conta enquanto o coelho está na faixa da placa (fora dela, ela não o alcança)
		if c["wait"] == 0 and c["adv"] > 0.0 and i < 2 and room.overlaps(room.rabbit.rect, c["lane"]):
			if room.crusher_gap(c) < min_gap[i]:
				min_gap[i] = room.crusher_gap(c)
				min_at[i] = frame
	gatsby_min = minf(gatsby_min, room.actors[0].min_gap)


func px() -> int:
	return room.rabbit.pos.x


func grounded() -> bool:
	return room.rabbit.on_ground


func won() -> bool:
	return room.state == "won" or room.state == "done"


func wait(n: int) -> void:
	for i in n:
		tick()


func wait_until(cond: Callable, limit := 600) -> void:
	var n := 0
	while not dead and not cond.call() and n < limit:
		tick()
		n += 1
	if n >= limit:
		print("  (esperou o limite de %d quadros)" % limit)


## Corre no sentido `dir` até a borda esquerda do coelho chegar a `x` (ou passar).
func run_to(x: int, limit := 600) -> void:
	var dir := 1.0 if x > px() else -1.0
	var n := 0
	while not dead and ((dir > 0 and px() < x) or (dir < 0 and px() > x)) and n < limit:
		tick(dir)
		n += 1


## Pula no sentido `dir`, segurando o botão por `hold` quadros, e segue até pousar.
func jump(dir: float, hold := 22, air := 120) -> void:
	tick(dir, true, true)
	var n := 1
	while not dead and n < air:
		tick(dir, false, n < hold)
		n += 1
		if grounded():
			break


## Corre até `x` e pula no sentido `dir` (1 direita, -1 esquerda).
func hop(x: int, dir: float, hold := 22) -> void:
	run_to(x)
	jump(dir, hold)


## A primeira peça do canal `ch` (a placa vai destruindo as de baixo, então o índice muda).
func mover_of(ch: int) -> Dictionary:
	for m in room.movers:
		if m["ch"] == ch:
			return m
	return {}


## Passa por baixo do estampador cuja borda esquerda fica em `sx` (px): espera perto dele até
## ele acabar de subir e então corre.
func pass_stamper(sx: int) -> void:
	var m := {}
	for q in room.movers:
		if q["ch"] == 0 and q["off"].position.x == sx:
			m = q
	run_to(sx - 20)
	var up_y := 40
	wait_until(func(): return m["r"].position.y != up_y, 400)
	wait_until(func(): return m["r"].position.y == up_y, 400)
	run_to(sx + 30)


func settle(n := 2) -> void:
	wait(n)


func mark(label: String) -> void:
	var g0: float = room.crusher_gap(room.crushers[0]) if room.crushers.size() > 0 else 0.0
	var g1: float = room.crusher_gap(room.crushers[1]) if room.crushers.size() > 1 else 0.0
	print("%-26s q %4d  pos %-12s chão %-5s orient %d  placa0 %4.0f  placa1 %4.0f" % [label, frame, str(room.rabbit.pos), str(grounded()), room.orientation, g0, g1])


# ---------------------------------------------------------------- o plano

func _plan() -> void:
	wait_until(func(): return not room.input_lock and room.actors[0].si >= 2)
	mark("fim da cena")
	# S0: três patamares
	hop(28, 1); mark("patamar 1")
	hop(92, 1); mark("patamar 2")
	hop(156, 1); mark("patamar 3")
	# S1: chapas soltas, para a esquerda
	hop(192, -1); mark("chapa A")
	hop(144, -1); mark("chapa B")
	hop(96, -1); mark("chapa C")
	hop(60, 1); mark("patamar da catapulta")
	# S2: catapulta 1: pulinho para cima da peça; o Gatsby a dispara
	hop(132, 1, 6); mark("em cima da catapulta")
	run_to(170)
	wait_until(func(): return not grounded() and room.rabbit.vel.y < -200.0, 200)
	mark("arremessado")
	# no ar, vai para a direita e pousa no patamar da pista
	var n := 0
	while not dead and n < 200:
		tick(1.0 if px() < 204 else 0.0)
		n += 1
		if grounded() and room.rabbit.pos.y < 540:
			break
	mark("patamar da pista")
	# S3: pista da direita: gira no sentido horário e corre pela parede até o giro se desfazer
	wall_run(1); mark("fim da pista direita")
	# S3b: travessia para a esquerda, sobre chapas soltas
	hop(232, -1, 10); mark("patamar do meio")
	hop(168, -1); mark("chapa D")
	hop(120, -1); mark("chapa E")
	hop(72, -1, 14); mark("patamar da esquerda")
	run_to(34)
	wait_until(func(): return room.rot_lock == 0, 300)
	wall_run(-1); mark("fim da pista esquerda")
	# S4: o varredor (espinhos que correm pelo patamar): espera ele ir para a direita, sobe,
	# pula por cima quando ele volta
	hop(12, 1, 6); mark("patamar do varredor (embaixo)")
	run_to(60)
	var sw: Dictionary = mover_of(1)
	wait_until(func(): return room.mover_wants_on(sw) and sw["r"].position.x >= 128, 400)
	jump(1.0); mark("patamar do varredor")
	wait_until(func(): return not room.mover_wants_on(sw) and sw["r"].position.x - (px() + 12) <= 22, 400)
	jump(1.0); mark("passou o varredor")
	hop(128, 1); mark("patamar da catapulta 2")
	# S5: catapulta 2, para dentro do corredor
	run_to(190)
	wait_until(func(): return not grounded() and room.rabbit.vel.y < -200.0, 200)
	mark("arremessado 2")
	var n2 := 0
	while not dead and n2 < 240:
		tick(1.0)
		n2 += 1
		if grounded() and px() > 240:
			break
	mark("corredor")
	# C1: ponte de chapas soltas sobre os espinhos, com dois vãos
	hop(412, 1); mark("ponte, 2º trecho")
	hop(484, 1); mark("ponte, 3º trecho")
	# C2: estampadores: passa por baixo de cada um logo depois de ele subir
	for sx in [624, 688, 752]:
		pass_stamper(sx)
	mark("passou os estampadores")
	# C3: a queda: o Gatsby gira a sala; cai rente ao chão antigo até o degrau; ele desgira
	run_to(792)
	wait_until(func(): return room.orientation == 1 and not room.rotating, 300)
	mark("a sala girou")
	wait_until(func(): return room.orientation == 0 and not room.rotating, 600)
	wait_until(func(): return grounded(), 200)
	mark("a sala voltou")
	hop(1054, 1); mark("em cima do degrau")
	# C4: a ponte final e a porta
	var n3 := 0
	while not dead and not won() and n3 < 900:
		tick(1.0)
		n3 += 1
	mark("porta")


## Gira (1 horário: a parede da direita vira chão; -1: a da esquerda) e corre "para cima" até o
## limitador desfazer o giro; depois espera pousar.
func wall_run(dir: int) -> void:
	tick(0.0, false, false, dir)
	var n := 0
	while not dead and n < 400 and (room.orientation != 0 or room.rotating or n < 20):
		tick(float(dir))
		n += 1
	wait_until(func(): return grounded(), 200)

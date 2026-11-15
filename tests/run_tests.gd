extends SceneTree
## Testes headless. Rodar:
##   Godot_console.exe --headless --path . -s tests/run_tests.gd

const Levels := preload("res://scripts/levels.gd")
const RoomScript := preload("res://scripts/room.gd")
const Rabbit := preload("res://scripts/rabbit.gd")

var failures := 0
var room
var frames := 0


func _init() -> void:
	test_format()
	test_jump_height()
	test_no_flicker_at_wall()
	test_push_animation()
	test_sfx_signals()
	test_box_impact_and_sensor()
	test_locked_door_not_solid()
	test_start_is_stable()
	test_room_1()
	test_room_2()
	test_room_3()
	test_room_3_wrong_way()
	test_rot_cooldown()
	test_room_4()
	test_room_5()
	print("")
	if failures == 0:
		print("TODOS OS TESTES PASSARAM")
	else:
		print("FALHAS: %d" % failures)
	quit(1 if failures > 0 else 0)


# ------------------------------------------------------------ utilidades

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		failures += 1


func load_room(i: int) -> void:
	room = RoomScript.new()
	room.setup(Levels.ROOMS[i])
	frames = 0


func tick(inp: Dictionary = {}) -> void:
	room.step(inp)
	frames += 1


func idle(n: int) -> void:
	for i in n:
		tick()


func cx() -> int:
	return room.rabbit.pos.x + 6


func walk_to(x: int, max_frames := 900) -> void:
	for i in max_frames:
		var d := x - cx()
		if absi(d) <= 1:
			return
		tick({"move": signf(d)})


func walk_until(dir: float, cond: Callable, max_frames := 900) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		tick({"move": dir})
	return cond.call()


func jump(dir := 0.0, hold := 40) -> void:
	tick({"jump_pressed": true, "jump_held": true, "move": dir})
	for i in hold:
		tick({"jump_held": true, "move": dir})


func wait_rot_ready() -> void:
	for i in 120:
		if room.rot_lock == 0:
			return
		tick()


func rot(dir: int) -> void:
	wait_rot_ready()
	tick({"rotate": dir})
	for i in 40:
		if not room.rotating:
			break
		tick()
	idle(2)


func wait_ground(max_frames := 240) -> void:
	for i in max_frames:
		if room.rabbit.on_ground and room.rabbit.vel.y == 0.0:
			return
		tick()


# ------------------------------------------------------------ testes

func test_format() -> void:
	print("formato das salas")
	for i in Levels.ROOMS.size():
		var d: Dictionary = Levels.ROOMS[i]
		var rows: Array = d["rows"]
		var ok := rows.size() == 20
		for r in rows:
			ok = ok and r.length() == 20
		check(ok, "sala %d (%s): 20x20" % [i + 1, d["name"]])
		load_room(i)
		check(room.has_door, "sala %d tem porta" % (i + 1))
		check(not room.sockets.is_empty(), "sala %d tem compartimento" % (i + 1))
		check(room.boxes.size() >= room.sockets.size(), "sala %d: caixas >= compartimentos" % (i + 1))


func test_jump_height() -> void:
	print("pulo")
	load_room(0)
	idle(10)
	var y0: int = room.rabbit.pos.y
	var top := y0
	tick({"jump_pressed": true, "jump_held": true})
	for i in 60:
		tick({"jump_held": true})
		top = mini(top, room.rabbit.pos.y)
	var h := y0 - top
	print("  altura máxima do pulo: %d px" % h)
	check(h >= 28 and h <= 34, "pulo longo entre 28 e 34 px")
	# pulo curto
	load_room(0)
	idle(10)
	y0 = room.rabbit.pos.y
	top = y0
	tick({"jump_pressed": true, "jump_held": true})
	for i in 60:
		tick({})
		top = mini(top, room.rabbit.pos.y)
	var hs := y0 - top
	print("  altura do pulo curto: %d px" % hs)
	check(hs >= 6 and hs <= 16, "pulo curto entre 6 e 16 px")


func test_no_flicker_at_wall() -> void:
	print("animação contra a parede")
	load_room(0)
	idle(10)
	for i in 120:
		tick({"move": -1.0})  # anda até encostar na parede esquerda
	var changes := 0
	var last = null
	for i in 90:
		tick({"move": -1.0})
		var tex = room._rabbit_frame()[0]
		if last != null and tex != last:
			changes += 1
		last = tex
	print("  trocas de quadro em 90 quadros contra a parede: %d" % changes)
	# a piscada e a orelha mexendo do coelho parado causam até 4 trocas; o bug dava uma por quadro
	check(changes <= 4 and room.rabbit.run_t == 0, "sem piscar ao andar contra a parede (fica parado)")


func test_push_animation() -> void:
	print("animação de empurrar")
	load_room(0)
	idle(10)
	var seen := {}
	for i in 80:
		tick({"move": 1.0})
		if room.rabbit.push_t > 0:
			seen[room._rabbit_frame()[0]] = true
	check(room.rabbit.push_t > 0 or seen.size() > 0, "o coelho entra no estado de empurrar")
	check(seen.size() >= 2, "empurrar alterna entre dois quadros")


func test_sfx_signals() -> void:
	print("sinais de som")
	load_room(0)
	var got: Array = []
	room.sfx.connect(func(n): got.append(n))
	idle(10)
	jump(0.0, 5)
	check(got.has("jump"), "pular emite o som de pulo")
	load_room(3)
	got.clear()
	room.sfx.connect(func(n): got.append(n))
	idle(5)
	tick({"rotate": 1})
	for i in 120:
		tick()
		if room.state == "dead":
			break
	check(got.has("death"), "morrer emite o som de morte")
	load_room(0)
	got.clear()
	room.sfx.connect(func(n): got.append(n))
	walk_until(1.0, func(): return room.door_open)
	walk_to(104)
	jump(1.0, 30)
	walk_until(1.0, func(): return room.state != "play", 300)
	check(got.has("win") and room.state != "play", "entrar no portal emite o som de vitória")


func test_box_impact_and_sensor() -> void:
	print("impacto da caixa e sensor")
	var got: Array = []
	# sala 2: depois do giro a caixa cai da parede até o chão
	load_room(1)
	var hits: Array = []
	room.impact.connect(func(s): hits.append(s))
	rot(1)
	wait_ground()
	idle(60)
	check(hits.size() >= 1, "caixa que cai depois do giro faz impacto")
	# altura: a mesma caixa, solta de mais alto, bate mais forte
	var low := _drop_strength(1, Vector2i(48, 100))
	var high := _drop_strength(1, Vector2i(48, 8))
	print("  força: baixo %.2f, alto %.2f" % [low[0], high[0]])
	check(high[0] > low[0] + 0.3, "mais altura, mais impacto")
	check(high[1] > low[1], "mais altura, solavanco maior (%.1f > %.1f px)" % [high[1], low[1]])
	# quantidade: duas caixas caindo juntas batem mais forte que uma sozinha
	load_room(4)
	var two: Array = []
	room.impact.connect(func(s): two.append(s))
	room.boxes[0].pos = Vector2i(40, 16)
	room.boxes[1].pos = Vector2i(100, 16)
	idle(150)
	print("  duas caixas: %s" % [two])
	check(two.size() == 2 and two.max() > high[0] * 1.2, "mais caixas, mais impacto")
	var amp_two := _max_jolt_after_drop(4, [Vector2i(40, 16), Vector2i(100, 16)])
	check(amp_two <= 7.0, "solavanco com duas caixas tem teto (%.1f px)" % amp_two)
	check(room.jolt_amp == 0.0, "o solavanco termina")
	# sala 1: a caixa entra no buraco e o sensor liga
	load_room(0)
	got.clear()
	room.sfx.connect(func(n): got.append(n))
	walk_until(1.0, func(): return room.door_open)
	check(got.has("sensor_on"), "caixa no buraco liga o sensor")
	check(room.socket_fx[0] > 0, "o efeito do sensor está ativo")


## Solta a caixa 0 da sala em `pos` e devolve [força do impacto, solavanco máximo em px].
func _drop_strength(room_index: int, pos: Vector2i) -> Array:
	load_room(room_index)
	var s: Array = []
	room.impact.connect(func(v): s.append(v))
	room.boxes[0].pos = pos
	var amp := 0.0
	for i in 200:
		room.step({})
		amp = maxf(amp, room.jolt_amp)
	return [s[0] if s.size() > 0 else 0.0, amp]


func _max_jolt_after_drop(room_index: int, positions: Array) -> float:
	load_room(room_index)
	for i in positions.size():
		room.boxes[i].pos = positions[i]
	var amp := 0.0
	for i in 200:
		room.step({})
		amp = maxf(amp, room.jolt_amp)
	return amp


func test_locked_door_not_solid() -> void:
	print("porta fechada")
	load_room(0)
	room.rabbit.pos = room.door.position + Vector2i(2, 20)
	idle(30)
	check(not room.door_open and room.state == "play", "o coelho fica dentro da porta fechada sem vencer nem morrer")
	check(not room.solid_static(room.door), "a porta fechada não é sólida")
	var b = room.boxes[0]
	b.pos = room.door.position + Vector2i(0, 16)
	idle(30)
	check(room.state == "play", "uma caixa também atravessa a porta fechada")


func test_start_is_stable() -> void:
	print("estado inicial estável (nada se mexe sozinho)")
	for i in Levels.ROOMS.size():
		load_room(i)
		var before: Array = []
		for b in room.boxes:
			before.append(b.pos)
		var rp: Vector2i = room.rabbit.pos
		idle(90)
		var same: bool = room.rabbit.pos == rp or room.rabbit.pos.y - rp.y <= 2
		for k in room.boxes.size():
			same = same and room.boxes[k].pos == before[k]
		check(same and room.state == "play", "sala %d estável" % (i + 1))


func test_room_1() -> void:
	print("sala 1 — Toca")
	load_room(0)
	check(walk_until(1.0, func(): return room.door_open), "empurrando a caixa abre a porta")
	walk_to(104)
	jump(1.0, 30)
	walk_until(1.0, func(): return room.state != "play", 300)
	check(room.state == "won" or room.state == "done", "coelho alcança a porta")


func test_room_2() -> void:
	print("sala 2 — Vertigem")
	load_room(1)
	check(not room.door_open, "porta começa fechada")
	rot(1)
	wait_ground()
	# o coelho cai sobre a protuberância; passa para cima da caixa e desce ao lado esquerdo dela
	walk_until(1.0, func(): return room.rabbit.pos.x >= 26, 200)
	wait_ground()
	walk_until(-1.0, func(): return room.rabbit.pos.x <= 12 and room.rabbit.pos.y > 100, 200)
	wait_ground()
	check(walk_until(1.0, func(): return room.door_open, 1200), "caixa empurrada para o compartimento")
	# o coelho terminou embaixo da plataforma: volta e sobe nela pela esquerda
	walk_to(94)
	jump(1.0, 40)
	walk_until(1.0, func(): return room.state != "play", 400)
	check(room.state == "won" or room.state == "done", "coelho alcança a porta")


func test_room_3() -> void:
	print("sala 3 — Derrame")
	load_room(2)
	check(walk_until(1.0, func(): return room.door_open, 1500), "caixa no compartimento")
	rot(1)
	idle(20)
	check(room.door_open, "giro horário mantém a caixa encaixada")
	rot(1)
	idle(30)
	check(room.door_open, "180° pelo lado seguro mantém a porta aberta")
	walk_until(1.0, func(): return room.rabbit.pos.x >= 60, 300)
	wait_ground()
	walk_until(1.0, func(): return room.state != "play", 600)
	check(room.state == "won" or room.state == "done", "coelho alcança a porta de cabeça para baixo")


func test_rot_cooldown() -> void:
	print("recarga do giro")
	load_room(2)
	idle(5)
	tick({"rotate": 1})
	check(room.rotating, "primeiro giro acontece")
	idle(20)
	check(not room.rotating and room.rot_lock > 0, "depois da animação o giro fica bloqueado")
	var before: int = room.rot_lock
	tick({"rotate": 1})
	idle(3)
	check(not room.rotating and room.rot_lock < before, "apertar durante a recarga não gira")
	check(room.rot_ratio() > 0.0 and room.rot_ratio() < 1.0, "a barra está no meio do caminho")
	wait_rot_ready()
	check(room.rot_ratio() == 1.0, "a barra enche")
	tick({"rotate": 1})
	check(room.rotating, "com a barra cheia o giro volta a funcionar")


func test_room_3_wrong_way() -> void:
	print("sala 3 — sentido errado")
	load_room(2)
	walk_until(1.0, func(): return room.door_open, 1500)
	rot(-1)
	idle(40)
	check(not room.door_open, "giro anti-horário derrama a caixa e fecha a porta")


func test_room_4() -> void:
	print("sala 4 — Espinhos")
	load_room(3)
	# gira do chão: deve morrer nos espinhos
	var dead := false
	rot(1)
	for i in 120:
		tick()
		if room.state == "dead":
			dead = true
			break
	check(dead, "girar do chão atravessa os espinhos e mata")
	# solução: pula, gira no ar para cruzar, volta, pula e gira no outro sentido
	load_room(3)
	idle(5)
	jump(0.0, 8)
	tick({"rotate": 1})
	for i in 40:
		if not room.rotating:
			break
		tick()
	idle(90)
	check(room.state == "play", "cruzou os espinhos pelo ar")
	rot(-1)
	idle(60)
	check(room.door_open, "caixa caiu no buraco e abriu a porta")
	jump(0.0, 8)
	tick({"rotate": -1})
	for i in 40:
		if not room.rotating:
			break
		tick()
	idle(120)
	check(room.state == "won" or room.state == "done", "volta pelo ar até a porta")


func test_room_5() -> void:
	print("sala 5 — Fuga")
	load_room(4)
	# empurra a primeira caixa (à esquerda) para o buraco da esquerda
	check(walk_until(-1.0, func(): return room.socket_filled.size() > 0 and room.socket_filled[0], 600), "caixa da esquerda encaixada")
	walk_to(80)
	idle(5)
	jump(0.0, 8)
	tick({"rotate": 1})
	for i in 40:
		if not room.rotating:
			break
		tick()
	idle(90)
	check(room.state == "play", "cruzou os espinhos pelo ar")
	rot(-1)
	idle(60)
	check(room.door_open, "as duas caixas encaixadas abrem a porta")
	jump(0.0, 8)
	tick({"rotate": -1})
	for i in 40:
		if not room.rotating:
			break
		tick()
	idle(120)
	check(room.state == "won" or room.state == "done", "volta pelo ar até a porta")

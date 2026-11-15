extends SceneTree
## Testes headless. Rodar:
##   Godot_console.exe --headless --path . -s tests/run_tests.gd
##
## Os testes de mecânica usam salas de teste próprias (abaixo), para não quebrarem quando as
## salas do jogo forem redesenhadas. Cada sala do jogo tem um bot que a resolve.

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
	test_nonsquare_rotation()
	test_camera()
	test_gates()
	test_platforms()
	test_rot_cooldown()
	test_start_is_stable()
	test_intro()
	test_passos()
	test_degraus()
	test_comporta()
	test_room_1()
	test_giro()
	test_room_3()
	test_room_3_wrong_way()
	test_setas()
	test_room_2()
	test_room_4()
	test_room_5()
	print("")
	if failures == 0:
		print("TODOS OS TESTES PASSARAM")
	else:
		print("FALHAS: %d" % failures)
	quit(1 if failures > 0 else 0)


# ------------------------------------------------------------ salas de teste

## Sala plana 20x20: coelho, uma caixa, um buraco "S" e a porta num degrau.
const FLAT := {
	"name": "teste plano", "rotate": true, "start_rot": 0,
	"rows": [
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#...............DD.#",
		"#...............DD.#",
		"#...............DD.#",
		"#...............DD.#",
		"#..PP.BB.......#####",
		"#..PP.BB.......#####",
		"##########SS########",
		"##########SS########",
		"####################",
	],
}

## Sala 20x20 com chão grosso e duas caixas, para testes de queda.
const DROP := {
	"name": "teste queda", "rotate": true, "start_rot": 0,
	"rows": [
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#DD................#",
		"#DD................#",
		"#DD..BBPPBB........#",
		"#DD..BBPPBB^^^^^^..#",
		"###SS############SS#",
		"###SS############SS#",
		"####################",
	],
}


# ------------------------------------------------------------ utilidades

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		failures += 1


func load_room(i: int) -> void:
	load_def(Levels.ROOMS[i])


## Carrega a sala pelo nome (os bots não dependem da ordem dos níveis).
func load_named(n: String) -> void:
	for d in Levels.ROOMS:
		if d["name"] == n:
			print("%s — nível %d" % [n, Levels.ROOMS.find(d) + 1])
			load_def(d)
			return
	check(false, "sala '%s' existe" % n)


func load_def(d: Dictionary) -> void:
	room = RoomScript.new()
	room.setup(d)
	frames = 0


func tick(inp: Dictionary = {}) -> void:
	room.step(inp)
	frames += 1


func idle(n: int) -> void:
	for i in n:
		tick()


func cx() -> int:
	return room.rabbit.pos.x + 6


func won() -> bool:
	return room.state == "won" or room.state == "done"


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


## Anda e pula sozinho quando há parede à frente (degraus de até 3 tiles).
func walk_jump_until(dir: float, cond: Callable, max_frames := 1200) -> bool:
	var s := int(signf(dir))
	for i in max_frames:
		if cond.call():
			return true
		var ahead := Rect2i(room.rabbit.pos + Vector2i(s * 2, 0), Vector2i(12, 12))
		if room.rabbit.on_ground and room.solid_static(ahead):
			jump(dir, 30)
		else:
			tick({"move": dir})
	return cond.call()


func jump(dir := 0.0, hold := 40) -> void:
	tick({"jump_pressed": true, "jump_held": true, "move": dir})
	for i in hold:
		tick({"jump_held": true, "move": dir})


## Pula e se dirige no ar até cair perto de `x` (centro do coelho).
func hop_to(x: int, max_frames := 180) -> void:
	tick({"jump_pressed": true, "jump_held": true, "move": signf(x - cx())})
	for i in max_frames:
		var d := x - cx()
		tick({"jump_held": i < 20, "move": 0.0 if absi(d) <= 1 else signf(d)})
		if room.rabbit.on_ground and i > 3:
			return


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


## Pula, espera `rise` quadros e gira no ar.
func air_rot(dir: int, rise := 8) -> void:
	wait_rot_ready()
	jump(0.0, rise)
	tick({"rotate": dir})
	for i in 40:
		if not room.rotating:
			break
		tick()


func wait_ground(max_frames := 240) -> void:
	for i in max_frames:
		if room.rabbit.on_ground and room.rabbit.vel.y == 0.0:
			return
		tick()


func where() -> String:
	var bs: Array = []
	for b in room.boxes:
		bs.append(b.pos)
	return "coelho em %s, estado %s, sala %dx%d, caixas %s, compartimentos %s" % [room.rabbit.pos, room.state, room.gw, room.gh, bs, room.sockets]


# ------------------------------------------------------------ mecânica

func test_format() -> void:
	print("formato das salas")
	for i in Levels.ROOMS.size():
		var d: Dictionary = Levels.ROOMS[i]
		var rows: Array = d["rows"]
		var w: int = rows[0].length()
		var ok := true
		for r in rows.size():
			var line: String = rows[r]
			ok = ok and line.length() == w and line[0] == "#" and line[w - 1] == "#"
			if r == 0 or r == rows.size() - 1:
				ok = ok and line == "#".repeat(w)
		check(ok, "sala %d (%s): %dx%d, retangular e cercada de parede" % [i + 1, d["name"], w, rows.size()])
		load_room(i)
		check(room.has_door, "sala %d tem porta" % (i + 1))
		check(room.group_filled(0) == false and room.socket_group.has(0), "sala %d tem compartimento da porta" % (i + 1))
		check(room.boxes.size() >= room.sockets.size(), "sala %d: caixas >= compartimentos" % (i + 1))
		for g in room.gates:
			check(room.socket_group.has(g["id"]), "sala %d: a comporta %d tem compartimento" % [i + 1, g["id"]])


func test_jump_height() -> void:
	print("pulo")
	load_def(FLAT)
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
	load_def(FLAT)
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
	load_def(FLAT)
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
	load_def(FLAT)
	idle(10)
	var seen := {}
	for i in 80:
		tick({"move": 1.0})
		if room.rabbit.push_t > 0:
			seen[room._rabbit_frame()[0]] = true
	check(seen.size() > 0, "o coelho entra no estado de empurrar")
	check(seen.size() >= 2, "empurrar alterna entre dois quadros")


func test_sfx_signals() -> void:
	print("sinais de som")
	load_def(FLAT)
	var got: Array = []
	room.sfx.connect(func(n): got.append(n))
	idle(10)
	jump(0.0, 5)
	check(got.has("jump"), "pular emite o som de pulo")
	load_def(DROP)
	got.clear()
	room.sfx.connect(func(n): got.append(n))
	idle(5)
	walk_until(1.0, func(): return room.state == "dead", 200)
	check(got.has("death"), "morrer emite o som de morte")
	load_def(FLAT)
	got.clear()
	room.sfx.connect(func(n): got.append(n))
	walk_until(1.0, func(): return room.door_open)
	walk_to(104)
	jump(1.0, 30)
	walk_until(1.0, func(): return room.state != "play", 300)
	check(got.has("win") and room.state != "play", "entrar no portal emite o som de vitória")


func test_box_impact_and_sensor() -> void:
	print("impacto da caixa e sensor")
	var low := _drop_strength([Vector2i(120, 100)])
	var high := _drop_strength([Vector2i(120, 8)])
	print("  força: baixo %.2f, alto %.2f" % [low[0][0], high[0][0]])
	check(low[0].size() >= 1, "caixa que cai faz impacto")
	check(high[0][0] > low[0][0] + 0.3, "mais altura, mais impacto")
	check(high[1] > low[1], "mais altura, solavanco maior (%.1f > %.1f px)" % [high[1], low[1]])
	var two := _drop_strength([Vector2i(40, 16), Vector2i(100, 16)])
	print("  duas caixas: %s" % [two[0]])
	check(two[0].size() == 2 and two[0].max() > high[0][0] * 1.2, "mais caixas, mais impacto")
	check(two[1] <= 7.0, "solavanco com duas caixas tem teto (%.1f px)" % two[1])
	check(room.jolt_amp == 0.0, "o solavanco termina")
	load_def(FLAT)
	var got: Array = []
	room.sfx.connect(func(n): got.append(n))
	walk_until(1.0, func(): return room.door_open)
	check(got.has("sensor_on"), "caixa no buraco liga o sensor")
	check(room.socket_fx[0] > 0, "o efeito do sensor está ativo")


## Solta caixas da sala DROP nas posições dadas: devolve [forças dos impactos, solavanco máximo].
func _drop_strength(positions: Array) -> Array:
	load_def(DROP)
	var s: Array = []
	room.impact.connect(func(v): s.append(v))
	for i in positions.size():
		room.boxes[i].pos = positions[i]
	var amp := 0.0
	for i in 200:
		room.step({})
		amp = maxf(amp, room.jolt_amp)
	return [s, amp]


func test_locked_door_not_solid() -> void:
	print("porta fechada")
	load_def(FLAT)
	room.rabbit.pos = room.door.position + Vector2i(2, 20)
	idle(30)
	check(not room.door_open and room.state == "play", "o coelho fica dentro da porta fechada sem vencer nem morrer")
	check(not room.solid_static(room.door), "a porta fechada não é sólida")
	var b = room.boxes[0]
	b.pos = room.door.position + Vector2i(0, 16)
	idle(30)
	check(room.state == "play", "uma caixa também atravessa a porta fechada")


func _snapshot() -> Dictionary:
	var bp: Array = []
	for b in room.boxes:
		bp.append(b.pos)
	var pl: Array = []
	for p in room.platforms:
		pl.append([p["rect"], p["facing"]])
	var gr: Array = []
	for g in room.gates:
		gr.append(g["rects"].duplicate())
	var sp: Array = []
	for s in room.spikes:
		sp.append([s["rect"], s["facing"]])
	return {"tiles": room.tiles.duplicate(), "w": room.gw, "h": room.gh, "boxes": bp,
		"rabbit": room.rabbit.pos, "plat": pl, "gates": gr, "spikes": sp,
		"sockets": room.sockets.duplicate(), "door": room.door}


const WIDE := {
	"name": "teste largo", "rotate": true, "start_rot": 0,
	"rows": [
		"##############################",
		"#............................#",
		"#.......{......2.............#",
		"#.......=......2......DD.....#",
		"#..............2......DD.....#",
		"#....BB........2......DD.....#",
		"#....BB........2......DD..v..#",
		"#PP........................bb#",
		"#PP..........^^^^..........bb#",
		"##############################",
	],
}


func test_nonsquare_rotation() -> void:
	print("rotação de sala não quadrada")
	load_def(WIDE)
	var s0 := _snapshot()
	room._rotate_logic(1)
	check(room.gw == s0["h"] and room.gh == s0["w"], "um giro troca largura e altura (%dx%d)" % [room.gw, room.gh])
	room._rotate_logic(1)
	room._rotate_logic(1)
	room._rotate_logic(1)
	check(_snapshot() == s0, "quatro giros horários voltam ao estado inicial")
	room._rotate_logic(-1)
	room._rotate_logic(1)
	check(_snapshot() == s0, "anti-horário seguido de horário volta ao estado inicial")


func test_camera() -> void:
	print("câmera")
	var rows: Array = []
	for r in 30:
		var line := ""
		for c in 60:
			line += "#" if (r == 0 or r == 29 or c == 0 or c == 59) else "."
		rows.append(line)
	rows[27] = "#PP" + rows[27].substr(3)
	rows[28] = "#PP" + rows[28].substr(3)
	load_def({"name": "câmera", "rotate": true, "start_rot": 0, "rows": rows})
	var ok := true
	var followed := false
	for i in 400:
		tick({"move": 1.0})
		var c: Vector2 = room.cam
		ok = ok and c.x >= 160.0 - 0.01 and c.x <= 480.0 - 160.0 + 0.01 and c.y >= 90.0 - 0.01 and c.y <= 240.0 - 90.0 + 0.01
		if i == 150:
			followed = absf(c.x - (room.rabbit.pos.x + 6)) < 24.0
	check(ok, "a câmera não mostra além das bordas de uma sala 60x30")
	check(followed, "no meio da sala, a câmera acompanha o coelho na horizontal")
	check(absf(room.cam.x - 320.0) < 1.0, "no fim da sala, a câmera para na borda")
	rot(1)
	idle(120)
	var c2: Vector2 = room.cam
	check(c2.x >= 90.0 - 0.01 and c2.x <= 240.0 - 90.0 + 0.01, "depois de girar, a câmera respeita as novas bordas")
	load_def(FLAT)
	check(room.cam == Vector2(80, 80), "sala que cabe na tela fica centralizada")


const GATE_ROOM := {
	"name": "teste comporta", "rotate": false, "start_rot": 0,
	"rows": [
		"####################",
		"#.....BB.......1...#",
		"#.....BB.......1...#",
		"#..............1...#",
		"#PP............1...#",
		"#PP............1...#",
		"######aa############",
		"######aa############",
		"####################",
	],
}


func test_gates() -> void:
	print("comportas")
	load_def(GATE_ROOM)
	var g: Dictionary = room.gates[0]
	check(g["closed"] and room.solid_static(Rect2i(120, 8, 8, 8)), "a comporta começa fechada e sólida")
	var got: Array = []
	room.sfx.connect(func(n): got.append(n))
	idle(80)
	check(not g["closed"], "a caixa no compartimento 'a' abre a comporta 1")
	check(got.has("gate_open"), "abrir a comporta emite som")
	check(walk_until(1.0, func(): return room.rabbit.pos.x > 130, 400), "o coelho passa pela comporta aberta")
	# coelho parado dentro da comporta; a caixa sai do compartimento
	room.rabbit.pos = Vector2i(118, 28)
	room.boxes[0].pos = Vector2i(24, 8)
	idle(60)
	check(not g["closed"], "com o coelho dentro, a comporta não fecha (não esmaga)")
	room.rabbit.pos = Vector2i(140, 28)
	idle(5)
	check(g["closed"], "com o caminho livre, a comporta fecha")
	check(got.has("gate_close"), "fechar a comporta emite som")


const PLATFORM_ROOM := {
	"name": "teste plataforma", "rotate": true, "start_rot": 0,
	"rows": [
		"####################",
		"#..................#",
		"#..................#",
		"#........BB........#",
		"#........BB........#",
		"#........==........#",
		"#..................#",
		"#..................#",
		"#.......{..........#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#PP................#",
		"#PP................#",
		"####################",
	],
}


func test_platforms() -> void:
	print("plataformas por orientação")
	load_def(PLATFORM_ROOM)
	idle(30)
	var top: Dictionary = room.platforms[0]
	check(top["solid"], "com a seta para cima a plataforma é sólida")
	var by: int = room.boxes[0].pos.y
	idle(30)
	check(room.boxes[0].pos.y == by, "a caixa fica em cima dela")
	room._rotate_logic(1)
	room._update_mechanisms(false)
	check(not top["solid"], "girada, a seta sai de cima e ela deixa de ser sólida")
	load_def(PLATFORM_ROOM)
	var left: Dictionary = room.platforms[2]
	check(left["facing"] == 3 and not left["solid"], "seta para a esquerda: não sólida")
	room._rotate_logic(1)
	room.rabbit.pos = left["rect"].position - Vector2i(2, 2)  # coelho dentro do tile
	room._update_mechanisms(false)
	check(left["facing"] == 0 and not left["solid"], "com o coelho dentro, não fica sólida (não esmaga)")
	room.rabbit.pos = Vector2i(16, 16)
	room._update_mechanisms(false)
	check(left["solid"], "com o tile livre, fica sólida")


func test_rot_cooldown() -> void:
	print("recarga do giro")
	load_def(FLAT)
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
		var after: Array = []
		for b in room.boxes:
			after.append(b.pos)
		# a simulação reordena as caixas (de baixo para cima): compara sem depender da ordem
		var key := func(v: Vector2i): return v.y * 10000 + v.x
		before.sort_custom(func(a, b): return key.call(a) < key.call(b))
		after.sort_custom(func(a, b): return key.call(a) < key.call(b))
		same = same and before == after
		check(same and room.state == "play", "sala %d estável (coelho %s -> %s, caixas %s -> %s)" % [i + 1, rp, room.rabbit.pos, before, after])


# ------------------------------------------------------------ abertura

func test_intro() -> void:
	print("abertura")
	var IntroScript = load("res://scripts/intro.gd")
	var intro = IntroScript.new()
	intro._ready()
	var ev: Array = []
	var hits: Array = []
	intro.started.connect(func(): ev.append("started"))
	intro.finished.connect(func(): ev.append("finished"))
	intro.sfx.connect(func(n): ev.append(n))
	intro.impact.connect(func(s): hits.append(s))
	for i in 200:
		intro.step(false)
	check(intro.phase == intro.TITLE and ev.is_empty(), "sem apertar nada, fica na tela de título")
	intro.step(true)
	check(ev.has("started") and intro.phase == intro.SURPRISE, "Enter começa a cutscene")
	var count := 0
	while not ev.has("finished") and count < 2000:
		intro.step(false)
		count += 1
	print("  duração da cutscene: %.1f s" % (count / 60.0))
	check(ev.has("finished"), "a cutscene chega ao fim sozinha")
	check(count > 400 and count < 900, "dura entre 7 e 15 segundos")
	check(hits.size() >= 2 and ev.has("jump") and ev.has("sensor_on"), "tem efeitos sonoros (buraco, susto, pouso, porta)")
	intro.free()
	# pular
	intro = IntroScript.new()
	intro._ready()
	ev.clear()
	intro.finished.connect(func(): ev.append("finished"))
	for i in 30:
		intro.step(false)
	intro.step(true)
	for i in 40:
		intro.step(false)
	intro.step(true)
	check(ev.has("finished"), "Enter de novo pula a cutscene")
	intro.free()
	# a sala de início bate com o quadrado da cutscene
	load_def(Levels.START)
	check(room.door_open, "na sala de início a porta já está aberta")
	var origin := Vector2(160, 90) - Vector2(room.pw, room.ph) / 2.0
	check(origin == IntroScript.SQ_OUT.position and Vector2(room.pw, room.ph) == IntroScript.SQ_OUT.size, "a sala de início ocupa o mesmo quadrado da cutscene")
	check(Rect2(Vector2(room.door.position) + origin, room.door.size) == IntroScript.DOOR_RECT, "a porta está no mesmo lugar")
	idle(20)
	check(absf(room.rabbit.pos.x + 6 + origin.x - 160.0) <= 1.0 and room.rabbit.pos.y + 12 + origin.y == IntroScript.FLOOR_Y, "o coelho começa onde pousou")
	walk_until(1.0, won, 300)
	check(won(), "andar até a porta começa o jogo")


# ------------------------------------------------------------ bots das salas

func test_passos() -> void:
	load_named("Primeiros passos")
	check(walk_until(1.0, func(): return room.door_open, 600), "empurrar a caixa no buraco abre a porta")
	walk_until(1.0, won, 300)
	check(won(), "coelho alcança a porta (%s)" % where())


func test_degraus() -> void:
	load_named("Degraus")
	check(walk_jump_until(1.0, func(): return room.door_open, 1500), "sobe os degraus, passa o vão e põe a caixa no buraco (%s)" % where())
	walk_until(1.0, won, 300)
	check(won(), "coelho alcança a porta (%s)" % where())


func test_comporta() -> void:
	load_named("Comporta")
	check(walk_until(1.0, func(): return room.group_filled(1), 900), "caixa no buraco abre a comporta")
	walk_to(116)
	hop_to(160)
	check(room.state == "play", "pula os espinhos (%s)" % where())
	check(walk_until(1.0, func(): return room.door_open, 600), "segunda caixa abre a porta")
	walk_until(1.0, won, 300)
	check(won(), "coelho alcança a porta (%s)" % where())


func test_giro() -> void:
	load_named("Giro")
	check(walk_until(1.0, func(): return room.door_open, 600), "caixa no buraco abre a porta")
	walk_until(1.0, won, 200)
	check(not won(), "sem girar, a porta na parede fica fora de alcance")
	rot(1)
	wait_ground()
	walk_until(1.0, won, 400)
	check(won(), "girando, a parede vira chão e a porta fica ao alcance (%s)" % where())


func test_setas() -> void:
	load_named("Setas")
	var top: Dictionary = room.platforms[0]
	check(not top["solid"], "as setas começam apontando para baixo: não sólidas")
	check(walk_until(1.0, func(): return room.door_open, 1500), "caixa no nicho abre a porta")
	rot(1)
	idle(30)
	rot(1)
	idle(60)
	check(room.door_open and top["solid"], "virada, a caixa fica e as setas viram ponte")
	walk_until(1.0, func(): return not room.rabbit.on_ground, 300)
	wait_ground()
	if room.rabbit.pos.y > 100:
		hop_to(80)
	walk_until(1.0, won, 600)
	check(won(), "atravessa a ponte sobre os espinhos até a porta (%s)" % where())


func test_room_1() -> void:
	load_named("Toca")
	check(walk_jump_until(1.0, func(): return room.group_filled(1)), "pula o bloco e põe a caixa no buraco: comporta abre")
	walk_to(178)
	hop_to(208)
	check(room.state == "play" and room.rabbit.pos.y < 70, "primeiro pilar (%s)" % where())
	hop_to(240)
	check(room.state == "play" and room.rabbit.pos.y < 70, "segundo pilar (%s)" % where())
	hop_to(278)
	check(room.state == "play", "passa os espinhos (%s)" % where())
	check(walk_until(1.0, func(): return room.door_open), "segunda caixa no buraco abre a porta")
	walk_until(1.0, won, 300)
	check(won(), "coelho alcança a porta (%s)" % where())


func test_room_2() -> void:
	load_named("Vertigem")
	check(room.gh > room.gw, "começa alta (%dx%d)" % [room.gw, room.gh])
	rot(1)
	wait_ground()
	# etapa 1 (o esboço): passa por cima da caixa, desce do lado esquerdo e a empurra até o nicho
	walk_until(1.0, func(): return room.rabbit.pos.x >= 26, 200)
	wait_ground()
	walk_until(-1.0, func(): return room.rabbit.pos.x <= 12 and room.rabbit.pos.y > 100, 200)
	wait_ground()
	check(walk_until(1.0, func(): return room.group_filled(1), 1200), "caixa no nicho abre a comporta")
	walk_to(94)
	jump(1.0, 40)
	# etapa 2: atravessa a comporta empurrando a segunda caixa para o poço
	var b2 = null
	for b in room.boxes:
		if b.pos.x >= 160:
			b2 = b
	var by: int = b2.pos.y
	check(walk_until(1.0, func(): return b2.pos.y > by + 4, 600), "segunda caixa cai no poço")
	check(room.state == "play", "coelho continua na borda (%s)" % where())
	idle(40)  # espera a caixa chegar ao fundo do poço antes de girar
	rot(1)
	wait_ground()
	idle(40)
	check(room.door_open, "girada, a caixa escorrega até o compartimento e abre a porta (%s)" % where())
	check(room.state == "play", "coelho pousou fora dos espinhos (%s)" % where())
	walk_to(44)
	hop_to(76)
	check(room.state == "play" and room.rabbit.pos.y < 272, "sobe na ponte que só existe girada (%s)" % where())
	walk_to(100)
	hop_to(116)
	walk_until(1.0, won, 400)
	check(won(), "coelho alcança a porta (%s)" % where())


func test_room_3() -> void:
	load_named("Derrame")
	check(walk_until(1.0, func(): return room.group_filled(1), 1500), "caixa no nicho abre a comporta")
	walk_to(76)
	jump(1.0, 40)
	check(walk_until(1.0, func(): return cx() >= 168, 400), "sobe no teto do nicho e atravessa a comporta (%s)" % where())
	wait_ground()
	check(walk_until(1.0, func(): return room.door_open, 1500), "segunda caixa no nicho abre a porta (%s)" % where())
	rot(1)
	idle(30)
	check(room.door_open and room.group_filled(1), "giro horário mantém as duas caixas encaixadas")
	rot(1)
	idle(40)
	check(room.door_open and room.group_filled(1), "180° pelo lado seguro mantém tudo aberto")
	walk_until(1.0, func(): return room.rabbit.pos.x >= 60, 300)
	wait_ground()
	walk_until(1.0, won, 600)
	check(won(), "coelho alcança a porta de cabeça para baixo (%s)" % where())


func test_room_3_wrong_way() -> void:
	load_named("Derrame")
	print("  (sentido errado)")
	walk_until(1.0, func(): return room.group_filled(1), 1500)
	rot(-1)
	idle(40)
	check(not room.group_filled(1), "giro anti-horário derrama a caixa")
	check(room.gates[0]["closed"] or room.state != "play", "e a comporta volta a fechar")


func test_room_4() -> void:
	load_named("Espinhos")
	var dead := false
	rot(1)
	for i in 160:
		tick()
		if room.state == "dead":
			dead = true
			break
	check(dead, "girar do chão atravessa os espinhos e mata")
	load_named("Espinhos")
	idle(5)
	air_rot(1)
	idle(120)
	check(room.state == "play", "cruzou os espinhos pelo ar e pousou na plataforma (%s)" % where())
	rot(-1)
	idle(60)
	check(room.door_open, "caixa caiu no buraco e abriu a porta")
	check(room.state == "play", "desceu sem tocar nos espinhos da parede (%s)" % where())
	air_rot(-1)
	idle(160)
	check(won(), "volta pelo ar até a porta (%s)" % where())


func test_room_5() -> void:
	load_named("Fuga")
	idle(5)
	# etapa de baixo: travessia pelo ar, a caixa vai para o buraco "a"
	air_rot(1)
	idle(160)
	check(room.state == "play", "cruzou os espinhos pelo ar (%s)" % where())
	rot(-1)
	idle(60)
	check(room.group_filled(1), "caixa no buraco abre a comporta do teto (%s)" % where())
	air_rot(-1)
	idle(160)
	check(room.state == "play", "voltou pelo ar (%s)" % where())
	rot(1)
	wait_ground()
	idle(20)
	# escadaria de plataformas até a comporta
	if cx() > 30:
		walk_to(36)
		hop_to(16)
	for x in [40, 64, 40, 16]:
		hop_to(x)
	check(room.state == "play" and room.rabbit.pos.y <= 140, "subiu a escadaria (%s)" % where())
	jump(0.0, 14)
	for i in 40:
		tick({"move": 1.0, "jump_held": i < 6})
	wait_ground()
	check(room.rabbit.pos.y < 128, "passou pela comporta para a etapa de cima (%s)" % where())
	walk_until(1.0, func(): return room.rabbit.pos.x >= 88, 300)
	idle(10)
	# vira a sala de cabeça para baixo pelo sentido horário
	rot(1)
	idle(40)
	rot(1)
	idle(80)
	check(room.door_open, "virada, a segunda caixa cai no compartimento do teto (%s)" % where())
	check(room.state == "play", "coelho pousou no teto fora dos espinhos (%s)" % where())
	walk_jump_until(-1.0, func(): return cx() < 112, 300)
	wait_ground()
	check(room.state == "play", "desceu do compartimento sem tocar nos espinhos (%s)" % where())
	hop_to(56)
	walk_until(-1.0, won, 300)
	check(won(), "coelho alcança a porta (%s)" % where())

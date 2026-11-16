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
	test_limiter()
	test_reload_params()
	test_rope()
	test_water()
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
	test_prumo()
	test_agua()
	test_mare()
	test_inverse_gate()
	test_represa()
	test_naufragio()
	test_mergulho()
	test_spin_block()
	test_jeffrey_no_suicide()
	test_jeffrey_bot()
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
	for i in 400:
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


## Roda até `n` quadros; devolve true se o coelho morreu nesse tempo.
func dies_within(n: int, inp: Dictionary = {}) -> bool:
	for i in n:
		tick(inp)
		if room.state == "dead":
			return true
	return false


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
		if d.has("actors"):
			pass   # sala de boss: quem abre a porta é o boss derrotado
		elif d.get("door_open", false):
			check(not room.socket_group.has(0), "sala %d: porta sem compartimento (door_open)" % (i + 1))
		else:
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
	room.pan(Vector2(-50, -50))
	idle(1)
	check(room.cam == Vector2(80, 80), "arrastar a vista não mexe numa sala que cabe na tela")
	room.end_pan()
	# arrastar a vista (celular) numa sala maior que a tela
	load_def({"name": "câmera", "rotate": true, "start_rot": 0, "rows": rows})
	idle(5)
	var c0: Vector2 = room.cam
	room.pan(Vector2(-100, 0))
	idle(1)
	check(absf(room.cam.x - (c0.x + 100.0)) < 1.0, "arrastar o dedo para a esquerda mostra o que está à direita, sem atraso")
	room.pan(Vector2(-5000, -5000))
	idle(1)
	check(absf(room.cam.x - 320.0) < 0.01 and absf(room.cam.y - 150.0) < 0.01, "a vista arrastada para nas bordas da sala")
	room.end_pan()
	idle(90)
	check(room.cam.distance_to(c0) < 2.0, "ao soltar, a câmera volta para o coelho")
	room.pan(Vector2(-60, 0))
	room.end_pan()
	rot(1)
	check(room.look == Vector2.ZERO, "girar a sala zera a vista arrastada")


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


func test_limiter() -> void:
	print("limitador")
	var d: Dictionary = FLAT.duplicate()
	d["limiter"] = true
	load_def(d)
	var got: Array = []
	room.sfx.connect(func(n): got.append(n))
	idle(10)
	check(room.limit_t == 0 and room.limiter_ratio() == 0.0, "sem giro, o limitador está parado")
	tick({"rotate": 1})
	check(room.limit_t > 0 and room.orientation == 1, "girar liga o limitador")
	idle(60)
	check(room.orientation == 1 and room.limiter_ratio() > 0.3 and room.limiter_ratio() < 0.7, "a barra desce com o tempo (%.2f)" % room.limiter_ratio())
	tick({"rotate": -1})
	check(room.orientation == 1, "durante a recarga não dá para desfazer à mão")
	idle(100)
	check(room.orientation == 0 and got.has("limiter"), "ao fim dos 2,5 s o giro é desfeito, com som")
	check(room.limit_t == 0 and room.rot_lock > 100, "desfeito, a recarga recomeça e o limitador para")
	load_def(FLAT)
	tick({"rotate": 1})
	idle(300)
	check(room.orientation == 1, "sem o campo limiter, o giro fica")


func test_reload_params() -> void:
	print("recarga e limitador parametrizados")
	load_def(FLAT)
	tick({"rotate": 1})
	check(room.rot_lock == 150 and room.reload_frames == 150 and room.limiter_frames == 150, "sem campos, valem 2,5 s (150 quadros)")
	var d: Dictionary = FLAT.duplicate()
	d["reload_time"] = 1.0
	d["limiter"] = true
	d["limiter_time"] = 0.5
	load_def(d)
	check(room.reload_frames == 60 and room.limiter_frames == 30, "reload_time e limiter_time viram quadros")
	tick({"rotate": 1})
	check(room.rot_lock == 60 and room.limit_t == 30 and room.orientation == 1, "o giro dura 1 s de recarga e 0,5 s de limitador")
	idle(15)
	check(absf(room.rot_ratio() - 0.25) < 0.05 and absf(room.limiter_ratio() - 0.5) < 0.05, "as barras usam o tempo de cada um")
	idle(20)
	check(room.orientation == 0 and room.rot_lock > 0 and room.rot_lock <= 60, "o limitador desfaz aos 0,5 s e a recarga recomeça de 1 s")
	d["reload_time"] = 0.1
	d["limiter_time"] = 100.0
	load_def(d)
	check(room.reload_frames == room.ROT_FRAMES + 1 and room.limiter_frames == 1800, "os valores extremos são limitados")
	d["reload_time"] = 4.0
	d["limiter_time"] = 2.0
	load_def(d)
	tick({"rotate": 1})
	idle(125)
	check(room.orientation == 0 and room.rot_lock > 100, "limitador menor que a recarga: desfaz e a recarga cheia recomeça")


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


# ------------------------------------------------------------ corda

## Sala 20x20 com uma corda de 14 tiles pendendo do teto (a ponta fica 20 px acima da cabeça).
const ROPE_ROOM := {
	"name": "teste corda", "rotate": true, "start_rot": 0, "door_open": true,
	"rows": [
		"####################",
		"#........|.........#",
		"#........|.........#",
		"#........|.........#",
		"#........|.........#",
		"#........|.........#",
		"#........|.........#",
		"#........|.........#",
		"#........|.........#",
		"#........|.........#",
		"#........|.........#",
		"#........|.........#",
		"#........|.........#",
		"#........|.........#",
		"#........|.........#",
		"#..................#",
		"#..................#",
		"#.PP...............#",
		"#.PP...............#",
		"####################",
	],
}


func test_rope() -> void:
	print("corda")
	load_def(ROPE_ROOM)
	var got: Array = []
	room.sfx.connect(func(n): got.append(n))
	var rp: Dictionary = room.ropes[0]
	check(room.ropes.size() == 1 and rp["len"] == 112 and rp["facing"] == 2 and rp["anchor"] == Vector2(76, 8), "a corda é lida da sala: âncora no teto, 112 px")
	var a0: Vector2 = rp["anchor"]
	for i in 4:
		room._rotate_logic(1)
	check(rp["anchor"] == a0 and rp["facing"] == 2, "quatro giros devolvem a corda ao lugar")
	idle(10)
	walk_to(76)
	idle(10)
	check(room.rabbit.rope == null, "andar pela corda no chão não agarra")
	jump(0.0, 25)
	check(room.rabbit.rope == rp and got.has("rope"), "pular na corda agarra (%s)" % where())
	check(room.rabbit.air_rot, "agarrar a corda recarrega o giro do ar")
	idle(120)
	var p0: Vector2i = room.rabbit.pos
	idle(60)
	var dp: Vector2i = room.rabbit.pos - p0
	check(room.rabbit.rope == rp and absi(dp.x) <= 1 and absi(dp.y) <= 1, "pendurado, fica parado (%s -> %s)" % [p0, room.rabbit.pos])
	# girar pendurado é livre e dá movimento
	room.rabbit.air_rot = false
	wait_rot_ready()
	tick({"rotate": 1})
	check(room.rotating and room.rabbit.rope == rp, "pendurado, o giro é livre e o coelho continua na corda")
	var top_speed := 0.0
	var travelled := 0
	var p1: Vector2i = room.rabbit.pos
	for i in 80:
		tick()
		top_speed = maxf(top_speed, room.rabbit.vel.length())
		travelled = maxi(travelled, absi(room.rabbit.pos.x - p1.x) + absi(room.rabbit.pos.y - p1.y))
		if room.rabbit.rope == null:
			break
	print("  velocidade máxima no arco: %.0f px/s" % top_speed)
	check(top_speed > 150.0 and travelled > 40, "depois do giro o pêndulo acelera o coelho (%.0f px/s)" % top_speed)
	check(room.rabbit.rope == null, "bater na parede solta a corda")
	# só dá para descer
	load_def(ROPE_ROOM)
	idle(10)
	walk_to(76)
	idle(15)
	jump(0.0, 25)
	room.rabbit.rope_r = 50.0  # como se tivesse agarrado no meio da corda
	idle(40)
	var y_hang: int = room.rabbit.pos.y
	for i in 60:
		tick({"climb": -1.0})
	check(room.rabbit.rope != null and absi(room.rabbit.pos.y - y_hang) <= 1, "não dá para subir pela corda")
	for i in 60:
		tick({"climb": 1.0})
	var y_down: int = room.rabbit.pos.y
	check(room.rabbit.rope != null and y_down - y_hang > 30, "desce pela corda (%d px em 1 s)" % (y_down - y_hang))
	for i in 600:
		tick({"climb": 1.0})
	check(room.rabbit.rope != null and absf(room.rabbit.rope_r - 112.0) < 0.5, "desce até a ponta e para")
	# agarrar durante o giro: quem pulou e girou no ar continua podendo agarrar
	load_def(ROPE_ROOM)
	idle(10)
	air_rot(1, 6)
	check(room.rabbit.jumping and not room.rabbit.on_ground, "pulou e girou no ar: ainda pode agarrar a corda")
	load_def(ROPE_ROOM)
	idle(10)
	rot(1)
	check(not room.rabbit.jumping, "girou do chão: caindo, passa pela corda")
	# pulo com giro no ar que põe a corda no teto: agarra em pleno voo
	load_def(ROPE_ROOM)
	idle(10)
	rot(-1)
	wait_ground()
	wait_rope(room.ropes[0])
	var caught := false
	for x in range(20, 140, 6):
		load_def(ROPE_ROOM)
		idle(10)
		rot(-1)
		wait_ground()
		wait_rope(room.ropes[0])
		room.rabbit.pos = Vector2i(x, room.ph - 8 - 12)
		idle(5)
		air_rot(1, 10)
		for i in 120:
			tick()
			if room.rabbit.rope != null:
				caught = true
				break
		if caught:
			break
	check(caught, "pular, girar no ar e agarrar a corda que o giro pôs no teto (%s)" % where())
	# a corda tem física: depois do giro ela cai e balança, não muda de lugar de uma vez
	load_def(ROPE_ROOM)
	idle(10)
	rot(1)
	var tip0: Vector2 = room.ropes[0]["pts"][room.ropes[0]["pts"].size() - 1]
	idle(10)
	var tip1: Vector2 = room.ropes[0]["pts"][room.ropes[0]["pts"].size() - 1]
	wait_rope(room.ropes[0])
	var tip2: Vector2 = room.ropes[0]["pts"][room.ropes[0]["pts"].size() - 1]
	check(tip0.distance_to(tip1) > 1.0 and tip0.distance_to(tip1) < 40.0 and tip1.distance_to(tip2) > 20.0, "depois do giro a corda cai aos poucos até repousar")
	var ok_len := true
	var pts2: PackedVector2Array = room.ropes[0]["pts"]
	for i in pts2.size() - 1:
		ok_len = ok_len and pts2[i].distance_to(pts2[i + 1]) < 6.0
	check(ok_len and not room._pt_solid(tip2), "a corda não estica nem entra na parede")
	# soltar com o pulo
	load_def(ROPE_ROOM)
	idle(10)
	walk_to(76)
	idle(15)
	jump(0.0, 25)
	idle(30)
	tick({"jump_pressed": true, "jump_held": true})
	check(room.rabbit.rope == null and room.rabbit.vel.y < 0.0, "pulo solta a corda, com um pequeno impulso")
	for i in 40:
		tick()
	check(room.rabbit.rope == null, "não agarra a mesma corda de novo antes de pousar")
	# caindo (sem ter pulado), passa pela corda
	load_def(ROPE_ROOM)
	idle(10)
	room.rabbit.pos = Vector2i(70, 20)
	idle(60)
	check(room.rabbit.rope == null and room.rabbit.on_ground, "caindo sem ter pulado, passa pela corda")
	# corda fora do teto: frouxa, não dá para agarrar
	load_def(ROPE_ROOM)
	idle(10)
	rot(1)
	wait_ground()
	check(room.ropes[0]["facing"] == 3 and room.rope_at(Rect2i(0, 0, room.pw, room.ph)) == null, "com a âncora na parede, a corda fica frouxa e não agarra")


# ------------------------------------------------------------ água

## Sala 20x20: 6 tiles de água no fundo, o coelho e uma caixa lá no alto.
const WATER_ROOM := {
	"name": "teste água", "rotate": true, "start_rot": 0, "door_open": true,
	"rows": [
		"####################",
		"#.PP...........BB..#",
		"#.PP...........BB..#",
		"#####..........###.#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#~~~~~~~~~~~~~~~~~~#",
		"#~~~~~~~~~~~~~~~~~~#",
		"#~~~~~~~~~~~~~~~~~~#",
		"#~~~~~~~~~~~~~~~~~~#",
		"#~~~~~~~~~~~~~~~~~~#",
		"#~~~~~~~~~~~~~~~~~~#",
		"####################",
	],
}

## Água rasa (2 tiles) sobre espinhos.
const WATER_SPIKES := {
	"name": "teste água e espinhos", "rotate": true, "start_rot": 0, "door_open": true,
	"rows": [
		"############",
		"#.PP.......#",
		"#.PP.......#",
		"####.......#",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		"#~~~~~~~~~~#",
		"#~~~~~~~~~~#",
		"#^^^^^^^^^^#",
		"############",
	],
}


## Soma a água de todos os vãos (px²).
func _water_sum() -> float:
	var n := 0.0
	for v in room.wt_h:
		n += v
	return n


## Maior diferença de nível (px) entre as colunas com água que não estão cheias até o teto do vão.
func _surface_spread() -> float:
	var lo := INF
	var hi := -INF
	for k in room.wt_x.size():
		var h: float = room.wt_h[k]
		if h < 0.5 or h > room.wt_bot[k] - room.wt_top[k] - 0.5:
			continue
		var y: float = room.wt_bot[k] - h
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return hi - lo if hi >= lo else 0.0


## Espera a ponta da corda parar de balançar.
func wait_rope(rp: Dictionary, max_frames := 900) -> void:
	var still := 0
	for i in max_frames:
		var pts: PackedVector2Array = rp["pts"]
		var old: PackedVector2Array = rp["old"]
		var n := pts.size() - 1
		still = still + 1 if pts[n].distance_to(old[n]) < 0.05 else 0
		if still > 20:
			return
		tick()


func test_water() -> void:
	print("água")
	load_def(WATER_ROOM)
	var got: Array = []
	room.sfx.connect(func(n): got.append(n))
	var vol := _water_sum()
	check(absf(vol - 18 * 6 * 64) < 0.5 and absf(room.water_vol - vol) < 0.5 and room.water_calm, "a água é lida da sala e começa parada (%.0f px²)" % vol)
	check(_surface_spread() < 0.5, "começa com a superfície plana")
	var h0: PackedFloat64Array = room.wt_h.duplicate()
	for i in 4:
		room._rotate_logic(1)
	var same: bool = room.wt_h.size() == h0.size()
	for k in h0.size():
		same = same and absf(room.wt_h[k] - h0[k]) < 0.001
	check(same, "quatro giros devolvem a água ao lugar")
	idle(60)
	# cair na água: afunda um instante, depois boia com a cabeça de fora
	var surface := 13 * 8
	walk_until(1.0, func(): return not room.rabbit.on_ground and room.rabbit.pos.x > 40, 200)
	var deepest := 0
	var max_wet := 0.0
	for i in 240:
		tick()
		deepest = maxi(deepest, room.rabbit.pos.y - surface)
		max_wet = maxf(max_wet, room.rabbit.wet)
	print("  afundou até %d px abaixo da superfície; em repouso, %.0f%% submerso" % [deepest, room.rabbit.wet * 100.0])
	check(got.has("splash"), "cair na água faz barulho")
	check(max_wet >= 0.99 and deepest >= 4, "ao cair, o coelho afunda por um momento")
	check(room.rabbit.wet > 0.45 and room.rabbit.wet < 0.75 and not room.rabbit.on_ground, "depois boia com a cabeça para fora")
	var p0: Vector2i = room.rabbit.pos
	idle(90)
	check((room.rabbit.pos - p0).length() <= 1.0 and room.state == "play", "boiando, fica parado e a água não mata")
	# nadar e pular a partir da superfície
	var x0: int = room.rabbit.pos.x
	for i in 60:
		tick({"move": 1.0})
	var swum: int = room.rabbit.pos.x - x0
	check(swum > 20 and swum < 72, "nada para o lado, mais devagar que andando (%d px em 1 s)" % swum)
	idle(60)
	var y0: int = room.rabbit.pos.y
	var top := y0
	tick({"jump_pressed": true, "jump_held": true})
	for i in 40:
		tick({"jump_held": true})
		top = mini(top, room.rabbit.pos.y)
	print("  pulo a partir da superfície: %d px" % (y0 - top))
	check(y0 - top >= 12 and y0 - top <= 30, "pula a partir da superfície (%d px)" % (y0 - top))
	idle(120)
	# boiando, o giro é livre; a água cai, conserva o volume e assenta
	room.rabbit.air_rot = false
	wait_rot_ready()
	tick({"rotate": 1})
	check(room.rotating, "boiando, pode girar a sala")
	idle(400)
	print("  volume depois do giro: %.0f de %.0f px²; desnível da superfície: %.2f px" % [_water_sum(), vol, _surface_spread()])
	check(absf(_water_sum() - vol) < vol * 0.01 and room.water_calm, "depois do giro a água conserva o volume e assenta")
	check(_surface_spread() < 1.0, "a água fica nivelada, sem degraus (%.2f px)" % _surface_spread())
	# caixa: afunda devagar
	load_def(WATER_ROOM)
	var b = room.boxes[0]
	b.pos = Vector2i(60, 40)
	var wet_speed := 0.0
	var air_speed := 0.0
	for i in 400:
		tick()
		if room.water_frac(b.rect) >= 0.9:
			wet_speed = maxf(wet_speed, b.vel_y)
		elif room.water_frac(b.rect) == 0.0:
			air_speed = maxf(air_speed, b.vel_y)
	check(b.settled and b.pos.y == 19 * 8 - 16, "a caixa afunda até o fundo")
	check(air_speed > 100.0 and wet_speed > 0.0 and wet_speed <= 46.0, "na água a caixa desce devagar (%.0f px/s no ar, %.0f na água)" % [air_speed, wet_speed])
	# espinhos submersos
	load_def(WATER_SPIKES)
	room.rabbit.pos = Vector2i(60, 16 * 8 - 5)
	idle(120)
	check(room.state == "play" and room.rabbit.wet > 0.4, "boiando sobre espinhos submersos, não encosta neles")
	load_def(WATER_SPIKES)
	walk_until(1.0, func(): return room.state != "play", 300)
	check(room.state == "dead", "caindo de alto, afunda até os espinhos e morre")


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
	for step in [[38, 56], [58, 96], [98, 144], [146, 188]]:
		walk_to(step[0])
		hop_to(step[1])
		check(room.state == "play" and room.rabbit.on_ground and room.rabbit.pos.y < 70, "pilar em x=%d (%s)" % [step[1], where()])
	check(walk_until(1.0, func(): return room.door_open, 600), "caixa no buraco abre a porta (%s)" % where())
	walk_until(1.0, won, 300)
	check(won(), "coelho alcança a porta (%s)" % where())


func test_mergulho() -> void:
	load_named("Mergulho")
	idle(30)
	check(not room.door_open and room.socket_group.has(0), "a porta começa trancada: pede uma caixa")
	wait_rot_ready()
	tick({"rotate": 1})
	idle(300)
	check(not won() and room.state == "play" and not room.door_open, "girando sem a corda, a porta não abre (%s)" % where())
	load_def(Levels.MERGULHO)
	idle(30)
	check(walk_until(1.0, func(): return room.group_filled(0), 600), "empurra a caixa no compartimento do palco (%s)" % where())
	walk_to(int(room.ropes[0]["anchor"].x))
	wait_rope(room.ropes[0])
	jump(0.0, 25)
	check(room.rabbit.rope != null, "agarra a corda (%s)" % where())
	idle(40)
	rot(1)
	idle(360)
	check(room.state == "play" and room.rabbit.rope == null and room.rabbit.wet > 0.3, "o arco o leva até o poço fundo, onde cair é seguro (%s)" % where())
	check(room.group_filled(0), "a caixa continua no compartimento depois do giro")
	for i in 600:
		if won():
			break
		tick({"move": -1.0, "jump_pressed": i % 30 == 0, "jump_held": true})
	check(won(), "do poço, pula para a porta na borda (%s)" % where())


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
	# etapa de baixo: travessia pelo ar; o limitador desfaz o giro e a caixa cai no buraco "a"
	air_rot(1)
	idle(200)
	check(room.state == "play" and room.orientation == 0, "cruzou os espinhos pelo ar e o giro foi desfeito (%s)" % where())
	check(room.group_filled(1), "caixa no buraco abre a comporta do teto (%s)" % where())
	air_rot(-1)
	idle(200)
	check(room.state == "play" and room.orientation == 0, "voltou pelo ar (%s)" % where())
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
	# em cima: sem girar, a porta está alta demais
	walk_until(1.0, func(): return cx() >= 210, 600)
	idle(10)
	jump(0.0, 30)
	wait_ground()
	check(not won() and room.state == "play", "sem girar, a porta alta fica fora de alcance (%s)" % where())
	# girar no sentido horário: a parede da direita vira chão por 2,5 s
	walk_until(1.0, func(): return cx() >= 232, 100)
	wait_ground()
	wait_rot_ready()
	tick({"rotate": 1})
	var t0 := frames
	for i in 148:
		if room.state != "play":
			break
		var inp := {"move": 1.0, "jump_held": true}
		if room.rabbit.on_ground and room.rabbit.pos.x >= 160:
			inp["jump_pressed"] = true
		tick(inp)
	print("  a subida pela parede leva %.1f s de 2,5" % ((frames - t0) / 60.0))
	check(won(), "a parede vira chão: sobe por ela, pulando os espinhos, até a porta (%s)" % where())


func test_agua() -> void:
	load_named("Água")
	idle(30)
	check(room.door_flooded and not room.door_open, "a água cobre a porta e a tranca (%.0f%%)" % (room.water_frac(room.door) * 100.0))
	walk_until(1.0, func(): return room.overlaps(room.rabbit.rect, room.door), 600)
	idle(20)
	check(not won(), "encostar na porta alagada não vence")
	var vol: float = room.water_vol
	rot(-1)
	check(room.state == "play", "girar de dentro da porta alagada não vence: ela demora a destravar")
	rot(1)
	idle(120)
	check(room.state == "play" and room.water_vol > 0.0, "voltar cedo demais (a recarga é de 2,5 s): ainda sobra água (%.0f de %.0f px²)" % [room.water_vol, vol])
	rot(-1)
	var n := 0
	while room.water_vol > 0.5 and n < 1500:
		tick()
		n += 1
	print("  o ralo secou a sala em %.1f s" % (n / 60.0))
	check(room.water_vol <= 0.5, "com a parede do ralo no chão, a água escoa toda (sobrou %.1f px²)" % room.water_vol)
	rot(1)
	wait_ground()
	check(room.door_open, "sem água, a porta abre")
	walk_until(1.0, won, 600)
	check(won(), "coelho alcança a porta (%s)" % where())


## Sala Prumo: pula, gira no ar, agarra a corda, desce `down` quadros e gira de novo.
func _prumo(rise: int, down: int, dir: int) -> String:
	load_def(Levels.PRUMO)
	for r in room.ropes:
		wait_rope(r)
	idle(20)
	air_rot(1, rise)
	for i in 120:
		tick()
		if room.rabbit.rope != null or room.state != "play":
			break
	if room.rabbit.rope == null:
		return "solta"
	for i in down:
		tick({"climb": 1.0})
	wait_rot_ready()
	tick({"rotate": dir})
	for k in 400:
		if room.state != "play":
			break
		tick()
	return room.state


func test_prumo() -> void:
	load_named("Prumo")
	var r0 := "%s" % [room.rotating]
	check(room.gh > room.gw, "começa em pé, com a parede da esquerda por chão (%dx%d)" % [room.gw, room.gh])
	check(_prumo(8, 0, 1) == "dead", "girando sem descer, o arco curto bate nos espinhos")
	check(_prumo(8, 500, 1) in ["won", "done"], "descendo até a ponta e girando, o arco leva à porta")
	check(_prumo(16, 500, 1) in ["won", "done"], "agarrando mais embaixo também funciona")
	check(_prumo(8, 500, -1) == "play", "girando para o outro lado, não chega à porta")
	load_def(Levels.PRUMO)
	idle(10)
	rot(1)
	check(dies_within(300), "girar do chão, sem a corda, é cair nos espinhos")


func _mare_bot(stage: int) -> Array:
	var rx: int = room.rabbit.pos.x + 6
	var ry: int = room.rabbit.pos.y
	var dry: bool = room.rabbit.wet == 0.0
	if dry and ry >= 114 and ry <= 117 and rx >= 54 and stage < 1:
		stage = 1
	if dry and ry >= 90 and ry <= 93 and rx <= 46 and stage == 1:
		stage = 2
	var g: bool = room.rabbit.on_ground
	var inp := {"jump_held": true}
	match stage:
		0:
			var d := 44 - rx
			inp["move"] = signf(d) if absi(d) > 3 else 0.0
			if ry < 140:
				inp["move"] = 1.0 if rx < 58 else 0.0
				if frames % 4 == 0:
					inp["jump_pressed"] = true
		1:
			inp["move"] = -1.0
			if g and rx <= 64:
				inp["jump_pressed"] = true
		2:
			inp["move"] = -1.0
	return [stage, inp]


func test_mare() -> void:
	load_named("Maré")
	idle(60)
	check(room.gw > room.gh, "começa deitada (%dx%d)" % [room.gw, room.gh])
	var got: Array = []
	room.sfx.connect(func(n): got.append(n))
	# sem fazer nada: o giro dura 5 s e é desfeito
	tick({"rotate": 1})
	check(room.limit_t > 0, "o giro liga o limitador")
	idle(160)
	check(room.gw > room.gh and got.has("limiter"), "sem fazer nada, o giro é desfeito aos 2,5 s")
	# a solução, dentro dos 5 s
	load_def(Levels.MARE)
	idle(60)
	tick({"rotate": 1})
	var stage := 0
	var t0 := frames
	for i in 148:
		var r := _mare_bot(stage)
		stage = r[0]
		tick(r[1])
		if room.state != "play":
			break
	print("  a solução leva %.1f s de 2,5" % ((frames - t0) / 60.0))
	check(room.state != "play" and room.state != "dead", "boiando e subindo pelas duas plataformas, chega à porta antes dos 2,5 s (%s)" % where())


func _water_right_of(x: int) -> float:
	var tot := 0.0
	var all := 0.0
	for k in room.wt_x.size():
		all += room.wt_h[k]
		if room.wt_x[k] >= x:
			tot += room.wt_h[k]
	return tot / maxf(all, 1.0)


func test_represa() -> void:
	load_named("Represa")
	idle(40)
	check(room.door_flooded and not room.door_open, "a porta começa alagada, no fundo da cuia")
	var vol: float = room.water_vol
	# esperar não adianta
	idle(600)
	check(room.door_flooded and absf(room.water_vol - vol) < 1.0, "esperar não resolve: não há ralo")
	rot(1)
	idle(120)
	check(room.state == "play" and _water_right_of(0) > 0.0, "girando no sentido horário, a cuia derrama (%s)" % where())
	rot(-1)
	idle(180)
	check(_water_right_of(208) > 0.95, "ao voltar, a água cai na cuia da direita (%.0f%%)" % (_water_right_of(208) * 100.0))
	check(not room.door_flooded and room.door_open, "a porta fica seca e abre")
	check(room.state == "play" and room.rabbit.wet > 0.2, "o coelho caiu junto e boia na cuia da direita (%s)" % where())
	# sai da cuia pela esquerda e cai de lado na cuia da porta
	for i in 600:
		if room.state != "play":
			break
		var inp := {"move": -1.0, "jump_held": true}
		if (room.rabbit.on_ground or room.rabbit.wet > 0.25) and i % 8 == 0:
			inp["jump_pressed"] = true
		tick(inp)
	check(won(), "chega à porta dobrando a borda e pulando sobre os espinhos (%s)" % where())
	# o giro para o outro lado só devolve a água ao ponto de partida
	load_def(Levels.REPRESA)
	idle(40)
	rot(-1)
	idle(120)
	rot(1)
	idle(180)
	check(room.door_flooded, "girando para o lado errado, a água volta para a porta")


func test_naufragio() -> void:
	load_named("Naufrágio")
	idle(40)
	check(room.boxes.size() == 2 and room.sockets.size() == 2 and not room.door_open, "duas caixas, dois compartimentos do outro lado, porta fechada")
	rot(1)
	idle(120)
	check(room.state == "play", "girando, o coelho e as caixas caem rente à parede e passam do poço (%s)" % where())
	rot(-1)
	idle(200)
	check(room.group_filled(0) and room.door_open, "ao voltar, as duas caixas caem nos compartimentos e a porta abre (%s)" % where())
	check(room.state == "play" and room.rabbit.pos.x > 200, "o coelho ficou do lado das caixas")
	var swam := false
	for i in 900:
		if room.state != "play":
			break
		var inp := {"move": -1.0, "jump_held": true}
		if (room.rabbit.on_ground or room.rabbit.wet > 0.25) and i % 10 == 0:
			inp["jump_pressed"] = true
		if room.rabbit.wet > 0.25:
			swam = true
		tick(inp)
	check(swam, "a volta é a nado, por cima dos espinhos")
	check(won(), "chega à porta, pulando o espinho (%s)" % where())
	# empurrar uma caixa para dentro do poço é perdê-la
	load_def(Levels.NAUFRAGIO)
	idle(40)
	walk_until(1.0, func(): return room.boxes[0].pos.x > 112 or room.boxes[1].pos.x > 112, 900)
	idle(400)
	var lost := false
	for b in room.boxes:
		if b.pos.x > 96 and b.pos.x < 248 and b.pos.y > 112:
			lost = true
	check(lost, "caixa empurrada para o poço afunda e fica perdida (%s)" % where())


## Sala de teste: comporta "1" e a inversa do mesmo número, ligadas ao compartimento "a".
const INVERSE_ROOM := {
	"name": "teste inversa", "rotate": true, "start_rot": 0, "door_open": true,
	"rows": [
		"######################",
		"#....................#",
		"#....................#",
		"#.........1...¹......#",
		"#.........1...¹......#",
		"#PP.BB....1...¹....DD#",
		"#PP.BB....1...¹....DD#",
		"######aa##############",
		"######aa##############",
		"######################",
	],
}


func test_inverse_gate() -> void:
	print("comporta inversa")
	load_def(INVERSE_ROOM)
	idle(10)
	var normal: Dictionary = {}
	var inv: Dictionary = {}
	for g in room.gates:
		if g["inverse"]:
			inv = g
		else:
			normal = g
	check(room.gates.size() == 2 and normal["id"] == 1 and inv["id"] == 1, "duas comportas com o mesmo número: a comum e a inversa")
	check(normal["closed"] and not inv["closed"], "com o compartimento vazio, a comum fecha e a inversa abre")
	check(room.solid_static(normal["rects"][0]) and not room.solid_static(inv["rects"][0]), "e só a comum é sólida")
	var got: Array = []
	room.sfx.connect(func(n): got.append(n))
	check(walk_until(1.0, func(): return room.group_filled(1), 600), "empurra a caixa para o compartimento (%s)" % where())
	idle(30)
	check(not normal["closed"] and inv["closed"], "com a caixa lá, a comum abre e a inversa fecha")
	check(room.solid_static(inv["rects"][0]) and not room.solid_static(normal["rects"][0]), "agora é a inversa que é sólida")
	check(got.has("gate_open") and got.has("gate_close"), "as duas mudanças fazem som")
	for i in 200:
		tick({"move": 1.0})
	check(room.rabbit.pos.x + 12 <= inv["rects"][0].position.x and not won(), "o coelho passa pela comum e para na inversa (%s)" % where())
	# tirar a caixa desfaz tudo
	room.boxes[0].pos = Vector2i(32, 40)
	idle(60)
	check(normal["closed"] and not inv["closed"], "sem a caixa, voltam ao estado original")
	# nunca fecha em cima do coelho
	load_def(INVERSE_ROOM)
	idle(10)
	room.rabbit.pos = Vector2i(14 * 8 + 2, 40)
	room.boxes[0].pos = Vector2i(6 * 8, 40)
	idle(40)
	check(room.group_filled(1) and room.state == "play", "a inversa espera o coelho sair antes de fechar (não esmaga)")
	# quatro giros devolvem as comportas inversas ao lugar
	load_def(INVERSE_ROOM)
	var before: Array = []
	for g in room.gates:
		before.append([g["inverse"], g["rects"].duplicate()])
	for i in 4:
		room._rotate_logic(1)
	var after: Array = []
	for g in room.gates:
		after.append([g["inverse"], g["rects"].duplicate()])
	check(before == after, "quatro giros devolvem as comportas ao lugar")


# ------------------------------------------------------------ boss 1: Jeffrey

func _jeffrey() -> void:
	load_def(Levels.JEFFREY)
	seed(7)


func test_spin_block() -> void:
	print("bloco que gira (sala de boss)")
	_jeffrey()
	idle(60)
	check(room.has_spin and room.spin_face == 0, "o bloco começa com espinhos em cima")
	var y0: int = room.rabbit.pos.y
	var w0: int = room.pw
	wait_rot_ready()
	tick({"rotate": 1})
	check(room.spinning and not room.rotating, "girar mexe no bloco, não na sala")
	var frames_spin := 0
	while room.spinning and frames_spin < 40:
		tick()
		frames_spin += 1
	check(frames_spin <= room.SPIN_FRAMES, "o giro do bloco é curto (%d quadros)" % frames_spin)
	check(room.spin_face == 1, "girar no sentido horário leva os espinhos para a direita")
	check(room.pw == w0, "a sala continua do mesmo tamanho")
	var right := true
	for sp in room.spikes:
		if sp.get("block", false):
			right = right and sp["facing"] == 1 and sp["rect"].position.x == room.spin_rect.end.x
	check(right, "os espinhos ficam encostados na face direita, apontando para fora")
	# o jogo não pausa: o esquilo segue se movendo durante o giro
	_jeffrey()
	idle(80)
	wait_rot_ready()
	var p0: Vector2 = room.actors[0].pos
	tick({"rotate": -1})
	idle(4)
	check(room.actors[0].pos != p0, "o jogo não pausa durante o giro do bloco")


## Girando à toa, mas nunca durante o salto de ataque, o esquilo não pode se ferir.
func test_jeffrey_no_suicide() -> void:
	print("Jeffrey: nunca salta nos espinhos")
	_jeffrey()
	var boss = room.actors[0]
	var states := {}
	var hit := false
	for i in 6000:
		var r := 0
		if boss.state != "attack" and boss.state != "bounce" and randi() % 25 == 0:
			r = 1 if randi() % 2 == 0 else -1
		tick({"rotate": r})
		states[boss.state] = true
		if boss.hearts < 3:
			hit = true
			break
	check(not hit, "girar fora do salto de ataque nunca acerta o esquilo")
	check(states.has("attack") and states.has("aim"), "o esquilo mira e ataca (estados vistos: %s)" % ", ".join(states.keys()))


## Bot: gira no último instante, no sentido que leva os espinhos para a face mirada.
func test_jeffrey_bot() -> void:
	print("Jeffrey: girar no último instante vence")
	_jeffrey()
	var boss = room.actors[0]
	var deaths := 0
	var was_dead := false
	var i := 0
	while boss.hearts > 0 and i < 20000:
		var r := 0
		if boss.state == "attack" and boss.t == boss.leg_frames - room.SPIN_FRAMES - 4:
			r = 1 if boss.target_face == (room.spin_face + 1) % 4 else -1
		tick({"rotate": r})
		if room.state == "dead" and not was_dead:
			deaths += 1
		was_dead = room.state == "dead"
		i += 1
	print("  %d quadros, %d mortes do coelho" % [i, deaths])
	check(boss.hearts == 0, "o bot tira os 3 corações")
	idle(120)
	check(room.door_open, "com o esquilo derrotado, a porta abre")
	var won := false
	for k in 900:
		tick({"move": 1.0})
		if room.state == "won" or room.state == "done":
			won = true
			break
	check(won, "o coelho chega à porta depois da luta")

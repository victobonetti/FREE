extends SceneTree
## Testes headless. Rodar:
##   Godot_console.exe --headless --path . -s tests/run_tests.gd
##
## Os testes de mecânica usam salas de teste próprias (abaixo), para não quebrarem quando as
## salas do jogo forem redesenhadas. Cada sala do jogo tem um bot que a resolve.

const Levels := preload("res://scripts/levels.gd")
const LevelData := preload("res://scripts/level_data.gd")
const Replay := preload("res://scripts/replay.gd")
const RoomScript := preload("res://scripts/room.gd")
const SfxFactory := preload("res://scripts/sfx_factory.gd")
const Rabbit := preload("res://scripts/rabbit.gd")

var failures := 0
var room
var frames := 0


func _init() -> void:
	test_format()
	test_campaign_proof()
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
	test_crusher()
	test_movers()
	test_gatsby()
	test_gatsby_route()
	test_race_components()
	test_acid()
	test_battery_lever()
	test_mover_triggers()
	test_dynamic_parts()
	test_industrial_levels()
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
	test_jeffrey_replay()
	test_jeffrey_lives()
	test_jeffrey_intro()
	test_subsoil_and_anchors()
	test_mecha_intro()
	test_mecha_dash()
	test_mecha_homing()
	test_mecha_thirds()
	test_mecha_lives()
	test_mecha_stomp()
	test_mecha_bot()
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
	load_def(Levels.rooms()[i])


## Carrega a sala pelo nome (os bots não dependem da ordem dos níveis).
func load_named(n: String) -> void:
	for d in Levels.rooms():
		if d["name"] == n:
			print("%s — nível %d" % [n, Levels.rooms().find(d) + 1])
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
	for i in Levels.count():
		var d: Dictionary = Levels.rooms()[i]
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
		check(room.boxes.size() + (1 if room.chute != null else 0) >= room.sockets.size(), "sala %d: caixas >= compartimentos" % (i + 1))
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
	var steps := got.filter(func(n): return str(n).begins_with("step_"))
	check(steps.size() >= 4, "correr emite passos (%d)" % steps.size())
	check(SfxFactory.make(str(steps[0])) != null if not steps.is_empty() else false, "o passo tem som (%s)" % (steps[0] if not steps.is_empty() else "-"))
	var mats := ["grass", "dirt", "stone", "wet", "metal", "wood", "plate", "water"]
	var ok := true
	for m in mats:
		ok = ok and SfxFactory.make("step_" + m) != null and SfxFactory.ONE_SHOTS.has("step_" + m)
	check(ok, "os oito materiais de passo existem")


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


## Poço 12x20 para a placa de espinhos: chão grosso, o coelho num degrau alto, e uma caixa e
## um espinho no chão (a placa os alcança antes do coelho).
const CRUSH_ROOM := {
	"name": "teste placa", "rotate": true, "start_rot": 0, "door_open": true,
	"crushers": [{"rect": [1, 1, 10, 18], "dir": 0, "speed": 30.0, "delay": 0.5}],
	"rows": [
		"############",
		"#DD........#",
		"#DD........#",
		"###........#",
		"#.......PP.#",
		"#.......PP.#",
		"#.......####",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		"#....BB..^.#",
		"#....BB..#.#",
		"############",
		"############",
		"############",
		"############",
		"############",
		"############",
		"############",
	],
}


func _crush_def(over: Dictionary) -> Dictionary:
	var d: Dictionary = CRUSH_ROOM.duplicate(true)
	for k in over:
		d["crushers"][0][k] = over[k]
	return d


func test_crusher() -> void:
	print("placa de espinhos")
	load_def(CRUSH_ROOM)
	var gw: int = room.gw
	idle(25)
	check(room.crushers[0]["adv"] == 0.0 and room.state == "play", "antes do atraso, a placa está parada")
	check(room.tiles[18 * gw + 5] == 1, "as paredes de baixo estão inteiras")
	idle(60)
	check(room.crushers[0]["adv"] > 10.0, "depois do atraso ela avança (%.1f px)" % room.crushers[0]["adv"])
	check(room.tiles[18 * gw + 5] == 0 and room.tiles[17 * gw + 5] == 0, "destrói as paredes que alcança")
	check(room.tiles[13 * gw + 5] == 1, "o que ela ainda não alcançou fica")
	check(room.tiles[18 * gw] == 1 and room.tiles[18 * gw + 11] == 1, "fora da faixa, a parede fica")
	check(room.state == "play", "o coelho ainda está vivo acima dela")
	var died := false
	for i in 300:
		tick()
		if room.state == "dead":
			died = true
			break
	check(died, "a placa mata o coelho ao alcançá-lo")
	check(room.boxes.is_empty() and room.spikes.is_empty(), "a caixa e o espinho do caminho sumiram")
	idle(30)
	check(room.state == "play" and room.crushers[0]["adv"] == 0.0 and room.tiles[18 * gw + 5] == 1 		and room.boxes.size() == 1 and room.spikes.size() == 1, "morrer reinicia a placa e devolve o que ela destruiu")

	# espera por um ator
	load_def(_crush_def({"delay": -1, "speed": 240.0}))
	idle(120)
	check(room.crushers[0]["adv"] == 0.0, "com atraso negativo, espera ser ligada")
	room.crusher_start(0)
	idle(8)
	check(room.crushers[0]["adv"] > 20.0 and room.state == "play", "crusher_start liga a placa")

	# gira com a sala
	load_def(_crush_def({"delay": -1}))
	var lane0: Rect2i = room.crushers[0]["lane"]
	room._rotate_logic(1)
	check(room.crushers[0]["dir"] == 1, "giro horário: a placa que vinha de baixo passa a vir da esquerda")
	check(room.crushers[0]["lane"].size == Vector2i(lane0.size.y, lane0.size.x), "a faixa gira junto")
	for i in 3:
		room._rotate_logic(1)
	check(room.crushers[0]["dir"] == 0 and room.crushers[0]["lane"] == lane0, "quatro giros restauram a placa")
	room._rotate_logic(-1)
	room.crusher_start(0)
	room.crushers[0]["speed"] = 240.0
	var before: float = room.crusher_gap(room.crushers[0])
	idle(4)
	check(room.crushers[0]["dir"] == 3 and room.crusher_gap(room.crushers[0]) < before, "girada, ela avança da direita para a esquerda")

	# começa já avançada; a guia acelera quando o coelho está longe
	load_def(_crush_def({"delay": -1, "start": 16}))
	check(room.crushers[0]["adv"] == 16.0 and room.tiles[18 * room.gw + 5] == 0, "\"start\": começa avançada e já sem as paredes de baixo")
	check(room.tiles[13 * room.gw + 5] == 1, "o chão continua")
	load_def(_crush_def({"delay": 0, "speed": 6.0, "leash": 20}))
	idle(30)
	var fast: float = room.crushers[0]["adv"]
	load_def(_crush_def({"delay": 0, "speed": 6.0}))
	idle(30)
	check(fast > room.crushers[0]["adv"] * 3.0, "com guia, ela acelera enquanto o coelho está longe (%.1f contra %.1f px)" % [fast, room.crushers[0]["adv"]])


## Corredor 30x12 para o Gatsby: uma cutscene que liga a placa, um giro feito por ele e a fuga.
const GATSBY_ROOM := {
	"name": "teste gatsby", "rotate": true, "start_rot": 0, "door_open": true,
	"actors": ["res://scripts/boss_gatsby.gd"],
	"crushers": [{"rect": [1, 1, 28, 10], "dir": 1, "speed": 6.0, "delay": -1}],
	"movers": [{"ch": 0, "off": [20, 4, 3, 1], "on": [24, 4], "speed": 50.0}],
	"gatsby": {"start": [10, 3], "script": [
		{"cut": true, "mood": "smug", "fly": [12, 5], "lever": true, "crusher": 0, "toggle": 0, "wait": 0.2},
		{"when": [14, 1, 2, 10], "mood": "furious", "rotate": 1},
		{"when": [1, 1, 28, 10], "mood": "smirk", "flee": true},
	]},
	"rows": [
		"##############################",
		"#DD..........................#",
		"#DD..........................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"#....PP......................#",
		"#....PP......................#",
		"##############################",
	],
}


func test_gatsby() -> void:
	print("gatsby")
	var Gatsby = load("res://scripts/boss_gatsby.gd")
	Gatsby.intro_seen = false
	load_def(GATSBY_ROOM)
	var g = room.actors[0]
	var x0: int = room.rabbit.pos.x
	for i in 20:
		tick({"move": 1.0})
	check(room.input_lock and room.rabbit.pos.x == x0, "na cutscene a entrada fica travada")
	check(room.cam_focus != null, "e a câmera vai para ele")
	check(room.crushers[0]["wait"] != 0, "a placa ainda está desligada")
	for i in 200:
		tick()
		if not room.input_lock:
			break
	check(not room.input_lock and room.cam_focus == null, "a cutscene termina e devolve o controle")
	check(room.crushers[0]["wait"] == 0 and g.lever_on, "ele puxou a alavanca e ligou a placa")
	check(Gatsby.intro_seen and g.mood == "smug", "a cutscene fica marcada como vista")
	check(room.mover_state.get(0, false), "o passo liga o canal 0 (toggle)")
	# flutua em volta do coelho, sem encostar e sem se afastar demais
	var dmin := 9999.0
	var dmax := 0.0
	for i in 150:
		tick({"move": 1.0} if i % 40 < 30 else {})
		if g.phase == "flee":
			break
		var d: float = (g.pos - (Vector2(room.rabbit.pos) + Vector2(6, 6))).length()
		dmin = minf(dmin, d)
		dmax = maxf(dmax, d)
	check(dmin >= 24.0 and dmax < 110.0, "ele flutua em volta do coelho, nem encosta nem some (%.0f a %.0f px)" % [dmin, dmax])
	walk_until(1.0, func(): return room.orientation != 0, 300)
	check(room.orientation == 1 and room.limit_t == 0, "o coelho chega à área e ele gira a sala; não é o giro do limitador")
	check(room.crushers[0]["dir"] == 2, "a placa girou junto: agora vem de cima")
	check(g.jolt > 0, "ele é jogado dentro da cápsula")
	idle(30)
	check(g.phase == "flee" or g.phase == "gone", "no fim do roteiro ele foge")
	idle(240)
	check(g.phase == "gone", "e some da tela")
	check(room.state == "play" or room.state == "dead" or won(), "a sala segue em jogo sem ele")
	# repeat: a alavanca é puxada de novo, com pausa
	var rd: Dictionary = GATSBY_ROOM.duplicate(true)
	rd["gatsby"]["script"] = [{"mood": "annoyed", "lever": true, "toggle": 0, "repeat": 2, "wait": 0.5}]
	load_def(rd)
	var flips: Array = []
	var last := false
	for i in 300:
		tick()
		var now: bool = room.mover_state.get(0, false)
		if now != last:
			flips.append(now)
			last = now
	check(flips == [true, false, true], "repeat: três puxadas, ligando e desligando o canal (%s)" % [flips])
	# segunda vez: sem cutscene
	load_def(GATSBY_ROOM)
	idle(2)
	check(not room.input_lock and room.crushers[0]["wait"] == 0, "na segunda vez não há cutscene: a placa já liga")
	Gatsby.intro_seen = false


## Sala 30x16 para os blocos motorizados: o coelho começa em cima da peça A (a balsa).
func _mover_def(movers: Array, box := false, extra := {}) -> Dictionary:
	var rows: Array = []
	for r in 16:
		var line := ""
		for c in 30:
			var ch := "."
			if r == 0 or r >= 14 or c == 0 or c == 29:
				ch = "#"
			if (r == 10 or r == 11) and (c == 4 or c == 5):
				ch = "P"
			if box and (r == 12 or r == 13) and (c == 10 or c == 11):
				ch = "B"
			line += ch
		rows.append(line)
	var d := {"name": "teste movers", "rotate": true, "start_rot": 0, "door_open": true, "movers": movers, "rows": rows}
	d.merge(extra, true)
	return d


func test_movers() -> void:
	print("blocos motorizados")
	var ferry := {"ch": 0, "off": [3, 12, 5, 1], "on": [20, 12], "speed": 60.0}
	load_def(_mover_def([ferry]))
	idle(5)
	var m: Dictionary = room.movers[0]
	check(room.mover_docked(m) and m["r"].position == Vector2i(24, 96), "começa encaixada no lugar de desligado")
	var x0: int = room.rabbit.pos.x
	var y0: int = room.rabbit.pos.y
	check(y0 == 84, "o coelho está em cima dela (y=%d)" % y0)
	idle(30)
	check(room.rabbit.pos.x == x0 and not room.mover_docked(m) == false, "sem o canal ligado, ela não se mexe")
	room.mover_toggle(0, true)
	idle(60)
	check(absi(room.rabbit.pos.x - x0 - 60) <= 2 and room.rabbit.pos.y == y0, "quem está em cima vai junto (andou %d px)" % [room.rabbit.pos.x - x0])
	idle(200)
	check(room.mover_docked(m) and m["r"].position == Vector2i(160, 96), "chega e encaixa no lugar de ligado")
	check(room.rabbit.pos.x - x0 == 136 and room.state == "play", "o coelho chegou do outro lado com ela")
	room.mover_toggle(0)
	idle(400)
	check(m["r"].position == Vector2i(24, 96) and room.rabbit.pos.x == x0, "desligando, ela volta e leva o coelho de volta")

	# elevador: sobe 8 tiles com o coelho em cima
	load_def(_mover_def([{"ch": 1, "off": [26, 12, 3, 1], "on": [26, 4], "speed": 60.0}]))
	room.rabbit.pos = Vector2i(26 * 8 + 4, 12 * 8 - 12)
	idle(3)
	room.mover_toggle(1)
	idle(150)
	check(room.movers[0]["r"].position.y == 32 and room.rabbit.pos.y == 20, "o elevador leva o coelho para cima (y=%d)" % room.rabbit.pos.y)

	# empurra, e esmaga contra a parede
	load_def(_mover_def([ferry]))
	room.rabbit.pos = Vector2i(8 * 8, 100)
	idle(3)
	room.mover_toggle(0)
	idle(40)
	check(room.rabbit.pos.x > 8 * 8 + 20 and room.state == "play", "uma peça que anda empurra o coelho que estava no caminho")
	load_def(_mover_def([{"ch": 0, "off": [20, 12, 3, 1], "on": [26, 12], "speed": 120.0}]))
	room.rabbit.pos = Vector2i(29 * 8 - 12, 100)
	idle(3)
	room.mover_toggle(0)
	check(dies_within(60), "contra a parede, ele é esmagado")

	# a caixa também é empurrada
	load_def(_mover_def([ferry], true))
	idle(5)
	var bx: int = room.boxes[0].pos.x
	room.mover_toggle(0)
	idle(300)
	check(room.boxes[0].pos.x > bx + 20 and room.mover_docked(room.movers[0]), "a caixa é empurrada pela peça")

	# espinhos
	load_def(_mover_def([{"ch": 0, "off": [4, 12, 2, 1], "on": [4, 12], "spikes": 0}]))
	idle(6)
	check(room.state == "dead", "espinhos na face de cima matam quem cai na peça")
	load_def(_mover_def([{"ch": 0, "off": [10, 12, 2, 1], "on": [18, 12], "spikes": 3}]))
	room.rabbit.pos = Vector2i(10 * 8 - 20, 100)
	idle(3)
	check(room.state == "play", "longe dos espinhos, vivo")
	room.mover_toggle(0)
	idle(200)
	check(room.state == "play" or room.state == "dead", "peça com espinhos anda")
	load_def(_mover_def([{"ch": 0, "off": [10, 12, 2, 1], "on": [18, 12], "spikes": 1}]))
	room.rabbit.pos = Vector2i(18 * 8 - 14, 100)
	room.mover_toggle(0)
	check(dies_within(150), "a peça com espinhos na frente alcança e mata o coelho no caminho")

	# gira com a sala, e a placa destrói
	load_def(_mover_def([{"ch": 0, "off": [10, 12, 2, 1], "on": [18, 12], "spikes": 0}]))
	var r0: Rect2i = room.movers[0]["r"]
	var o0: Rect2i = room.movers[0]["on"]
	room._rotate_logic(1)
	check(room.movers[0]["spikes"] == 1 and room.movers[0]["r"].size == Vector2i(r0.size.y, r0.size.x), "gira com a sala (espinhos e peça)")
	for i in 3:
		room._rotate_logic(1)
	check(room.movers[0]["r"] == r0 and room.movers[0]["on"] == o0 and room.movers[0]["spikes"] == 0, "quatro giros restauram")
	load_def(_mover_def([ferry], false, {"crushers": [{"rect": [1, 1, 28, 14], "dir": 0, "speed": 400.0, "delay": 0.0}]}))
	idle(60)
	check(room.movers.is_empty(), "a placa de espinhos destrói as peças no caminho")


## A fase do Gatsby (levels/wip/gatsby.json) tem solução: a rota gravada por um robô
## (tests/fixtures/gatsby-route.json, quadro a quadro) vence a fase sem morrer, e o Gatsby sai de
## cena antes de o coelho chegar à porta. Se mudar a fase, a rota precisa ser refeita.
func test_gatsby_route() -> void:
	print("fase do Gatsby: rota gravada")
	if PENDING_PROOF.has("gatsby"):
		print("  PENDENTE: a rota da corrida precisa ser refeita (D88); teste pulado")
		return
	var def: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/wip/gatsby.json"))
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/gatsby-route.json"))
	var Gatsby = load("res://scripts/boss_gatsby.gd")
	Gatsby.intro_seen = false
	load_def(def)
	var g = room.actors[0]
	var died := false
	var touched := false
	var fled_at := -1
	var won_at := -1
	var n := 0
	for run in route["runs"]:
		var k: Array = run[1]
		var inp := {"move": float(k[0]), "jump_pressed": int(k[1]) == 1, "jump_held": int(k[2]) == 1, "rotate": int(k[3])}
		for i in int(run[0]):
			tick(inp)
			n += 1
			if room.state == "dead":
				died = true
			# a cápsula inteira (antena, casco, propulsor e chama) contra a caixa do coelho
			if g.phase != "gone" and room.overlaps(room.rabbit.rect, Rect2i(Vector2i(g.pos.round()) + Vector2i(-19, -21), Vector2i(38, 62))):
				touched = true
			if fled_at < 0 and (g.phase == "flee" or g.phase == "gone"):
				fled_at = n
			if won_at < 0 and won():
				won_at = n
	for i in 120:
		if won_at >= 0:
			break
		tick()
		n += 1
		if won():
			won_at = n
	check(not died, "a rota não morre")
	check(g.min_gap >= Gatsby.KEEP_MIN - 0.01, "o Gatsby nunca chega perto do coelho (menor distância entre os centros: %.0f px)" % g.min_gap)
	check(not touched, "a cápsula nunca encosta no coelho, quadro a quadro")
	check(won_at > 0, "a rota chega à porta (quadro %d de %d)" % [won_at, int(route["frames"])])
	check(fled_at > 0 and fled_at < won_at - 120, "o Gatsby sai de cena bem antes do fim (saiu no quadro %d, a porta no %d)" % [fled_at, won_at])
	check(room.crushers[1]["adv"] > 0.0 and room.crusher_gap(room.crushers[1]) > 60.0, "a placa triste não alcançou o coelho")
	Gatsby.intro_seen = false


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
	for i in Levels.count():
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
	if load("res://scripts/build_info.gd").BETA:
		# build de teste: o seletor escolhe a fase e Enter começa nela
		IntroScript.beta_sel = 0
		var bi = IntroScript.new()
		bi._ready()
		var picked: Array = []
		bi.level_picked.connect(func(i): picked.append(i))
		for i in 30:
			bi.step(false)
		bi.change_sel(1)
		bi.change_sel(1)
		bi.change_sel(-1)
		bi.step(true)
		check(picked == [0] and bi.phase == bi.TITLE, "beta: o seletor escolhe a fase 1 e Enter começa nela (%s)" % str(picked))
		bi.change_sel(-1)
		bi.step(true)
		check(bi.phase != bi.TITLE, "beta: 'do início' começa pela abertura")
		bi.free()
		IntroScript.beta_sel = 0
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
	load_def(Levels.by_id("mergulho"))
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
	load_def(Levels.by_id("prumo"))
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
	load_def(Levels.by_id("prumo"))
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
	load_def(Levels.by_id("mare"))
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
	load_def(Levels.by_id("represa"))
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
	load_def(Levels.by_id("naufragio"))
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

const BossSquirrel := preload("res://scripts/boss_squirrel.gd")

func _jeffrey() -> void:
	BossSquirrel.intro_seen = true   # os testes da luta pulam a abertura
	load_def(Levels.by_id("jeffrey"))
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
		boss.lives = boss.LIVES   # o bot não desvia de nada: aqui só interessa o acerto do giro
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


## O replay da luta se repete igual: grava os comandos de um bot que vence (sem trapaça de
## vidas) e roda de novo, com e sem a abertura já vista no jogo.
func test_jeffrey_replay() -> void:
	print("Jeffrey: replay da luta")
	for seen in [true, false]:
		BossSquirrel.intro_seen = seen
		var def: Dictionary = Levels.by_id("jeffrey")
		var state := Replay.capture_state(def)
		load_def(def)
		var boss = room.actors[0]
		var runs: Array = []
		var i := 0
		while room.state != "won" and room.state != "done" and i < 30000:
			var inp := {"rotate": 0, "move": 0.0}
			if boss.state == "wait" and room.rot_lock == 0 and i % 20 == 0:
				inp["rotate"] = 1   # abertura: gira o bloco até ele aparecer
			if boss.state == "attack" and boss.t == boss.leg_frames - room.SPIN_FRAMES - 4:
				inp["rotate"] = 1 if boss.target_face == (room.spin_face + 1) % 4 else -1
			if boss.hearts <= 0:
				inp["move"] = 1.0
			Replay.record(runs, inp)
			tick(inp)
			i += 1
		var live_won: bool = room.state == "won" or room.state == "done"
		var rep := Replay.pack(runs, LevelData.from_def(def).content_hash(), state)
		BossSquirrel.intro_seen = not seen   # o jogo em outro estado: o replay tem de restaurar
		var res: Dictionary = Replay.run(def, rep)
		check(BossSquirrel.intro_seen == not seen, "rodar o replay devolve o estado do jogo")
		var live_end := {"state": room.state, "rabbit": room.rabbit.pos, "frame": i, "hearts": boss.hearts}
		check(res["end"] == live_end, "abertura %s: o replay termina exatamente igual à partida (%s)" % ["vista" if seen else "nova", str(live_end)])
		check(res["won"] == live_won, "e com o mesmo resultado (%s)" % ("venceu" if live_won else "não venceu"))
	BossSquirrel.intro_seen = false


## Na primeira vez, o esquilo só aparece depois de 3 giros do bloco; depois, nunca mais espera.
func test_jeffrey_intro() -> void:
	print("Jeffrey: abertura com 3 giros")
	BossSquirrel.intro_seen = false
	load_def(Levels.by_id("jeffrey"))
	var boss = room.actors[0]
	idle(300)
	check(boss.state == "wait" and boss.nuts.is_empty(), "sem girar, o esquilo não aparece")
	check(room.music_override == "", "e a música do boss ainda não toca")
	for n in 2:
		wait_rot_ready()
		tick({"rotate": 1})
		idle(60)
	check(boss.state == "wait", "dois giros ainda não bastam")
	wait_rot_ready()
	tick({"rotate": -1})
	idle(20)
	check(boss.state == "wait", "depois do terceiro, uma pausa curta")
	idle(15)
	check(room.music_override == "res://music/boss-rush-groove.mp3", "a música do boss é pedida quando ele aparece")
	check(boss.state == "enter" and boss.pos.y < room.ph / 2.0, "e ele cai do céu, girando (%s em y=%d)" % [boss.state, boss.pos.y])
	idle(60)
	check(boss.state != "enter" and boss.state != "wait", "e a luta começa")
	room.rabbit.pos = Vector2i(24, 100)
	boss.lives = 1
	room.kill()
	var guard := 0
	while room.state != "play" and guard < 600:
		tick()
		guard += 1
	check(boss.state == "enter", "depois de morrer, ele entra direto, sem esperar os giros")
	load_def(Levels.by_id("jeffrey"))
	check(room.actors[0].state == "enter", "voltando à sala, também")


## Só nesta sala o coelho tem 3 vidas: cada morte custa uma; na terceira, a luta recomeça.
func test_jeffrey_lives() -> void:
	print("Jeffrey: 3 vidas do coelho")
	_jeffrey()
	var boss = room.actors[0]
	idle(70)
	boss.hearts = 1
	check(boss.lives == 3, "o coelho começa com 3 vidas")
	var p0: Vector2i = room.rabbit.pos
	room.kill()
	check(room.state == "play" and boss.lives == 2 and room.invuln > 0, "o primeiro dano tira uma vida e o coelho pisca, sem morrer")
	check(room.rabbit.pos == p0, "e continua onde estava")
	room.kill()
	check(boss.lives == 2, "piscando, é imune")
	idle(boss.INVULN + 2)
	check(room.invuln == 0, "a imunidade é curta (%d quadros)" % boss.INVULN)
	room.kill()
	check(room.state == "play" and boss.lives == 1 and boss.hearts == 1, "segundo dano: sobra 1 vida e o esquilo continua ferido")
	idle(boss.INVULN + 2)
	room.kill()
	check(room.state == "dead", "terceiro dano: o coelho morre")
	var guard := 0
	while room.state != "play" and guard < 600:
		tick()
		guard += 1
	check(boss.lives == 3 and boss.hearts == 3 and room.invuln == 0, "e a luta recomeça, os dois com 3")
	boss.hearts = 2
	boss.lives = 2
	room.reset()
	check(boss.lives == 3 and boss.hearts == 3, "reiniciar com R também recomeça a luta")
	check(boss.blast_hits(Vector2(50, 50), Rect2(60, 44, 12, 12)) and not boss.blast_hits(Vector2(50, 50), Rect2(70, 44, 12, 12)), "a explosão fere só dentro do raio")


# ------------------------------------------------------------ prova da campanha

## Fases que ainda são provadas por um bot escrito à mão (neste arquivo). Cada uma sai desta
## lista quando ganhar um replay gravado no editor; fases novas só entram com replay.
const BOT_IDS := ["passos", "degraus", "giro", "comporta", "derrame", "toca", "setas", "espinhos",
	"prumo", "vertigem", "agua", "mare", "represa", "naufragio", "mergulho", "fuga", "jeffrey",
	"a-mecha"]   # a mecha: provada por test_mecha_bot
## Fases na campanha ainda sem prova (a rota precisa ser refeita): aparecem no relatório, sem falhar.
## A corrida do Gatsby perdeu os giros programados (D88); a rota antiga dependia deles.
const PENDING_PROOF := ["gatsby"]


func test_campaign_proof() -> void:
	print("campanha: toda fase tem prova (replay ou bot)")
	var with_replay := 0
	for id in Levels.ids():
		var path := Levels.replay_path(id)
		if FileAccess.file_exists(path):
			with_replay += 1
			var rep: Dictionary = Replay.load_file(path)
			var raw := FileAccess.get_file_as_string(Levels.level_path(id))
			var data: RefCounted = LevelData.from_json(raw)
			check(Replay.is_for(rep, data.content_hash()), "%s: o replay é da versão atual da fase" % id)
			var res: Dictionary = Replay.run(Levels.by_id(id), rep)
			check(res["won"], "%s: o replay chega à porta (quadro %d)" % [id, res["frame"]])
		else:
			if PENDING_PROOF.has(id):
				print("  PENDENTE %s: sem prova (refazer a rota)" % id)
			else:
				check(BOT_IDS.has(id), "%s: tem replay ou bot" % id)
	print("  %d de %d fases com replay; as outras ainda com bot" % [with_replay, Levels.count()])


# ------------------------------------------------------------ componentes da corrida (D75)

func test_race_components() -> void:
	print("conectores: aviso e catapulta")
	var lift := {"ch": 1, "off": [3, 12, 5, 1], "on": [3, 6], "speed": 240.0, "launch": 300.0}
	load_def(_mover_def([lift]))
	idle(10)
	var m: Dictionary = room.movers[0]
	var y0: int = room.rabbit.pos.y
	room.mover_toggle(1)
	idle(room.MOVER_WARN - 1)
	check(room.mover_warning(1) and not room.mover_wants_on(m) and m["r"].position.y == 96, "no aviso, o canal ainda não mudou e a peça não saiu")
	idle(2)
	check(room.mover_wants_on(m) and not room.mover_warning(1), "depois do aviso, o canal muda")
	var top := y0
	for i in 120:
		tick()
		top = mini(top, room.rabbit.pos.y)
	check(y0 - top > 48 + 15, "a catapulta arremessa o coelho acima do encaixe (subiu %d px; o encaixe fica a 48)" % (y0 - top))
	check(room.state == "play" and room.rabbit.on_ground and room.rabbit.pos.y == 6 * 8 - 12, "e ele cai de volta em cima da peça")
	var plain := {"ch": 1, "off": [3, 12, 5, 1], "on": [3, 6], "speed": 240.0}
	load_def(_mover_def([plain]))
	idle(10)
	room.mover_toggle(1, true)
	top = room.rabbit.pos.y
	for i in 120:
		tick()
		top = mini(top, room.rabbit.pos.y)
	check(top == 6 * 8 - 12, "sem 'launch', a peça só leva o coelho")
	var side := {"ch": 1, "off": [3, 12, 5, 1], "on": [20, 12], "speed": 240.0, "launch": 300.0}
	load_def(_mover_def([side]))
	idle(10)
	y0 = room.rabbit.pos.y
	room.mover_toggle(1, true)
	top = y0
	for i in 120:
		tick()
		top = mini(top, room.rabbit.pos.y)
	check(top == y0, "a catapulta só arremessa para cima")

	print("chapas soltas")
	load_def(_mover_def([], false, {"crumbles": [[3, 12, 5, 1]]}))
	idle(10)
	y0 = room.rabbit.pos.y
	check(room.rabbit.on_ground and y0 == 84 and room.crumbles[0]["t"] >= 0, "a chapa segura o coelho e começa a contar quando pisada")
	idle(room.CRUMBLE_FRAMES - 12)
	check(room.rabbit.pos.y == y0 and room.crumbles.size() == 1, "ainda firme antes do tempo")
	idle(40)
	check(room.crumbles.is_empty() and room.rabbit.pos.y > y0, "depois de %d quadros ela desaba e o coelho cai" % room.CRUMBLE_FRAMES)
	room.reset()
	check(room.crumbles.size() == 1, "reiniciar a sala devolve a chapa")
	load_def(_mover_def([], false, {"crumbles": [[20, 8, 3, 1]]}))
	idle(60)
	check(room.crumbles.size() == 1 and room.crumbles[0]["t"] < 0, "sem pisar, a chapa não cai")
	var r0: Rect2i = room.crumbles[0]["rect"]
	for i in 4:
		rot(1)
	check(room.crumbles[0]["rect"] == r0, "a chapa gira com a sala (quatro giros restauram)")
	load_def(_mover_def([], false, {"crumbles": [[20, 12, 3, 1]], "crushers": [{"rect": [1, 1, 28, 13], "dir": 0, "speed": 60.0}]}))
	idle(90)
	check(room.crumbles.is_empty(), "a placa de espinhos destrói as chapas")

	print("perigo (placa perto)")
	load_def(_mover_def([], false, {"crushers": [{"rect": [1, 1, 28, 13], "dir": 2, "speed": 20.0}]}))
	room.rabbit.pos = Vector2i(40, 100)
	idle(20)
	check(room.danger < 0.6, "com a placa longe, pouco perigo (%.2f)" % room.danger)
	var peak := 0.0
	for i in 400:
		tick()
		if room.state == "play":
			peak = maxf(peak, room.danger)
	check(peak > 0.9 and room.danger_dir == 2, "com a placa chegando, o perigo vai a 1 e aponta o lado de onde ela vem (%.2f)" % peak)
	load_def(FLAT)
	idle(5)
	check(room.danger == 0.0, "sem placa, perigo zero")

	print("Gatsby: nunca encosta no coelho")
	Gatsby_script().intro_seen = true
	load_def(JSON.parse_string(FileAccess.get_file_as_string("res://levels/wip/gatsby.json")))
	var g = room.actors[0]
	idle(30)
	var worst := 1e9
	# o coelho é posto em cima dele, várias vezes, de vários lados
	for k in 40:
		room.rabbit.pos = Vector2i(g.pos.round()) + Vector2i(-6 + (k % 5) * 3 - 6, 2 + (k % 3) * 4 - 4)
		room.rabbit.vel = Vector2.ZERO
		tick()
		if room.state != "play":
			break
		worst = minf(worst, (g.pos + g.BODY - (Vector2(room.rabbit.pos) + Vector2(6, 6))).length())
	check(worst >= g.KEEP_MIN - 1.5, "posto em cima dele, no quadro seguinte ele já está a %d px ou mais (pior caso: %.0f)" % [int(g.KEEP_MIN), worst])
	Gatsby_script().intro_seen = false


func Gatsby_script() -> Script:
	return load("res://scripts/boss_gatsby.gd")


# ------------------------------------------------------------ ácido (D76)

func _acid_room() -> Dictionary:
	var d: Dictionary = WATER_ROOM.duplicate(true)
	var rows: Array = []
	for r in d["rows"]:
		rows.append(String(r).replace("~", "%"))
	d["rows"] = rows
	d["name"] = "teste ácido"
	return d


func test_acid() -> void:
	print("ácido")
	load_def(_acid_room())
	check(room.fluid_acid, "o glifo % faz o fluido da sala ser ácido")
	var vol := _water_sum()
	check(absf(vol - 18 * 6 * 64) < 0.5 and room.water_calm and _surface_spread() < 0.5, "escorre e assenta como a água (%.0f px²)" % vol)
	var h0: PackedFloat64Array = room.wt_h.duplicate()
	for i in 4:
		room._rotate_logic(1)
	var same: bool = room.wt_h.size() == h0.size()
	for k in h0.size():
		same = same and absf(room.wt_h[k] - h0[k]) < 0.001
	check(same, "quatro giros devolvem o ácido ao lugar")
	room.reset()
	idle(30)
	check(room.state == "play", "longe do ácido, nada acontece")
	var got: Array = []
	room.sfx.connect(func(n): got.append(n))
	walk_until(1.0, func(): return room.state != "play" or not room.rabbit.on_ground and room.rabbit.pos.x > 40, 200)
	var died := false
	for i in 150:
		tick()
		if room.state == "dead":
			died = true
			break   # depois de morrer a sala reinicia sozinha
	check(died, "tocar no ácido mata")
	check(got.has("acid_burn") and got.has("acid_splash"), "com chiado e respingo próprios")
	# nada de ácido no que não toca: ficar na borda do tanque, rente à superfície
	room.reset()
	idle(30)
	var surface_y := 13 * 8
	check(room.rabbit.pos.y + 12 <= surface_y - 20, "o coelho começa bem acima da superfície")
	# a sala mista é recusada pelo validador
	var mixed: RefCounted = LevelData.from_def(WATER_ROOM)
	mixed.set_cell(3, 8, "%")
	var msgs := ""
	for e in mixed.errors():
		msgs += e["msg"]
	check(msgs.contains("água") and msgs.contains("ácido"), "água e ácido na mesma sala é erro no editor")
	var pure: RefCounted = LevelData.from_def(_acid_room())
	var only_door := true
	for e in pure.errors():
		only_door = only_door and String(e["msg"]).contains("porta")
	check(only_door, "uma sala só de ácido é válida (o único erro é a falta de porta da sala de teste)")
	load_def(WATER_ROOM)
	check(not room.fluid_acid, "a água continua água")


# ------------------------------------------------------------ baterias, alavanca e calha (D76)

func _lever_room(bats: int = 2, extra := {}) -> Dictionary:
	var rows: Array = []
	for r in 17:
		var line := ""
		for c in 30:
			var ch := "."
			if r == 0 or r == 16 or c == 0 or c == 29 or r == 14 or r == 15:
				ch = "#"
			line += ch
		rows.append(line)
	var put := func(c: int, r: int, t: String) -> void:
		var l: String = rows[r]
		rows[r] = l.substr(0, c) + t + l.substr(c + t.length())
	put.call(1, 12, "PP"); put.call(1, 13, "PP")
	put.call(18, 11, "LL"); put.call(18, 12, "LL")
	put.call(26, 2, "HH"); put.call(26, 3, "HH")
	put.call(26, 14, "SS"); put.call(26, 15, "SS")
	put.call(22, 12, "DD"); put.call(22, 13, "DD")
	var xs := [6, 11, 15]
	for i in bats:
		put.call(xs[i], 13, "+")
	var d := {"name": "teste alavanca", "rotate": true, "start_rot": 0, "rows": rows}
	d.merge(extra, true)
	return d


func test_battery_lever() -> void:
	print("baterias, alavanca e calha")
	load_def(_lever_room(2))
	idle(10)
	check(room.batteries.size() == 2 and room.lever != null and room.chute != null, "o jogo lê as baterias, a alavanca e a calha")
	check(room.boxes.is_empty() and not room.door_open, "no começo não há caixa e a porta está fechada")
	var got: Array = []
	room.sfx.connect(func(n): got.append(n))
	for i in 200:
		tick({"move": 1.0})
		if room.bat_got == 1:
			break
	check(room.bat_got == 1 and got.has("battery"), "pegar a primeira bateria faz barulho")
	check(room.lever["t"] < 0 and not room.input_lock, "com uma só de duas, a alavanca não dispara")
	for i in 200:
		tick({"move": 1.0})
		if room.bat_got == 2:
			break
	check(room.bat_got == 2 and room.lever["t"] >= 0 and got.has("charge"), "com todas as baterias a alavanca dispara sozinha")
	check(room.input_lock, "a entrada fica travada durante a cena")
	for i in 10:
		tick({"move": 1.0})   # ainda desliza um pouco com a velocidade que tinha
	var x0: int = room.rabbit.pos.x
	for i in 50:
		tick({"move": 1.0})
	check(room.rabbit.pos.x == x0 and room.cam_focus != null, "o coelho não anda e a câmera vai para a alavanca")
	var total: int = room.LEVER_PAN + room.LEVER_PULL + room.LEVER_WATCH
	while room.lever["t"] < total - 1:
		tick()
	check(room.lever["pulled"] and room.chute["open"] > 0 and got.has("lever") and got.has("hatch"), "a alavanca vira e a calha abre")
	tick()
	tick()
	check(not room.input_lock and room.cam_focus == null, "no fim da cena, a entrada e a câmera voltam")
	check(room.boxes.size() == 1, "a calha soltou uma caixa")
	idle(260)
	check(room.group_filled(0) and room.door_open, "a caixa cai no compartimento e abre a porta")
	var won := false
	for i in 400:
		tick({"move": 1.0})
		if room.state == "won" or room.state == "done":
			won = true
			break
	check(won, "o coelho chega à porta")

	room.reset()
	check(room.bat_got == 0 and room.lever["t"] < 0 and not room.lever["pulled"] and room.chute["open"] == 0 and room.boxes.is_empty(), "reiniciar a sala devolve as baterias, a alavanca e a calha")
	check(room.batteries[0]["taken"] == false and not room.input_lock, "e destrava a entrada")

	var r0: Rect2i = room.lever["rect"]
	var b0: Rect2i = room.batteries[0]["rect"]
	for i in 4:
		room._rotate_logic(1)
	check(room.lever["rect"] == r0 and room.batteries[0]["rect"] == b0, "quatro giros devolvem a alavanca e as baterias ao lugar")

	print("baterias: validação")
	check(LevelData.from_def(_lever_room(2)).errors().is_empty() or LevelData.from_def(_lever_room(2)).errors().size() == 0, "a sala de teste é válida (a calha conta como a caixa do compartimento)")
	var no_lever: Dictionary = _lever_room(2)
	var rows2: Array = []
	for r in no_lever["rows"]:
		rows2.append(String(r).replace("L", "."))
	no_lever["rows"] = rows2
	var msg := ""
	for e in LevelData.from_def(no_lever).errors():
		msg += String(e["msg"])
	check(msg.contains("alavanca"), "sem alavanca, é erro")
	var four: RefCounted = LevelData.from_def(_lever_room(3))
	four.set_cell(20, 13, "+")
	msg = ""
	for e in four.errors():
		msg += String(e["msg"])
	check(msg.contains("1 a 3 baterias"), "mais de 3 baterias é erro")
	var none: RefCounted = LevelData.from_def(_lever_room(1))
	none.set_cell(6, 13, ".")
	msg = ""
	for e in none.errors():
		msg += String(e["msg"])
	check(msg.contains("1 a 3 baterias"), "alavanca sem baterias é erro")
	var plain: RefCounted = LevelData.from_def(Levels.by_id("giro"))
	check(plain.errors().is_empty(), "as fases sem esses itens continuam válidas")

	print("tema industrial")
	var th: Dictionary = _lever_room(1)
	th["theme"] = "industrial"
	load_def(th)
	idle(30)
	check(room.theme == "industrial" and room.state == "play", "o tema é lido e não muda a simulação")


# ------------------------------------------------------------ gatilhos dos conectores (D76)

## As mensagens do validador. A sala de teste não tem porta, então esse erro é sempre ignorado.
func _msgs(d: RefCounted, only_errors := false) -> String:
	var t := ""
	for e in d.validate():
		if String(e["msg"]).contains("Falta a porta"):
			continue
		if not only_errors or e["erro"]:
			t += String(e["msg"]) + " | "
	return t


func test_mover_triggers() -> void:
	print("conectores: ciclo, bateria e botão")
	# ciclo: meio ciclo de 1 s, aviso nos últimos 16 quadros
	var cyc := {"ch": 0, "off": [20, 3, 4, 1], "on": [20, 8], "speed": 240.0, "cycle": 1.0}
	load_def(_mover_def([cyc]))
	var m: Dictionary = room.movers[0]
	idle(30)
	check(not room.mover_wants_on(m) and m["r"].position.y == 24 and not m["warn"], "no começo do ciclo o conector está no encaixe de desligado")
	idle(20)
	check(m["warn"], "nos últimos %d quadros do meio ciclo os encaixes avisam" % room.MOVER_WARN)
	idle(12)
	check(room.mover_wants_on(m) and not m["warn"], "passado o meio ciclo ele vai para o outro encaixe")
	idle(40)
	check(m["r"].position.y == 64, "e chega lá (y=%d)" % m["r"].position.y)
	idle(60)
	check(not room.mover_wants_on(m) and m["r"].position.y == 24, "no ciclo seguinte volta")
	var a: Dictionary = cyc.duplicate()
	var b: Dictionary = cyc.duplicate()
	b["phase"] = 1.0
	b["off"] = [10, 3, 4, 1]
	b["on"] = [10, 8]
	load_def(_mover_def([a, b]))
	idle(70)
	check(room.mover_wants_on(room.movers[0]) != room.mover_wants_on(room.movers[1]), "'phase' defasa os ciclos (um liga quando o outro desliga)")
	room.reset()
	idle(10)
	check(room.cycle_t == 10 and not room.mover_wants_on(room.movers[0]), "morrer reinicia o relógio dos ciclos")

	# bateria
	var bm := {"ch": 3, "off": [20, 3, 4, 1], "on": [20, 8], "speed": 240.0, "bat": 2}
	load_def(_lever_room(2, {"movers": [bm]}))
	idle(5)
	var mb: Dictionary = room.movers[0]
	check(not room.mover_wants_on(mb), "sem as baterias, o conector fica parado")
	for i in 200:
		tick({"move": 1.0})
		if room.bat_got == 1:
			break
	check(not room.mover_wants_on(mb), "com 1 de 2 baterias, ainda parado")
	for i in 200:
		tick({"move": 1.0})
		if room.bat_got == 2:
			break
	idle(2)
	check(room.mover_wants_on(mb), "com 2 baterias o conector liga")

	# botão de pressão
	var pm := {"ch": 2, "off": [20, 3, 4, 1], "on": [20, 7], "speed": 240.0}
	var plate := {"rect": [9, 13, 3], "ch": 2}
	load_def(_mover_def([pm], false, {"plates": [plate]}))
	idle(20)
	var mp: Dictionary = room.movers[0]
	check(not room.mover_wants_on(mp) and not room.plates[0]["down"], "o botão solto não liga nada")
	var got: Array = []
	room.sfx.connect(func(n): got.append(n))
	for i in 120:
		tick({"move": 1.0})
		if room.plates[0]["down"]:
			break
	idle(2)
	check(room.plates[0]["down"] and room.mover_wants_on(mp) and got.has("plate_on"), "pisar no botão liga o canal dele, com clique")
	for i in 120:
		tick({"move": 1.0})
		if not room.plates[0]["down"]:
			break
	idle(2)
	check(not room.mover_wants_on(mp) and got.has("plate_off"), "sair do botão desliga (modo 'hold')")
	load_def(_mover_def([pm], true, {"plates": [{"rect": [10, 13, 3], "ch": 2}]}))
	idle(30)
	check(room.plates[0]["down"] and room.mover_wants_on(room.movers[0]) and room.rabbit.pos.x < 40, "uma caixa em cima do botão o mantém apertado, mesmo com o coelho longe")
	load_def(_mover_def([pm], false, {"plates": [{"rect": [9, 13, 3], "ch": 2, "mode": "once"}]}))
	for i in 150:
		tick({"move": 1.0})
		if room.plates[0]["down"]:
			break
	for i in 90:
		tick({"move": 1.0})
	check(room.mover_wants_on(room.movers[0]) and room.plates[0]["down"], "no modo 'once' o botão fica apertado depois que o coelho sai")
	load_def(_mover_def([pm], false, {"plates": [{"rect": [9, 13, 3], "ch": 2, "mode": "timed", "time": 1.0}]}))
	for i in 150:
		tick({"move": 1.0})
		if room.plates[0]["down"]:
			break
	var gone := 0
	while room.plates[0]["down"] and gone < 200:
		tick({"move": 1.0})
		gone += 1
	check(gone > 60 and not room.plates[0]["down"], "no modo 'timed' o botão fica ligado um tempo depois de sair e então desliga (%d quadros)" % gone)
	for i in 120:
		tick({"move": -1.0})
		if room.plates[0]["down"]:
			break
	check(room.plates[0]["down"], "no modo 'timed' dá para chamar de novo")
	var pr: Rect2i = room.plates[0]["rect"]
	for i in 4:
		room._rotate_logic(1)
	check(room.plates[0]["rect"] == pr, "o botão gira com a sala (quatro giros restauram)")

	print("validação das peças")
	var base := _mover_def([])
	var ok := LevelData.from_def(base)
	var bad: Dictionary
	bad = _mover_def([{"ch": 0, "off": [3, 5, 4, 1], "on": [20, 8], "speed": 60.0, "cycle": 1.0}])
	check(_msgs(LevelData.from_def(bad), true).contains("mesma linha ou na mesma coluna"), "conector com encaixes desalinhados é erro")
	bad = _mover_def([{"ch": 0, "off": [3, 12, 4, 1], "on": [3, 14], "speed": 60.0, "cycle": 1.0}])
	check(_msgs(LevelData.from_def(bad), true).contains("dentro da parede"), "encaixe dentro da parede é erro")
	bad = _mover_def([{"ch": 0, "off": [3, 3, 4, 1], "on": [3, 8], "speed": 60.0, "cycle": 0.2}])
	check(_msgs(LevelData.from_def(bad), true).contains("0,5 s"), "ciclo menor que 0,5 s é erro")
	bad = _mover_def([{"ch": 9, "off": [3, 3, 4, 1], "on": [3, 8], "speed": 60.0, "cycle": 1.0}])
	check(_msgs(LevelData.from_def(bad), true).contains("canal"), "canal fora de 0 a 7 é erro")
	bad = _mover_def([{"ch": 0, "off": [3, 3, 4, 1], "on": [3, 8], "speed": 60.0}])
	var dm := _msgs(LevelData.from_def(bad))
	check(dm.contains("não tem acionador") and _msgs(LevelData.from_def(bad), true) == "", "conector sem acionador é só aviso")
	bad = _mover_def([{"ch": 0, "off": [3, 3, 4, 1], "on": [3, 8], "speed": 60.0}], false, {"plates": [{"rect": [9, 13, 3], "ch": 0}]})
	check(not _msgs(LevelData.from_def(bad)).contains("acionador"), "com um botão no canal dele, o aviso some")
	bad = _mover_def([], false, {"crushers": [{"rect": [1, 1, 99, 5], "dir": 0, "speed": 9.0}]})
	check(_msgs(LevelData.from_def(bad), true).contains("fora da sala"), "placa fora da sala é erro")
	bad = _mover_def([], false, {"crushers": [{"rect": [1, 1, 5, 5], "dir": 7, "speed": 9.0}]})
	check(_msgs(LevelData.from_def(bad), true).contains("'dir'"), "direção da placa inválida é erro")
	bad = _mover_def([], false, {"crushers": [{"rect": [1, 1, 5, 5], "dir": 0, "speed": 9.0, "delay": -1}]})
	check(_msgs(LevelData.from_def(bad)).contains("nunca liga"), "placa que espera um ator inexistente é aviso")
	bad = _mover_def([], false, {"crumbles": [[0, 0, 3, 1]]})
	check(_msgs(LevelData.from_def(bad)).contains("dentro da parede"), "chapa solta dentro da parede é aviso")
	bad = _mover_def([], false, {"crumbles": [[40, 3, 3, 1]]})
	check(_msgs(LevelData.from_def(bad), true).contains("fora da sala"), "chapa solta fora da sala é erro")
	bad = _mover_def([], false, {"plates": [{"rect": [9, 13, 3], "ch": 9}]})
	check(_msgs(LevelData.from_def(bad), true).contains("canal"), "botão com canal inválido é erro")
	check(_msgs(ok, true) == "", "e uma sala sem esses objetos continua válida")
	var gat: RefCounted = LevelData.from_json(FileAccess.get_file_as_string("res://levels/wip/gatsby.json"))
	check(gat.validate().is_empty(), "a fase do Gatsby valida sem erros nem avisos")


# ------------------------------------------------------------ esteira, mola, ventilador e vapor (D76)

func test_dynamic_parts() -> void:
	print("esteira")
	# o chão (linhas 14 e 15) é de parede; a esteira cobre a fileira de cima (linha 14)
	var belt := {"rect": [3, 14, 20], "dir": 1, "speed": 40.0}
	load_def(_mover_def([], true, {"conveyors": [belt]}))
	idle(20)
	var x0: int = room.rabbit.pos.x
	idle(60)
	var d1: int = room.rabbit.pos.x - x0
	check(d1 >= 34 and d1 <= 46, "parado em cima da esteira, o coelho é levado (%d px em 1 s a 40 px/s)" % d1)
	var bx0: int = room.boxes[0].pos.x
	idle(60)
	check(room.boxes[0].pos.x > bx0 or room.boxes[0].pos.x >= 20 * 8 - 16, "a caixa em cima também anda")
	room.rabbit.pos = Vector2i(12 * 8, 100)
	var xs: int = room.rabbit.pos.x
	for i in 60:
		tick({"move": -1.0})
	check(room.rabbit.pos.x < xs - 20 and room.rabbit.pos.x > xs - 72, "andando contra a esteira, vai mais devagar que no chão (%d px em 1 s)" % (xs - room.rabbit.pos.x))
	var rev := {"rect": [3, 14, 20], "dir": 1, "speed": 40.0, "ch": 4}
	load_def(_mover_def([], false, {"conveyors": [rev]}))
	idle(20)
	check(room.belt_sign(room.conveyors[0]) == 1, "o sentido é o de 'dir'")
	room.mover_toggle(4, true)
	check(room.belt_sign(room.conveyors[0]) == -1, "o canal inverte o sentido")
	load_def(_mover_def([], false, {"conveyors": [{"rect": [3, 14, 20], "dir": 1, "speed": 40.0, "cycle": 1.0}]}))
	idle(70)
	check(room.belt_sign(room.conveyors[0]) == -1, "'cycle' inverte sozinha a cada meio ciclo")
	var dirv: int = room.conveyors[0]["dir"]
	for i in 4:
		room._rotate_logic(1)
	check(room.conveyors[0]["dir"] == dirv and room.conveyors[0]["rect"] == Rect2i(24, 112, 160, 8), "a esteira gira com a sala (quatro giros restauram)")
	room._rotate_logic(1)
	check(room.belt_sign(room.conveyors[0]) == 0, "de lado (a sala girou), ela não carrega")

	print("mola")
	load_def(_mover_def([], false, {"springs": [{"rect": [8, 13, 2], "power": 280.0}]}))
	idle(20)
	var got: Array = []
	room.sfx.connect(func(n): got.append(n))
	var y_ground: int = room.rabbit.pos.y
	var top := y_ground
	for i in 90:
		tick({"move": 1.0})
		top = mini(top, room.rabbit.pos.y)
	check(got.has("spring"), "pisar na mola faz o som dela")
	check(y_ground - top >= 36, "a mola lança bem mais alto que um pulo comum (%d px; o pulo comum sobe ~30)" % (y_ground - top))
	check(room.springs[0]["cd"] >= 0 and room.state == "play", "e o coelho segue vivo")
	load_def(_mover_def([], false, {"springs": [{"rect": [8, 13, 2], "power": 200.0}]}))
	idle(20)
	var top2: int = room.rabbit.pos.y
	for i in 90:
		tick({"move": 1.0})
		top2 = mini(top2, room.rabbit.pos.y)
	check(y_ground - top > y_ground - top2, "mais 'power', mais alto")

	print("ventilador")
	load_def(_mover_def([], true, {"fans": [{"rect": [5, 4, 3, 10], "dir": 0}]}))
	room.rabbit.pos = Vector2i(5 * 8 + 6, 100)
	idle(30)
	check(room.rabbit.pos.y < 100 - 20, "dentro do ar soprado, o coelho sobe do chão (y=%d)" % room.rabbit.pos.y)
	idle(120)
	check(room.rabbit.pos.y <= 4 * 8 + 2 and room.state == "play", "e sobe até o alto da coluna, sem atravessar o teto")
	room.rabbit.pos = Vector2i(5 * 8 + 6, 100)
	room.rabbit.vel = Vector2.ZERO
	var spd := 0.0
	for i in 40:
		tick()
		spd = maxf(spd, -room.rabbit.vel.y)
	check(spd <= 72.5, "a velocidade de subida tem teto ('cap' 70 px/s: %.0f)" % spd)
	load_def(_mover_def([], true, {"fans": [{"rect": [10, 3, 2, 11], "dir": 0}]}))
	idle(5)
	var by0: int = room.boxes[0].pos.y
	check(room.boxes[0].pos.x >= 80 and room.boxes[0].pos.x < 96, "a caixa está na coluna de ar")
	idle(120)
	check(room.boxes[0].pos.y < by0 - 30, "a caixa também sobe no ar soprado (y %d -> %d)" % [by0, room.boxes[0].pos.y])
	idle(240)
	var hover: int = room.boxes[0].pos.y
	check(hover >= 3 * 8 - 16 - 2 and hover <= 3 * 8 - 16 + 3, "e paira no alto da coluna de ar, com a base na borda dela (y=%d)" % hover)
	check(room.fans.size() == 1 and room.fan_gain >= 0.0, "o ventilador gira com a sala")
	var fr: Rect2i = room.fans[0]["rect"]
	for i in 4:
		room._rotate_logic(1)
	check(room.fans[0]["rect"] == fr and room.fans[0]["dir"] == 0, "quatro giros restauram o ventilador")
	room._rotate_logic(1)
	check(room.fans[0]["dir"] == 1, "e um giro vira o sopro para o lado")

	print("jato de vapor")
	# período de 3 s, aberto nos últimos 1 s; o jato fica em cima do chão
	load_def(_mover_def([], false, {"vents": [{"rect": [20, 8, 2, 6], "dir": 0, "period": 3.0, "on": 1.0}]}))
	room.rabbit.pos = Vector2i(2 * 8, 100)
	var got2: Array = []
	room.sfx.connect(func(n): got2.append(n))
	idle(60)
	var v: Dictionary = room.vents[0]
	check(not v["active"] and not v["warn"], "no começo do período o jato está fechado")
	idle(45)
	check(v["warn"] and not v["active"] and got2.has("steam_warn"), "meio segundo antes de abrir ele avisa, com chiado")
	idle(30)
	check(v["active"] and got2.has("steam_burst"), "depois do aviso ele abre, com um sopro")
	room.rabbit.pos = Vector2i(20 * 8 + 2, 100)
	room.rabbit.vel = Vector2.ZERO
	var died := false
	for i in 30:
		tick()
		if room.state == "dead":
			died = true
			break
	check(died, "o vapor aberto mata o coelho")
	load_def(_mover_def([], false, {"vents": [{"rect": [20, 8, 2, 6], "dir": 0, "period": 3.0, "on": 1.0}]}))
	room.rabbit.pos = Vector2i(20 * 8 + 2, 100)
	idle(60)
	check(room.state == "play", "com o jato fechado dá para atravessar")
	var vr: Rect2i = room.vents[0]["rect"]
	for i in 4:
		room._rotate_logic(1)
	check(room.vents[0]["rect"] == vr, "o jato gira com a sala (quatro giros restauram)")
	room.reset()
	idle(3)
	check(room.cycle_t == 3 and not room.vents[0]["active"], "morrer reinicia o relógio do vapor")
	print("peças dinâmicas na placa de espinhos")
	load_def(_mover_def([], false, {"springs": [{"rect": [20, 13, 2]}], "crushers": [{"rect": [1, 1, 28, 13], "dir": 1, "speed": 60.0, "delay": 0.0}]}))
	room.rabbit.pos = Vector2i(27 * 8, 100)   # longe: a placa ainda não o alcançou
	idle(150)
	check(room.state == "play" and room.springs.is_empty(), "a placa de espinhos destrói a mola")


# ------------------------------------------------------------ as 5 fases industriais (D76)

const INDUSTRIAL := ["montagem", "esteiras", "prensas", "dutos", "forca"]


## Cada fase do ato 2 (levels/wip) tem solução: a rota gravada pelo robô (tools/robot.gd) vence sem
## morrer, pega todas as baterias e a caixa abre a porta. A fase valida sem erros nem avisos.
func test_industrial_levels() -> void:
	print("fases industriais: rotas do robô")
	var Gatsby = load("res://scripts/boss_gatsby.gd")
	for id in INDUSTRIAL:
		var raw := FileAccess.get_file_as_string("res://levels/wip/%s.json" % id)
		var data: RefCounted = LevelData.from_json(raw)
		check(data != null and _msgs(data) == "", "%s: valida sem erros nem avisos (%s)" % [id, _msgs(data)])
		var def: Dictionary = JSON.parse_string(raw)
		var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/route-%s.json" % id))
		Gatsby.intro_seen = false
		load_def(def)
		var died := false
		var won_at := -1
		var fired := false
		var n := 0
		for run in route["runs"]:
			var k: Array = run[1]
			var inp := {"move": float(k[0]), "jump_pressed": int(k[1]) == 1, "jump_held": int(k[2]) == 1, "rotate": int(k[3])}
			for i in int(run[0]):
				tick(inp)
				n += 1
				if room.state == "dead":
					died = true
				if room.lever != null and room.lever["pulled"]:
					fired = true
				if won_at < 0 and won():
					won_at = n
		for i in 90:
			if won_at >= 0:
				break
			tick()
			n += 1
			if won():
				won_at = n
		check(not died, "%s: a rota não morre" % id)
		check(won_at > 0, "%s: a rota chega à porta (quadro %d de %d)" % [id, won_at, int(route["frames"])])
		check(room.bat_got == room.batteries.size() and fired, "%s: pega todas as %d baterias e a alavanca se puxa" % [id, room.batteries.size()])
		check(room.group_filled(0) or won_at > 0, "%s: a caixa está no compartimento" % id)
		var tall: int = room.gh
		check(room.gw * room.gh >= 80 * 40, "%s: é grande (%dx%d tiles)" % [id, room.gw, tall])
		check(room.theme == "industrial" and room.allow_rotate and room.def.get("limiter", false), "%s: tema industrial, giro liberado com limitador" % id)
	Gatsby.intro_seen = false


# ------------------------------------------------------------ boss 3: a mecha do Gatsby (D80)

const BossMecha := preload("res://scripts/boss_mecha.gd")


func _mecha(skip_intro := true) -> Variant:
	BossMecha.intro_seen = skip_intro
	load_def(JSON.parse_string(FileAccess.get_file_as_string("res://levels/wip/mecha.json")))
	var m = room.actors[0]
	if skip_intro:
		var n := 0
		while m.state != "idle" and n < 600:
			tick()
			n += 1
	return m


## Começa um ataque de investida já; devolve a mecha.
func _mecha_dash(m) -> void:
	m.homers.clear()
	m.markers.clear()
	m.shots.clear()
	m.state = "dash_warn"
	m.t = 0
	m.committed = false
	m.lost = false


func test_mecha_intro() -> void:
	print("mecha: a abertura")
	var raw := FileAccess.get_file_as_string("res://levels/wip/mecha.json")
	var data: RefCounted = LevelData.from_json(raw)
	check(data != null and _msgs(data, true) == "", "a sala da mecha valida sem erros (%s)" % _msgs(data, true))
	var m = _mecha(false)
	check(m.state == "inert" and not room.allow_rotate, "começa com a mecha inerte e sem giro")
	idle(30)
	tick({"rotate": 1})
	idle(20)
	check(room.orientation == 0, "na abertura, o giro não acontece")
	var n := 0
	while m.state != "idle" and n < 600:
		tick()
		n += 1
	check(m.state == "idle" and room.allow_rotate, "o Gatsby pluga e a luta começa (giro liberado) em %d quadros" % (n + 50))
	check(BossMecha.intro_seen, "a abertura fica vista")
	check(m.puppet.pos.distance_to(m.pos + m.HEAD) < 3.0, "a cápsula do Gatsby fica no alto da mecha")


func test_mecha_dash() -> void:
	print("mecha: a investida e o giro")
	# sem girar: pega o coelho e a batida não a fere
	var m = _mecha()
	_mecha_dash(m)
	var n := 0
	while m.state != "stun" and n < 300:
		tick()
		n += 1
	check(m.lives == 2 and m.energy == m.ENERGY, "sem girar, a investida tira um coração do coelho (vidas %d, energia %d)" % [m.lives, m.energy])
	# girando com a mira travada (antes de partir) ou logo depois de partir: erra e bate na parede
	for when in [-10, -2, 0, 6]:
		m = _mecha()
		_mecha_dash(m)
		n = 0
		var flipped := false
		while m.state != "stun" and n < 400:
			var inp := {}
			var at: int = m.DASH_WARN[0] + when
			var now: int = m.t if m.state == "dash_warn" else m.DASH_WARN[0] + m.t
			if not flipped and (m.state == "dash_warn" or m.state == "dash") and now >= at:
				inp = {"rotate": 1}
				flipped = true
			tick(inp)
			n += 1
		check(flipped and m.lives == 3 and m.energy == m.ENERGY - 1, "girar %+d quadros da partida: ela erra, bate e leva dano (vidas %d, energia %d)" % [when, m.lives, m.energy])
	# girar cedo demais (antes de travar a mira): ela mira de novo e pega
	m = _mecha()
	_mecha_dash(m)
	idle(10)
	tick({"rotate": 1})
	n = 0
	while m.state != "stun" and n < 400:
		tick()
		n += 1
	check(m.lives == 2, "girar cedo demais não esquiva (vidas %d)" % m.lives)
	idle(200)
	check(room.orientation == 1 and not room.def.get("limiter", false), "sem limitador: o giro fica")


func test_mecha_homing() -> void:
	print("mecha: os teleguiados")
	var m = _mecha()
	m.state = "idle"
	m.t = -100000
	# um míssil armado vindo para a mecha: acerta e tira energia
	m.homers.append({"pos": m.pos + Vector2(-30, -4), "vel": Vector2(40, 0), "age": m.HOM_ARM + 1})
	room.rabbit.pos = Vector2i(int(m.pos.x) + 40, room.rabbit.pos.y)
	idle(60)
	check(m.energy == m.ENERGY - 1, "o próprio míssil fere a mecha (energia %d)" % m.energy)
	# recém-lançado: passa por ela sem acertar
	m = _mecha()
	m.t = -100000
	m.homers.append({"pos": m.pos, "vel": Vector2(0, -70), "age": 0})
	idle(10)
	check(m.energy == m.ENERGY, "o míssil saindo dela não a fere")
	# sem a mecha no caminho, persegue e acerta o coelho
	m = _mecha()
	m.t = -100000
	m.homers.append({"pos": Vector2(100, 40), "vel": Vector2(0, 40), "age": 20})
	var n := 0
	while m.lives == 3 and n < 900:
		tick()
		n += 1
	check(m.lives == 2, "o teleguiado persegue e acerta o coelho em %d quadros" % n)
	# depois de um giro, a velocidade é de tela: o míssil não vira junto com a sala
	m = _mecha()
	m.t = -100000
	m.homers.append({"pos": Vector2(88, 60), "vel": Vector2(40, 0), "age": 20})
	wait_rot_ready()
	tick({"rotate": 1})
	check(m.homers.size() == 1 and m.homers[0]["vel"].x > 30.0, "o giro não vira a velocidade do míssil")


func test_mecha_thirds() -> void:
	print("mecha: barra em terços e os corações do Gatsby")
	var m = _mecha()
	m.energy = 9
	m._damage(1)
	check(m.hearts == 2 and m.state == "break", "perder um terço: explode por dentro e o Gatsby perde um coração")
	idle(m.BREAK_FRAMES + 2)
	check(m.state == "idle", "depois da explosão, a luta segue")
	m.energy = 1
	m.hearts = 1
	m._damage(1)
	check(m.hearts == 0 and m.state == "dying", "o último terço: ela se desmancha")
	idle(m.DIE_FRAMES + 5)
	check(m.state == "wreck" and room.door_unlocked, "derrotada, a porta destrava")
	idle(200)
	check(not m.puppet.visible, "o Gatsby foge na cápsula")


func test_mecha_lives() -> void:
	print("mecha: os 3 corações do coelho")
	var m = _mecha()
	for i in 2:
		room.kill()
		check(room.state == "play" and m.lives == 2 - i, "levar dano tira um coração e o coelho continua (vidas %d)" % m.lives)
		room.invuln = 0
	m.energy = 7
	room.kill()
	check(room.state == "dead", "no terceiro, o coelho morre")
	idle(200)
	check(m.lives == 3 and m.energy == m.ENERGY and m.hearts == m.HEARTS, "a luta recomeça inteira")


## Um bot que só gira quando a mira da investida trava (e não desvia de mais nada) vence a mecha.
func test_mecha_bot() -> void:
	print("mecha: girar na investida vence")
	var m = _mecha()
	var i := 0
	var flips := 0
	while m.hearts > 0 and i < 40000:
		var r := 0
		if m.state == "dash_warn" and m.t == m.DASH_WARN[m._phase()] - m.DASH_LASER[m._phase()] + 3 and not room.rotating and room.rot_lock == 0:
			r = 1 if flips % 2 == 0 else -1
			flips += 1
		m.lives = m.LIVES   # só interessa o giro na investida
		tick({"rotate": r})
		i += 1
	print("  %d quadros (%.0f s), %d giros" % [i, i / 60.0, flips])
	check(m.hearts == 0, "o bot tira os 3 corações do Gatsby")
	idle(m.DIE_FRAMES + 60)
	check(room.door_unlocked, "a porta destrava")


# ------------------------------------------------------------ ato 1: subsolo, amortecedor, despertar (D82)

func test_subsoil_and_anchors() -> void:
	print("subsolo: tema, amortecedor e despertar")
	# o tema é só aparência: não muda o hash da verificação
	var raw := FileAccess.get_file_as_string(Levels.level_path("passos"))
	var a: RefCounted = LevelData.from_json(raw)
	var d: Dictionary = JSON.parse_string(raw)
	d["theme"] = "industrial"
	var b: RefCounted = LevelData.from_json(JSON.stringify(d))
	check(a.content_hash() == b.content_hash(), "trocar o tema não muda o hash")
	var themed := 0
	for i in 17:
		if RoomScript.SUBSOIL.has(str(Levels.rooms()[i].get("theme", ""))):
			themed += 1
	check(themed == 17, "as 17 fases do ato 1 têm um trecho do subsolo (%d)" % themed)
	# amortecedor: só nas salas com limitador, e gira com a sala
	load_named("Maré")
	check(not room.anchors.is_empty(), "Maré (com limitador) tem amortecedor")
	var r0: Rect2i = room.anchors[0]["rect"]
	var o0: int = room.orientation
	check(room.anchors[0]["facing"] == posmod(2 + o0, 4), "o amortecedor fica no teto da fase como foi desenhada")
	wait_rot_ready()
	tick({"rotate": 1})
	check(room.orientation != o0 and room.anchors[0]["facing"] == posmod(2 + room.orientation, 4) and room.anchors[0]["rect"] != r0, "o amortecedor gira com a sala")
	var n := 0
	while room.orientation != o0 and n < 400:
		tick()
		n += 1
	check(room.orientation == o0 and room.anchors[0]["rect"] == r0, "o limitador desfaz e o amortecedor volta ao lugar")
	load_named("Primeiros passos")
	check(room.anchors.is_empty(), "sala sem limitador não tem amortecedor")
	# despertar: a fase do giro mostra o susto e a primeira batida acende o clarão, uma vez só
	RoomScript.awakened = false
	load_named("Giro")
	check(room.awaken_t == 0, "a fase do giro começa com o despertar")
	idle(30)
	wait_rot_ready()
	tick({"rotate": 1})
	check(RoomScript.awakened and room.awaken_flash > 0, "a primeira batida desperta o giro")
	load_named("Giro")
	check(room.awaken_t == -1, "depois de desperto, a fase não repete a cena")


## Coelho colado na mecha: ela sobe rápido e volta sentando; a onda de choque pega quem está no chão.
func test_mecha_stomp() -> void:
	print("mecha: a sentada e a onda de choque")
	var m = _mecha()
	m.homers.clear()
	room.rabbit.pos = Vector2i(int(m.pos.x) - 40, room.rabbit.pos.y)
	var n := 0
	var seen := {}
	while n < 200 and m.lives == 3:
		tick()
		seen[m.state] = true
		n += 1
	check(seen.has("stomp_up") and seen.has("stomp_down"), "perto demais, ela sobe e volta sentando")
	check(m.lives == 2, "a onda de choque (ou a sentada) pega o coelho parado no chão (vidas %d)" % m.lives)
	m = _mecha()
	m.homers.clear()
	room.rabbit.pos = Vector2i(int(m.pos.x) - 38, room.rabbit.pos.y)
	m.stomp_cd = 0
	m.state = "stomp_down"
	m.t = 0
	m.pos.y -= 40.0
	var jumped := false
	var held := 0
	n = 0
	while n < 120 and m.state != "idle":
		var inp := {}
		if held > 0:
			inp = {"jump_held": true}
			held -= 1
		if not m.waves.is_empty() and not jumped:
			var w = m.waves[0]
			if absf(w["x"] - (room.rabbit.pos.x + 6)) < 14.0 and room.rabbit.on_ground:
				inp = {"jump_pressed": true, "jump_held": true}
				jumped = true
				held = 14
		tick(inp)
		n += 1
	check(jumped and m.lives == 3, "pulando, a onda passa por baixo (vidas %d)" % m.lives)
	# longe (a mais de ~55 px da mecha), a onda some antes de chegar
	m = _mecha()
	m.homers.clear()
	room.rabbit.pos = Vector2i(int(m.pos.x) - 90, room.rabbit.pos.y)
	m.state = "stomp_down"
	m.t = 0
	m.pos.y -= 40.0
	n = 0
	while n < 90 and m.state != "idle":
		tick()
		n += 1
	check(m.lives == 3, "a onda é curta: longe da mecha, o coelho parado não é atingido")

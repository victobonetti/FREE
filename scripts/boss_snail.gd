extends Node2D
## Boss do ato 3: Senzi, o caramujo (D112). Ator da sala (campo "actors"): a sala chama step(room) a
## cada quadro, on_reset(room) quando reinicia e on_rotate(room, dir) quando gira.
##
## Parece só um caramujo um pouco maior, andando devagar. Chegando perto, ele se revela: incha em três
## trancos e vira o Senzi: alto, atlético, um velocista sem rosto com a concha minúscula de chapéu.
##
## A regra da luta (D112, refeita): ele CORRE grudado na superfície (chão, paredes, teto; girar a sala
## não o derruba), atrás do coelho; encostar nele tira um coração do coelho. Muros de cogumelo brotam
## no caminho do coelho (o coelho pula; ele atravessa na força bruta). A energia dele, uma barra
## grande no alto, cai com o tempo e muito mais a cada muro quebrado. Sem energia, ele desaba e morre.
##   - A cada terço da barra gasto ele fica mais rápido (e para um instante, flexionando, com raiva).
##   - No segundo terço: às vezes pula para a frente do coelho (pisca e grunhe antes) ou vira de repente.
##   - No último: também arremessa halteres.
## 3 corações do coelho nesta sala, como na mecha.

const LIVES := 3
const INVULN := 60
const BODY := Vector2(30, 46)        # ao longo da superfície × para fora dela (alto: o coelho não pula por cima)
# A arte (D112): folha de sprites desenhada quadro a quadro por tools/art/senzi_sprites.py.
# (load, e não preload: sem a arte importada, o script ainda carrega e a sala funciona)
var sheet: Texture2D = load("res://art/senzi.png")
const FRAME := Vector2(96, 96)
const FEET := 94.0                   # a linha dos pés no quadro
const ANIM := {"run": [0, 8], "idle": [1, 4], "flex": [2, 6], "throw": [3, 4], "die": [4, 4], "leap": [5, 3], "punch": [6, 4]}
const TUCK := Vector2(8, -33)        # o centro da bola encolhida, a partir dos pés (o eixo da cambalhota)
const STRIDE := 5.0                  # px corridos por quadro da corrida
const SPEED := [62.0, 76.0, 90.0]    # px/s, por terço da barra gasto
const TURN_DELAY := [34, 22, 14]     # quadros para dar meia-volta quando o coelho passa por ele
const ENERGY := 300.0
const DRAIN := [3.0, 3.5, 4.0]       # energia por segundo, só de correr
const WALL_COST := 30.0              # energia por muro quebrado
const WALL_EVERY := [105, 92, 80]    # quadros entre dois muros
const WALL_MAX := 3
const WALL_LIFE := 600
const WALL_SIZE := Vector2(12, 20)   # largura × altura, de pé no chão
const GRAV := 700.0
const REVEAL := 200                  # a revelação: parado, encara; então incha em três estouros e ruge
const R_STARE := 70
const R_POPS := [70, 92, 114]
const R_ROAR := 114
const LEAP_EVERY := 170
const LEAP_WARN := 30
const LEAP_FRAMES := 30
const LEAP_HIGH := 58.0              # altura da cambalhota
const PUNCH_REACH := 40.0            # alcance do soco, à frente do centro dele
const PUNCH_WIND := 8                # quadros carregando o soco (dá para escapar)
const PUNCH_FRAMES := 34
const PUNCH_SPEED := 520.0           # px/s, o coelho voando
const PUNCH_LIFT := 150.0
const FLY_FRAMES := 70               # quadros em que o coelho voando quebra o que encontra
const BELL_EVERY := 140
const RAGE_FRAMES := 45              # a pausa de raiva ao passar de um terço da barra
const DIE_FRAMES := 150

const C_SKIN := Color("d7cdb8")
const C_MUSCLE := Color("e9e3d4")
const C_GOO := Color("aca08c")
const C_SHELL := Color("8a5f9e")
const C_SHELL_DARK := Color("5e3f70")
const C_SHELL_LINE := Color("c9a6dd")
const C_HEART := Color("e0657c")
const C_HEART_EMPTY := Color(1, 1, 1, 0.18)
const C_ENERGY := Color("b98ee0")

static var intro_seen := false

var room
var rng := RandomNumberGenerator.new()
var state := "lurk"
var t := 0
var anim := 0
var pos := Vector2.ZERO        # centro do corpo, px da sala atual
var vel := Vector2.ZERO        # morrendo (solto, cai)
var dir := 1.0                 # sentido no contorno (+1 / -1)
var turn_t := 0
var lives := LIVES
var energy := ENERGY
var walls: Array = []          # {"rect": Rect2i, "n": Vector2 (normal da face onde nasceu), "age"}
var bells: Array = []          # {"pos", "vel", "age", "bounced"}
var wall_t := 0
var leap_t := 0
var bell_t := 0
var leap_from := Vector2.ZERO
var leap_to := Vector2.ZERO
var flash := 0
var hud_hit := 0
var bar_hit := 0
var pop_flash := 0             # clarão branco da revelação
var phase := 0
var vis_ang := 0.0             # o ângulo desenhado (vira suave nos cantos)
var snap_ang := true
var run_dist := 0.0            # px corridos (o quadro da corrida segue a distância, não o tempo)
var throw_t := 0               # quadros da animação de arremesso do haltere
var fly_t := 0                 # o coelho voando do soco


static func replay_state() -> Dictionary:
	return {"intro_seen": intro_seen}


static func apply_replay_state(d: Dictionary) -> void:
	intro_seen = bool(d.get("intro_seen", false))


func on_reset(r) -> void:
	room = r
	r.input_lock = false
	rng.seed = 20261119
	walls.clear()
	bells.clear()
	vel = Vector2.ZERO
	flash = 0
	hud_hit = 0
	fly_t = 0
	if state == "dead":
		r.door_unlocked = true
		pos = Vector2(r.pw * 0.5, _inner().end.y - 3.0)
		return
	phase = 0
	lives = LIVES
	energy = ENERGY
	wall_t = 0
	leap_t = 0
	bell_t = 0
	t = 0
	var inn := _inner()
	pos = Vector2(inn.position.x + inn.size.x * 0.72, inn.end.y - 3.0)
	dir = -1.0
	state = "lurk" if not intro_seen else "reveal"
	if state == "reveal":
		t = REVEAL - 30   # já visto: a revelação é curta


func on_rotate(r, d: int) -> void:
	pos = r._rot_point(pos, d)
	vel = _rv(vel, d)
	leap_from = r._rot_point(leap_from, d)
	leap_to = r._rot_point(leap_to, d)
	snap_ang = true
	for w in walls:
		w["rect"] = r._rot_rect(w["rect"], d)
		w["n"] = _rv(w["n"], d)
	for b in bells:
		b["pos"] = r._rot_point(b["pos"], d)
		b["vel"] = _rv(b["vel"], d)


static func _rv(v: Vector2, d: int) -> Vector2:
	return Vector2(-v.y, v.x) if d > 0 else Vector2(v.y, -v.x)


func absorb_kill(r) -> bool:
	lives -= 1
	hud_hit = 50
	if lives <= 0:
		return false
	r.invuln = INVULN
	r.shake = maxf(r.shake, 3.0)
	r.sfx.emit("death")
	return true


## Os muros de cogumelo são sólidos (para o coelho).
func blocks(r: Rect2i) -> bool:
	if fly_t > 0:
		return false   # o coelho voando do soco atravessa (e quebra) os muros
	for w in walls:
		if r.intersects(w["rect"]):
			return true
	return false


# ---------------------------------------------------------------- medidas

## O vão da sala (o retângulo de ar), na sala de agora.
func _inner() -> Rect2:
	var gw: int = room.gw
	var gh: int = room.gh
	var x0 := gw
	var y0 := gh
	var x1 := 0
	var y1 := 0
	for r in gh:
		for c in gw:
			if room.tiles[r * gw + c] == 0:
				x0 = mini(x0, c)
				y0 = mini(y0, r)
				x1 = maxi(x1, c)
				y1 = maxi(y1, r)
	return Rect2(x0 * 8, y0 * 8, (x1 - x0 + 1) * 8, (y1 - y0 + 1) * 8)


## O caminho do centro dele quando grudado: o vão encolhido de meia altura do corpo.
func _path() -> Rect2:
	return _inner().grow(-BODY.y / 2.0)


func _u_len(p: Rect2) -> float:
	return 2.0 * (p.size.x + p.size.y)


## A posição no contorno (0 no canto de baixo à esquerda, correndo pelo chão, a parede da direita, o
## teto e a parede da esquerda) do ponto do contorno mais perto de `q`.
func _u_of(q: Vector2) -> float:
	var p := _path()
	var x := clampf(q.x, p.position.x, p.end.x)
	var y := clampf(q.y, p.position.y, p.end.y)
	var d_floor := absf(q.y - p.end.y)
	var d_right := absf(q.x - p.end.x)
	var d_ceil := absf(q.y - p.position.y)
	var d_left := absf(q.x - p.position.x)
	var m := minf(minf(d_floor, d_right), minf(d_ceil, d_left))
	if m == d_floor:
		return x - p.position.x
	if m == d_right:
		return p.size.x + (p.end.y - y)
	if m == d_ceil:
		return p.size.x + p.size.y + (p.end.x - x)
	return 2.0 * p.size.x + p.size.y + (y - p.position.y)


## O ponto do chão embaixo de x (o alvo dele: o coelho está sempre no chão ou caindo para ele; no
## canto, projetar no ponto mais perto fazia o alvo pular entre o chão e a parede e ele tremia).
func _u_floor(x: float) -> float:
	var p := _path()
	return clampf(x - p.position.x, 0.0, p.size.x)


func _pt_of(u: float) -> Vector2:
	var p := _path()
	var L := _u_len(p)
	u = fposmod(u, L)
	if u < p.size.x:
		return Vector2(p.position.x + u, p.end.y)
	u -= p.size.x
	if u < p.size.y:
		return Vector2(p.end.x, p.end.y - u)
	u -= p.size.y
	if u < p.size.x:
		return Vector2(p.end.x - u, p.position.y)
	u -= p.size.x
	return Vector2(p.position.x, p.position.y + u)


## A normal (para dentro da sala) da superfície em que ele está grudado.
func _surf_n() -> Vector2:
	var p := _path()
	var d_floor := absf(pos.y - p.end.y)
	var d_right := absf(pos.x - p.end.x)
	var d_ceil := absf(pos.y - p.position.y)
	var d_left := absf(pos.x - p.position.x)
	var m := minf(minf(d_floor, d_right), minf(d_ceil, d_left))
	if m == d_floor:
		return Vector2(0, -1)
	if m == d_right:
		return Vector2(-1, 0)
	if m == d_ceil:
		return Vector2(0, 1)
	return Vector2(1, 0)


func body_rect() -> Rect2:
	var n := _surf_n() if _stuck() else Vector2(0, -1)
	var sz := BODY if absf(n.y) > 0.5 else Vector2(BODY.y, BODY.x)
	if state == "dying" or state == "dead":
		sz = Vector2(BODY.y, BODY.x * 0.6)   # caído
	if state == "lurk":
		sz = Vector2(6, 4)
	return Rect2(pos - sz / 2.0, sz)


func _stuck() -> bool:
	return state in ["berserk", "rage", "leap_warn", "punch", "lurk", "reveal"]


func _rabbit_c() -> Vector2:
	return Vector2(room.rabbit.pos) + Vector2(6, 6)


func fighting() -> bool:
	return state in ["berserk", "rage", "leap_warn", "leap", "punch"]


## O terço da barra em que ele está: 0 (cheia), 1, 2 (o fim).
func _phase() -> int:
	return clampi(int((1.0 - energy / ENERGY) * 3.0), 0, 2)


# ---------------------------------------------------------------- simulação

func step(r) -> void:
	room = r
	anim += 1
	flash = maxi(flash - 1, 0)
	pop_flash = maxi(pop_flash - 1, 0)
	throw_t = maxi(throw_t - 1, 0)
	hud_hit = maxi(hud_hit - 1, 0)
	bar_hit = maxi(bar_hit - 1, 0)
	if r.state != "play":
		return
	t += 1
	room.invuln = maxi(room.invuln - 1, 0)
	_update_bells()
	_update_fly()
	match state:
		"lurk":
			# um caramujo um pouco maior, passeando devagar
			var u := _u_of(pos) + dir * 8.0 / 60.0
			var p := _path()
			if u < 10.0 or u > p.size.x - 10.0:
				dir = -dir
			pos = _pt_of(u)
			if pos.distance_to(_rabbit_c()) < 40.0:
				state = "reveal"
				t = 0
				r.input_lock = true
				r.allow_rotate = false
		"reveal":
			if t in R_POPS:
				# cada estouro: clarão, tremor forte, poeira do teto
				var k := R_POPS.find(t)
				pop_flash = 8
				r.shake = maxf(r.shake, 4.0 + 2.5 * k)
				r.impact.emit(1.5 + 0.8 * k)
				r.sfx.emit("blast" if k == 2 else "slam")
				for i in 12 + k * 8:
					var a := rng.randf() * TAU
					r.particles.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * rng.randf_range(40.0, 160.0),
						"life": rng.randi_range(12, 26), "col": C_MUSCLE if i % 2 else C_SHELL, "grav": 120.0})
			if t == R_ROAR + 10:
				r.sfx.emit("gatsby_dash")
			if t >= REVEAL:
				intro_seen = true
				r.input_lock = false
				r.allow_rotate = bool(r.def.get("rotate", true))
				state = "berserk"
				t = 0
				r.sfx.emit("gatsby_dash")
		"berserk":
			_berserk()
		"leap_warn":
			if t % 6 == 0:
				r.sfx.emit("lock_on")
			if t >= LEAP_WARN:
				state = "leap"
				t = 0
				leap_from = pos
				var ahead := 1.0 if room.rabbit.facing > 0 else -1.0
				leap_to = _pt_of(_u_floor(_rabbit_c().x + ahead * 44.0))
				r.sfx.emit("gatsby_dash")
		"leap":
			var k := clampf(float(t) / LEAP_FRAMES, 0.0, 1.0)
			pos = leap_from.lerp(leap_to, k) + Vector2(0, -sin(k * PI) * LEAP_HIGH)
			_hit_rabbit()
			_smash_walls()
			if t >= LEAP_FRAMES:
				pos = leap_to
				state = "berserk"
				t = 0
				r.shake = maxf(r.shake, 3.0)
				r.sfx.emit("slam")
		"punch":
			_punch()
		"rage":
			# passou de um terço da barra: para, flexiona e ruge; volta mais rápido
			_hit_rabbit()
			if t == 10:
				r.sfx.emit("gatsby_dash")
				r.shake = maxf(r.shake, 3.0)
			if t >= RAGE_FRAMES:
				state = "berserk"
				t = 0
		"dying":
			_fall()
			if t % 10 == 0:
				r.particles.append({"pos": pos, "vel": Vector2(rng.randf_range(-40, 40), -rng.randf_range(20, 60)), "life": 20, "col": C_MUSCLE, "grav": 60.0})
			if t >= DIE_FRAMES:
				state = "dead"
				r.door_unlocked = true
				r.sfx.emit("gate_open")
		"dead":
			pass


func _berserk() -> void:
	var ph := _phase()
	# energia: cai com o tempo
	energy -= DRAIN[ph] / 60.0
	# perseguição pelo contorno
	var p := _path()
	var L := _u_len(p)
	var u := _u_of(pos)
	var ur := _u_floor(_rabbit_c().x)
	var d := fposmod(ur - u + L / 2.0, L) - L / 2.0
	var want := signf(d) if absf(d) > 3.0 else dir
	if want != dir:
		turn_t += 1
		var delay: int = TURN_DELAY[ph]
		if ph >= 1 and turn_t == 1 and rng.randf() < 0.5:
			flash = 12
			room.sfx.emit("lock_on")   # vira de repente (com aviso)
			delay = 12
		if turn_t >= delay:
			dir = want
			turn_t = 0
	else:
		turn_t = 0
	if absf(d) > 3.0 or want == dir:
		u += dir * float(SPEED[ph]) / 60.0
		run_dist += float(SPEED[ph]) / 60.0
	pos = _pt_of(u)
	if _in_reach(PUNCH_REACH * 0.8):
		state = "punch"
		t = 0
		var along := (_rabbit_c() - pos).dot(_ahead())
		if along < -2.0:
			dir = -dir   # vira para o coelho
		room.sfx.emit("lock_on")
		return
	_smash_walls()
	# deixa gosma pelo caminho
	if int(run_dist) % 9 < int(float(SPEED[ph]) / 60.0 + 1.0) and rng.randf() < 0.6:
		var n := _surf_n()
		room.particles.append({"pos": pos - n * (BODY.y / 2.0 - 1.0) - _ahead() * rng.randf_range(4.0, 14.0),
			"vel": n * rng.randf_range(4.0, 16.0), "life": rng.randi_range(30, 60), "col": C_GOO if rng.randf() < 0.5 else C_SKIN, "grav": 0.0})
	# muros de cogumelo no caminho do coelho
	wall_t += 1
	if wall_t >= WALL_EVERY[ph]:
		wall_t = 0
		_spawn_wall()
	for w in walls:
		w["age"] += 1
	walls = walls.filter(func(w): return w["age"] < WALL_LIFE)
	# truques
	if ph >= 1:
		leap_t += 1
		if leap_t >= LEAP_EVERY and pos.distance_to(_rabbit_c()) > 50.0 and _surf_n().y < -0.5:
			leap_t = 0
			state = "leap_warn"
			t = 0
			flash = LEAP_WARN
	if ph >= 2:
		bell_t += 1
		if bell_t >= BELL_EVERY:
			bell_t = 0
			_throw_bell()
	if energy <= 0.0:
		_die()
	elif _phase() > phase:
		phase = _phase()
		state = "rage"
		t = 0
		flash = 24
		walls.clear()
		room.sfx.emit("lock_on")


## O vetor ao longo da superfície, no sentido em que ele corre.
func _ahead() -> Vector2:
	var n := _surf_n()
	return Vector2(-n.y, n.x) * dir


## O coelho está ao alcance do soco (à frente dele, na altura do corpo)?
func _in_reach(reach: float) -> bool:
	if room.invuln > 0 or fly_t > 0:
		return false
	# pela distância (e não só à frente): no canto, encurralado, o coelho também apanha
	return pos.distance_to(_rabbit_c()) < reach


## O soco: carrega, estoura (o coelho voa para o outro lado, quebrando tudo), segura e volta.
func _punch() -> void:
	if t == PUNCH_WIND:
		room.sfx.emit("blast")
		if _in_reach(PUNCH_REACH):
			var lives0 := lives
			room.kill()   # um coração (ou a morte, no último)
			if lives < lives0 and lives > 0:
				var rb = room.rabbit
				# para o outro lado da sala, um pouco para o alto (sai do chão)
				var side := 1.0 if _rabbit_c().x < _inner().get_center().x else -1.0
				rb.vel = Vector2(side * PUNCH_SPEED, -PUNCH_LIFT)
				rb.launched = true
				rb.on_ground = false
				rb.var_jump = 0
				rb.coyote = 0
				fly_t = FLY_FRAMES
				# e gira a sala à força: a parede para onde o coelho voa vira o chão (ele despenca
				# até a borda oposta com o embalo do soco)
				if not room.rotating:
					room.pending_rot = 0
					room._begin_rotate(1 if side > 0.0 else -1, true)
				room.shake = maxf(room.shake, 10.0)
				room.impact.emit(4.0)
				var c := _rabbit_c()
				room.particles.append({"pos": c, "vel": Vector2.ZERO, "life": 12, "col": Color(1, 1, 1, 0.9), "grav": 0.0, "ring": 6.0})
				for i in 18:
					var a := rng.randf() * TAU
					room.particles.append({"pos": c, "vel": Vector2(cos(a), sin(a)) * rng.randf_range(60.0, 200.0),
						"life": rng.randi_range(10, 22), "col": Color("efeadf") if i % 2 else C_MUSCLE, "grav": 120.0})
	if t >= PUNCH_FRAMES:
		state = "berserk"
		t = 0


## O coelho voando do soco: quebra os muros que encontra e deixa um rastro; a sala treme.
func _update_fly() -> void:
	if fly_t <= 0:
		return
	fly_t -= 1
	var rb = room.rabbit
	if fly_t < FLY_FRAMES - 6 and rb.on_ground:
		fly_t = 0
		return
	var rr := Rect2(rb.rect).grow(3.0)
	var keep: Array = []
	for w in walls:
		if rr.intersects(Rect2(w["rect"])):
			room.shake = maxf(room.shake, 7.0)
			room.impact.emit(2.0)
			room.sfx.emit("crunch")
			var c := Rect2(w["rect"]).get_center()
			for i in 16:
				room.particles.append({"pos": c, "vel": Vector2(rng.randf_range(-140, 140), -rng.randf_range(20, 160)),
					"life": rng.randi_range(14, 28), "col": Color("9b6bc4") if i % 2 else Color("cfc6d8"), "grav": 300.0})
		else:
			keep.append(w)
	walls = keep
	room.shake = maxf(room.shake, 3.0 + fly_t * 0.06)
	if fly_t % 2 == 0:
		room.particles.append({"pos": _rabbit_c(), "vel": Vector2.ZERO, "life": 10, "col": Color(1, 1, 1, 0.5), "grav": 0.0})


func _hit_rabbit() -> void:
	if room.invuln == 0 and Rect2(room.rabbit.rect).intersects(body_rect().grow(-2.0)):
		room.kill()


func _smash_walls() -> void:
	var br := body_rect()
	var keep: Array = []
	for w in walls:
		if br.intersects(Rect2(w["rect"])):
			energy -= WALL_COST
			bar_hit = 14
			room.shake = maxf(room.shake, 2.5)
			room.sfx.emit("crunch")
			var c := Rect2(w["rect"]).get_center()
			for i in 10:
				room.particles.append({"pos": c, "vel": Vector2(rng.randf_range(-90, 90), -rng.randf_range(20, 110)),
					"life": rng.randi_range(12, 24), "col": Color("9b6bc4") if i % 2 else Color("cfc6d8"), "grav": 300.0})
		else:
			keep.append(w)
	walls = keep


## Um muro de cogumelo brota no chão de agora, no caminho de fuga do coelho.
func _spawn_wall() -> void:
	if walls.size() >= WALL_MAX:
		return
	var inn := _inner()
	var rc := _rabbit_c()
	var away := signf(rc.x - pos.x)
	if away == 0.0:
		away = 1.0
	# tamanho sorteado (D112): de um degrau baixo a quase o pulo inteiro, para não dar para decorar
	var ww := rng.randi_range(9, 16)
	var wh := rng.randi_range(10, 26)
	var x := rc.x + away * rng.randf_range(30.0, 52.0)
	x = clampf(x, inn.position.x + 10.0, inn.end.x - 10.0 - ww)
	var r := Rect2i(int(x), int(inn.end.y - wh), ww, wh)
	if Rect2(r).grow(3.0).intersects(Rect2(room.rabbit.rect)) or Rect2(r).grow(6.0).intersects(body_rect()):
		return
	for w in walls:
		if Rect2(w["rect"]).grow(8.0).intersects(Rect2(r)):
			return
	walls.append({"rect": r, "n": Vector2(0, -1), "age": 0})
	room.sfx.emit("plate_on")


func _die() -> void:
	energy = 0.0
	state = "dying"
	t = 0
	vel = Vector2.ZERO
	walls.clear()
	bells.clear()
	flash = 30
	bar_hit = 30
	room.shake = 6.0
	room.impact.emit(2.5)
	room.sfx.emit("blast")
	for i in 16:
		room.particles.append({"pos": pos, "vel": Vector2(rng.randf_range(-120, 120), rng.randf_range(-120, 60)),
			"life": rng.randi_range(14, 26), "col": C_SKIN if i % 2 else C_SHELL, "grav": 200.0})


## Morrendo: solto, cai com a gravidade de agora.
func _fall() -> void:
	vel.y = minf(vel.y + GRAV / 60.0, 360.0)
	vel.x = move_toward(vel.x, 0.0, 6.0)
	pos += vel / 60.0
	var inn := _inner()
	var br := body_rect()
	if br.end.y >= inn.end.y:
		pos.y = inn.end.y - br.size.y / 2.0
		if vel.y > 120.0:
			room.shake = maxf(room.shake, 2.0)
			room.sfx.emit("slam")
		vel.y = 0.0
	pos.x = clampf(pos.x, inn.position.x + br.size.x / 2.0, inn.end.x - br.size.x / 2.0)
	pos.y = maxf(pos.y, inn.position.y + br.size.y / 2.0)


func _throw_bell() -> void:
	var rc := _rabbit_c()
	var T := 0.9
	var v := Vector2((rc.x - pos.x) / T, (rc.y - pos.y) / T - 0.5 * GRAV * T)
	bells.append({"pos": pos + Vector2(0, -10), "vel": v, "age": 0, "bounced": false})
	throw_t = 16
	room.sfx.emit("gatsby_dash")


func _update_bells() -> void:
	var inn := _inner()
	var keep: Array = []
	for b in bells:
		b["age"] += 1
		b["vel"].y += GRAV / 60.0
		b["pos"] += b["vel"] / 60.0
		var p: Vector2 = b["pos"]
		if p.y > inn.end.y - 4.0:
			p.y = inn.end.y - 4.0
			if not b["bounced"]:
				b["vel"] = Vector2(b["vel"].x * 0.5, -absf(b["vel"].y) * 0.4)
				b["bounced"] = true
				room.sfx.emit("crunch")
			else:
				b["vel"] = Vector2(b["vel"].x * 0.9, 0.0)
		if p.x < inn.position.x + 4.0 or p.x > inn.end.x - 4.0:
			b["vel"].x = -b["vel"].x * 0.5
			p.x = clampf(p.x, inn.position.x + 4.0, inn.end.x - 4.0)
		b["pos"] = p
		if room.invuln == 0 and Rect2(room.rabbit.rect).intersects(Rect2(p - Vector2(5, 3), Vector2(10, 6))):
			room.kill()
			continue
		if b["age"] < 200:
			keep.append(b)
	bells = keep


# ---------------------------------------------------------------- desenho

func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if room == null:
		return
	var base := Transform2D(room.view_angle, Vector2.ZERO) * Transform2D(0.0, -room.cam.round())
	draw_set_transform_matrix(base)
	_draw_walls()
	for b in bells:
		draw_set_transform_matrix(base * Transform2D(b["age"] * 0.3, (b["pos"] as Vector2).round()))
		draw_rect(Rect2(-5, -1, 10, 2), Color("6a6d75"))
		draw_rect(Rect2(-6, -3, 3, 6), Color("2b2c33"))
		draw_rect(Rect2(3, -3, 3, 6), Color("2b2c33"))
		draw_rect(Rect2(-6, -3, 3, 1), Color("8a8d95"))
		draw_rect(Rect2(3, -3, 3, 1), Color("8a8d95"))
	_draw_snail(base)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_hud()


func _draw_walls() -> void:
	for w in walls:
		var r := Rect2(w["rect"])
		var k := clampf(float(w["age"]) / 10.0, 0.0, 1.0)
		var n: Vector2 = w["n"]
		var stem := r
		var cap := r
		if absf(n.y) > 0.5:
			var hh := r.size.y * k
			stem = Rect2(r.position.x + 3, r.end.y - hh if n.y < 0 else r.position.y, r.size.x - 6, hh)
			cap = Rect2(r.position.x - 2, (r.end.y - hh) if n.y < 0 else (r.position.y + hh - 6), r.size.x + 4, 6)
		else:
			var ww := r.size.x * k
			stem = Rect2(r.end.x - ww if n.x < 0 else r.position.x, r.position.y + 3, ww, r.size.y - 6)
			cap = Rect2((r.end.x - ww) if n.x < 0 else (r.position.x + ww - 6), r.position.y - 2, 6, r.size.y + 4)
		draw_rect(stem, Color("cfc6d8"))
		draw_rect(Rect2(stem.position, Vector2(2, stem.size.y)), Color("a99fb4"))
		draw_rect(cap, Color("9b6bc4"))
		draw_rect(Rect2(cap.position, Vector2(cap.size.x, 1)), Color("c9a6dd"))
		if w["age"] > WALL_LIFE - 60 and (anim / 4) % 2 == 0:
			draw_rect(r, Color(0, 0, 0, 0.25))


## Quanto do corpo marombado aparece (0 = o caramujinho; 1 = o Senzi), na revelação e na morte.
func _bulk() -> float:
	match state:
		"lurk":
			return 0.0
		"reveal":
			if t < R_POPS[0]:
				return 0.0
			if t < R_POPS[1]:
				return 0.45
			if t < R_POPS[2]:
				return 0.75
			return 1.0
		"dying":
			# desaba inteiro; só no fim murcha de volta ao caramujinho
			return clampf((float(DIE_FRAMES) - t) / 40.0, 0.0, 1.0)
		"dead":
			return 0.0
	return 1.0


func _draw_snail(base: Transform2D) -> void:
	var n := _surf_n() if _stuck() else Vector2(0, -1)
	var target := Vector2(0, -1).angle_to(n)
	if snap_ang or state == "lurk":
		vis_ang = target
		snap_ang = false
	else:
		vis_ang = lerp_angle(vis_ang, target, 0.3)   # vira suave na quina
	var ang := vis_ang
	var flip := -1.0 if dir < 0 else 1.0
	if state == "reveal" and t < R_STARE:
		flip = signf(_rabbit_c().x - pos.x) if t > 25 else flip   # para e vira para o coelho
	var bulk := _bulk()
	var h := BODY.y / 2.0
	if bulk <= 0.0:
		# o caramujinho: minúsculo (como os de enfeite)
		draw_set_transform_matrix(base * Transform2D(ang, (pos - n * (h - 3.0) * (1.0 if _stuck() else 0.0)).round()) * Transform2D(0.0, Vector2(flip, 1), 0.0, Vector2.ZERO))
		var crawl := 0.5 + 0.5 * sin(anim * 0.08)
		draw_rect(Rect2(-3, 1, 6 + crawl, 2), C_SKIN)
		draw_circle(Vector2(-0.5, 0), 2.5, C_SHELL)
		draw_circle(Vector2(-0.5, 0), 1.3, C_SHELL_DARK)
		draw_line(Vector2(3 + crawl, 1), Vector2(4 + crawl, -2), C_SKIN, 1.0)
		draw_rect(Rect2(4 + crawl, -3, 1, 1), Color("1a1820"))
		if state == "reveal" and t > 30 and t < R_POPS[0]:
			# encara... e treme
			draw_rect(Rect2(4 + crawl, -3, 1, 1), Color("ff3b4e"))
			if (anim / 2) % 2 == 0:
				draw_rect(Rect2(-1, -6, 1, 2), Color(1, 1, 1, 0.9))
				draw_rect(Rect2(-1, -3, 1, 1), Color(1, 1, 1, 0.9))
		draw_set_transform_matrix(base)
		return
	var sc := lerpf(0.5, 1.0, bulk)
	var anim_name := "idle"
	var fr := (anim / 9) % 4
	match state:
		"leap":
			anim_name = "leap"
			fr = 1 + (anim / 4) % 2
		"berserk":
			if throw_t > 0:
				anim_name = "throw"
				fr = clampi((16 - throw_t) / 4, 0, 3)
			else:
				anim_name = "run"
				fr = int(run_dist / STRIDE) % 8
		"leap_warn":
			anim_name = "leap"
			fr = 0
		"punch":
			anim_name = "punch"
			fr = 0 if t < PUNCH_WIND else (1 if t < PUNCH_WIND + 5 else (2 if t < PUNCH_WIND + 14 else 3))
		"rage":
			anim_name = "flex"
			fr = mini(t / 4, 2) if t < 8 else 2 + (t / 5) % 4
		"reveal":
			anim_name = "flex"
			fr = 0 if t < R_ROAR else (mini((t - R_ROAR) / 4, 2) if t < R_ROAR + 8 else 2 + (t / 5) % 4)
		"dying", "dead":
			anim_name = "die"
			fr = clampi(t / 10, 0, 3) if state == "dying" else 3
	if sheet == null:
		draw_set_transform_matrix(base)
		return
	var row: int = ANIM[anim_name][0]
	var white := (flash > 0 and (flash / 3) % 2 == 0)
	var mod := Color(1.0, 0.55, 0.55) if white else Color(1, 1, 1)
	draw_set_transform_matrix(base * Transform2D(ang, pos.round()) * Transform2D(0.0, Vector2(sc * flip, sc), 0.0, Vector2.ZERO))
	var src := Rect2(Vector2(fr, row) * FRAME, FRAME)
	var hd := body_rect().size.y / 2.0 if (state == "dying" or state == "dead") else h
	if state == "leap":
		# a cambalhota: uma volta inteira, para a frente, em torno da bola encolhida
		var k := clampf(float(t) / LEAP_FRAMES, 0.0, 1.0)
		var c := Vector2(TUCK.x, hd + TUCK.y)
		draw_set_transform_matrix(base * Transform2D(ang, pos.round()) * Transform2D(0.0, Vector2(sc * flip, sc), 0.0, Vector2.ZERO)
			* Transform2D(0.0, c) * Transform2D(k * TAU, Vector2.ZERO) * Transform2D(0.0, -c))
	draw_texture_rect_region(sheet, Rect2(Vector2(-FRAME.x / 2.0, hd - FEET), FRAME), src, mod)
	draw_set_transform_matrix(base)


func _draw_hud() -> void:
	if pop_flash > 0:
		draw_rect(Rect2(-200, -120, 400, 240), Color(1, 1, 1, 0.12 * pop_flash))
	if state == "lurk" or state == "reveal" or state == "dead":
		return
	var y := -89.0
	var rb := Rect2(-72, y, 16, 18)
	draw_rect(rb, Color(C_HEART, 0.9) if hud_hit > 0 and (hud_hit / 4) % 2 == 0 else Color(0.05, 0.05, 0.08, 0.85))
	draw_rect(rb, Color(0.89, 0.87, 0.81, 0.8), false, 1.0)
	var tex: Texture2D = room._rabbit_tex("up", "stand", room.state == "dead" or hud_hit > 0)
	draw_texture(tex, rb.position + Vector2(2, 1))
	for i in LIVES:
		_draw_heart(Vector2(-52 + i * 10, y + 6), i < lives)
	# a energia do Senzi: a barra grande, em três terços
	var bar := Rect2(-18, y + 4, 168, 10)
	draw_rect(bar.grow(1.0), Color(0.05, 0.05, 0.08, 0.85))
	var k := clampf(energy / ENERGY, 0.0, 1.0)
	var col := Color(1, 1, 1) if bar_hit > 0 and (bar_hit / 3) % 2 == 0 else C_ENERGY
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), col)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, 2)), col.lightened(0.35))
	for q in [1.0 / 3.0, 2.0 / 3.0]:
		draw_rect(Rect2(bar.position + Vector2(bar.size.x * q, 0), Vector2(1, bar.size.y)), Color(0.05, 0.05, 0.08, 0.9))
	draw_rect(bar.grow(1.0), Color(0.89, 0.87, 0.81, 0.8), false, 1.0)


func _draw_heart(q: Vector2, full: bool) -> void:
	var c := C_HEART if full else C_HEART_EMPTY
	draw_rect(Rect2(q + Vector2(1, 0), Vector2(2, 1)), c)
	draw_rect(Rect2(q + Vector2(4, 0), Vector2(2, 1)), c)
	draw_rect(Rect2(q + Vector2(0, 1), Vector2(7, 2)), c)
	draw_rect(Rect2(q + Vector2(1, 3), Vector2(5, 1)), c)
	draw_rect(Rect2(q + Vector2(2, 4), Vector2(3, 1)), c)
	draw_rect(Rect2(q + Vector2(3, 5), Vector2(1, 1)), c)

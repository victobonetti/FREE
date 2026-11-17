extends Node2D
## Boss 3: a mecha do Gatsby (GDD 8e, D79, D80). Ator da sala (campo "actors"): a sala chama
## step(room) a cada quadro, on_reset(room) quando reinicia e on_rotate(room, dir) quando gira.
##
## Abertura: a sala tem só o corpo inerte da mecha. O coelho anda um pouco, sem poder girar; o
## Gatsby chega na cápsula, pluga na mecha (a cápsula vira a cabeça dela) e a luta começa.
##
## Vidas: o coelho tem 3 corações (como no Jeffrey: `absorb_kill`, pisca imune). A mecha tem uma
## barra de energia; a cada terço perdido ela explode por dentro, se estraga um pouco e o Gatsby
## perde um coração (3). A energia só cai com:
##   - os próprios mísseis teleguiados, quando acertam a mecha;
##   - a investida, quando ela bate na parede sem ter pegado o coelho (fica atordoada).
##
## Ataques (a lista de cada fase em PLAN):
##   aim     miras nas paredes, no chão e no teto; depois do aviso, mísseis quase instantâneos saem
##           da mecha até cada mira e explodem num raio pequeno. Pegam quem estiver no caminho.
##   homing  mísseis lentos que perseguem o coelho; explodem no que tocarem (coelho, mecha, parede).
##   dash    aviso (a mecha se agacha e mira), depois a investida, corrigindo a rota até o coelho.
##   barrage miras e teleguiados ao mesmo tempo (última fase).
##
## O giro: a mecha se adapta à gravidade. Depois de um giro (do coelho ou do limitador) ela liga os
## propulsores, flutua na direção do coelho e desce devagar até o chão novo. A velocidade da
## investida e dos teleguiados é de TELA: o giro não a vira junto com a sala. Por isso um giro no
## meio da investida a faz perder o alvo e seguir reto até a parede: é a esquiva.
## Coordenadas em px da sala; `pos` é o centro da caixa de colisão (MW x MH, sempre em pé na tela).

const GatsbyScript := preload("res://scripts/boss_gatsby.gd")

const MW := 24
const MH := 30
const LIVES := 3                 # corações do coelho, só nesta sala
const HEARTS := 3                # corações do Gatsby: um por terço da barra
const ENERGY := 12               # barra da mecha (4 por terço)
const INVULN := 60
const INTRO_FREE := 150          # quadros para olhar a sala antes de o Gatsby chegar (1ª vez)
const INTRO_AGAIN := 30          # depois de perder: a cápsula chega logo
const ARRIVE := 70               # voo da cápsula até a mecha
const PLUG := 50                 # encaixe: faíscas, luzes acendem
const HEAD := Vector2(0, -17)    # centro da cúpula da cápsula, em relação a `pos` (em pé na tela)
const GRAV := 420.0
const FALL_MAX := 220.0
const FLOAT_FRAMES := 110        # quadros flutuando depois de um giro
const FLOAT_FALL := 16.0         # px/s: desce devagar com os propulsores
const FLOAT_SEEK := 30.0         # px/s: vai para o lado do coelho enquanto flutua
const WALK := 14.0
const IDLE := [80, 60, 45]       # quadros entre ataques, por fase
const PLAN := [
	["aim", "homing", "dash"],
	["homing", "aim", "dash", "homing", "dash"],
	["barrage", "dash", "homing", "dash", "aim"],
]
const AIM_COUNT := [4, 6, 8]
const AIM_WARN := [60, 52, 44]   # quadros de aviso antes do primeiro disparo
const AIM_GAP := 5               # quadros entre um disparo e o seguinte
const AIM_STEP := 12.0           # px por quadro: quase instantâneo
const AIM_RADIUS := 11.0
const AIM_SPACING := 28.0        # distância mínima entre duas miras
const HOM_COUNT := [3, 4, 5]
const HOM_SPEED := [34.0, 38.0, 42.0]
const HOM_TURN := 0.032          # rad por quadro
const HOM_LIFE := 540
const HOM_ARM := 36              # antes disto o míssil não acerta a própria mecha (está saindo dela)
const HOM_RADIUS := 10.0
const DASH_WARN := [54, 46, 38]
const DASH_SPEED := 240.0
const KEEP := [56.0, 96.0]     # distância que ela mantém do coelho, andando (perto: recua)
const DASH_COMMIT := 14         # quadros finais do aviso com a mira travada (a linha fica sólida)
const DASH_TURN := 0.06          # correção da rota por quadro, enquanto tem o alvo
const DASH_MAX := 120
const STUN := [80, 70, 60]
const BREAK_FRAMES := 100        # explosão de um terço: a mecha fica parada, faiscando
const DIE_FRAMES := 150

const C_HULL := GatsbyScript.C_HULL
const C_HULL_DARK := GatsbyScript.C_HULL_DARK
const C_HULL_LIGHT := GatsbyScript.C_HULL_LIGHT
const C_SEAM := GatsbyScript.C_SEAM
const C_RIVET := GatsbyScript.C_RIVET
const C_RUST := GatsbyScript.C_RUST
const C_FLAME := GatsbyScript.C_FLAME
const C_FLAME_CORE := GatsbyScript.C_FLAME_CORE
const C_HEART := Color("e0657c")
const C_HEART_EMPTY := Color(1, 1, 1, 0.18)
const C_AIM := Color("ff4d5e")
const C_FIRE := Color("ffb347")
const C_MISSILE := Color("e9e4d6")
const C_ENERGY := Color("f0a05a")
const C_LIGHTS := [Color("e0657c"), Color("ffe08a"), Color("9fd4ff")]

static var intro_seen := false


static func replay_state() -> Dictionary:
	return {"intro_seen": intro_seen}


static func apply_replay_state(d: Dictionary) -> void:
	intro_seen = bool(d.get("intro_seen", false))


var room
var rng := RandomNumberGenerator.new()
var puppet: Node2D          # o Gatsby na cápsula (boss_gatsby.gd, só o desenho)
var state := "inert"        # inert, arrive, plug, idle, aim, homing, dash_warn, dash, stun, break, dying, wreck
var t := 0
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var cap_pos := Vector2.ZERO # a cápsula, enquanto não está plugada
var cap_from := Vector2.ZERO
var energy := ENERGY
var hearts := HEARTS
var lives := LIVES
var plan_i := 0
var float_t := 0
var markers: Array = []     # {pos, n (normal, para dentro da sala), fire_at, fired}
var shots: Array = []       # mísseis da mira: {pos, to}
var homers: Array = []      # teleguiados: {pos, vel, age}
var blasts: Array = []      # {pos, t, r}
var locked := false         # a investida ainda corrige a rota até o coelho
var dash_dir := Vector2.LEFT  # mira travada no fim do aviso (direção de tela)
var committed := false
var lost := false           # girou depois da mira travada: a investida sai sem alvo
var dash_hit := false       # a investida pegou o coelho (então a batida na parede não a fere)
var launched := 0           # teleguiados lançados neste ataque
var flash := 0              # pisca branco ao levar dano
var hud_hit := 0
var bar_hit := 0
var anim := 0
var trail: Array = []       # rastro da investida
var pod_side := 1
var last_floor := true


func _init() -> void:
	puppet = GatsbyScript.new()
	puppet.phase = "puppet"
	puppet.show_behind_parent = true   # o corpo da mecha cobre o casco: só a cúpula aparece
	add_child(puppet)


func on_reset(r) -> void:
	room = r
	rng.seed = 20261117
	puppet.room = r
	markers.clear()
	shots.clear()
	homers.clear()
	blasts.clear()
	trail.clear()
	vel = Vector2.ZERO
	float_t = 0
	flash = 0
	if hearts <= 0 and state == "wreck":
		# já vencida: a sala só reinicia se o jogador apertar R
		pos = Vector2(room.pw * 0.62, _bounds().end.y)
		room.door_unlocked = true
		return
	lives = LIVES
	hearts = HEARTS
	energy = ENERGY
	plan_i = 0
	pos = Vector2(room.pw * 0.62, _bounds().end.y)
	last_floor = true
	cap_from = Vector2(pos.x - 40.0, -40.0)
	cap_pos = cap_from
	room.allow_rotate = false   # a abertura não deixa girar
	state = "inert"
	t = 0
	puppet.mood = "bored"
	puppet.visible = true


## A sala ia matar o coelho: aqui ele perde um coração e pisca, imune. No terceiro, morre de
## verdade e a luta recomeça.
func absorb_kill(r) -> bool:
	lives -= 1
	hud_hit = 50
	puppet.mood = "amused"
	if lives <= 0:
		return false
	r.invuln = INVULN
	r.shake = maxf(r.shake, 3.0)
	r.sfx.emit("death")
	var c := Vector2(r.rabbit.pos) + Vector2(6, 6)
	for i in 8:
		var a := randf() * TAU
		r.particles.append({
			"pos": c, "vel": Vector2(cos(a), sin(a)) * randf_range(30.0, 80.0),
			"life": randi_range(8, 14), "col": C_HEART, "grav": 120.0,
		})
	return true


func on_rotate(r, dir: int) -> void:
	pos = r._rot_point(pos, dir)
	cap_pos = r._rot_point(cap_pos, dir)
	cap_from = r._rot_point(cap_from, dir)
	for m in markers:
		m["pos"] = r._rot_point(m["pos"], dir)
		m["n"] = Vector2(-m["n"].y, m["n"].x) if dir > 0 else Vector2(m["n"].y, -m["n"].x)
	for s in shots:
		s["pos"] = r._rot_point(s["pos"], dir)
		s["to"] = r._rot_point(s["to"], dir)
	# os teleguiados mudam de lugar com a sala, mas a velocidade é de tela: o giro os desvia
	for h in homers:
		h["pos"] = r._rot_point(h["pos"], dir)
	for b in blasts:
		b["pos"] = r._rot_point(b["pos"], dir)
	trail.clear()
	if state == "dash":
		locked = false   # perdeu o alvo: segue reto (na tela) até a parede
	elif state == "dash_warn" and committed:
		lost = true      # a mira já estava travada: sai reto, sem corrigir
	elif state != "inert" and state != "wreck" and state != "dying":
		vel = Vector2.ZERO
		float_t = FLOAT_FRAMES   # liga os propulsores e se ajeita na gravidade nova


# ---------------------------------------------------------------- medidas

func _bounds() -> Rect2:
	var hw := MW / 2.0
	var hh := MH / 2.0
	return Rect2(8 + hw, 8 + hh, room.pw - 16 - MW, room.ph - 16 - MH)


func body_rect() -> Rect2:
	return Rect2(pos - Vector2(MW, MH) / 2.0, Vector2(MW, MH))


func _rabbit_c() -> Vector2:
	return Vector2(room.rabbit.pos) + Vector2(6, 6)


func _phase() -> int:
	return clampi(HEARTS - hearts, 0, 2)


func _on_floor() -> bool:
	return pos.y >= _bounds().end.y - 0.5


func _pod() -> Vector2:
	pod_side = -pod_side
	return pos + Vector2(14 * pod_side, -16)


func fighting() -> bool:
	return state in ["idle", "aim", "homing", "dash_warn", "dash", "stun", "break"]


# ---------------------------------------------------------------- simulação

func step(r) -> void:
	room = r
	anim += 1
	flash = maxi(flash - 1, 0)
	bar_hit = maxi(bar_hit - 1, 0)
	if room.state == "play":
		room.invuln = maxi(room.invuln - 1, 0)
	for b in blasts:
		b["t"] += 1
	blasts = blasts.filter(func(b): return b["t"] < 16)
	if room.state != "play":
		return
	t += 1
	_smoke()
	match state:
		"inert":
			if t >= (INTRO_AGAIN if intro_seen else INTRO_FREE):
				state = "arrive"
				t = 0
				puppet.mood = "smug"
				room.sfx.emit("gatsby_dash")
		"arrive":
			var k := clampf(float(t) / ARRIVE, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			var to := pos + HEAD
			cap_pos = cap_from.lerp(to, k) + Vector2(0, -sin(k * PI) * 18.0)
			if t >= ARRIVE:
				cap_pos = to
				state = "plug"
				t = 0
				room.sfx.emit("hatch")
				room.shake = maxf(room.shake, 2.0)
				_sparks(pos + Vector2(0, -12), 10)
		"plug":
			if t == 20:
				room.sfx.emit("charge")
			if t >= PLUG:
				intro_seen = true
				room.allow_rotate = bool(room.def.get("rotate", true))
				room.impact.emit(1.4)
				room.shake = maxf(room.shake, 3.0)
				room.music_override = str(room.def.get("boss_music", ""))
				if room.music_override != "":
					room.music_request.emit(room.music_override)
				puppet.mood = "smug"
				_go_idle()
		"idle":
			_body(true)
			# na primeira fase, um ataque por vez: espera os teleguiados acabarem
			var busy: bool = _phase() == 0 and not homers.is_empty()
			if t >= IDLE[_phase()] and not busy:
				_next_attack()
		"aim":
			_body(false)
			for m in markers:
				if not m["fired"] and t >= m["fire_at"]:
					m["fired"] = true
					shots.append({"pos": _pod(), "to": m["pos"] + m["n"] * 3.0})
					room.sfx.emit("missile")
			if t > 20 and shots.is_empty() and markers.all(func(m): return m["fired"]):
				markers.clear()
				_go_idle()
		"homing":
			_body(false)
			if t >= 20 and (t - 20) % 10 == 0 and launched < HOM_COUNT[_phase()]:
				_launch_homer()
			if launched >= HOM_COUNT[_phase()] and t > 40 + 10 * HOM_COUNT[_phase()]:
				_go_idle()
		"dash_warn":
			# agacha, liga os propulsores e mira; ainda se ajeita se estiver flutuando
			_body(false)
			puppet.mood = "furious"
			if not committed and t >= DASH_WARN[_phase()] - DASH_COMMIT:
				committed = true
				var d := _rabbit_c() - pos
				dash_dir = d.normalized() if d.length() > 1.0 else Vector2.LEFT
				room.sfx.emit("mover_warn")
			if t >= DASH_WARN[_phase()]:
				vel = dash_dir * DASH_SPEED
				locked = not lost
				dash_hit = false
				float_t = 0
				state = "dash"
				t = 0
				room.sfx.emit("gatsby_dash")
		"dash":
			_dash()
		"stun":
			_body(false)
			if t % 6 == 0:
				_sparks(pos + Vector2(rng.randf_range(-10, 10), rng.randf_range(-12, 6)), 2)
			if t >= STUN[_phase()]:
				_go_idle()
		"break":
			_body(false)
			if t % 9 == 0 and t < BREAK_FRAMES - 20:
				_boom(pos + Vector2(rng.randf_range(-12, 12), rng.randf_range(-14, 10)), 8.0, false)
			if t >= BREAK_FRAMES:
				plan_i = 0
				puppet.mood = "furious"
				_go_idle()
		"dying":
			_body(false)
			if t % 7 == 0:
				_boom(pos + Vector2(rng.randf_range(-14, 14), rng.randf_range(-16, 12)), 9.0, false)
			cap_pos = pos + HEAD
			if t >= DIE_FRAMES:
				state = "wreck"
				t = 0
				cap_from = pos + HEAD
				room.door_unlocked = true
				room.sfx.emit("gate_open")
				_boom(pos, 16.0, false)
				puppet.mood = "panic"
		"wreck":
			_body(false)
			# o Gatsby ejeta a cápsula e foge pelo alto
			cap_pos = cap_from + Vector2(sin(t * 0.3) * 3.0, -t * t * 0.02 - t * 0.6)
			if cap_pos.y < -60.0:
				puppet.visible = false
	anim_draw()
	if room.state != "play":
		return
	_update_shots()
	if room.state != "play":
		return
	_update_homers()


func _go_idle() -> void:
	state = "idle"
	t = 0
	if puppet.mood != "amused":
		puppet.mood = "smug"


func _next_attack() -> void:
	var plan: Array = PLAN[_phase()]
	var a: String = plan[plan_i % plan.size()]
	plan_i += 1
	t = 0
	match a:
		"aim":
			state = "aim"
			_place_markers(AIM_COUNT[_phase()])
			room.sfx.emit("lock_on")
		"homing":
			state = "homing"
			launched = 0
			puppet.mood = "smug"
		"barrage":
			state = "aim"
			_place_markers(AIM_COUNT[_phase()])
			room.sfx.emit("lock_on")
			for i in HOM_COUNT[_phase()] - 2:
				_launch_homer()
		"dash":
			state = "dash_warn"
			committed = false
			lost = false
			room.sfx.emit("crusher_wake")


## Há espaço para recuar (para longe do coelho, que está a `dx`)?
func _room_to_back(dx: float) -> bool:
	var b := _bounds()
	return pos.x > b.position.x + 4.0 if dx > 0.0 else pos.x < b.end.x - 4.0


## Corpo fora da investida: gravidade, ou flutuando depois de um giro. `walk`: anda até o coelho.
func _body(walk: bool) -> void:
	var b := _bounds()
	if float_t > 0:
		float_t -= 1
		vel.y = move_toward(vel.y, FLOAT_FALL, 6.0)
		var dx := _rabbit_c().x - pos.x
		var want := signf(dx) * FLOAT_SEEK if absf(dx) > 6.0 else 0.0
		vel.x = move_toward(vel.x, want, 3.0)
		if anim % 3 == 0:
			_thrust_puff()
	else:
		vel.y = minf(vel.y + GRAV / 60.0, FALL_MAX)
		if _on_floor() and walk and state == "idle":
			var dx := _rabbit_c().x - pos.x
			if absf(dx) > KEEP[1]:
				vel.x = signf(dx) * WALK
			elif absf(dx) < KEEP[0] and _room_to_back(dx):
				vel.x = -signf(dx) * WALK * 1.5
			else:
				vel.x = 0.0
		elif _on_floor():
			vel.x = move_toward(vel.x, 0.0, 6.0)
	var fall := vel.y
	pos += vel / 60.0
	pos.x = clampf(pos.x, b.position.x, b.end.x)
	pos.y = clampf(pos.y, b.position.y, b.end.y)
	var on := _on_floor()
	if on:
		vel.y = 0.0
		if not last_floor and fall > 90.0:
			room.impact.emit(minf(fall / 120.0, 2.0))
			room.shake = maxf(room.shake, 2.0)
			room.sfx.emit("crunch")
	last_floor = on


func _dash() -> void:
	puppet.mood = "furious"
	var target := _rabbit_c()
	var d := target - pos
	if locked:
		if d.dot(vel) <= 0.0:
			locked = false   # passou do coelho: não volta
		else:
			var diff := wrapf(d.angle() - vel.angle(), -PI, PI)
			vel = Vector2.from_angle(vel.angle() + clampf(diff, -DASH_TURN, DASH_TURN)) * DASH_SPEED
	if t % 2 == 0:
		trail.append(pos)
		if trail.size() > 4:
			trail.pop_front()
	var b := _bounds()
	var n := 4
	for i in n:
		pos += vel / 60.0 / n
		if not dash_hit and room.invuln == 0 and room.overlaps(Rect2i(body_rect()), room.rabbit.rect):
			dash_hit = true
			room.kill()
			if room.state != "play":
				return
		# passou de um limite: de frente, é a batida; de raspão (rente ao chão), desliza
		var nrm := Vector2.ZERO
		if pos.x < b.position.x:
			nrm.x = 1.0
		elif pos.x > b.end.x:
			nrm.x = -1.0
		if pos.y < b.position.y:
			nrm.y = 1.0
		elif pos.y > b.end.y:
			nrm.y = -1.0
		if nrm != Vector2.ZERO:
			pos.x = clampf(pos.x, b.position.x, b.end.x)
			pos.y = clampf(pos.y, b.position.y, b.end.y)
			var into := -vel.dot(nrm.normalized()) / DASH_SPEED
			if into > 0.5:
				_slam()
				return
			vel -= nrm * vel.dot(nrm)
			vel = (vel.normalized() if vel.length() > 1.0 else Vector2(-nrm.y, nrm.x)) * DASH_SPEED
	if t >= DASH_MAX:
		vel = Vector2.ZERO
		_go_idle()


## Bateu na parede: impacto enorme. Sem ter pegado o coelho, leva dano e fica atordoada.
func _slam() -> void:
	var dir := vel.normalized()
	vel = Vector2.ZERO
	trail.clear()
	room.shake = 6.0
	room.impact.emit(2.5)
	room.sfx.emit("slam")
	var hit_pt := pos + Vector2(dir.x * MW / 2.0, dir.y * MH / 2.0)
	for i in 18:
		var a := dir.angle() + PI + randf_range(-1.2, 1.2)
		room.particles.append({
			"pos": hit_pt, "vel": Vector2.from_angle(a) * randf_range(40.0, 140.0),
			"life": randi_range(10, 22), "col": C_RIVET if i % 3 else C_FIRE, "grav": 160.0,
		})
	state = "stun"
	t = 0
	puppet.mood = "panic"
	if not dash_hit:
		_damage(1)


func _damage(n: int) -> void:
	if not fighting():
		return
	energy = maxi(energy - n, 0)
	flash = 20
	bar_hit = 20
	room.sfx.emit("sensor_on")
	var per := ENERGY / HEARTS
	var left := ceili(float(energy) / per)
	if left < hearts:
		hearts = left
		if hearts <= 0:
			_die()
		else:
			_break()
	elif state != "stun":
		puppet.mood = "annoyed"


## Um terço da barra: explode por dentro, se estraga e o Gatsby perde um coração.
func _break() -> void:
	_clear_projectiles()
	state = "break"
	t = 0
	float_t = 0
	puppet.mood = "panic"
	room.shake = 7.0
	room.impact.emit(2.5)
	room.sfx.emit("steam_burst")
	_boom(pos, 18.0, false)
	for i in 24:
		var a := randf() * TAU
		room.particles.append({
			"pos": pos, "vel": Vector2(cos(a), sin(a)) * randf_range(40.0, 150.0),
			"life": randi_range(16, 30), "col": C_HULL_LIGHT if i % 3 else C_FIRE, "grav": 140.0,
		})


func _die() -> void:
	_clear_projectiles()
	state = "dying"
	t = 0
	float_t = 0
	puppet.mood = "panic"
	room.shake = 8.0
	room.impact.emit(2.5)
	room.sfx.emit("steam_burst")


func _clear_projectiles() -> void:
	for h in homers:
		_boom(h["pos"], 6.0, false)
	homers.clear()
	shots.clear()
	markers.clear()


# ---------------------------------------------------------------- miras

## Miras no contorno da sala (chão, paredes, teto): a primeira na superfície mais perto do coelho.
func _place_markers(count: int) -> void:
	markers.clear()
	var inner := Rect2(8, 8, room.pw - 16, room.ph - 16)
	var cands: Array = []
	var x := inner.position.x + 12.0
	while x <= inner.end.x - 12.0:
		cands.append([Vector2(x, inner.end.y), Vector2.UP])
		cands.append([Vector2(x, inner.position.y), Vector2.DOWN])
		x += 8.0
	var y := inner.position.y + 12.0
	while y <= inner.end.y - 12.0:
		cands.append([Vector2(inner.position.x, y), Vector2.RIGHT])
		cands.append([Vector2(inner.end.x, y), Vector2.LEFT])
		y += 8.0
	var rc := _rabbit_c()
	var best: Array = cands[0]
	for c in cands:
		if c[0].distance_to(rc) < best[0].distance_to(rc):
			best = c
	var picked: Array = [best]
	var tries := 0
	while picked.size() < count and tries < 400:
		tries += 1
		var c: Array = cands[rng.randi() % cands.size()]
		var ok := true
		for p in picked:
			if p[0].distance_to(c[0]) < AIM_SPACING:
				ok = false
				break
		if ok:
			picked.append(c)
	for i in picked.size():
		markers.append({"pos": picked[i][0], "n": picked[i][1], "fire_at": AIM_WARN[_phase()] + i * AIM_GAP, "fired": false})


func _update_shots() -> void:
	var keep: Array = []
	for s in shots:
		var done := false
		for k in 3:
			var d: Vector2 = s["to"] - s["pos"]
			var stp := AIM_STEP / 3.0
			if d.length() <= stp:
				s["pos"] = s["to"]
				done = true
				break
			s["pos"] += d.normalized() * stp
			if Rect2(room.rabbit.rect).grow(1.0).has_point(s["pos"]):
				done = true
				break
		if done:
			_boom(s["pos"], AIM_RADIUS, true)
			if room.state != "play":
				return
		else:
			keep.append(s)
	shots = keep


# ---------------------------------------------------------------- teleguiados

func _launch_homer() -> void:
	launched += 1
	var p := _pod()
	var a := -PI / 2.0 + rng.randf_range(-0.6, 0.6) + 0.35 * pod_side
	homers.append({"pos": p, "vel": Vector2.from_angle(a) * 70.0, "age": 0})
	room.sfx.emit("homer")


func _update_homers() -> void:
	var inner := Rect2(8, 8, room.pw - 16, room.ph - 16).grow(-2.0)
	var cruise: float = HOM_SPEED[_phase()]
	var list := homers.duplicate()
	homers.clear()
	var keep: Array = []
	for h in list:
		h["age"] += 1
		var d: Vector2 = _rabbit_c() - h["pos"]
		var v: Vector2 = h["vel"]
		var spd := move_toward(v.length(), cruise, 1.2)
		var ang := v.angle()
		if h["age"] > 16:
			ang += clampf(wrapf(d.angle() - ang, -PI, PI), -HOM_TURN, HOM_TURN)
		h["vel"] = Vector2.from_angle(ang) * spd
		h["pos"] += h["vel"] / 60.0
		var p: Vector2 = h["pos"]
		if h["age"] % 4 == 0:
			room.particles.append({"pos": p - h["vel"].normalized() * 3.0, "vel": Vector2.ZERO,
				"life": 10, "col": Color(0.75, 0.75, 0.8, 0.8), "grav": -6.0})
		if Rect2(room.rabbit.rect).grow(2.0).has_point(p):
			_boom(p, HOM_RADIUS, true)
		elif h["age"] > HOM_ARM and fighting() and body_rect().grow(1.0).has_point(p):
			_boom(p, HOM_RADIUS, false)
			_damage(1)
			if not fighting():
				return   # explodiu um terço ou morreu: os outros mísseis já foram limpos
		elif not inner.has_point(p) or h["age"] > HOM_LIFE:
			_boom(p, HOM_RADIUS, true)
		else:
			keep.append(h)
		if room.state != "play":
			return
	homers = keep + homers   # os lançados durante a volta (nenhum, hoje) ficam também


## Explosão: fere o coelho se o raio alcançar (`hurt`).
func _boom(p: Vector2, radius: float, hurt: bool) -> void:
	blasts.append({"pos": p, "t": 0, "r": radius})
	room.shake = maxf(room.shake, 2.5)
	room.sfx.emit("blast")
	for i in 8:
		var a := randf() * TAU
		room.particles.append({
			"pos": p, "vel": Vector2(cos(a), sin(a)) * randf_range(30.0, 100.0),
			"life": randi_range(6, 14), "col": C_FIRE if i % 2 == 0 else C_RIVET, "grav": 40.0,
		})
	if hurt and blast_hits(p, Rect2(room.rabbit.rect), radius):
		room.kill()


static func blast_hits(p: Vector2, r: Rect2, radius: float) -> bool:
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return q.distance_to(p) <= radius


# ---------------------------------------------------------------- efeitos

func _sparks(p: Vector2, n: int) -> void:
	for i in n:
		room.particles.append({
			"pos": p, "vel": Vector2(randf_range(-60.0, 60.0), randf_range(-90.0, -10.0)),
			"life": randi_range(8, 16), "col": C_FLAME_CORE, "grav": 260.0,
		})


func _thrust_puff() -> void:
	for s in [-1, 1]:
		room.particles.append({
			"pos": pos + Vector2(14.5 * s, 7), "vel": Vector2(randf_range(-6.0, 6.0), 40.0),
			"life": randi_range(6, 10), "col": C_FLAME if randf() < 0.5 else Color(0.6, 0.6, 0.65), "grav": -20.0,
		})


## Fumaça da mecha estragada (mais a cada terço perdido).
func _smoke() -> void:
	var dmg := HEARTS - hearts
	if dmg <= 0 or state == "inert":
		return
	var every := 14 if dmg == 1 else 7
	if anim % every == 0:
		room.particles.append({
			"pos": pos + Vector2(rng.randf_range(-10, 10), -8), "vel": Vector2(randf_range(-5.0, 5.0), -22.0),
			"life": randi_range(18, 30), "col": Color(0.35, 0.35, 0.4, 0.7), "grav": -10.0,
		})


# ---------------------------------------------------------------- desenho

func _process(_delta: float) -> void:
	anim_draw()
	queue_redraw()


## A cápsula acompanha a mecha na tela (também durante a animação do giro, quando step não roda).
func anim_draw() -> void:
	if room == null:
		return
	puppet.anim = anim
	var plugged := state in ["plug", "idle", "aim", "homing", "dash_warn", "dash", "stun", "break", "dying"]
	puppet.pos = (pos + _lift() + HEAD.rotated(-room.view_angle)) if plugged else cap_pos
	puppet.jolt = 20 if state == "break" or state == "stun" else 0


## Deslocamento do desenho: agacha no aviso, treme atordoada.
func _lift() -> Vector2:
	if state == "dash_warn":
		return Vector2(0, 2)
	if state == "stun" or state == "break" or state == "dying":
		return Vector2(float((anim / 2) % 2) - 0.5, 0)
	return Vector2.ZERO


func _draw() -> void:
	if room == null:
		return
	var base := Transform2D(room.view_angle, Vector2.ZERO) * Transform2D(0.0, -room.cam.round())
	draw_set_transform_matrix(base)
	for m in markers:
		_draw_marker(m)
	for s in shots:
		var p: Vector2 = s["pos"]
		var d: Vector2 = (s["to"] - p).normalized()
		draw_line(p - d * 16.0, p, Color(C_FIRE, 0.5), 2.0)
		draw_line(p - d * 7.0, p, Color(1, 1, 0.85), 1.0)
	for h in homers:
		_draw_homer(base, h)
	draw_set_transform_matrix(base)
	for b in blasts:
		var k := float(b["t"]) / 16.0
		var p: Vector2 = b["pos"].round()
		var rr: float = b["r"]
		draw_circle(p, rr * minf(1.0, 0.4 + k * 1.5), Color(C_FIRE, 0.55 * (1.0 - k)))
		draw_circle(p, rr * 0.6 * (1.0 - k), Color(1, 1, 1, 0.9 * (1.0 - k)))
		draw_arc(p, rr, 0.0, TAU, 20, Color(C_FIRE, 1.0 - k), 1.0)
	# aviso da investida: a linha até o coelho pisca
	if state == "dash_warn" and (committed or (t / 4) % 2 == 0):
		var a := pos
		var b := a + dash_dir * _ray_len(a, dash_dir) if committed else _rabbit_c()
		var n := int(a.distance_to(b) / 6.0)
		for i in n:
			if i % 2 == 0 or committed:
				draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), Color(C_AIM, 0.95 if committed else 0.7), 1.0)
	# rastro
	for i in trail.size():
		var tp: Vector2 = trail[i]
		draw_set_transform_matrix(base * Transform2D(-room.view_angle, tp.round()))
		draw_rect(Rect2(-MW / 2.0, -MH / 2.0, MW, MH), Color(C_HULL_LIGHT, 0.12 + 0.08 * i), false, 1.0)
	draw_set_transform_matrix(base * Transform2D(-room.view_angle, (pos + _lift()).round()))
	_draw_mecha()
	if fighting() or state == "dying":
		_draw_gatsby_hearts()
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_hud()


## Distância de `a` até a parede, na direção `d` (para a linha da mira travada).
func _ray_len(a: Vector2, d: Vector2) -> float:
	var inner := Rect2(8, 8, room.pw - 16, room.ph - 16)
	var best := 400.0
	if d.x > 0.001:
		best = minf(best, (inner.end.x - a.x) / d.x)
	elif d.x < -0.001:
		best = minf(best, (inner.position.x - a.x) / d.x)
	if d.y > 0.001:
		best = minf(best, (inner.end.y - a.y) / d.y)
	elif d.y < -0.001:
		best = minf(best, (inner.position.y - a.y) / d.y)
	return maxf(best, 0.0)


func _draw_marker(m: Dictionary) -> void:
	var p: Vector2 = (m["pos"] + m["n"] * 4.0).round()
	var left: float = float(m["fire_at"] - t) / float(AIM_WARN[_phase()])
	if m["fired"]:
		return
	var blink := (anim / 3) % 2 == 0 or left > 0.5
	var col := Color(C_AIM, 0.95 if blink else 0.5)
	draw_arc(p, 4.0, 0.0, TAU, 12, col, 1.0)
	draw_line(p + Vector2(-7, 0), p + Vector2(-2, 0), col, 1.0)
	draw_line(p + Vector2(2, 0), p + Vector2(7, 0), col, 1.0)
	draw_line(p + Vector2(0, -7), p + Vector2(0, -2), col, 1.0)
	draw_line(p + Vector2(0, 2), p + Vector2(0, 7), col, 1.0)
	draw_arc(p, 4.0 + 8.0 * clampf(left, 0.0, 1.0), 0.0, TAU, 16, Color(C_AIM, 0.45), 1.0)
	draw_rect(Rect2(p - Vector2(0.5, 0.5), Vector2(1, 1)), col)


func _draw_homer(base: Transform2D, h: Dictionary) -> void:
	var v: Vector2 = h["vel"]
	draw_set_transform_matrix(base * Transform2D(v.angle(), h["pos"].round()))
	draw_rect(Rect2(-4, -1, 6, 3), C_MISSILE)
	draw_rect(Rect2(2, -1, 2, 3), C_AIM)
	draw_rect(Rect2(-5, -2, 2, 1), C_RIVET)
	draw_rect(Rect2(-5, 2, 2, 1), C_RIVET)
	var fl := 2.0 + float((anim / 2) % 2)
	draw_rect(Rect2(-5 - fl, 0, fl, 1), C_FLAME)
	# piscar para mostrar que está armado (já acerta a mecha)
	if h["age"] > HOM_ARM and (anim / 6) % 2 == 0:
		draw_rect(Rect2(0, -1, 1, 1), Color(1, 1, 1))


## A mecha em pé na tela. Origem no centro da caixa (24 x 30); os pés em y = 15.
func _draw_mecha() -> void:
	var dmg := HEARTS - hearts
	var on := state != "inert" and state != "arrive" and state != "wreck"
	var thr := float_t > 0 or state == "dash" or state == "dash_warn"
	# compartimentos de mísseis, atrás dos ombros
	for s in [-1, 1]:
		var px := -18 if s < 0 else 12
		draw_rect(Rect2(px, -18, 6, 17), C_HULL_DARK)
		draw_rect(Rect2(px, -18, 6, 1), C_HULL_LIGHT)
		draw_rect(Rect2(px, -1, 6, 1), C_SEAM)
		for k in 3:
			var broken: bool = dmg >= 1 and s < 0 and k == 0
			var c: Color = C_SEAM if broken else (C_AIM if on else C_RUST)
			draw_rect(Rect2(px + 2, -16 + k * 5, 2, 3), c)
			draw_rect(Rect2(px + 2, -16 + k * 5, 2, 1), Color(1, 1, 1, 0.35) if on and not broken else C_SEAM)
	# pernas e pés
	for s in [-1, 1]:
		var lx := -10 if s < 0 else 4
		draw_rect(Rect2(lx, 4, 6, 9), C_HULL)
		draw_rect(Rect2(lx, 4, 6, 1), C_HULL_LIGHT)
		draw_rect(Rect2(lx - 1, 12, 8, 3), C_HULL_DARK)
		draw_rect(Rect2(lx + 1, 8, 1, 1), C_RIVET)
		draw_rect(Rect2(lx + 4, 8, 1, 1), C_RIVET)
	# quadril e a placa do meio (cobre a chama da cápsula)
	draw_rect(Rect2(-8, 2, 16, 4), C_HULL_DARK)
	draw_rect(Rect2(-4, 6, 8, 5), C_HULL_DARK)
	draw_rect(Rect2(-4, 6, 8, 1), C_SEAM)
	# tronco: chapas remendadas
	draw_rect(Rect2(-12, -11, 24, 14), C_HULL)
	draw_rect(Rect2(-12, -11, 24, 2), C_HULL_LIGHT)
	draw_rect(Rect2(-12, -2, 24, 1), C_SEAM)
	draw_rect(Rect2(-6, -9, 1, 7), C_SEAM)
	draw_rect(Rect2(5, -9, 1, 7), C_SEAM)
	for q in [Vector2(-11, -8), Vector2(10, -8), Vector2(-11, 1), Vector2(10, 1)]:
		draw_rect(Rect2(q, Vector2(1, 1)), C_RIVET)
	# painel do peito com luzes
	draw_rect(Rect2(-4, -8, 8, 6), C_SEAM)
	for i in 3:
		var lc: Color = C_LIGHTS[i]
		var lit := on and ((anim / 10 + i) % 3 != 0 or state == "dash_warn")
		draw_rect(Rect2(-3 + i * 2 + (i / 2), -7, 2, 2), lc if lit else Color(lc, 0.2))
	draw_rect(Rect2(-3, -4, 6, 1), C_ENERGY if on else C_RUST)
	# encaixe da cápsula no alto
	draw_rect(Rect2(-8, -13, 16, 2), C_SEAM)
	draw_rect(Rect2(-7, -13, 2, 1), C_RIVET)
	draw_rect(Rect2(5, -13, 2, 1), C_RIVET)
	# braços com propulsor na mão
	for s in [-1, 1]:
		var ax := -17 if s < 0 else 13
		draw_rect(Rect2(ax, -9, 4, 12), C_HULL_LIGHT)
		draw_rect(Rect2(ax, -9, 4, 1), C_RIVET)
		draw_rect(Rect2(ax, 3, 4, 3), C_HULL_DARK)
		if thr and on:
			var fl := 4.0 + float((anim / 2) % 3) * 2.0
			var cx := ax + 2.0
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 2, 6), Vector2(cx, 6 + fl), Vector2(cx + 2, 6)]), C_FLAME)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 1, 6), Vector2(cx, 6 + fl * 0.5), Vector2(cx + 1, 6)]), C_FLAME_CORE)
	# estragos
	if dmg >= 1:
		draw_line(Vector2(-10, -10), Vector2(-7, -5), C_SEAM, 1.0)
		draw_line(Vector2(-7, -5), Vector2(-9, -2), C_SEAM, 1.0)
		draw_rect(Rect2(7, -1, 4, 3), C_RUST)
	if dmg >= 2:
		draw_rect(Rect2(6, -9, 5, 6), Color("120f0c"))       # chapa arrancada: fios à mostra
		draw_line(Vector2(7, -8), Vector2(9, -5), C_AIM, 1.0)
		draw_line(Vector2(9, -8), Vector2(8, -4), C_LIGHTS[1], 1.0)
		if (anim / 4) % 5 == 0:
			draw_rect(Rect2(8, -6, 1, 1), C_FLAME_CORE)
	if state == "wreck":
		draw_rect(Rect2(-12, -11, 24, 14), Color(0, 0, 0, 0.35))
	elif state == "inert":
		draw_rect(Rect2(-12, -11, 24, 14), Color(0, 0, 0, 0.25))
	# pisca branco ao levar dano
	if flash > 0 and (flash / 3) % 2 == 0:
		draw_rect(Rect2(-12, -11, 24, 26), Color(1, 1, 1, 0.55))


## Os corações do Gatsby, flutuando acima da cápsula.
func _draw_gatsby_hearts() -> void:
	for i in HEARTS:
		_draw_heart(Vector2(-13 + i * 9, -42), i < hearts)


func _draw_hud() -> void:
	if state == "inert" or state == "arrive":
		return
	var y := -89.0
	# coelho: retrato e corações (como no Jeffrey)
	var rb := Rect2(-72, y, 16, 18)
	_draw_frame(rb, hud_hit > 0 and (hud_hit / 4) % 2 == 0)
	var tex: Texture2D = room._rabbit_tex("up", "stand", room.state == "dead" or hud_hit > 0)
	draw_texture(tex, rb.position + Vector2(2, 1))
	for i in LIVES:
		_draw_heart(Vector2(-52 + i * 10, y + 6), i < lives)
	# barra de energia da mecha, com as marcas dos terços
	var bar := Rect2(-8, y + 5, 80, 6)
	draw_rect(bar.grow(1.0), Color(0.05, 0.05, 0.08, 0.85))
	var k := float(energy) / ENERGY
	var col := Color(1, 1, 1) if bar_hit > 0 and (bar_hit / 3) % 2 == 0 else C_ENERGY
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), col)
	for i in range(1, HEARTS):
		var x := bar.position.x + bar.size.x * float(i) / HEARTS
		draw_rect(Rect2(x, bar.position.y - 1, 1, bar.size.y + 2), Color(0.89, 0.87, 0.81, 0.8))
	draw_rect(bar.grow(1.0), Color(0.89, 0.87, 0.81, 0.8), false, 1.0)


func _draw_frame(r: Rect2, lit: bool) -> void:
	draw_rect(r, Color(C_HEART, 0.9) if lit else Color(0.05, 0.05, 0.08, 0.85))
	draw_rect(r, Color(0.89, 0.87, 0.81, 0.8), false, 1.0)


func _draw_heart(q: Vector2, full: bool) -> void:
	var c := C_HEART if full else C_HEART_EMPTY
	draw_rect(Rect2(q + Vector2(1, 0), Vector2(2, 1)), c)
	draw_rect(Rect2(q + Vector2(4, 0), Vector2(2, 1)), c)
	draw_rect(Rect2(q + Vector2(0, 1), Vector2(7, 2)), c)
	draw_rect(Rect2(q + Vector2(1, 3), Vector2(5, 1)), c)
	draw_rect(Rect2(q + Vector2(2, 4), Vector2(3, 1)), c)
	draw_rect(Rect2(q + Vector2(3, 5), Vector2(1, 1)), c)

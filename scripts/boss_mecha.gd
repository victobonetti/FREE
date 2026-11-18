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

const MW := 40                   # caixa de colisão: o corpo E a cúpula (depois da fusão são uma coisa só)
const MH := 52
const LIVES := 3                 # corações do coelho, só nesta sala
const HEARTS := 3                # corações do Gatsby: um por terço da barra
const ENERGY := 24               # barra da mecha (8 por terço; D102: era 12)
const INVULN := 60
const INTRO_FREE := 150          # quadros para olhar a sala antes de o Gatsby chegar (1ª vez)
const INTRO_AGAIN := 30          # depois de perder: a cápsula chega logo
const ARRIVE := 70               # voo da cápsula até a mecha
const PLUG := 84                 # a fusão: tranco, cabos acendem, luzes do peito uma a uma, motores
const HEAD := Vector2(0, -13)    # centro da cúpula da cápsula, em relação a `pos` (em pé na tela)
const FEET := 26.0               # os pés, em relação a `pos`: o corpo se inclina em torno deles
const GRAV := 420.0
const FALL_MAX := 220.0
const FLOAT_FRAMES := 110        # quadros flutuando depois de um giro
const FLOAT_FALL := 16.0         # px/s: desce devagar com os propulsores
const FLOAT_SEEK := 30.0         # px/s: vai para o lado do coelho enquanto flutua
# A queda (D103): no fim da flutuação, os propulsores falham (aviso) e desligam; ela despenca e o
# impacto solta duas ondas de choque pelo chão. Fere quem está embaixo dela ou no chão onde a onda
# passa (pulando, escapa); no máximo um coração por queda.
const CUT_WARN := 24             # quadros finais da flutuação com os propulsores engasgando
const DROP_SPEED := 240.0        # px/s: velocidade inicial ao desligar
const DROP_MAX := 460.0          # px/s: a queda é bem mais rápida que a gravidade normal
const WAVE_SPEED := 130.0        # onda de choque correndo pelo chão (px/s)
const WAVE_LIFE := 18            # curta: some a uns 40 px da mecha (D104; era 24, ~50 px)
const WAVE_H := 5.0              # baixa: quem está no chão é atingido; pulando, não
const WALK := 18.0
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
const AIM_RADIUS := 12.0
const AIM_SPACING := 32.0        # distância mínima entre duas miras
const HOM_COUNT := [3, 4, 5]
const HOM_SPEED := [34.0, 38.0, 42.0]
const HOM_TURN := 0.032          # rad por quadro
const HOM_LIFE := 540
const HOM_ARM := 36              # antes disto o míssil não acerta a própria mecha (está saindo dela)
const HOM_RADIUS := 10.0
const DASH_WARN := [64, 56, 48]    # D104: +10 quadros para reagir (era 54, 46, 38)
const DASH_SPEED := 260.0
const DASH_MIN_DIST := 64.0      # D108: mais perto que isto do coelho, ela não começa a investida (troca por mísseis)
const KEEP := [72.0, 130.0]     # distância que ela mantém do coelho, andando (perto: recua)
const DASH_LASER := [46, 42, 38] # D104: o laser aparece 10 quadros antes; quadros finais do aviso com o laser posto: a direção não muda mais
const SHOVE_AFTER := 45          # quadros com o coelho encostado nela até ela dar o empurrão (D95)
const SHOVE_FRAMES := 20         # duração do dash para longe do coelho
const SHOVE_SPEED := 190.0       # px/s
const DASH_MAX := 120
const STUN := [80, 70, 60]
const BREAK_FRAMES := 100        # explosão de um terço: a mecha fica parada, faiscando
const DIE_FRAMES := 150

const C_HULL := Color("525663")          # chapas um pouco mais claras que as da cápsula: lê no fundo escuro
const C_HULL_DARK := Color("373a44")
const C_HULL_LIGHT := Color("767b88")
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
var dropping := false       # despencando com os propulsores desligados (D103)
var drop_hit := false       # esta queda já tirou um coração
var waves: Array = []       # ondas de choque da queda: {"x", "dir", "life"}
var markers: Array = []     # {pos, n (normal, para dentro da sala), fire_at, fired}
var shots: Array = []       # mísseis da mira: {pos, to}
var homers: Array = []      # teleguiados: {pos, vel, age}
var blasts: Array = []      # {pos, t, r}
var locked := false         # a investida ainda corrige a rota até o coelho
var dash_dir := Vector2.LEFT  # mira travada no fim do aviso (direção de tela)
const LAG_RATE := 16.0        # quão rápido o desenho da mecha alcança o giro do cenário (1/s)
var _lag_ang := 0.0           # ângulo de tela em que a mecha é desenhada (persegue view_angle)
var _lag_pending := false
var committed := false
var lost := false           # girou depois da mira travada: a investida sai sem alvo
var dash_hit := false       # a investida pegou o coelho (então a batida na parede não a fere)
var contact_t := 0          # quadros seguidos com o coelho encostado nela
var shove_t := 0            # quadros restantes do empurrão (dash para longe do coelho)
var shove_dir := 0.0
var launched := 0           # teleguiados lançados neste ataque
var flash := 0              # pisca branco ao levar dano
var hud_hit := 0
var bar_hit := 0
var anim := 0
var trail: Array = []       # rastro da investida
var pod_side := 1
var last_floor := true
var face := 1.0             # para onde olha, suavizado: -1 esquerda, 0 de frente, 1 direita
var walk_ph := 0.0          # passada
var recoil := 0             # tranco do disparo
var grimace := 0            # careta do Gatsby depois de levar um míssil
var debris: Array = []      # pedaços de chapa que voam quando um míssil acerta: {pos, vel, ang, av, life}


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
	contact_t = 0
	shove_t = 0
	vel = Vector2.ZERO
	float_t = 0
	dropping = false
	waves.clear()
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
	face = -1.0
	debris.clear()
	grimace = 0
	puppet.mood = "bored"
	puppet.visible = true
	puppet.fused = false
	puppet.tilt = 0.0


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
	# a mecha gira com a sala: fica no mesmo lugar em relação a ela (D101, D102). Na investida (e
	# no aviso com a mira travada), a velocidade e a mira giram junto: ela vai para a mesma parede
	# que estava mirando. No desenho, acompanha o giro um pouco atrás do cenário (`_lag_ang`).
	pos = r._rot_point(pos, dir)
	vel = vel.rotated(PI / 2.0 * dir)
	dash_dir = dash_dir.rotated(PI / 2.0 * dir)
	_lag_pending = true
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
	for d in debris:
		d["pos"] = r._rot_point(d["pos"], dir)
	trail.clear()
	waves.clear()       # as ondas corriam pelo chão de antes
	dropping = false    # flutua de novo na gravidade nova
	shove_t = 0
	if state == "dash":
		locked = false   # perdeu o alvo: segue reto até a parede que mirava
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
	recoil = 6
	return pos + Vector2(22 * pod_side - 2 * face, -18)


func fighting() -> bool:
	return state in ["idle", "aim", "homing", "dash_warn", "dash", "stun", "break"]


# ---------------------------------------------------------------- simulação

func step(r) -> void:
	room = r
	anim += 1
	flash = maxi(flash - 1, 0)
	bar_hit = maxi(bar_hit - 1, 0)
	recoil = maxi(recoil - 1, 0)
	_update_debris()
	if grimace > 0:
		grimace -= 1
		if grimace == 0 and puppet.mood == "panic" and fighting() and state != "stun" and state != "break":
			puppet.mood = "annoyed"
	if room.state == "play":
		room.invuln = maxi(room.invuln - 1, 0)
	for b in blasts:
		b["t"] += 1
	blasts = blasts.filter(func(b): return b["t"] < 16)
	if room.state != "play":
		return
	t += 1
	_smoke()
	_turn()
	_update_contact()
	_update_waves()
	match state:
		"inert":
			if t >= (INTRO_AGAIN if intro_seen else INTRO_FREE):
				state = "arrive"
				t = 0
				puppet.mood = "smug"
				room.sfx.emit("gatsby_dash")
		"arrive":
			room.cam_focus = pos + Vector2(0, -24)
			var k := clampf(float(t) / ARRIVE, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			var to := pos + HEAD
			cap_pos = cap_from.lerp(to, k) + Vector2(0, -sin(k * PI) * 18.0)
			if t >= ARRIVE:
				cap_pos = to
				state = "plug"
				t = 0
				puppet.fused = true
				room.sfx.emit("hatch")
				room.sfx.emit("crunch")
				room.shake = maxf(room.shake, 3.0)
				room.impact.emit(1.2)
				_sparks(pos + Vector2(-9, -15), 8)
				_sparks(pos + Vector2(9, -15), 8)
		"plug":
			# a fusão: tranco, os cabos acendem, as luzes do peito ligam uma a uma, os motores rugem
			if t == 14:
				room.sfx.emit("charge")
			if t == 34 or t == 42 or t == 50:
				room.sfx.emit("plate_on")
			if t == 62:
				room.sfx.emit("crusher_wake")
				room.shake = maxf(room.shake, 3.0)
				for k in 10:
					_thrust_puff()
			if t >= PLUG:
				room.cam_focus = null
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
			if not committed and t >= DASH_WARN[_phase()] - DASH_LASER[_phase()]:
				committed = true
				var d := _rabbit_c() - pos
				dash_dir = d.normalized() if d.length() > 1.0 else Vector2.LEFT
				room.sfx.emit("mover_warn")
			if t >= DASH_WARN[_phase()]:
				# o laser foi posto: a investida segue reto por ele, sem corrigir (quem saiu da linha escapa)
				vel = dash_dir * DASH_SPEED
				locked = false
				dash_hit = false
				dropping = false
				float_t = 0
				state = "dash"
				t = 0
				room.sfx.emit("gatsby_dash")
		"dash":
			_dash()
		"stun":
			_body(false)
			if t % 6 == 0:
				_sparks(pos + Vector2(rng.randf_range(-16, 16), rng.randf_range(-18, 10)), 2)
			if t >= STUN[_phase()]:
				_go_idle()
		"break":
			_body(false)
			if t % 9 == 0 and t < BREAK_FRAMES - 20:
				_boom(pos + Vector2(rng.randf_range(-18, 18), rng.randf_range(-22, 16)), 9.0, false)
			if t >= BREAK_FRAMES:
				plan_i = 0
				puppet.mood = "furious"
				_go_idle()
		"dying":
			_body(false)
			if t % 7 == 0:
				_boom(pos + Vector2(rng.randf_range(-20, 20), rng.randf_range(-24, 18)), 10.0, false)
			cap_pos = pos + HEAD
			if t >= DIE_FRAMES:
				state = "wreck"
				t = 0
				cap_from = pos + HEAD
				puppet.fused = false
				puppet.tilt = 0.0
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


## O coelho encostado nela por um tempo (embaixo ou colado): ela dá um dash curto para o lado
## oposto, sem dano, para ele sair. Só parada (andando, mirando, lançando mísseis).
func _update_contact() -> void:
	if shove_t > 0:
		shove_t -= 1
		return
	var calm: bool = state == "idle" or state == "aim" or state == "homing"
	if calm and room.overlaps(Rect2i(body_rect().grow(2.0)), room.rabbit.rect):
		contact_t += 1
	else:
		contact_t = 0
	if contact_t >= SHOVE_AFTER:
		contact_t = 0
		var dx := _rabbit_c().x - pos.x
		shove_dir = -signf(dx) if absf(dx) > 2.0 else (1.0 if pos.x < room.pw / 2.0 else -1.0)
		var b := _bounds()
		if (shove_dir < 0.0 and pos.x <= b.position.x + 2.0) or (shove_dir > 0.0 and pos.x >= b.end.x - 2.0):
			shove_dir = -shove_dir   # encostada na parede: vai para o outro lado
		shove_t = SHOVE_FRAMES
		room.sfx.emit("gatsby_dash")
		for i in 6:
			room.particles.append({"pos": pos + Vector2(-shove_dir * 14.0, 12), "vel": Vector2(-shove_dir * randf_range(30.0, 80.0), -randf_range(5.0, 30.0)),
				"life": randi_range(8, 14), "col": C_FLAME if i % 2 else C_RIVET, "grav": 60.0})


func _go_idle() -> void:
	state = "idle"
	t = 0
	if puppet.mood != "amused":
		puppet.mood = "smug"


func _next_attack() -> void:
	var plan: Array = PLAN[_phase()]
	var a: String = plan[plan_i % plan.size()]
	plan_i += 1
	if a == "dash" and pos.distance_to(_rabbit_c()) < DASH_MIN_DIST:
		a = "homing"   # colada no coelho, a investida não daria tempo de desviar
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
		if float_t >= CUT_WARN:
			if anim % 3 == 0:
				_thrust_puff()
		else:
			# os propulsores engasgam: fumaça preta, tranco, chama piscando (o aviso da queda)
			if float_t == CUT_WARN - 1:
				room.sfx.emit("mover_warn")
			if anim % 4 == 0:
				_thrust_puff()
			if anim % 2 == 0:
				room.particles.append({"pos": pos + Vector2(randf_range(-20.0, 20.0), 12), "vel": Vector2(randf_range(-8.0, 8.0), 20.0),
					"life": randi_range(8, 14), "col": Color(0.12, 0.12, 0.14, 0.9), "grav": -30.0})
			if float_t == 0 and not _on_floor():
				dropping = true
				drop_hit = false
				vel = Vector2(0.0, DROP_SPEED)
				room.sfx.emit("steam_burst")
	elif dropping:
		vel.x = 0.0
		vel.y = minf(vel.y + GRAV * 1.6 / 60.0, DROP_MAX)
		if not drop_hit and room.invuln == 0 and room.overlaps(Rect2i(body_rect()), room.rabbit.rect):
			drop_hit = true
			room.kill()
			if room.state != "play":
				return
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
	if shove_t > 0:
		vel.x = shove_dir * SHOVE_SPEED
	var fall := vel.y
	pos += vel / 60.0
	pos.x = clampf(pos.x, b.position.x, b.end.x)
	pos.y = clampf(pos.y, b.position.y, b.end.y)
	var on := _on_floor()
	if on and dropping:
		dropping = false
		vel.y = 0.0
		_drop_impact()
	elif on:
		vel.y = 0.0
		if not last_floor and fall > 90.0:
			room.impact.emit(minf(fall / 120.0, 2.0))
			room.shake = maxf(room.shake, 2.0)
			room.sfx.emit("crunch")
	last_floor = on


## A queda bate no chão: tremor forte, poeira e duas ondas de choque correndo pelo chão (D103).
## Quem ficou embaixo leva dano (se a descida ainda não tirou um coração).
func _drop_impact() -> void:
	room.shake = maxf(room.shake, 6.0)
	room.impact.emit(2.5)
	room.sfx.emit("slam")
	if not drop_hit and room.invuln == 0 and room.overlaps(Rect2i(body_rect().grow(1.0)), room.rabbit.rect):
		drop_hit = true
		room.kill()
		if room.state != "play":
			return
	var fy := _floor_y()
	for sd in [-1.0, 1.0]:
		waves.append({"x": pos.x + sd * (MW / 2.0), "dir": sd, "life": WAVE_LIFE})
		for i in 10:
			room.particles.append({"pos": Vector2(pos.x + sd * randf_range(4.0, 20.0), fy - 1.0),
				"vel": Vector2(sd * randf_range(20.0, 90.0), -randf_range(20.0, 80.0)),
				"life": randi_range(10, 20), "col": C_RIVET if i % 2 else C_FIRE, "grav": 200.0})


## A superfície do chão (px da sala atual).
func _floor_y() -> float:
	return room.ph - 8.0


## Ondas de choque: correm pelo chão; pegam o coelho encostado no chão onde a onda passa. Uma queda
## tira no máximo um coração (acertou: as ondas param de ferir).
func _update_waves() -> void:
	if waves.is_empty():
		return
	var fy := _floor_y()
	var keep: Array = []
	for w in waves:
		w["x"] += w["dir"] * WAVE_SPEED / 60.0
		w["life"] -= 1
		if w["life"] <= 0 or w["x"] < 8.0 or w["x"] > room.pw - 8.0:
			continue
		if anim % 3 == 0:
			room.particles.append({"pos": Vector2(w["x"], fy - 1.0), "vel": Vector2(w["dir"] * 10.0, -randf_range(15.0, 40.0)),
				"life": randi_range(8, 14), "col": C_FIRE, "grav": 160.0})
		var rr: Rect2i = room.rabbit.rect
		if not drop_hit and room.state == "play" and room.invuln == 0 and float(rr.end.y) >= fy - 1.0 - WAVE_H * 0.4 \
				and absf(float(rr.position.x) + 6.0 - w["x"]) < 5.0:
			drop_hit = true
			room.kill()
			if room.state != "play":
				return
		keep.append(w)
	waves = keep


func _dash() -> void:
	puppet.mood = "furious"
	if t % 2 == 0:
		trail.append(pos)
		if trail.size() > 4:
			trail.pop_front()
	var b := _bounds()
	var n := 4
	for i in n:
		pos += vel / 60.0 / n
		# D108: no trajeto não fere (numa esquiva, os dois podem se cruzar no ar). Só se o coelho
		# está no chão no caminho: ela para em cima dele, e isso é o impacto.
		if not dash_hit and room.invuln == 0 and room.rabbit.on_ground and room.overlaps(Rect2i(body_rect()), room.rabbit.rect):
			_stop_on_rabbit()
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


## A investida parou em cima do coelho (no chão): o impacto o fere, e ela fica um instante parada.
func _stop_on_rabbit() -> void:
	dash_hit = true
	vel = Vector2.ZERO
	trail.clear()
	room.shake = 4.0
	room.impact.emit(1.8)
	room.sfx.emit("slam")
	room.kill()
	if room.state != "play":
		return
	state = "stun"
	t = 0
	puppet.mood = "smug"


## Bateu na parede: impacto enorme. Sem ter pegado o coelho, leva dano e fica atordoada. Se o coelho
## ficou entre ela e a parede, o impacto o fere.
func _slam() -> void:
	if not dash_hit and room.invuln == 0 and room.overlaps(Rect2i(body_rect().grow(2.0)), room.rabbit.rect):
		dash_hit = true
		room.kill()
		if room.state != "play":
			return
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
		puppet.mood = "panic"
		grimace = 40


## Um terço da barra: explode por dentro, se estraga e o Gatsby perde um coração.
func _break() -> void:
	_clear_projectiles()
	state = "break"
	t = 0
	float_t = 0
	dropping = false
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
	dropping = false
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
	waves.clear()


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
			_hit_fx(p)
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

## Vira o corpo para o coelho (ou para onde vai, na investida). Passa pela frente ao virar.
func _turn() -> void:
	if state == "inert" or state == "wreck" or state == "dying" or state == "stun" or state == "break":
		return
	var want := face
	if state == "dash":
		if absf(vel.x) > 20.0:
			want = signf(vel.x)
	elif state == "dash_warn" and committed:
		want = signf(dash_dir.x) if absf(dash_dir.x) > 0.2 else face
	else:
		var dx := _rabbit_c().x - pos.x
		if absf(dx) > 8.0:
			want = signf(dx)
	face = move_toward(face, want, 0.07)


## Míssil acertou a mecha: pedaços de chapa voam e o Gatsby faz careta.
func _hit_fx(p: Vector2) -> void:
	room.shake = maxf(room.shake, 3.5)
	room.sfx.emit("crunch")
	var away := (p - pos).normalized()
	for i in 4:
		var a := away.angle() + rng.randf_range(-0.9, 0.9)
		debris.append({"pos": p, "vel": Vector2.from_angle(a) * rng.randf_range(60.0, 120.0) + Vector2(0, -40),
			"ang": rng.randf() * TAU, "av": rng.randf_range(-0.4, 0.4), "life": 50, "w": 2 + i % 3})


func _update_debris() -> void:
	for d in debris:
		d["vel"].y += 6.0
		d["pos"] += d["vel"] / 60.0
		d["ang"] += d["av"]
		d["life"] -= 1
	debris = debris.filter(func(d): return d["life"] > 0)


func _sparks(p: Vector2, n: int) -> void:
	for i in n:
		room.particles.append({
			"pos": p, "vel": Vector2(randf_range(-60.0, 60.0), randf_range(-90.0, -10.0)),
			"life": randi_range(8, 16), "col": C_FLAME_CORE, "grav": 260.0,
		})


func _thrust_puff() -> void:
	for s in [-1, 1]:
		room.particles.append({
			"pos": pos + Vector2(20.0 * s, 12), "vel": Vector2(randf_range(-6.0, 6.0), 40.0),
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
			"pos": pos + Vector2(rng.randf_range(-14, 14), -10), "vel": Vector2(randf_range(-5.0, 5.0), -22.0),
			"life": randi_range(18, 30), "col": Color(0.35, 0.35, 0.4, 0.7), "grav": -10.0,
		})


# ---------------------------------------------------------------- desenho

func _process(delta: float) -> void:
	# o ângulo em que a mecha é desenhada persegue o do cenário, um pouco atrás dele
	if room != null:
		if _lag_pending and room.rotating:
			_lag_pending = false
			_lag_ang = room.view_angle
		elif not _lag_pending:
			_lag_ang = lerpf(_lag_ang, room.view_angle, 1.0 - exp(-delta * LAG_RATE))
			if absf(_lag_ang - room.view_angle) < 0.002:
				_lag_ang = room.view_angle
	anim_draw()
	queue_redraw()


## A pose do quadro (só desenho): inclinação em torno dos pés, deslocamento, pernas, braços,
## tampas dos mísseis, direção do fogo dos motores.
func _pose() -> Dictionary:
	var p := {"tilt": 0.0, "off": Vector2.ZERO, "leg": [0.0, 0.0], "swing": 0.0, "raise": 0.0,
		"dangle": 0.0, "slump": 0.0, "lid": 0.0, "thrust": Vector2.ZERO}
	match state:
		"inert", "arrive":
			p["slump"] = 5.0
			p["tilt"] = 0.07
		"plug":
			var k := clampf(float(t - 14) / 40.0, 0.0, 1.0)
			p["slump"] = 5.0 * (1.0 - k)
			p["tilt"] = 0.07 * (1.0 - k)
			if t < 12:
				p["off"] = Vector2(0, 3.0 * (1.0 - t / 12.0))   # o tranco do encaixe
			if t >= 62 and t < 82:
				p["thrust"] = Vector2.DOWN
				p["off"] += Vector2(0, -2)
		"dash_warn":
			p["slump"] = 5.0 if committed else 2.5 + sin(anim * 0.6)
			p["tilt"] = -0.12 * face
			p["swing"] = -4.0
			p["thrust"] = Vector2(-face * 0.7, 1.0).normalized()
		"dash":
			p["tilt"] = clampf(vel.x / DASH_SPEED, -1.0, 1.0) * 0.35
			p["thrust"] = -vel.normalized() if vel.length() > 1.0 else Vector2.ZERO
			p["swing"] = -5.0
			p["dangle"] = 3.0
		"aim", "homing":
			p["raise"] = 1.0
			p["lid"] = 1.0
			p["off"] = Vector2(-face * recoil * 0.25, recoil * 0.25)
		"stun":
			p["slump"] = 4.0
			p["tilt"] = sin(anim * 0.18) * 0.13
		"break", "dying":
			p["off"] = Vector2(float((anim * 7) % 3) - 1.0, float((anim * 5) % 3) - 1.0)
			p["slump"] = 2.0
			p["tilt"] = sin(anim * 0.5) * 0.06
		"wreck":
			p["slump"] = 8.0
			p["tilt"] = 0.24
	if shove_t > 0:
		p["tilt"] += shove_dir * 0.25
		p["thrust"] = Vector2(-shove_dir, 0.3).normalized()
	if dropping:
		p["dangle"] = 4.0
		p["thrust"] = Vector2.ZERO
		p["swing"] = 3.0
	elif float_t > 0 and float_t < CUT_WARN and state != "dash":
		p["dangle"] = 3.0
		p["thrust"] = Vector2.DOWN if (anim / 3) % 2 == 0 else Vector2.ZERO
		p["off"] += Vector2(float((anim * 7) % 3) - 1.0, float((anim * 5) % 3) - 1.0)
		p["tilt"] += sin(anim * 0.9) * 0.05
	elif float_t > 0 and state != "dash":
		p["dangle"] = 3.0
		p["thrust"] = Vector2.DOWN
		p["tilt"] += clampf(vel.x / FLOAT_SEEK, -1.0, 1.0) * 0.12
		p["swing"] = 2.0
	elif state == "idle" and _on_floor():
		if absf(vel.x) > 1.0:
			var ph := pos.x * 0.22
			p["leg"] = [maxf(0.0, sin(ph)) * 3.5, maxf(0.0, -sin(ph)) * 3.5]
			p["off"].y -= absf(sin(ph)) * 1.2
			p["swing"] = sin(ph) * 2.5
			p["tilt"] += signf(vel.x) * 0.05
		else:
			p["slump"] = (sin(anim * 0.07) + 1.0) * 0.6   # respira
	return p


## No giro, a mecha (e o laser) giram com a sala, um pouco atrás do cenário: o ponto `p` da sala é
## desenhado no ângulo `_lag_ang` em vez do ângulo do cenário.
func _lock(p: Vector2) -> Vector2:
	if room == null or absf(_lag_ang - room.view_angle) < 0.0005:
		return p
	return room.cam + (p - room.cam).rotated(_lag_ang - room.view_angle)


## Um ponto do corpo (em relação a `pos`, em pé) para px da sala, com a inclinação e o giro da tela.
func _body_point(local: Vector2, pz: Dictionary) -> Vector2:
	var f := Vector2(0, FEET)
	var q: Vector2 = (local - f).rotated(pz["tilt"]) + f + pz["off"]
	return _lock(pos) + q.rotated(-room.view_angle)


## A cápsula acompanha a mecha na tela (também durante a animação do giro, quando step não roda).
func anim_draw() -> void:
	if room == null:
		return
	puppet.anim = anim
	var plugged := fighting() or state == "plug" or state == "dying"
	if plugged:
		var pz := _pose()
		puppet.pos = _body_point(HEAD + Vector2(2.0 * face, pz["slump"]), pz)
		puppet.tilt = pz["tilt"]
	else:
		puppet.pos = cap_pos
		puppet.tilt = 0.0
	if grimace > 0 and fighting():
		puppet.mood = "panic"
	puppet.jolt = 20 if state == "break" or state == "stun" else 0


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
	for d in debris:
		draw_set_transform_matrix(base * Transform2D(d["ang"], d["pos"].round()))
		var w: float = d["w"]
		draw_rect(Rect2(-w, -1, w * 2.0, 2), C_HULL_LIGHT)
		draw_rect(Rect2(-w, -1, 1, 1), C_RIVET)
	draw_set_transform_matrix(base)
	# o laser da investida: aparece uma vez, já na direção final, e não muda mais
	if state == "dash_warn" and committed:
		var a0 := _lock(pos)
		var b0 := _lock(pos + dash_dir * _ray_len(pos, dash_dir))
		var fl := 0.75 + 0.25 * sin(anim * 0.9)
		draw_line(a0, b0, Color(C_AIM, 0.18 * fl), 5.0)
		draw_line(a0, b0, Color(C_AIM, 0.85 * fl), 1.0)
		draw_circle(b0, 2.5 + sin(anim * 0.5), Color(C_AIM, 0.7))
		draw_circle(b0, 1.0, Color(1, 0.9, 0.9, 0.9))
	# ondas de choque da queda
	for w in waves:
		var kf: float = float(w["life"]) / WAVE_LIFE
		var fy := _floor_y()
		var wx: float = w["x"]
		var hgt := WAVE_H * (0.5 + 0.5 * kf)
		draw_colored_polygon(PackedVector2Array([Vector2(wx - 6, fy), Vector2(wx - 1, fy - hgt), Vector2(wx + 2, fy - hgt * 0.6), Vector2(wx + 6, fy)]), Color(C_FIRE, 0.75 * kf + 0.2))
		draw_line(Vector2(wx - 8 * w["dir"], fy - 1), Vector2(wx, fy - 1), Color(1, 0.95, 0.8, 0.6 * kf), 1.0)
	# rastro
	for i in trail.size():
		var tp: Vector2 = trail[i]
		draw_set_transform_matrix(base * Transform2D(-room.view_angle, tp.round()))
		draw_rect(Rect2(-MW / 2.0 + 4, -MH / 2.0 + 10, MW - 8, MH - 10), Color(C_HULL_LIGHT, 0.10 + 0.07 * i), false, 1.0)
	var pz := _pose()
	var xf := base * Transform2D(-room.view_angle, _lock(pos).round()) * Transform2D(0.0, pz["off"].round()) \
		* Transform2D(pz["tilt"], Vector2(0, FEET)) * Transform2D(0.0, Vector2(0, -FEET))
	draw_set_transform_matrix(xf)
	_draw_mecha(pz)
	if fighting() or state == "dying":
		draw_set_transform_matrix(base * Transform2D(-room.view_angle, _lock(pos).round()))
		_draw_gatsby_hearts()
	draw_set_transform_matrix(base)
	_draw_offscreen()
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


## A sala é mais alta que a tela: miras e mísseis fora da vista ganham uma seta na borda.
func _draw_offscreen() -> void:
	if room.rotating:
		return
	var half: float = room.VIEW.y / 2.0 - 6.0
	var c: Vector2 = room.cam
	var items: Array = []
	for m in markers:
		if not m["fired"]:
			items.append([m["pos"], C_AIM])
	for h in homers:
		items.append([h["pos"], C_MISSILE])
	for it in items:
		var p: Vector2 = it[0]
		var dy := p.y - c.y
		if absf(dy) <= half + 4.0:
			continue
		var sgn := signf(dy)
		var tip := Vector2(p.x, c.y + sgn * half)
		var col: Color = it[1]
		if (anim / 5) % 2 == 0:
			col = Color(col, 0.6)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-3, -sgn * 4), tip + Vector2(3, -sgn * 4)]), col)


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


# ---- a mecha (40 x 52; origem no centro da caixa, pés em y = 26). Vista de 3/4: `face` vai de
# -1 (olha para a esquerda) a 1 (direita), passando pela frente. O lado para onde olha é o "de
# perto" (desenhado por cima); o outro fica atrás do tronco, mais escuro.

func _dk(c: Color, far: bool) -> Color:
	return c.darkened(0.32) if far else c


func _draw_mecha(pz: Dictionary) -> void:
	var dmg := HEARTS - hearts
	var on := state != "inert" and state != "arrive" and state != "wreck"
	var d := 1.0 if face >= 0.0 else -1.0
	var k := absf(face)
	var u: Vector2 = Vector2(0, pz["slump"])             # o tronco desce quando ela se agacha
	var sx := 1.0 - 0.16 * k                      # escorço: o corpo estreita de lado
	var lights := 3
	if state == "inert" or state == "arrive":
		lights = 0
	elif state == "plug":
		lights = clampi((t - 26) / 8, 0, 3)
	# compartimentos de mísseis (nas costas): vão para trás quando ela vira
	for side in [-d, d]:
		# bem para fora: não cobrem a cúpula (o rosto do Gatsby), nem de lado
		var cx: float = side * 22.0 - d * 2.0 * k
		_draw_pod(Vector2(cx, -20) + u, side == -d, pz["lid"], dmg, on, side)
	# braço e perna de trás
	_draw_leg(-d, pz, true, sx, k)
	_draw_arm(-d, pz, true, sx, k, u)
	# quadril, perna da frente
	draw_rect(Rect2(-11 * sx, 8 + u.y * 0.6, 22 * sx, 5), C_HULL_DARK)
	draw_rect(Rect2(-4 * sx + 2 * d * k, 12 + u.y * 0.6, 8, 4), C_HULL_DARK)
	_draw_leg(d, pz, false, sx, k)
	# tronco
	var tx: float = -15.0 * sx + 1.5 * d * k
	var tw := 30.0 * sx
	var ty: float = -14.0 + u.y
	draw_rect(Rect2(tx, ty, tw, 23), C_HULL)
	draw_rect(Rect2(tx, ty, tw, 2), C_HULL_LIGHT)
	draw_rect(Rect2(tx, ty + 22, tw, 1), C_SEAM)
	if k > 0.15:
		# a lateral do tronco aparece do lado de trás: dá volume
		var sw := roundf(4.0 * k)
		draw_rect(Rect2(tx if d > 0 else tx + tw - sw, ty, sw, 23), C_HULL_DARK)
	draw_rect(Rect2(tx, ty + 12, tw, 1), C_SEAM)
	draw_rect(Rect2(tx + tw * 0.25, ty + 3, 1, 9), C_SEAM)
	draw_rect(Rect2(tx + tw * 0.75, ty + 3, 1, 9), C_SEAM)
	for q in [Vector2(tx + 1, ty + 4), Vector2(tx + tw - 2, ty + 4), Vector2(tx + 1, ty + 18), Vector2(tx + tw - 2, ty + 18)]:
		draw_rect(Rect2(q, Vector2(1, 1)), C_RIVET)
	# placa da barriga com remendo
	draw_rect(Rect2(tx + 4, ty + 14, tw - 8, 7), C_HULL_DARK)
	draw_rect(Rect2(tx + 6 + 3 * d * k, ty + 15, 6, 4), C_RUST)
	# painel do peito: vai para o lado para onde ela olha
	var px: float = -6.0 + 4.0 * d * k
	draw_rect(Rect2(px, ty + 3, 12, 9), C_SEAM)
	for i in 3:
		var lc: Color = C_LIGHTS[i]
		var lit := i < lights and ((anim / 9 + i) % 4 != 0 or state == "dash_warn" or state == "plug")
		draw_rect(Rect2(px + 1 + i * 4, ty + 4, 3, 3), lc if lit else Color(lc, 0.15))
		if lit:
			draw_rect(Rect2(px + 1 + i * 4, ty + 4, 1, 1), Color(1, 1, 1, 0.6))
	var bar_w := 10.0 * clampf(float(energy) / ENERGY, 0.0, 1.0) if lights > 0 else 0.0
	draw_rect(Rect2(px + 1, ty + 9, 10, 2), C_RUST)
	draw_rect(Rect2(px + 1, ty + 9, bar_w, 2), C_ENERGY)
	# gola e cabos da fusão (prendem a cúpula ao tronco)
	draw_rect(Rect2(-10 * sx + 2 * d * k, ty - 2, 20 * sx, 3), C_HULL_DARK)
	draw_rect(Rect2(-10 * sx + 2 * d * k, ty - 2, 20 * sx, 1), C_HULL_LIGHT)
	var glow := 0.0
	if state == "plug":
		glow = clampf(float(t - 14) / 16.0, 0.0, 1.0)
	elif on:
		glow = 0.55 + 0.25 * sin(anim * 0.15)
	for side in [-1.0, 1.0]:
		var c0: Vector2 = Vector2(side * 8.0 * sx + 2 * d * k, ty - 1)
		var c1: Vector2 = Vector2(side * 12.0 + 2 * d * k, ty - 6)
		draw_line(c0, c1, C_SEAM, 2.0)
		if glow > 0.0:
			draw_line(c0, c1, Color(C_LIGHTS[2], glow), 1.0)
	# ombros com chifres
	for side in [-d, d]:
		var far: bool = side == -d
		var sh: Vector2 = Vector2(side * 15.0 * sx + d * 1.5 * k, ty + 1)
		draw_rect(Rect2(sh.x - 5, sh.y - 3, 10, 6), _dk(C_HULL_LIGHT, far))
		draw_rect(Rect2(sh.x - 5, sh.y + 2, 10, 1), C_SEAM)
		if not (dmg >= 2 and side < 0):
			draw_colored_polygon(PackedVector2Array([sh + Vector2(-3, -3), sh + Vector2(side * 3.0, -9), sh + Vector2(2, -3)]), _dk(C_HULL_LIGHT, far))
	# braço da frente
	_draw_arm(d, pz, false, sx, k, u)
	# estragos
	if dmg >= 1:
		draw_line(Vector2(tx + 3, ty + 2), Vector2(tx + 7, ty + 8), C_SEAM, 1.0)
		draw_line(Vector2(tx + 7, ty + 8), Vector2(tx + 4, ty + 12), C_SEAM, 1.0)
		draw_rect(Rect2(tx + tw - 9, ty + 16, 5, 3), C_RUST)
	if dmg >= 2:
		draw_rect(Rect2(tx + tw - 10, ty + 3, 7, 8), Color("120f0c"))   # chapa arrancada: fios
		draw_line(Vector2(tx + tw - 9, ty + 4), Vector2(tx + tw - 6, ty + 9), C_AIM, 1.0)
		draw_line(Vector2(tx + tw - 5, ty + 4), Vector2(tx + tw - 7, ty + 10), C_LIGHTS[1], 1.0)
		if (anim / 4) % 5 == 0:
			draw_rect(Rect2(tx + tw - 7, ty + 6, 1, 1), C_FLAME_CORE)
	if state == "wreck":
		draw_rect(Rect2(tx, ty, tw, 23), Color(0, 0, 0, 0.3))
	if flash > 0 and (flash / 3) % 2 == 0:
		draw_rect(Rect2(tx, ty, tw, 23), Color(1, 1, 1, 0.4))


## Compartimento de mísseis: caixa alta com as bocas redondas; a tampa abre para atirar.
func _draw_pod(o: Vector2, far: bool, lid: float, dmg: int, on: bool, side: float) -> void:
	draw_rect(Rect2(o.x - 4, o.y, 8, 20), _dk(C_HULL_DARK, far))
	draw_rect(Rect2(o.x - 4, o.y + 19, 8, 1), C_SEAM)
	draw_rect(Rect2(o.x - 4, o.y, 1, 20), _dk(C_HULL_LIGHT, far))
	for i in 3:
		var c: Vector2 = o + Vector2(0.5, 4 + i * 5)
		var empty: bool = (dmg >= 1 and side < 0 and i == 0) or not on
		draw_circle(c, 2.2, C_SEAM)
		draw_circle(c, 1.4, C_SEAM if empty else _dk(C_AIM, far))
		if not empty:
			draw_rect(Rect2(c - Vector2(1, 1), Vector2(1, 1)), Color(1, 1, 1, 0.5))
	# tampa: abre girando para fora
	var hinge: Vector2 = o + Vector2(-4 if side < 0 else 4, 0)
	var ang: float = -side * lid * 1.1
	var a: Vector2 = hinge
	var b: Vector2 = hinge + Vector2(side * -8.0, 0).rotated(ang)
	draw_line(a, b, _dk(C_HULL_LIGHT, far), 2.0)


func _draw_leg(side: float, pz: Dictionary, far: bool, sx: float, k: float) -> void:
	var lift: float = pz["leg"][0 if side < 0 else 1]
	var dangle: float = pz["dangle"]
	var hip: Vector2 = Vector2(side * 7.0 * sx - (2.0 * k * side if far else 0.0), 12 + pz["slump"] * 0.6)
	var knee_y: float = 18.0 + pz["slump"] * 0.3 - lift * 0.5 + dangle * 0.5
	var foot_y: float = 23.0 - lift + dangle
	var c := _dk(C_HULL, far)
	draw_rect(Rect2(hip.x - 4, hip.y, 8, knee_y - hip.y + 1), c)
	draw_rect(Rect2(hip.x - 5, knee_y - 1, 10, 3), _dk(C_HULL_LIGHT, far))
	draw_rect(Rect2(hip.x - 1, knee_y, 2, 1), C_RIVET)
	draw_rect(Rect2(hip.x - 4, knee_y + 2, 8, foot_y - knee_y - 2), c)
	# pé: o bico aponta para onde ela olha
	var d := 1.0 if face >= 0.0 else -1.0
	var toe: float = d * (2.0 + 2.0 * k)
	draw_rect(Rect2(hip.x - 6 + toe * 0.5, foot_y, 12, 3), _dk(C_HULL_DARK, far))
	draw_colored_polygon(PackedVector2Array([Vector2(hip.x + d * 6 + toe * 0.5, foot_y), Vector2(hip.x + d * 9 + toe * 0.5, foot_y + 3), Vector2(hip.x + d * 6 + toe * 0.5, foot_y + 3)]), _dk(C_HULL_LIGHT, far))


## Braço com o motor embaixo da mão (os dois motores laterais).
func _draw_arm(side: float, pz: Dictionary, far: bool, sx: float, k: float, u: Vector2) -> void:
	var d := 1.0 if face >= 0.0 else -1.0
	var sh: Vector2 = Vector2(side * 17.0 * sx + (d * 3.0 * k if far else d * 1.0 * k), -11 + u.y)
	var raise: float = pz["raise"]
	var swing: float = pz["swing"] * side * d * 0.5 + pz["swing"] * 0.5
	var hand: Vector2 = sh + Vector2(side * (2.0 + raise * 3.0) + swing, 18.0 - raise * 10.0)
	var c := _dk(C_HULL_LIGHT, far)
	var elbow: Vector2 = sh.lerp(hand, 0.5) + Vector2(side * 2.0, 0)
	draw_line(sh, elbow, c, 6.0)
	draw_line(elbow, hand, c, 6.0)
	draw_rect(Rect2(elbow - Vector2(2, 2), Vector2(4, 4)), _dk(C_HULL_DARK, far))
	# motor: um bocal embaixo da mão
	var noz: Vector2 = hand + Vector2(0, 3)
	draw_rect(Rect2(noz.x - 4, noz.y - 1, 8, 4), _dk(C_HULL_DARK, far))
	draw_rect(Rect2(noz.x - 4, noz.y - 1, 8, 1), C_RIVET)
	var th: Vector2 = pz["thrust"]
	if th != Vector2.ZERO and state != "wreck":
		# o fogo sai para trás do movimento (o corpo está inclinado: compensa)
		var dir: Vector2 = th.rotated(-pz["tilt"])
		var fl := 6.0 + float((anim / 2) % 3) * 2.5 + (4.0 if state == "dash" else 0.0)
		var o: Vector2 = noz + Vector2(0, 3)
		var nrm: Vector2 = dir.orthogonal()
		draw_colored_polygon(PackedVector2Array([o - nrm * 3.0, o + dir * fl, o + nrm * 3.0]), _dk(C_FLAME, far))
		draw_colored_polygon(PackedVector2Array([o - nrm * 1.5, o + dir * fl * 0.55, o + nrm * 1.5]), C_FLAME_CORE)


## Os corações do Gatsby, flutuando acima da cápsula.
func _draw_gatsby_hearts() -> void:
	for i in HEARTS:
		_draw_heart(Vector2(-13 + i * 9, -38), i < hearts)


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

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
const ANIM := {"run": [0, 8], "idle": [1, 4], "flex": [2, 6], "throw": [3, 4], "die": [4, 4], "leap": [5, 3], "punch": [6, 4],
	"tired": [7, 4], "hold": [8, 4], "inject": [9, 12], "guard": [10, 4], "walk": [11, 6], "block": [12, 2], "hit": [13, 2]}
# O plot twist (D113): sem energia, ele para, ergue a seringa verde e se injeta (a energia volta toda).
# O coelho pode pegá-la enquanto ela flutua acima da mão aberta.
const TIRED_FRAMES := 50             # para, ofegando
const HOLD_FRAMES := 360             # 6 s com a seringa no alto (a janela do coelho)
const INJ_FAST := 3                  # quadros do jogo por quadro da injeção (0 a 7: rápida)
const INJ_PUMP := 5                  # e do PUMP (8 a 11)
const INJECT_FRAMES := 8 * INJ_FAST + 4 * INJ_PUMP
const HAND_UP := Vector2(49.3, 18.0) # a mão aberta no quadro "hold" (art/senzi.json, hand_up)
const SYRINGE_FLOAT := 20.0          # quanto a seringa flutua acima da mão
const DOSE_SPEED := 0.1              # cada dose: 10% mais rápido
# O ringue (D114): o coelho pega a seringa e vira o coelhão por 12 s.
const HERO_SHEET := "res://art/coelhao.png"
const HERO_ANIM := {"guard": [0, 4], "walk": [1, 6], "jab": [2, 4], "block": [3, 2], "hit": [4, 2], "jump": [5, 2],
	"flex": [6, 6], "die": [7, 4], "kick": [8, 4]}
const G_UNROT := 20                  # a transformação: quando a sala volta ao normal
const G_BOLT := 100                  # o raio
const G_POPS := [112, 128, 144]      # os três estouros do coelhão crescendo
const G_ROAR := 168
const G_END := 200
const BOLT_FRAMES := 14
const RING_FRAMES := 720             # 12 s de coelhão
const DEFLATE_FRAMES := 48
const H_HP_HEART := 30.0             # vida do coelho por coração (3 jabs do Senzi)
const S_HP_HEART := 60.0             # vida do Senzi por coração (12 jabs do coelho)
const S_HP_MAX := 180.0
const H_WALK := 78.0
const H_JUMP := 230.0
const HJAB_HIT := 4                  # o jab do coelho: quadro em que acerta, total, alcance, dano
const HJAB_TOTAL := 13
const HJAB_REACH := 40.0
const HJAB_DMG := 5.0
const HKICK_HIT := 9                 # o chute (giro direito): mais lento, mais longe, mais forte, e quebra a defesa
const HKICK_TOTAL := 24
const HKICK_REACH := 54.0
const HKICK_DMG := 9.0
const S_STUN := 12                   # quadros sem agir depois de apanhar
const H_STUN := 16
const S_WALK := 46.0
const S_RANGE := 38.0
const SJAB_WIND := 12                # o jab do Senzi: o aviso (dá para defender)
const SJAB_REACH := 40.0
const SJAB_DMG := 10.0
const SCHARGE_WIND := 32             # o soco carregado: pisca e grunhe; não dá para defender (recue ou pule)
const SCHARGE_DMG := 20.0
const SLEAP_DMG := 15.0
const RING_PATTERNS := [
	["approach", "jab", "jab", "retreat", "guard"],                       # 3 corações
	["approach", "jab", "jab", "charge", "retreat"],                      # 2
	["approach", "jab", "leap", "jab", "jab", "charge", "guard"],         # 1
]
const TUCK := Vector2(8, -33)        # o centro da bola encolhida, a partir dos pés (o eixo da cambalhota)
const STRIDE := 5.0                  # px corridos por quadro da corrida
const SPEED := [62.0, 76.0, 90.0]    # px/s, por terço da barra gasto
const TURN_DELAY := [34, 22, 14]     # quadros para dar meia-volta quando o coelho passa por ele
const ENERGY := 300.0
const DRAIN := [3.0, 3.5, 4.0]       # energia por segundo, só de correr
# Os cogumelos que brotam (D112): tipo -> energia que ele perde ao quebrar.
#   toco (baixo e largo), muro (alto), pendurado (do teto: o coelho passa por baixo), fenda (um de cima e
#   um de baixo, só um buraco), mola (joga o coelho e vira a gravidade) e grudento (gosma: ele fica preso).
const COST := {"stump": 20.0, "wall": 30.0, "hang": 30.0, "gap": 25.0, "spring": 20.0, "sticky": 40.0}
# Os padrões: cada terço da barra tem a sua sequência fixa de ondas, que se repete na mesma ordem (dá
# para aprender). Uma peça: [tipo, distância à frente do coelho (px, no sentido da fuga; negativo = entre
# ele e o Senzi), largura, altura (toco/muro/grudento) ou altura do pé (fenda)].
const PATTERNS := [
	[   # 1º terço: aprender a pular, a passar por baixo e a alternar
		[["stump", 36, 22, 10]],
		[["wall", 40, 12, 24]],
		[["hang", 34, 14, 0], ["hang", 60, 14, 0]],
		[["stump", 34, 18, 10], ["hang", 66, 14, 0]],
	],
	[   # 2º terço: o buraco, a mola (fuga) e a gosma (armadilha para ele)
		[["gap", 42, 12, 10]],
		[["spring", 34, 14, 0]],
		[["sticky", -44, 18, 12], ["wall", 40, 12, 22]],
		[["hang", 34, 14, 0], ["gap", 66, 12, 8]],
	],
	[   # último terço: combinações
		[["stump", 30, 18, 9], ["wall", 56, 12, 26], ["hang", 84, 14, 0]],
		[["gap", 36, 12, 8], ["gap", 68, 12, 14]],
		[["sticky", -44, 18, 12], ["spring", 36, 14, 0]],
		[["hang", 30, 14, 0], ["wall", 58, 12, 20], ["spring", 86, 14, 0]],
	],
]
const WAVE_EVERY := [150, 135, 120]  # quadros entre duas ondas
const SPROUT_WARN := 36              # quadros de aviso (esporos e a sombra no lugar) antes de brotar
const GAP_HOLE := 17                 # o buraco da fenda (o coelho tem 12)
const HANG_CLEAR := 20               # o vão embaixo do pendurado
const SPRING_POWER := 300.0          # como o cogumelo-mola do ato 3
const STICK_FRAMES := 60             # preso na gosma
const WALL_MAX := 8                  # pedaços (a fenda são dois)
const WALL_LIFE := 600
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
const PUNCH_MIN := 120.0             # o voo mínimo do coelho socado (px até a parede)
const FLY_FRAMES := 70               # quadros em que o coelho voando quebra o que encontra
const BELL_EVERY := 140
const RAGE_FRAMES := 45              # a pausa de raiva ao passar de um terço da barra
const DIE_FRAMES := 150

const C_SKIN := Color("d7cdb8")
const C_MUSCLE := Color("e9e3d4")
const C_GOO := Color("aca08c")
const C_JUICE := Color("70ff4a")      # o líquido da seringa
const C_GRAV := Color("7fe0d0")       # a mola: verde-água, pulsando (ela vira a gravidade)
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
var walls: Array = []          # {"rect": Rect2i, "n": Vector2 (normal da face onde nasceu), "age", "kind", "gid", "k"}
var gid_next := 0
var _wall_base := Transform2D.IDENTITY
var wave_i := 0                # a próxima onda do padrão do terço
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
var doses := 0                 # quantas vezes ele se injetou
var syringe_taken := false     # o coelho pegou a seringa
var hero_sheet: Texture2D = load(HERO_SHEET)
var hero_on := false           # o coelhão em cena (o coelho da sala, escondido)
var hx := 0.0                  # os pés do coelhão (px da sala)
var hy := 0.0
var h_vx := 0.0
var h_vy := 0.0
var h_face := 1.0
var h_jab := -1                # quadro do golpe (-1: sem golpe)
var h_kick := false            # o golpe é o chute (senão, o jab)
var h_jab_hit := false
var h_cd := 0
var h_stun := 0
var h_block := false
var h_hp := 90.0
var ring_t := 0
var act := ""                  # a ação do Senzi no ringue
var act_i := 0
var act_t := 0
var s_stun := 0
var s_push := 0.0
var s_block := false
var s_hit_done := false
var s_hp := S_HP_MAX           # a vida do Senzi no ringue (fica perdida entre os ringues)
var hitstop := 0
var bolt_t := 0
var win_deflate := false


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
		pos = Vector2(r.pw * 0.5, _inner().end.y - body_rect().size.y / 2.0)
		return
	phase = 0
	doses = 0
	syringe_taken = false
	hero_on = false
	win_deflate = false
	hitstop = 0
	bolt_t = 0
	s_hp = S_HP_MAX
	lives = LIVES
	energy = ENERGY
	wall_t = 0
	wave_i = 0
	leap_t = 0
	bell_t = 0
	t = 0
	var inn := _inner()
	# no caminho (o centro do corpo a meia altura do chão): senão, na revelação curta, o corpo grande
	# nascia enterrado no chão
	pos = _pt_of(_u_floor(inn.position.x + inn.size.x * 0.72))
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
		if w["age"] >= 0 and r.intersects(w["rect"]):
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
	return state in ["berserk", "rage", "leap_warn", "punch", "glued", "tired", "hold", "inject", "lurk", "reveal"]


func _rabbit_c() -> Vector2:
	return Vector2(room.rabbit.pos) + Vector2(6, 6)


func fighting() -> bool:
	return state in ["berserk", "rage", "leap_warn", "leap", "punch", "glued", "tired", "hold", "inject"]


## A fase da perseguição: segue a vida dele (que só cai no ringue): 0 com 3 corações, 1 com 2, 2 com 1.
func _phase() -> int:
	return clampi(3 - _s_hearts(), 0, 2)


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
	bolt_t = maxi(bolt_t - 1, 0)
	if win_deflate and hero_on and (state == "dying" or state == "dead") and t >= 60:
		# ganhou: o coelhão desincha e o coelho volta
		hero_on = false
		r.rabbit_hidden = false
		r.input_lock = false
		r.cam_focus = null
		r.rabbit.pos = Vector2i(int(hx) - 6, int(_inner().end.y) - 12)
		r.rabbit.vel = Vector2.ZERO
	_update_bells()
	_update_fly()
	if fighting():
		_age_shrooms()
	_rabbit_on_shrooms()
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
		"grabbed":
			_grabbed()
		"ring":
			_ring()
		"deflate":
			_deflate()
		"glued":
			# preso na gosma do cogumelo grudento: se debate
			if t % 8 == 0:
				r.particles.append({"pos": pos + Vector2(rng.randf_range(-10, 10), rng.randf_range(-6, 18)), "vel": Vector2(0, rng.randf_range(10, 30)),
					"life": 30, "col": C_GOO, "grav": 40.0})
			if t >= STICK_FRAMES:
				state = "berserk"
				t = 0
		"rage":
			# passou de um terço da barra: para, flexiona e ruge; volta mais rápido
			_hit_rabbit()
			if t == 10:
				r.sfx.emit("gatsby_dash")
				r.shake = maxf(r.shake, 3.0)
			if t >= RAGE_FRAMES:
				state = "berserk"
				t = 0
		"tired":
			if t % 12 == 0:
				r.particles.append({"pos": pos + _up() * 10.0 + _ahead() * 8.0, "vel": _up() * 14.0 + _ahead() * 10.0, "life": 22,
					"col": Color(1, 1, 1, 0.45), "grav": 0.0})   # o bafo, ofegando
			if t >= TIRED_FRAMES:
				state = "hold"
				t = 0
				r.sfx.emit("lock_on")
				r.shake = maxf(r.shake, 1.5)
		"hold":
			# a seringa no alto, flutuando; o coelho pode pegá-la
			if t % 5 == 0:
				var a := rng.randf() * TAU
				r.particles.append({"pos": syringe_pos() + Vector2(cos(a), sin(a)) * 6.0, "vel": Vector2(cos(a), sin(a)) * 8.0,
					"life": 16, "col": C_JUICE, "grav": 0.0})
			if Rect2(r.rabbit.rect).intersects(syringe_rect()):
				_take_syringe()
			elif t >= HOLD_FRAMES:
				state = "inject"
				t = 0
				r.sfx.emit("gatsby_dash")
		"inject":
			var stab := 3 * INJ_FAST
			var pump := 8 * INJ_FAST
			if t == stab:
				r.sfx.emit("crunch")
				r.shake = maxf(r.shake, 3.0)
			if t > stab and t < pump and t % 4 == 0:
				flash = 3   # pisca, pisca
				r.particles.append({"pos": pos + _up() * 14.0, "vel": Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 10)),
					"life": 14, "col": C_JUICE, "grav": 60.0})
			if t == pump:
				# o PUMP: a energia volta toda
				energy = ENERGY
				doses += 1
				bar_hit = 30
				pop_flash = 8
				r.shake = 8.0
				r.impact.emit(3.5)
				r.sfx.emit("blast")
				for i in 24:
					var a := rng.randf() * TAU
					r.particles.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * rng.randf_range(60.0, 200.0),
						"life": rng.randi_range(14, 28), "col": C_JUICE if i % 3 == 0 else C_SKIN, "grav": 120.0})
			if t >= INJECT_FRAMES:
				state = "berserk"
				t = 0
				phase = _phase()
				wave_i = 0
				wall_t = 0
				r.sfx.emit("gatsby_dash")
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
		u += dir * _speed(ph) / 60.0
		run_dist += _speed(ph) / 60.0
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
	if wall_t >= WAVE_EVERY[ph]:
		wall_t = 0
		_spawn_wave()
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
		_tire()


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
				# para onde: longe do Senzi, com pelo menos PUNCH_MIN de voo; se a parede daquele lado
				# está perto, para a parede adjacente (o teto, ou o outro lado se o Senzi não estiver lá)
				var to := _punch_dir()
				rb.vel = to * PUNCH_SPEED + (Vector2(0, -PUNCH_LIFT) if absf(to.x) > 0.5 else Vector2.ZERO)
				rb.launched = true
				rb.on_ground = false
				rb.var_jump = 0
				rb.coyote = 0
				fly_t = FLY_FRAMES
				# e gira a sala à força: a parede para onde o coelho voa vira o chão (ele despenca
				# até ela com o embalo do soco)
				if not room.rotating:
					room.pending_rot = 0
					if to.y < -0.5:
						_flip180()
					else:
						room._begin_rotate(1 if to.x > 0.0 else -1, true)
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


## A direção do soco: entre a fuga (longe do Senzi), o teto e o outro lado, a primeira com pelo menos
## PUNCH_MIN de espaço até a parede, nunca na direção do Senzi; se nenhuma tem, a de mais espaço.
func _punch_dir() -> Vector2:
	var inn := _inner()
	var rc := _rabbit_c()
	var away := signf(rc.x - pos.x)
	if away == 0.0:
		away = 1.0
	var to_s := (pos - rc).normalized()
	var best := Vector2(away, 0)
	var best_d := -1.0
	for d in [Vector2(away, 0), Vector2(0, -1), Vector2(-away, 0)]:
		if d.dot(to_s) > 0.5:
			continue   # nunca na direção dele
		var room_d: float = (inn.end.x - rc.x) if d.x > 0.5 else ((rc.x - inn.position.x) if d.x < -0.5 else (rc.y - inn.position.y))
		if room_d >= PUNCH_MIN:
			return d
		if room_d > best_d:
			best_d = room_d
			best = d
	return best


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
		if w["age"] >= 0 and rr.intersects(Rect2(w["rect"])):
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
	var glued := false
	for w in walls:
		if w["age"] >= 0 and br.intersects(Rect2(w["rect"])):
			energy -= float(COST.get(w["kind"], 30.0))
			bar_hit = 14
			room.shake = maxf(room.shake, 2.5)
			room.sfx.emit("crunch")
			var c := Rect2(w["rect"]).get_center()
			var cols := _shroom_cols(w["kind"])
			for i in 10:
				room.particles.append({"pos": c, "vel": Vector2(rng.randf_range(-90, 90), -rng.randf_range(20, 110)),
					"life": rng.randi_range(12, 24), "col": cols[0] if i % 2 else cols[1], "grav": 300.0})
			if w["kind"] == "sticky":
				glued = true
		else:
			keep.append(w)
	walls = keep
	if glued and state == "berserk":
		state = "glued"
		t = 0
		flash = 10
		room.sfx.emit("steam_burst")


## O coelho pisando na mola: ela o joga para o alto e a gravidade vira (a sala gira 180° de uma vez):
## o coelho sai disparado para o lado de lá, que agora é o chão, e o Senzi fica lá em cima.
func _rabbit_on_shrooms() -> void:
	var rb = room.rabbit
	if not rb.on_ground or fly_t > 0 or room.state != "play" or room.rotating:
		return
	var feet := Rect2(rb.rect.position.x, rb.rect.end.y, rb.rect.size.x, 1)
	for w in walls:
		if w["age"] < 0 or w["kind"] != "spring" or not feet.intersects(Rect2(w["rect"])):
			continue
		var c := Rect2(w["rect"]).get_center()
		walls.erase(w)
		rb.vel.y = -SPRING_POWER
		rb.launched = true
		rb.var_jump = 0
		rb.on_ground = false
		rb.coyote = 0
		rb.jumping = true
		rb.squash = Vector2(0.7, 1.35)
		room.sfx.emit("spring")
		room.sfx.emit("limiter")
		room.shake = maxf(room.shake, 4.0)
		for i in 16:
			var a := rng.randf() * TAU
			room.particles.append({"pos": c, "vel": Vector2(cos(a), sin(a)) * rng.randf_range(30, 140),
				"life": rng.randi_range(12, 26), "col": C_GRAV if i % 2 else Color("d9f5ef"), "grav": 0.0})
		_flip180()
		return


## A gravidade vira: a sala gira 180° de uma vez (como o limitador desfazendo dois giros).
func _flip180() -> void:
	room.pending_rot = 0
	room._rotate_logic(1)
	room._rotate_logic(1)
	room.rotating = true
	room.rot_frame = 0
	room.rot_len = room.ROT_FRAMES * 3 / 2
	room.rot_from = -PI
	room.view_angle = room.rot_from
	room.rot_lock_max = room.reload_frames
	room.rot_lock = room.rot_lock_max


## A próxima onda do padrão do terço: as peças brotam, cada uma no seu lugar em relação ao coelho, no
## sentido da fuga (longe do Senzi). Se não couber à frente (o coelho encostado na parede), a onda vira
## para o outro lado. Antes de brotar, um aviso no lugar (esporos e a sombra).
func _spawn_wave() -> void:
	var waves: Array = PATTERNS[_phase()]
	var wave: Array = waves[wave_i % waves.size()]
	wave_i += 1
	var inn := _inner()
	var rc := _rabbit_c()
	var away := signf(rc.x - pos.x)
	if away == 0.0:
		away = 1.0
	var reach := 0.0
	for pc in wave:
		reach = maxf(reach, float(pc[1]) + float(pc[2]))
	var room_ahead := (inn.end.x - rc.x) if away > 0.0 else (rc.x - inn.position.x)
	if room_ahead < reach + 8.0:
		away = -away
	gid_next += 1
	for pc in wave:
		for piece in _piece_rects(pc, rc.x + away * float(pc[1]), away):
			var r: Rect2i = piece[0]
			if Rect2(r).grow(3.0).intersects(Rect2(room.rabbit.rect)) or Rect2(r).grow(4.0).intersects(body_rect()):
				continue
			if walls.size() >= WALL_MAX:
				walls.pop_front()
			walls.append({"rect": r, "n": piece[1], "age": -SPROUT_WARN, "kind": pc[0], "gid": gid_next, "k": 0.0, "seed": rng.randi()})
	room.sfx.emit("plate_on")


## Os retângulos de uma peça (a fenda são dois), com a normal da face onde nasce.
func _piece_rects(pc: Array, cx: float, away: float) -> Array:
	var inn := _inner()
	var fl := int(inn.end.y)
	var ce := int(inn.position.y)
	var kind: String = pc[0]
	var ww: int = pc[2]
	var x := int(clampf(cx - ww / 2.0, inn.position.x + 4.0, inn.end.x - 4.0 - ww))
	match kind:
		"stump", "wall", "sticky":
			var h: int = pc[3]
			return [[Rect2i(x, fl - h, ww, h), Vector2(0, -1)]]
		"hang":
			return [[Rect2i(x, ce, ww, fl - HANG_CLEAR - ce), Vector2(0, 1)]]
		"gap":
			var hb: int = pc[3]
			return [[Rect2i(x, fl - hb, ww, hb), Vector2(0, -1)], [Rect2i(x, ce, ww, fl - hb - GAP_HOLE - ce), Vector2(0, 1)]]
		"spring":
			return [[Rect2i(x, fl - 7, ww, 7), Vector2(0, -1)]]
	return []


## Os cogumelos envelhecem: o aviso conta até brotar (esporos subindo do lugar); depois de um tempo,
## murcham e somem.
func _age_shrooms() -> void:
	for w in walls:
		w["age"] += 1
		w["k"] = maxf(float(w.get("k", 0.0)) - 0.1, 0.0)
		if w["age"] < 0 and w["age"] % 6 == 0:
			var r := Rect2(w["rect"])
			var n: Vector2 = w["n"]
			var at := Vector2(rng.randf_range(r.position.x, r.end.x), r.end.y if n.y < 0 else r.position.y)
			room.particles.append({"pos": at, "vel": n * rng.randf_range(10, 30), "life": 18,
				"col": _shroom_cols(w["kind"])[0], "grav": 0.0})
		if w["age"] == 0:
			room.sfx.emit("crunch")
	walls = walls.filter(func(w): return w["age"] < WALL_LIFE)
	_unstick_rabbit()


## Um cogumelo que brotou (ou girou) em cima do coelho não o prende: o coelho sai pela ponta dele,
## num pulinho para fora (para cima, no do chão; para baixo, no do teto).
func _unstick_rabbit() -> void:
	var rb = room.rabbit
	if hero_on:
		return
	for w in walls:
		if w["age"] < 0:
			continue
		var r: Rect2i = w["rect"]
		var rr: Rect2i = rb.rect
		if not rr.intersects(r):
			continue
		var n: Vector2 = w["n"]
		var p: Vector2i = rb.pos
		if n.y < -0.5:
			p.y = r.position.y - rr.size.y
		elif n.y > 0.5:
			p.y = r.end.y
		elif n.x > 0.5:
			p.x = r.end.x
		else:
			p.x = r.position.x - rr.size.x
		rb.pos = p
		rb.vel = n * 120.0 if absf(n.y) > 0.5 else Vector2(n.x * 80.0, -80.0)
		rb.on_ground = false
		rb.launched = false


func _speed(ph: int) -> float:
	return float(SPEED[ph]) * (1.0 + DOSE_SPEED * doses)


## Para dentro da sala, a partir da superfície em que ele está.
func _up() -> Vector2:
	return _surf_n() if _stuck() else Vector2(0, -1)


## Sem energia: para, cansado (e depois a seringa).
func _tire() -> void:
	energy = 0.0
	state = "tired"
	t = 0
	bells.clear()
	room.sfx.emit("steam_burst")
	room.shake = maxf(room.shake, 2.0)


## Onde a seringa flutua: acima da mão aberta, no alto (gira com ele, na superfície em que está).
func syringe_pos() -> Vector2:
	var flip := -1.0 if dir < 0 else 1.0
	var h := BODY.y / 2.0
	var local := Vector2((HAND_UP.x - FRAME.x / 2.0) * flip, h - FEET + HAND_UP.y - SYRINGE_FLOAT + sin(anim * 0.1) * 1.5)
	return pos + local.rotated(Vector2(0, -1).angle_to(_up()))


func syringe_rect() -> Rect2:
	var c := syringe_pos()
	return Rect2(c - Vector2(9, 16), Vector2(18, 32))


## O coelho pegou a seringa: sem a dose, ele cai (por enquanto, morre).
func _take_syringe() -> void:
	syringe_taken = true
	var c := syringe_pos()
	room.sfx.emit("gate_open")
	for i in 20:
		var a := rng.randf() * TAU
		room.particles.append({"pos": c, "vel": Vector2(cos(a), sin(a)) * rng.randf_range(30.0, 140.0),
			"life": rng.randi_range(12, 26), "col": C_JUICE if i % 2 else Color(1, 1, 1), "grav": 0.0})
	room.particles.append({"pos": c, "vel": Vector2.ZERO, "life": 12, "col": C_JUICE, "grav": 0.0, "ring": 5.0})
	_start_grab()


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
	_wall_base = base
	_draw_walls()
	for b in bells:
		draw_set_transform_matrix(base * Transform2D(b["age"] * 0.3, (b["pos"] as Vector2).round()))
		draw_rect(Rect2(-5, -1, 10, 2), Color("6a6d75"))
		draw_rect(Rect2(-6, -3, 3, 6), Color("2b2c33"))
		draw_rect(Rect2(3, -3, 3, 6), Color("2b2c33"))
		draw_rect(Rect2(-6, -3, 3, 1), Color("8a8d95"))
		draw_rect(Rect2(3, -3, 3, 1), Color("8a8d95"))
	_draw_snail(base)
	if hero_on:
		_draw_hero(base)
	if bolt_t > 0:
		_draw_bolt(base)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_hud()


## As cores de cada tipo: [chapéu, talo, lamelas (embaixo do chapéu), pintas].
func _shroom_cols(kind: String) -> Array:
	match kind:
		"stump":
			return [Color("7c6596"), Color("bdb3c9"), Color("4e3f63"), Color("c9b6dd")]
		"hang":
			return [Color("b98ee0"), Color("a99fb4"), Color("6e5a8c"), Color("f1e6fb")]
		"gap":
			return [Color("c58cff"), Color("cfc6d8"), Color("6e4a82"), Color("f6ecff")]
		"spring":
			return [C_GRAV, Color("d9f5ef"), Color("2f8a7c"), Color(1, 1, 1)]
		"sticky":
			return [C_SKIN, C_MUSCLE, C_GOO, Color(1, 1, 1)]
	return [Color("9b6bc4"), Color("cfc6d8"), Color("5e3f70"), Color("e7d6f5")]   # muro


func _draw_walls() -> void:
	var base := _wall_base
	for w in walls:
		var r := Rect2(w["rect"])
		var n: Vector2 = w["n"]
		# o referencial do cogumelo: a origem no meio do pé, "para cima" = para dentro da sala (n)
		var foot: Vector2
		var W: float
		var H: float
		if absf(n.y) > 0.5:
			foot = Vector2(r.get_center().x, r.end.y if n.y < 0 else r.position.y)
			W = r.size.x
			H = r.size.y
		else:
			foot = Vector2(r.end.x if n.x < 0 else r.position.x, r.get_center().y)
			W = r.size.y
			H = r.size.x
		draw_set_transform_matrix(base * Transform2D(Vector2(0, -1).angle_to(n), foot.round()))
		_draw_shroom(w, W, H)
	draw_set_transform_matrix(base)


## Um cogumelo em pixel art, de pé no referencial dele (o pé em 0, crescendo para -y).
func _draw_shroom(w: Dictionary, W: float, H: float) -> void:
	var kind: String = w["kind"]
	var cols := _shroom_cols(kind)
	var cap: Color = cols[0]
	var stem_c: Color = cols[1]
	var gill: Color = cols[2]
	var spot: Color = cols[3]
	var age: int = w["age"]
	var hw := floorf(W / 2.0)
	if age < 0:
		# o aviso: a sombra no chão e o contorno de onde vai brotar, piscando cada vez mais rápido
		var k0 := 1.0 - float(-age) / SPROUT_WARN
		var blink := (age / maxi(2, int(8 - k0 * 6))) % 2 == 0
		draw_rect(Rect2(-hw - 1, -1, W + 2, 1), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(-hw, -2, W, 1), Color(cap, 0.25 + 0.35 * k0))
		if blink:
			draw_rect(Rect2(-hw, -H, W, H), Color(cap, 0.08 + 0.1 * k0), false, 1.0)
		return
	var k := clampf(float(age) / 8.0, 0.0, 1.0)
	var squash := float(w.get("k", 0.0)) * 3.0
	var Hs := maxf(3.0, roundf(H * k - squash))
	var wilt := age > WALL_LIFE - 60 and (anim / 4) % 2 == 0
	if wilt:
		cap = cap.darkened(0.3)
		stem_c = stem_c.darkened(0.3)
	var seed: int = int(w.get("seed", 0))
	if kind == "sticky":
		# um monte de gosma em cúpula, mole, que treme e escorre
		var wob := roundf(sin(anim * 0.12 + seed % 7) * 1.0)
		var rows := int(Hs + wob)
		for i in rows:
			var f := sqrt(clampf(1.0 - pow(1.0 - float(i + 1) / rows, 2.0), 0.0, 1.0))
			var wi := maxf(2.0, roundf(W * f))
			var y := -rows + i
			draw_rect(Rect2(-floorf(wi / 2.0), y, wi, 1), cap if i < rows - 2 else gill)
			if i > 0 and i < rows - 2:
				draw_rect(Rect2(-floorf(wi / 2.0), y, 1, 1), stem_c)
		draw_rect(Rect2(-hw - 2, -1, W + 4, 1), gill)            # a poça
		for q in 3:
			var dx := float((seed >> (q * 3)) % int(maxf(W - 2.0, 1.0))) - hw + 1.0
			var dl := 1.0 + fposmod(anim * 0.04 + q * 1.3, 3.0)
			draw_rect(Rect2(dx, -rows + 2 + q, 1, dl), gill)
		draw_rect(Rect2(-hw + 3, -rows + 1, 2, 1), Color(1, 1, 1, 0.8))  # brilho molhado
		if (anim / 20 + seed) % 3 == 0:
			draw_rect(Rect2(hw - 4, -rows - 1, 1, 1), stem_c)  # uma bolha
		return
	# o chapéu: cúpula (o toco é uma prateleira achatada; o da mola, gordo)
	var ch := 6.0
	var CW := W + 4.0
	match kind:
		"stump":
			ch = 4.0
			CW = W + 2.0
		"spring":
			ch = 5.0
			CW = W + 2.0 + squash * 0.7
		"hang":
			ch = 7.0
	ch = minf(ch, Hs)
	var sw := maxf(3.0, roundf(W * (0.6 if kind == "stump" else (0.3 if kind == "hang" else 0.42))))
	var top := -Hs
	# o talo
	var st_h := Hs - ch + 1.0
	if st_h > 0.0:
		draw_rect(Rect2(-floorf(sw / 2.0), top + ch - 1.0, sw, st_h), stem_c)
		draw_rect(Rect2(-floorf(sw / 2.0) + sw - 1.0, top + ch - 1.0, 1, st_h), stem_c.darkened(0.2))
		draw_rect(Rect2(-floorf(sw / 2.0), top + ch - 1.0, sw, 1), gill.darkened(0.1))   # a sombra do chapéu
		if kind == "wall" or kind == "gap" or kind == "hang":
			var ry := roundf(top + ch + st_h * 0.3)
			draw_rect(Rect2(-floorf(sw / 2.0) - 1.0, ry, sw + 2.0, 1), stem_c.darkened(0.12))   # o anel
		if kind == "spring":
			# setinhas: sobe e vira
			draw_rect(Rect2(-1, top + ch + 1.0, 1, 2), gill)
			draw_rect(Rect2(1, top + ch + 1.0, 1, 2), gill)
	# o pé (micélio)
	draw_rect(Rect2(-floorf(sw / 2.0) - 2.0, -1.0, sw + 4.0, 1), Color("d9cfe6").darkened(0.15))
	draw_rect(Rect2(-floorf(sw / 2.0) - 3.0, -1.0, 1, 1), Color("d9cfe6").darkened(0.3))
	draw_rect(Rect2(floorf(sw / 2.0) + 2.0, -1.0, 1, 1), Color("d9cfe6").darkened(0.3))
	# o chapéu
	for i in int(ch):
		var f := 1.0 if kind == "stump" and i > 0 else sqrt(clampf(1.0 - pow(1.0 - float(i + 1) / ch, 2.0), 0.0, 1.0))
		var wi := maxf(2.0, roundf(CW * (0.45 + 0.55 * f)))
		var y := top + i
		var c := cap
		if i == 0:
			c = cap.lightened(0.25)
		elif i == int(ch) - 1:
			c = gill   # as lamelas
		draw_rect(Rect2(-floorf(wi / 2.0), y, wi, 1), c)
		if i > 0 and i < int(ch) - 1:
			draw_rect(Rect2(-floorf(wi / 2.0), y, 1, 1), cap.lightened(0.2))
			draw_rect(Rect2(-floorf(wi / 2.0) + wi - 1.0, y, 1, 1), cap.darkened(0.2))
	# as pintas
	var ns := 2 if CW < 14.0 else 3
	for q in ns:
		var sx := float((seed >> (q * 4)) % int(maxf(CW - 6.0, 1.0))) - floorf(CW / 2.0) + 3.0
		var sy := top + 1.0 + float((seed >> (q * 4 + 2)) % maxi(int(ch) - 2, 1))
		draw_rect(Rect2(sx, sy, 2 if q == 0 else 1, 1), spot)
	if kind == "hang":
		# fios de micélio pendurados na borda do chapéu
		for q in 3:
			var hx := -floorf(CW / 2.0) + 2.0 + q * floorf((CW - 4.0) / 2.0)
			draw_rect(Rect2(hx, top - 1.0 - (q % 2), 1, 1 + (q % 2)), Color(spot, 0.6))
	if kind == "spring":
		# pulsa: um brilho que corre por cima do chapéu
		var pulse := 0.5 + 0.5 * sin(anim * 0.2)
		var gw := roundf(CW * 0.45)
		draw_rect(Rect2(-floorf(gw / 2.0), top - 1.0, gw, 1), Color(C_GRAV, 0.25 + 0.5 * pulse))


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
		# no chão: grudado, a meia altura do caminho; solto (morto), embaixo do corpo caído
		var ground := pos - n * (h - 3.0) if _stuck() else pos + Vector2(0, body_rect().size.y / 2.0 - 3.0)
		draw_set_transform_matrix(base * Transform2D(ang, ground.round()) * Transform2D(0.0, Vector2(flip, 1), 0.0, Vector2.ZERO))
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
		"glued":
			anim_name = "idle"
			fr = (anim / 3) % 4
		"grabbed":
			anim_name = "hit" if t < G_BOLT else ("flex" if t >= G_ROAR else "guard")
			fr = (anim / 6) % 2 if t < G_BOLT else (mini((t - G_ROAR) / 4, 5) if t >= G_ROAR else (anim / 9) % 4)
		"deflate":
			anim_name = "guard"
			fr = (anim / 9) % 4
		"ring":
			anim_name = "guard"
			fr = (anim / 9) % 4
			if s_stun > 0 and not s_block:
				anim_name = "hit"
				fr = 0 if s_stun > S_STUN / 2 else 1
			else:
				match act:
					"approach", "retreat":
						anim_name = "walk"
						fr = int(run_dist / 4.0) % 6
					"guard":
						anim_name = "block"
						fr = 0
					"jab", "charge":
						var wind := SJAB_WIND if act == "jab" else SCHARGE_WIND
						anim_name = "punch"
						fr = 0 if act_t <= wind else (1 if act_t <= wind + 4 else (2 if act_t <= wind + 8 else 3))
					"leap":
						anim_name = "leap"
						fr = 1 + (anim / 4) % 2
		"tired":
			anim_name = "tired"
			fr = (anim / 7) % 4
		"hold":
			anim_name = "hold"
			fr = (anim / 9) % 4
		"inject":
			anim_name = "inject"
			fr = t / INJ_FAST if t < 8 * INJ_FAST else mini(8 + (t - 8 * INJ_FAST) / INJ_PUMP, 11)
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
	if state == "inject" and white:
		mod = Color(2.4, 2.6, 2.4)   # pisca: branco
	if state == "inject" and t >= 8 * INJ_FAST:
		sc *= 1.0 + 0.08 * maxf(0.0, 1.0 - float(t - 8 * INJ_FAST) / float(4 * INJ_PUMP))   # o PUMP
	draw_set_transform_matrix(base * Transform2D(ang, pos.round()) * Transform2D(0.0, Vector2(sc * flip, sc), 0.0, Vector2.ZERO))
	var src := Rect2(Vector2(fr, row) * FRAME, FRAME)
	var hd := body_rect().size.y / 2.0 if (state == "dying" or state == "dead") else h
	if state == "leap" or (state == "ring" and act == "leap" and s_stun == 0):
		# a cambalhota: uma volta inteira, para a frente, em torno da bola encolhida
		var k := clampf(float(t if state == "leap" else act_t) / LEAP_FRAMES, 0.0, 1.0)
		var c := Vector2(TUCK.x, hd + TUCK.y)
		draw_set_transform_matrix(base * Transform2D(ang, pos.round()) * Transform2D(0.0, Vector2(sc * flip, sc), 0.0, Vector2.ZERO)
			* Transform2D(0.0, c) * Transform2D(k * TAU, Vector2.ZERO) * Transform2D(0.0, -c))
	draw_texture_rect_region(sheet, Rect2(Vector2(-FRAME.x / 2.0, hd - FEET), FRAME), src, mod)
	draw_set_transform_matrix(base)
	if state == "hold":
		_draw_syringe(base * Transform2D(ang, syringe_pos().round()), clampf(float(t) / 10.0, 0.0, 1.0), 2.0)


## A seringa flutuando, bem destacada: de pé, a agulha para cima, o líquido verde brilhando, com um
## halo que pulsa. Desenhada com o centro na origem.
func _draw_syringe(xf: Transform2D, k: float, size := 1.0) -> void:
	draw_set_transform_matrix(xf)
	var pulse := 0.5 + 0.5 * sin(anim * 0.25)
	var g := size * k
	draw_circle(Vector2.ZERO, (10.0 + 2.5 * pulse) * g, Color(C_JUICE, 0.1 + 0.1 * pulse))
	draw_circle(Vector2.ZERO, 6.5 * g, Color(C_JUICE, 0.16))
	for q in 6:
		var a := anim * 0.05 + q * TAU / 6.0
		var d := Vector2(cos(a), sin(a))
		draw_line(d * 8.5 * g, d * (11.5 + 2.5 * pulse) * g, Color(C_JUICE, 0.55), 1.0)
	draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(g, g), 0.0, Vector2.ZERO))
	draw_rect(Rect2(-0.5, -9, 1, 4), Color("d6dae2"))          # a agulha
	draw_rect(Rect2(-1.5, -5, 3, 1), Color("8a929e"))          # o bico
	draw_rect(Rect2(-2, -4, 4, 9), Color("3c5c54"))            # o vidro (contorno)
	draw_rect(Rect2(-1, -4, 2, 8), Color("cfe8e2"))
	draw_rect(Rect2(-1, -3, 2, 6), C_JUICE)                    # o líquido
	draw_rect(Rect2(-1, -3, 1, 6), C_JUICE.lightened(0.5))
	draw_rect(Rect2(-3, 5, 6, 1), Color("3c5c54"))             # as abas
	draw_rect(Rect2(-0.5, 6, 1, 2), Color("d6dae2"))           # o êmbolo
	draw_rect(Rect2(-2, 8, 4, 1), Color("d6dae2"))
	draw_set_transform_matrix(_wall_base)


func _draw_hud() -> void:
	if pop_flash > 0:
		draw_rect(Rect2(-200, -120, 400, 240), Color(1, 1, 1, 0.12 * pop_flash))
	if hero_on and state in ["grabbed", "ring", "deflate"]:
		if state != "grabbed" or t >= G_ROAR:
			_draw_ring_hud()
		return
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
	if syringe_taken:
		_draw_syringe(Transform2D(0.0, Vector2(-26, y + 9)), 1.0)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	# a energia do Senzi (sem divisões) e, ao lado, os corações dele (a vida, que só cai no ringue)
	var bar := Rect2(-18, y + 5, 67, 8)
	draw_rect(bar.grow(1.0), Color(0.05, 0.05, 0.08, 0.85))
	var k := clampf(energy / ENERGY, 0.0, 1.0)
	var col := Color(1, 1, 1) if bar_hit > 0 and (bar_hit / 3) % 2 == 0 else C_ENERGY
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), col)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, 2)), col.lightened(0.35))
	draw_rect(bar.grow(1.0), Color(0.89, 0.87, 0.81, 0.8), false, 1.0)
	for i in 3:
		_draw_heart(Vector2(bar.end.x + 5 + i * 9, y + 6), i < _s_hearts(), C_ENERGY)


func _draw_heart(q: Vector2, full: bool, col := C_HEART) -> void:
	var c := col if full else C_HEART_EMPTY
	draw_rect(Rect2(q + Vector2(1, 0), Vector2(2, 1)), c)
	draw_rect(Rect2(q + Vector2(4, 0), Vector2(2, 1)), c)
	draw_rect(Rect2(q + Vector2(0, 1), Vector2(7, 2)), c)
	draw_rect(Rect2(q + Vector2(1, 3), Vector2(5, 1)), c)
	draw_rect(Rect2(q + Vector2(2, 4), Vector2(3, 1)), c)
	draw_rect(Rect2(q + Vector2(3, 5), Vector2(1, 1)), c)


# ================================================================ o ringue (D114)
# O coelho pega a seringa e se injeta: a gravidade volta ao normal, cai um raio nele e ele vira o
# coelhão. Por 12 s é uma luta 2D: os dois no chão, de frente um para o outro; o coelho anda, pula,
# defende andando para trás e dá jab (os dois botões de giro). Cada um tem uma barra de vida em três
# terços (um coração por terço). Nocaute no Senzi: ele cai. Acabou o tempo: o coelhão desincha e a
# perseguição recomeça (a vida perdida do Senzi fica perdida).

## A transformação: congela, a sala volta ao normal (ele se solta e cai), o raio, os estouros, o rugido.
func _start_grab() -> void:
	state = "grabbed"
	t = 0
	walls.clear()
	bells.clear()
	fly_t = 0
	vel = Vector2.ZERO
	room.input_lock = true
	room.allow_rotate = false
	room.pending_rot = 0
	room.shake = maxf(room.shake, 3.0)
	room.sfx.emit("gate_open")


func _grabbed() -> void:
	var r = room
	if t == G_UNROT:
		# a gravidade volta ao normal: a sala gira de volta à orientação de antes de tudo
		var o := posmod(int(r.orientation), 4)
		if o != 0 and not r.rotating:
			var d := -1 if o == 1 else 1
			var k := 2 if o == 2 else 1
			for i in k:
				r._rotate_logic(d)
			r.rotating = true
			r.rot_frame = 0
			r.rot_len = r.ROT_FRAMES * 2
			r.rot_from = -d * k * PI / 2.0
			r.view_angle = r.rot_from
			r.sfx.emit("limiter")
	if t > G_UNROT:
		_fall()   # solto, cai no chão
	if t == G_BOLT:
		var rb = r.rabbit
		hx = float(rb.pos.x) + 6.0
		hy = float(rb.pos.y) + 12.0
		h_face = signf(pos.x - hx) if pos.x != hx else 1.0
		bolt_t = BOLT_FRAMES
		r.shake = 9.0
		r.impact.emit(5.0)
		r.sfx.emit("blast")
		r.rabbit_hidden = true
		hero_on = true
		for i in 24:
			var a := rng.randf() * TAU
			r.particles.append({"pos": Vector2(hx, hy - 6.0), "vel": Vector2(cos(a), sin(a)) * rng.randf_range(40.0, 180.0),
				"life": rng.randi_range(10, 24), "col": Color("fff6a0") if i % 2 else Color(1, 1, 1), "grav": 60.0})
	if t in G_POPS:
		var k := G_POPS.find(t)
		pop_flash = 8
		r.shake = maxf(r.shake, 4.0 + 2.0 * k)
		r.impact.emit(1.5 + 0.8 * k)
		r.sfx.emit("blast" if k == 2 else "slam")
	if t == G_ROAR:
		r.sfx.emit("gatsby_dash")
	if hero_on:
		r.cam_focus = Vector2((hx + pos.x) / 2.0, hy - 40.0)
	if t >= G_END:
		_ring_begin()


func _ring_begin() -> void:
	state = "ring"
	t = 0
	ring_t = RING_FRAMES
	h_hp = float(lives) * H_HP_HEART
	h_vx = 0.0
	h_vy = 0.0
	h_jab = -1
	h_stun = 0
	act_i = 0
	act = ""
	act_t = 0
	s_stun = 0
	pos.y = _inner().end.y - BODY.y / 2.0
	room.input_lock = true
	room.allow_rotate = false


## O coração de cada um: um por terço da barra.
func _s_hearts() -> int:
	return clampi(ceili(s_hp / S_HP_HEART - 0.001), 0, 3)


func _h_hearts() -> int:
	return clampi(ceili(h_hp / H_HP_HEART - 0.001), 0, 3)


func _ring() -> void:
	var r = room
	if hitstop > 0:
		hitstop -= 1
		return
	ring_t -= 1
	if ring_t <= 0:
		_ring_end()
		return
	if ring_t == 180:
		r.sfx.emit("lock_on")   # 3 s: o efeito está acabando
	var inn := _inner()
	var fl := inn.end.y
	var lo := inn.position.x + 14.0
	var hi := inn.end.x - 14.0
	var sx := pos.x
	# ---- o coelhão
	var inp: Dictionary = r.raw_inp
	var mv := float(inp.get("move", 0.0))
	h_face = 1.0 if sx >= hx else -1.0
	h_block = false
	h_stun = maxi(h_stun - 1, 0)
	if h_stun > 0:
		h_vx = move_toward(h_vx, 0.0, 12.0)
		h_jab = -1
	else:
		var rq := int(inp.get("rotate", 0))
		if rq != 0 and h_jab < 0 and h_cd == 0:
			# giro esquerdo: jab; giro direito: chute
			h_kick = rq > 0
			h_jab = 0
			h_cd = (HKICK_TOTAL if h_kick else HJAB_TOTAL) + 2
			r.sfx.emit("jump" if h_kick else "thump")
		var ground := hy >= fl - 0.5
		var back := absf(mv) > 0.2 and signf(mv) == -h_face
		h_block = back and ground and h_jab < 0
		var spd := H_WALK * (0.6 if h_block else 1.0)
		h_vx = mv * spd if h_jab < 0 or not ground else move_toward(h_vx, 0.0, 20.0)
		if bool(inp.get("jump", false)) and ground and h_jab < 0:
			h_vy = -H_JUMP
			r.sfx.emit("jump")
	h_cd = maxi(h_cd - 1, 0)
	h_vy += GRAV / 60.0
	hx += h_vx / 60.0
	hy = minf(hy + h_vy / 60.0, fl)
	if hy >= fl:
		h_vy = 0.0
	if h_jab >= 0:
		h_jab += 1
		var hit_at := HKICK_HIT if h_kick else HJAB_HIT
		if h_jab >= hit_at and h_jab < hit_at + 3 and not h_jab_hit:
			if absf(sx - hx) < (HKICK_REACH if h_kick else HJAB_REACH) and s_air() < 20.0:
				h_jab_hit = true
				_hit_senzi(HKICK_DMG if h_kick else HJAB_DMG, h_kick)
		if h_jab >= (HKICK_TOTAL if h_kick else HJAB_TOTAL):
			h_jab = -1
			h_jab_hit = false
	# ---- o Senzi
	s_stun = maxi(s_stun - 1, 0)
	s_block = false
	if s_stun > 0:
		pos.x += s_push / 60.0
		s_push = move_toward(s_push, 0.0, 8.0)
	else:
		_s_act()
	# os corpos não se atravessam; as paredes seguram
	var gap := 26.0
	if absf(pos.x - hx) < gap and s_air() < 20.0 and hy > fl - 30.0:
		var mid := (pos.x + hx) / 2.0
		var sd := 1.0 if pos.x >= hx else -1.0
		pos.x = mid + sd * gap / 2.0
		hx = mid - sd * gap / 2.0
	pos.x = clampf(pos.x, lo, hi)
	hx = clampf(hx, lo, hi)
	r.cam_focus = Vector2((hx + pos.x) / 2.0, fl - 40.0)
	# o coelho da sala vai junto (escondido), para a porta e o resto do jogo saberem onde ele está
	r.rabbit.pos = Vector2i(int(hx) - 6, int(fl) - 12)
	r.rabbit.vel = Vector2.ZERO


## A altura dele acima do chão (no pulo).
func s_air() -> float:
	return (_inner().end.y - BODY.y / 2.0) - pos.y


## O Senzi no ringue segue um padrão por coração (como os cogumelos: dá para aprender).
func _s_act() -> void:
	var seq: Array = RING_PATTERNS[clampi(3 - _s_hearts(), 0, 2)]
	if act == "":
		act = seq[act_i % seq.size()]
		act_i += 1
		act_t = 0
	act_t += 1
	var dx := hx - pos.x
	var dist := absf(dx)
	var toward := signf(dx) if dx != 0.0 else 1.0
	dir = toward
	var spd := S_WALK * (1.0 + 0.15 * (3 - _s_hearts()))
	match act:
		"approach":
			if dist > S_RANGE:
				pos.x += toward * spd / 60.0
				run_dist += spd / 60.0
			if dist <= S_RANGE or act_t > 150:
				act = ""
		"retreat":
			pos.x -= toward * spd * 0.8 / 60.0
			run_dist += spd / 60.0
			if act_t > 30:
				act = ""
		"guard":
			s_block = true
			if act_t > 40:
				act = ""
		"jab", "charge":
			var wind := SJAB_WIND if act == "jab" else SCHARGE_WIND
			if act_t == 1 and dist > S_RANGE + 8.0:
				act = "approach"   # longe: chega antes
				act_i -= 1
				return
			if act == "charge" and act_t % 6 == 0 and act_t < wind:
				flash = 3
				room.sfx.emit("lock_on")
			if act == "charge" and act_t > wind and act_t <= wind + 6:
				pos.x += toward * 7.0   # a investida
			if act_t == wind + 1:
				room.sfx.emit("blast" if act == "charge" else "thump")
			if act_t >= wind + 1 and act_t <= wind + 4 and not s_hit_done:
				var reach := SJAB_REACH + (24.0 if act == "charge" else 0.0)
				if dist < reach and hy > _inner().end.y - 34.0:
					s_hit_done = true
					_hit_hero(SJAB_DMG if act == "jab" else SCHARGE_DMG, act == "charge")
			if act_t >= wind + (14 if act == "jab" else 24):
				act = ""
				s_hit_done = false
		"leap":
			# a cambalhota por cima, caindo no coelho (dá para defender)
			if act_t == 1:
				leap_from = pos
				leap_to = Vector2(clampf(hx, _inner().position.x + 14.0, _inner().end.x - 14.0), pos.y)
				room.sfx.emit("gatsby_dash")
			var k := clampf(float(act_t) / LEAP_FRAMES, 0.0, 1.0)
			pos = leap_from.lerp(leap_to, k) + Vector2(0, -sin(k * PI) * LEAP_HIGH)
			if act_t == LEAP_FRAMES:
				pos = leap_to
				room.shake = maxf(room.shake, 4.0)
				room.sfx.emit("slam")
				if absf(hx - pos.x) < 30.0:
					_hit_hero(SLEAP_DMG, false)
				act = ""


func _hit_senzi(dmg: float, kick := false) -> void:
	var sd := signf(pos.x - hx) if pos.x != hx else 1.0
	if kick and s_block:
		# o chute quebra a defesa: ele cambaleia
		_spark(Vector2(pos.x - sd * 12.0, pos.y - 10.0), Color("ffd27a"))
		room.sfx.emit("blast")
	if s_block and not kick:
		s_hp -= dmg * 0.2
		room.sfx.emit("plate_on")
		hitstop = 2
		_spark(Vector2(pos.x - sd * 12.0, pos.y - 10.0), Color("cfe8ff"))
		s_push = sd * 60.0
		s_stun = 4
		return
	var hearts0 := _s_hearts()
	s_hp -= dmg
	s_stun = S_STUN + (8 if kick else 0)
	s_push = sd * (170.0 if kick else 90.0)
	act = ""
	s_hit_done = false
	hitstop = 4
	flash = 6
	bar_hit = 10
	room.shake = maxf(room.shake, 2.5)
	room.sfx.emit("crunch")
	_spark(Vector2(pos.x - sd * 12.0, pos.y - 14.0), Color(1, 1, 1))
	if _s_hearts() < hearts0:
		room.shake = 6.0
		room.impact.emit(3.0)
		room.sfx.emit("blast")
		act_i = 0
	if s_hp <= 0.0:
		_ring_win()


func _hit_hero(dmg: float, unblockable: bool) -> void:
	var sd := signf(hx - pos.x) if hx != pos.x else 1.0
	if h_block and not unblockable:
		h_hp -= dmg * 0.2
		room.sfx.emit("plate_on")
		hitstop = 2
		h_vx = sd * 80.0
		_spark(Vector2(hx - sd * 10.0, hy - 50.0), Color("cfe8ff"))
	else:
		h_hp -= dmg
		h_stun = H_STUN if not unblockable else H_STUN * 2
		h_vx = sd * (260.0 if unblockable else 110.0)
		h_vy = -150.0 if unblockable else 0.0
		h_jab = -1
		hitstop = 4 if not unblockable else 8
		hud_hit = 30
		room.shake = maxf(room.shake, 3.0 if not unblockable else 8.0)
		room.impact.emit(1.5 if not unblockable else 4.0)
		room.sfx.emit("death" if unblockable else "crunch")
		_spark(Vector2(hx - sd * 10.0, hy - 50.0), Color(1, 0.7, 0.7))
	lives = maxi(_h_hearts(), 0)
	if h_hp <= 0.0:
		# nocaute: a fase recomeça do começo
		hero_on = false
		room.rabbit_hidden = false
		room.input_lock = false
		room.invuln = 0
		lives = 1
		room.kill()


func _spark(at: Vector2, col: Color) -> void:
	room.particles.append({"pos": at, "vel": Vector2.ZERO, "life": 8, "col": col, "grav": 0.0, "ring": 3.0})
	for i in 8:
		var a := rng.randf() * TAU
		room.particles.append({"pos": at, "vel": Vector2(cos(a), sin(a)) * rng.randf_range(40.0, 120.0),
			"life": rng.randi_range(6, 12), "col": col, "grav": 0.0})


## Acabou o tempo: o coelhão desincha e a perseguição recomeça.
func _ring_end() -> void:
	state = "deflate"
	t = 0
	room.sfx.emit("steam_burst")


func _deflate() -> void:
	if t >= DEFLATE_FRAMES:
		hero_on = false
		var r = room
		r.rabbit_hidden = false
		r.input_lock = false
		r.cam_focus = null
		r.allow_rotate = bool(r.def.get("rotate", true))
		r.rabbit.pos = Vector2i(int(hx) - 6, int(_inner().end.y) - 12)
		r.rabbit.vel = Vector2.ZERO
		r.invuln = INVULN
		lives = maxi(_h_hearts(), 1)
		syringe_taken = false
		pos = _pt_of(_u_floor(pos.x))
		energy = ENERGY
		# a fase alcançada fica guardada: a vida volta ao topo do coração em que ele está
		s_hp = _s_hearts() * S_HP_HEART
		phase = _phase()
		wave_i = 0
		wall_t = 0
		state = "rage"   # ruge e volta a correr
		t = 0
		flash = 24


## Nocaute no Senzi: ele cai (e murcha no caramujinho); o coelhão desincha e a porta abre.
func _ring_win() -> void:
	s_hp = 0.0
	hitstop = 20
	room.shake = 9.0
	room.impact.emit(5.0)
	room.sfx.emit("blast")
	win_deflate = true
	_die()


# ---------------------------------------------------------------- o ringue: desenho

func _draw_hero(base: Transform2D) -> void:
	var sc := 1.0
	var anim_name := "guard"
	var fr := (anim / 9) % 4
	match state:
		"grabbed":
			if t < G_POPS[0]:
				# ainda o coelho, eletrizado
				var tex: Texture2D = room._rabbit_tex("up", "stand", (anim / 2) % 2 == 0)
				draw_set_transform_matrix(base * Transform2D(0.0, Vector2(hx, hy).round()) * Transform2D(0.0, Vector2(h_face, 1), 0.0, Vector2.ZERO))
				draw_texture(tex, Vector2(-6, -12))
				draw_set_transform_matrix(base)
				return
			sc = 0.45 if t < G_POPS[1] else (0.75 if t < G_POPS[2] else 1.0)
			if t >= G_ROAR:
				anim_name = "flex"
				fr = mini((t - G_ROAR) / 4, 5)
		"deflate":
			sc = lerpf(1.0, 0.2, float(t) / DEFLATE_FRAMES)
		"ring":
			if h_stun > 0:
				anim_name = "hit"
				fr = 0 if h_stun > H_STUN / 2 else 1
			elif h_jab >= 0:
				anim_name = "kick" if h_kick else "jab"
				var at := HKICK_HIT if h_kick else HJAB_HIT
				fr = 0 if h_jab < at else (1 if h_jab < at + 3 else (2 if h_jab < at + (10 if h_kick else 6) else 3))
			elif hy < _inner().end.y - 0.5:
				anim_name = "jump"
				fr = 0 if h_vy < 0.0 else 1
			elif h_block:
				anim_name = "block"
				fr = (anim / 10) % 2
			elif absf(h_vx) > 1.0:
				anim_name = "walk"
				fr = int(absf(hx) / 4.0) % 6
		"dying", "dead":
			anim_name = "flex"
			fr = mini(t / 4, 5)
			sc = 1.0 if t < 40 else lerpf(1.0, 0.2, clampf(float(t - 40) / 20.0, 0.0, 1.0))
	if hero_sheet == null:
		return
	var mod := Color(1, 1, 1)
	if state == "ring" and h_stun > 0 and (h_stun / 2) % 2 == 0:
		mod = Color(1.0, 0.55, 0.55)
	if state == "ring" and ring_t < 180 and (ring_t / 6) % 2 == 0:
		mod = mod * Color(1.0, 1.15, 0.85)   # o efeito acabando: pisca verde
	var row: int = HERO_ANIM[anim_name][0]
	var src := Rect2(Vector2(fr, row) * FRAME, FRAME)
	draw_set_transform_matrix(base * Transform2D(0.0, Vector2(hx, hy).round()) * Transform2D(0.0, Vector2(sc * h_face, sc), 0.0, Vector2.ZERO))
	draw_texture_rect_region(hero_sheet, Rect2(Vector2(-FRAME.x / 2.0, -FEET), FRAME), src, mod)
	draw_set_transform_matrix(base)


## O raio: do teto até o coelho, em zigue-zague, branco por dentro.
func _draw_bolt(base: Transform2D) -> void:
	draw_set_transform_matrix(base)
	var top := Vector2(hx, _inner().position.y)
	var end := Vector2(hx, hy - 6.0)
	var pts := PackedVector2Array()
	var n := 9
	var r2 := RandomNumberGenerator.new()
	r2.seed = bolt_t / 3
	for i in n + 1:
		var k := float(i) / n
		var q := top.lerp(end, k)
		if i > 0 and i < n:
			q.x += r2.randf_range(-9.0, 9.0)
		pts.append(q.round())
	draw_polyline(pts, Color("fff6a0", 0.6), 5.0)
	draw_polyline(pts, Color(1, 1, 1), 2.0)
	draw_circle(end, 10.0 * float(bolt_t) / BOLT_FRAMES, Color(1, 1, 0.8, 0.5))
	if bolt_t > BOLT_FRAMES - 4:
		draw_set_transform_matrix(Transform2D.IDENTITY)
		draw_rect(Rect2(-200, -120, 400, 240), Color(1, 1, 1, 0.5))
		draw_set_transform_matrix(base)


## As barras da luta: a do coelho à esquerda, a do Senzi à direita, cada uma em três terços (um
## coração por terço); no meio, o tempo do coelhão, esvaziando verde.
func _draw_ring_hud() -> void:
	var y := -86.0
	var bw := 116.0
	var lb := Rect2(-150, y, bw, 8)
	var rb := Rect2(150 - bw, y, bw, 8)
	for b in [lb, rb]:
		draw_rect((b as Rect2).grow(1.0), Color(0.05, 0.05, 0.08, 0.85))
	var hk := clampf(h_hp / (3.0 * H_HP_HEART), 0.0, 1.0)
	var sk := clampf(s_hp / S_HP_MAX, 0.0, 1.0)
	var hcol := Color(1, 1, 1) if hud_hit > 0 and (hud_hit / 3) % 2 == 0 else Color("efeadf")
	var scol := Color(1, 1, 1) if bar_hit > 0 and (bar_hit / 3) % 2 == 0 else C_ENERGY
	draw_rect(Rect2(lb.position, Vector2(bw * hk, 8)), hcol)
	draw_rect(Rect2(rb.end.x - bw * sk, rb.position.y, bw * sk, 8), scol)
	for b in [lb, rb]:
		for q in [1.0 / 3.0, 2.0 / 3.0]:
			draw_rect(Rect2((b as Rect2).position + Vector2(bw * q, 0), Vector2(1, 8)), Color(0.05, 0.05, 0.08, 0.9))
		draw_rect((b as Rect2).grow(1.0), Color(0.89, 0.87, 0.81, 0.8), false, 1.0)
	for i in 3:
		_draw_heart(Vector2(-150 + i * 10, y + 11), i < _h_hearts())
		_draw_heart(Vector2(143 - i * 10, y + 11), i < _s_hearts(), C_ENERGY)
	# o tempo
	var tk := clampf(float(ring_t) / RING_FRAMES, 0.0, 1.0) if state == "ring" else (1.0 if state == "grabbed" else 0.0)
	var tw := 52.0
	draw_rect(Rect2(-tw / 2.0 - 1, y - 1, tw + 2, 10), Color(0.05, 0.05, 0.08, 0.85))
	var tc := C_JUICE if ring_t >= 180 or (ring_t / 6) % 2 == 0 else Color(1, 1, 1)
	draw_rect(Rect2(-tw * tk / 2.0, y, tw * tk, 8), tc)
	draw_rect(Rect2(-tw / 2.0 - 1, y - 1, tw + 2, 10), Color(0.89, 0.87, 0.81, 0.8), false, 1.0)

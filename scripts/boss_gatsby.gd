extends Node2D
## Boss 2: Gatsby, o texugo (GDD 8c, D72). Ator da sala (campo "actors"): a sala chama
## step(room) a cada quadro de jogo, on_reset(room) quando reinicia e on_rotate(room, dir)
## quando gira.
##
## Esta fase é uma corrida: o Gatsby nunca é alcançado e não machuca. Ele voa numa cápsula À
## FRENTE do coelho, no rumo da próxima área do roteiro (campo "gatsby" da sala), olhando para
## trás, sem respeitar paredes. O roteiro avança conforme o coelho avança. A alavanca fica dentro
## da nave: ele a puxa de onde estiver, e um raio na cor do canal liga a nave às peças acionadas.
## Ele NUNCA encosta no coelho: há uma distância mínima garantida a cada quadro (KEEP_MIN), em
## qualquer fase do roteiro; se o coelho vem para cima dele, ele dá um arranque para longe.
##
##   "gatsby": {"start": [coluna, linha], "hidden": true (opcional), "script": [passo, passo, ...]}
##
## "hidden": ele não aparece (nem acompanha o coelho) até o primeiro passo começar; aí surge em
## "start" (que pode ficar fora da sala) e segue o roteiro. Para uma aparição só no final (D105).
##
## Cada passo é um dicionário; tudo é opcional e acontece nesta ordem:
##   "when": [coluna, linha, largura, altura]  espera o coelho entrar nesta área
##   "mood": "bored" | "smug" | "amused" | "annoyed" | "furious" | "nervous" | "panic" | "smirk"
##   "fly": [coluna, linha] ou uma lista de pontos   voa até lá (para cenas; normalmente não se usa)
##   "lever": true            puxa uma alavanca dentro da nave; os efeitos saem nesse instante
##   "crusher": índice        liga essa placa de espinhos
##   "speed": [índice, px/s]  muda a velocidade de uma placa
##   "toggle": canal ou [canais]  liga/desliga os blocos motorizados desses canais (campo "movers")
##   "rotate": 1 ou -1        gira a sala (horário / anti-horário); esse giro fica
##   "wait": segundos         pausa antes do passo seguinte (com "repeat": o intervalo entre as puxadas)
##   "repeat": n              repete a alavanca e os efeitos mais n vezes, a cada "wait" s. As repetições
##                            acontecem em segundo plano: o roteiro segue para o passo seguinte
##   "flee": true             vai embora voando, para longe do coelho (fim do roteiro)
##   "cut": true              cutscene: a entrada fica travada e a câmera vai para ele.
##                            Só na primeira vez; depois, o passo acontece na hora.
##
## Posições em tiles, como a fase foi desenhada. Coordenadas internas em px da sala.

const DT := 1.0 / 60.0
const FLY_SPEED := 130.0
const FLY_ACCEL := 420.0
const FLEE_ACCEL := 520.0
const LEVER_FRAMES := 36      # duração do gesto de puxar a alavanca
const LEVER_HIT := 18         # quadro em que a alavanca vira e os efeitos acontecem
const JOLT_FRAMES := 45       # jogado dentro da cápsula depois de um giro
# Voar à frente do coelho: uma mola puxa a cápsula para um ponto adiante dele, no rumo da corrida.
const ORBIT_K := 22.0         # força da mola
const ORBIT_C := 7.5          # amortecimento (um pouco abaixo do crítico: ele balança de leve)
const ORBIT_MAX := 420.0      # px/s: mais rápido que o coelho em qualquer situação (queda, catapulta)
const BODY := Vector2(0, 8)   # centro do corpo da cápsula em relação a `pos` (o centro da cúpula)
const KEEP_AWAY := 66.0       # coelho mais perto que isto: ele é empurrado para longe
const KEEP_MIN := 50.0        # distância mínima garantida entre os centros (a cápsula inteira, com
                              # a chama, cabe num raio de 35 px; o coelho, num de 9)
const DASH_CD := 40           # quadros entre dois arranques
# distância à frente (px), balanço lateral (px) e velocidade do balanço (rad/quadro) por humor
const LEAD := {
	"bored": [78.0, 5.0, 0.03], "smug": [76.0, 7.0, 0.04], "amused": [74.0, 9.0, 0.06], "annoyed": [72.0, 8.0, 0.09],
	"furious": [70.0, 6.0, 0.16], "nervous": [80.0, 10.0, 0.13], "panic": [86.0, 12.0, 0.20], "smirk": [78.0, 6.0, 0.05],
}

const C_GLASS := Color("9fd4ff")
const C_HULL := Color("31343d")
const C_HULL_DARK := Color("26282f")
const C_HULL_LIGHT := Color("454852")
const C_SEAM := Color("0e0f13")
const C_RIVET := Color("7b7f8a")
const C_RUST := Color("5a4034")
const C_WHITE := Color("e9e4d6")
const C_DARK := Color("1a1b22")
const C_FUR := Color("4a4d57")
const C_KNOB := Color("e0657c")
const C_FLAME := Color("f0a05a")
const C_FLAME_CORE := Color("fff4c2")
const C_SWEAT := Color("9fd4ff")

var room
## A cutscene já aconteceu nesta sessão de jogo: morrer não a repete.
static var intro_seen := false


## Para o replay (scripts/replay.gd): a cutscene muda a partida.
static func replay_state() -> Dictionary:
	return {"intro_seen": intro_seen}


static func apply_replay_state(d: Dictionary) -> void:
	intro_seen = bool(d.get("intro_seen", false))


var pos := Vector2.ZERO   # centro da cúpula
var vel := Vector2.ZERO
var steps: Array = []     # {"zone": Rect2i ou null, "path": Array[Vector2], "src": Dictionary}
var si := 0
var phase := "idle"       # when | fly | lever | wait | flee | idle | gone
var t := 0
var path: Array = []
var mood := "bored"
var cut := false          # o passo atual é uma cutscene em andamento
var lever_on := false     # lado da alavanca (só desenho)
var jolt := 0
var anim := 0
var nozzle := 0.0         # ângulo do propulsor, suavizado
var theta := 0.0          # fase do balanço
var lead := Vector2(0.6, -0.8)   # rumo da corrida (unitário), suavizado
var dash_cd := 0
var dash_fx := 0          # quadros de chama forte depois de um arranque
var sig_ch := -1          # canal do último acionamento (a cor do raio e da luz da antena)
var sig_t := 0            # quadros restantes do raio
var min_gap := 1e9        # menor distância ao coelho desde o reset (os testes conferem)
var pulses: Array = []    # repetições em andamento: {"at": quadros até a alavanca virar, "src", "left", "gap"}
var lever_vis := 0        # quadros de gesto da alavanca (para o desenho, também nas repetições)
var fused := false        # plugado na mecha (boss_mecha.gd): sem balanço nem propulsor próprio
var tilt := 0.0           # inclinação dada pela mecha (o corpo dela se inclina e leva a cápsula)


func on_reset(r) -> void:
	room = r
	var g: Dictionary = r.def.get("gatsby", {})
	pos = _pt(g.get("start", [3, 3]))
	vel = Vector2.ZERO
	lurking = bool(g.get("hidden", false))
	visible = not lurking
	steps.clear()
	for s in g.get("script", []):
		var zone = null
		if s.has("when"):
			var w: Array = s["when"]
			zone = Rect2i(int(w[0]) * 8, int(w[1]) * 8, int(w[2]) * 8, int(w[3]) * 8)
		var pts: Array = []
		if s.has("fly"):
			var f: Array = s["fly"]
			if f.size() > 0 and f[0] is Array:
				for q in f:
					pts.append(_pt(q))
			else:
				pts.append(_pt(f))
		steps.append({"zone": zone, "path": pts, "src": s})
	si = 0
	mood = "bored"
	cut = false
	lever_on = false
	jolt = 0
	nozzle = 0.0
	theta = -1.2
	lead = Vector2(0.6, -0.8)
	dash_cd = 0
	dash_fx = 0
	sig_ch = -1
	sig_t = 0
	min_gap = 1e9
	pulses.clear()
	lever_vis = 0
	phase = "when" if not steps.is_empty() else "idle"


var lurking := false  # escondido até o primeiro passo ("hidden" no campo "gatsby")


func _pt(a: Array) -> Vector2:
	return Vector2(float(a[0]) * 8.0 + 4.0, float(a[1]) * 8.0 + 4.0)


## A sala girou: ele e o roteiro giram junto (a cápsula, no desenho, fica em pé).
func on_rotate(r, dir: int) -> void:
	pos = r._rot_point(pos, dir)
	vel = Vector2(-vel.y, vel.x) if dir > 0 else Vector2(vel.y, -vel.x)
	for i in path.size():
		path[i] = r._rot_point(path[i], dir)
	for e in steps:
		if e["zone"] != null:
			e["zone"] = r._rot_rect(e["zone"], dir)
		var pts: Array = e["path"]
		for i in pts.size():
			pts[i] = r._rot_point(pts[i], dir)
	lead = Vector2(-lead.y, lead.x) if dir > 0 else Vector2(lead.y, -lead.x)
	jolt = JOLT_FRAMES


func step(r) -> void:
	room = r
	anim += 1
	jolt = maxi(jolt - 1, 0)
	dash_cd = maxi(dash_cd - 1, 0)
	dash_fx = maxi(dash_fx - 1, 0)
	sig_t = maxi(sig_t - 1, 0)
	lever_vis = maxi(lever_vis - 1, 0)
	_update_pulses()
	match phase:
		"when":
			if not lurking:
				_orbit()
			var zone = steps[si]["zone"]
			if zone == null or r.overlaps(r.rabbit.rect, zone):
				lurking = false
				visible = true
				_begin()
		"fly":
			if _fly_to(path[0]):
				path.pop_front()
				if path.is_empty():
					_arrived()
		"lever":
			_orbit()
			t += 1
			if t == LEVER_HIT:
				_pull(steps[si]["src"])
				var rp := int(steps[si]["src"].get("repeat", 0))
				if rp > 0:
					var gap := maxi(roundi(float(steps[si]["src"].get("wait", 1.0)) * 60.0), LEVER_FRAMES)
					pulses.append({"at": gap, "src": steps[si]["src"], "left": rp, "gap": gap})
			if t >= LEVER_FRAMES:
				_pause()
		"wait":
			_orbit()
			t -= 1
			if t <= 0:
				_next()
		"flee":
			vel += _flee_dir() * FLEE_ACCEL * DT
			pos += vel * DT
			if (pos - r.cam).length() > 320.0:
				phase = "gone"
		_:
			_orbit()
	if phase != "gone":
		_keep_clear()
	if cut:
		r.cam_focus = pos.lerp(Vector2(r.rabbit.pos) + Vector2(6, 6), 0.4)
	nozzle = lerpf(nozzle, clampf(vel.x / FLY_SPEED, -1.0, 1.0) * 0.9, 0.2)
	if phase != "gone" and anim % 3 == 0:
		_exhaust()


func _begin() -> void:
	var s: Dictionary = steps[si]["src"]
	if s.has("mood"):
		mood = s["mood"]
	if s.get("cut", false):
		if intro_seen:
			# já vista: o passo acontece na hora, sem cena
			var pts: Array = steps[si]["path"]
			if not pts.is_empty():
				pos = pts[-1]
			vel = Vector2.ZERO
			if s.get("lever", false):
				lever_on = not lever_on
			_effects()
			_next()
			return
		cut = true
		room.input_lock = true
	path = steps[si]["path"].duplicate()
	if path.is_empty():
		_arrived()
	else:
		phase = "fly"


func _arrived() -> void:
	if steps[si]["src"].get("lever", false):
		phase = "lever"
		lever_vis = LEVER_FRAMES
		t = 0
	else:
		_effects()
		_pause()


func _pause() -> void:
	phase = "wait"
	var src: Dictionary = steps[si]["src"]
	# com repeat, "wait" é o intervalo das repetições, não uma pausa do roteiro
	t = 0 if src.has("repeat") else roundi(float(src.get("wait", 0.0)) * 60.0)


## A alavanca vira: o gesto, o som, as faíscas e os efeitos do passo.
func _pull(src: Dictionary) -> void:
	lever_on = not lever_on
	room.sfx.emit("lever")
	room.shake = maxf(room.shake, 1.0)
	if src.has("toggle"):
		var tg = src["toggle"]
		sig_ch = int(tg[0] if tg is Array else tg)
		sig_t = 22
	_sparks()
	_effects(src)


## As repetições em segundo plano: o gesto começa LEVER_HIT quadros antes do efeito.
func _update_pulses() -> void:
	for p in pulses:
		p["at"] -= 1
		if p["at"] == LEVER_HIT:
			lever_vis = LEVER_FRAMES
		if p["at"] <= 0:
			_pull(p["src"])
			p["left"] -= 1
			p["at"] = p["gap"]
	pulses = pulses.filter(func(p): return p["left"] > 0)


func _effects(s: Dictionary = {}) -> void:
	if s.is_empty():
		s = steps[si]["src"]
	if s.has("crusher"):
		room.crusher_start(int(s["crusher"]))
	if s.has("speed"):
		var sp: Array = s["speed"]
		if int(sp[0]) < room.crushers.size():
			room.crushers[int(sp[0])]["speed"] = float(sp[1])
	if s.has("toggle"):
		var tg = s["toggle"]
		for ch in (tg if tg is Array else [tg]):
			room.mover_toggle(int(ch))
	if s.has("rotate"):
		room.actor_rotate(int(s["rotate"]))
	# "chase_music" (campo da sala): a perseguição começa quando o Gatsby foge
	if s.get("flee", false) and str(room.def.get("chase_music", "")) != "":
		room.music_override = str(room.def["chase_music"])
		room.music_request.emit(room.music_override)


func _next() -> void:
	var s: Dictionary = steps[si]["src"]
	# a cutscene só termina quando o passo seguinte já não é de cena (uma cena pode ter vários passos)
	var more_cut: bool = si + 1 < steps.size() and steps[si + 1]["src"].get("cut", false) and not s.get("flee", false)
	if cut and not more_cut:
		cut = false
		intro_seen = true
		room.input_lock = false
		room.cam_focus = null
	if s.get("flee", false):
		phase = "flee"
		return
	si += 1
	phase = "when" if si < steps.size() else "idle"


## O rumo da corrida: do coelho para a próxima área do roteiro.
func _race_dir() -> Vector2:
	var c := Vector2(room.rabbit.pos) + Vector2(6, 6)
	for k in range(si, steps.size()):
		var z = steps[k]["zone"]
		if z != null:
			var d: Vector2 = Vector2(z.position) + Vector2(z.size) / 2.0 - c
			if d.length() > 24.0:
				return d.normalized()
	return lead


## Voa à frente do coelho, no rumo da próxima área, com um balanço de lado. Não olha paredes.
func _orbit() -> void:
	var c := Vector2(room.rabbit.pos) + Vector2(6, 6)
	var mo: Array = LEAD.get(mood, [76.0, 7.0, 0.05])
	lead = lead.slerp(_race_dir(), 0.035).normalized()
	theta += float(mo[2])
	var side := Vector2(-lead.y, lead.x)
	# elipse: mais longe na horizontal (a tela é larga) do que na vertical
	var ahead := Vector2(lead.x * float(mo[0]) * 1.15, lead.y * float(mo[0]) * 0.82)
	var tgt := c + ahead + side * sin(theta) * float(mo[1]) - BODY
	# prefere o ar livre: se o ponto à frente cai dentro de uma parede, procura um ao lado
	if _in_wall(tgt):
		for off in [0.6, -0.6, 1.2, -1.2, 1.9, -1.9, 2.6, -2.6, PI]:
			var d2 := lead.rotated(off)
			var cand := c + Vector2(d2.x * float(mo[0]) * 1.15, d2.y * float(mo[0]) * 0.82) - BODY
			if not _in_wall(cand):
				tgt = cand
				break
	vel += ((tgt - pos) * ORBIT_K - vel * ORBIT_C) * DT
	if vel.length() > ORBIT_MAX:
		vel = vel.normalized() * ORBIT_MAX
	pos += vel * DT


## A cápsula, centrada em `p`, ficaria com o corpo dentro de uma parede?
func _in_wall(p: Vector2) -> bool:
	return room.tile_solid_rect(Rect2i(Vector2i(p.round()) + Vector2i(-13, -10), Vector2i(26, 32)))


## A garantia de que ele nunca encosta no coelho, em qualquer fase: se o coelho chega perto,
## ele arranca para longe; e a distância entre os centros nunca fica abaixo de KEEP_MIN.
func _keep_clear() -> void:
	var c := Vector2(room.rabbit.pos) + Vector2(6, 6)
	var away := pos + BODY - c
	var dist := away.length()
	if dist < 0.5:
		away = -lead if lead.length() > 0.1 else Vector2(0, -1)
		dist = 1.0
	var n := away / dist
	if dist < KEEP_AWAY and phase != "flee":
		# arranque: para longe do coelho, puxando para o rumo da corrida
		var push := (n + lead * 0.6).normalized()
		vel += push * (KEEP_AWAY - dist) * 30.0 * DT
		if dash_cd == 0 and dist < KEEP_AWAY - 6.0:
			dash_cd = DASH_CD
			dash_fx = 14
			vel += push * 120.0
			room.sfx.emit("gatsby_dash")
	if dist < KEEP_MIN:
		pos = c + n * KEEP_MIN - BODY
		# tira a parte da velocidade que vai na direção do coelho
		var into := vel.dot(-n)
		if into > 0.0:
			vel += n * into
		dist = KEEP_MIN
	min_gap = minf(min_gap, dist)


## A sala chama quando o coelho morre: ele ri. Nunca absorve a morte.
## Na corrida, o Gatsby faz o papel do amortecedor: o laser do limitador sai da cápsula dele.
func limiter_source() -> Variant:
	if phase == "gone" or phase == "puppet" or not visible:
		return null
	return pos


func absorb_kill(r) -> bool:
	r.sfx.emit("gatsby_laugh")
	return false


## Para onde ele foge: para longe do coelho, e para cima.
func _flee_dir() -> Vector2:
	var c := Vector2(room.rabbit.pos) + Vector2(6, 6)
	var d := pos - c
	var sx := 1.0 if d.x >= 0.0 else -1.0
	return Vector2(sx * 0.7, -0.9).normalized()


func _hover() -> void:
	vel = vel.move_toward(Vector2.ZERO, FLY_ACCEL * DT)
	pos += vel * DT


func _fly_to(target: Vector2) -> bool:
	var d := target - pos
	var dist := d.length()
	var want := Vector2.ZERO
	if dist > 0.5:
		want = d / dist * minf(FLY_SPEED, dist * 5.0)
	vel = vel.move_toward(want, FLY_ACCEL * DT)
	pos += vel * DT
	return dist < 3.0


## Direção do jato (para onde o bocal aponta): contra o movimento.
func _nozzle_dir() -> Vector2:
	return Vector2(-sin(nozzle), cos(nozzle))


func _exhaust() -> void:
	var tip := pos + Vector2(0, 19) + _nozzle_dir() * 8.0
	room.particles.append({
		"pos": tip, "vel": _nozzle_dir() * 45.0 + Vector2(randf_range(-10.0, 10.0), 0.0),
		"life": randi_range(8, 14), "col": Color("85858f"), "grav": -30.0,
	})


func _sparks() -> void:
	for i in 6:
		room.particles.append({
			"pos": pos + Vector2(9, 0), "vel": Vector2(randf_range(-50.0, 50.0), randf_range(-70.0, -10.0)),
			"life": randi_range(8, 16), "col": C_FLAME_CORE, "grav": 260.0,
		})


# ---------------------------------------------------------------- desenho

func _process(_delta: float) -> void:
	queue_redraw()


func _px(p: Vector2, col: Color) -> void:
	draw_rect(Rect2(p, Vector2(1, 1)), col)


func _draw() -> void:
	if room == null or phase == "gone":
		return
	var base := Transform2D(room.view_angle, Vector2.ZERO) * Transform2D(0.0, -room.cam.round())
	var bob := Vector2.ZERO if fused else Vector2(0, roundf(sin(anim * 0.07) * 1.5))
	# a cápsula fica em pé mesmo com a sala girando
	var cap := base * Transform2D(-room.view_angle + tilt, pos.round() + bob)
	var m := mood
	if room.state == "dead":
		m = "amused"   # ri quando o coelho morre
	elif jolt > 0:
		m = "panic"
	var shake := Vector2.ZERO
	if jolt > 0:
		shake = Vector2(roundf(sin(anim * 1.3) * 3.0 * jolt / JOLT_FRAMES), 0)
	elif m == "furious" or m == "panic":
		shake = Vector2((anim / 2) % 2, 0)
	elif m == "amused":
		shake = Vector2(0, (anim / 5) % 2)

	# o raio do acionamento: da antena até cada peça do canal, na cor dele
	if sig_t > 0 and sig_ch >= 0:
		draw_set_transform_matrix(base)
		var col := Color(_sig_color(), float(sig_t) / 22.0)
		var from := pos + Vector2(-14, -19)
		for mv in room.movers:
			if mv["ch"] != sig_ch:
				continue
			var to: Vector2 = Vector2(mv["r"].position) + Vector2(mv["r"].size) / 2.0
			if to.distance_to(from) > 420.0:
				continue
			var pts := PackedVector2Array([from])
			var segs := 6
			var nrm := (to - from).orthogonal().normalized()
			for k in range(1, segs):
				var jit := sin(float(anim * 3 + k * 7)) * 5.0
				pts.append(from.lerp(to, float(k) / segs) + nrm * jit)
			pts.append(to)
			draw_polyline(pts, col, 1.0)

	# propulsor: gira contra o movimento (plugada na mecha, quem empurra são os motores dela)
	if not fused:
		draw_set_transform_matrix(cap * Transform2D(nozzle, Vector2(0, 19)))
		var fl := 6.0 + float((anim / 2) % 3) * 2.0 + clampf(-vel.y / 30.0, -2.0, 4.0) + (4.0 if dash_fx > 0 else 0.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-3, 6), Vector2(0, 6 + fl), Vector2(3, 6)]), C_FLAME)
		draw_colored_polygon(PackedVector2Array([Vector2(-1.5, 6), Vector2(0, 6 + fl * 0.55), Vector2(1.5, 6)]), C_FLAME_CORE)
		draw_rect(Rect2(-4, 0, 9, 3), C_HULL_LIGHT)
		draw_rect(Rect2(-3, 3, 7, 3), C_HULL_DARK)
		draw_rect(Rect2(-4, 2, 9, 1), C_SEAM)
		_px(Vector2(-3, 1), C_RIVET)
		_px(Vector2(3, 1), C_RIVET)
	draw_set_transform_matrix(cap)

	# vidro
	# fundo da cabine mais claro que a sala, para as faixas escuras do texugo aparecerem
	draw_circle(Vector2(0, -3), 13.0, Color("2c3644"))
	# o Gatsby
	_draw_badger(shake, m)
	# alavanca dentro da nave
	var knob := Vector2(12, -1) if lever_on else Vector2(7, -1)
	draw_line(Vector2(9.5, 6), knob + Vector2(0.5, 1), C_RIVET, 1.0)
	draw_rect(Rect2(knob - Vector2(1, 1), Vector2(3, 3)), _sig_color() if sig_t > 0 else C_KNOB)
	if phase == "lever" or lever_vis > 0:
		draw_rect(Rect2(knob + Vector2(-3, 1), Vector2(3, 2)), C_FUR)   # a pata na alavanca
	draw_arc(Vector2(0, -3), 13.0, PI * 0.95, PI * 2.05, 24, Color(C_GLASS, 0.85), 1.0)
	draw_arc(Vector2(0, -3), 10.0, PI * 1.15, PI * 1.4, 6, Color(1, 1, 1, 0.5), 1.0)
	# remendo no vidro: fita em X
	draw_line(Vector2(6, -13), Vector2(10, -9), C_RIVET, 1.0)
	draw_line(Vector2(10, -13), Vector2(6, -9), C_RIVET, 1.0)

	# casco: chapas remendadas
	draw_rect(Rect2(-15, 5, 31, 3), C_HULL_LIGHT)
	draw_rect(Rect2(-14, 8, 29, 7), C_HULL)
	draw_rect(Rect2(-10, 15, 21, 3), C_HULL_DARK)
	draw_rect(Rect2(-14, 8, 29, 1), C_SEAM)
	draw_rect(Rect2(-4, 9, 1, 6), C_SEAM)
	draw_rect(Rect2(6, 9, 1, 6), C_SEAM)
	for x in [-13, -7, -1, 5, 11]:
		_px(Vector2(x, 6), C_RIVET)
	for q in [Vector2(-2, 10), Vector2(4, 10), Vector2(-2, 13), Vector2(4, 13), Vector2(12, 10), Vector2(12, 13)]:
		_px(q, C_RIVET)
	draw_rect(Rect2(-13, 9, 8, 5), C_SEAM)
	draw_rect(Rect2(-12, 10, 6, 3), C_RUST)
	_px(Vector2(-12, 10), C_RIVET)
	_px(Vector2(-7, 10), C_RIVET)
	_px(Vector2(-12, 12), C_RIVET)
	_px(Vector2(-7, 12), C_RIVET)
	# canos laterais e antena
	draw_rect(Rect2(-18, 9, 4, 3), C_HULL_DARK)
	draw_rect(Rect2(15, 9, 4, 3), C_HULL_DARK)
	draw_line(Vector2(-11.5, -11), Vector2(-14.5, -19), C_RIVET, 1.0)
	if sig_t > 0:
		draw_rect(Rect2(-16, -21, 3, 3), _sig_color())   # a antena acende na cor do canal acionado
	else:
		_px(Vector2(-15, -20), C_KNOB if (anim / 20) % 2 == 0 else C_HULL_DARK)
	draw_set_transform_matrix(Transform2D())


func _sig_color() -> Color:
	var pal: Array = room.C_CHANNEL
	return pal[maxi(sig_ch, 0) % pal.size()]


## Texugo: cabeça clara com duas faixas escuras (os olhos brilham dentro delas), pelo espetado.
func _draw_badger(o: Vector2, m: String) -> void:
	# corpo e barriga
	draw_rect(Rect2(o.x * 0.5 - 6, 2, 13, 6), C_FUR)
	draw_rect(Rect2(o.x * 0.5 - 3, 3, 7, 5), C_WHITE)
	var h := o + Vector2(0, -5)
	if m == "bored":
		h.y += 1
	# orelhas
	draw_rect(Rect2(h + Vector2(-6, -7), Vector2(3, 3)), C_DARK)
	draw_rect(Rect2(h + Vector2(4, -7), Vector2(3, 3)), C_DARK)
	_px(h + Vector2(-5, -6), C_WHITE)
	_px(h + Vector2(5, -6), C_WHITE)
	# cabeça
	draw_rect(Rect2(h + Vector2(-6, -5), Vector2(13, 9)), C_WHITE)
	draw_rect(Rect2(h + Vector2(-5, 4), Vector2(11, 1)), C_WHITE)
	# pelo espetado nas bochechas (mais arrepiado quando furioso ou em pânico)
	var wild := m == "furious" or m == "panic"
	for y in [-3, 0, 3]:
		_px(h + Vector2(-7, y), C_WHITE)
		_px(h + Vector2(7, y), C_WHITE)
		if wild:
			_px(h + Vector2(-8, y - 1), C_WHITE)
			_px(h + Vector2(8, y - 1), C_WHITE)
	if wild:
		_px(h + Vector2(-2, -6), C_WHITE)
		_px(h + Vector2(1, -7), C_WHITE)
		_px(h + Vector2(3, -6), C_WHITE)
	# faixas
	draw_rect(Rect2(h + Vector2(-5, -5), Vector2(3, 7)), C_DARK)
	draw_rect(Rect2(h + Vector2(3, -5), Vector2(3, 7)), C_DARK)
	# focinho
	draw_rect(Rect2(h + Vector2(-1, 0), Vector2(3, 2)), C_DARK)

	# olhos: olham para o coelho (nervoso: para trás)
	var look := 0
	if room != null and room.rabbit != null:
		var dx: float = room.rabbit.pos.x + 6.0 - pos.x
		look = 1 if dx > 12.0 else (-1 if dx < -12.0 else 0)
	var lx := -5 if look <= 0 else -4
	var rx := 3 if look <= 0 else 4
	var eye := C_WHITE
	match m:
		"bored":
			draw_rect(Rect2(h + Vector2(lx, -1), Vector2(2, 1)), eye)
			draw_rect(Rect2(h + Vector2(rx, -1), Vector2(2, 1)), eye)
		"amused":
			# olhos fechados de riso: ^ ^
			_px(h + Vector2(-5, -1), eye)
			_px(h + Vector2(-4, -2), eye)
			_px(h + Vector2(-3, -1), eye)
			_px(h + Vector2(3, -1), eye)
			_px(h + Vector2(4, -2), eye)
			_px(h + Vector2(5, -1), eye)
		"annoyed", "furious":
			if m == "furious":
				eye = C_KNOB
			# inclinados para o focinho: \ /
			_px(h + Vector2(lx, -3), eye)
			draw_rect(Rect2(h + Vector2(lx, -2), Vector2(2, 1)), eye)
			_px(h + Vector2(lx + 1, -1), eye)
			_px(h + Vector2(rx + 1, -3), eye)
			draw_rect(Rect2(h + Vector2(rx, -2), Vector2(2, 1)), eye)
			_px(h + Vector2(rx, -1), eye)
		"panic":
			draw_rect(Rect2(h + Vector2(-5, -4), Vector2(3, 4)), eye)
			draw_rect(Rect2(h + Vector2(3, -4), Vector2(3, 4)), eye)
			_px(h + Vector2(-4 + look, -2), C_DARK)
			_px(h + Vector2(4 + look, -2), C_DARK)
		"nervous":
			draw_rect(Rect2(h + Vector2(lx, -3), Vector2(2, 3)), eye)
			draw_rect(Rect2(h + Vector2(rx, -3), Vector2(2, 3)), eye)
			_px(h + Vector2(lx + (1 if look > 0 else 0), -2), C_DARK)
			_px(h + Vector2(rx + (1 if look > 0 else 0), -2), C_DARK)
		"smirk":
			draw_rect(Rect2(h + Vector2(lx, -1), Vector2(2, 1)), eye)   # piscadela
			draw_rect(Rect2(h + Vector2(rx, -2), Vector2(2, 2)), eye)
		_:  # smug
			draw_rect(Rect2(h + Vector2(lx, -2), Vector2(2, 2)), eye)
			draw_rect(Rect2(h + Vector2(rx, -2), Vector2(2, 1)), eye)

	# boca
	match m:
		"bored":
			_px(h + Vector2(0, 3), C_DARK)
		"amused":
			draw_rect(Rect2(h + Vector2(-2, 2), Vector2(5, 3)), C_DARK)
			draw_rect(Rect2(h + Vector2(-1, 4), Vector2(3, 1)), C_KNOB)
		"annoyed":
			draw_rect(Rect2(h + Vector2(-2, 3), Vector2(4, 1)), C_DARK)
		"furious":
			draw_rect(Rect2(h + Vector2(-3, 2), Vector2(7, 3)), C_DARK)
			for x in [-2, 0, 2]:
				_px(h + Vector2(x, 3), C_WHITE)
		"panic":
			draw_rect(Rect2(h + Vector2(-1, 2), Vector2(3, 3)), C_DARK)
		"nervous":
			_px(h + Vector2(-2, 3), C_DARK)
			_px(h + Vector2(-1, 4), C_DARK)
			_px(h + Vector2(0, 3), C_DARK)
			_px(h + Vector2(1, 4), C_DARK)
			_px(h + Vector2(2, 3), C_DARK)
		_:  # smug, smirk: sorriso torto
			draw_rect(Rect2(h + Vector2(-1, 3), Vector2(4, 1)), C_DARK)
			_px(h + Vector2(3, 2), C_DARK)

	# suor
	if m == "nervous" or m == "panic":
		var dy := (anim / 6) % 5
		_px(h + Vector2(8, -6 + dy), C_SWEAT)
		_px(h + Vector2(8, -5 + dy), C_SWEAT)
	# entediado: xícara de chá; toma um gole de vez em quando
	if m == "bored":
		var sip := (anim % 200) < 40
		var cup := Vector2(-3, 1) if sip else Vector2(-10, 4)
		draw_rect(Rect2(cup, Vector2(4, 3)), C_WHITE)
		_px(cup + Vector2(-1, 1), C_WHITE)
		draw_rect(Rect2(cup + Vector2(1, 0), Vector2(2, 1)), C_RUST)
		if not sip:
			_px(cup + Vector2(1 + (anim / 12) % 2, -2), Color(C_WHITE, 0.5))

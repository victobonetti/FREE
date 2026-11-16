extends Node2D
## Boss 1: Jeffrey, o esquilo (GDD 8b, D63). Ator da sala (campo "actors"): a sala chama
## step(room) a cada quadro de jogo e on_reset(room) quando reinicia (morte do coelho ou R).
##
## O esquilo não machuca ao encostar: só as nozes e as bombas matam o coelho.
## Noz: gira, perde força a cada batida, muda de cara e quebra na terceira.
## Bomba (a partir do segundo coração): vai reto até onde o coelho estava e explode no
## primeiro contato, ferindo num raio pequeno.
##
## A regra que importa: o esquilo nunca salta numa face com espinhos. Ele escolhe uma face
## vizinha à dos espinhos (um giro sempre basta), avisa, e salta em linha reta; depois que o
## salto começa, não muda. Girar cedo faz ele trocar de alvo; girar tarde, ele já ricocheteou.
## O acerto vem de girar no último instante, no meio do salto.
##
## Rotas: o esquilo pula entre pontos de apoio (chão, paredes, teto). Só usa trechos que passam
## longe do bloco, então nenhum giro o acerta fora do salto de ataque.
## Coordenadas em px da sala; o desenho usa a câmera da sala.

const SIZE := 12                     # caixa de colisão (o coelho tem 12; dá para pular por cima)
const HEARTS := 3
const LIVES := 3                     # vidas do coelho, só nesta sala
const INTRO_SPINS := 3                # giros do bloco antes de o esquilo aparecer (só na 1ª vez)
const INTRO_DELAY := 30               # quadros entre o terceiro giro e a entrada
const INVULN := 40                   # quadros piscando, imune, depois de levar dano
const HOP_SPEED := 230.0             # px/s nos saltos entre apoios
const WALK_SPEED := [38.0, 48.0, 58.0]       # por fase (corações perdidos: 0, 1, 2)
const WALK_TIME := [100, 75, 55]             # quadros andando antes de atacar
const HOPS := [1, 2, 3]                      # saltos de zigue-zague antes do ataque
const AIM_TIME := [40, 34, 28]               # quadros de aviso antes do salto de ataque
const ATTACK_TIME := [66, 54, 45]            # duração do salto de ataque: a janela de reação
const MAX_NUTS := [1, 1, 2]
const MAX_BOMBS := [0, 1, 1]
const BOMB_SPEED := 85.0    # px/s, em linha reta
const BOMB_SIZE := 9
const BOMB_RADIUS := 14.0   # raio da explosão, em px
const BOMB_MIN_DIST := 50.0 # de mais perto que isto ele não joga bomba (não daria para desviar)
const BLAST_FRAMES := 14
const NUT_KEEP := 0.8       # fração da velocidade que sobra a cada batida (além do quique)
const WALK_CYCLE := 20      # corridinha de esquilo: anda 16 quadros, para 4
const WALK_PAUSE := 4
const STUN_TIME := 75
const PERCH := 7                     # quadros parado em cada apoio
const NUT_GRAV := 140.0     # nozes lentas: dá para ver e desviar
const NUT_SIZE := 10
const NUT_DRAW := 1.45      # o desenho da noz (7 px) ampliado para o tamanho da colisão
const NUT_FLIGHT := 1.5     # segundos do arremesso até onde o coelho estava

const C_FUR := Color("c47a3c")
const C_FUR_DARK := Color("8a4f22")
const C_BELLY := Color("e8c79a")
const C_EYE := Color("1a1410")
const C_NUT := Color("9a6a3a")
const C_NUT_DARK := Color("5e3d1d")
const C_HEART := Color("e0657c")
const C_HEART_EMPTY := Color(1, 1, 1, 0.18)
const C_AIM := Color("ffe9a8")
const C_SHADE := Color("0d0d14")
const C_TOOTH := Color("fff6e0")
const C_BOMB := Color("3a3a4c")
const C_BOMB_DARK := Color("1f1f2b")
const C_FIRE := Color("ffb347")

## Sorteio próprio, com semente fixa: as decisões do esquilo se repetem iguais a cada vez que a
## sala é criada, e um replay gravado no editor reproduz a luta exatamente. (As partículas usam
## o sorteio global: são só visuais.)
const RNG_SEED := 20261116
var rng := RandomNumberGenerator.new()
var room
## A abertura já aconteceu nesta sessão de jogo: morrer ou voltar à sala não a repete.
static var intro_seen := false


## Para o replay (scripts/replay.gd): a abertura muda a luta, então entra no estado de partida.
static func replay_state() -> Dictionary:
	return {"intro_seen": intro_seen}


static func apply_replay_state(d: Dictionary) -> void:
	intro_seen = bool(d.get("intro_seen", false))

var hearts := HEARTS
var spins_seen := 0      # giros do bloco contados na abertura
var was_spinning := false
var lives := LIVES       # vidas do coelho: zerou, a luta recomeça do início
var hud_hit := 0         # quadros piscando o retrato do coelho
var state := "enter"     # wait (abertura: esperando os giros), enter, walk, hop, perch, aim, attack, bounce, stunned, dead, gone
var pos := Vector2.ZERO  # centro
var t := 0               # quadros no estado atual
var leg_from := Vector2.ZERO
var leg_to := Vector2.ZERO
var leg_frames := 1
var path: Array = []     # próximos apoios
var hops_left := 0
var then_state := ""     # para onde vai ao fim do caminho
var target_face := -1
var dir := -1            # para onde olha / anda (-1 esquerda)
var spin := 0.0          # rotação do desenho
var flash := 0           # piscar ao ser atingido
var thrown := false      # já jogou a noz neste salto
var nuts: Array = []     # {pos, vel, hits, ang, av}
var bombs: Array = []    # {pos, vel}
var blasts: Array = []   # {pos, t}: explosões em andamento (só desenho; o dano é no 1º quadro)
var throws := 0          # arremessos feitos: alterna noz e bomba
var anim := 0            # relógio só do desenho
var vel_s := Vector2.ZERO   # velocidade suavizada: o rabo segue com atraso
var last_pos := Vector2.ZERO
var trail: Array = []    # rastro da bola no ar
var laugh := 0           # quadros rindo (o coelho morreu)
var anchors: Array = []  # pontos de apoio
var faces: Array = []    # [ponto de ataque (encostado na face), apoio de onde sai]
var zone := Rect2()      # bloco, espinhos e folga: nenhuma rota passa por aqui


func _init() -> void:
	rng.seed = RNG_SEED


func on_reset(r) -> void:
	room = r
	_build_points()
	nuts.clear()
	bombs.clear()
	trail.clear()
	if hearts <= 0:
		state = "gone"
		room.door_unlocked = true
		return
	# A sala só reinicia quando o coelho perde as 3 vidas (ou com R): a luta recomeça inteira.
	lives = LIVES
	hearts = HEARTS
	throws = 0
	if not intro_seen:
		# primeira vez: a sala está vazia até o jogador girar o bloco 3 vezes
		state = "wait"
		spins_seen = 0
		was_spinning = false
		t = 0
		pos = Vector2(room.pw - 40, -40)
		last_pos = pos
		return
	_enter()


## Cai do céu, girando.
func _enter() -> void:
	_go_leg(Vector2(room.pw - 40, -30), Vector2(room.pw - 40, _floor_y()), 45)
	room.music_override = room.def.get("boss_music", "")
	if room.music_override != "":
		room.music_request.emit(room.music_override)
	last_pos = pos
	state = "enter"
	dir = -1


## A sala ia matar o coelho (noz, bomba, espinhos): aqui ele perde uma vida e pisca, imune,
## por um instante. Na terceira, morre de verdade e a sala reinicia.
func absorb_kill(r) -> bool:
	lives -= 1
	hud_hit = 50
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


func _floor_y() -> float:
	return room.ph - 8 - SIZE / 2.0


func _phase() -> int:
	return clampi(HEARTS - hearts, 0, 2)


## Pontos de apoio e de ataque, a partir do tamanho da sala e do bloco.
func _build_points() -> void:
	var w: float = room.pw
	var h: float = room.ph
	var lx := 8 + SIZE / 2.0
	var rx := w - 8 - SIZE / 2.0
	var ty := 8 + SIZE / 2.0
	var fy := _floor_y()
	var b: Rect2 = Rect2(room.spin_rect)
	var c := b.get_center()
	zone = b.grow(8 + SIZE / 2.0 + 2)
	anchors = [
		Vector2(30, fy), Vector2(90, fy), Vector2(c.x, fy), Vector2(w - 90, fy), Vector2(w - 30, fy),
		Vector2(lx, 24), Vector2(lx, c.y), Vector2(lx, h - 26),
		Vector2(rx, 24), Vector2(rx, c.y), Vector2(rx, h - 26),
		Vector2(40, ty), Vector2(c.x, ty), Vector2(w - 40, ty),
	]
	var hs := SIZE / 2.0
	faces = [
		[Vector2(c.x, b.position.y - hs), Vector2(c.x, ty)],          # 0 cima: cai do teto
		[Vector2(b.end.x + hs, c.y), Vector2(rx, c.y)],               # 1 direita: da parede direita
		[Vector2(c.x, b.end.y + hs), Vector2(c.x, fy)],               # 2 baixo: sobe do chão
		[Vector2(b.position.x - hs, c.y), Vector2(lx, c.y)],          # 3 esquerda: da parede esquerda
	]


func rect() -> Rect2i:
	return Rect2i(Vector2i((pos - Vector2(SIZE, SIZE) / 2.0).round()), Vector2i(SIZE, SIZE))


# ---------------------------------------------------------------- rotas

func _clear(a: Vector2, b: Vector2) -> bool:
	# amostra o trecho: nenhum ponto pode entrar na zona do bloco
	var n := int(a.distance_to(b) / 3.0) + 1
	for i in n + 1:
		if zone.has_point(a.lerp(b, float(i) / n)):
			return false
	return true


## Menor sequência de apoios de `from` até `to` (busca em largura no grafo de trechos livres).
func _route(from: Vector2, to: Vector2) -> Array:
	var nodes: Array = anchors.duplicate()
	if not nodes.has(to):
		nodes.append(to)
	var prev := {}
	var queue: Array = [from]
	var seen := {from: true}
	while not queue.is_empty():
		var cur: Vector2 = queue.pop_front()
		if cur == to:
			break
		for nx in nodes:
			if not seen.has(nx) and nx != cur and _clear(cur, nx):
				seen[nx] = true
				prev[nx] = cur
				queue.append(nx)
	if not seen.has(to):
		return []
	var out: Array = []
	var k: Vector2 = to
	while k != from:
		out.push_front(k)
		k = prev[k]
	return out


func _go_leg(a: Vector2, b: Vector2, frames := -1) -> void:
	leg_from = a
	leg_to = b
	leg_frames = frames if frames > 0 else maxi(int(a.distance_to(b) / HOP_SPEED * 60.0), 4)
	pos = a
	t = 0
	thrown = false
	if absf(b.x - a.x) > 1.0:
		dir = 1 if b.x > a.x else -1


## Faces que o esquilo aceita atacar agora: vizinhas da face com espinhos (contando o giro em
## andamento) e, claro, sem espinhos.
func _valid_faces() -> Array:
	var s: int = room.spin_face_next()
	return [(s + 1) % 4, (s + 3) % 4]


func _pick_attack() -> void:
	var opts := _valid_faces()
	for i in range(opts.size() - 1, 0, -1):   # embaralha com o sorteio próprio
		var j := rng.randi_range(0, i)
		var tmp = opts[i]
		opts[i] = opts[j]
		opts[j] = tmp
	for f in opts:
		var from: Vector2 = faces[f][1]
		path = _route(pos, from)
		if not path.is_empty() or pos.distance_to(from) < 1.0:
			target_face = f
			_next_hop("aim")
			return
	# sem caminho livre (não deveria acontecer): volta a andar e tenta de novo
	path = []
	_start_walk()


## Vai para o próximo apoio do caminho; no fim, entra em `then`.
func _next_hop(then: String) -> void:
	if path.is_empty():
		state = then
		t = 0
		return
	var nx: Vector2 = path.pop_front()
	_go_leg(pos, nx)
	state = "hop"
	then_state = then


# ---------------------------------------------------------------- simulação

func step(r) -> void:
	room = r
	flash = maxi(flash - 1, 0)
	if room.state == "play":
		room.invuln = maxi(room.invuln - 1, 0)
	_update_nuts()
	_update_bombs()
	if room.state != "play":
		if room.state == "dead":
			laugh += 1
		return
	laugh = 0
	t += 1
	vel_s = vel_s.lerp((pos - last_pos) * 60.0, 0.25)
	last_pos = pos
	if _is_ball():
		if t % 2 == 0:
			trail.append(_vis_pos())
			if trail.size() > 4:
				trail.pop_front()
	elif not trail.is_empty():
		trail.pop_front()
	match state:
		"wait":
			if room.spinning and not was_spinning:
				spins_seen += 1
				t = 0
			was_spinning = room.spinning
			if spins_seen >= INTRO_SPINS and not room.spinning and t >= INTRO_DELAY:
				intro_seen = true
				_enter()
		"enter":
			_fly()
			spin += 0.5
			if t >= leg_frames:
				pos = leg_to
				room.impact.emit(1.2)
				_start_walk()
		"walk":
			spin = 0.0
			var sp: float = WALK_SPEED[_phase()] / 60.0
			var rx: float = room.rabbit.pos.x + 6
			if absf(rx - pos.x) > 4.0:
				dir = 1 if rx > pos.x else -1
			# corridinha de esquilo: dispara e para, em vez de deslizar
			if t % WALK_CYCLE < WALK_CYCLE - WALK_PAUSE:
				pos.x = clampf(pos.x + dir * sp * 1.25, 8 + SIZE / 2.0, room.pw - 8 - SIZE / 2.0)
			if t >= WALK_TIME[_phase()]:
				_start_hops()
		"hop":
			_fly()
			spin += 0.45 * dir
			# só joga no zigue-zague: a caminho do ataque, a atenção fica no bloco
			if not thrown and t >= leg_frames / 2 and then_state == "zigzag":
				thrown = true
				_throw()
			if t >= leg_frames:
				pos = leg_to
				spin = 0.0
				state = "perch"
				t = 0
				room.sfx.emit("jump")
		"perch":
			if t >= PERCH:
				if path.is_empty() and then_state == "zigzag":
					_zigzag()
				else:
					_next_hop(then_state)
		"aim":
			spin = 0.0
			# girou para a face escolhida antes do salto: troca de alvo, nunca se arrisca
			if not _valid_faces().has(target_face):
				_pick_attack()
				return
			if t >= AIM_TIME[_phase()]:
				_go_leg(pos, faces[target_face][0], ATTACK_TIME[_phase()])
				state = "attack"
				room.sfx.emit("jump")
		"attack":
			_fly()
			spin += 0.6 * dir
			if _hits_spikes():
				_get_hit()
				return
			if t >= leg_frames:
				pos = leg_to
				# ricochete: volta pelo mesmo caminho
				_go_leg(pos, leg_from, 14)
				state = "bounce"
				room.impact.emit(0.8)
		"bounce":
			_fly()
			if t <= 3 and _hits_spikes():
				_get_hit()
				return
			if t >= leg_frames:
				pos = leg_to
				path = _route(pos, _nearest_floor())
				_next_hop("walk_start")
		"walk_start":
			_start_walk()
		"stunned":
			if t < leg_frames:
				_fly()
			else:
				pos = leg_to
			spin += 0.2 if t < leg_frames else 0.0
			if t >= STUN_TIME:
				spin = 0.0
				if hearts <= 0:
					_defeat()
				else:
					_start_walk()


func _fly() -> void:
	var k := clampf(float(t) / float(leg_frames), 0.0, 1.0)
	if state == "hop":
		# sai com impulso e chega freando (o ataque continua em velocidade constante)
		k = lerpf(k, k * k * (3.0 - 2.0 * k), 0.6)
	pos = leg_from.lerp(leg_to, k)


func _start_walk() -> void:
	state = "walk"
	t = 0
	pos.y = _floor_y()


func _start_hops() -> void:
	hops_left = HOPS[_phase()]
	_zigzag()


## Um salto de zigue-zague para um apoio livre qualquer (de preferência longe de onde está).
func _zigzag() -> void:
	if hops_left <= 0:
		_pick_attack()
		return
	hops_left -= 1
	var opts: Array = []
	for a in anchors:
		if a.distance_to(pos) > 60.0 and _clear(pos, a):
			opts.append(a)
	if opts.is_empty():
		_pick_attack()
		return
	path = [opts[rng.randi_range(0, opts.size() - 1)]]
	_next_hop("zigzag")


func _nearest_floor() -> Vector2:
	var best: Vector2 = anchors[0]
	for a in anchors:
		if absf(a.y - _floor_y()) < 0.5 and a.distance_to(pos) < best.distance_to(pos):
			best = a
	return best


func _hits_spikes() -> bool:
	var me := rect()
	for h in room.spin_hurt_rects():
		if room.overlaps(me, h):
			return true
	return false


func _get_hit() -> void:
	hearts -= 1
	flash = 40
	room.shake = 5.0
	room.impact.emit(2.4)
	room.sfx.emit("sensor_on")
	for i in 16:
		var a := randf() * TAU
		room.particles.append({
			"pos": pos, "vel": Vector2(cos(a), sin(a)) * randf_range(40.0, 110.0),
			"life": randi_range(14, 26), "col": C_FUR if i % 2 == 0 else C_HEART, "grav": 80.0,
		})
	# arremessado para longe da face e cai no chão, tonto
	var away: Vector2 = (pos - Rect2(room.spin_rect).get_center()).normalized()
	var land := Vector2(clampf(pos.x + away.x * 60.0, 30.0, room.pw - 30.0), _floor_y())
	path = []
	_go_leg(pos, land, 24)
	state = "stunned"


func _defeat() -> void:
	state = "dead"
	room.sfx.emit("gate_open")
	room.door_unlocked = true
	for i in 30:
		var a := randf() * TAU
		room.particles.append({
			"pos": pos, "vel": Vector2(cos(a), sin(a)) * randf_range(30.0, 120.0) - Vector2(0, 30),
			"life": randi_range(20, 40), "col": C_FUR if i % 3 else C_BELLY, "grav": 90.0,
		})
	state = "gone"


# ---------------------------------------------------------------- nozes

## Alterna noz e bomba; a bomba só entra a partir do segundo coração.
func _throw() -> void:
	var ph := _phase()
	var target := Vector2(room.rabbit.pos) + Vector2(6, 6)
	throws += 1
	if throws % 2 == 0 and bombs.size() < MAX_BOMBS[ph] and target.distance_to(pos) >= BOMB_MIN_DIST:
		bombs.append({"pos": pos, "vel": (target - pos).normalized() * BOMB_SPEED})
		room.sfx.emit("jump")
		return
	if nuts.size() >= MAX_NUTS[ph]:
		return
	var d := target - pos
	# arremesso em arco até onde o coelho estava
	var tf := NUT_FLIGHT
	var vel := Vector2(d.x / tf, d.y / tf - 0.5 * NUT_GRAV * tf)
	nuts.append({"pos": pos, "vel": vel, "hits": 0, "ang": 0.0, "av": 0.3 * signf(vel.x)})


func _update_nuts() -> void:
	if room == null or room.state != "play":
		return
	var keep: Array = []
	for n in nuts:
		var alive := true
		n["vel"].y += NUT_GRAV / 60.0
		n["ang"] += n["av"]
		var steps := 3
		for i in steps:
			var np: Vector2 = n["pos"] + n["vel"] / 60.0 / steps
			var r := _nut_rect(np)
			if room.tile_solid_rect(r):
				# quica: descobre o eixo que bateu; cada batida tira força e giro
				var rx := _nut_rect(Vector2(np.x, n["pos"].y))
				if room.tile_solid_rect(rx):
					n["vel"].x *= -0.7
				else:
					n["vel"].y *= -0.6
				n["vel"] *= NUT_KEEP
				n["av"] = 0.55 * absf(n["av"]) * signf(n["vel"].x)
				n["hits"] += 1
				room.sfx.emit("platform")
				_chips(n["pos"], 3)
				if n["hits"] >= 3:
					alive = false
					break
			else:
				n["pos"] = np
		if alive:
			var nr := _nut_rect(n["pos"])
			for h in room.spin_hurt_rects():
				if room.overlaps(nr, h):
					alive = false
			if room.overlaps(nr, room.rabbit.rect):
				room.kill()
		if alive:
			keep.append(n)
		else:
			_nut_break(n["pos"])
	nuts = keep


func _chips(p: Vector2, count: int) -> void:
	for i in count:
		var a := randf() * TAU
		room.particles.append({
			"pos": p, "vel": Vector2(cos(a), sin(a)) * randf_range(15.0, 40.0),
			"life": randi_range(6, 10), "col": C_NUT_DARK, "grav": 120.0,
		})


# ---------------------------------------------------------------- bombas

func _update_bombs() -> void:
	for b in blasts:
		b["t"] += 1
	blasts = blasts.filter(func(b): return b["t"] < BLAST_FRAMES)
	if room == null or room.state != "play":
		return
	var keep: Array = []
	for b in bombs:
		b["pos"] += b["vel"] / 60.0
		var r := _bomb_rect(b["pos"])
		var boom: bool = room.tile_solid_rect(r) or room.overlaps(r, room.rabbit.rect)
		for h in room.spin_hurt_rects():
			boom = boom or room.overlaps(r, h)
		if boom:
			_explode(b["pos"])
		else:
			keep.append(b)
	bombs = keep


func _bomb_rect(p: Vector2) -> Rect2i:
	return Rect2i(Vector2i((p - Vector2(BOMB_SIZE, BOMB_SIZE) / 2.0).round()), Vector2i(BOMB_SIZE, BOMB_SIZE))


## Explode no primeiro contato: fere o coelho se ele estiver dentro do raio.
func _explode(p: Vector2) -> void:
	blasts.append({"pos": p, "t": 0})
	room.shake = maxf(room.shake, 3.0)
	room.impact.emit(1.6)
	room.sfx.emit("gate_close")
	for i in 14:
		var a := randf() * TAU
		room.particles.append({
			"pos": p, "vel": Vector2(cos(a), sin(a)) * randf_range(40.0, 120.0),
			"life": randi_range(8, 18), "col": C_FIRE if i % 2 == 0 else C_BOMB, "grav": 60.0,
		})
	if blast_hits(p, Rect2(room.rabbit.rect)):
		room.kill()


## O raio da explosão alcança o retângulo?
static func blast_hits(p: Vector2, r: Rect2) -> bool:
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return q.distance_to(p) <= BOMB_RADIUS


func _nut_rect(p: Vector2) -> Rect2i:
	return Rect2i(Vector2i((p - Vector2(NUT_SIZE, NUT_SIZE) / 2.0).round()), Vector2i(NUT_SIZE, NUT_SIZE))


func _nut_break(p: Vector2) -> void:
	for i in 6:
		var a := randf() * TAU
		room.particles.append({
			"pos": p, "vel": Vector2(cos(a), sin(a)) * randf_range(20.0, 60.0),
			"life": randi_range(8, 14), "col": C_NUT, "grav": 120.0,
		})


# ---------------------------------------------------------------- desenho
# Jeffrey é desenhado com uns 20 px (a colisão continua 12): óculos escuros, sorriso de dentes
# e um rabo grande que segue o corpo com atraso. No ar, vira uma bola girando.

func _process(_delta: float) -> void:
	anim += 1
	hud_hit = maxi(hud_hit - 1, 0)
	queue_redraw()


func _is_ball() -> bool:
	return state == "enter" or state == "hop" or state == "attack" or state == "bounce"


## Onde ele aparece: a posição da colisão mais o arco do salto e o balanço da corridinha.
func _vis_pos() -> Vector2:
	var p := pos
	if state == "hop":
		var d := leg_to - leg_from
		if absf(d.x) > absf(d.y) * 1.5:
			var k := clampf(float(t) / float(leg_frames), 0.0, 1.0)
			var up := -1.0 if leg_from.y > room.ph / 2.0 else 1.0   # no teto, o arco é para baixo
			p.y += up * sin(k * PI) * minf(12.0, d.length() * 0.1)
	elif state == "walk" and t % WALK_CYCLE < WALK_CYCLE - WALK_PAUSE:
		p.y -= absf(sin(t * 0.39)) * 2.0
	elif state == "aim":
		p += Vector2(sin(anim * 2.3), cos(anim * 3.1)) * 0.6   # treme de vontade
	return p


## Em que superfície ele está apoiado: os pés viram para ela.
func _surface_rot() -> float:
	var m := SIZE / 2.0 + 9.0
	if pos.y >= _floor_y() - 1.0:
		return 0.0
	if pos.x <= m:
		return PI / 2.0
	if pos.x >= room.pw - m:
		return -PI / 2.0
	if pos.y <= m:
		return PI
	return 0.0


func _draw() -> void:
	if room == null:
		return
	var base := Transform2D(0.0, -room.cam.round())
	draw_set_transform_matrix(base)
	# aviso: a face escolhida pisca enquanto ele mira e durante o salto
	if state == "aim" or state == "attack":
		if (t / 4) % 2 == 0 or state == "attack":
			_draw_face_mark(target_face)
	for n in nuts:
		_draw_nut(base, n)
	for b in bombs:
		_draw_bomb(base, b["pos"].round())
	draw_set_transform_matrix(base)
	for b in blasts:
		var k := float(b["t"]) / BLAST_FRAMES
		var p: Vector2 = b["pos"].round()
		draw_circle(p, BOMB_RADIUS * minf(1.0, 0.4 + k * 1.5), Color(C_FIRE, 0.55 * (1.0 - k)))
		draw_circle(p, BOMB_RADIUS * 0.6 * (1.0 - k), Color(1, 1, 1, 0.9 * (1.0 - k)))
		draw_arc(p, BOMB_RADIUS, 0.0, TAU, 20, Color(C_FIRE, 1.0 - k), 1.0)
	if state != "gone" and state != "dead" and state != "wait":
		if flash == 0 or (flash / 3) % 2 == 0:
			_draw_squirrel(base)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_hearts()


func _draw_face_mark(f: int) -> void:
	if f < 0:
		return
	var b := Rect2(room.spin_rect)
	var col := Color(C_AIM, 0.85)
	match f:
		0:
			draw_rect(Rect2(b.position.x, b.position.y - 2, b.size.x, 1), col)
		1:
			draw_rect(Rect2(b.end.x + 1, b.position.y, 1, b.size.y), col)
		2:
			draw_rect(Rect2(b.position.x, b.end.y + 1, b.size.x, 1), col)
		3:
			draw_rect(Rect2(b.position.x - 2, b.position.y, 1, b.size.y), col)


## Bolota girando. A cara muda a cada batida: calma, irritada, rachada e furiosa.
func _draw_nut(base: Transform2D, n: Dictionary) -> void:
	draw_set_transform_matrix(base * Transform2D(n["ang"], Vector2(NUT_DRAW, NUT_DRAW), 0.0, n["pos"].round()))
	draw_rect(Rect2(-3, -1, 7, 4), C_NUT)
	draw_rect(Rect2(-2, 3, 5, 1), C_NUT)
	draw_rect(Rect2(-1, 4, 3, 1), C_NUT)
	draw_rect(Rect2(-3, -3, 7, 2), C_NUT_DARK)
	draw_rect(Rect2(0, -4, 1, 1), C_NUT_DARK)
	var hits: int = n["hits"]
	if hits == 0:
		draw_rect(Rect2(-2, 0, 1, 1), Color(1, 1, 1, 0.35))
		return
	# olhos
	draw_rect(Rect2(-2, 0, 1, 1), C_EYE)
	draw_rect(Rect2(2, 0, 1, 1), C_EYE)
	if hits == 1:
		draw_rect(Rect2(-1, 2, 3, 1), C_EYE)   # boca reta: irritada
	else:
		draw_rect(Rect2(-3, -1, 2, 1), C_EYE)  # sobrancelhas
		draw_rect(Rect2(2, -1, 2, 1), C_EYE)
		draw_rect(Rect2(-1, 2, 3, 2), C_EYE)   # boca aberta
		draw_rect(Rect2(-1, 2, 3, 1), C_TOOTH)
		draw_line(Vector2(0.5, -3), Vector2(1.5, -1), C_TOOTH, 1.0)   # rachadura
		draw_line(Vector2(1.5, -1), Vector2(0.5, 0), C_TOOTH, 1.0)


## Bomba: óculos escuros e sorriso, como o dono. O pavio solta faísca.
func _draw_bomb(base: Transform2D, p: Vector2) -> void:
	draw_set_transform_matrix(base * Transform2D(sin(anim * 0.3) * 0.15, p))
	draw_circle(Vector2.ZERO, 5.0, C_BOMB_DARK)
	draw_circle(Vector2(-0.5, -0.5), 4.0, C_BOMB)
	draw_rect(Rect2(-1, -7, 2, 2), C_BOMB_DARK)
	var sp := Vector2(1 + (anim / 3) % 2, -8 - (anim / 2) % 2)
	draw_rect(Rect2(sp, Vector2(1, 1)), C_FIRE if (anim / 2) % 2 == 0 else Color.WHITE)
	draw_rect(Rect2(-4, -2, 8, 2), C_SHADE)       # óculos
	draw_rect(Rect2(-3, -2, 1, 1), Color(1, 1, 1, 0.8))
	draw_rect(Rect2(-3, 1, 6, 2), C_SHADE)        # sorriso
	draw_rect(Rect2(-2, 1, 4, 1), C_TOOTH)
	draw_rect(Rect2(0, 1, 1, 1), C_BOMB_DARK)


func _draw_squirrel(base: Transform2D) -> void:
	if _is_ball() or (state == "stunned" and t < leg_frames):
		# rastro
		draw_set_transform_matrix(base)
		for i in trail.size():
			draw_circle(trail[i].round(), 3.0 + i, Color(C_FUR, 0.10 + 0.07 * i))
		draw_set_transform_matrix(base * Transform2D(spin, Vector2(dir, 1), 0.0, _vis_pos().round()))
		_draw_ball(state == "stunned")
		return
	var mood := "calm"
	var rot := _surface_rot()
	var sc := Vector2.ONE
	var p := _vis_pos()
	if state == "stunned":
		mood = "dizzy"
		sc = Vector2(1.1, 0.85)
	elif room.state == "dead":
		mood = "laugh"
		p.y -= absf(sin(laugh * 0.5)) * 2.0
	elif state == "aim":
		mood = "aim"
		sc = Vector2(1.12, 0.84)   # agachado
	elif state == "perch":
		# amassa ao pousar; encolhe de novo antes de sair
		var k := maxf(1.0 - t / 5.0, 0.0) + (0.5 if t >= PERCH - 2 else 0.0)
		sc = Vector2(1.0 + 0.25 * k, 1.0 - 0.3 * k)
	# escala em torno dos pés (y = +6), não do centro
	var xf := Transform2D(rot, Vector2(dir * sc.x, sc.y), 0.0, p.round())
	xf = xf.translated_local(Vector2(0, 6.0 * (1.0 - sc.y) / sc.y))
	draw_set_transform_matrix(base * xf)
	_draw_upright(mood)


## No ar: enrolado em bola, o rabo em volta.
func _draw_ball(hurt: bool) -> void:
	draw_circle(Vector2(-1, -1), 9.0, C_FUR_DARK)
	draw_circle(Vector2(-4, -3), 5.0, C_FUR)        # rabo enrolado
	draw_circle(Vector2(1, 1), 7.0, C_FUR)
	draw_circle(Vector2(2, 3), 4.0, C_BELLY)
	draw_rect(Rect2(2, -8, 3, 3), C_FUR_DARK)       # orelha
	if hurt:
		draw_rect(Rect2(2, -3, 2, 2), Color.WHITE)
		draw_rect(Rect2(6, -3, 2, 2), Color.WHITE)
		draw_rect(Rect2(3, -2, 1, 1), C_EYE)
		draw_rect(Rect2(7, -2, 1, 1), C_EYE)
		draw_rect(Rect2(4, 1, 3, 3), C_EYE)
	else:
		draw_rect(Rect2(1, -4, 8, 3), C_SHADE)
		draw_rect(Rect2(2, -4, 1, 1), Color(1, 1, 1, 0.8))
		draw_rect(Rect2(3, 1, 5, 2), C_SHADE)
		draw_rect(Rect2(4, 1, 3, 1), C_TOOTH)


## Em pé. Origem no centro da colisão, pés em y = +6, olhando para +x.
func _draw_upright(mood: String) -> void:
	var fluff := 1.2 if mood == "aim" else 0.0
	# rabo: curva de três pontos; a ponta atrasa em relação ao corpo
	var lag := (Vector2(-vel_s.x * dir, -vel_s.y) * 0.035).limit_length(5.0)
	var a := Vector2(-5, 3)
	var c := Vector2(-15, -1)
	var b := Vector2(-9 + sin(anim * 0.08) * 1.2, -14) + lag
	if mood == "dizzy":
		c = Vector2(-12, 5)
		b = Vector2(-16, 3)
	elif mood == "laugh":
		b.y += sin(laugh * 0.5) * 2.0
	for pass_i in 2:
		for i in 7:
			var k := i / 6.0
			var q := a.lerp(c, k).lerp(c.lerp(b, k), k)
			if fluff > 0.0:
				q += Vector2(sin(anim * 1.7 + i), cos(anim * 2.1 + i)) * 0.7
			var r := 2.5 + 3.0 * k + fluff
			if pass_i == 0:
				draw_circle(q, r, C_FUR_DARK)
			else:
				draw_circle(q + Vector2(0.5, 0.5), r - 1.5, C_FUR)
	# pés: alternam na corridinha
	var step_a := 0
	var step_b := 0
	if state == "walk" and t % WALK_CYCLE < WALK_CYCLE - WALK_PAUSE:
		step_a = -1 if (t / 4) % 2 == 0 else 0
		step_b = -1 - step_a
	draw_rect(Rect2(-5, 4 + step_a, 4, 2), C_FUR_DARK)
	draw_rect(Rect2(1, 4 + step_b, 5, 2), C_FUR_DARK)
	# corpo
	draw_rect(Rect2(-5, -4, 10, 9), C_FUR)
	draw_rect(Rect2(-4, -5, 8, 1), C_FUR)
	draw_rect(Rect2(-2, -2, 6, 7), C_BELLY)
	# braços
	if mood == "aim":
		draw_rect(Rect2(4, 1, 4, 2), C_FUR_DARK)        # patas à frente, pronto para saltar
	elif mood == "laugh":
		draw_rect(Rect2(3, -2, 3, 2), C_FUR_DARK)       # mão na barriga
	else:
		draw_rect(Rect2(3, -1, 2, 3), C_FUR_DARK)
	var hy := -13
	if mood == "laugh":
		hy -= 1 if (laugh / 4) % 2 == 0 else 0
	_draw_head(hy, mood)


## Cabeça (também usada no retrato do alto da tela). `hy` é o topo dela.
func _draw_head(hy: int, mood: String) -> void:
	var ph := _phase()
	draw_rect(Rect2(0, hy - 3, 3, 4), C_FUR_DARK)       # orelhas
	draw_rect(Rect2(6, hy - 3, 3, 4), C_FUR_DARK)
	draw_rect(Rect2(1, hy - 2, 1, 2), C_BELLY)
	draw_rect(Rect2(7, hy - 2, 1, 2), C_BELLY)
	draw_rect(Rect2(-1, hy, 11, 9), C_FUR)
	draw_rect(Rect2(0, hy - 1, 9, 1), C_FUR)
	draw_rect(Rect2(4, hy + 5, 6, 4), C_BELLY)          # focinho
	draw_rect(Rect2(10, hy + 4, 1, 1), C_EYE)           # nariz
	# descabelado a cada coração perdido
	if ph >= 1:
		draw_rect(Rect2(3, hy - 3, 1, 2), C_FUR)
		draw_rect(Rect2(-2, hy + 2, 1, 1), C_FUR)
	if ph >= 2:
		draw_rect(Rect2(5, hy - 4, 1, 3), C_FUR)
		draw_rect(Rect2(-2, hy + 5, 1, 1), C_FUR)
		draw_rect(Rect2(-6, -1, 1, 1), C_FUR)
	# rosto
	if mood == "dizzy":
		# óculos tortos, olhos arregalados, boca aberta, estrelinhas
		draw_rect(Rect2(1, hy + 1, 3, 3), Color.WHITE)
		draw_rect(Rect2(6, hy + 1, 3, 3), Color.WHITE)
		draw_rect(Rect2(2 + (anim / 6) % 2, hy + 2, 1, 1), C_EYE)
		draw_rect(Rect2(7 + (anim / 6) % 2, hy + 2, 1, 1), C_EYE)
		draw_line(Vector2(0, hy + 4), Vector2(10, hy + 7), C_SHADE, 2.0)
		draw_rect(Rect2(6, hy + 6, 2, 2), C_EYE)
		for i in 3:
			var ang := anim * 0.12 + i * TAU / 3.0
			var sp := Vector2(4 + cos(ang) * 9.0, hy - 4 + sin(ang) * 2.5)
			draw_rect(Rect2(sp, Vector2(1, 1)), C_AIM)
			draw_rect(Rect2(sp + Vector2(-1, 0), Vector2(3, 1)), Color(C_AIM, 0.5))
			draw_rect(Rect2(sp + Vector2(0, -1), Vector2(1, 3)), Color(C_AIM, 0.5))
		return
	draw_rect(Rect2(0, hy + 1, 10, 3), C_SHADE)          # óculos escuros
	draw_rect(Rect2(-1, hy + 2, 1, 1), C_SHADE)
	draw_rect(Rect2(1 + (anim / 20) % 8, hy + 1, 1, 1), Color(1, 1, 1, 0.85))   # brilho que passeia
	if ph >= 2:
		draw_line(Vector2(3, hy - 0.5), Vector2(9, hy + 1.5), C_SHADE, 1.0)     # cenho fechado
	# sorriso: discreto em calma, de orelha a orelha ao mirar e ao rir
	if mood == "calm":
		draw_rect(Rect2(5, hy + 6, 5, 2), C_SHADE)
		draw_rect(Rect2(6, hy + 6, 3, 1), C_TOOTH)
	else:
		var open := 1 if mood == "laugh" and (laugh / 4) % 2 == 0 else 0
		draw_rect(Rect2(2, hy + 5, 8, 3 + open), C_SHADE)
		draw_rect(Rect2(3, hy + 5, 6, 2), C_TOOTH)
		draw_rect(Rect2(5, hy + 5, 1, 2), C_SHADE)
		draw_rect(Rect2(7, hy + 5, 1, 2), C_SHADE)


## No alto da tela: retrato do coelho com as vidas dele à esquerda, as do Jeffrey com o retrato
## à direita. (A sala é desenhada a partir do centro da tela: x de -160 a 160, y de -90 a 90.)
func _draw_hearts() -> void:
	if state == "wait":
		return   # antes de o Jeffrey aparecer, não há barras de vida
	var y := -89.0
	# coelho
	var rb := Rect2(-72, y, 16, 18)
	_draw_frame(rb, hud_hit > 0 and (hud_hit / 4) % 2 == 0)
	var tex: Texture2D = room._rabbit_tex("up", "stand", room.state == "dead" or hud_hit > 0)
	draw_texture(tex, rb.position + Vector2(2, 1))
	for i in LIVES:
		_draw_heart(Vector2(-52 + i * 10, y + 6), i < lives)
	# Jeffrey
	var jb := Rect2(56, y, 16, 18)
	_draw_frame(jb, flash > 0 and (flash / 4) % 2 == 0)
	draw_set_transform_matrix(Transform2D(0.0, Vector2(-1, 1), 0.0, jb.position + Vector2(12, 15)))
	_draw_head(-11, "dizzy" if state == "stunned" or hearts <= 0 else ("laugh" if room.state == "dead" else "calm"))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for i in HEARTS:
		_draw_heart(Vector2(45 - i * 10, y + 6), i < hearts)


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

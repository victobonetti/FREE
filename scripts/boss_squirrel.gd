extends Node2D
## Boss 1: Jeffrey, o esquilo (GDD 8b, D63). Ator da sala (campo "actors"): a sala chama
## step(room) a cada quadro de jogo e on_reset(room) quando reinicia (morte do coelho ou R).
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
const HOP_SPEED := 230.0             # px/s nos saltos entre apoios
const WALK_SPEED := [38.0, 48.0, 58.0]       # por fase (corações perdidos: 0, 1, 2)
const WALK_TIME := [100, 75, 55]             # quadros andando antes de atacar
const HOPS := [1, 2, 3]                      # saltos de zigue-zague antes do ataque
const AIM_TIME := [40, 30, 24]               # quadros de aviso antes do salto de ataque
const ATTACK_TIME := [60, 42, 30]            # duração do salto de ataque: a janela de reação
const MAX_NUTS := [0, 2, 3]
const STUN_TIME := 75
const PERCH := 7                     # quadros parado em cada apoio
const NUT_GRAV := 330.0
const NUT_SIZE := 4

const C_FUR := Color("c47a3c")
const C_FUR_DARK := Color("8a4f22")
const C_BELLY := Color("e8c79a")
const C_EYE := Color("1a1410")
const C_NUT := Color("9a6a3a")
const C_NUT_DARK := Color("5e3d1d")
const C_HEART := Color("e0657c")
const C_HEART_EMPTY := Color(1, 1, 1, 0.18)
const C_AIM := Color("ffe9a8")

var room
var hearts := HEARTS
var state := "enter"     # enter, walk, hop, perch, aim, attack, bounce, stunned, dead, gone
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
var nuts: Array = []     # {pos, vel, hits}
var anchors: Array = []  # pontos de apoio
var faces: Array = []    # [ponto de ataque (encostado na face), apoio de onde sai]
var zone := Rect2()      # bloco, espinhos e folga: nenhuma rota passa por aqui


func on_reset(r) -> void:
	room = r
	_build_points()
	nuts.clear()
	if hearts <= 0:
		state = "gone"
		room.door_unlocked = true
		return
	# Os corações perdidos continuam perdidos depois que o coelho morre.
	_go_leg(Vector2(room.pw + 30, -20), Vector2(room.pw - 40, _floor_y()), 50)
	state = "enter"
	dir = -1


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
	opts.shuffle()
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
	_update_nuts()
	if room.state != "play":
		return
	t += 1
	match state:
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
			pos.x = clampf(pos.x + dir * sp, 8 + SIZE / 2.0, room.pw - 8 - SIZE / 2.0)
			if t >= WALK_TIME[_phase()]:
				_start_hops()
		"hop":
			_fly()
			spin += 0.45 * dir
			if not thrown and t >= leg_frames / 2 and _phase() > 0:
				thrown = true
				_throw_nut()
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
	_check_rabbit()


func _fly() -> void:
	var k := clampf(float(t) / float(leg_frames), 0.0, 1.0)
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
	path = [opts[randi() % opts.size()]]
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


func _check_rabbit() -> void:
	if state in ["stunned", "dead", "gone", "enter"]:
		return
	if room.overlaps(rect(), room.rabbit.rect):
		room.kill()


# ---------------------------------------------------------------- nozes

func _throw_nut() -> void:
	if nuts.size() >= MAX_NUTS[_phase()]:
		return
	var target := Vector2(room.rabbit.pos) + Vector2(6, 6)
	var d := target - pos
	# arremesso em arco: tempo de voo ~0,7 s até o coelho
	var tf := 0.7
	var vel := Vector2(d.x / tf, d.y / tf - 0.5 * NUT_GRAV * tf)
	nuts.append({"pos": pos, "vel": vel, "hits": 0})


func _update_nuts() -> void:
	if room == null or room.state != "play":
		return
	var keep: Array = []
	for n in nuts:
		var alive := true
		n["vel"].y += NUT_GRAV / 60.0
		var steps := 3
		for i in steps:
			var np: Vector2 = n["pos"] + n["vel"] / 60.0 / steps
			var r := _nut_rect(np)
			if room.tile_solid_rect(r):
				# quica: descobre o eixo que bateu
				var rx := _nut_rect(Vector2(np.x, n["pos"].y))
				if room.tile_solid_rect(rx):
					n["vel"].x *= -0.7
				else:
					n["vel"].y *= -0.6
				n["hits"] += 1
				room.sfx.emit("platform")
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

func _process(_delta: float) -> void:
	queue_redraw()


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
		var p: Vector2 = n["pos"].round()
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), C_NUT)
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 1)), C_NUT_DARK)
	if state != "gone" and state != "dead":
		var visible_now := flash == 0 or (flash / 3) % 2 == 0
		if state == "stunned" and (t / 5) % 2 == 1:
			visible_now = false
		if visible_now:
			_draw_squirrel()
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


func _draw_squirrel() -> void:
	var p := pos.round()
	draw_set_transform_matrix(Transform2D(0.0, -room.cam.round()) * Transform2D(spin, Vector2(dir, 1), 0.0, p))
	# rabo felpudo, curvado para cima atrás do corpo
	draw_circle(Vector2(-6, -4), 5.0, C_FUR_DARK, true, -1.0, false)
	draw_circle(Vector2(-7, -7), 4.0, C_FUR, true, -1.0, false)
	draw_circle(Vector2(-5, -1), 3.0, C_FUR, true, -1.0, false)
	# corpo e cabeça
	draw_rect(Rect2(-3, -2, 8, 8), C_FUR)
	draw_rect(Rect2(-1, 0, 4, 6), C_BELLY)
	draw_rect(Rect2(1, -6, 6, 5), C_FUR)
	draw_rect(Rect2(2, -8, 2, 2), C_FUR_DARK)   # orelha
	draw_rect(Rect2(5, -5, 1, 1), C_EYE)
	draw_rect(Rect2(7, -3, 1, 1), C_EYE)        # nariz
	if state == "aim":
		# agachado, pronto para saltar: patas à frente
		draw_rect(Rect2(4, 4, 3, 2), C_FUR_DARK)


func _draw_hearts() -> void:
	# no alto da tela, centralizado (a sala é desenhada a partir do centro da tela)
	var o := Vector2(-HEARTS * 6.0, -84.0)
	for i in HEARTS:
		var c := C_HEART if i < hearts else C_HEART_EMPTY
		var q := o + Vector2(i * 12, 0)
		draw_rect(Rect2(q + Vector2(1, 0), Vector2(2, 1)), c)
		draw_rect(Rect2(q + Vector2(4, 0), Vector2(2, 1)), c)
		draw_rect(Rect2(q + Vector2(0, 1), Vector2(7, 2)), c)
		draw_rect(Rect2(q + Vector2(1, 3), Vector2(5, 1)), c)
		draw_rect(Rect2(q + Vector2(2, 4), Vector2(3, 1)), c)
		draw_rect(Rect2(q + Vector2(3, 5), Vector2(1, 1)), c)

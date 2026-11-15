extends Node2D
## Uma sala: grade de tiles, coelho, caixas, compartimentos, porta, espinhos, comportas e
## plataformas por orientação. A sala pode ter qualquer tamanho; a câmera segue o coelho.
##
## Rotação: a simulação sempre acontece com a gravidade para baixo. Ao girar, todos os
## dados da sala (tiles, caixas, coelho, câmera...) são rotacionados 90° de verdade, e só o
## desenho faz a animação (de -90° até 0°). Assim a física nunca precisa saber de orientação.

signal completed
## "jump" | "death" | "win" | "sensor_on" | "sensor_off" | "gate_open" | "gate_close" | "platform"
signal sfx(name: String)
signal impact(strength: float)  # pouso de caixa; 0 a 2,5 (mais altura e mais caixas = mais forte)

const TILE := 8
const VIEW := Vector2(320, 180)  # tamanho da tela (resolução interna)
const CAM_SMOOTH := 0.12
const ROT_FRAMES := 16       # duração da animação do giro
const ROT_COOLDOWN := 36     # espera extra depois do giro, até poder girar de novo
const ROT_BUFFER := 6        # apertar até 6 quadros antes do fim da recarga ainda vale
const DT := 1.0 / 60.0
const BOX_GRAVITY := 900.0
const BOX_MAX_FALL := 160.0
const IMPACT_MIN_DIST := 8     # queda mínima (px) para o pouso virar efeito
const IMPACT_FULL_DIST := 128  # queda (px) que dá força 1 a uma caixa sozinha
const IMPACT_MAX := 2.5
const IMPACT_CHAIN := 0.6      # quanto da força recente soma ao próximo pouso (várias caixas)
const SENSOR_FRAMES := 16
const SWITCH_FRAMES := 12      # efeito de comporta/plataforma mudando de estado
const WIN_FRAMES := 44
const DEATH_FRAMES := 20
const GATE_SOCKETS := "abcdefghi"  # compartimento "a" abre a comporta "1", e assim por diante
const PLATFORM_CHARS := "=}_{"     # seta para cima, direita, baixo, esquerda

const Rabbit := preload("res://scripts/rabbit.gd")
const Box := preload("res://scripts/box.gd")

const C_BG := Color("0c0c12")
const C_WALL := Color("181821")
const C_EDGE := Color("e2ddcf")
const C_BOX := Color("2aa6ee")
const C_BOX_DARK := Color("1b78b3")
const C_BOX_MID := Color("1f8fd0")
const C_SOCKET := Color("34343d")
const C_SOCKET_FRAME := Color("85858f")
const C_SOCKET_ON := Color("d8c25c")
const C_DOOR_LOCKED := Color("5d76a6")
const C_DOOR_LOCKED_DARK := Color("46597d")
const C_DOOR_OPEN := Color("f3cf3b")
const C_DOOR_INNER := Color("2a2209")
const C_SPIKE := Color("e0657c")
const C_DUST := Color("bdb8ab")
const C_GATE := Color("6fd3b8")
const C_GATE_DARK := Color("1d3a35")
const C_PLAT := Color("b9a3f0")
const C_PLAT_DARK := Color("3a3158")

# --- Sprite do coelho (12x16, virado para a direita), montado por partes ---
# w branco | g sombra | p rosa | r olho
const EARS := {
	"up": [
		"......w..w..",
		".....ww.ww..",
		".....wp.wp..",
		".....wp.wp..",
		".....wp.wp..",
		".....wp.wp..",
		".....ww.ww..",
	],
	"back": [
		"............",
		"..ww..ww....",
		"..wpw.wpw...",
		"...wpw.wpw..",
		"....wpwwpw..",
		".....wwwww..",
		".....ww.ww..",
	],
	"fall": [
		"....w....w..",
		"....ww..ww..",
		"....wp..pw..",
		".....wp.pw..",
		".....wp.pw..",
		".....wp.wp..",
		".....ww.ww..",
	],
	"twitch": [
		"......w.....",
		".....ww.....",
		".....wp..ww.",
		".....wp.wpw.",
		".....wp.wp..",
		".....wp.wp..",
		".....ww.ww..",
	],
}
const BODY := [
	".....wwwwww.",
	"....wwwwwrw.",
	"....wwwwwwwp",
	".....wwwwww.",
	"...wwwwww...",
	"wwwwwwwww...",
	".wwwwwwww...",
	"..wwwwwwg...",
]
const FEET := {
	"stand": "..ww..www...",
	"run_a": ".ww.....www.",
	"run_b": "...wwwww....",
	"air": ".ww..ww.....",
	"push_a": "..ww....www.",
	"push_b": "...www.ww...",
}

var def: Dictionary = {}
var allow_rotate := true

# tamanho atual da sala (troca de largura e altura a cada giro)
var gw := 20  # em tiles
var gh := 20
var pw := 160  # em pixels
var ph := 160

var tiles := PackedByteArray()
var boxes: Array = []
var sockets: Array = []        # Rect2i
var socket_group: Array = []   # 0 = porta de saída; 1..9 = comporta
var socket_filled: Array = []
var socket_fx: Array = []      # quadros restantes do efeito de sensor, por compartimento
var door := Rect2i()
var has_door := false
var door_open := false
var door_flash := 0
var spikes: Array = []
var gates: Array = []      # {"id", "rects": Array[Rect2i], "closed", "anim", "fx"}
var platforms: Array = []  # {"rect": Rect2i, "facing", "solid", "fx"}
var rabbit

var state := "play"  # play | dead | won | done
var timer := 0
var frame := 0

var rotating := false
var rot_frame := 0
var rot_from := 0.0
var view_angle := 0.0
var pending_rot := 0
var rot_lock := 0  # quadros até poder girar de novo (animação + recarga)
var orientation := 0  # giros acumulados (0..3), só informativo

var cam := Vector2.ZERO  # ponto da sala (px) que fica no centro da tela

var particles: Array = []
var rabbit_frames := {}
var shake := 0.0  # tremor de tela (px), decai sozinho
var jolt_amp := 0.0    # solavanco na direção da gravidade (px): oscila e amortece
var jolt_phase := 0.0
var impact_recent := 0.0  # força dos pousos dos últimos quadros; decai e soma com o próximo


func _process(_delta: float) -> void:
	queue_redraw()


func setup(room_def: Dictionary) -> void:
	def = room_def
	allow_rotate = room_def.get("rotate", true)
	reset()


func reset() -> void:
	var rows: Array = def["rows"]
	gh = rows.size()
	gw = 0
	for line in rows:
		gw = maxi(gw, String(line).length())
	pw = gw * TILE
	ph = gh * TILE
	tiles = PackedByteArray()
	tiles.resize(gw * gh)
	boxes.clear()
	sockets.clear()
	socket_group.clear()
	socket_filled.clear()
	socket_fx.clear()
	spikes.clear()
	gates.clear()
	platforms.clear()
	particles.clear()
	jolt_amp = 0.0
	impact_recent = 0.0
	shake = 0.0
	door = Rect2i()
	has_door = false
	door_open = false
	door_flash = 0
	rotating = false
	rot_frame = 0
	view_angle = 0.0
	pending_rot = 0
	rot_lock = 0
	orientation = 0
	state = "play"
	timer = 0
	rabbit = Rabbit.new()
	_parse(rows)
	var sr: int = def.get("start_rot", 0)
	for i in absi(sr):
		_rotate_logic(1 if sr > 0 else -1)
	_update_sockets()
	_update_mechanisms(true)
	cam = _cam_target()


## 0.0 logo após girar, 1.0 quando o giro está disponível de novo.
func rot_ratio() -> float:
	return 1.0 - float(rot_lock) / float(ROT_FRAMES + ROT_COOLDOWN)


# ---------------------------------------------------------------- parsing

func _parse(rows: Array) -> void:
	var visited := {}
	var door_cells: Array = []
	var gate_cells := {}  # id -> Array[Rect2i]
	for r in gh:
		var line: String = rows[r]
		for c in gw:
			var ch: String = line[c] if c < line.length() else "#"
			var key := Vector2i(c, r)
			var cell := Rect2i(c * TILE, r * TILE, TILE, TILE)
			if ch == "#":
				tiles[r * gw + c] = 1
			elif ch == "^":
				_add_spike(c, r, 0)
			elif ch == ">":
				_add_spike(c, r, 1)
			elif ch == "v":
				_add_spike(c, r, 2)
			elif ch == "<":
				_add_spike(c, r, 3)
			elif ch == "D":
				door_cells.append(key)
			elif ch >= "1" and ch <= "9":
				var gid := int(ch)
				if not gate_cells.has(gid):
					gate_cells[gid] = []
				gate_cells[gid].append(cell)
			elif PLATFORM_CHARS.contains(ch):
				platforms.append({"rect": cell, "facing": PLATFORM_CHARS.find(ch), "solid": false, "fx": 0})
			elif (ch == "P" or ch == "B" or ch == "S" or GATE_SOCKETS.contains(ch)) and not visited.has(key):
				for dy in 2:
					for dx in 2:
						visited[Vector2i(c + dx, r + dy)] = true
				var origin := Vector2i(c * TILE, r * TILE)
				if ch == "P":
					rabbit.pos = origin + Vector2i(2, 2)  # hitbox 12x12 centrada no bloco 16x16
				elif ch == "B":
					boxes.append(Box.new(origin))
				else:
					sockets.append(Rect2i(origin, Vector2i(16, 16)))
					socket_group.append(0 if ch == "S" else GATE_SOCKETS.find(ch) + 1)
	if not door_cells.is_empty():
		var lo: Vector2i = door_cells[0]
		var hi: Vector2i = door_cells[0]
		for k in door_cells:
			lo = Vector2i(mini(lo.x, k.x), mini(lo.y, k.y))
			hi = Vector2i(maxi(hi.x, k.x), maxi(hi.y, k.y))
		door = Rect2i(lo * TILE, (hi - lo + Vector2i.ONE) * TILE)
		has_door = true
	var ids := gate_cells.keys()
	ids.sort()
	for gid in ids:
		gates.append({"id": gid, "rects": gate_cells[gid], "closed": true, "anim": 0.0, "fx": 0})


func _add_spike(c: int, r: int, facing: int) -> void:
	spikes.append({"rect": Rect2i(c * TILE, r * TILE, TILE, TILE), "facing": facing})


# ---------------------------------------------------------------- rotação

## Gira um retângulo junto com a sala (usa o tamanho atual, antes da troca de largura/altura).
func _rot_rect(r: Rect2i, dir: int) -> Rect2i:
	if dir > 0:  # horário: (x, y) -> (H - y, x)
		return Rect2i(ph - (r.position.y + r.size.y), r.position.x, r.size.y, r.size.x)
	# anti-horário: (x, y) -> (y, W - x)
	return Rect2i(r.position.y, pw - (r.position.x + r.size.x), r.size.y, r.size.x)


func _rot_point(p: Vector2, dir: int) -> Vector2:
	if dir > 0:
		return Vector2(ph - p.y, p.x)
	return Vector2(p.y, pw - p.x)


func _rotate_logic(dir: int) -> void:
	var nw := gh
	var nh := gw
	var nt := PackedByteArray()
	nt.resize(nw * nh)
	for r in gh:
		for c in gw:
			if tiles[r * gw + c] != 0:
				var nc: int
				var nr: int
				if dir > 0:
					nc = gh - 1 - r
					nr = c
				else:
					nc = r
					nr = gw - 1 - c
				nt[nr * nw + nc] = 1
	for b in boxes:
		b.pos = _rot_rect(b.rect, dir).position
		b.vel_y = 0.0
		b.rem_y = 0.0
		b.fall_dist = 0
		b.settled = false
	for i in sockets.size():
		sockets[i] = _rot_rect(sockets[i], dir)
	if has_door:
		door = _rot_rect(door, dir)
	for s in spikes:
		s["rect"] = _rot_rect(s["rect"], dir)
		s["facing"] = posmod(s["facing"] + dir, 4)
	for g in gates:
		var rs: Array = g["rects"]
		for i in rs.size():
			rs[i] = _rot_rect(rs[i], dir)
	for p in platforms:
		p["rect"] = _rot_rect(p["rect"], dir)
		p["facing"] = posmod(p["facing"] + dir, 4)
	rabbit.pos = _rot_rect(rabbit.rect, dir).position
	rabbit.on_rotate()
	cam = _rot_point(cam, dir)
	for p in particles:
		p["pos"] = _rot_point(p["pos"], dir)
		p["vel"] = Vector2(-p["vel"].y, p["vel"].x) if dir > 0 else Vector2(p["vel"].y, -p["vel"].x)
	# só agora a sala troca de largura e altura
	tiles = nt
	gw = nw
	gh = nh
	pw = gw * TILE
	ph = gh * TILE
	orientation = posmod(orientation + dir, 4)


func _begin_rotate(dir: int) -> void:
	if not rabbit.on_ground:
		rabbit.air_rot = false
	_rotate_logic(dir)
	rotating = true
	rot_frame = 0
	rot_from = -dir * PI / 2.0
	view_angle = rot_from
	rot_lock = ROT_FRAMES + ROT_COOLDOWN


func _ease(t: float) -> float:
	if t < 0.5:
		return 4.0 * t * t * t
	return 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0


# ---------------------------------------------------------------- câmera

## Onde a câmera quer estar: centralizada no eixo em que a sala cabe na tela; no outro,
## seguindo o coelho, sem mostrar além das bordas da sala.
func _cam_target() -> Vector2:
	var rc := Vector2(rabbit.pos) + Vector2(6, 2)
	var t := Vector2.ZERO
	t.x = pw / 2.0 if pw <= VIEW.x else clampf(rc.x, VIEW.x / 2.0, pw - VIEW.x / 2.0)
	t.y = ph / 2.0 if ph <= VIEW.y else clampf(rc.y, VIEW.y / 2.0, ph - VIEW.y / 2.0)
	return t


func _update_camera() -> void:
	cam = cam.lerp(_cam_target(), CAM_SMOOTH)


# ---------------------------------------------------------------- colisão

func overlaps(a: Rect2i, b: Rect2i) -> bool:
	return a.position.x < b.position.x + b.size.x \
		and a.position.x + a.size.x > b.position.x \
		and a.position.y < b.position.y + b.size.y \
		and a.position.y + a.size.y > b.position.y


func tile_solid_rect(r: Rect2i) -> bool:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.position.x + r.size.x - 1
	var y1 := r.position.y + r.size.y - 1
	if x0 < 0 or y0 < 0 or x1 >= pw or y1 >= ph:
		return true
	for ty in range(y0 >> 3, (y1 >> 3) + 1):
		for tx in range(x0 >> 3, (x1 >> 3) + 1):
			if tiles[ty * gw + tx] != 0:
				return true
	return false


## Paredes, comportas fechadas e plataformas sólidas. A porta nunca bloqueia ninguém.
func solid_static(r: Rect2i) -> bool:
	if tile_solid_rect(r):
		return true
	for g in gates:
		if g["closed"]:
			for gr in g["rects"]:
				if overlaps(r, gr):
					return true
	for p in platforms:
		if p["solid"] and overlaps(r, p["rect"]):
			return true
	return false


func box_at(r: Rect2i, ignore):
	for b in boxes:
		if b != ignore and overlaps(r, b.rect):
			return b
	return null


## Há coelho ou caixa ocupando este retângulo? (comportas e plataformas nunca esmagam)
func _occupied(r: Rect2i) -> bool:
	if rabbit != null and overlaps(r, rabbit.rect):
		return true
	return box_at(r, null) != null


func push_box(b, d: Vector2i) -> bool:
	var nxt := Rect2i(b.pos + d, Vector2i(Box.SIZE, Box.SIZE))
	if solid_static(nxt):
		return false
	var other = box_at(nxt, b)
	if other != null and not push_box(other, d):
		return false
	b.pos += d
	return true


# ---------------------------------------------------------------- simulação

func step(inp: Dictionary) -> void:
	frame += 1
	_update_particles()
	door_flash = maxi(door_flash - 1, 0)
	if state == "won":
		timer -= 1
		# ondas de luz saindo da porta, uma depois da outra
		if timer == WIN_FRAMES - 8 or timer == WIN_FRAMES - 16:
			_door_ring()
		if timer <= 0:
			state = "done"
			completed.emit()
		return
	if state == "dead":
		timer -= 1
		if timer <= 0:
			reset()
		return
	if state != "play":
		return

	rot_lock = maxi(rot_lock - 1, 0)
	var req: int = inp.get("rotate", 0)
	if req != 0 and rot_lock <= ROT_BUFFER:
		pending_rot = req
	if rotating:
		rot_frame += 1
		var t := float(rot_frame) / float(ROT_FRAMES)
		if t >= 1.0:
			rotating = false
			view_angle = 0.0
		else:
			view_angle = rot_from * (1.0 - _ease(t))
			return
	if pending_rot != 0 and rot_lock == 0:
		var dir := pending_rot
		pending_rot = 0
		if allow_rotate and (rabbit.on_ground or rabbit.air_rot):
			_begin_rotate(dir)
			return

	_update_mechanisms(false)
	rabbit.update(self, inp)
	if rabbit.ev_jump:
		_dust(3, 30.0)
		_jump_ring()
		sfx.emit("jump")
	if rabbit.ev_land:
		_dust(5, 45.0)
	if rabbit.push_t > 0 and frame % 7 == 0:
		_push_dust()
	_update_boxes()
	if state != "play":
		return
	_update_sockets()
	_update_camera()
	if state != "play":
		return
	_check_hazards()
	if state != "play":
		return
	_check_win()


func _update_boxes() -> void:
	boxes.sort_custom(func(a, b): return a.pos.y > b.pos.y)
	for b in boxes:
		_box_step(b)
		if state != "play":
			return


func _box_supported(b) -> bool:
	# Só a faixa central da base apoia: a caixa "tomba" no buraco quando o centro passa da borda.
	var s := Rect2i(b.pos.x + 3, b.pos.y + Box.SIZE, Box.SIZE - 6, 1)
	return solid_static(s) or box_at(s, b) != null


func _box_blocked(b, r: Rect2i) -> bool:
	return solid_static(r) or box_at(r, b) != null


## Caixa que bate no chão: poeira, anel, detritos, som e um solavanco na direção da gravidade.
## A força cresce com a altura da queda e com quantas caixas pousaram há pouco.
func _box_impact(b, dist: int) -> void:
	var e := clampf(float(dist) / float(IMPACT_FULL_DIST), 0.0, 1.0)
	var s := minf(e + IMPACT_CHAIN * impact_recent, IMPACT_MAX)
	impact_recent = s
	var base_pos := Vector2(b.pos.x + Box.SIZE / 2.0, b.pos.y + Box.SIZE)
	# poeira: mais, mais rápida e mais alta quanto mais forte
	for i in 4 + int(8.0 * s):
		var dir := -1.0 if i % 2 == 0 else 1.0
		particles.append({
			"pos": base_pos + Vector2(dir * randf_range(2.0, 7.0), -1.0),
			"vel": Vector2(dir * randf_range(0.4, 1.0) * (30.0 + 40.0 * minf(s, 1.5)), -randf_range(6.0, 14.0 + 14.0 * s)),
			"life": randi_range(9, 14 + int(4.0 * s)), "col": C_DUST, "grav": 25.0,
		})
	particles.append({"pos": base_pos, "vel": Vector2.ZERO, "life": 10 + int(3.0 * s), "col": C_BOX, "grav": 0.0, "ring": 3.0})
	if s > 1.0:
		# impacto forte: segundo anel e lascas da caixa saltando
		particles.append({"pos": base_pos, "vel": Vector2.ZERO, "life": 14, "col": C_DUST, "grav": 0.0, "ring": 1.0})
		for i in 2 + int((s - 1.0) * 5.0):
			particles.append({
				"pos": base_pos + Vector2(randf_range(-6.0, 6.0), -2.0),
				"vel": Vector2(randf_range(-45.0, 45.0), -randf_range(50.0, 90.0)),
				"life": randi_range(12, 22), "col": C_BOX, "grav": 380.0,
			})
		shake = maxf(shake, 0.8 * (s - 1.0))
	jolt_amp = maxf(jolt_amp, 0.6 + 2.4 * s)
	jolt_phase = 0.0
	impact.emit(s)


func _box_step(b) -> void:
	if _box_supported(b):
		if b.fall_dist >= IMPACT_MIN_DIST:
			_box_impact(b, b.fall_dist)
		b.fall_dist = 0
		b.vel_y = 0.0
		b.rem_y = 0.0
		b.settled = true
		return
	b.settled = false
	b.vel_y = minf(b.vel_y + BOX_GRAVITY * DT, BOX_MAX_FALL)
	b.rem_y += b.vel_y * DT
	var steps := int(b.rem_y)
	b.rem_y -= steps
	while steps > 0:
		var nxt := Rect2i(b.pos + Vector2i(0, 1), Vector2i(Box.SIZE, Box.SIZE))
		if _box_blocked(b, nxt):
			if _box_nudge(b):
				continue
			b.vel_y = 0.0
			b.rem_y = 0.0
			break
		if overlaps(nxt, rabbit.rect):
			var rn := Rect2i(rabbit.pos + Vector2i(0, 1), Vector2i(Rabbit.SIZE, Rabbit.SIZE))
			if solid_static(rn) or box_at(rn, b) != null:
				kill()
				return
			rabbit.pos.y += 1
		b.pos.y += 1
		b.fall_dist += 1
		steps -= 1


## Alinha a caixa com um buraco logo abaixo (até 4 px), para encaixar sem precisão de pixel.
func _box_nudge(b) -> bool:
	for k in range(1, 5):
		for sgn in [-1, 1]:
			var below := Rect2i(b.pos + Vector2i(sgn * k, 1), Vector2i(Box.SIZE, Box.SIZE))
			var side := Rect2i(b.pos + Vector2i(sgn, 0), Vector2i(Box.SIZE, Box.SIZE))
			if not _box_blocked(b, below) and not _box_blocked(b, side):
				b.pos.x += sgn
				return true
	return false


func _update_sockets() -> void:
	var old_n := socket_fx.size()
	socket_filled.resize(sockets.size())
	socket_fx.resize(sockets.size())
	for k in range(old_n, sockets.size()):
		socket_fx[k] = 0
		socket_filled[k] = false
	for i in sockets.size():
		var s: Rect2i = sockets[i]
		var f := false
		for b in boxes:
			if b.settled and absi(b.pos.x - s.position.x) <= 3 and absi(b.pos.y - s.position.y) <= 3:
				f = true
		var was: bool = socket_filled[i] == true
		if f != was and state == "play":
			socket_fx[i] = SENSOR_FRAMES
			sfx.emit("sensor_on" if f else "sensor_off")
		socket_filled[i] = f
	var open := group_filled(0)
	if open != door_open:
		door_open = open
		door_flash = 14


## Todos os compartimentos do grupo têm caixa? (grupo 0 = porta; sem compartimentos = não)
func group_filled(group: int) -> bool:
	var any := false
	for i in sockets.size():
		if socket_group[i] == group:
			any = true
			if not socket_filled[i]:
				return false
	return any


## Comportas e plataformas mudam de estado; nenhuma fica sólida em cima de alguém.
func _update_mechanisms(instant: bool) -> void:
	var gate_changed := ""
	for g in gates:
		var want_closed := not group_filled(g["id"])
		if want_closed != g["closed"]:
			var can := true
			if want_closed:
				for gr in g["rects"]:
					if _occupied(gr):
						can = false
						break
			if can:
				g["closed"] = want_closed
				g["fx"] = SWITCH_FRAMES
				gate_changed = "gate_close" if want_closed else "gate_open"
		var target := 0.0 if g["closed"] else 1.0
		g["anim"] = target if instant else move_toward(g["anim"], target, 0.12)
		g["fx"] = maxi(g["fx"] - 1, 0)
	var plat_changed := false
	for p in platforms:
		var want: bool = p["facing"] == 0
		if want != p["solid"]:
			if not want or not _occupied(p["rect"]):
				p["solid"] = want
				p["fx"] = SWITCH_FRAMES
				plat_changed = true
		p["fx"] = maxi(p["fx"] - 1, 0)
	if instant:
		for g in gates:
			g["fx"] = 0
		for p in platforms:
			p["fx"] = 0
		return
	if gate_changed != "":
		sfx.emit(gate_changed)
	if plat_changed:
		sfx.emit("platform")


func _spike_hurt(r: Rect2i, facing: int) -> Rect2i:
	var p := r.position
	match facing:
		0:
			return Rect2i(p.x + 1, p.y + 3, 6, 5)
		1:
			return Rect2i(p.x, p.y + 1, 5, 6)
		2:
			return Rect2i(p.x + 1, p.y, 6, 5)
	return Rect2i(p.x + 3, p.y + 1, 5, 6)


func _check_hazards() -> void:
	var rr: Rect2i = rabbit.rect
	for s in spikes:
		if overlaps(rr, _spike_hurt(s["rect"], s["facing"])):
			kill()
			return


func _check_win() -> void:
	if door_open and has_door and overlaps(rabbit.rect, door):
		state = "won"
		timer = WIN_FRAMES
		shake = 1.5
		sfx.emit("win")
		_door_ring()
		var c := Vector2(door.position) + Vector2(door.size) / 2.0
		for i in 26:
			var a := randf() * TAU
			var sp := randf_range(20.0, 90.0)
			particles.append({
				"pos": c, "vel": Vector2(cos(a), sin(a)) * sp - Vector2(0, 25),
				"life": randi_range(22, 40), "col": C_DOOR_OPEN, "grav": 60.0,
			})
		# faíscas subindo, como poeira de luz
		for i in 10:
			particles.append({
				"pos": c + Vector2(randf_range(-4.0, 4.0), randf_range(-8.0, 8.0)),
				"vel": Vector2(0, -randf_range(20.0, 55.0)),
				"life": randi_range(26, 44), "col": Color("fff4c2"), "grav": 0.0,
			})


func _door_ring() -> void:
	var c := Vector2(door.position) + Vector2(door.size) / 2.0
	particles.append({"pos": c, "vel": Vector2.ZERO, "life": 22, "col": C_DOOR_OPEN, "grav": 0.0, "ring": 4.0})


func _jump_ring() -> void:
	var feet := Vector2(rabbit.pos.x + 6, rabbit.pos.y + 12)
	particles.append({"pos": feet, "vel": Vector2.ZERO, "life": 10, "col": C_DUST, "grav": 0.0, "ring": 2.0})


func _push_dust() -> void:
	var feet := Vector2(rabbit.pos.x + 6 - rabbit.facing * 5, rabbit.pos.y + 11)
	particles.append({
		"pos": feet, "vel": Vector2(-rabbit.facing * randf_range(8.0, 20.0), -randf_range(4.0, 12.0)),
		"life": randi_range(8, 12), "col": C_DUST, "grav": 20.0,
	})


func kill() -> void:
	if state != "play":
		return
	state = "dead"
	timer = DEATH_FRAMES
	shake = 4.0
	sfx.emit("death")
	var c := Vector2(rabbit.pos) + Vector2(6, 6)
	particles.append({"pos": c, "vel": Vector2.ZERO, "life": 14, "col": Color("efeadf"), "grav": 0.0, "ring": 3.0})
	for i in 14:
		var a := randf() * TAU
		var sp := randf_range(30.0, 110.0)
		particles.append({
			"pos": c, "vel": Vector2(cos(a), sin(a)) * sp - Vector2(0, 30),
			"life": randi_range(14, 26), "col": Color("efeadf"), "grav": 300.0,
		})


func _dust(n: int, speed: float) -> void:
	var feet := Vector2(rabbit.pos.x + 6, rabbit.pos.y + 11)
	for i in n:
		var dir := -1.0 if i % 2 == 0 else 1.0
		particles.append({
			"pos": feet + Vector2(dir * randf_range(1.0, 4.0), 0),
			"vel": Vector2(dir * randf_range(0.3, 1.0) * speed, -randf_range(4.0, 16.0)),
			"life": randi_range(8, 14), "col": C_DUST, "grav": 20.0,
		})


func _update_particles() -> void:
	shake = maxf(shake - 0.35, 0.0)
	jolt_phase += 1.15
	jolt_amp *= 0.84  # forças maiores duram um pouco mais
	impact_recent *= 0.9
	if jolt_amp < 0.05:
		jolt_amp = 0.0
	for i in socket_fx.size():
		socket_fx[i] = maxi(socket_fx[i] - 1, 0)
	for p in particles:
		p["pos"] += p["vel"] * DT
		p["vel"].y += p["grav"] * DT
		p["vel"].x *= 0.92
		p["life"] -= 1
		if p.has("ring"):
			p["ring"] += 1.1
	particles = particles.filter(func(p): return p["life"] > 0)


# ---------------------------------------------------------------- desenho

func _rabbit_tex(ears: String, feet: String, blink: bool) -> ImageTexture:
	var key := "%s|%s|%s" % [ears, feet, blink]
	if rabbit_frames.has(key):
		return rabbit_frames[key]
	var rows: Array = []
	rows.append_array(EARS[ears])
	rows.append_array(BODY)
	rows.append(FEET[feet])
	var palette := {
		"w": Color("efeadf"),
		"g": Color("b7b2a6"),
		"p": Color("e8a0b0"),
		"r": Color("b7b2a6") if blink else Color("e0334a"),
	}
	var img := Image.create_empty(12, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 16:
		var line: String = rows[y]
		for x in 12:
			var ch := line[x]
			if palette.has(ch):
				img.set_pixel(x, y, palette[ch])
	var tex := ImageTexture.create_from_image(img)
	rabbit_frames[key] = tex
	return tex


## Escolhe o quadro do coelho: [textura, deslocamento vertical].
func _rabbit_frame() -> Array:
	if not rabbit.on_ground:
		if rabbit.vel.y < -15.0:
			return [_rabbit_tex("back", "air", false), 0]
		return [_rabbit_tex("fall", "air", false), 0]
	if rabbit.push_t > 0:
		# empurrando: orelhas para trás, pernas abertas, passos curtos e lentos
		if int(rabbit.anim / 5.0) % 2 == 0:
			return [_rabbit_tex("back", "push_a", false), 0]
		return [_rabbit_tex("back", "push_b", false), 0]
	if rabbit.run_t > 0:
		if int(rabbit.anim / 6.0) % 2 == 0:
			return [_rabbit_tex("back", "run_a", false), -1]
		return [_rabbit_tex("up", "run_b", false), 0]
	var t := frame % 260
	var blink := t >= 120 and t < 127
	var ears := "twitch" if (t >= 200 and t < 214) else "up"
	return [_rabbit_tex(ears, "stand", blink), 0]


## Triângulo apontando para `facing` dentro de um tile (0 cima, 1 direita, 2 baixo, 3 esquerda).
func _spike_points(r: Rect2i, facing: int) -> PackedVector2Array:
	return _tri_points(r, facing, [Vector2(1, 8), Vector2(4, 3), Vector2(7, 8)])


func _tri_points(r: Rect2i, facing: int, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		var q: Vector2 = p
		for i in facing:
			q = Vector2(8.0 - q.y, q.x)  # 90° horário em volta do centro do tile
		out.append(Vector2(r.position) + q)
	return out


func _draw() -> void:
	var jitter := Vector2.ZERO
	if shake > 0.0:
		jitter = Vector2(roundf(randf_range(-shake, shake)), roundf(randf_range(-shake, shake)))
	# solavanco no sentido da gravidade (para baixo na tela): a sala "afunda" e volta
	var jolt := Vector2(0.0, roundf(jolt_amp * sin(jolt_phase)))
	var base := Transform2D(0.0, jolt) * Transform2D(view_angle, Vector2.ZERO) * Transform2D(0.0, -cam.round() + jitter)
	draw_set_transform_matrix(base)
	var room_rect := Rect2(0, 0, pw, ph)

	draw_rect(room_rect, C_BG)

	# compartimentos (fundo)
	for s in sockets:
		draw_rect(Rect2(s), C_SOCKET)

	# porta e seus brilhos: desenhados ANTES das paredes, para a parede e a linha branca
	# da borda sempre ficarem por cima e nada da porta vazar para dentro delas
	if has_door:
		_draw_door()
		_draw_door_beam()

	_draw_walls()
	_draw_gates()
	_draw_platforms()

	# espinhos
	for s in spikes:
		draw_colored_polygon(_spike_points(s["rect"], s["facing"]), C_SPIKE)

	# caixas
	for b in boxes:
		var p := Vector2(b.pos)
		draw_rect(Rect2(p, Vector2(16, 16)), C_BOX_DARK)
		draw_rect(Rect2(p + Vector2(1, 1), Vector2(14, 14)), C_BOX)
		draw_rect(Rect2(p + Vector2(5, 5), Vector2(6, 6)), C_BOX_MID)

	# moldura dos compartimentos (por cima da caixa: ela parece encaixada)
	for i in sockets.size():
		var s: Rect2i = sockets[i]
		var filled: bool = i < socket_filled.size() and socket_filled[i]
		var col := _socket_color(i, filled)
		var o := Vector2(s.position)
		draw_rect(Rect2(o, Vector2(16, 2)), col)
		draw_rect(Rect2(o + Vector2(0, 14), Vector2(16, 2)), col)
		draw_rect(Rect2(o + Vector2(0, 2), Vector2(2, 12)), col)
		draw_rect(Rect2(o + Vector2(14, 2), Vector2(2, 12)), col)
		_draw_sensor_fx(s, i)

	# coelho
	if rabbit != null and (state == "play" or state == "won"):
		_draw_rabbit(base)

	# partículas
	for p in particles:
		var a := clampf(float(p["life"]) / 14.0, 0.0, 1.0)
		var col: Color = p["col"]
		if p.has("ring"):
			draw_arc(p["pos"], p["ring"], 0.0, TAU, 20, Color(col, a * 0.8), 1.0)
		else:
			draw_rect(Rect2(p["pos"] - Vector2(1, 1), Vector2(2, 2)), Color(col, a))

	# entrada no portal: véu dourado que cresce sobre a sala inteira
	if (state == "won" or state == "done") and has_door:
		var t := 1.0 - float(timer) / float(WIN_FRAMES)
		draw_rect(room_rect, Color(1.0, 0.9, 0.45, 0.35 * smoothstep(0.55, 1.0, t)))

	# clarão da morte
	if state == "dead":
		var f := float(timer) / float(DEATH_FRAMES)
		draw_rect(room_rect, Color(1, 1, 1, 0.35 * f * f))


## Compartimentos da porta: cinza/amarelo. Compartimentos de comporta: na cor da comporta.
func _socket_color(i: int, filled: bool) -> Color:
	if socket_group[i] == 0:
		return C_SOCKET_ON if filled else C_SOCKET_FRAME
	return C_GATE if filled else Color(C_GATE, 0.45)


func _draw_walls() -> void:
	# fora da animação de giro, só desenha o que está na tela (salas grandes)
	var c0 := 0
	var c1 := gw - 1
	var r0 := 0
	var r1 := gh - 1
	if not rotating:
		var half := VIEW / 2.0 + Vector2(24, 24)
		c0 = maxi(int((cam.x - half.x) / TILE), 0)
		c1 = mini(int((cam.x + half.x) / TILE), gw - 1)
		r0 = maxi(int((cam.y - half.y) / TILE), 0)
		r1 = mini(int((cam.y + half.y) / TILE), gh - 1)
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			if tiles[r * gw + c] == 0:
				continue
			var x := c * TILE
			var y := r * TILE
			draw_rect(Rect2(x, y, TILE, TILE), C_WALL)
			if r > 0 and tiles[(r - 1) * gw + c] == 0:
				draw_rect(Rect2(x, y, TILE, 1), C_EDGE)
			if r < gh - 1 and tiles[(r + 1) * gw + c] == 0:
				draw_rect(Rect2(x, y + TILE - 1, TILE, 1), C_EDGE)
			if c > 0 and tiles[r * gw + c - 1] == 0:
				draw_rect(Rect2(x, y, 1, TILE), C_EDGE)
			if c < gw - 1 and tiles[r * gw + c + 1] == 0:
				draw_rect(Rect2(x + TILE - 1, y, 1, TILE), C_EDGE)


## Comporta: bloco escuro com barras. Ao abrir, as barras encolhem para o centro e somem.
func _draw_gates() -> void:
	for g in gates:
		var k: float = g["anim"]  # 0 fechada, 1 aberta
		var fx := float(g["fx"]) / float(SWITCH_FRAMES)
		if k >= 1.0 and fx <= 0.0:
			continue
		for gr in g["rects"]:
			var r := Rect2(gr)
			if k < 1.0:
				var inner := r.grow(-3.5 * k)
				draw_rect(inner, Color(C_GATE_DARK, 1.0 - k))
				draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y * 0.25, inner.size.x, 1), Color(C_GATE, 1.0 - k))
				draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y * 0.7, inner.size.x, 1), Color(C_GATE, 1.0 - k))
				draw_rect(Rect2(inner.position.x + inner.size.x * 0.25, inner.position.y, 1, inner.size.y), Color(C_GATE, 0.6 * (1.0 - k)))
				draw_rect(Rect2(inner.position.x + inner.size.x * 0.7, inner.position.y, 1, inner.size.y), Color(C_GATE, 0.6 * (1.0 - k)))
			if fx > 0.0:
				draw_rect(r.grow(1.0 + 2.0 * (1.0 - fx)), Color(C_GATE, 0.5 * fx), false, 1.0)


## Plataforma por orientação: sólida (preenchida) só com a seta para cima; fora disso, contorno
## tracejado com a seta mostrando para onde ela precisa apontar.
func _draw_platforms() -> void:
	for p in platforms:
		var r := Rect2(p["rect"])
		var fx := float(p["fx"]) / float(SWITCH_FRAMES)
		if p["solid"]:
			draw_rect(r, C_PLAT_DARK)
			draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), C_PLAT)
			draw_colored_polygon(_tri_points(p["rect"], p["facing"], [Vector2(2.5, 6.5), Vector2(4, 4), Vector2(5.5, 6.5)]), Color(C_PLAT, 0.8))
		else:
			var col := Color(C_PLAT, 0.4)
			for i in 4:
				var a := Vector2(i * 2, 0)
				draw_rect(Rect2(r.position + a, Vector2(1, 1)), col)
				draw_rect(Rect2(r.position + Vector2(i * 2 + 1, 7), Vector2(1, 1)), col)
				draw_rect(Rect2(r.position + Vector2(0, i * 2 + 1), Vector2(1, 1)), col)
				draw_rect(Rect2(r.position + Vector2(7, i * 2), Vector2(1, 1)), col)
			draw_colored_polygon(_tri_points(p["rect"], p["facing"], [Vector2(1.5, 6.5), Vector2(4, 2), Vector2(6.5, 6.5)]), Color(C_PLAT, 0.6))
		if fx > 0.0:
			draw_rect(r.grow(1.0 + 2.0 * (1.0 - fx)), Color(C_PLAT, 0.6 * fx), false, 1.0)


func _draw_rabbit(base: Transform2D) -> void:
	var fr := _rabbit_frame()
	var pivot := Vector2(rabbit.pos.x + 6, rabbit.pos.y + 12)
	var sc := Vector2(rabbit.squash.x * rabbit.facing, rabbit.squash.y)
	if rabbit.push_t > 0:
		# inclina o corpo para a frente, fazendo força
		pivot.x += rabbit.facing
		sc *= Vector2(1.06, 0.94)
	var alpha := 1.0
	if state == "won":
		# o coelho é puxado para dentro da porta, encolhendo
		var t := 1.0 - float(timer) / float(WIN_FRAMES)
		var k := smoothstep(0.0, 0.5, t)
		var target := Vector2(door.position) + Vector2(door.size) / 2.0 + Vector2(0, 6)
		pivot = pivot.lerp(target, k)
		sc *= 1.0 - 0.85 * k
		alpha = 1.0 - smoothstep(0.35, 0.55, t)
		fr = [_rabbit_tex("back", "air", false), 0]
	if alpha <= 0.0:
		return
	draw_set_transform_matrix(base * Transform2D(-view_angle, sc, 0.0, pivot))
	draw_texture(fr[0], Vector2(-6, -16 + fr[1]), Color(1, 1, 1, alpha))
	draw_set_transform_matrix(base)


## Feixe de luz subindo da porta ao vencer. Fica atrás das paredes, então é cortado por elas.
func _draw_door_beam() -> void:
	if state != "won" and state != "done":
		return
	var t := 1.0 - float(timer) / float(WIN_FRAMES)
	var beam := sin(clampf(t / 0.8, 0.0, 1.0) * PI)
	var c := Vector2(door.position.x + door.size.x / 2.0, door.position.y)
	draw_rect(Rect2(c.x - 3.0 - 3.0 * beam, 0.0, 6.0 + 6.0 * beam, c.y), Color(1.0, 0.93, 0.55, 0.22 * beam))
	draw_rect(Rect2(c.x - 1.0, 0.0, 2.0, c.y), Color(1.0, 0.98, 0.8, 0.5 * beam))


## Sensor ativando: uma linha de varredura cruza o compartimento e um contorno fino se expande.
func _draw_sensor_fx(s: Rect2i, i: int) -> void:
	if i >= socket_fx.size() or socket_fx[i] <= 0:
		return
	var t := 1.0 - float(socket_fx[i]) / float(SENSOR_FRAMES)  # 0 -> 1
	var on: bool = socket_filled[i] == true
	var col := _socket_color(i, on)
	var r := Rect2(s)
	# contorno que se expande e some
	draw_rect(r.grow(1.0 + 4.0 * t), Color(col, 0.7 * (1.0 - t)), false, 1.0)
	# linha de varredura (desce ao ativar, sobe ao desativar)
	var yy := r.position.y + 2.0 + (r.size.y - 5.0) * (t if on else 1.0 - t)
	draw_rect(Rect2(r.position.x + 2.0, floorf(yy), r.size.x - 4.0, 1.0), Color(1.0, 0.97, 0.8, 0.9 * (1.0 - t)))


func _draw_door() -> void:
	var r := Rect2(door)
	if not door_open:
		# Fechada: translúcida e vazada, para não parecer um bloco sólido (dá para atravessar).
		draw_rect(r, Color(C_DOOR_LOCKED, 0.35))
		draw_rect(r, C_DOOR_LOCKED, false, 1.0)
		draw_rect(r.grow(-3.0), Color(C_DOOR_LOCKED_DARK, 0.5))
		var c := r.position + r.size / 2.0
		draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), Color(C_DOOR_LOCKED, 0.8))
		return

	# Porta aberta: um vão escuro com moldura amarela e luz pulsando por dentro.
	var ph_ := sin(frame * 0.1) * 0.5 + 0.5
	var pulse := float(door_flash) / 14.0
	var win_t := 0.0
	if state == "won" or state == "done":
		win_t = 1.0 - float(timer) / float(WIN_FRAMES)
	# ao vencer: clarão, depois a porta se fecha em uma linha
	var close := smoothstep(0.6, 1.0, win_t)
	var center := r.position + r.size / 2.0
	var sz := r.size
	if sz.x <= sz.y:
		sz.x *= 1.0 - close
	else:
		sz.y *= 1.0 - close
	r = Rect2(center - sz / 2.0, sz)
	if r.size.x < 1.0 or r.size.y < 1.0:
		return

	draw_rect(r.grow(3.0 + 3.0 * pulse), Color(C_DOOR_OPEN, 0.07 + 0.06 * ph_ + 0.2 * pulse))
	draw_rect(r.grow(1.0), Color(C_DOOR_OPEN, 0.22))
	draw_rect(r, C_DOOR_OPEN)
	if r.size.x > 4.0 and r.size.y > 4.0:
		var inner := r.grow(-2.0)
		draw_rect(inner, C_DOOR_INNER)
		draw_rect(inner.grow(-1.0), Color(C_DOOR_OPEN, 0.18 + 0.16 * ph_))
		# faíscas subindo dentro do vão
		for i in 4:
			var px := inner.position.x + 1.0 + fmod(i * 5.3 + 2.0, maxf(inner.size.x - 2.0, 1.0))
			var py := inner.end.y - 1.0 - fmod(frame * (0.25 + 0.07 * i) + i * 9.0, maxf(inner.size.y - 1.0, 1.0))
			draw_rect(Rect2(floorf(px), floorf(py), 1, 1), Color(1.0, 0.95, 0.7, 0.9))
	# clarão quando o coelho entra
	if win_t > 0.0:
		var f := sin(clampf(win_t / 0.7, 0.0, 1.0) * PI)
		draw_rect(r.grow(5.0 * f), Color(1.0, 0.96, 0.75, 0.55 * f))

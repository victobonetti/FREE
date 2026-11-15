extends Node2D
## Uma sala: grade de tiles, coelho, caixas, compartimentos, porta e espinhos.
##
## Rotação: a simulação sempre acontece com a gravidade para baixo. Ao girar, todos os
## dados da sala (tiles, caixas, coelho...) são rotacionados 90° de verdade, e só o desenho
## faz a animação (de -90° até 0°). Assim a física nunca precisa saber de orientação.

signal completed
signal sfx(name: String)  # "jump" | "death" | "win" | "sensor_on" | "sensor_off"; o som é tocado por main.gd
signal impact(strength: float)  # pouso de caixa; 0 a 2,5 (mais altura e mais caixas = mais forte)

const TILE := 8
const GRID := 20
const SIZE := TILE * GRID
const HALF := Vector2(SIZE / 2.0, SIZE / 2.0)
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
const WIN_FRAMES := 44
const DEATH_FRAMES := 20

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

var tiles := PackedByteArray()
var boxes: Array = []
var sockets: Array = []
var socket_filled: Array = []
var door := Rect2i()
var has_door := false
var door_open := false
var door_flash := 0
var spikes: Array = []
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

var particles: Array = []
var rabbit_frames := {}
var shake := 0.0  # tremor de tela (px), decai sozinho
var jolt_amp := 0.0    # solavanco na direção da gravidade (px): oscila e amortece
var jolt_phase := 0.0
var impact_recent := 0.0  # força dos pousos dos últimos quadros; decai e soma com o próximo
var socket_fx: Array = []  # quadros restantes do efeito de sensor, por compartimento


func _process(_delta: float) -> void:
	queue_redraw()


func setup(room_def: Dictionary) -> void:
	def = room_def
	allow_rotate = room_def.get("rotate", true)
	reset()


func reset() -> void:
	tiles = PackedByteArray()
	tiles.resize(GRID * GRID)
	boxes.clear()
	sockets.clear()
	socket_filled.clear()
	socket_fx.clear()
	jolt_amp = 0.0
	impact_recent = 0.0
	spikes.clear()
	particles.clear()
	door = Rect2i()
	has_door = false
	door_open = false
	door_flash = 0
	rotating = false
	rot_frame = 0
	view_angle = 0.0
	pending_rot = 0
	rot_lock = 0
	state = "play"
	timer = 0
	rabbit = Rabbit.new()
	_parse(def["rows"])
	var sr: int = def.get("start_rot", 0)
	for i in absi(sr):
		_rotate_logic(1 if sr > 0 else -1)
	_update_sockets()


## 0.0 logo após girar, 1.0 quando o giro está disponível de novo.
func rot_ratio() -> float:
	return 1.0 - float(rot_lock) / float(ROT_FRAMES + ROT_COOLDOWN)


# ---------------------------------------------------------------- parsing

func _parse(rows: Array) -> void:
	var visited := {}
	var door_cells: Array = []
	for r in GRID:
		var line: String = rows[r]
		for c in GRID:
			var ch := line[c]
			var key := Vector2i(c, r)
			if ch == "#":
				tiles[r * GRID + c] = 1
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
			elif (ch == "P" or ch == "B" or ch == "S") and not visited.has(key):
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
	if not door_cells.is_empty():
		var lo: Vector2i = door_cells[0]
		var hi: Vector2i = door_cells[0]
		for k in door_cells:
			lo = Vector2i(mini(lo.x, k.x), mini(lo.y, k.y))
			hi = Vector2i(maxi(hi.x, k.x), maxi(hi.y, k.y))
		door = Rect2i(lo * TILE, (hi - lo + Vector2i.ONE) * TILE)
		has_door = true


func _add_spike(c: int, r: int, facing: int) -> void:
	spikes.append({"rect": Rect2i(c * TILE, r * TILE, TILE, TILE), "facing": facing})


# ---------------------------------------------------------------- rotação

func _rot_rect(r: Rect2i, dir: int) -> Rect2i:
	if dir > 0:  # horário: (x, y) -> (SIZE - y, x)
		return Rect2i(SIZE - (r.position.y + r.size.y), r.position.x, r.size.y, r.size.x)
	# anti-horário: (x, y) -> (y, SIZE - x)
	return Rect2i(r.position.y, SIZE - (r.position.x + r.size.x), r.size.y, r.size.x)


func _rotate_logic(dir: int) -> void:
	var nt := PackedByteArray()
	nt.resize(GRID * GRID)
	for r in GRID:
		for c in GRID:
			if tiles[r * GRID + c] != 0:
				var nc: int
				var nr: int
				if dir > 0:
					nc = GRID - 1 - r
					nr = c
				else:
					nc = r
					nr = GRID - 1 - c
				nt[nr * GRID + nc] = 1
	tiles = nt
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
	rabbit.pos = _rot_rect(rabbit.rect, dir).position
	rabbit.on_rotate()


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
	if x0 < 0 or y0 < 0 or x1 >= SIZE or y1 >= SIZE:
		return true
	for ty in range(y0 >> 3, (y1 >> 3) + 1):
		for tx in range(x0 >> 3, (x1 >> 3) + 1):
			if tiles[ty * GRID + tx] != 0:
				return true
	return false


## Só as paredes são sólidas. A porta (aberta ou fechada) nunca bloqueia ninguém.
func solid_static(r: Rect2i) -> bool:
	return tile_solid_rect(r)


func box_at(r: Rect2i, ignore):
	for b in boxes:
		if b != ignore and overlaps(r, b.rect):
			return b
	return null


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
	var all := not sockets.is_empty()
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
		all = all and f
	if all != door_open:
		door_open = all
		door_flash = 14


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


func _spike_points(r: Rect2i, facing: int) -> PackedVector2Array:
	var pts := [Vector2(1, 8), Vector2(4, 3), Vector2(7, 8)]
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
	var base := Transform2D(0.0, jolt) * Transform2D(view_angle, Vector2.ZERO) * Transform2D(0.0, -HALF + jitter)
	draw_set_transform_matrix(base)

	draw_rect(Rect2(0, 0, SIZE, SIZE), C_BG)

	# compartimentos (fundo)
	for s in sockets:
		draw_rect(Rect2(s), C_SOCKET)

	# porta e seus brilhos: desenhados ANTES das paredes, para a parede e a linha branca
	# da borda sempre ficarem por cima e nada da porta vazar para dentro delas
	if has_door:
		_draw_door()
		_draw_door_beam()

	# paredes
	for r in GRID:
		for c in GRID:
			if tiles[r * GRID + c] == 0:
				continue
			var x := c * TILE
			var y := r * TILE
			draw_rect(Rect2(x, y, TILE, TILE), C_WALL)
			if r > 0 and tiles[(r - 1) * GRID + c] == 0:
				draw_rect(Rect2(x, y, TILE, 1), C_EDGE)
			if r < GRID - 1 and tiles[(r + 1) * GRID + c] == 0:
				draw_rect(Rect2(x, y + TILE - 1, TILE, 1), C_EDGE)
			if c > 0 and tiles[r * GRID + c - 1] == 0:
				draw_rect(Rect2(x, y, 1, TILE), C_EDGE)
			if c < GRID - 1 and tiles[r * GRID + c + 1] == 0:
				draw_rect(Rect2(x + TILE - 1, y, 1, TILE), C_EDGE)

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
		var col := C_SOCKET_ON if filled else C_SOCKET_FRAME
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
		draw_rect(Rect2(0, 0, SIZE, SIZE), Color(1.0, 0.9, 0.45, 0.35 * smoothstep(0.55, 1.0, t)))

	# clarão da morte
	if state == "dead":
		var f := float(timer) / float(DEATH_FRAMES)
		draw_rect(Rect2(0, 0, SIZE, SIZE), Color(1, 1, 1, 0.35 * f * f))


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
	var col := C_SOCKET_ON if on else C_SOCKET_FRAME
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
	var ph := sin(frame * 0.1) * 0.5 + 0.5
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

	draw_rect(r.grow(3.0 + 3.0 * pulse), Color(C_DOOR_OPEN, 0.07 + 0.06 * ph + 0.2 * pulse))
	draw_rect(r.grow(1.0), Color(C_DOOR_OPEN, 0.22))
	draw_rect(r, C_DOOR_OPEN)
	if r.size.x > 4.0 and r.size.y > 4.0:
		var inner := r.grow(-2.0)
		draw_rect(inner, C_DOOR_INNER)
		draw_rect(inner.grow(-1.0), Color(C_DOOR_OPEN, 0.18 + 0.16 * ph))
		# faíscas subindo dentro do vão
		for i in 4:
			var px := inner.position.x + 1.0 + fmod(i * 5.3 + 2.0, maxf(inner.size.x - 2.0, 1.0))
			var py := inner.end.y - 1.0 - fmod(frame * (0.25 + 0.07 * i) + i * 9.0, maxf(inner.size.y - 1.0, 1.0))
			draw_rect(Rect2(floorf(px), floorf(py), 1, 1), Color(1.0, 0.95, 0.7, 0.9))
	# clarão quando o coelho entra
	if win_t > 0.0:
		var f := sin(clampf(win_t / 0.7, 0.0, 1.0) * PI)
		draw_rect(r.grow(5.0 * f), Color(1.0, 0.96, 0.75, 0.55 * f))

extends Node2D
## Uma sala: grade de tiles, coelho, caixas, compartimentos, porta, espinhos, comportas,
## plataformas por orientação, cordas, água e ralos. A sala pode ter qualquer tamanho; a câmera segue o coelho.
##
## Rotação: a simulação sempre acontece com a gravidade para baixo. Ao girar, todos os
## dados da sala (tiles, caixas, coelho, câmera...) são rotacionados 90° de verdade, e só o
## desenho faz a animação (de -90° até 0°). Assim a física nunca precisa saber de orientação.

signal completed
## "jump" | "death" | "win" | "sensor_on" | "sensor_off" | "gate_open" | "gate_close" | "platform"
## | "rope" (agarrou a corda) | "splash" (caiu na água)
signal sfx(name: String)
signal impact(strength: float)  # pouso de caixa; 0 a 2,5 (mais altura e mais caixas = mais forte)

const TILE := 8
const VIEW := Vector2(320, 180)  # tamanho da tela (resolução interna)
const CAM_SMOOTH := 0.12
const ROT_FRAMES := 16       # duração da animação do giro
const ROT_COOLDOWN := 134    # espera extra depois do giro: com a animação, 2,5 s (150 quadros)
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
const WATER_REACH := [1, 2, 4, 8, 16, 32, 64, 128]  # distâncias (px) em que duas colunas trocam água
const WATER_NU := 0.5          # parcela do desnível que colunas vizinhas igualam por subpasso
const WATER_NU_FAR := 0.3      # idem para as trocas a distância: dá a velocidade com que a água corre
const WATER_SUBSTEPS := 3
const RIPPLE_TENSION := 0.03   # ondas da superfície: mola que puxa de volta ao nível
const RIPPLE_SPREAD := 0.22    # quanto uma coluna puxa as vizinhas
const RIPPLE_DAMP := 0.955
const RIPPLE_MAX := 5.0        # amplitude máxima (px)
const WATER_FALL_G := 900.0    # queda de um bloco de água solto no ar depois do giro
const WATER_MAX_FALL := 260.0
const WATER_CALM_Q := 0.004    # troca (px por subpasso) abaixo da qual a água conta como parada
const WATER_CALM_FRAMES := 20
const WATER_FILM := 0.4        # lâmina mais fina que isto (px) seca sozinha quando a água está quase parada
const WATER_SETTLE := 1500     # máximo de quadros para assentar a água ao carregar a sala
const DRAIN_RATE := 1.0        # px de altura por quadro que o ralo engole em cada coluna dele
const ROPE_SEG := 4.0          # distância entre os pontos da corda (px)
const ROPE_ITERS := 10         # iterações das restrições de distância por quadro
const ROPE_AIR := 0.985        # perda de velocidade dos pontos por quadro
const DOOR_FLOOD := 0.3        # fração da porta coberta de água que a bloqueia
const DOOR_DRY_FRAMES := 30    # a porta só destrava depois de ficar seca por este tempo
const BOX_WET := 0.25          # fração submersa a partir da qual a caixa afunda devagar
const BOX_WATER_GRAVITY := 300.0
const BOX_WATER_FALL := 45.0

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
const C_ROPE := Color("e39a4c")
const C_WATER := Color("2f86e0")
const C_WATER_TOP := Color("9fd4ff")
const C_DRAIN := Color("8d8d99")

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
# cordas: {"anchor": Vector2, "facing", "len", "pts", "old"}. facing 2 = presa no teto (ativa).
# pts/old são os pontos da corda (Verlet): a forma dela é simulada, cai e balança de verdade.
var ropes: Array = []
var drains: Array = []     # {"rect": Rect2i, "t", "spin"}
# Água: modelo de colunas. Cada coluna de 1 px tem "vãos" (trechos verticais livres entre
# sólidos); cada vão guarda uma altura de água (fracionária) apoiada no fundo dele. Vãos
# ligados trocam água até igualar o nível; por cima disso, a superfície tem ondas.
var wt_x := PackedInt32Array()      # coluna do vão
var wt_top := PackedInt32Array()    # primeira linha livre
var wt_bot := PackedInt32Array()    # primeira linha sólida abaixo
var wt_h := PackedFloat64Array()    # altura de água
var wt_air := PackedFloat64Array()  # distância do fundo (> 0: bloco de água ainda caindo)
var wt_vy := PackedFloat64Array()
var wt_o := PackedFloat64Array()    # onda: deslocamento da superfície (px, + para baixo)
var wt_v := PackedFloat64Array()    # onda: velocidade
var wcol := PackedInt32Array()      # índice do primeiro vão de cada coluna (pw + 1 entradas)
# ligações: o vão a troca água com o vão b, à direita. As primeiras we_near são entre colunas
# vizinhas; as demais, a distância (só existem se há passagem livre entre as duas).
var we_a := PackedInt32Array()
var we_b := PackedInt32Array()
var we_sill := PackedInt32Array()   # soleira: o fundo mais alto no caminho
var we_nu := PackedFloat64Array()
var we_fall := PackedFloat64Array() # cascata visível nesta ligação (só desenho)
var we_near := 0
var ripples := false       # há ondas na superfície
var water_vol := 0.0       # volume total (px²)
var water_calm := false    # parada: a simulação descansa
var water_dirty := true    # os vãos precisam ser refeitos (comporta ou plataforma mudou)
var water_still := 0       # quadros seguidos quase sem vazão
var door_flooded := false   # bloqueada pela água (inclui o tempo de secar)
var door_dry := 0           # quadros seguidos com menos de DOOR_FLOOD de água na porta
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
# Limitador (campo "limiter" da sala): o giro é desfeito sozinho quando a recarga termina.
var limit_net := 0   # giros acumulados desde o estado inicial da sala
var limit_t := 0     # quadros até o giro ser desfeito (0 = nada a desfazer)
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
	water_vol = 0.0
	water_calm = false
	water_dirty = false
	water_still = 0
	door_flooded = false
	door_dry = DOOR_DRY_FRAMES
	ropes.clear()
	drains.clear()
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
	limit_net = 0
	limit_t = 0
	orientation = 0
	state = "play"
	timer = 0
	rabbit = Rabbit.new()
	var water_tiles: Array = []
	_parse(rows, water_tiles)
	_water_build()
	for t in water_tiles:
		for dx in TILE:
			var k := _tank_at(t.x * TILE + dx, t.y * TILE)
			if k >= 0:
				wt_h[k] += TILE
				water_vol += TILE
	var sr: int = def.get("start_rot", 0)
	for i in absi(sr):
		_rotate_logic(1 if sr > 0 else -1)
	_update_sockets()
	_update_mechanisms(true)
	_settle_water()
	for i in 300:
		_update_ropes()
	_update_sockets()
	cam = _cam_target()


## 0.0 logo após girar, 1.0 quando o giro está disponível de novo.
func rot_ratio() -> float:
	return 1.0 - float(rot_lock) / float(ROT_FRAMES + ROT_COOLDOWN)


# ---------------------------------------------------------------- parsing

func _parse(rows: Array, water_tiles: Array) -> void:
	var visited := {}
	var door_cells: Array = []
	var gate_cells := {}  # id -> Array[Rect2i]
	var rope_cells := {}  # Vector2i -> "|" ou "-"
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
			elif ch == "~":
				water_tiles.append(key)
			elif ch == "o":
				drains.append({"rect": cell, "t": 0, "spin": 0.0})
			elif ch == "|" or ch == "-":
				rope_cells[key] = ch
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
	_parse_ropes(rows, rope_cells)
	var ids := gate_cells.keys()
	ids.sort()
	for gid in ids:
		gates.append({"id": gid, "rects": gate_cells[gid], "closed": true, "anim": 0.0, "fx": 0})


## Cada sequência reta de "|" ou "-" é uma corda esticada. A ponta encostada numa parede é a
## âncora; o comprimento é o da sequência.
func _parse_ropes(rows: Array, cells: Dictionary) -> void:
	var keys := cells.keys()
	keys.sort_custom(func(a, b): return a.y < b.y if a.y != b.y else a.x < b.x)
	var seen := {}
	for k in keys:
		if seen.has(k):
			continue
		var vertical: bool = cells[k] == "|"
		var st: Vector2i = Vector2i(0, 1) if vertical else Vector2i(1, 0)
		var last: Vector2i = k
		while cells.get(last + st, "") == cells[k]:
			last += st
		var n: int = (last.y - k.y if vertical else last.x - k.x) + 1
		for i in n:
			seen[k + st * i] = true
		var start_wall := _char_at(rows, k - st) == "#"
		var end_wall := _char_at(rows, last + st) == "#"
		var rope := {"len": n * TILE, "anchor": Vector2.ZERO, "facing": 2}
		if vertical:
			if start_wall or not end_wall:
				rope["anchor"] = Vector2(k.x * TILE + 4, k.y * TILE)
				rope["facing"] = 2
			else:
				rope["anchor"] = Vector2(k.x * TILE + 4, (last.y + 1) * TILE)
				rope["facing"] = 0
		else:
			if start_wall or not end_wall:
				rope["anchor"] = Vector2(k.x * TILE, k.y * TILE + 4)
				rope["facing"] = 1
			else:
				rope["anchor"] = Vector2((last.x + 1) * TILE, k.y * TILE + 4)
				rope["facing"] = 3
		_rope_init(rope)
		ropes.append(rope)


func _char_at(rows: Array, k: Vector2i) -> String:
	if k.y < 0 or k.y >= rows.size():
		return "#"
	var line: String = rows[k.y]
	return line[k.x] if k.x >= 0 and k.x < line.length() else "#"


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
	for rp in ropes:
		rp["anchor"] = _rot_point(rp["anchor"], dir)
		rp["facing"] = posmod(rp["facing"] + dir, 4)
		# a corda gira na forma em que estava e, daí, cai com a nova gravidade
		var pts: PackedVector2Array = rp["pts"]
		var old: PackedVector2Array = rp["old"]
		for i in pts.size():
			pts[i] = _rot_point(pts[i], dir)
			old[i] = _rot_point(old[i], dir)
		rp["pts"] = pts
		rp["old"] = old
	for d in drains:
		d["rect"] = _rot_rect(d["rect"], dir)
	var slivers := _water_slivers(dir)
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
	_water_build()
	_water_deposit(slivers)


## Fração (0 a 1) do tempo que falta para o limitador desfazer o giro.
func limiter_ratio() -> float:
	return float(limit_t) / float(ROT_FRAMES + ROT_COOLDOWN)


func _begin_rotate(dir: int, forced := false) -> void:
	if not forced and not rabbit.free_rotate():
		rabbit.air_rot = false
	if def.get("limiter", false):
		limit_net += dir
		limit_t = ROT_FRAMES + ROT_COOLDOWN if limit_net != 0 else 0
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
	if limit_t > 0:
		limit_t -= 1
		if limit_t == 0 and not rotating:
			pending_rot = 0
			_begin_rotate(-signi(limit_net), true)
			sfx.emit("limiter")
			return
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
		if allow_rotate and rabbit.can_rotate():
			_begin_rotate(dir)
			return

	_update_mechanisms(false)
	rabbit.update(self, inp)
	if state != "play":
		return
	if rabbit.ev_jump:
		_dust(3, 30.0)
		_jump_ring()
		sfx.emit("jump")
	if rabbit.ev_land:
		_dust(5, 45.0)
	if rabbit.ev_grab:
		sfx.emit("rope")
		_rope_puff()
	if rabbit.ev_release:
		sfx.emit("jump")
	if rabbit.ev_splash > 0.0:
		sfx.emit("splash")
		_splash(rabbit.ev_splash)
		_water_push(rabbit.pos.x, rabbit.pos.x + Rabbit.SIZE, rabbit.ev_splash * 0.02)
	elif rabbit.wet > 0.2 and absf(rabbit.vel.x) > 12.0 and frame % 5 == 0:
		# nadando: marolas
		_water_push(rabbit.pos.x + 1, rabbit.pos.x + 11, 0.12 if frame % 10 == 0 else -0.12)
	if rabbit.push_t > 0 and frame % 7 == 0:
		_push_dust()
	_update_ropes()
	_update_boxes()
	if state != "play":
		return
	_update_water()
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
	# na água a caixa continua afundando, mas devagar, e pousa sem estrondo
	var wet := water_frac(b.rect) >= BOX_WET
	if not wet:
		b.vel_y = minf(b.vel_y + BOX_GRAVITY * DT, BOX_MAX_FALL)
	elif b.vel_y > BOX_WATER_FALL:
		b.vel_y = maxf(b.vel_y * 0.8, BOX_WATER_FALL)
	else:
		b.vel_y = minf(b.vel_y + BOX_WATER_GRAVITY * DT, BOX_WATER_FALL)
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
		if not wet:
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
	# Água na porta a bloqueia; ela só destrava depois de um tempo seca. Sem essa espera, bastava
	# ficar dentro da porta e girar a sala: a água cai, a porta abre e o coelho ainda está lá.
	if has_door and water_frac(door) >= DOOR_FLOOD:
		door_dry = 0
	else:
		door_dry = mini(door_dry + 1, DOOR_DRY_FRAMES)
	door_flooded = door_dry < DOOR_DRY_FRAMES
	var open: bool = (group_filled(0) or def.get("door_open", false)) and not door_flooded
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
				water_dirty = true
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
				water_dirty = true
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


# ---------------------------------------------------------------- corda

## A corda presa no teto que passa por este retângulo, ou null. Vale a forma real da corda:
## logo depois de um giro ela ainda está balançando.
func rope_at(r: Rect2i):
	var box := Rect2(r)
	for rp in ropes:
		if rp["facing"] != 2:
			continue
		var pts: PackedVector2Array = rp["pts"]
		for i in range(1, pts.size()):
			if box.has_point(pts[i]):
				return rp
	return null


func _rope_init(rp: Dictionary) -> void:
	var dirv: Vector2 = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT][rp["facing"]]
	var pts := PackedVector2Array()
	for i in int(rp["len"] / ROPE_SEG) + 1:
		pts.append(rp["anchor"] + dirv * (i * ROPE_SEG))
	rp["pts"] = pts
	rp["old"] = pts.duplicate()


func _pt_solid(p: Vector2) -> bool:
	return solid_static(Rect2i(int(floorf(p.x)), int(floorf(p.y)), 1, 1))


## Física da corda (Verlet): cada ponto cai com a gravidade, as distâncias entre vizinhos são
## mantidas, e os pontos não entram nas paredes. A âncora é fixa; se o coelho está pendurado,
## o ponto que ele segura acompanha a mão dele, e a sobra balança solta.
func _update_ropes() -> void:
	for rp in ropes:
		var pts: PackedVector2Array = rp["pts"]
		var old: PackedVector2Array = rp["old"]
		var n := pts.size()
		var hold := -1
		var hand := Vector2.ZERO
		if rabbit != null and rabbit.rope == rp:
			hold = clampi(roundi(rabbit.rope_r / ROPE_SEG), 1, n - 1)
			hand = Vector2(rabbit.pos) + Vector2(6, 6)
		for i in range(1, n):
			var v := (pts[i] - old[i]) * ROPE_AIR
			old[i] = pts[i]
			# um sopro mínimo de lado: sem ele, uma corda apontando reta para cima ficaria em pé
			pts[i] += v + Vector2(0.004 * sin(i * 1.7 + frame * 0.05), BOX_GRAVITY * DT * DT)
		for it in ROPE_ITERS:
			pts[0] = rp["anchor"]
			if hold > 0:
				pts[hold] = hand
			for i in n - 1:
				var d := pts[i + 1] - pts[i]
				var dist := d.length()
				if dist < 0.0001:
					continue
				var corr := d * (1.0 - ROPE_SEG / dist)
				var pin_a := i == 0 or i == hold
				var pin_b := i + 1 == hold
				if pin_a and pin_b:
					continue
				if pin_a:
					pts[i + 1] -= corr
				elif pin_b:
					pts[i] += corr
				else:
					pts[i] += corr * 0.5
					pts[i + 1] -= corr * 0.5
		for i in range(1, n):
			if i == hold:
				continue
			var p := pts[i]
			if _pt_solid(p):
				var o := old[i]
				if not _pt_solid(Vector2(p.x, o.y)):
					# apoiou em cima ou embaixo de algo: para na vertical e arrasta na horizontal
					pts[i] = Vector2(lerpf(p.x, o.x, 0.4), o.y)
				elif not _pt_solid(Vector2(o.x, p.y)):
					pts[i] = Vector2(o.x, p.y)
				else:
					pts[i] = o
		rp["pts"] = pts
		rp["old"] = old


func _rope_puff() -> void:
	var c := Vector2(rabbit.pos) + Vector2(6, 2)
	for i in 5:
		particles.append({
			"pos": c + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)),
			"vel": Vector2(randf_range(-30.0, 30.0), randf_range(-25.0, 5.0)),
			"life": randi_range(8, 14), "col": C_ROPE, "grav": 60.0,
		})


# ---------------------------------------------------------------- água

## Fração (0 a 1) de um retângulo que está dentro da água.
func water_frac(r: Rect2i) -> float:
	if water_vol <= 0.0:
		return 0.0
	var x0 := maxi(r.position.x, 0)
	var x1 := mini(r.position.x + r.size.x, pw)
	var y0 := float(r.position.y)
	var y1 := float(r.position.y + r.size.y)
	var area := 0.0
	for x in range(x0, x1):
		for k in range(wcol[x], wcol[x + 1]):
			var h := wt_h[k]
			if h <= 0.0:
				continue
			var b := wt_bot[k] - wt_air[k]
			var lo := maxf(b - h, y0)
			var hi := minf(b, y1)
			if hi > lo:
				area += hi - lo
	return area / float(r.size.x * r.size.y)


func _tile_blocked(c: int, r: int) -> bool:
	if tiles[r * gw + c] != 0:
		return true
	var cell := Rect2i(c * TILE, r * TILE, TILE, TILE)
	for g in gates:
		if g["closed"] and g["rects"].has(cell):
			return true
	for p in platforms:
		if p["solid"] and p["rect"] == cell:
			return true
	return false


## Monta os vãos de cada coluna e os canos entre vãos vizinhos. Começa sem água.
func _water_build() -> void:
	water_dirty = false
	wt_x = PackedInt32Array()
	wt_top = PackedInt32Array()
	wt_bot = PackedInt32Array()
	wcol = PackedInt32Array()
	wcol.resize(pw + 1)
	for c in gw:
		# trechos livres desta coluna de tiles, iguais para as 8 colunas de pixels dela
		var segs: Array = []
		var start := -1
		for r in gh + 1:
			var blocked := r == gh or _tile_blocked(c, r)
			if not blocked and start < 0:
				start = r
			elif blocked and start >= 0:
				segs.append(Vector2i(start * TILE, r * TILE))
				start = -1
		for dx in TILE:
			wcol[c * TILE + dx] = wt_x.size()
			for sg in segs:
				wt_x.append(c * TILE + dx)
				wt_top.append(sg.x)
				wt_bot.append(sg.y)
	var n := wt_x.size()
	wcol[pw] = n
	wt_h = PackedFloat64Array()
	wt_h.resize(n)
	wt_air = PackedFloat64Array()
	wt_air.resize(n)
	wt_vy = PackedFloat64Array()
	wt_vy.resize(n)
	wt_o = PackedFloat64Array()
	wt_o.resize(n)
	wt_v = PackedFloat64Array()
	wt_v.resize(n)
	ripples = false
	# ligações entre colunas vizinhas: [a, b, soleira, teto da passagem]
	var level: Array = []
	for x in pw - 1:
		for a in range(wcol[x], wcol[x + 1]):
			for b in range(wcol[x + 1], wcol[x + 2]):
				var roof := maxi(wt_top[a], wt_top[b])
				var sill := mini(wt_bot[a], wt_bot[b])
				if roof < sill:
					level.append([a, b, sill, roof])
	we_a = PackedInt32Array()
	we_b = PackedInt32Array()
	we_sill = PackedInt32Array()
	we_nu = PackedFloat64Array()
	we_near = level.size()
	var reach := 1
	while true:
		var stride := maxi(reach / 2, 1)
		for ed in level:
			if wt_x[ed[0]] % stride == 0:
				we_a.append(ed[0])
				we_b.append(ed[1])
				we_sill.append(ed[2])
				we_nu.append(WATER_NU if reach == 1 else WATER_NU_FAR)
		if reach >= WATER_REACH[WATER_REACH.size() - 1]:
			break
		# o dobro da distância: emenda duas ligações que passam pelo mesmo vão do meio
		var from := {}
		for ed in level:
			if not from.has(ed[0]):
				from[ed[0]] = []
			from[ed[0]].append(ed)
		var longer: Array = []
		for e1 in level:
			for e2 in from.get(e1[1], []):
				var roof := maxi(e1[3], e2[3])
				var sill := mini(e1[2], e2[2])
				if roof < sill:
					longer.append([e1[0], e2[1], sill, roof])
		level = longer
		reach *= 2
	we_fall = PackedFloat64Array()
	we_fall.resize(we_a.size())
	water_calm = false
	water_still = 0


## O vão da coluna x que contém a linha y, ou -1.
func _tank_at(x: int, y: int) -> int:
	if x < 0 or x >= pw:
		return -1
	for k in range(wcol[x], wcol[x + 1]):
		if y >= wt_top[k] and y < wt_bot[k]:
			return k
	return -1


## Comporta ou plataforma mudou: refaz os vãos e recoloca a água no vão onde ela estava.
func _water_rebuild_keep() -> void:
	var keep: Array = []
	for k in wt_x.size():
		if wt_h[k] > 0.0:
			keep.append([wt_x[k], wt_bot[k] - wt_air[k], wt_h[k]])
	_water_build()
	water_vol = 0.0
	for w in keep:
		var k := _tank_at(w[0], int(ceilf(w[1])) - 1)
		if k < 0:
			continue
		var room_left := float(wt_bot[k] - wt_top[k]) - wt_h[k]
		var add := minf(w[2], room_left)
		wt_air[k] = maxf(wt_bot[k] - w[1], 0.0) if wt_h[k] <= 0.0 else wt_air[k]
		wt_h[k] += add
		water_vol += add


## Antes do giro: a água como faixas horizontais já giradas: [linha, x inicial, x final].
func _water_slivers(dir: int) -> Array:
	var out: Array = []
	for k in wt_x.size():
		var h := wt_h[k]
		if h <= 0.0:
			continue
		var y1 := wt_bot[k] - wt_air[k]
		var y0 := y1 - h
		if dir > 0:
			out.append([wt_x[k], ph - y1, ph - y0])
		else:
			out.append([pw - 1 - wt_x[k], y0, y1])
	return out


## Depois do giro: distribui as faixas pelas colunas novas. Em cada vão a água fica onde
## estava; se não há nada embaixo dela, vai cair (wt_air > 0).
func _water_deposit(slivers: Array) -> void:
	water_vol = 0.0
	var low := {}  # vão -> linha de água mais baixa
	for sl in slivers:
		var row: int = sl[0]
		var xa: float = sl[1]
		var xb: float = sl[2]
		for cx in range(int(floorf(xa)), int(ceilf(xb))):
			var cov := minf(xb, cx + 1.0) - maxf(xa, float(cx))
			var k := _tank_at(cx, row)
			if k < 0 or cov <= 0.0:
				continue
			wt_h[k] += cov
			if cov >= 0.5:
				low[k] = maxi(low.get(k, -1), row)
	for k in wt_x.size():
		if wt_h[k] <= 0.0:
			continue
		if low.has(k):
			wt_air[k] = float(wt_bot[k] - 1 - low[k])
		wt_h[k] = minf(wt_h[k], float(wt_bot[k] - wt_top[k]) - wt_air[k])
		water_vol += wt_h[k]
	water_calm = false
	water_still = 0


## Um quadro da água. Blocos soltos caem; depois, cada ligação iguala uma parcela do desnível
## entre os dois vãos (só passa a água que está acima da soleira). É estável por construção:
## cada troca só aproxima os dois níveis. Devolve a maior troca do quadro.
func _water_sim() -> float:
	var n := wt_x.size()
	var falling := false
	for k in n:
		if wt_air[k] > 0.0:
			if wt_h[k] <= 0.0:
				wt_air[k] = 0.0
				continue
			wt_vy[k] = minf(wt_vy[k] + WATER_FALL_G * DT, WATER_MAX_FALL)
			wt_air[k] -= wt_vy[k] * DT
			if wt_air[k] <= 0.0:
				wt_air[k] = 0.0
				wt_v[k] += wt_vy[k] * 0.02  # o bloco bate no fundo: onda
				wt_vy[k] = 0.0
				ripples = true
			else:
				falling = true
	var ne := we_a.size()
	var peak := 0.0
	for e in ne:
		we_fall[e] *= 0.8
	for s in WATER_SUBSTEPS:
		for i in ne:
			var e := i if (s + frame) % 2 == 0 else ne - 1 - i
			var a := we_a[e]
			var b := we_b[e]
			var ha := wt_h[a]
			var hb := wt_h[b]
			if ha <= 0.0 and hb <= 0.0:
				continue
			if wt_air[a] > 0.0 or wt_air[b] > 0.0:
				continue
			var sill := float(we_sill[e])
			var sa := wt_bot[a] - ha
			var sb := wt_bot[b] - hb
			var drive := minf(sb, sill) - minf(sa, sill)
			if drive == 0.0:
				continue
			var q := we_nu[e] * drive
			if q > 0.0:
				q = minf(q, float(wt_bot[b] - wt_top[b]) - hb)
				if e < we_near and sb > sill + 1.0:
					we_fall[e] = maxf(we_fall[e], q)
			else:
				q = -minf(-q, float(wt_bot[a] - wt_top[a]) - ha)
				if e < we_near and sa > sill + 1.0:
					we_fall[e] = minf(we_fall[e], q)
			wt_h[a] = ha - q
			wt_h[b] = hb + q
			var aq := absf(q)
			if aq > peak:
				peak = aq
			if e < we_near and aq > 0.25:
				# água correndo: agita a superfície, em ondulações largas (não coluna a coluna)
				var jit := minf(aq, 2.0) * 0.03 * sin(frame * 0.35 + wt_x[a] * 0.3)
				wt_v[a] += jit
				wt_v[b] += jit
				ripples = true
	return INF if falling else peak


## Ondas da superfície: cada coluna é uma mola presa ao nível da água e puxada pelas vizinhas.
## Não mexem no volume nem na física; só no desenho.
func _ripple_sim() -> void:
	var live := false
	for e in we_near:
		var a := we_a[e]
		var b := we_b[e]
		if wt_h[a] < 1.0 or wt_h[b] < 1.0:
			continue
		if absf((wt_bot[a] - wt_h[a]) - (wt_bot[b] - wt_h[b])) > 3.0:
			continue  # não é a mesma superfície (degrau, cascata)
		var d := (wt_o[b] - wt_o[a]) * RIPPLE_SPREAD
		wt_v[a] += d
		wt_v[b] -= d
	for k in wt_x.size():
		var o := wt_o[k]
		var v := wt_v[k]
		if o == 0.0 and v == 0.0:
			continue
		v = (v - RIPPLE_TENSION * o) * RIPPLE_DAMP
		o = clampf(o + v, -RIPPLE_MAX, minf(RIPPLE_MAX, wt_h[k]))
		if wt_h[k] < 1.0 or (absf(o) < 0.02 and absf(v) < 0.02):
			o = 0.0
			v = 0.0
		else:
			live = true
		wt_o[k] = o
		wt_v[k] = v
	ripples = live


func _update_water() -> void:
	if wt_x.is_empty() or (water_vol <= 0.0 and not water_dirty):
		return
	if water_dirty:
		_water_rebuild_keep()
	if not water_calm:
		var peak := _water_sim()
		if peak < WATER_CALM_Q * 6.0:
			_water_dry_films()
		water_still = water_still + 1 if peak < WATER_CALM_Q else 0
		if water_still >= WATER_CALM_FRAMES:
			water_calm = true
			for e in we_fall.size():
				we_fall[e] = 0.0
	if ripples:
		_ripple_sim()
	for d in drains:
		_drain_step(d)


## Lâminas finas demais para ver secam, em vez de ficarem escorrendo para sempre.
func _water_dry_films() -> void:
	for k in wt_x.size():
		var h := wt_h[k]
		if h > 0.0 and h < WATER_FILM and wt_air[k] <= 0.0:
			var take := minf(h, 0.02)
			wt_h[k] -= take
			water_vol -= take


## O ralo engole, aos poucos, a água que encosta nele.
func _drain_step(d: Dictionary) -> void:
	var r: Rect2i = d["rect"]
	var took := 0.0
	for x in range(r.position.x, r.position.x + r.size.x):
		var k := _tank_at(x, r.position.y + r.size.y - 1)
		if k < 0 or wt_h[k] <= 0.0 or wt_air[k] > 0.0:
			continue
		if wt_bot[k] - wt_h[k] >= r.position.y + r.size.y:
			continue  # a água desta coluna está abaixo do ralo
		var take := minf(wt_h[k], DRAIN_RATE)
		wt_h[k] -= take
		took += take
	if took <= 0.0:
		return
	water_vol = maxf(water_vol - took, 0.0)
	water_calm = false
	water_still = 0
	d["spin"] += 0.35
	if frame % 6 == 0:
		var c := Vector2(r.position) + Vector2(4, 4)
		particles.append({
			"pos": c + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)),
			"vel": Vector2(randf_range(-12.0, 12.0), -randf_range(10.0, 30.0)),
			"life": randi_range(8, 14), "col": C_WATER_TOP, "grav": 0.0,
		})


## Ao carregar a sala: deixa a água escorrer até parar, para nada se mexer sozinho no início.
func _settle_water() -> void:
	if water_dirty:
		_water_rebuild_keep()
	if water_vol <= 0.0:
		return
	water_calm = false
	water_still = 0
	for i in WATER_SETTLE:
		var peak := _water_sim()
		water_still = water_still + 1 if peak < WATER_CALM_Q else 0
		if water_still >= WATER_CALM_FRAMES:
			break
	water_calm = true
	for e in we_fall.size():
		we_fall[e] = 0.0
	for k in wt_o.size():
		wt_o[k] = 0.0
		wt_v[k] = 0.0
	ripples = false


## Algo caiu na água entre as colunas x0 e x1: afunda a superfície ali e a onda se espalha.
func _water_push(x0: int, x1: int, strength: float) -> void:
	for x in range(maxi(x0, 0), mini(x1, pw)):
		for k in range(wcol[x], wcol[x + 1]):
			if wt_h[k] >= 1.0:
				wt_v[k] += strength
				ripples = true


func _splash(speed: float) -> void:
	var k := clampf(speed / 160.0, 0.3, 1.5)
	var c := Vector2(rabbit.pos.x + 6, rabbit.pos.y + 10)
	for i in 6 + int(6.0 * k):
		var dir := -1.0 if i % 2 == 0 else 1.0
		particles.append({
			"pos": c + Vector2(dir * randf_range(1.0, 6.0), 0),
			"vel": Vector2(dir * randf_range(10.0, 45.0) * k, -randf_range(40.0, 110.0) * k),
			"life": randi_range(12, 22), "col": C_WATER_TOP, "grav": 380.0,
		})


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


## Chamado pelo coelho a cada pixel quando ele está rápido (na corda ou arremessado): o que
## ele toca primeiro decide. Devolve true se a sala deixou de estar em jogo.
func touch_check() -> bool:
	if state != "play":
		return true
	_check_win()
	if state == "play":
		_check_hazards()
	return state != "play"


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
	if rabbit.rope != null:
		return [_rabbit_tex("back", "air", false), 0]
	if not rabbit.on_ground and rabbit.wet >= Rabbit.SWIM_MIN and absf(rabbit.vel.y) < 40.0:
		# boiando: orelhas em pé, patas remando devagar
		var paddle := "air" if int(frame / 14.0) % 2 == 0 else "run_a"
		return [_rabbit_tex("up", paddle, frame % 260 >= 120 and frame % 260 < 127), 0]
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
	_draw_drains()
	_draw_ropes()

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

	_draw_water()

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


## Ralo: grade redonda com raios; gira enquanto engole água.
func _draw_drains() -> void:
	for d in drains:
		var c := Vector2(d["rect"].position) + Vector2(4, 4)
		draw_circle(c, 4.0, Color(C_DRAIN, 0.25))
		draw_arc(c, 3.5, 0.0, TAU, 16, C_DRAIN, 1.0)
		for i in 3:
			var a: float = d["spin"] + i * PI / 3.0
			var v := Vector2(cos(a), sin(a)) * 3.0
			draw_line(c - v, c + v, C_DRAIN, 1.0)


## Corda: uma linha pelos pontos simulados. Presa no teto (dá para agarrar) ou na mão do
## coelho, na cor cheia; nas outras orientações, apagada.
func _draw_ropes() -> void:
	for rp in ropes:
		var pts: PackedVector2Array = rp["pts"]
		var live: bool = rp["facing"] == 2 or (rabbit != null and rabbit.rope == rp)
		var col := C_ROPE if live else Color(C_ROPE, 0.5)
		draw_polyline(pts, col, 1.0)
		var tip := pts[pts.size() - 1].floor()
		draw_rect(Rect2(tip - Vector2(1, 1), Vector2(3, 3)), col)
		draw_rect(Rect2(rp["anchor"] - Vector2(1, 1), Vector2(3, 3)), C_ROPE)


## Água: uma faixa por coluna, da superfície ao fundo, com a linha da superfície mais clara.
## Colunas vizinhas iguais viram um retângulo só. Cascatas: um fio da soleira até a água.
func _draw_water() -> void:
	if water_vol <= 0.0:
		return
	var body := Color(C_WATER, 0.55)
	var top := Color(C_WATER_TOP, 0.85)
	var run_x := 0
	var run_y0 := -1
	var run_y1 := -1
	var run_w := 0
	for k in wt_x.size():
		var y0 := -1
		var y1 := -1
		if wt_h[k] >= 0.5:
			var b := wt_bot[k] - wt_air[k]
			y1 = roundi(b)
			y0 = mini(roundi(b - wt_h[k] + wt_o[k]), y1 - 1)
		if run_w > 0 and y0 == run_y0 and y1 == run_y1 and wt_x[k] == run_x + run_w:
			run_w += 1
			continue
		if run_w > 0:
			draw_rect(Rect2(run_x, run_y0, run_w, run_y1 - run_y0), body)
			draw_rect(Rect2(run_x, run_y0, run_w, 1), top)
		run_w = 0
		if y1 > y0:
			run_x = wt_x[k]
			run_y0 = y0
			run_y1 = y1
			run_w = 1
	if run_w > 0:
		draw_rect(Rect2(run_x, run_y0, run_w, run_y1 - run_y0), body)
		draw_rect(Rect2(run_x, run_y0, run_w, 1), top)
	for e in we_a.size():
		var q := we_fall[e]
		if absf(q) < 0.004:
			continue
		var to := we_b[e] if q > 0.0 else we_a[e]
		var y_from := float(we_sill[e])
		var y_to := wt_bot[to] - wt_air[to] - wt_h[to]
		if y_to > y_from + 1.0:
			var w := 2.0 if absf(q) > 0.05 else 1.0
			var x := float(wt_x[to]) if q > 0.0 else float(wt_x[to]) + 1.0 - w
			draw_rect(Rect2(x, y_from, w, y_to - y_from), Color(C_WATER_TOP, clampf(absf(q) * 30.0, 0.35, 0.8)))


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

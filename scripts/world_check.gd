extends RefCounted
## As checagens do mundo sobre os dados de verdade (D120, D121):
##
## - **O giro não pula a sala** (D121): o giro é a mecânica central, mas não pode servir para
##   atravessar a sala sem passar pelo que ela pede (como na Passagem antiga: muito espaço vazio em
##   cima e plataformas embaixo; girada, o coelho caía de uma ponta à outra). Para cada par entrada →
##   saída livre, mede o esforço do caminho mais barato com giro e sem giro, num modelo simples do
##   coelho na grade. Se o giro corta o caminho para menos de um terço da distância entre as saídas
##   (e para menos da metade do caminho sem giro), a sala é recusada.
## - **Alcance**: as mesmas contas, com as peças a favor (comportas abertas, saídas trancadas abertas),
##   dizem de que saída se chega a que saída com as habilidades e os itens de agora. O validador de
##   progressão do mundo anda por essas ligações, ganhando o que as salas dão.
##
## O modelo (em tiles, o coelho ocupa 2×2): andar (1 por tile), pular (até 3 para cima, 1 de lado por
## linha e mais 1 no alto; 1 por tile), cair (de graça no aberto, 1 por tile no corredor; 1 de deriva
## a cada 2), girar no chão (A1) ou uma vez no ar
## (A2), 2 por giro. Corda, ventilador, vapor e plataforma móvel valem como escada (sobe e desce);
## água deixa nadar (afundar só com o mergulho, A3); mola e cogumelo-mola pulam alto. Espinhos e ácido
## não se pisam. A saída comum só deixa passar de pé (D100).

const World := preload("res://scripts/world.gd")

const EMPTY := 0
const SOLID := 1
const DEADLY := 2
const WATER := 3
const CLIMB := 4
const EXIT := 5
const PLAT := 6     # barra sólida: sólida quando a seta aponta para cima
const PASS := 7     # barra de passagem: segura quando a seta aponta para cima

const INF := 1 << 28
const JUMP := 3
const SPRING_JUMP := 12
const ROT_COST := 2

## A regra do giro (D121).
const SKIP_MIN_DIST := 24      # salas (de saída a saída) menores que isso não entram na conta
const SKIP_RATIO := 0.34       # o giro não pode baratear o caminho abaixo disso da distância
const SKIP_VS_UP := 0.5        # ... nem abaixo disso do caminho sem giro


## A grade da sala, de pé: tipos de célula, a saída de cada célula (-1) e a seta das barras.
## `reach`: modo alcance (comportas abertas, saídas trancadas abertas); senão, o estado inicial.
static func model(def: Dictionary, abilities: Dictionary, items: Dictionary, reach := false) -> Dictionary:
	var rows: Array = def.get("rows", [])
	var h := rows.size()
	var w := 0
	for r in rows:
		w = maxi(w, String(r).length())
	var kind := PackedInt32Array()
	kind.resize(w * h)
	var exit_of := PackedInt32Array()
	exit_of.resize(w * h)
	exit_of.fill(-1)
	var facing := PackedInt32Array()
	facing.resize(w * h)
	var spring := PackedByteArray()
	spring.resize(w * h)
	for r in h:
		var line := String(rows[r])
		for c in w:
			var ch := line[c] if c < line.length() else "#"
			var k := EMPTY
			match ch:
				"#":
					k = SOLID
				"^", ">", "v", "<", "%":
					k = DEADLY
				"~":
					k = WATER
				"|", "-":
					k = CLIMB
				"=", "}", "_", "{":
					k = PLAT
					facing[r * w + c] = "=}_{".find(ch)
				"↑", "→", "↓", "←":
					k = PASS
					facing[r * w + c] = "↑→↓←".find(ch)
				_:
					if ch >= "1" and ch <= "9":
						k = EMPTY if reach else SOLID
			kind[r * w + c] = k
	var exs := World.parse_exits(rows)
	var entry_only: Array = []
	for v in def.get("entry_only", []):
		entry_only.append(int(v))
	for i in exs.size():
		var er: Rect2i = exs[i]["rect"]
		var leave := not entry_only.has(i) and (reach or not bool(exs[i]["locked"]) or bool(def.get("door_open", false)))
		for y in range(er.position.y, er.end.y):
			for x in range(er.position.x, er.end.x):
				kind[y * w + x] = EXIT
				exit_of[y * w + x] = i if leave else -2   # -2: saída que não deixa sair (fecha)
	# as peças em objeto (em tiles)
	for m in def.get("movers", []):
		var a: Array = m["off"]
		var b: Array = m.get("on", [a[0], a[1]])
		var r0 := Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))
		var r1 := Rect2i(Vector2i(int(b[0]), int(b[1])), r0.size)
		_fill(kind, w, h, r0.merge(r1), CLIMB, [EMPTY, WATER])
	for kname in ["fans", "vents"]:
		for f in def.get(kname, []):
			var a: Array = f["rect"]
			_fill(kind, w, h, Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3])), CLIMB, [EMPTY, WATER])
	for kname in ["crumbles", "wilts"]:
		for f in def.get(kname, []):
			var a: Array = f if f is Array else f["rect"]
			_fill(kind, w, h, Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3])), SOLID, [EMPTY])
	for kname in ["springs", "bouncers"]:
		for f in def.get(kname, []):
			var a: Array = f["rect"]
			for y in range(int(a[1]) - 2, int(a[1]) + int(a[3])):
				for x in range(int(a[0]) - 1, int(a[0]) + int(a[2])):
					if x >= 0 and y >= 0 and x < w and y < h:
						spring[y * w + x] = 1
	for b in def.get("barriers", []):
		if has_need(str(b.get("need", "A6")), abilities, items, reach):
			continue
		var a: Array = b["rect"]
		_fill(kind, w, h, Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3])), SOLID, [])
	var item_of := PackedInt32Array()
	item_of.resize(w * h)
	item_of.fill(-1)
	var il: Array = def.get("items", [])
	for i in il.size():
		var a: Array = il[i]["rect"]
		for y in range(int(a[1]), int(a[1]) + int(a[3])):
			for x in range(int(a[0]), int(a[0]) + int(a[2])):
				if x >= 0 and y >= 0 and x < w and y < h:
					item_of[y * w + x] = i
	return {"w": w, "h": h, "kind": kind, "exit": exit_of, "facing": facing, "spring": spring, "item": item_of,
		"exits": exs, "rose": bool(def.get("rose", false)), "ab": abilities}


## A barreira abre com isso? (a pedra do chefe: no alcance, o chefe é vencível)
static func has_need(need: String, abilities: Dictionary, items: Dictionary, reach: bool) -> bool:
	if need == "chefe" or need == "sala":
		return reach
	if need == "chaves":
		return int(items.get("chave1", 0)) > 0 and int(items.get("chave2", 0)) > 0 and int(items.get("chave3", 0)) > 0
	return abilities.has(need) or int(items.get(need, 0)) > 0


static func _fill(kind: PackedInt32Array, w: int, h: int, r: Rect2i, k: int, only: Array) -> void:
	for y in range(maxi(r.position.y, 0), mini(r.end.y, h)):
		for x in range(maxi(r.position.x, 0), mini(r.end.x, w)):
			if only.is_empty() or only.has(kind[y * w + x]):
				kind[y * w + x] = k


## As quatro grades giradas (o = quartos de volta no sentido horário, como a sala gira).
static func _rotations(m: Dictionary) -> Array:
	var out: Array = []
	var w: int = m["w"]
	var h: int = m["h"]
	var kind: PackedInt32Array = m["kind"]
	var ex: PackedInt32Array = m["exit"]
	var fc: PackedInt32Array = m["facing"]
	var sp: PackedByteArray = m["spring"]
	var it: PackedInt32Array = m["item"]
	for o in 4:
		var ww := w if o % 2 == 0 else h
		var hh := h if o % 2 == 0 else w
		var k2 := PackedInt32Array()
		k2.resize(ww * hh)
		var e2 := PackedInt32Array()
		e2.resize(ww * hh)
		var s2 := PackedByteArray()
		s2.resize(ww * hh)
		var i2 := PackedInt32Array()
		i2.resize(ww * hh)
		for y in h:
			for x in w:
				var p := _rot_cell(Vector2i(x, y), w, h, o)
				var i := y * w + x
				var j := p.y * ww + p.x
				var k := kind[i]
				if k == PLAT or k == PASS:
					var up := posmod(fc[i] + o, 4) == 0
					k = (SOLID if k == PLAT else PASS) if up else EMPTY
				elif k == EXIT:
					# a saída comum só abre de pé; a rosa, em qualquer giro
					if not (o == 0 or m["rose"]) or ex[i] < 0:
						k = SOLID
				k2[j] = k
				e2[j] = ex[i]
				s2[j] = sp[i]
				i2[j] = it[i]
		out.append({"w": ww, "h": hh, "kind": k2, "exit": e2, "spring": s2, "item": i2})
	return out


## A célula (x, y) da sala de pé (w×h), girada o vezes no horário: (x, y) -> (H - 1 - y, x) a cada vez.
static func _rot_cell(p: Vector2i, w: int, h: int, o: int) -> Vector2i:
	var q := p
	var cw := w
	var ch := h
	for i in posmod(o, 4):
		q = Vector2i(ch - 1 - q.y, q.x)
		var t := cw
		cw = ch
		ch = t
	return q


## O coelho (2×2 células, canto em (x, y)) girando junto com a sala: o canto novo.
static func _rot_body(p: Vector2i, w: int, h: int, d: int) -> Vector2i:
	# d = +1 (horário): (x, y) -> (h - 2 - y, x); d = -1: (x, y) -> (y, w - 2 - x)
	if d > 0:
		return Vector2i(h - 2 - p.y, p.x)
	return Vector2i(p.y, w - 2 - p.x)


## Custo do caminho mais barato de cada saída de entrada a cada saída (que deixa sair). `rotate`:
## pode girar (com A1; no ar com A2). {entrada: {saída: custo}}.
static func paths(def: Dictionary, abilities: Dictionary, items := {}, reach := false, rotate := true) -> Dictionary:
	if not bool(def.get("rotate", true)):
		rotate = false   # sala sem giro (corredor)
	var m := model(def, abilities, items, reach)
	var grids := _rotations(m)
	var out := {}
	var exs: Array = m["exits"]
	for i in exs.size():
		out[i] = _dijkstra(m, grids, i, abilities, rotate)
	return out


## Onde o coelho aparece entrando pela saída i (como room._place_at_exit), e em que modo.
static func _entry_state(m: Dictionary, i: int) -> Array:
	var ex: Dictionary = m["exits"][i]
	var er: Rect2i = ex["rect"]
	var w: int = m["w"]
	var h: int = m["h"]
	var cx := er.position.x + er.size.x / 2 - 1
	match int(ex["side"]):
		9:
			return [er.position, 1]
		3:
			return [Vector2i(1, er.end.y - 2), 1]
		1:
			return [Vector2i(w - 3, er.end.y - 2), 1]
		0:
			return [Vector2i(cx, 1), 1]
	return [Vector2i(cx, h - 3), 2]   # por baixo: sobe com um impulso


const M_GROUND := 0
const M_FALL := 1      # no ar, ainda pode girar (A2)
const M_FALL2 := 2     # no ar, já girou


static func _dijkstra(m: Dictionary, grids: Array, entry: int, ab: Dictionary, rotate: bool) -> Dictionary:
	var w0: int = m["w"]
	var h0: int = m["h"]
	var can_rot := rotate and ab.has("A1")
	var air_rot := can_rot and ab.has("A2")
	var dive := ab.has("A3")
	var half := can_rot and ab.has("A5")
	# índice do estado: ((o * h_max + y) * w_max + x) * 3 + modo
	var wm := maxi(w0, h0)
	_wm = wm
	var n := 4 * wm * wm * 3
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(INF)
	var buckets: Array = []   # custo -> Array de estados
	var best := {}
	var st: Array = _entry_state(m, entry)
	var p0: Vector2i = st[0]
	var o0 := 0
	if not _start_at.is_empty():
		# o robô do mundo: o caminho a partir de onde o coelho está (giro, célula)
		o0 = int(_start_at[0])
		p0 = _start_at[1]
		st = [p0, 1]
	var g0: Dictionary = grids[o0]
	if not _free(g0, p0.x, p0.y):
		return best
	var s0 := ((o0 * wm + p0.y) * wm + p0.x) * 3 + M_FALL
	dist[s0] = 0
	buckets.append([s0])
	var start_rise: bool = st[1] == 2
	var cost := 0
	while cost < buckets.size():
		var bucket: Array = buckets[cost]
		var bi := 0
		while bi < bucket.size():
			var s: int = bucket[bi]
			bi += 1
			if dist[s] != cost:
				continue
			_cur = s
			var mode := s % 3
			var cell := s / 3
			var x := cell % wm
			var y := (cell / wm) % wm
			var o := cell / (wm * wm)
			var g: Dictionary = grids[o]
			var gw: int = g["w"]
			var gh: int = g["h"]
			# chegou numa saída aberta? (e em que giro: a rosa sai para lados diferentes)
			var e := _exit_touch(g, x, y)
			if e == ignore_exit and o == 0:
				e = -1   # a saída por onde o robô entrou: passar por ela de novo não conta
			if e >= 0:
				if not best.has(e):
					best[e] = cost
					if trace_on:
						_hit[e] = s
				var eo := "%d@%d" % [e, o]
				if not best.has(eo):
					best[eo] = cost
					if trace_on:
						_hit[eo] = s
				continue   # encostou numa saída aberta: saiu da sala (não segue daqui)
			var it := _item_touch(g, x, y)
			if it >= 0 and not best.has("i%d" % it):
				best["i%d" % it] = cost
				if trace_on:
					_hit["i%d" % it] = s
			var hold := _hold(g, x, y)
			var sup := _supported(g, x, y)
			if mode != M_GROUND:
				if sup or hold:
					_push(dist, buckets, ((o * wm + y) * wm + x) * 3 + M_GROUND, cost)
					continue
				# cair: reto de graça, na diagonal 1
				# caindo em cima de espinho (ou ácido): morreu (não dá para girar depois de encostar)
				if not _free(g, x, y + 1) and _deadly_below(g, x, y):
					continue
				# no corredor estreito, cair custa como andar (girado, o túnel não é atalho)
				var nar := 1 if _narrow(g, x, y + 1) else 0
				# deriva no ar: 1 tile de lado a cada 2 de queda (o coelho anda 72 px/s; a queda acelera)
				for dx in ([0, -1, 1] if (y + 1) % 2 == 0 else [0]):
					var nx: int = x + dx
					if _free(g, nx, y + 1) and (dx == 0 or _free(g, nx, y) or _free(g, x, y + 1)):
						_push(dist, buckets, ((o * wm + y + 1) * wm + nx) * 3 + mode, cost + maxi(absi(dx), nar))
				if mode == M_FALL and air_rot:
					_rotate_edges(dist, buckets, wm, grids, o, x, y, cost, M_FALL2, half)
				if start_rise and s == s0:
					_jump_edges(dist, buckets, wm, g, o, x, y, cost, JUMP, mode)
				continue
			# no chão (ou pendurado, ou nadando)
			for dx in [-1, 1]:
				var nx: int = x + dx
				if _free(g, nx, y):
					_push(dist, buckets, ((o * wm + y) * wm + nx) * 3 + (M_GROUND if _supported(g, nx, y) or _hold(g, nx, y) else M_FALL), cost + 1)
			if hold:
				var can_down := not _in_water(g, x, y) or dive or _climb(g, x, y)
				for dy in [-1, 1]:
					if dy > 0 and not can_down:
						continue
					if _free(g, x, y + dy):
						_push(dist, buckets, ((o * wm + y + dy) * wm + x) * 3 + (M_GROUND if _hold(g, x, y + dy) or _supported(g, x, y + dy) else M_FALL), cost + 1)
			var jh := SPRING_JUMP if _on_spring(g, x, y) else JUMP
			_jump_edges(dist, buckets, wm, g, o, x, y, cost, jh, M_FALL)
			if can_rot:
				_rotate_edges(dist, buckets, wm, grids, o, x, y, cost, M_FALL, half)
		buckets[cost] = []
		cost += 1
	return best


## Depuração: guarda de onde veio cada estado (trace_path).
static var trace_on := false
static var _parent := {}
static var _cur := -1
static var _hit := {}
static var _wm := 0
static var _start_at: Array = []   # [giro, célula]: começar daí em vez da saída
static var rot_extra := 0           # o robô do mundo: girar custa mais (prefere andar quando dá)
static var ignore_exit := -1        # o robô do mundo: a saída por onde entrou


static func _push(dist: PackedInt32Array, buckets: Array, s: int, c: int) -> void:
	if c >= dist[s]:
		return
	dist[s] = c
	if trace_on:
		_parent[s] = _cur
	while buckets.size() <= c:
		buckets.append([])
	(buckets[c] as Array).append(s)


## O pulo: sobe até `jh`, andando 1 de lado por linha (o coelho corre 72 px/s também subindo), e
## mais 1 de lado no alto. A queda depois segue com a deriva de 1 a cada 2 linhas.
static func _jump_edges(dist: PackedInt32Array, buckets: Array, wm: int, g: Dictionary, o: int, x: int, y: int, cost: int, jh: int, mode: int) -> void:
	for d in [0, -1, 1]:
		var cx := x
		var cy := y
		for i in range(1, jh + 1):
			# na subida, o coelho anda ~2 tiles nos 3 de altura (72 px/s em ~0,25 s): de lado só depois
			# da primeira linha
			if d != 0 and i >= 2 and _free(g, cx + d, cy - 1) and _free(g, cx, cy - 1):
				cx += d
				cy -= 1
			elif _free(g, cx, cy - 1):
				cy -= 1
			else:
				break
			_push(dist, buckets, ((o * wm + cy) * wm + cx) * 3 + mode, cost + i + absi(cx - x))
		if d != 0 and _free(g, cx + d, cy):
			_push(dist, buckets, ((o * wm + cy) * wm + cx + d) * 3 + mode, cost + (y - cy) + absi(cx + d - x))


static func _rotate_edges(dist: PackedInt32Array, buckets: Array, wm: int, grids: Array, o: int, x: int, y: int, cost: int, mode: int, half: bool) -> void:
	var g: Dictionary = grids[o]
	for d in ([1, -1, 2] if half else [1, -1]):
		var p := Vector2i(x, y)
		var gw: int = g["w"]
		var gh: int = g["h"]
		var steps: int = 2 if d == 2 else 1
		var dd: int = 1 if d != -1 else -1
		for i in steps:
			p = _rot_body(p, gw, gh, dd)
			var t := gw
			gw = gh
			gh = t
		var no := posmod(o + (2 if d == 2 else d), 4)
		var g2: Dictionary = grids[no]
		if _free(g2, p.x, p.y):
			_push(dist, buckets, ((no * wm + p.y) * wm + p.x) * 3 + mode, cost + ROT_COST + rot_extra * (2 if mode == M_FALL2 else 1))


## O vão na altura do corpo é estreito (até NARROW tiles de largura)? Um corredor, não um salão.
const NARROW := 6


static func _narrow(g: Dictionary, x: int, y: int) -> bool:
	var row := y + 1
	var n := 2
	var l := x - 1
	while n <= NARROW and _k(g, l, row) != SOLID:
		n += 1
		l -= 1
	var r := x + 2
	while n <= NARROW and _k(g, r, row) != SOLID:
		n += 1
		r += 1
	return n <= NARROW


static func _k(g: Dictionary, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= int(g["w"]) or y >= int(g["h"]):
		return SOLID
	return (g["kind"] as PackedInt32Array)[y * int(g["w"]) + x]


static func _free(g: Dictionary, x: int, y: int) -> bool:
	for dy in 2:
		for dx in 2:
			var k := _k(g, x + dx, y + dy)
			if k == SOLID or k == DEADLY:
				return false
	return true


static func _deadly_below(g: Dictionary, x: int, y: int) -> bool:
	return _k(g, x, y + 2) == DEADLY or _k(g, x + 1, y + 2) == DEADLY


static func _supported(g: Dictionary, x: int, y: int) -> bool:
	for dx in 2:
		var k := _k(g, x + dx, y + 2)
		if k == SOLID or k == PASS:
			return true
	return false


static func _hold(g: Dictionary, x: int, y: int) -> bool:
	for dy in 2:
		for dx in 2:
			var k := _k(g, x + dx, y + dy)
			if k == CLIMB or k == WATER:
				return true
	return false


static func _climb(g: Dictionary, x: int, y: int) -> bool:
	for dy in 2:
		for dx in 2:
			if _k(g, x + dx, y + dy) == CLIMB:
				return true
	return false


static func _in_water(g: Dictionary, x: int, y: int) -> bool:
	for dy in 2:
		for dx in 2:
			if _k(g, x + dx, y + dy) == WATER:
				return true
	return false


static func _on_spring(g: Dictionary, x: int, y: int) -> bool:
	var sp: PackedByteArray = g["spring"]
	for dy in 3:
		for dx in 2:
			var xx := x + dx
			var yy := y + dy
			if xx >= 0 and yy >= 0 and xx < int(g["w"]) and yy < int(g["h"]) and sp[yy * int(g["w"]) + xx] != 0:
				return true
	return false


static func _exit_touch(g: Dictionary, x: int, y: int) -> int:
	for dy in 2:
		for dx in 2:
			var xx := x + dx
			var yy := y + dy
			if xx < 0 or yy < 0 or xx >= int(g["w"]) or yy >= int(g["h"]):
				continue
			var i := yy * int(g["w"]) + xx
			if (g["kind"] as PackedInt32Array)[i] == EXIT and (g["exit"] as PackedInt32Array)[i] >= 0:
				return (g["exit"] as PackedInt32Array)[i]
	return -1


static func _item_touch(g: Dictionary, x: int, y: int) -> int:
	var itg: PackedInt32Array = g["item"]
	for dy in 2:
		for dx in 2:
			var xx := x + dx
			var yy := y + dy
			if xx < 0 or yy < 0 or xx >= int(g["w"]) or yy >= int(g["h"]):
				continue
			var v := itg[yy * int(g["w"]) + xx]
			if v >= 0:
				return v
	return -1


## A regra do giro (D121): a lista dos pares (entrada, saída) que o giro deixa pular. Cada item:
## {"from", "to", "rot", "up", "dist"} (custos no modelo; up = INF: sem giro não passa).
static func flip_skips(def: Dictionary, abilities := {"A1": true, "A2": true}) -> Array:
	var with_rot := paths(def, abilities, {}, false, true)
	var no_rot := paths(def, abilities, {}, false, false)
	var exs := World.parse_exits(def.get("rows", []))
	var out: Array = []
	for i in with_rot:
		for j in with_rot[i]:
			if typeof(j) != TYPE_INT or int(j) == int(i):
				continue
			var c: int = with_rot[i][j]
			var u: int = no_rot.get(i, {}).get(j, INF)
			var a: Vector2 = Rect2(exs[i]["rect"]).get_center()
			var b: Vector2 = Rect2(exs[j]["rect"]).get_center()
			var dist := int(absf(a.x - b.x) + absf(a.y - b.y))
			if dist < SKIP_MIN_DIST:
				continue
			if float(c) < SKIP_RATIO * dist and float(c) < SKIP_VS_UP * u:
				out.append({"from": int(i), "to": int(j), "rot": c, "up": u, "dist": dist})
	return out


## A regra do giro numa sala do mundo: a de portais (D124) é a fase da campanha, do P à porta (só se a
## porta não é trancada: trancada, o enigma segura); as outras, saída a saída. [] se passa.
static func room_skips(def: Dictionary) -> Array:
	if def.has("flip_exempt"):
		return []
	if def.has("portal_p"):
		if not bool(def.get("door_open", false)):
			return []
		var ls := level_skip(def)
		if ls.is_empty():
			return []
		if int(ls["dist"]) >= SKIP_MIN_DIST and float(ls["rot"]) < SKIP_RATIO * float(ls["dist"]) and float(ls["rot"]) < SKIP_VS_UP * float(ls["up"]):
			return [{"from": "P", "to": "D", "rot": ls["rot"], "up": ls["up"], "dist": ls["dist"]}]
		return []
	return flip_skips(def)


## O mesmo para uma fase da campanha (sem saídas): do começo (P) à porta (D), com e sem giro.
static func level_skip(def: Dictionary, abilities := {"A1": true, "A2": true}) -> Dictionary:
	var rows: Array = def.get("rows", []).duplicate()
	# a porta vira uma "saída" de mentira: troca D por X só no modelo, e o começo vira a entrada
	var start := Vector2i(-1, -1)
	var door := Rect2i()
	var has_door := false
	for r in rows.size():
		var line := String(rows[r])
		for c in line.length():
			if line[c] == "P" and start.x < 0:
				start = Vector2i(c, r)
			elif line[c] == "D":
				door = Rect2i(c, r, 1, 1) if not has_door else door.merge(Rect2i(c, r, 1, 1))
				has_door = true
	if start.x < 0 or not has_door:
		return {}
	var m := model(def, abilities, {}, false)
	var w: int = m["w"]
	var kind: PackedInt32Array = m["kind"]
	var exo: PackedInt32Array = m["exit"]
	for y in range(door.position.y, door.end.y):
		for x in range(door.position.x, door.end.x):
			kind[y * w + x] = EXIT
			exo[y * w + x] = 0
	m["exits"] = [{"side": 3, "rect": Rect2i(start, Vector2i(2, 2))}]
	m["rose"] = true   # a porta vale em qualquer giro
	var grids := _rotations(m)
	# o começo: no canto do P
	var res := {}
	for rot in [true, false]:
		var d := _dijkstra_from(m, grids, start, abilities, rot)
		res["rot" if rot else "up"] = d.get(0, INF)
	var a := Vector2(start)
	var b := Rect2(door).get_center()
	res["dist"] = int(absf(a.x - b.x) + absf(a.y - b.y))
	return res


static func _dijkstra_from(m: Dictionary, grids: Array, p: Vector2i, ab: Dictionary, rot: bool) -> Dictionary:
	var ex: Array = m["exits"]
	var save: Dictionary = ex[0]
	# a entrada de mentira: o coelho já parado em p
	m["exits"] = [{"side": 9, "rect": Rect2i(p, Vector2i(2, 2))}]
	var d := _dijkstra(m, grids, 0, ab, rot)
	m["exits"] = [save]
	return d


# ---------------------------------------------------------------- progressão do mundo

static var _pcache := {}


## Anda pelo mundo como o jogador: do começo, sem nada, abre o que dá com o que tem (no modelo:
## comportas e saídas trancadas valem abertas, os chefes valem vencíveis), recolhe o que as salas
## dão e repete. {"waves": [{"rooms": n, "gains": [...]}], "reached": {id: onda}, "missing": [ids],
## "items": {"sala:i": onda}}.
static func progression(w: Dictionary) -> Dictionary:
	_pcache.clear()
	var ab := {}
	var it := {}
	var reached := {}
	var got := {}
	var waves: Array = []
	var start := str(w.get("start", ""))
	var se := int(w.get("start_exit", -1))
	var rose_at := {}   # rosa -> {giro: true} em que ela pode estar (onde o coelho a deixou)
	for wave in 20:
		var seen := {}
		var queue: Array = [[start, se]]
		var gains: Array = []
		while not queue.is_empty():
			var cur: Array = queue.pop_back()
			var id: String = cur[0]
			var e: int = cur[1]
			var key := "%s:%d" % [id, e]
			if seen.has(key):
				continue
			seen[key] = true
			if not reached.has(id):
				reached[id] = wave + 1
			var def := World.load_room_def(id)
			var res := _room_reach(id, def, e, ab, it)
			# sala de portais (D124): sair pela porta dá a recompensa da fase
			if def.has("reward") and res.has(int(def.get("portal_d", -1))):
				var rk := "%s:reward" % id
				if not got.has(rk):
					got[rk] = wave + 1
					for g in def["reward"]:
						gains.append([str(g), id])
			var il: Array = def.get("items", [])
			for k in res:
				if typeof(k) == TYPE_STRING and String(k).begins_with("i"):
					var idx := int(String(k).substr(1))
					var ik := "%s:%d" % [id, idx]
					if not got.has(ik) and idx < il.size():
						got[ik] = wave + 1
						gains.append([str(il[idx]["give"]), id])
				elif typeof(k) == TYPE_STRING and String(k).contains("@"):
					var parts := String(k).split("@")
					var j := int(parts[0])
					var o := int(parts[1])
					var rose: bool = World.info(id)["rose"]
					if o != 0 and not rose:
						continue
					if rose:
						if not rose_at.has(id):
							rose_at[id] = {0: true}
						rose_at[id][o] = true
					var to := World.link(w, id, j, o if rose else 0, {})
					if to.is_empty() and not rose:
						# a vizinha pode ser uma rosa: entra se ela estiver virada para cá
						var nb := _neighbor(w, id, j)
						if nb != "" and World.info(nb)["rose"]:
							for ro in rose_at.get(nb, {0: true}):
								to = World.link(w, id, j, 0, {nb: ro})
								if not to.is_empty():
									break
					if not to.is_empty():
						queue.append([str(to["room"]), int(to["exit"])])
		var new_any := false
		var names: Array = []
		for gk in gains:
			var g: String = gk[0]
			if ["A1", "A2", "A3", "A4", "A5", "A6", "A7"].has(g):
				if not ab.has(g):
					ab[g] = true
					new_any = true
			else:
				var before := int(it.get(g, 0))
				it[g] = before + 1
				if g in ["noz", "cracha", "lanterna", "chave1", "chave2", "chave3"] and before == 0:
					new_any = true
			names.append("%s (%s)" % [g, gk[1]])
		waves.append({"rooms": reached.size(), "gains": names, "abilities": ab.duplicate(), "items": it.duplicate()})
		if not new_any:
			break
	var missing: Array = []
	for r in World.rooms(w):
		var rid := str(r["id"])
		# o Campo do fim só abre depois do amortecedor-mor (a subida final): não conta
		if not reached.has(rid) and not bool(World.load_room_def(rid).get("ending", false)):
			missing.append(rid)
	return {"waves": waves, "reached": reached, "missing": missing, "items": got, "abilities": ab, "inventory": it}


static func _neighbor(w: Dictionary, id: String, j: int) -> String:
	var me := World.exit_world(w, id, j, 0)
	if me.is_empty():
		return ""
	var outside: Rect2i = me["rect"]
	outside.position += World.SIDES[int(me["side"])]
	return World.room_at_cell(w, outside.position)


static func _room_reach(id: String, def: Dictionary, e: int, ab: Dictionary, it: Dictionary) -> Dictionary:
	var needs := []
	for b in def.get("barriers", []):
		needs.append(str(b.get("need", "")))
	var ik := ""
	for n in needs:
		ik += n + ("1" if has_need(n, ab, it, true) else "0")
	var abk := ""
	for a in ["A1", "A2", "A3", "A4", "A5", "A6", "A7"]:
		if ab.has(a):
			abk += a
	var key := "%s:%d:%s:%s" % [id, e, abk, ik]
	if _pcache.has(key):
		return _pcache[key]
	var m := model(def, ab, it, true)
	var grids := _rotations(m)
	var res := {}
	if e >= 0 and e < (m["exits"] as Array).size():
		res = _dijkstra(m, grids, e, ab, bool(def.get("rotate", true)))
	if bool(def.get("puzzle", false)):
		# sala de enigma (caixas, comportas): o modelo não empilha caixas; resolvida, dá em todas as
		# saídas e itens que nenhuma barreira fechada guarda
		var exs: Array = m["exits"]
		var eo: Array = []
		for v in def.get("entry_only", []):
			eo.append(int(v))
		for j in exs.size():
			if eo.has(j) or _behind_barrier(def, Rect2i(exs[j]["rect"]), ab, it):
				continue
			if not res.has(j):
				res[j] = 0
				res["%d@0" % j] = 0
		var il: Array = def.get("items", [])
		for i in il.size():
			var a: Array = il[i]["rect"]
			if not _behind_barrier(def, Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3])), ab, it):
				res["i%d" % i] = 0
	_pcache[key] = res
	return res


static func _behind_barrier(def: Dictionary, r: Rect2i, ab: Dictionary, it: Dictionary) -> bool:
	for b in def.get("barriers", []):
		if has_need(str(b.get("need", "")), ab, it, true):
			continue
		var a: Array = b["rect"]
		if Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3])).grow(3).intersects(r):
			return true
	return false


## O caminho do modelo da saída `entry` até `target` (índice da saída ou "iN"): [[giro, x, y, modo]].
static func trace_path(def: Dictionary, ab: Dictionary, entry: int, target, reach := true) -> Array:
	trace_on = true
	_parent.clear()
	_hit.clear()
	var m := model(def, ab, def.get("_items", {}), reach)
	var grids := _rotations(m)
	_dijkstra(m, grids, entry, ab, bool(def.get("rotate", true)))
	trace_on = false
	var out: Array = []
	if not _hit.has(target):
		return out
	var st: int = _hit[target]
	while st >= 0:
		var mode := st % 3
		var cell := st / 3
		out.push_front([cell / (_wm * _wm), cell % _wm, (cell / _wm) % _wm, mode])
		st = int(_parent.get(st, -1))
	return out


## O caminho do modelo a partir da célula `p` (canto do 2x2) com a sala girada `o`, até `target`.
static func trace_from(def: Dictionary, ab: Dictionary, p: Vector2i, o: int, target, reach := true) -> Array:
	_start_at = [o, p]
	var out := trace_path(def, ab, 0, target, reach)
	_start_at = []
	return out

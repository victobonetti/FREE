extends RefCounted
## O mundo (metroidvania, D100 e D120): salas ligadas pelas saídas na parede, num mapa contínuo.
##
##   levels/world/mundo.json        {"version": 2, "start": id, "rooms": [{"id": id, "pos": [x, y]}, ...]}
##   levels/world/rooms/<id>.json   a sala, no formato de fase de sempre (editável no editor)
##
## `pos` é o canto de cima à esquerda da sala no mundo, **em tiles**. Uma saída (um trecho contínuo
## de células X ou Z numa borda da sala) leva à sala que encosta do outro lado daquelas células, e
## entra pela saída dela que fica de frente. Assim uma sala pode ter várias saídas por lado, e salas de
## tamanhos diferentes se encaixam como no mapa.
##
## A sala comum só deixa sair de pé (girada, a saída levaria para o lugar errado). A **rosa** (campo
## "rose" da sala; sala quadrada) é a exceção: girada, a abertura dela aponta para outro lado do mundo
## e leva à sala que estiver ali (D119). O giro em que a rosa ficou é guardado no progresso.
##
## Lados: 0 cima, 1 direita, 2 baixo, 3 esquerda.

const LevelData := preload("res://scripts/level_data.gd")
const LevelStore := preload("res://scripts/level_store.gd")

const SIDES := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const SIDE_NAMES := ["cima", "direita", "baixo", "esquerda"]
## Uma tela do jogo, em tiles (a casa do mapa).
const UNIT := Vector2i(40, 22)

## Pasta do mundo (os testes podem trocar).
static var dir := "res://levels/world"
static var _cache := {}   # id -> {"size": Vector2i, "exits": Array, "rose": bool, "name": String, "theme": String}


static func world_path() -> String:
	return dir + "/mundo.json"


static func room_path(id: String) -> String:
	return dir + "/rooms/%s.json" % id


static func load_world() -> Dictionary:
	_cache.clear()
	if not FileAccess.file_exists(world_path()):
		return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(world_path()))
	return v if typeof(v) == TYPE_DICTIONARY else {}


static func save_world(w: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(dir + "/rooms")
	var f := FileAccess.open(world_path(), FileAccess.WRITE)
	if f == null:
		return false
	w["version"] = 2
	f.store_string(JSON.stringify(w, "\t") + "\n")
	f.close()
	return true


static func rooms(w: Dictionary) -> Array:
	return w.get("rooms", [])


static func has_room(w: Dictionary, id: String) -> bool:
	for r in rooms(w):
		if str(r["id"]) == id:
			return true
	return false


## O canto da sala no mundo, em tiles.
static func pos_of(w: Dictionary, id: String) -> Vector2i:
	for r in rooms(w):
		if str(r["id"]) == id:
			return Vector2i(int(r["pos"][0]), int(r["pos"][1]))
	return Vector2i(-99999, -99999)


static func set_pos(w: Dictionary, id: String, p: Vector2i) -> void:
	for r in rooms(w):
		if str(r["id"]) == id:
			r["pos"] = [p.x, p.y]


## O retângulo da sala no mundo, em tiles.
static func rect_of(w: Dictionary, id: String) -> Rect2i:
	return Rect2i(pos_of(w, id), info(id)["size"])


## A sala que ocupa a célula `cell` do mundo ("" se nenhuma).
static func room_at_cell(w: Dictionary, cell: Vector2i) -> String:
	for r in rooms(w):
		var id := str(r["id"])
		if rect_of(w, id).has_point(cell):
			return id
	return ""


## A sala como o jogo a lê (def), ou {} se não existe.
static func load_room_def(id: String) -> Dictionary:
	var d := load_room_data(id)
	return d.to_def() if d != null else {}


static func load_room_data(id: String) -> RefCounted:
	if not FileAccess.file_exists(room_path(id)):
		return null
	return LevelData.from_json(FileAccess.get_file_as_string(room_path(id)))


static func save_room(id: String, data: RefCounted) -> bool:
	DirAccess.make_dir_recursive_absolute(dir + "/rooms")
	var f := FileAccess.open(room_path(id), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(data.to_json() + "\n")
	f.close()
	_cache.erase(id)
	return true


static func forget(id: String) -> void:
	_cache.erase(id)


## Tamanho, saídas e se é rosa (com cache).
static func info(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var out := {"size": Vector2i(1, 1), "exits": [], "rose": false, "name": id, "theme": ""}
	var d := load_room_data(id)
	if d != null:
		var w := 0
		for r in d.rows:
			w = maxi(w, String(r).length())
		out["size"] = Vector2i(w, d.rows.size())
		out["exits"] = parse_exits(d.rows)
		out["rose"] = bool(d.extra.get("rose", false))
		out["name"] = d.name
		out["theme"] = str(d.extra.get("theme", ""))
	_cache[id] = out
	return out


## As saídas de uma sala, como desenhada: cada trecho contínuo de X ou Z numa borda (fora dos cantos)
## é uma saída. A ordem (o índice) é a mesma que a sala usa (room.gd): por lado (cima, direita, baixo,
## esquerda) e, em cada lado, ao longo dele. {"side", "rect": Rect2i em tiles, "locked"}.
static func parse_exits(rows: Array) -> Array:
	var h := rows.size()
	var w := 0
	for r in rows:
		w = maxi(w, String(r).length())
	var cells := [[], [], [], []]   # por lado: [posição ao longo, Vector2i, trancada]
	for r in h:
		var line := String(rows[r])
		for c in line.length():
			var g := line[c]
			if g != "X" and g != "Z":
				continue
			var side := -1
			if r == 0:
				side = 0
			elif r == h - 1:
				side = 2
			elif c == 0:
				side = 3
			elif c == w - 1:
				side = 1
			if side < 0:
				continue
			var along := c if side == 0 or side == 2 else r
			cells[side].append([along, Vector2i(c, r), g == "Z"])
	var out: Array = []
	for side in 4:
		var list: Array = cells[side]
		list.sort_custom(func(a, b): return a[0] < b[0])
		var run: Array = []
		for k in list.size() + 1:
			var brk: bool = k == list.size() or (not run.is_empty() and list[k][0] != run[-1][0] + 1)
			if brk and not run.is_empty():
				var rect := Rect2i(run[0][1], Vector2i.ONE)
				var locked := false
				for e in run:
					rect = rect.merge(Rect2i(e[1], Vector2i.ONE))
					locked = locked or e[2]
				out.append({"side": side, "rect": rect, "locked": locked})
				run = []
			if k < list.size():
				run.append(list[k])
	return out


## Gira um retângulo de tiles de uma sala quadrada de lado `n` por `o` quartos de volta (horário),
## como a sala gira (room.gd: _rot_point com dir > 0).
static func rot_rect(r: Rect2i, n: int, o: int) -> Rect2i:
	var out := r
	for i in posmod(o, 4):
		# (c, l) -> (n - 1 - l, c)
		out = Rect2i(Vector2i(n - out.end.y, out.position.x), Vector2i(out.size.y, out.size.x))
	return out


## A saída `idx` da sala `id` com a sala girada `o` vezes: o lado e as células, no mundo.
static func exit_world(w: Dictionary, id: String, idx: int, o := 0) -> Dictionary:
	var inf := info(id)
	var exs: Array = inf["exits"]
	if idx < 0 or idx >= exs.size():
		return {}
	var ex: Dictionary = exs[idx]
	var r: Rect2i = ex["rect"]
	var side: int = ex["side"]
	if o != 0:
		var n: int = inf["size"].x
		r = rot_rect(r, n, o)
		side = posmod(side + o, 4)
	return {"side": side, "rect": Rect2i(r.position + pos_of(w, id), r.size), "locked": ex["locked"]}


## Para onde leva a saída `idx` da sala `id` (girada `o` vezes; só a rosa sai girada). `roses` diz o
## giro de cada rosa (id -> o). {"room": id, "exit": índice} ou {} (a saída dá na rocha).
static func link(w: Dictionary, id: String, idx: int, o := 0, roses := {}) -> Dictionary:
	var me := exit_world(w, id, idx, o)
	if me.is_empty():
		return {}
	var side: int = me["side"]
	var outside: Rect2i = me["rect"]
	outside.position += SIDES[side]
	var nb := room_at_cell(w, outside.position)
	if nb == "" or nb == id:
		return {}
	var back := (side + 2) % 4
	var nb_o := int(roses.get(nb, 0)) if info(nb)["rose"] else 0
	var exs: Array = info(nb)["exits"]
	for k in exs.size():
		var them := exit_world(w, nb, k, nb_o)
		if int(them["side"]) == back and Rect2i(them["rect"]).intersects(outside):
			return {"room": nb, "exit": k}
	return {}


## Os giros (0..3) em que a saída `idx` da rosa `id` leva a algum lugar.
static func rose_links(w: Dictionary, id: String, idx: int, roses := {}) -> Array:
	var out: Array = []
	for o in 4:
		if not link(w, id, idx, o, roses).is_empty():
			out.append(o)
	return out


## Os lados (como desenhados) que têm saída (o editor e o mapinho usam).
static func exit_sides(rows: Array) -> Array:
	var out: Array = []
	for ex in parse_exits(rows):
		if not out.has(ex["side"]):
			out.append(ex["side"])
	return out


## Um id livre para uma sala nova do mundo, a partir do nome.
static func free_id(w: Dictionary, name: String) -> String:
	var base := LevelStore.slug(name if name.strip_edges() != "" else "sala")
	var id := base
	var n := 2
	while has_room(w, id) or FileAccess.file_exists(room_path(id)):
		id = "%s-%d" % [base, n]
		n += 1
	return id


## Problemas do mapa: salas sobrepostas, saída que não leva a nada, ou que leva a uma sala sem a
## saída de volta. A rosa é conferida de pé (girada, a abertura pode dar na rocha de propósito).
static func problems(w: Dictionary) -> Array:
	var out: Array = []
	var ids: Array = []
	for r in rooms(w):
		var id := str(r["id"])
		if load_room_data(id) == null:
			out.append("%s: o arquivo da sala não existe" % id)
			continue
		ids.append(id)
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if rect_of(w, ids[i]).intersects(rect_of(w, ids[j])):
				out.append("%s e %s se sobrepõem no mapa" % [ids[i], ids[j]])
	for id in ids:
		var exs: Array = info(id)["exits"]
		var rose: bool = info(id)["rose"]
		for k in exs.size():
			if rose:
				if rose_links(w, id, k).is_empty():
					out.append("%s: a abertura da rosa não leva a nenhuma sala em nenhum giro" % id)
				continue
			# a vizinha pode ser uma rosa: vale se algum giro dela encaixa
			var to := {}
			var used := {}
			var outside: Rect2i = exit_world(w, id, k)["rect"]
			outside.position += SIDES[exs[k]["side"]]
			var nb := room_at_cell(w, outside.position)
			for o in (4 if nb != "" and info(nb)["rose"] else 1):
				used = {nb: o}
				to = link(w, id, k, 0, used)
				if not to.is_empty():
					break
			if to.is_empty():
				out.append("%s: a saída %d (%s) não leva a nenhuma sala" % [id, k, SIDE_NAMES[exs[k]["side"]]])
				continue
			var back := link(w, str(to["room"]), int(to["exit"]), int(used.get(nb, 0)))
			if back.is_empty() or str(back["room"]) != id:
				out.append("%s → %s: a sala vizinha não tem a saída de volta" % [id, to["room"]])
	return out

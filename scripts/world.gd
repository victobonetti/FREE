extends RefCounted
## O mundo (modo metroidvania, teste, D100): salas ligadas pelas saídas na parede, num mapa em grade.
##
##   levels/world/mundo.json        {"start": id, "rooms": [{"id": id, "pos": [coluna, linha]}, ...]}
##   levels/world/rooms/<id>.json   a sala, no formato de fase de sempre (editável no editor)
##
## Uma saída no lado L de uma sala (como ela foi desenhada) leva à sala da casa vizinha desse lado
## no mapa, entrando pela saída do lado oposto. Lados: 0 cima, 1 direita, 2 baixo, 3 esquerda.
## O editor (janela "Mundo") posiciona as salas, abre, salva e define o início.

const LevelData := preload("res://scripts/level_data.gd")
const LevelStore := preload("res://scripts/level_store.gd")

const SIDES := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const SIDE_NAMES := ["cima", "direita", "baixo", "esquerda"]

## Pasta do mundo (os testes podem trocar).
static var dir := "res://levels/world"


static func world_path() -> String:
	return dir + "/mundo.json"


static func room_path(id: String) -> String:
	return dir + "/rooms/%s.json" % id


static func load_world() -> Dictionary:
	if not FileAccess.file_exists(world_path()):
		return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(world_path()))
	return v if typeof(v) == TYPE_DICTIONARY else {}


static func save_world(w: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(dir + "/rooms")
	var f := FileAccess.open(world_path(), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(w, "\t") + "\n")
	f.close()
	return true


static func rooms(w: Dictionary) -> Array:
	return w.get("rooms", [])


static func pos_of(w: Dictionary, id: String) -> Vector2i:
	for r in rooms(w):
		if str(r["id"]) == id:
			return Vector2i(int(r["pos"][0]), int(r["pos"][1]))
	return Vector2i(-9999, -9999)


static func room_at(w: Dictionary, p: Vector2i) -> String:
	for r in rooms(w):
		if int(r["pos"][0]) == p.x and int(r["pos"][1]) == p.y:
			return str(r["id"])
	return ""


static func neighbor(w: Dictionary, id: String, side: int) -> String:
	return room_at(w, pos_of(w, id) + SIDES[side])


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
	return true


## Os lados (como desenhados) que têm saída, a partir das linhas da sala.
static func exit_sides(rows: Array) -> Array:
	var out: Array = []
	var h := rows.size()
	if h == 0:
		return out
	var w := 0
	for r in rows:
		w = maxi(w, String(r).length())
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
			if side >= 0 and not out.has(side):
				out.append(side)
	return out


## Um id livre para uma sala nova do mundo, a partir do nome.
static func free_id(w: Dictionary, name: String) -> String:
	var base := LevelStore.slug(name if name.strip_edges() != "" else "sala")
	var id := base
	var n := 2
	while pos_of(w, id).x != -9999 or FileAccess.file_exists(room_path(id)):
		id = "%s-%d" % [base, n]
		n += 1
	return id


## Problemas do mapa: saída sem sala vizinha, ou vizinha sem a saída de volta.
static func problems(w: Dictionary) -> Array:
	var out: Array = []
	for r in rooms(w):
		var id := str(r["id"])
		var d := load_room_data(id)
		if d == null:
			out.append("%s: o arquivo da sala não existe" % id)
			continue
		for side in exit_sides(d.rows):
			var nb := neighbor(w, id, side)
			if nb == "":
				out.append("%s: a saída da %s não leva a nenhuma sala" % [id, SIDE_NAMES[side]])
			else:
				var nd := load_room_data(nb)
				if nd != null and not exit_sides(nd.rows).has((side + 2) % 4):
					out.append("%s → %s: a sala vizinha não tem saída do lado de volta (%s)" % [id, nb, SIDE_NAMES[(side + 2) % 4]])
	return out

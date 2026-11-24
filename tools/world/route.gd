extends RefCounted
## O caminho do jogo (D124): os trechos de sala nova que o robô do mundo atravessa, na ordem, com as
## habilidades de cada ponto. Cada trecho: [sala, de onde entra (vizinha, ou "start"), [alvos], habilidades,
## itens]. Alvo: a vizinha para onde sai, ou "item:N" (o item N da sala). As fases da campanha (portais)
## são provadas pelas provas delas (teste do mundo).

const World := preload("res://scripts/world.gd")

const A0 := ""
const A1 := "A1"
const A12 := "A1 A2"
const A123 := "A1 A2 A3"
const A1234 := "A1 A2 A3 A4"
const A12345 := "A1 A2 A3 A4 A5"
const A6 := "A1 A2 A3 A4 A5 A6"
const A7 := "A1 A2 A3 A4 A5 A6 A7"

const SEGMENTS := [
	# as Raízes
	["P1", "start", ["r1"], A0],
	["r4", "r3", ["item:0", "c1"], A1],
	["c5", "c1", ["item:0", "rA"], A12],
	["c5", "c1", ["c7"], A12],
	# a rosa das raízes: de pé (da Ninho) para o Derrame (180°) e os Espinhos (270°)
	["rA", "c5", ["c2"], A12],
	["rA", "c5", ["c6"], A12],
	# Prumo: do Ninho à Vertigem e à rosa funda (giro no ar)
	["c7", "c5", ["c8"], A12],
	["c7", "c5", ["rB"], A12],
	# a rosa funda: para a Represa (180°) e a Água (270°)
	["rB", "c7", ["a3"], A12],
	["rB", "c7", ["a1"], A12],
	["a6", "a2", ["a7"], A123],
	["d1", "a5", ["d2"], A123],
	["P2", "d3", ["t1"], A1234, {"noz": 1}],
	["t1", "P2", ["f1"], A1234],
	["f1", "t1", ["f2"], A1234],
	["f8", "f6", ["f7"], A12345],
	["f7", "f8", ["f9"], A12345],
	["f4", "f9", ["f1"], A12345],
	["f1", "f4", ["fa"], A12345],
	["fa", "f1", ["fb"], A12345, {"cracha": 1}],
	["fp", "fc", ["fe"], A6],
	["fe", "fp", ["g1"], A6],
	["g1", "fe", ["g2"], A6],
	["g7", "g5", ["g4"], A6],
	["g6", "g4", ["g8"], A12345],
	["P4", "g9", ["L1"], A7, {"chave1": 1, "chave2": 1, "chave3": 1}],
	["L1", "P4", ["L2"], A7],
	["L6", "L5", ["L7"], A7],
]


static func name_of(seg: Array) -> String:
	return "%s %s→%s" % [seg[0], seg[1], ",".join(seg[2])]


static func fixture(seg: Array) -> String:
	return "res://tests/fixtures/world/walk-%s-%s-%s.json" % [seg[0], seg[1], "-".join(seg[2]).replace(":", "")]


static func abilities(s: String) -> Dictionary:
	var out := {}
	for a in s.split(" ", false):
		out[a] = true
	return out


## O índice da saída da sala `id` que leva à vizinha `nb` ("start": a do começo do mundo).
static func exit_index(w: Dictionary, id: String, nb: String) -> int:
	if nb == "start":
		return int(w.get("start_exit", -1))
	var exs: Array = World.info(id)["exits"]
	for k in exs.size():
		for o in 4:
			var to := World.link(w, id, k, o, {})
			if not to.is_empty() and str(to["room"]) == nb:
				return k
			if not World.info(id)["rose"]:
				break
		# a vizinha pode ser uma rosa: vale qualquer giro dela
		var me := World.exit_world(w, id, k, 0)
		var outside: Rect2i = me["rect"]
		outside.position += World.SIDES[int(me["side"])]
		if World.room_at_cell(w, outside.position) == nb:
			return k
	return -1


## O alvo como o modelo entende: o índice da saída, ou "iN" (o item N).
static func target(w: Dictionary, id: String, t: String):
	if t.begins_with("item:"):
		return "i" + t.substr(5)
	if World.info(id)["rose"]:
		# a rosa: a abertura (0) no giro em que ela dá na vizinha
		for o in 4:
			var to := World.link(w, id, 0, o, {})
			if not to.is_empty() and str(to["room"]) == t:
				return "0@%d" % o
	return exit_index(w, id, t)


## A sala como o jogo monta (main.world_def), resolvida (as saídas trancadas abertas).
static func world_def(w: Dictionary, id: String, entry: int, ab: Dictionary, items: Dictionary) -> Dictionary:
	var d: Dictionary = World.load_room_def(id)
	d["_entry_exit"] = entry
	d["_entry_vel"] = Vector2(0, 40)
	d["_abilities"] = ab.duplicate()
	d["_items"] = items.duplicate()
	d["_world"] = true
	d["_solved"] = true
	if World.info(id)["rose"]:
		var open := {}
		for g in 4:
			open[g] = []
			for k in (World.info(id)["exits"] as Array).size():
				if not World.link(w, id, k, g).is_empty():
					open[g].append(k)
		d["_rose_open"] = open
	return d

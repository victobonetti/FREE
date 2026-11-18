extends RefCounted
## Os objetos de uma fase que não são glifos da grade: placas de espinhos, conectores, chapas
## soltas, botões, esteiras, molas, ventiladores e jatos de vapor. Cada tipo é uma lista em
## `LevelData.extra` (a mesma que `room.gd` lê). Este arquivo diz, para o editor, quais campos cada
## tipo tem, como criar um novo e como acompanhar a sala quando ela gira, espelha ou muda de tamanho.
##
## Retângulos são [coluna, linha, largura, altura] em tiles (a esteira, a mola e o botão aceitam
## também [coluna, linha, largura], de altura 1; ao girar a sala viram de 4 números).

const DIRS := [{"v": 0, "t": "para cima"}, {"v": 1, "t": "para a direita"}, {"v": 2, "t": "para baixo"}, {"v": 3, "t": "para a esquerda"}]

## chave -> {label, cor, scalar (o item é o próprio retângulo), fields, rects, dirs}
## Campo: {key, label, kind: "rect" | "pt" | "int" | "float" | "choice", ...}
const TYPES := {
	"crushers": {
		"label": "Placa de espinhos", "color": Color("e0657c"),
		"fields": [
			{"key": "rect", "label": "Faixa que ela varre", "kind": "rect"},
			{"key": "dir", "label": "Avança", "kind": "choice", "opts": DIRS, "def": 0},
			{"key": "speed", "label": "Velocidade (px/s)", "kind": "float", "min": 1.0, "max": 80.0, "step": 0.5, "def": 9.0},
			{"key": "delay", "label": "Atraso (s; -1 = espera um ator)", "kind": "float", "min": -1.0, "max": 60.0, "step": 0.1, "def": 0.0},
			{"key": "start", "label": "Já avançou (px)", "kind": "float", "min": 0.0, "max": 4000.0, "step": 1.0, "def": 0.0},
			{"key": "leash", "label": "Guia (px; 0 = desligada)", "kind": "float", "min": 0.0, "max": 400.0, "step": 1.0, "def": 0.0},
			{"key": "face", "label": "Carinha", "kind": "choice", "opts": [{"v": "happy", "t": "feliz"}, {"v": "sad", "t": "triste"}], "def": "happy"},
		],
		"rects": ["rect"], "dirs": ["dir"],
	},
	"movers": {
		"label": "Conector (peça móvel)", "color": Color("4fd8d0"),
		"fields": [
			{"key": "off", "label": "Encaixe de desligado", "kind": "rect"},
			{"key": "on", "label": "Encaixe de ligado (canto)", "kind": "pt"},
			{"key": "ch", "label": "Canal (cor)", "kind": "int", "min": 0, "max": 7, "def": 0},
			{"key": "speed", "label": "Velocidade (px/s)", "kind": "float", "min": 5.0, "max": 400.0, "step": 5.0, "def": 40.0},
			{"key": "cycle", "label": "Ciclo (s por meio ciclo; 0 = não)", "kind": "float", "min": 0.0, "max": 30.0, "step": 0.25, "def": 0.0},
			{"key": "phase", "label": "Defasagem do ciclo (s)", "kind": "float", "min": 0.0, "max": 30.0, "step": 0.25, "def": 0.0},
			{"key": "bat", "label": "Liga com N baterias (0 = não)", "kind": "int", "min": 0, "max": 3, "def": 0},
			{"key": "delay", "label": "Atraso depois do gatilho (s)", "kind": "float", "min": 0.0, "max": 10.0, "step": 0.25, "def": 0.0},
			{"key": "launch", "label": "Catapulta (px/s; 0 = não)", "kind": "float", "min": 0.0, "max": 500.0, "step": 10.0, "def": 0.0},
			{"key": "spikes", "label": "Espinhos", "kind": "choice", "opts": [{"v": -1, "t": "nenhum"}, {"v": 0, "t": "em cima"}, {"v": 1, "t": "à direita"}, {"v": 2, "t": "embaixo"}, {"v": 3, "t": "à esquerda"}], "def": -1},
		],
		"rects": ["off"], "pts": ["on"], "dirs": [], "spike_dirs": ["spikes"],
	},
	"crumbles": {
		"label": "Chapa solta", "color": Color("b9805a"), "scalar": true,
		"fields": [{"key": "rect", "label": "Área", "kind": "rect"}],
		"rects": ["rect"], "dirs": [],
	},
	"plates": {
		"label": "Botão de pressão", "color": Color("8fd16a"),
		"fields": [
			{"key": "rect", "label": "Área", "kind": "rect"},
			{"key": "ch", "label": "Canal (cor)", "kind": "int", "min": 0, "max": 7, "def": 0},
			{"key": "mode", "label": "Modo", "kind": "choice", "opts": [{"v": "hold", "t": "só enquanto apertado"}, {"v": "once", "t": "liga e fica"}, {"v": "timed", "t": "liga por um tempo (pode chamar de novo)"}], "def": "hold"},
			{"key": "time", "label": "Tempo ligado, no modo por tempo (s)", "kind": "float", "min": 0.5, "max": 30.0, "step": 0.5, "def": 4.0},
		],
		"rects": ["rect"], "dirs": [],
	},
	"conveyors": {
		"label": "Esteira", "color": Color("f0a05a"),
		"fields": [
			{"key": "rect", "label": "Área (sobre parede)", "kind": "rect"},
			{"key": "dir", "label": "Sentido", "kind": "choice", "opts": DIRS, "def": 1},
			{"key": "speed", "label": "Velocidade (px/s)", "kind": "float", "min": 5.0, "max": 120.0, "step": 5.0, "def": 40.0},
			{"key": "ch", "label": "Canal que inverte (-1 = nenhum)", "kind": "int", "min": -1, "max": 7, "def": -1},
			{"key": "cycle", "label": "Inverte sozinha a cada (s; 0 = não)", "kind": "float", "min": 0.0, "max": 30.0, "step": 0.25, "def": 0.0},
		],
		"rects": ["rect"], "dirs": ["dir"],
	},
	"springs": {
		"label": "Mola", "color": Color("f0b428"),
		"fields": [
			{"key": "rect", "label": "Área (sobre o chão)", "kind": "rect"},
			{"key": "power", "label": "Força (px/s)", "kind": "float", "min": 100.0, "max": 500.0, "step": 10.0, "def": 280.0},
			{"key": "dir", "label": "Lança", "kind": "choice", "opts": DIRS, "def": 0},
		],
		"rects": ["rect"], "dirs": ["dir"],
	},
	"fans": {
		"label": "Ventilador (corrente de ar)", "color": Color("9fd4ff"),
		"fields": [
			{"key": "rect", "label": "Coluna de ar", "kind": "rect"},
			{"key": "dir", "label": "Sopra", "kind": "choice", "opts": DIRS, "def": 0},
			{"key": "accel", "label": "Força (px/s²)", "kind": "float", "min": 300.0, "max": 3000.0, "step": 50.0, "def": 1500.0},
			{"key": "cap", "label": "Velocidade máxima (px/s)", "kind": "float", "min": 20.0, "max": 200.0, "step": 5.0, "def": 70.0},
		],
		"rects": ["rect"], "dirs": ["dir"],
	},
	"bouncers": {
		"label": "Cogumelo-mola", "color": Color("c99be8"),
		"fields": [
			{"key": "rect", "label": "Área (sobre a face onde nasce)", "kind": "rect"},
			{"key": "power", "label": "Força (px/s)", "kind": "float", "min": 100.0, "max": 700.0, "step": 10.0, "def": 300.0},
			{"key": "dir", "label": "Lança", "kind": "choice", "opts": DIRS, "def": 0},
		],
		"rects": ["rect"], "dirs": ["dir"],
	},
	"puffs": {
		"label": "Bufa-esporos (solta nuvens que caem e ferem)", "color": Color("b9a3cf"),
		"fields": [
			{"key": "rect", "label": "Cogumelo", "kind": "rect"},
			{"key": "period", "label": "Solta uma nuvem a cada (s)", "kind": "float", "min": 0.5, "max": 30.0, "step": 0.25, "def": 3.0},
			{"key": "phase", "label": "Defasagem (s)", "kind": "float", "min": 0.0, "max": 30.0, "step": 0.25, "def": 0.0},
		],
		"rects": ["rect"], "dirs": [],
	},
	"wilts": {
		"label": "Cogumelo murcho (murcha ao pisar, rebrota)", "color": Color("8e72b0"),
		"fields": [
			{"key": "rect", "label": "Chapéu (plataforma)", "kind": "rect"},
			{"key": "regrow", "label": "Rebrota depois de (s)", "kind": "float", "min": 0.5, "max": 30.0, "step": 0.25, "def": 2.5},
		],
		"rects": ["rect"], "dirs": [],
	},
	"sprouts": {
		"label": "Broto (cogumelo que cresce)", "color": Color("b98ee0"),
		"fields": [
			{"key": "rect", "label": "Chapéu recolhido (2x2, rente à face onde nasce)", "kind": "rect"},
			{"key": "dir", "label": "Cresce", "kind": "choice", "opts": DIRS, "def": 0},
			{"key": "len", "label": "Altura máxima (tiles)", "kind": "int", "min": 1, "max": 30, "def": 5},
			{"key": "speed", "label": "Crescendo (px/s)", "kind": "float", "min": 5.0, "max": 200.0, "step": 5.0, "def": 40.0},
			{"key": "back", "label": "Recolhendo (px/s)", "kind": "float", "min": 5.0, "max": 200.0, "step": 5.0, "def": 16.0},
			{"key": "launch", "label": "Catapulta (px/s; 0 = não)", "kind": "float", "min": 0.0, "max": 700.0, "step": 10.0, "def": 0.0},
		],
		"rects": ["rect"], "dirs": ["dir"],
	},
	"vents": {
		"label": "Jato de vapor", "color": Color("e9e4d6"),
		"fields": [
			{"key": "rect", "label": "Coluna do jato", "kind": "rect"},
			{"key": "dir", "label": "Sopra", "kind": "choice", "opts": DIRS, "def": 0},
			{"key": "period", "label": "Período (s)", "kind": "float", "min": 0.5, "max": 30.0, "step": 0.25, "def": 3.0},
			{"key": "on", "label": "Aberto por (s, no fim do período)", "kind": "float", "min": 0.1, "max": 30.0, "step": 0.1, "def": 1.0},
			{"key": "phase", "label": "Defasagem (s)", "kind": "float", "min": 0.0, "max": 30.0, "step": 0.25, "def": 0.0},
		],
		"rects": ["rect"], "dirs": ["dir"],
	},
}

## A ordem em que os tipos aparecem na interface.
const ORDER := ["crushers", "movers", "plates", "crumbles", "conveyors", "springs", "fans", "vents", "sprouts", "bouncers", "wilts", "puffs"]


static func label(kind: String) -> String:
	return TYPES[kind]["label"]


static func is_scalar(kind: String) -> bool:
	return TYPES[kind].get("scalar", false)


## Um objeto novo do tipo `kind`, com o canto em (c, r) e os valores padrão.
static func make_default(kind: String, c: int, r: int) -> Variant:
	var t: Dictionary = TYPES[kind]
	var rect: Array
	match kind:
		"crushers":
			rect = [1, 1, 8, 8]
		"movers":
			rect = [c, r, 3, 1]
		"crumbles":
			rect = [c, r, 3, 1]
		"plates":
			rect = [c, r, 2, 1]
		"conveyors":
			rect = [c, r, 6, 1]
		"springs":
			rect = [c, r, 2, 1]
		"fans":
			rect = [c, r, 3, 8]
		"sprouts":
			rect = [c, r, 2, 2]
		"bouncers":
			rect = [c, r, 2, 1]
		"wilts":
			rect = [c, r, 3, 1]
		"puffs":
			rect = [c, r, 2, 2]
		_:
			rect = [c, r, 2, 6]
	if t.get("scalar", false):
		return rect
	var o := {}
	for f in t["fields"]:
		match f["kind"]:
			"rect":
				o[f["key"]] = rect.duplicate()
			"pt":
				o[f["key"]] = [c, maxi(r - 4, 1)]
			_:
				o[f["key"]] = f["def"]
	# só o que o jogo precisa; o resto vem dos padrões dele
	if kind == "crushers":
		o["delay"] = 0.0
	return o


## O retângulo de um objeto (ou [] se não tem).
static func rect_of(kind: String, o: Variant) -> Array:
	var v: Variant = o if is_scalar(kind) else (o as Dictionary).get(TYPES[kind]["rects"][0], [])
	if v is Array and v.size() >= 3:
		return [int(v[0]), int(v[1]), int(v[2]), int(v[3]) if v.size() > 3 else 1]
	return []


static func set_rect(kind: String, o: Variant, rect: Array) -> Variant:
	if is_scalar(kind):
		return rect.duplicate()
	o[TYPES[kind]["rects"][0]] = rect.duplicate()
	return o


## Uma linha para a lista: "1 · 12,5 20×1 · canal 2".
static func summary(kind: String, i: int, o: Variant) -> String:
	var r := rect_of(kind, o)
	var where := "?"
	if not r.is_empty():
		where = "%d,%d  %d×%d" % [r[0], r[1], r[2], r[3]]
	var extra := ""
	if not is_scalar(kind):
		if (o as Dictionary).has("ch") and kind != "crushers":
			extra = "  · canal %d" % int(o["ch"])
		if kind == "movers" and int(o.get("cycle", 0)) != 0:
			extra += "  · ciclo"
	return "%d · %s%s" % [i + 1, where, extra]


# ---------------------------------------------------------------- transformações (girar, espelhar, redimensionar)

static func _rect4(v: Variant) -> Array:
	return [int(v[0]), int(v[1]), int(v[2]), int(v[3]) if v.size() > 3 else 1]


## Aplica `rect_fn(rect4, extra_size) -> rect4`, `dir_fn(dir) -> dir` e `spike_fn(side) -> side` a
## todos os objetos e ao bloco giratório. `pt_fn(pos, size) -> pos` trata o "on" dos conectores.
static func _map(extra: Dictionary, rect_fn: Callable, dir_fn: Callable) -> Dictionary:
	var out := extra.duplicate(true)
	for kind in TYPES:
		if not out.has(kind):
			continue
		var t: Dictionary = TYPES[kind]
		var list: Array = out[kind]
		for i in list.size():
			if t.get("scalar", false):
				list[i] = rect_fn.call(_rect4(list[i]))
				continue
			var o: Dictionary = list[i]
			var size: Array = [1, 1]
			for k in t["rects"]:
				if o.has(k):
					var r: Array = _rect4(o[k])
					size = [r[2], r[3]]
					o[k] = rect_fn.call(r)
			for k in t.get("pts", []):
				if o.has(k):
					# o encaixe de ligado tem o mesmo tamanho do de desligado
					var moved: Array = rect_fn.call([int(o[k][0]), int(o[k][1]), size[0], size[1]])
					o[k] = [moved[0], moved[1]]
			for k in t.get("dirs", []):
				if o.has(k):
					o[k] = dir_fn.call(int(o[k]))
			for k in t.get("spike_dirs", []):
				if o.has(k) and int(o[k]) >= 0:
					o[k] = dir_fn.call(int(o[k]))
	if out.has("spin_block") and out["spin_block"] is Array and out["spin_block"].size() == 3:
		var sb: Array = out["spin_block"]
		var m: Array = rect_fn.call([int(sb[0]), int(sb[1]), int(sb[2]), int(sb[2])])
		out["spin_block"] = [m[0], m[1], m[2]]
	return out


## Gira a sala (dir > 0 horário), de `old_w` × `old_h` tiles.
static func rotate(extra: Dictionary, dir: int, old_w: int, old_h: int) -> Dictionary:
	var cw := dir > 0
	var rf := func(r: Array) -> Array:
		if cw:
			return [old_h - (r[1] + r[3]), r[0], r[3], r[2]]
		return [r[1], old_w - (r[0] + r[2]), r[3], r[2]]
	var df := func(d: int) -> int:
		return posmod(d + (1 if cw else -1), 4)
	return _map(extra, rf, df)


## Espelha a sala na horizontal.
static func mirror(extra: Dictionary, old_w: int) -> Dictionary:
	var rf := func(r: Array) -> Array:
		return [old_w - (r[0] + r[2]), r[1], r[2], r[3]]
	var df := func(d: int) -> int:
		return 3 if d == 1 else (1 if d == 3 else d)
	return _map(extra, rf, df)


## Muda de tamanho mantendo o chão: tudo desce `dr` linhas (new_h - old_h).
static func shift_rows(extra: Dictionary, dr: int) -> Dictionary:
	var rf := func(r: Array) -> Array:
		return [r[0], r[1] + dr, r[2], r[3]]
	var df := func(d: int) -> int:
		return d
	return _map(extra, rf, df)

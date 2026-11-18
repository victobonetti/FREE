extends RefCounted
## Uma fase como dado: a grade de texto de `levels.gd` mais os campos, com validação, JSON e
## código de texto para compartilhar. É o que o editor edita e o que `room.setup()` consome
## (`to_def()`).
##
## Legenda das peças (a mesma de levels.gd):
##   #  parede   .  vazio   P  coelho (2x2)   B  caixa (2x2)   S  compartimento da porta (2x2)
##   D  porta (retângulo)   1..9  comporta   a..i  compartimento de comporta (2x2)
##   ¹²³⁴⁵⁶⁷⁸⁹  comporta inversa 1..9: fecha quando a comporta de mesmo número abre
##   = } _ {  plataforma por orientação (seta para cima, direita, baixo, esquerda)
##   ^ > v <  espinho   ~  água   o  ralo   |  -  corda (sequência reta)

const CODE_PREFIX := "FREE1:"
const MAX_W := 512   # teto técnico, não de design (D72)
const MAX_H := 512
const MIN_TIME := 0.3   # s, recarga e limitador
const MAX_TIME := 30.0
const MIN_W := 6
const MIN_H := 6
const INVERSE_GATES := "¹²³⁴⁵⁶⁷⁸⁹"   # comporta inversa 1..9
const GLYPHS := "#.PBSD123456789abcdefghi=}_{^>v<~%o|-+LH¹²³⁴⁵⁶⁷⁸⁹"
const BLOCK_GLYPHS := "PBSLHabcdefghi"   # peças de 2x2
const GATE_SOCKETS := "abcdefghi"
const MAX_BATTERIES := 3

var name := ""
var hint := ""
var music := ""
var door_open := false
var rotate := true
var limiter := false
var reload_time := 0.4      # s: recarga do giro (D92)
var limiter_time := 2.5     # s: tempo até o limitador desfazer o giro
var start_rot := 0
var rows: Array = []        # Array[String]
var verified := false       # o autor venceu esta versão da fase
# Campos que o editor não edita (sala de boss: "spin_block", "actors"...; "hint_touch", "notes"):
# guardados como vieram e devolvidos em to_def(), para editar a grade não apagar nada.
var extra := {}
var verified_hash := ""     # hash da versão vencida; vale só se for igual ao hash atual


# ---------------------------------------------------------------- construção

static func blank(w: int, h: int) -> RefCounted:
	var d: RefCounted = load("res://scripts/level_data.gd").new()
	w = clampi(w, MIN_W, MAX_W)
	h = clampi(h, MIN_H, MAX_H)
	for r in h:
		d.rows.append("#".repeat(w) if (r == 0 or r == h - 1) else "#" + ".".repeat(w - 2) + "#")
	# um coelho e uma porta aberta, para a fase nova já ser jogável
	d.name = "Nova fase"
	d.door_open = true
	d.set_block(2, h - 3, "P")
	for r in range(h - 6, h - 2):
		for c in range(w - 3, w - 1):
			d.set_cell(c, r, "D")
	return d


static func from_def(def: Dictionary) -> RefCounted:
	var d: RefCounted = load("res://scripts/level_data.gd").new()
	d.name = str(def.get("name", ""))
	d.hint = str(def.get("hint", ""))
	d.music = str(def.get("music", ""))
	d.door_open = bool(def.get("door_open", false))
	d.rotate = bool(def.get("rotate", true))
	d.limiter = bool(def.get("limiter", false))
	d.reload_time = float(def.get("reload_time", 0.4))
	d.limiter_time = float(def.get("limiter_time", 2.5))
	d.start_rot = int(def.get("start_rot", 0))
	d.rows = []
	for r in def.get("rows", []):
		d.rows.append(str(r))
	d.verified = bool(def.get("verified", false))
	d.verified_hash = str(def.get("verified_hash", ""))
	for k in def:
		if not KNOWN_KEYS.has(k):
			d.extra[k] = def[k]
	return d


## Campos que esta classe edita (os outros vão para `extra`).
const KNOWN_KEYS := ["name", "hint", "music", "door_open", "rotate", "limiter", "reload_time",
	"limiter_time", "start_rot", "rows", "verified", "verified_hash", "version", "id"]
## Campos de `extra` que não mudam a jogabilidade (não entram no hash da verificação): textos e
## o que é só aparência (o tema do cenário, a cena do despertar do giro).
const TEXT_KEYS := ["hint_touch", "notes", "theme", "awaken", "chase_music"]


## O dicionário que `room.setup()` e o resto do jogo entendem.
func to_def() -> Dictionary:
	var def := {
		"name": name, "rotate": rotate, "start_rot": start_rot,
		"rows": rows.duplicate(),
	}
	if hint != "":
		def["hint"] = hint
	if music != "":
		def["music"] = music
	if door_open:
		def["door_open"] = true
	if limiter:
		def["limiter"] = true
	if not is_equal_approx(reload_time, 0.4):
		def["reload_time"] = reload_time
	if not is_equal_approx(limiter_time, 2.5):
		def["limiter_time"] = limiter_time
	for k in extra:
		def[k] = extra[k]
	return def


func duplicate_data() -> RefCounted:
	var d: RefCounted = from_def(to_def().duplicate(true))
	d.verified = verified
	d.verified_hash = verified_hash
	return d


# ---------------------------------------------------------------- grade

func width() -> int:
	return String(rows[0]).length() if not rows.is_empty() else 0


func height() -> int:
	return rows.size()


func in_bounds(c: int, r: int) -> bool:
	return r >= 0 and r < rows.size() and c >= 0 and c < String(rows[r]).length()


func cell(c: int, r: int) -> String:
	if not in_bounds(c, r):
		return "#"
	return String(rows[r])[c]


func set_cell(c: int, r: int, ch: String) -> void:
	if not in_bounds(c, r):
		return
	var line: String = rows[r]
	rows[r] = line.substr(0, c) + ch + line.substr(c + 1)


## Põe uma peça de 2x2 com o canto superior esquerdo em (c, r).
func set_block(c: int, r: int, ch: String) -> void:
	for dy in 2:
		for dx in 2:
			set_cell(c + dx, r + dy, ch)


# ---------------------------------------------------------------- hash e verificação

## Hash do que muda a jogabilidade (não conta nome nem dica de texto).
func content_hash() -> String:
	var parts: Array = [rotate, limiter, start_rot, door_open, rows, snappedf(reload_time, 0.01), snappedf(limiter_time, 0.01)]
	var play := {}
	for k in extra:
		if not TEXT_KEYS.has(k):
			play[k] = extra[k]
	if not play.is_empty():
		parts.append(_norm(play))   # só quando há: o hash das fases sem campos extras não muda
	return JSON.stringify(parts, "", true).sha256_text()


## Números inteiros lidos de JSON chegam como 17.0: normaliza para o hash não mudar.
static func _norm(v: Variant) -> Variant:
	if typeof(v) == TYPE_FLOAT and v == floorf(v):
		return int(v)
	if typeof(v) == TYPE_ARRAY:
		var out: Array = []
		for x in v:
			out.append(_norm(x))
		return out
	if typeof(v) == TYPE_DICTIONARY:
		var d := {}
		for k in v:
			d[k] = _norm(v[k])
		return d
	return v


func is_verified() -> bool:
	return verified and verified_hash == content_hash()


func mark_verified() -> void:
	verified = true
	verified_hash = content_hash()


# ---------------------------------------------------------------- JSON e código

func to_json() -> String:
	var def := to_def()
	def["verified"] = is_verified()
	def["verified_hash"] = verified_hash if is_verified() else ""
	def["version"] = 1
	return JSON.stringify(def, "\t")


static func from_json(text: String) -> RefCounted:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	if not parsed.has("rows") or typeof(parsed["rows"]) != TYPE_ARRAY:
		return null
	return from_def(parsed)


## Texto curto para colar e mandar a amigos: "FREE1:<tamanho>:<base64 do JSON comprimido>".
func to_code() -> String:
	var def := to_def()
	def["verified"] = is_verified()
	def["verified_hash"] = verified_hash if is_verified() else ""
	var raw := JSON.stringify(def).to_utf8_buffer()
	var packed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	return "%s%d:%s" % [CODE_PREFIX, raw.size(), Marshalls.raw_to_base64(packed)]


static func from_code(code: String) -> RefCounted:
	code = code.strip_edges()
	if not code.begins_with(CODE_PREFIX):
		return null
	var rest := code.substr(CODE_PREFIX.length())
	var sep := rest.find(":")
	if sep <= 0:
		return null
	var size := int(rest.substr(0, sep))
	if size <= 0 or size > 200000:
		return null
	var b64 := rest.substr(sep + 1)
	var re := RegEx.new()
	re.compile("^[A-Za-z0-9+/=]+$")
	if re.search(b64) == null:
		return null
	var packed := Marshalls.base64_to_raw(b64)
	if packed.is_empty():
		return null
	var raw := packed.decompress(size, FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != size:
		return null
	return from_json(raw.get_string_from_utf8())


# ---------------------------------------------------------------- validação

## Lista de problemas: cada um é {"erro": bool, "msg": String, "pos": Vector2i (ou (-1,-1))}.
## Erro impede de jogar; aviso só informa.
func validate() -> Array:
	var out: Array = []
	var no_pos := Vector2i(-1, -1)
	var w := width()
	var h := height()
	if h == 0 or w == 0:
		out.append({"erro": true, "msg": "A fase está vazia.", "pos": no_pos})
		return out
	if w < MIN_W or h < MIN_H or w > MAX_W or h > MAX_H:
		out.append({"erro": true, "msg": "Tamanho %dx%d fora do limite (%dx%d a %dx%d)." % [w, h, MIN_W, MIN_H, MAX_W, MAX_H], "pos": no_pos})
	for r in h:
		if String(rows[r]).length() != w:
			out.append({"erro": true, "msg": "A linha %d tem tamanho diferente das outras." % (r + 1), "pos": Vector2i(0, r)})
			return out
	for r in h:
		for c in w:
			var ch := cell(c, r)
			if not GLYPHS.contains(ch):
				out.append({"erro": true, "msg": "Peça desconhecida '%s'." % ch, "pos": Vector2i(c, r)})
				return out
			var edge := r == 0 or r == h - 1 or c == 0 or c == w - 1
			if edge and ch != "#":
				out.append({"erro": true, "msg": "A borda da sala tem de ser parede.", "pos": Vector2i(c, r)})
				return out

	# peças de 2x2: mesma leitura de room.gd (canto superior esquerdo, marcando o bloco)
	var visited := {}
	var rabbits := 0
	var boxes := 0
	var door_sockets := 0
	var gate_sockets := {}
	var levers := 0
	var chutes := 0
	for r in h:
		for c in w:
			var ch := cell(c, r)
			if not BLOCK_GLYPHS.contains(ch) or visited.has(Vector2i(c, r)):
				continue
			var ok := true
			for dy in 2:
				for dx in 2:
					visited[Vector2i(c + dx, r + dy)] = true
					if cell(c + dx, r + dy) != ch or c + dx >= w or r + dy >= h:
						ok = false
			if not ok:
				out.append({"erro": true, "msg": "A peça '%s' precisa ocupar um quadrado de 2x2." % ch, "pos": Vector2i(c, r)})
				continue
			match ch:
				"P":
					rabbits += 1
				"B":
					boxes += 1
				"S":
					door_sockets += 1
				"L":
					levers += 1
				"H":
					chutes += 1
				_:
					gate_sockets[GATE_SOCKETS.find(ch) + 1] = true
	if rabbits == 0:
		out.append({"erro": true, "msg": "Falta o coelho.", "pos": no_pos})
	elif rabbits > 1:
		out.append({"erro": true, "msg": "Só pode haver um coelho (há %d)." % rabbits, "pos": no_pos})

	# porta: todas as células D formam um retângulo cheio
	var lo := Vector2i(w, h)
	var hi := Vector2i(-1, -1)
	var dcount := 0
	for r in h:
		for c in w:
			if cell(c, r) == "D":
				dcount += 1
				lo = Vector2i(mini(lo.x, c), mini(lo.y, r))
				hi = Vector2i(maxi(hi.x, c), maxi(hi.y, r))
	if dcount == 0:
		out.append({"erro": true, "msg": "Falta a porta.", "pos": no_pos})
	elif dcount != (hi.x - lo.x + 1) * (hi.y - lo.y + 1):
		out.append({"erro": true, "msg": "A porta tem de ser um retângulo inteiro.", "pos": lo})

	# comportas, compartimentos e caixas
	var gates := {}
	for r in h:
		for c in w:
			var ch := cell(c, r)
			if ch >= "1" and ch <= "9":
				gates[int(ch)] = Vector2i(c, r)
			elif INVERSE_GATES.contains(ch):
				gates[INVERSE_GATES.find(ch) + 1] = Vector2i(c, r)
	for id in gates:
		if not gate_sockets.has(id):
			out.append({"erro": true, "msg": "A comporta %d não tem compartimento '%s'." % [id, GATE_SOCKETS[id - 1]], "pos": gates[id]})
	for id in gate_sockets:
		if not gates.has(id):
			out.append({"erro": false, "msg": "O compartimento '%s' não abre nenhuma comporta." % GATE_SOCKETS[id - 1], "pos": no_pos})
	var sockets := door_sockets + gate_sockets.size()
	# baterias, alavanca e calha: andam juntas. A calha solta uma caixa, que conta como caixa da sala.
	var bats := 0
	for line in rows:
		bats += String(line).count("+")
	if bats + levers + chutes > 0:
		if levers != 1:
			out.append({"erro": true, "msg": "Com baterias ou calha, a sala precisa de exatamente uma alavanca 'L' (há %d)." % levers, "pos": no_pos})
		if chutes != 1:
			out.append({"erro": true, "msg": "Com baterias ou alavanca, a sala precisa de exatamente uma calha 'H' (há %d)." % chutes, "pos": no_pos})
		if bats < 1 or bats > MAX_BATTERIES:
			out.append({"erro": true, "msg": "A alavanca precisa de 1 a %d baterias '+' (há %d)." % [MAX_BATTERIES, bats], "pos": no_pos})
	boxes += chutes
	if boxes < sockets:
		out.append({"erro": true, "msg": "Há %d compartimentos e só %d caixas." % [sockets, boxes], "pos": no_pos})
	# a sala tem um fluido só: água ou ácido
	var has_w := false
	var has_a := false
	for line in rows:
		has_w = has_w or String(line).contains("~")
		has_a = has_a or String(line).contains("%")
	if has_w and has_a:
		out.append({"erro": true, "msg": "A sala não pode ter água '~' e ácido '%' ao mesmo tempo.", "pos": no_pos})
	# bloco giratório (sala de boss): quadrado, dentro da sala, todo de parede
	if extra.has("spin_block"):
		var sb = extra["spin_block"]
		if not (sb is Array) or sb.size() != 3:
			out.append({"erro": true, "msg": "Bloco giratório mal definido.", "pos": no_pos})
		else:
			var c0 := int(sb[0])
			var r0 := int(sb[1])
			var n := int(sb[2])
			var ok := n >= 1
			for rr in n:
				for cc in n:
					ok = ok and in_bounds(c0 + cc, r0 + rr) and cell(c0 + cc, r0 + rr) == "#"
			if not ok:
				out.append({"erro": true, "msg": "O bloco giratório precisa ser todo de parede '#'.", "pos": Vector2i(c0, r0)})
	if extra.has("actors") and not extra.has("spin_block") and str(extra["actors"]).contains("boss_squirrel"):
		out.append({"erro": true, "msg": "O Jeffrey precisa de um bloco giratório.", "pos": no_pos})
	_validate_objects(out, w, h)
	# numa sala com ator (boss), quem abre a porta é ele
	if door_sockets == 0 and not door_open and dcount > 0 and not extra.has("actors"):
		out.append({"erro": true, "msg": "A porta não tem compartimento 'S': marque 'porta aberta' ou ponha um.", "pos": no_pos})
	if door_sockets > 0 and door_open:
		out.append({"erro": false, "msg": "'Porta aberta' está ligado: o compartimento 'S' não será usado.", "pos": no_pos})
	if boxes > sockets and sockets > 0:
		out.append({"erro": false, "msg": "Há mais caixas do que compartimentos.", "pos": no_pos})

	# cordas: cada sequência reta precisa tocar uma parede numa das pontas
	var seen := {}
	for r in h:
		for c in w:
			var ch := cell(c, r)
			if (ch != "|" and ch != "-") or seen.has(Vector2i(c, r)):
				continue
			var vertical := ch == "|"
			var st := Vector2i(0, 1) if vertical else Vector2i(1, 0)
			var last := Vector2i(c, r)
			while cell(last.x + st.x, last.y + st.y) == ch:
				last += st
			var n := 0
			var p := Vector2i(c, r)
			while p != last + st:
				seen[p] = true
				p += st
				n += 1
			var before := Vector2i(c, r) - st
			var after := last + st
			if cell(before.x, before.y) != "#" and cell(after.x, after.y) != "#":
				out.append({"erro": true, "msg": "A corda precisa ter uma ponta encostada numa parede.", "pos": Vector2i(c, r)})
			elif n < 2:
				out.append({"erro": false, "msg": "Corda muito curta (%d tile)." % n, "pos": Vector2i(c, r)})

	if absi(start_rot) > 3:
		out.append({"erro": true, "msg": "Rotação inicial inválida.", "pos": no_pos})
	if reload_time < MIN_TIME or reload_time > MAX_TIME:
		out.append({"erro": true, "msg": "A recarga do giro tem de ficar entre %.1f e %.0f s." % [MIN_TIME, MAX_TIME], "pos": no_pos})
	if limiter and (limiter_time < MIN_TIME or limiter_time > MAX_TIME):
		out.append({"erro": true, "msg": "O tempo do limitador tem de ficar entre %.1f e %.0f s." % [MIN_TIME, MAX_TIME], "pos": no_pos})
	if limiter and not rotate:
		out.append({"erro": false, "msg": "O limitador não faz nada sem giro.", "pos": no_pos})
	return out


## Os objetos da fase que não são glifos: placas de espinhos, conectores, chapas soltas e botões.
## Cada um é uma lista em `extra` (veja room.gd). Em tiles, dentro da sala; erros impedem de jogar.
func _validate_objects(out: Array, w: int, h: int) -> void:
	var no_pos := Vector2i(-1, -1)
	var in_room := func(r: Array) -> bool:
		return r.size() >= 3 and int(r[0]) >= 0 and int(r[1]) >= 0 and int(r[0]) + int(r[2]) <= w \
			and int(r[1]) + (int(r[3]) if r.size() > 3 else 1) <= h
	var bad_rect := func(name: String, i: int, key: String) -> void:
		out.append({"erro": true, "msg": "%s %d: '%s' mal definido ou fora da sala." % [name, i + 1, key], "pos": no_pos})
	var has_actor: bool = extra.has("actors")
	var has_cycle_or_actor := has_actor
	var channels_driven := {}   # canais que algo aciona (botão ou ator)
	for pl in extra.get("plates", []):
		channels_driven[int(pl.get("ch", 0))] = true
	for i in extra.get("crushers", []).size():
		var c: Dictionary = extra["crushers"][i]
		if not (c.get("rect", null) is Array) or not in_room.call(c["rect"]) or int(c["rect"][3]) < 1:
			bad_rect.call("Placa", i, "rect")
			continue
		if int(c.get("dir", 0)) < 0 or int(c.get("dir", 0)) > 3:
			out.append({"erro": true, "msg": "Placa %d: 'dir' vai de 0 a 3." % (i + 1), "pos": no_pos})
		if float(c.get("speed", 9.0)) <= 0.0:
			out.append({"erro": true, "msg": "Placa %d: a velocidade precisa ser maior que zero." % (i + 1), "pos": no_pos})
		if float(c.get("delay", 0.0)) < 0.0 and not has_actor:
			out.append({"erro": false, "msg": "Placa %d espera um ator ligá-la, mas a fase não tem nenhum: ela nunca liga." % (i + 1), "pos": no_pos})
	for i in extra.get("movers", []).size():
		var m: Dictionary = extra["movers"][i]
		var off = m.get("off", null)
		var on = m.get("on", null)
		if not (off is Array) or not in_room.call(off) or int(off[3]) < 1:
			bad_rect.call("Conector", i, "off")
			continue
		if not (on is Array) or on.size() < 2:
			bad_rect.call("Conector", i, "on")
			continue
		var on_rect := [int(on[0]), int(on[1]), int(off[2]), int(off[3])]
		if not in_room.call(on_rect):
			bad_rect.call("Conector", i, "on")
			continue
		if int(off[0]) != int(on[0]) and int(off[1]) != int(on[1]):
			out.append({"erro": true, "msg": "Conector %d: os dois encaixes precisam estar na mesma linha ou na mesma coluna." % (i + 1), "pos": Vector2i(int(off[0]), int(off[1]))})
		if float(m.get("speed", 40.0)) <= 0.0:
			out.append({"erro": true, "msg": "Conector %d: a velocidade precisa ser maior que zero." % (i + 1), "pos": no_pos})
		if int(m.get("ch", 0)) < 0 or int(m.get("ch", 0)) > 7:
			out.append({"erro": true, "msg": "Conector %d: o canal vai de 0 a 7." % (i + 1), "pos": no_pos})
		if int(m.get("spikes", -1)) < -1 or int(m.get("spikes", -1)) > 3:
			out.append({"erro": true, "msg": "Conector %d: 'spikes' vai de -1 a 3." % (i + 1), "pos": no_pos})
		if float(m.get("delay", 0.0)) < 0.0 or float(m.get("delay", 0.0)) > 10.0:
			out.append({"erro": true, "msg": "Conector %d: o atraso vai de 0 a 10 s." % (i + 1), "pos": no_pos})
		if m.has("cycle") and float(m["cycle"]) != 0.0 and float(m["cycle"]) < 0.5:
			out.append({"erro": true, "msg": "Conector %d: o ciclo mínimo é 0,5 s." % (i + 1), "pos": no_pos})
		for dock in [off, on_rect]:
			for rr in range(int(dock[1]), int(dock[1]) + int(dock[3])):
				for cc in range(int(dock[0]), int(dock[0]) + int(dock[2])):
					if cell(cc, rr) == "#":
						out.append({"erro": true, "msg": "Conector %d: um encaixe cai dentro da parede." % (i + 1), "pos": Vector2i(cc, rr)})
		var driven: bool = has_actor or float(m.get("cycle", 0.0)) > 0.0 or int(m.get("bat", 0)) > 0 or channels_driven.has(int(m.get("ch", 0)))
		if not driven:
			out.append({"erro": false, "msg": "Conector %d não tem acionador (ciclo, bateria, botão ou ator): fica parado." % (i + 1), "pos": Vector2i(int(off[0]), int(off[1]))})
		if int(m.get("bat", 0)) > MAX_BATTERIES:
			out.append({"erro": true, "msg": "Conector %d: 'bat' vai até %d." % [i + 1, MAX_BATTERIES], "pos": no_pos})
	for i in extra.get("crumbles", []).size():
		var cr = extra["crumbles"][i]
		if not (cr is Array) or not in_room.call(cr):
			bad_rect.call("Chapa solta", i, "rect")
			continue
		for rr in range(int(cr[1]), int(cr[1]) + int(cr[3])):
			for cc in range(int(cr[0]), int(cr[0]) + int(cr[2])):
				if cell(cc, rr) == "#":
					out.append({"erro": false, "msg": "Chapa solta %d está dentro da parede." % (i + 1), "pos": Vector2i(cc, rr)})
	for i in extra.get("plates", []).size():
		var pl: Dictionary = extra["plates"][i]
		if not (pl.get("rect", null) is Array) or not in_room.call(pl["rect"]):
			bad_rect.call("Botão", i, "rect")
			continue
		if int(pl.get("ch", 0)) < 0 or int(pl.get("ch", 0)) > 7:
			out.append({"erro": true, "msg": "Botão %d: o canal vai de 0 a 7." % (i + 1), "pos": no_pos})
		var any := has_actor
		for m2 in extra.get("movers", []):
			any = any or int(m2.get("ch", 0)) == int(pl.get("ch", 0))
		if not any:
			out.append({"erro": false, "msg": "Botão %d: nenhum conector usa o canal %d." % [i + 1, int(pl.get("ch", 0))], "pos": no_pos})


func errors() -> Array:
	return validate().filter(func(p): return p["erro"])


func is_playable() -> bool:
	return errors().is_empty()

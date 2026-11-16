extends RefCounted
## Desenha cada peça da fase de forma esquemática, com as mesmas cores do jogo. Usado pela
## grade do editor e pelos botões da paleta, sempre sobre um retângulo `r` (um tile).

const RoomScript := preload("res://scripts/room.gd")

const SUPERS := "¹²³⁴⁵⁶⁷⁸⁹"
const NAMES := {
	"#": "Parede", ".": "Vazio", "^": "Espinho para cima", ">": "Espinho para a direita",
	"v": "Espinho para baixo", "<": "Espinho para a esquerda",
	"=": "Plataforma: seta para cima", "}": "Plataforma: seta para a direita",
	"_": "Plataforma: seta para baixo", "{": "Plataforma: seta para a esquerda",
	"~": "Água", "o": "Ralo", "|": "Corda vertical", "-": "Corda horizontal",
	"P": "Coelho (2x2)", "B": "Caixa (2x2)", "S": "Compartimento da porta (2x2)", "D": "Porta",
}

static var _art = null


static func rabbit_texture() -> Texture2D:
	if _art == null:
		_art = RoomScript.new()
	return _art._rabbit_tex("up", "stand", false)


static func name_of(g: String) -> String:
	if NAMES.has(g):
		return NAMES[g]
	if g >= "1" and g <= "9":
		return "Comporta %s" % g
	if SUPERS.contains(g):
		return "Comporta inversa %d: fecha quando a comporta %d abre" % [SUPERS.find(g) + 1, SUPERS.find(g) + 1]
	if "abcdefghi".contains(g):
		return "Compartimento '%s' (2x2): abre a comporta %d" % [g, "abcdefghi".find(g) + 1]
	return g


static func _font() -> Font:
	return ThemeDB.fallback_font


## `ctx`: {"edges": [cima, direita, baixo, esquerda] (true = encosta em vazio), "anchor": bool,
## "alpha": float}. Tudo opcional.
static func draw(ci: CanvasItem, g: String, r: Rect2, ctx := {}) -> void:
	var a: float = ctx.get("alpha", 1.0)
	var s := r.size.x
	match g:
		".":
			return
		"#":
			ci.draw_rect(r, Color("2b2b3a", a))
			var edges: Array = ctx.get("edges", [true, true, true, true])
			var e := Color(RoomScript.C_EDGE, a)
			if edges[0]:
				ci.draw_rect(Rect2(r.position, Vector2(s, 1)), e)
			if edges[1]:
				ci.draw_rect(Rect2(r.position + Vector2(s - 1, 0), Vector2(1, s)), e)
			if edges[2]:
				ci.draw_rect(Rect2(r.position + Vector2(0, s - 1), Vector2(s, 1)), e)
			if edges[3]:
				ci.draw_rect(Rect2(r.position, Vector2(1, s)), e)
		"^", ">", "v", "<":
			var f := "^>v<".find(g)
			var pts := PackedVector2Array([Vector2(0.12, 0.95), Vector2(0.5, 0.25), Vector2(0.88, 0.95)])
			ci.draw_colored_polygon(_xf(pts, f, r), Color(RoomScript.C_SPIKE, a))
		"=", "}", "_", "{":
			var f2 := "=}_{".find(g)
			ci.draw_rect(r, Color(RoomScript.C_PLAT_DARK, a))
			ci.draw_rect(Rect2(r.position, Vector2(s, maxf(s * 0.15, 1))), Color(RoomScript.C_PLAT, a))
			var ar := PackedVector2Array([Vector2(0.25, 0.75), Vector2(0.5, 0.3), Vector2(0.75, 0.75)])
			ci.draw_colored_polygon(_xf(ar, f2, r), Color(RoomScript.C_PLAT, a * 0.9))
		"~":
			ci.draw_rect(r, Color(RoomScript.C_WATER, 0.6 * a))
		"o":
			var c := r.get_center()
			ci.draw_circle(c, s * 0.42, Color(RoomScript.C_DRAIN, 0.3 * a))
			ci.draw_arc(c, s * 0.38, 0.0, TAU, 16, Color(RoomScript.C_DRAIN, a), 1.0)
			for i in 3:
				var an := i * PI / 3.0
				var v := Vector2(cos(an), sin(an)) * s * 0.38
				ci.draw_line(c - v, c + v, Color(RoomScript.C_DRAIN, a), 1.0)
		"|":
			var x := r.position.x + s * 0.5
			ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(RoomScript.C_ROPE, a), maxf(s * 0.1, 1.0))
			if ctx.get("anchor", false):
				ci.draw_rect(Rect2(Vector2(x - s * 0.15, r.position.y), Vector2(s * 0.3, s * 0.18)), Color(1, 1, 1, a))
			if ctx.get("anchor2", false):
				ci.draw_rect(Rect2(Vector2(x - s * 0.15, r.end.y - s * 0.18), Vector2(s * 0.3, s * 0.18)), Color(1, 1, 1, a))
		"-":
			var y := r.position.y + s * 0.5
			ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(RoomScript.C_ROPE, a), maxf(s * 0.1, 1.0))
			if ctx.get("anchor", false):
				ci.draw_rect(Rect2(Vector2(r.position.x, y - s * 0.15), Vector2(s * 0.18, s * 0.3)), Color(1, 1, 1, a))
			if ctx.get("anchor2", false):
				ci.draw_rect(Rect2(Vector2(r.end.x - s * 0.18, y - s * 0.15), Vector2(s * 0.18, s * 0.3)), Color(1, 1, 1, a))
		"D":
			ci.draw_rect(r, Color(RoomScript.C_DOOR_OPEN, 0.28 * a))
		"1", "2", "3", "4", "5", "6", "7", "8", "9":
			ci.draw_rect(r, Color(RoomScript.C_GATE_DARK, a))
			ci.draw_rect(Rect2(r.position + Vector2(0, s * 0.25), Vector2(s, 1)), Color(RoomScript.C_GATE, a))
			ci.draw_rect(Rect2(r.position + Vector2(0, s * 0.7), Vector2(s, 1)), Color(RoomScript.C_GATE, a))
			_label(ci, g, r, Color(RoomScript.C_GATE, a))
		_:
			if SUPERS.contains(g):
				ci.draw_rect(r, Color(RoomScript.C_IGATE_DARK, a))
				ci.draw_line(r.position, r.end, Color(RoomScript.C_IGATE, a), 1.0)
				ci.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Color(RoomScript.C_IGATE, a), 1.0)
				ci.draw_rect(r, Color(RoomScript.C_IGATE, 0.7 * a), false, 1.0)
				_label(ci, str(SUPERS.find(g) + 1), r, Color(RoomScript.C_IGATE, a))


## Peças de 2x2: `r` cobre as quatro células.
static func draw_block(ci: CanvasItem, g: String, r: Rect2, alpha := 1.0) -> void:
	var s := r.size.x
	match g:
		"P":
			var tex := rabbit_texture()
			var h := r.size.y * 0.92
			var w := h * 12.0 / 16.0
			ci.draw_texture_rect(tex, Rect2(r.position + Vector2((s - w) * 0.5, r.size.y - h), Vector2(w, h)), false, Color(1, 1, 1, alpha))
		"B":
			ci.draw_rect(r, Color(RoomScript.C_BOX_DARK, alpha))
			ci.draw_rect(r.grow(-s * 0.06), Color(RoomScript.C_BOX, alpha))
			ci.draw_rect(Rect2(r.position + r.size * 0.32, r.size * 0.36), Color(RoomScript.C_BOX_MID, alpha))
		"S":
			ci.draw_rect(r, Color(RoomScript.C_SOCKET, alpha))
			ci.draw_rect(r, Color(RoomScript.C_SOCKET_FRAME, alpha), false, maxf(s * 0.06, 1.0))
			_label(ci, "S", r, Color(RoomScript.C_SOCKET_FRAME, alpha))
		_:
			var col := Color(RoomScript.C_GATE, alpha)
			ci.draw_rect(r, Color(RoomScript.C_SOCKET, alpha))
			ci.draw_rect(r, col, false, maxf(s * 0.06, 1.0))
			_label(ci, g, r, col)


static func _label(ci: CanvasItem, text: String, r: Rect2, col: Color) -> void:
	var fs := int(clampf(r.size.y * 0.55, 6.0, 40.0))
	var f := _font()
	var sz := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	ci.draw_string(f, r.position + Vector2((r.size.x - sz.x) * 0.5, (r.size.y + sz.y * 0.55) * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Gira pontos 0..1 de um tile (`times` quartos de volta no sentido horário) e põe em `r`.
static func _xf(pts: PackedVector2Array, times: int, r: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		var q := p
		for i in times:
			q = Vector2(1.0 - q.y, q.x)
		out.append(r.position + q * r.size)
	return out

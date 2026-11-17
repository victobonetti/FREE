extends Control
## A grade do editor: desenha a fase, converte o mouse em células e entrega os gestos às
## ferramentas (`EditTools`). Roda com a roda do mouse (zoom) e o botão do meio ou Espaço
## com botão esquerdo (rolagem).

const GlyphDraw := preload("res://scripts/editor/glyph_draw.gd")
const RoomScript := preload("res://scripts/room.gd")
const EditTools := preload("res://scripts/editor/edit_tools.gd")
const Objects := preload("res://scripts/editor/objects.gd")

## Siglas dos objetos, no canto de cada contorno.
const TAGS := {"crushers": "PL", "movers": "CN", "crumbles": "CH", "plates": "BT", "conveyors": "ES", "springs": "ML", "fans": "VT", "vents": "VP"}

signal hovered(cell: Vector2i)
signal problem_clicked(index: int)

const MIN_CELL := 6.0
const MAX_CELL := 64.0

var model: RefCounted
var tools: RefCounted
var cell_size := 20.0
var offset := Vector2(40, 40)
var show_grid := true
var auto_fit := true        # enquadra sozinho até o jogador dar zoom ou mover
var problems: Array = []
var overlay_sel: Array = ["", -1]   # [tipo, índice] do objeto escolhido na janela de objetos

var _last_version := -1
var _origins := {}          # célula -> canto da peça de 2x2
var _panning := false
var _painting := false


func setup(m: RefCounted, t: RefCounted) -> void:
	model = m
	tools = t
	clip_contents = true
	focus_mode = Control.FOCUS_CLICK
	resized.connect(func():
		if auto_fit:
			fit())
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	refresh()


func refresh() -> void:
	_last_version = -1
	queue_redraw()


## Enquadra a sala inteira no espaço disponível.
func fit() -> void:
	auto_fit = true
	var w: int = model.data.width()
	var h: int = model.data.height()
	if w == 0 or h == 0 or size.x <= 0.0:
		return
	cell_size = clampf(floorf(minf((size.x - 24.0) / w, (size.y - 24.0) / h)), MIN_CELL, MAX_CELL)
	offset = ((size - Vector2(w, h) * cell_size) * 0.5).floor()
	queue_redraw()


## Contorno colorido de cada objeto (placas, conectores, chapas, botões...), com a sigla e o número;
## o escolhido na janela de objetos fica mais forte. O encaixe "ligado" do conector é tracejado.
func _draw_objects() -> void:
	var font := ThemeDB.fallback_font
	for kind in Objects.ORDER:
		var list: Array = model.data.extra.get(kind, [])
		var col: Color = Objects.TYPES[kind]["color"]
		for i in list.size():
			var o: Variant = list[i]
			var r := Objects.rect_of(kind, o)
			if r.is_empty():
				continue
			var chosen: bool = overlay_sel[0] == kind and int(overlay_sel[1]) == i
			var rr := Rect2(offset + Vector2(r[0], r[1]) * cell_size, Vector2(r[2], r[3]) * cell_size)
			draw_rect(rr, Color(col, 0.2 if chosen else 0.09))
			draw_rect(rr, Color(col, 1.0 if chosen else 0.65), false, 2.5 if chosen else 1.5)
			draw_string(font, rr.position + Vector2(3, 12), "%s%d" % [TAGS[kind], i + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(col, 1.0))
			if kind == "movers" and (o as Dictionary).get("on", null) is Array:
				var on: Array = o["on"]
				var onr := Rect2(offset + Vector2(int(on[0]), int(on[1])) * cell_size, Vector2(r[2], r[3]) * cell_size)
				for q in 4:
					var pts: Array = [onr.position, onr.position + Vector2(onr.size.x, 0), onr.end, onr.position + Vector2(0, onr.size.y)]
					draw_dashed_line(pts[q], pts[(q + 1) % 4], Color(col, 1.0 if chosen else 0.65), 1.5, 5.0)
				draw_line(rr.get_center(), onr.get_center(), Color(col, 0.5), 1.0)
			# seta do sentido, quando o objeto tem um
			if not Objects.is_scalar(kind) and (o as Dictionary).has("dir"):
				var dv: Vector2 = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][posmod(int(o["dir"]), 4)]
				var c := rr.get_center()
				var tip := c + dv * minf(cell_size * 0.9, 14.0)
				var side := Vector2(dv.y, -dv.x) * minf(cell_size * 0.4, 6.0)
				draw_colored_polygon(PackedVector2Array([tip, c - dv * 3.0 + side, c - dv * 3.0 - side]), Color(col, 0.9))


func cell_at(p: Vector2) -> Vector2i:
	var q := (p - offset) / cell_size
	return Vector2i(floori(q.x), floori(q.y))


func cell_rect(c: int, r: int, span := 1) -> Rect2:
	return Rect2(offset + Vector2(c, r) * cell_size, Vector2(cell_size, cell_size) * span)


func _process(_delta: float) -> void:
	if model != null and model.version != _last_version:
		_last_version = model.version
		_rebuild_origins()
		problems = model.data.validate()
		queue_redraw()


func _rebuild_origins() -> void:
	_origins = {}
	var d = model.data
	for r in d.height():
		for c in d.width():
			var g: String = d.cell(c, r)
			if not model.is_block(g) or _origins.has(Vector2i(c, r)):
				continue
			for dy in 2:
				for dx in 2:
					_origins[Vector2i(c + dx, r + dy)] = Vector2i(c, r)


# ---------------------------------------------------------------- desenho

func _draw() -> void:
	if model == null:
		return
	var d = model.data
	var w: int = d.width()
	var h: int = d.height()
	draw_rect(Rect2(Vector2.ZERO, size), Color("08080c"))
	draw_rect(Rect2(offset, Vector2(w, h) * cell_size), RoomScript.C_BG)
	var door_lo := Vector2i(w, h)
	var door_hi := Vector2i(-1, -1)
	for r in h:
		for c in w:
			var rect := cell_rect(c, r)
			if rect.end.x < 0 or rect.end.y < 0 or rect.position.x > size.x or rect.position.y > size.y:
				continue
			var g: String = d.cell(c, r)
			if g == ".":
				continue
			if model.is_block(g):
				if _origins.get(Vector2i(c, r), Vector2i(-2, -2)) == Vector2i(c, r):
					GlyphDraw.draw_block(self, g, cell_rect(c, r, 2))
				continue
			var ctx := {}
			if g == "#":
				ctx["edges"] = [d.cell(c, r - 1) != "#", d.cell(c + 1, r) != "#", d.cell(c, r + 1) != "#", d.cell(c - 1, r) != "#"]
			elif g == "|":
				ctx["anchor"] = d.cell(c, r - 1) == "#"
				ctx["anchor2"] = d.cell(c, r + 1) == "#" and d.cell(c, r - 1) != "#"
			elif g == "-":
				ctx["anchor"] = d.cell(c - 1, r) == "#"
				ctx["anchor2"] = d.cell(c + 1, r) == "#" and d.cell(c - 1, r) != "#"
			elif g == "D":
				door_lo = Vector2i(mini(door_lo.x, c), mini(door_lo.y, r))
				door_hi = Vector2i(maxi(door_hi.x, c), maxi(door_hi.y, r))
			GlyphDraw.draw(self, g, rect, ctx)
	if door_hi.x >= 0:
		var dr := Rect2(offset + Vector2(door_lo) * cell_size, Vector2(door_hi - door_lo + Vector2i.ONE) * cell_size)
		draw_rect(dr, RoomScript.C_DOOR_OPEN, false, 2.0)
		draw_rect(dr.grow(-cell_size * 0.2), Color(RoomScript.C_DOOR_INNER, 0.7))
	# bloco giratório (sala de boss): contorno tracejado laranja
	var sb = model.data.extra.get("spin_block", null)
	if sb is Array and sb.size() == 3:
		var br := cell_rect(int(sb[0]), int(sb[1]), int(sb[2]))
		var col := Color(1.0, 0.6, 0.2, 0.95)
		var corners: Array[Vector2] = [br.position, br.position + Vector2(br.size.x, 0), br.end, br.position + Vector2(0, br.size.y)]
		for k in 4:
			draw_dashed_line(corners[k], corners[(k + 1) % 4], col, 2.0, 6.0)
	_draw_objects()
	if show_grid and cell_size >= 10.0:
		var gc := Color(1, 1, 1, 0.06)
		for c in range(w + 1):
			draw_line(offset + Vector2(c * cell_size, 0), offset + Vector2(c * cell_size, h * cell_size), gc, 1.0)
		for r in range(h + 1):
			draw_line(offset + Vector2(0, r * cell_size), offset + Vector2(w * cell_size, r * cell_size), gc, 1.0)

	# fantasma da ferramenta (arrasto ou colagem)
	for item in tools.preview():
		var cell: Vector2i = item[0]
		var g2: String = item[1]
		if not d.in_bounds(cell.x, cell.y):
			continue
		if model.is_block(g2):
			GlyphDraw.draw_block(self, g2, cell_rect(cell.x, cell.y, 2), 0.5)
		else:
			GlyphDraw.draw(self, g2, cell_rect(cell.x, cell.y), {"alpha": 0.55})
	if tools.pasting:
		var pc: Array = tools.paste_clip
		if not pc.is_empty():
			var pr := Rect2(offset + Vector2(tools.hover) * cell_size, Vector2(String(pc[0]).length(), pc.size()) * cell_size)
			draw_rect(pr, Color(0.3, 0.9, 1.0, 0.9), false, 1.5)

	# seleção
	if tools.has_selection or (tools.tool == EditTools.Tool.SELECT and tools.sel_a != tools.sel_b):
		var sr: Rect2i = tools.selection_rect()
		var rr := Rect2(offset + Vector2(sr.position) * cell_size, Vector2(sr.size) * cell_size)
		draw_rect(rr, Color(0.3, 0.9, 1.0, 0.12))
		draw_rect(rr, Color(0.3, 0.9, 1.0, 0.95), false, 1.5)

	# a peça escolhida segue o mouse
	var hv: Vector2i = tools.hover
	if d.in_bounds(hv.x, hv.y) and not tools.pasting:
		var span := 2 if model.is_block(tools.glyph) and tools.tool == EditTools.Tool.PENCIL else 1
		draw_rect(cell_rect(hv.x, hv.y, span), Color(1, 1, 1, 0.8), false, 1.5)

	# problemas
	for p in problems:
		var pos: Vector2i = p["pos"]
		if pos.x < 0:
			continue
		var col := Color("ff5a5a") if p["erro"] else Color("ffd23f")
		var cr := cell_rect(pos.x, pos.y)
		draw_rect(cr.grow(1.0), col, false, 2.0)
		draw_circle(cr.position + Vector2(cr.size.x, 0), maxf(cell_size * 0.22, 3.0), col)


# ---------------------------------------------------------------- mouse

func _gui_input(event: InputEvent) -> void:
	if model == null:
		return
	if event is InputEventMouseMotion:
		var cell := cell_at(event.position)
		tools.hover = cell
		hovered.emit(cell)
		if _panning:
			auto_fit = false
			offset += event.relative
		elif _painting:
			tools.drag(cell)
		queue_redraw()
	elif event is InputEventMouseButton:
		var cell2 := cell_at(event.position)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 1.0 / 1.15)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				grab_focus()
				if event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SPACE):
					_panning = true
					return
				if model.data.in_bounds(cell2.x, cell2.y):
					_painting = true
					tools.press(cell2, event.button_index == MOUSE_BUTTON_RIGHT)
			else:
				if _panning and event.button_index == MOUSE_BUTTON_LEFT:
					_panning = false
				elif _painting:
					_painting = false
					tools.release(cell2)
		queue_redraw()


func _zoom_at(p: Vector2, factor: float) -> void:
	auto_fit = false
	var before := (p - offset) / cell_size
	cell_size = clampf(cell_size * factor, MIN_CELL, MAX_CELL)
	offset = p - before * cell_size
	queue_redraw()

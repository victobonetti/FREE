extends RefCounted
## As ferramentas do editor: transformam gestos do mouse (apertar, arrastar, soltar sobre
## células da grade) em operações do modelo. Não desenha nada e não conhece a janela, então
## dá para testar sem tela.

const EditModel := preload("res://scripts/editor/edit_model.gd")

enum Tool { PENCIL, ERASER, RECT, RECT_HOLLOW, LINE, FILL, SELECT, DOOR, ROPE }

const TOOL_NAMES := {
	Tool.PENCIL: "Lápis", Tool.ERASER: "Borracha", Tool.RECT: "Retângulo",
	Tool.RECT_HOLLOW: "Moldura", Tool.LINE: "Linha", Tool.FILL: "Balde",
	Tool.SELECT: "Seleção", Tool.DOOR: "Porta", Tool.ROPE: "Corda",
}

var model: RefCounted
var tool := Tool.PENCIL
var glyph := "#"                       # a peça escolhida na paleta
var clip: Array = []                   # área de transferência
var has_selection := false
var sel_a := Vector2i.ZERO
var sel_b := Vector2i.ZERO
var pasting := false                   # mostrando o recorte para colar
var paste_clip: Array = []
var hover := Vector2i(-1, -1)

var _pressed := false
var _right := false
var _start := Vector2i.ZERO
var _last := Vector2i.ZERO
var _end := Vector2i.ZERO


func _init(m: RefCounted) -> void:
	model = m


func set_tool(t: int) -> void:
	tool = t
	if t != Tool.SELECT:
		cancel_selection()


func set_glyph(g: String) -> void:
	glyph = g
	if tool == Tool.ERASER or tool == Tool.SELECT or tool == Tool.DOOR or tool == Tool.ROPE:
		tool = Tool.PENCIL
	if (g == "|" or g == "-") and tool == Tool.PENCIL:
		tool = Tool.ROPE
	if g == "D":
		tool = Tool.DOOR


func is_block_glyph() -> bool:
	return model.is_block(glyph)


# ---------------------------------------------------------------- gestos

func press(cell: Vector2i, right := false) -> void:
	_pressed = true
	_right = right
	_start = cell
	_last = cell
	_end = cell
	if pasting:
		if not right:
			model.paste(paste_clip, cell.x, cell.y)
		else:
			cancel_paste()
		_pressed = false
		return
	var t := Tool.ERASER if right else tool
	match t:
		Tool.PENCIL:
			if is_block_glyph():
				model.stamp(cell.x, cell.y, glyph)
				_pressed = false
			else:
				model.begin()
				model.paint(cell.x, cell.y, glyph)
		Tool.ERASER:
			model.begin()
			model.erase(cell.x, cell.y)
		Tool.FILL:
			if is_block_glyph() or glyph == "D":
				return
			model.fill(cell.x, cell.y, glyph)
			_pressed = false
		Tool.SELECT:
			has_selection = false
			sel_a = cell
			sel_b = cell
		_:
			pass


func drag(cell: Vector2i) -> void:
	if not _pressed:
		return
	var t := Tool.ERASER if _right else tool
	match t:
		Tool.PENCIL:
			for p in EditModel.line_cells(_last.x, _last.y, cell.x, cell.y):
				model.paint(p.x, p.y, glyph)
		Tool.ERASER:
			for p in EditModel.line_cells(_last.x, _last.y, cell.x, cell.y):
				model.erase(p.x, p.y)
		Tool.SELECT:
			sel_b = cell
		_:
			pass
	_last = cell
	_end = cell


func release(cell: Vector2i) -> void:
	if not _pressed:
		return
	_pressed = false
	_end = cell
	var t := Tool.ERASER if _right else tool
	match t:
		Tool.PENCIL, Tool.ERASER:
			model.end()
		Tool.RECT:
			model.rect(_start.x, _start.y, cell.x, cell.y, glyph, true)
		Tool.RECT_HOLLOW:
			model.rect(_start.x, _start.y, cell.x, cell.y, glyph, false)
		Tool.LINE:
			model.line(_start.x, _start.y, cell.x, cell.y, glyph)
		Tool.DOOR:
			model.set_door(_start.x, _start.y, cell.x, cell.y)
		Tool.ROPE:
			model.rope(_start.x, _start.y, cell.x, cell.y)
		Tool.SELECT:
			sel_b = cell
			has_selection = true


## O que desenhar como "fantasma" enquanto se arrasta ou cola: lista de [célula, peça].
func preview() -> Array:
	var out: Array = []
	if pasting:
		for j in paste_clip.size():
			var line: String = paste_clip[j]
			for i in line.length():
				if line[i] != ".":
					out.append([hover + Vector2i(i, j), line[i]])
		return out
	if not _pressed:
		return out
	match Tool.ERASER if _right else tool:
		Tool.RECT, Tool.RECT_HOLLOW:
			var x0 := mini(_start.x, _end.x)
			var x1 := maxi(_start.x, _end.x)
			var y0 := mini(_start.y, _end.y)
			var y1 := maxi(_start.y, _end.y)
			for r in range(y0, y1 + 1):
				for c in range(x0, x1 + 1):
					if tool == Tool.RECT or r == y0 or r == y1 or c == x0 or c == x1:
						out.append([Vector2i(c, r), glyph])
		Tool.LINE:
			for p in EditModel.line_cells(_start.x, _start.y, _end.x, _end.y):
				out.append([p, glyph])
		Tool.DOOR:
			var dx0 := mini(_start.x, _end.x)
			var dx1 := maxi(_start.x, _end.x)
			var dy0 := mini(_start.y, _end.y)
			var dy1 := maxi(_start.y, _end.y)
			for r in range(dy0, dy1 + 1):
				for c in range(dx0, dx1 + 1):
					out.append([Vector2i(c, r), "D"])
		Tool.ROPE:
			var vertical := absi(_end.y - _start.y) >= absi(_end.x - _start.x)
			if vertical:
				var step := 1 if _end.y >= _start.y else -1
				for r in range(_start.y, _end.y + step, step):
					out.append([Vector2i(_start.x, r), "|"])
			else:
				var step2 := 1 if _end.x >= _start.x else -1
				for c in range(_start.x, _end.x + step2, step2):
					out.append([Vector2i(c, _start.y), "-"])
	return out


# ---------------------------------------------------------------- seleção e área de transferência

func selection_rect() -> Rect2i:
	var x0 := mini(sel_a.x, sel_b.x)
	var y0 := mini(sel_a.y, sel_b.y)
	return Rect2i(x0, y0, absi(sel_a.x - sel_b.x) + 1, absi(sel_a.y - sel_b.y) + 1)


func cancel_selection() -> void:
	has_selection = false


func copy_selection() -> bool:
	if not has_selection:
		return false
	clip = model.copy(sel_a.x, sel_a.y, sel_b.x, sel_b.y)
	return true


func cut_selection() -> bool:
	if not copy_selection():
		return false
	model.clear_rect(sel_a.x, sel_a.y, sel_b.x, sel_b.y)
	return true


func delete_selection() -> void:
	if has_selection:
		model.clear_rect(sel_a.x, sel_a.y, sel_b.x, sel_b.y)


func start_paste() -> bool:
	if clip.is_empty():
		return false
	pasting = true
	paste_clip = clip.duplicate()
	return true


func cancel_paste() -> void:
	pasting = false


func rotate_paste(dir: int) -> void:
	if pasting:
		paste_clip = EditModel.rotate_clip(paste_clip, dir)


func mirror_paste() -> void:
	if pasting:
		paste_clip = EditModel.mirror_clip(paste_clip)


## Escape: cancela, em ordem, a colagem e a seleção.
func escape() -> bool:
	if pasting:
		pasting = false
		return true
	if has_selection:
		has_selection = false
		return true
	return false

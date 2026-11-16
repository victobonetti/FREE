extends RefCounted
## O modelo do editor: uma fase (LevelData) e as operações de edição sobre a grade, cada uma
## desfazível. Não conhece mouse nem janela; a interface só chama estas funções.
##
## Regras que o modelo garante:
##  - a borda da sala nunca é alterada (só `resize` mexe nela);
##  - peças de 2x2 (coelho, caixa, compartimentos) entram e saem inteiras;
##  - só existe uma porta: desenhar outra apaga a anterior;
##  - tudo que muda a grade entra no histórico como um traço.

const LevelData := preload("res://scripts/level_data.gd")

const CW := {"^": ">", ">": "v", "v": "<", "<": "^", "=": "}", "}": "_", "_": "{", "{": "=", "|": "-", "-": "|"}
const CCW := {">": "^", "v": ">", "<": "v", "^": "<", "}": "=", "_": "}", "{": "_", "=": "{", "-": "|", "|": "-"}
const MIRROR := {">": "<", "<": ">", "}": "{", "{": "}"}
const HISTORY_LIMIT := 200

var data: RefCounted
var undo_stack: Array = []
var redo_stack: Array = []
var version := 0          # sobe a cada mudança: a interface redesenha quando muda
var dirty := false        # há mudança desde o último salvar
var _stroke := {}         # Vector2i -> [antes, depois]
var _open := false


func _init(level: RefCounted = null) -> void:
	data = level if level != null else LevelData.blank(24, 14)


func load_level(level: RefCounted) -> void:
	data = level
	undo_stack.clear()
	redo_stack.clear()
	_stroke = {}
	_open = false
	dirty = false
	version += 1


# ---------------------------------------------------------------- traços

func begin() -> void:
	_stroke = {}
	_open = true


func end() -> void:
	_open = false
	var cells: Array = []
	for k in _stroke:
		var v: Array = _stroke[k]
		if v[0] != v[1]:
			cells.append([k.x, k.y, v[0], v[1]])
	_stroke = {}
	if cells.is_empty():
		return
	_push({"cells": cells})


func _push(entry: Dictionary) -> void:
	undo_stack.append(entry)
	if undo_stack.size() > HISTORY_LIMIT:
		undo_stack.pop_front()
	redo_stack.clear()
	dirty = true
	version += 1


## Executa `fn` como um traço único (se já não houver um aberto).
func _as_stroke(fn: Callable) -> void:
	var own := not _open
	if own:
		begin()
	fn.call()
	if own:
		end()


func _put(c: int, r: int, ch: String) -> void:
	if not _editable(c, r):
		return
	var k := Vector2i(c, r)
	var old: String = data.cell(c, r)
	if _stroke.has(k):
		_stroke[k][1] = ch
	else:
		_stroke[k] = [old, ch]
	data.set_cell(c, r, ch)


func _editable(c: int, r: int) -> bool:
	return c > 0 and r > 0 and c < data.width() - 1 and r < data.height() - 1


func can_undo() -> bool:
	return not undo_stack.is_empty()


func can_redo() -> bool:
	return not redo_stack.is_empty()


func undo() -> bool:
	if undo_stack.is_empty():
		return false
	var e: Dictionary = undo_stack.pop_back()
	_apply(e, true)
	redo_stack.append(e)
	dirty = true
	version += 1
	return true


func redo() -> bool:
	if redo_stack.is_empty():
		return false
	var e: Dictionary = redo_stack.pop_back()
	_apply(e, false)
	undo_stack.append(e)
	dirty = true
	version += 1
	return true


func _apply(e: Dictionary, backwards: bool) -> void:
	if e.has("rows_before"):
		data.rows = (e["rows_before"] if backwards else e["rows_after"]).duplicate()
		return
	var cells: Array = e["cells"]
	for i in cells.size():
		var x: Array = cells[cells.size() - 1 - i] if backwards else cells[i]
		data.set_cell(x[0], x[1], x[2] if backwards else x[3])


# ---------------------------------------------------------------- consultas

func is_block(ch: String) -> bool:
	return LevelData.BLOCK_GLYPHS.contains(ch)


## Canto superior esquerdo da peça de 2x2 que contém (c, r), ou (-1, -1) se não é peça.
func block_origin(c: int, r: int) -> Vector2i:
	var ch: String = data.cell(c, r)
	if not is_block(ch):
		return Vector2i(-1, -1)
	var visited := {}
	for rr in data.height():
		for cc in data.width():
			var g: String = data.cell(cc, rr)
			if not is_block(g) or visited.has(Vector2i(cc, rr)):
				continue
			for dy in 2:
				for dx in 2:
					visited[Vector2i(cc + dx, rr + dy)] = Vector2i(cc, rr)
			if visited.get(Vector2i(c, r), null) != null and visited[Vector2i(c, r)] == Vector2i(cc, rr):
				return Vector2i(cc, rr)
	return Vector2i(-1, -1)


## Apaga o que "é dono" da célula: a peça de 2x2 inteira ou a porta inteira.
func _clear_owner(c: int, r: int) -> void:
	var ch: String = data.cell(c, r)
	if is_block(ch):
		var o := block_origin(c, r)
		if o.x >= 0:
			for dy in 2:
				for dx in 2:
					_put(o.x + dx, o.y + dy, ".")
		else:
			_put(c, r, ".")
	elif ch == "D":
		for rr in data.height():
			for cc in data.width():
				if data.cell(cc, rr) == "D":
					_put(cc, rr, ".")


# ---------------------------------------------------------------- ferramentas de um tile

## Põe uma peça de um tile (ou apaga, com "."). Peças de 2x2 e porta têm funções próprias.
func paint(c: int, r: int, ch: String) -> void:
	if not _editable(c, r) or is_block(ch) or ch == "D":
		return
	_as_stroke(func():
		_clear_owner(c, r)
		_put(c, r, ch))


func erase(c: int, r: int) -> void:
	paint(c, r, ".")


## Carimba uma peça de 2x2 com o canto em (c, r). Falha (false) se tocar a borda.
func stamp(c: int, r: int, ch: String) -> bool:
	if not is_block(ch):
		return false
	for dy in 2:
		for dx in 2:
			if not _editable(c + dx, r + dy):
				return false
	_as_stroke(func():
		for dy in 2:
			for dx in 2:
				_clear_owner(c + dx, r + dy)
		# o coelho é único: o novo substitui o antigo
		if ch == "P":
			for rr in data.height():
				for cc in data.width():
					if data.cell(cc, rr) == "P":
						_put(cc, rr, ".")
		for dy in 2:
			for dx in 2:
				_put(c + dx, r + dy, ch))
	return true


## Desenha a porta como um retângulo (cantos opostos). Substitui a porta anterior.
func set_door(c0: int, r0: int, c1: int, r1: int) -> void:
	var x0: int = clampi(mini(c0, c1), 1, data.width() - 2)
	var x1: int = clampi(maxi(c0, c1), 1, data.width() - 2)
	var y0: int = clampi(mini(r0, r1), 1, data.height() - 2)
	var y1: int = clampi(maxi(r0, r1), 1, data.height() - 2)
	_as_stroke(func():
		for rr in data.height():
			for cc in data.width():
				if data.cell(cc, rr) == "D":
					_put(cc, rr, ".")
		for rr in range(y0, y1 + 1):
			for cc in range(x0, x1 + 1):
				_clear_owner(cc, rr)
				_put(cc, rr, "D"))


## Desenha uma corda reta do primeiro ao segundo ponto, pelo eixo de maior distância.
## Não atravessa paredes: para antes delas.
func rope(c0: int, r0: int, c1: int, r1: int) -> void:
	var vertical := absi(r1 - r0) >= absi(c1 - c0)
	var ch := "|" if vertical else "-"
	_as_stroke(func():
		if vertical:
			var step := 1 if r1 >= r0 else -1
			var rr := r0
			while rr != r1 + step:
				if data.cell(c0, rr) == "#" or not _editable(c0, rr):
					break
				_clear_owner(c0, rr)
				_put(c0, rr, ch)
				rr += step
		else:
			var step := 1 if c1 >= c0 else -1
			var cc := c0
			while cc != c1 + step:
				if data.cell(cc, r0) == "#" or not _editable(cc, r0):
					break
				_clear_owner(cc, r0)
				_put(cc, r0, ch)
				cc += step)


# ---------------------------------------------------------------- formas

func rect(c0: int, r0: int, c1: int, r1: int, ch: String, filled := true) -> void:
	if is_block(ch) or ch == "D":
		return
	var x0 := mini(c0, c1)
	var x1 := maxi(c0, c1)
	var y0 := mini(r0, r1)
	var y1 := maxi(r0, r1)
	_as_stroke(func():
		for rr in range(y0, y1 + 1):
			for cc in range(x0, x1 + 1):
				if filled or rr == y0 or rr == y1 or cc == x0 or cc == x1:
					if _editable(cc, rr):
						_clear_owner(cc, rr)
						_put(cc, rr, ch))


func line(c0: int, r0: int, c1: int, r1: int, ch: String) -> void:
	if is_block(ch) or ch == "D":
		return
	_as_stroke(func():
		for p in line_cells(c0, r0, c1, r1):
			if _editable(p.x, p.y):
				_clear_owner(p.x, p.y)
				_put(p.x, p.y, ch))


static func line_cells(c0: int, r0: int, c1: int, r1: int) -> Array:
	var out: Array = []
	var dx := absi(c1 - c0)
	var dy := -absi(r1 - r0)
	var sx := 1 if c0 < c1 else -1
	var sy := 1 if r0 < r1 else -1
	var err := dx + dy
	var c := c0
	var r := r0
	while true:
		out.append(Vector2i(c, r))
		if c == c1 and r == r1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			c += sx
		if e2 <= dx:
			err += dx
			r += sy
	return out


## Balde: troca a região contígua do mesmo tipo por `ch` (só peças de um tile).
func fill(c: int, r: int, ch: String) -> void:
	if not _editable(c, r) or is_block(ch) or ch == "D":
		return
	var target: String = data.cell(c, r)
	if target == ch or is_block(target) or target == "D":
		return
	_as_stroke(func():
		var stack: Array = [Vector2i(c, r)]
		var seen := {}
		while not stack.is_empty():
			var p: Vector2i = stack.pop_back()
			if seen.has(p) or not _editable(p.x, p.y) or data.cell(p.x, p.y) != target:
				continue
			seen[p] = true
			_put(p.x, p.y, ch)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				stack.append(p + d))


# ---------------------------------------------------------------- seleção, cópia e cola

## Copia a região (cantos opostos): lista de strings.
func copy(c0: int, r0: int, c1: int, r1: int) -> Array:
	var x0: int = clampi(mini(c0, c1), 1, data.width() - 2)
	var x1: int = clampi(maxi(c0, c1), 1, data.width() - 2)
	var y0: int = clampi(mini(r0, r1), 1, data.height() - 2)
	var y1: int = clampi(maxi(r0, r1), 1, data.height() - 2)
	var out: Array = []
	for rr in range(y0, y1 + 1):
		var line := ""
		for cc in range(x0, x1 + 1):
			line += data.cell(cc, rr)
		out.append(line)
	return out


func clear_rect(c0: int, r0: int, c1: int, r1: int) -> void:
	_as_stroke(func():
		for rr in range(mini(r0, r1), maxi(r0, r1) + 1):
			for cc in range(mini(c0, c1), maxi(c0, c1) + 1):
				if _editable(cc, rr):
					_clear_owner(cc, rr)
					_put(cc, rr, "."))


## Cola com o canto superior esquerdo em (c, r). Espaços vazios do recorte não apagam nada.
## Só um coelho e uma porta: colar outro substitui o que já existe.
func paste(clip: Array, c: int, r: int) -> void:
	_as_stroke(func():
		var has_p := false
		var has_d := false
		for line in clip:
			has_p = has_p or String(line).contains("P")
			has_d = has_d or String(line).contains("D")
		if has_p:
			for rr in data.height():
				for cc in data.width():
					if data.cell(cc, rr) == "P":
						_put(cc, rr, ".")
		if has_d:
			for rr in data.height():
				for cc in data.width():
					if data.cell(cc, rr) == "D":
						_put(cc, rr, ".")
		for j in clip.size():
			var line: String = clip[j]
			for i in line.length():
				var ch := line[i]
				if ch == "." or not _editable(c + i, r + j):
					continue
				_clear_owner(c + i, r + j)
				_put(c + i, r + j, ch))


static func rotate_clip(clip: Array, dir: int) -> Array:
	var h := clip.size()
	if h == 0:
		return []
	var w: int = String(clip[0]).length()
	var out: Array = []
	var map: Dictionary = CW if dir > 0 else CCW
	for rr in w:
		var line := ""
		for cc in h:
			var src_c: int = rr if dir > 0 else w - 1 - rr
			var src_r: int = h - 1 - cc if dir > 0 else cc
			var g := String(clip[src_r])[src_c]
			line += map.get(g, g)
		out.append(line)
	return out


static func mirror_clip(clip: Array) -> Array:
	var out: Array = []
	for line in clip:
		var s := ""
		for i in range(String(line).length() - 1, -1, -1):
			var g := String(line)[i]
			s += MIRROR.get(g, g)
		out.append(s)
	return out


# ---------------------------------------------------------------- a sala inteira

func _snapshot_change(new_rows: Array) -> void:
	var before: Array = data.rows.duplicate()
	data.rows = new_rows
	if before == new_rows:
		return
	_push({"rows_before": before, "rows_after": new_rows.duplicate()})


## Gira a sala inteira 90° (dir > 0 horário). As peças com direção giram junto.
func rotate_room(dir: int) -> void:
	var w: int = data.width()
	var h: int = data.height()
	var full: Array = []
	for r in h:
		full.append(String(data.rows[r]))
	var rot := rotate_clip(full, dir)
	if rot.size() > LevelData.MAX_H or (rot.size() > 0 and String(rot[0]).length() > LevelData.MAX_W):
		return
	_snapshot_change(rot)


func mirror_room() -> void:
	_snapshot_change(mirror_clip(data.rows))


## Muda o tamanho mantendo o chão (canto inferior esquerdo). Cresce para cima e para a direita.
func resize(new_w: int, new_h: int) -> void:
	new_w = clampi(new_w, LevelData.MIN_W, LevelData.MAX_W)
	new_h = clampi(new_h, LevelData.MIN_H, LevelData.MAX_H)
	var old_w: int = data.width()
	var old_h: int = data.height()
	if new_w == old_w and new_h == old_h:
		return
	var out: Array = []
	for r in new_h:
		var line := ""
		for c in new_w:
			if r == 0 or r == new_h - 1 or c == 0 or c == new_w - 1:
				line += "#"
				continue
			# alinha pelo canto inferior esquerdo do interior
			var sr: int = r - (new_h - old_h)
			var sc := c
			line += data.cell(sc, sr) if (sr > 0 and sr < old_h - 1 and sc > 0 and sc < old_w - 1) else "."
		out.append(line)
	_snapshot_change(out)

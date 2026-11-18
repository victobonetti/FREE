extends Window
## Janela "Mundo" do editor (modo mundo, teste metroidvania, D100): o mapa em grade das salas.
## Clique numa casa para selecioná-la. Com uma sala selecionada: abrir no editor (Salvar grava na
## sala do mundo), mover pelo mapa (as setas; troca de lugar se a casa estiver ocupada), marcar
## como início ou tirar do mapa. Numa casa vazia: criar uma sala nova ali, ou pôr ali uma cópia da
## fase aberta no editor. Embaixo, os problemas do mapa (saída sem vizinha, vizinha sem a volta).
##
## As salas são fases comuns, com saídas na borda: X (livre) e Z (trancada até resolver). Uma saída
## no lado L leva à sala da casa vizinha desse lado, entrando pela saída do lado oposto.

const World := preload("res://scripts/world.gd")
const LevelData := preload("res://scripts/level_data.gd")

const CELL := Vector2(58, 36)
const GAP := 10.0

var ed                      # o Editor (editor.gd)
var world: Dictionary = {}
var sel := Vector2i.ZERO
var _grid: Control
var _info: Label
var _problems: Label
var _name_edit: LineEdit
var _lo := Vector2i.ZERO    # canto de cima à esquerda do que o mapa mostra
var _sides := {}


func setup(editor) -> void:
	ed = editor
	title = "Mundo (teste metroidvania)"
	size = Vector2i(560, 520)
	min_size = Vector2i(420, 360)
	exclusive = false
	transient = true
	visible = false
	close_requested.connect(hide)
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var pad := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + m, 8)
	bg.add_child(pad)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	pad.add_child(root)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_grid = Control.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_STOP
	_grid.draw.connect(_draw_grid)
	_grid.gui_input.connect(_grid_input)
	scroll.add_child(_grid)

	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_info)

	var row1 := HBoxContainer.new()
	root.add_child(row1)
	_button(row1, "Abrir no editor", _on_open)
	_button(row1, "Início aqui", _on_start)
	_button(row1, "Tirar do mapa", _on_remove)
	row1.add_child(VSeparator.new())
	for d in [["←", Vector2i(-1, 0)], ["↑", Vector2i(0, -1)], ["↓", Vector2i(0, 1)], ["→", Vector2i(1, 0)]]:
		_button(row1, d[0], _on_move.bind(d[1])).tooltip_text = "Mover a sala no mapa"

	var row2 := HBoxContainer.new()
	root.add_child(row2)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "nome da sala nova"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(_name_edit)
	_button(row2, "Sala nova aqui", _on_new_room)
	_button(row2, "Pôr a fase aberta aqui", _on_place_current)

	_problems = Label.new()
	_problems.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problems.add_theme_font_size_override("font_size", 11)
	_problems.modulate = Color(1, 0.8, 0.6)
	root.add_child(_problems)


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func open() -> void:
	world = World.load_world()
	if world.is_empty():
		world = {"start": "", "rooms": []}
	refresh()
	if not visible:
		popup_centered()
	else:
		grab_focus()


func refresh() -> void:
	_sides.clear()
	var lo := Vector2i(0, 0)
	var hi := Vector2i(3, 2)
	for r in World.rooms(world):
		var p := Vector2i(int(r["pos"][0]), int(r["pos"][1]))
		lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
		hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
	_lo = lo - Vector2i.ONE                    # uma casa de folga em volta
	var n := hi - lo + Vector2i(3, 3)
	_grid.custom_minimum_size = Vector2(n) * (CELL + Vector2(GAP, GAP)) + Vector2(GAP, GAP)
	_grid.queue_redraw()
	var id := World.room_at(world, sel)
	if id != "":
		var d = World.load_room_data(id)
		_info.text = "Casa (%d, %d): %s%s — %s" % [sel.x, sel.y, id, "  [início]" if id == str(world.get("start", "")) else "",
			(d.name if d != null else "arquivo não existe")]
	else:
		_info.text = "Casa (%d, %d): vazia. Crie uma sala nova ou ponha ali a fase aberta no editor." % [sel.x, sel.y]
	var probs := World.problems(world)
	_problems.text = "Tudo ligado." if probs.is_empty() else "Problemas:\n· " + "\n· ".join(probs)


func _sides_of(id: String) -> Array:
	if not _sides.has(id):
		var d = World.load_room_data(id)
		_sides[id] = World.exit_sides(d.rows) if d != null else []
	return _sides[id]


func _cell_rect(p: Vector2i) -> Rect2:
	return Rect2(Vector2(GAP, GAP) + Vector2(p - _lo) * (CELL + Vector2(GAP, GAP)), CELL)


func _draw_grid() -> void:
	var font := ThemeDB.fallback_font
	var n := Vector2i((_grid.custom_minimum_size - Vector2(GAP, GAP)) / (CELL + Vector2(GAP, GAP)))
	for y in n.y:
		for x in n.x:
			var p := _lo + Vector2i(x, y)
			var r := _cell_rect(p)
			var id := World.room_at(world, p)
			if id == "":
				_grid.draw_rect(r, Color(1, 1, 1, 0.06))
			else:
				var start := id == str(world.get("start", ""))
				_grid.draw_rect(r, Color("3a3a52") if not start else Color("5a5030"))
				_grid.draw_string(font, r.position + Vector2(4, 14), id, HORIZONTAL_ALIGNMENT_LEFT, CELL.x - 6, 11)
				if start:
					_grid.draw_string(font, r.position + Vector2(4, 28), "início", HORIZONTAL_ALIGNMENT_LEFT, CELL.x - 6, 10, Color("f3cf3b"))
				for sd in _sides_of(id):
					var v := Vector2(World.SIDES[sd])
					var c := r.get_center() + v * CELL / 2.0
					var ok := World.neighbor(world, id, sd) != ""
					_grid.draw_line(c, c + v * GAP / 2.0, Color("f3cf3b") if ok else Color("ff6a5a"), 3.0)
			if p == sel:
				_grid.draw_rect(r.grow(2), Color.WHITE, false, 2.0)


func _grid_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var q: Vector2 = (e.position - Vector2(GAP, GAP)) / (CELL + Vector2(GAP, GAP))
		sel = _lo + Vector2i(floori(q.x), floori(q.y))
		refresh()
		if e.double_click and World.room_at(world, sel) != "":
			_on_open()


func _save() -> void:
	if not World.save_world(world):
		ed.toast("Não consegui salvar o mapa do mundo")


func _on_open() -> void:
	var id := World.room_at(world, sel)
	if id == "":
		return
	var d = World.load_room_data(id)
	if d == null:
		ed.toast("A sala %s não tem arquivo" % id)
		return
	ed.open_world_room(id, d)


func _on_start() -> void:
	var id := World.room_at(world, sel)
	if id != "":
		world["start"] = id
		_save()
		refresh()


func _on_remove() -> void:
	var id := World.room_at(world, sel)
	if id == "":
		return
	var rs: Array = World.rooms(world)
	for i in rs.size():
		if str(rs[i]["id"]) == id:
			rs.remove_at(i)
			break
	if str(world.get("start", "")) == id:
		world["start"] = str(rs[0]["id"]) if not rs.is_empty() else ""
	_save()
	ed.toast("%s saiu do mapa (o arquivo da sala continua)" % id)
	refresh()


func _on_move(d: Vector2i) -> void:
	var id := World.room_at(world, sel)
	if id == "":
		return
	var to := sel + d
	var other := World.room_at(world, to)
	for r in World.rooms(world):
		if str(r["id"]) == id:
			r["pos"] = [to.x, to.y]
		elif other != "" and str(r["id"]) == other:
			r["pos"] = [sel.x, sel.y]
	sel = to
	_save()
	refresh()


func _add_room(data: RefCounted) -> void:
	if World.room_at(world, sel) != "":
		ed.toast("Essa casa já tem sala")
		return
	var id := World.free_id(world, data.name)
	if not World.save_room(id, data):
		ed.toast("Não consegui salvar a sala")
		return
	world["rooms"].append({"id": id, "pos": [sel.x, sel.y]})
	if str(world.get("start", "")) == "":
		world["start"] = id
	_save()
	refresh()
	ed.open_world_room(id, World.load_room_data(id))


func _on_new_room() -> void:
	var d: RefCounted = LevelData.blank(24, 14)
	d.name = _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "Sala"
	_add_room(d)


func _on_place_current() -> void:
	if ed.model == null:
		return
	var d: RefCounted = LevelData.from_json(ed.model.data.to_json())
	if _name_edit.text.strip_edges() != "":
		d.name = _name_edit.text.strip_edges()
	_add_room(d)

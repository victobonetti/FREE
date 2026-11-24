extends Window
## Janela "Mundo" do editor (D100, D120): o mapa do mundo, com as salas em escala.
## Clique numa sala para selecioná-la, ou numa casa vazia (uma tela, 40×22 tiles). Com uma sala
## selecionada: abrir no editor (Salvar grava na sala do mundo), mover (as setas andam uma tela; com
## "ajuste fino", um tile), marcar como início ou tirar do mapa. Numa casa vazia: criar uma sala nova
## ali, ou pôr ali uma cópia da fase aberta no editor. Embaixo, os problemas do mapa (sala sobreposta,
## saída sem vizinha, vizinha sem a saída de volta).
##
## As salas são fases comuns, com saídas na borda: X (livre) e Z (trancada até resolver). Uma saída leva
## à sala que encosta do outro lado dela (world.gd).

const World := preload("res://scripts/world.gd")
const LevelData := preload("res://scripts/level_data.gd")

const K := 2.0          # px da janela por tile do mundo
const PAD := 12.0

var ed                      # o Editor (editor.gd)
var world: Dictionary = {}
var sel_id := ""
var sel_cell := Vector2i.ZERO   # a casa vazia escolhida (em telas)
var _grid: Control
var _info: Label
var _problems: Label
var _name_edit: LineEdit
var _fine: CheckBox
var _lo := Vector2i.ZERO        # canto (em tiles) do que o mapa mostra


func setup(editor) -> void:
	ed = editor
	title = "Mundo"
	size = Vector2i(760, 600)
	min_size = Vector2i(460, 380)
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
	_fine = CheckBox.new()
	_fine.text = "ajuste fino (1 tile)"
	_fine.focus_mode = Control.FOCUS_NONE
	row1.add_child(_fine)

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
		world = {"version": 2, "start": "", "rooms": []}
	refresh()
	if not visible:
		popup_centered()
	else:
		grab_focus()


func refresh() -> void:
	var lo := Vector2i(0, 0)
	var hi := World.UNIT * 3
	for r in World.rooms(world):
		var rr := World.rect_of(world, str(r["id"]))
		lo = Vector2i(mini(lo.x, rr.position.x), mini(lo.y, rr.position.y))
		hi = Vector2i(maxi(hi.x, rr.end.x), maxi(hi.y, rr.end.y))
	_lo = lo - World.UNIT
	var span := hi + World.UNIT - _lo
	_grid.custom_minimum_size = Vector2(span) * K + Vector2(PAD, PAD) * 2.0
	_grid.queue_redraw()
	if sel_id != "":
		var d = World.load_room_data(sel_id)
		var p := World.pos_of(world, sel_id)
		_info.text = "%s%s — %s, em (%d, %d) tiles, %d×%d" % [sel_id, "  [início]" if sel_id == str(world.get("start", "")) else "",
			(d.name if d != null else "arquivo não existe"), p.x, p.y, World.info(sel_id)["size"].x, World.info(sel_id)["size"].y]
	else:
		_info.text = "Casa (%d, %d): vazia. Crie uma sala nova ou ponha ali a fase aberta no editor." % [sel_cell.x, sel_cell.y]
	var probs := World.problems(world)
	_problems.text = "Tudo ligado." if probs.is_empty() else "Problemas:\n· " + "\n· ".join(probs.slice(0, 12)) + \
		("\n· …" if probs.size() > 12 else "")


func _to_px(t: Vector2i) -> Vector2:
	return Vector2(PAD, PAD) + Vector2(t - _lo) * K


func _draw_grid() -> void:
	var font := ThemeDB.fallback_font
	var span := (_grid.custom_minimum_size - Vector2(PAD, PAD) * 2.0) / K
	# a grade de telas
	var u := World.UNIT
	var c0 := floori(float(_lo.x) / u.x)
	var r0 := floori(float(_lo.y) / u.y)
	for cx in range(c0, c0 + int(span.x / u.x) + 2):
		for ry in range(r0, r0 + int(span.y / u.y) + 2):
			var rr := Rect2(_to_px(Vector2i(cx * u.x, ry * u.y)), Vector2(u) * K)
			_grid.draw_rect(rr, Color(1, 1, 1, 0.04), false, 1.0)
			if sel_id == "" and Vector2i(cx, ry) == sel_cell:
				_grid.draw_rect(rr.grow(-1), Color.WHITE, false, 2.0)
	for r in World.rooms(world):
		var id := str(r["id"])
		var rect := World.rect_of(world, id)
		var rr := Rect2(_to_px(rect.position), Vector2(rect.size) * K)
		var start := id == str(world.get("start", ""))
		_grid.draw_rect(rr, Color("3a3a52") if not start else Color("5a5030"))
		if World.info(id)["rose"]:
			_grid.draw_rect(rr.grow(-2), Color("5af0dc", 0.5), false, 1.0)
		_grid.draw_string(font, rr.position + Vector2(3, 12), id, HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 4, 10)
		var exs: Array = World.info(id)["exits"]
		for k in exs.size():
			var ew := World.exit_world(world, id, k)
			var er: Rect2i = ew["rect"]
			var ok := not World.link(world, id, k).is_empty()
			_grid.draw_rect(Rect2(_to_px(er.position), Vector2(er.size) * K).grow(1.0), Color("f3cf3b") if ok else Color("ff6a5a"))
		if id == sel_id:
			_grid.draw_rect(rr.grow(2), Color.WHITE, false, 2.0)


func _grid_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var t := Vector2i(((e.position - Vector2(PAD, PAD)) / K).floor()) + _lo
		sel_id = World.room_at_cell(world, t)
		sel_cell = Vector2i(floori(float(t.x) / World.UNIT.x), floori(float(t.y) / World.UNIT.y))
		refresh()
		if e.double_click and sel_id != "":
			_on_open()


func _save() -> void:
	if not World.save_world(world):
		ed.toast("Não consegui salvar o mapa do mundo")


func _on_open() -> void:
	if sel_id == "":
		return
	var d = World.load_room_data(sel_id)
	if d == null:
		ed.toast("A sala %s não tem arquivo" % sel_id)
		return
	ed.open_world_room(sel_id, d)


func _on_start() -> void:
	if sel_id != "":
		world["start"] = sel_id
		_save()
		refresh()


func _on_remove() -> void:
	if sel_id == "":
		return
	var rs: Array = World.rooms(world)
	for i in rs.size():
		if str(rs[i]["id"]) == sel_id:
			rs.remove_at(i)
			break
	if str(world.get("start", "")) == sel_id:
		world["start"] = str(rs[0]["id"]) if not rs.is_empty() else ""
	_save()
	ed.toast("%s saiu do mapa (o arquivo da sala continua)" % sel_id)
	sel_id = ""
	refresh()


func _on_move(d: Vector2i) -> void:
	if sel_id == "":
		return
	var step := d if _fine.button_pressed else d * World.UNIT
	World.set_pos(world, sel_id, World.pos_of(world, sel_id) + step)
	_save()
	refresh()


func _add_room(data: RefCounted) -> void:
	if sel_id != "":
		ed.toast("Escolha uma casa vazia")
		return
	var id := World.free_id(world, data.name)
	if not World.save_room(id, data):
		ed.toast("Não consegui salvar a sala")
		return
	var p := sel_cell * World.UNIT
	world["rooms"].append({"id": id, "pos": [p.x, p.y]})
	if str(world.get("start", "")) == "":
		world["start"] = id
	_save()
	sel_id = id
	refresh()
	ed.open_world_room(id, World.load_room_data(id))


func _on_new_room() -> void:
	var d: RefCounted = LevelData.blank(World.UNIT.x, World.UNIT.y)
	d.name = _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "Sala"
	_add_room(d)


func _on_place_current() -> void:
	if ed.model == null:
		return
	var d: RefCounted = LevelData.from_json(ed.model.data.to_json())
	if _name_edit.text.strip_edges() != "":
		d.name = _name_edit.text.strip_edges()
	_add_room(d)

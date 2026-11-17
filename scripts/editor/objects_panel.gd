extends Window
## Janela "Objetos" do editor: lista, cria, edita e apaga placas de espinhos, conectores, chapas
## soltas, botões, esteiras, molas, ventiladores e jatos de vapor (`Objects`). Não bloqueia o resto:
## dá para deixá-la aberta, selecionar um retângulo na grade com a ferramenta de seleção e
## clicar em "Usar a seleção da grade". Também edita o roteiro do Gatsby, como texto JSON.
##
## Tudo passa pelo modelo (`EditModel`), então desfazer e refazer valem para os objetos.

const Objects := preload("res://scripts/editor/objects.gd")

var ed                      # o Editor (editor.gd)
var kind := "crushers"
var sel := -1

var _type_opt: OptionButton
var _list: ItemList
var _form: VBoxContainer
var _info: Label
var _building := false
var _dump := ""             # o que a janela está mostrando, para só refazer quando mudar de fora
var _script_dialog: ConfirmationDialog
var _script_text: TextEdit


func setup(editor) -> void:
	ed = editor
	title = "Objetos da fase"
	size = Vector2i(440, 560)
	min_size = Vector2i(380, 360)
	exclusive = false
	transient = true
	visible = false
	close_requested.connect(func(): hide(); _sync_overlay())
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

	var top := HBoxContainer.new()
	root.add_child(top)
	_type_opt = OptionButton.new()
	_type_opt.focus_mode = Control.FOCUS_NONE
	for k in Objects.ORDER:
		_type_opt.add_item(Objects.label(k))
	_type_opt.item_selected.connect(func(i):
		kind = Objects.ORDER[i]
		sel = -1
		refresh())
	_type_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_type_opt)
	_button(top, "Novo", _on_new)
	_button(top, "Duplicar", _on_duplicate)
	_button(top, "Excluir", _on_delete)

	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 110)
	_list.item_selected.connect(func(i):
		sel = i
		_build_form()
		_sync_overlay())
	root.add_child(_list)

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 4)
	sc.add_child(_form)

	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 12)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_info)
	var bottom := HBoxContainer.new()
	root.add_child(bottom)
	var gb := _button(bottom, "Roteiro do Gatsby (JSON)…", _on_script)
	gb.tooltip_text = "O roteiro do boss Gatsby é um texto JSON ({\"start\": [...], \"script\": [...]}). Veja o topo de boss_gatsby.gd."

	_script_dialog = ConfirmationDialog.new()
	_script_dialog.title = "Roteiro do Gatsby"
	_script_dialog.ok_button_text = "Aplicar"
	_script_dialog.cancel_button_text = "Cancelar"
	_script_dialog.size = Vector2i(560, 440)
	_script_text = TextEdit.new()
	_script_text.custom_minimum_size = Vector2(520, 360)
	_script_dialog.add_child(_script_text)
	_script_dialog.confirmed.connect(_apply_script)
	add_child(_script_dialog)


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func open() -> void:
	refresh()
	if not visible:
		var vp: Vector2 = get_parent().get_viewport_rect().size
		popup(Rect2i(Vector2i(int(vp.x) - size.x - 6, 44), Vector2i(size.x, int(vp.y) - 52)))
	else:
		grab_focus()


# ---------------------------------------------------------------- lista e formulário

## Chamado a cada mudança do modelo: refaz a janela só se os objetos mudaram por fora (desfazer).
func refresh_if_changed() -> void:
	if visible and ed != null and ed.model != null and str(ed.model.objects_of(kind)) != _dump:
		refresh()


func refresh() -> void:
	if ed == null or ed.model == null:
		return
	_type_opt.select(Objects.ORDER.find(kind))
	var items: Array = ed.model.objects_of(kind)
	_dump = str(items)
	_list.clear()
	for i in items.size():
		_list.add_item(Objects.summary(kind, i, items[i]))
	if sel >= items.size():
		sel = items.size() - 1
	if sel >= 0:
		_list.select(sel)
	_build_form()
	_sync_overlay()


func _sync_overlay() -> void:
	if ed != null and ed.canvas != null:
		ed.canvas.overlay_sel = [kind, sel] if visible else ["", -1]
		ed.canvas.refresh()


func _clear_form() -> void:
	for c in _form.get_children():
		c.queue_free()


func _build_form() -> void:
	_clear_form()
	var items: Array = ed.model.objects_of(kind)
	if sel < 0 or sel >= items.size():
		_info.text = "Nenhum %s nesta fase. 'Novo' cria um (na seleção da grade, se houver)." % Objects.label(kind).to_lower()
		return
	_info.text = ""
	_building = true
	var o: Variant = items[sel]
	for f in Objects.TYPES[kind]["fields"]:
		var val: Variant = o if Objects.is_scalar(kind) else (o as Dictionary).get(f["key"], f.get("def", null))
		# o nome em cima e os controles embaixo: o formulário cabe numa janela estreita
		var lb := Label.new()
		lb.text = f["label"]
		lb.modulate = Color(1, 1, 1, 0.7)
		lb.add_theme_font_size_override("font_size", 11)
		_form.add_child(lb)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		_form.add_child(row)
		match f["kind"]:
			"rect":
				var r := Objects.rect_of(kind, o)
				var names := ["col", "lin", "larg", "alt"]
				for q in 4:
					row.add_child(_num(r[q] if not r.is_empty() else 0, 0 if q < 2 else 1, 512, 1, func(v):
						var cur := Objects.rect_of(kind, ed.model.objects_of(kind)[sel])
						cur[q] = int(v)
						_commit(f["key"], cur), names[q]))
				_button(row, "Usar a seleção", func(): _use_selection(f["key"]))
			"pt":
				var p: Array = val if val is Array else [0, 0]
				for q in 2:
					row.add_child(_num(p[q], 0, 512, 1, func(v):
						var cur: Array = (ed.model.objects_of(kind)[sel] as Dictionary).get(f["key"], [0, 0]).duplicate()
						cur[q] = int(v)
						_commit(f["key"], cur), ["col", "lin"][q]))
				_button(row, "Usar a seleção", func(): _use_selection_point(f["key"]))
			"int":
				row.add_child(_num(int(val), f["min"], f["max"], 1, func(v): _commit(f["key"], int(v)), ""))
			"float":
				row.add_child(_num(float(val), f["min"], f["max"], f["step"], func(v): _commit(f["key"], float(v)), ""))
			"choice":
				var ob := OptionButton.new()
				ob.focus_mode = Control.FOCUS_NONE
				var cur_i := 0
				for i in f["opts"].size():
					ob.add_item(f["opts"][i]["t"])
					if f["opts"][i]["v"] == val:
						cur_i = i
				ob.select(cur_i)
				ob.item_selected.connect(func(i): _commit(f["key"], f["opts"][i]["v"]))
				row.add_child(ob)
	_building = false


func _num(v: float, lo: float, hi: float, step: float, cb: Callable, tip: String) -> SpinBox:
	var sbx := SpinBox.new()
	sbx.min_value = lo
	sbx.max_value = hi
	sbx.step = step
	sbx.value = v
	sbx.custom_minimum_size = Vector2(62, 0)
	sbx.tooltip_text = tip
	sbx.value_changed.connect(func(x):
		if not _building:
			cb.call(x))
	return sbx


func _commit(key: String, value: Variant) -> void:
	if _building or sel < 0:
		return
	ed.model.set_object_field(kind, sel, key, value)
	var items: Array = ed.model.objects_of(kind)
	_dump = str(items)
	if sel < items.size():
		_list.set_item_text(sel, Objects.summary(kind, sel, items[sel]))
	ed.objects_changed()
	_sync_overlay()


# ---------------------------------------------------------------- ações

## O retângulo selecionado na grade como [coluna, linha, largura, altura], ou [] se não há.
func _selection_rect() -> Array:
	var t = ed.tools
	if not t.has_selection:
		return []
	var a: Vector2i = t.sel_a
	var b: Vector2i = t.sel_b
	return [mini(a.x, b.x), mini(a.y, b.y), absi(b.x - a.x) + 1, absi(b.y - a.y) + 1]


func _use_selection(key: String) -> void:
	var r := _selection_rect()
	if r.is_empty():
		ed.toast("Selecione um retângulo na grade (ferramenta Seleção) primeiro")
		return
	if sel < 0:
		return
	_commit(key, r)
	refresh()


func _use_selection_point(key: String) -> void:
	var r := _selection_rect()
	if r.is_empty():
		ed.toast("Selecione na grade onde fica o encaixe (ferramenta Seleção) primeiro")
		return
	_commit(key, [r[0], r[1]])
	refresh()


func _on_new() -> void:
	var r := _selection_rect()
	var c := 4
	var row := 4
	if not r.is_empty():
		c = r[0]
		row = r[1]
	else:
		c = ed.model.data.width() / 2
		row = ed.model.data.height() / 2
	var o: Variant = Objects.make_default(kind, c, row)
	if not r.is_empty() and kind != "movers":
		o = Objects.set_rect(kind, o, r)
	sel = ed.model.add_object(kind, o)
	ed.objects_changed()
	refresh()


func _on_duplicate() -> void:
	var items: Array = ed.model.objects_of(kind)
	if sel < 0 or sel >= items.size():
		return
	var copy: Variant = items[sel].duplicate(true)
	var r := Objects.rect_of(kind, copy)
	if not r.is_empty():
		r[0] += 1
		r[1] += 1
		copy = Objects.set_rect(kind, copy, r)
	sel = ed.model.add_object(kind, copy)
	ed.objects_changed()
	refresh()


func _on_delete() -> void:
	if sel < 0:
		return
	ed.model.remove_object(kind, sel)
	sel = -1
	ed.objects_changed()
	refresh()


func _on_script() -> void:
	var g: Variant = ed.model.data.extra.get("gatsby", null)
	_script_text.text = JSON.stringify(g, "  ") if g != null else '{"start": [3, 3], "script": []}'
	_script_dialog.popup_centered()


func _apply_script() -> void:
	var parsed: Variant = JSON.parse_string(_script_text.text)
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed.get("script", null) is Array) or not (parsed.get("start", null) is Array):
		ed.toast("Roteiro inválido: precisa ser {\"start\": [coluna, linha], \"script\": [...]}")
		return
	ed.model.set_extra_value("gatsby", parsed)
	ed.objects_changed()
	ed.toast("Roteiro do Gatsby aplicado")

extends Control
## A tela do editor: barra de cima, ferramentas e peças à esquerda, a grade no meio,
## propriedades e problemas à direita. Toda a lógica de edição está em EditModel/EditTools;
## aqui só há interface, arquivos e atalhos.

const LevelData := preload("res://scripts/level_data.gd")
const LevelStore := preload("res://scripts/level_store.gd")
const Levels := preload("res://scripts/levels.gd")
const CampaignStore := preload("res://scripts/campaign_store.gd")
const Replay := preload("res://scripts/replay.gd")
const EditModel := preload("res://scripts/editor/edit_model.gd")
const EditTools := preload("res://scripts/editor/edit_tools.gd")
const EditorCanvas := preload("res://scripts/editor/editor_canvas.gd")
const GlyphButton := preload("res://scripts/editor/glyph_button.gd")
const GlyphDraw := preload("res://scripts/editor/glyph_draw.gd")

const DESIGN_SIZE := Vector2i(960, 540)

## Bosses que uma fase pode ter: o comportamento é código (o ator); o editor só liga a fase a ele.
const BOSSES := [
	{"name": "Nenhum"},
	{"name": "Jeffrey, o esquilo", "actors": ["res://scripts/boss_squirrel.gd"],
		"boss_music": "res://music/boss-rush-groove.mp3", "needs_spin": true},
	# o roteiro dele (campo "gatsby") e as placas ("crushers") ainda são escritos à mão no JSON
	{"name": "Gatsby, o texugo", "actors": ["res://scripts/boss_gatsby.gd"]},
]

signal exit_requested
signal play_requested(def: Dictionary)

var model: RefCounted
var tools: RefCounted
var canvas: Control
var current_id := ""                    # arquivo em user://levels, ou "" se ainda não foi salvo
var campaign_id := ""                   # fase da campanha que está aberta, ou ""
var last_replay := {}                   # replay da última vitória (vale só para a versão vencida)
var playing := false

var _tool_buttons := {}
var _glyph_buttons := {}
var _name_edit: LineEdit
var _hint_edit: LineEdit
var _hint_touch_edit: LineEdit
var _boss_option: OptionButton
var _spin_label: Label
var _rotate_check: CheckBox
var _limiter_check: CheckBox
var _open_check: CheckBox
var _rot_spin: SpinBox
var _reload_spin: SpinBox
var _limit_spin: SpinBox
var _w_spin: SpinBox
var _h_spin: SpinBox
var _verified_label: Label
var _problems: ItemList
var _status: Label
var _toast: Label
var _toast_t := 0.0
var _undo_btn: Button
var _campaign_btn: Button
var _dialog_campaign: AcceptDialog
var _campaign_list: ItemList
var _campaign_info: Label
var _redo_btn: Button
var _dialog_open: ConfirmationDialog
var _open_list: ItemList
var _open_entries: Array = []
var _dialog_import: ConfirmationDialog
var _import_text: TextEdit
var _dialog_export: AcceptDialog
var _export_text: TextEdit
var _dialog_confirm: ConfirmationDialog
var _confirm_action := Callable()
var _syncing := false
var _last_version := -1


func _ready() -> void:
	var th := Theme.new()
	th.default_font_size = 13
	theme = th
	_resize()
	get_viewport().size_changed.connect(_resize)
	_build()
	new_level()


## Debaixo de uma CanvasLayer os anchors não valem: o tamanho vem da janela.
func _resize() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


# ---------------------------------------------------------------- montagem da interface

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("14141c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 4
	root.offset_top = 4
	root.offset_right = -4
	root.offset_bottom = -4
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	# --- barra de cima
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	root.add_child(top)
	_btn(top, "Novo", _on_new)
	_btn(top, "Abrir", _on_open)
	_btn(top, "Salvar", _on_save)
	_btn(top, "Salvar como", _on_save_as)
	top.add_child(VSeparator.new())
	_undo_btn = _btn(top, "Desfazer", _on_undo)
	_redo_btn = _btn(top, "Refazer", _on_redo)
	top.add_child(VSeparator.new())
	var play := _btn(top, "▶ Jogar", _on_play)
	play.tooltip_text = "Testa a fase (P). Vencer uma vez marca a fase como verificada."
	top.add_child(VSeparator.new())
	_btn(top, "Exportar código", _on_export)
	_btn(top, "Importar código", _on_import)
	if OS.is_debug_build():
		top.add_child(VSeparator.new())
		_campaign_btn = _btn(top, "Campanha…", _show_campaign)
		_campaign_btn.tooltip_text = "Só em desenvolvimento: a história em ordem; canonizar, mudar a ordem, tirar."
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_btn(top, "Voltar", _on_exit)

	# --- meio
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 6)
	root.add_child(mid)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(214, 0)
	mid.add_child(left)
	_build_left(left)

	canvas = EditorCanvas.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.hovered.connect(_on_hover)
	mid.add_child(canvas)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(236, 0)
	mid.add_child(right)
	_build_right(right)

	# --- barra de baixo
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.modulate = Color(1, 1, 1, 0.7)
	root.add_child(_status)

	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 16)
	_toast.add_theme_color_override("font_color", Color("ffe066"))
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position = Vector2(DESIGN_SIZE.x * 0.5 - 200, 60)
	_toast.size = Vector2(400, 24)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)

	_build_dialogs()


func _btn(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _title(parent: Node, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.modulate = Color(1, 1, 1, 0.55)
	parent.add_child(l)


func _build_left(left: VBoxContainer) -> void:
	_title(left, "FERRAMENTAS")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	left.add_child(grid)
	for t in EditTools.TOOL_NAMES:
		var b := Button.new()
		b.text = EditTools.TOOL_NAMES[t]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_tool.bind(t))
		grid.add_child(b)
		_tool_buttons[t] = b
	_title(left, "PEÇAS")
	var pal := GridContainer.new()
	pal.columns = 7
	pal.add_theme_constant_override("h_separation", 2)
	pal.add_theme_constant_override("v_separation", 2)
	left.add_child(pal)
	var all := ["#", "~", "o", "^", ">", "v", "<", "=", "}", "_", "{", "|", "-", "D",
		"P", "B", "S", "1", "2", "3", "4", "5", "6", "7", "8", "9",
		"¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹",
		"a", "b", "c", "d", "e", "f", "g", "h", "i"]
	for g in all:
		var gb := GlyphButton.new()
		gb.setup(g)
		gb.pressed.connect(_on_glyph.bind(g))
		pal.add_child(gb)
		_glyph_buttons[g] = gb
	var help := Label.new()
	help.text = "Botão direito apaga.\nRoda: zoom. Meio ou Espaço+arrastar: mover.\nCtrl+Z/Y desfaz/refaz. P joga."
	help.add_theme_font_size_override("font_size", 11)
	help.modulate = Color(1, 1, 1, 0.45)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(help)


func _build_right(right: VBoxContainer) -> void:
	_title(right, "FASE")
	_name_edit = _line(right, "Nome", func(t): _prop("name", t))
	_hint_edit = _line(right, "Dica de texto", func(t): _prop("hint", t))
	_hint_touch_edit = _line(right, "Dica no celular", func(t): _extra("hint_touch", t))
	var br := HBoxContainer.new()
	right.add_child(br)
	var bl := Label.new()
	bl.text = "Boss"
	bl.add_theme_font_size_override("font_size", 12)
	bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.add_child(bl)
	_boss_option = OptionButton.new()
	_boss_option.focus_mode = Control.FOCUS_NONE
	for b in BOSSES:
		_boss_option.add_item(b["name"])
	_boss_option.item_selected.connect(_on_boss)
	br.add_child(_boss_option)
	var sr := HBoxContainer.new()
	right.add_child(sr)
	_spin_label = Label.new()
	_spin_label.add_theme_font_size_override("font_size", 12)
	_spin_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sr.add_child(_spin_label)
	var spb := _btn(sr, "Da seleção", _on_spin_from_selection)
	spb.tooltip_text = "Bloco giratório (sala de boss): selecione um quadrado de parede. Q/E giram só ele e os espinhos encostados."
	_btn(sr, "Tirar", func(): _extra("spin_block", null); _sync_props())
	_rotate_check = _check(right, "Giro permitido", func(v): _prop("rotate", v))
	_limiter_check = _check(right, "Limitador (desfaz o giro sozinho)", func(v): _prop("limiter", v))
	_open_check = _check(right, "Porta aberta (sem caixa)", func(v): _prop("door_open", v))
	var rr := HBoxContainer.new()
	right.add_child(rr)
	var rl := Label.new()
	rl.text = "Rotação inicial"
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rr.add_child(rl)
	_rot_spin = SpinBox.new()
	_rot_spin.min_value = -3
	_rot_spin.max_value = 3
	_rot_spin.value_changed.connect(func(v): _prop("start_rot", int(v)))
	rr.add_child(_rot_spin)
	_reload_spin = _time_row(right, "Recarga do giro", func(v): _prop("reload_time", v))
	_limit_spin = _time_row(right, "Tempo do limitador", func(v): _prop("limiter_time", v))
	_verified_label = Label.new()
	_verified_label.add_theme_font_size_override("font_size", 12)
	right.add_child(_verified_label)

	_title(right, "SALA")
	var sz := HBoxContainer.new()
	right.add_child(sz)
	_w_spin = _spin(sz, LevelData.MIN_W, LevelData.MAX_W)
	var x := Label.new()
	x.text = "×"
	sz.add_child(x)
	_h_spin = _spin(sz, LevelData.MIN_H, LevelData.MAX_H)
	_btn(sz, "Aplicar", _on_resize)
	var ops := HBoxContainer.new()
	right.add_child(ops)
	_btn(ops, "Girar ↻", func(): model.rotate_room(1))
	_btn(ops, "Girar ↺", func(): model.rotate_room(-1))
	_btn(ops, "Espelhar", func(): model.mirror_room())
	var sel := HBoxContainer.new()
	right.add_child(sel)
	_btn(sel, "Copiar", _on_copy)
	_btn(sel, "Recortar", _on_cut)
	_btn(sel, "Colar", _on_paste)

	_title(right, "PROBLEMAS (clique para ir)")
	_problems = ItemList.new()
	_problems.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_problems.add_theme_font_size_override("font_size", 11)
	_problems.auto_height = false
	_problems.item_selected.connect(_on_problem)
	right.add_child(_problems)


func _line(parent: Node, label: String, cb: Callable) -> LineEdit:
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 12)
	parent.add_child(l)
	var e := LineEdit.new()
	e.text_changed.connect(cb)
	e.focus_mode = Control.FOCUS_CLICK
	parent.add_child(e)
	return e


func _check(parent: Node, text: String, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 12)
	c.toggled.connect(cb)
	parent.add_child(c)
	return c


func _time_row(parent: Node, text: String, cb: Callable) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var s := SpinBox.new()
	s.min_value = LevelData.MIN_TIME
	s.max_value = LevelData.MAX_TIME
	s.step = 0.1
	s.suffix = " s"
	s.value = 2.5
	s.custom_minimum_size = Vector2(96, 0)
	s.value_changed.connect(cb)
	row.add_child(s)
	return s


func _spin(parent: Node, lo: int, hi: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.custom_minimum_size = Vector2(70, 0)
	parent.add_child(s)
	return s


func _build_dialogs() -> void:
	_dialog_open = ConfirmationDialog.new()
	_dialog_open.title = "Abrir fase"
	_dialog_open.ok_button_text = "Abrir"
	_dialog_open.cancel_button_text = "Cancelar"
	_dialog_open.size = Vector2i(420, 420)
	_open_list = ItemList.new()
	_open_list.custom_minimum_size = Vector2(380, 340)
	_open_list.item_activated.connect(func(_i): _dialog_open.hide(); _do_open())
	_dialog_open.add_child(_open_list)
	_dialog_open.confirmed.connect(_do_open)
	add_child(_dialog_open)

	_build_campaign_dialog()

	_dialog_import = ConfirmationDialog.new()
	_dialog_import.title = "Importar código"
	_dialog_import.ok_button_text = "Importar"
	_dialog_import.cancel_button_text = "Cancelar"
	_dialog_import.size = Vector2i(520, 300)
	_import_text = TextEdit.new()
	_import_text.custom_minimum_size = Vector2(480, 200)
	_import_text.placeholder_text = "Cole aqui o código (começa com FREE1:)"
	_dialog_import.add_child(_import_text)
	_dialog_import.confirmed.connect(_do_import)
	add_child(_dialog_import)

	_dialog_export = AcceptDialog.new()
	_dialog_export.title = "Código da fase"
	_dialog_export.ok_button_text = "Fechar"
	_dialog_export.size = Vector2i(520, 300)
	_export_text = TextEdit.new()
	_export_text.custom_minimum_size = Vector2(480, 200)
	_export_text.editable = false
	_export_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_dialog_export.add_child(_export_text)
	add_child(_dialog_export)

	_dialog_confirm = ConfirmationDialog.new()
	_dialog_confirm.ok_button_text = "Sim"
	_dialog_confirm.cancel_button_text = "Não"
	_dialog_confirm.confirmed.connect(func(): _confirm_action.call())
	add_child(_dialog_confirm)


# ---------------------------------------------------------------- estado

func new_level() -> void:
	load_level(LevelData.blank(24, 14), "")


func load_level(level: RefCounted, id: String, campaign := "") -> void:
	campaign_id = campaign
	last_replay = CampaignStore.load_replay(campaign) if campaign != "" else {}
	if model == null:
		model = EditModel.new(level)
		tools = EditTools.new(model)
		canvas.setup(model, tools)
	else:
		model.load_level(level)
	current_id = id
	tools.has_selection = false
	tools.pasting = false
	_select_glyph("#")
	_sync_props()
	call_deferred("_fit")


func _fit() -> void:
	canvas.fit()


func _sync_props() -> void:
	_syncing = true
	var d = model.data
	_name_edit.text = d.name
	_hint_edit.text = d.hint
	_rotate_check.button_pressed = d.rotate
	_limiter_check.button_pressed = d.limiter
	_open_check.button_pressed = d.door_open
	_rot_spin.value = d.start_rot
	_hint_touch_edit.text = str(d.extra.get("hint_touch", ""))
	var boss_i := 0
	for k in BOSSES.size():
		if BOSSES[k].has("actors") and d.extra.get("actors", []) == BOSSES[k]["actors"]:
			boss_i = k
	_boss_option.select(boss_i)
	var sb = d.extra.get("spin_block", null)
	_spin_label.text = "Bloco giratório: %d×%d em (%d, %d)" % [int(sb[2]), int(sb[2]), int(sb[0]), int(sb[1])] if sb is Array else "Bloco giratório: nenhum"
	_reload_spin.value = d.reload_time
	_limit_spin.value = d.limiter_time
	_limit_spin.editable = d.limiter
	_w_spin.value = d.width()
	_h_spin.value = d.height()
	_syncing = false


## Campos guardados em `extra` (os que só fases especiais usam). Vazio/null apaga o campo.
func _extra(key: String, v) -> void:
	if _syncing:
		return
	if v == null or (v is String and v == ""):
		model.data.extra.erase(key)
	else:
		model.data.extra[key] = v
	model.dirty = true
	model.version += 1


func _on_boss(i: int) -> void:
	if _syncing:
		return
	var b: Dictionary = BOSSES[i]
	_extra("actors", b.get("actors", null))
	_extra("boss_music", b.get("boss_music", null))
	if b.get("needs_spin", false) and not model.data.extra.has("spin_block"):
		toast("Este boss precisa de um bloco giratório: selecione um quadrado de parede e use 'Da seleção'")


func _on_spin_from_selection() -> void:
	if not tools.has_selection:
		toast("Selecione um quadrado de parede com a ferramenta de seleção")
		return
	var a: Vector2i = tools.sel_a
	var b: Vector2i = tools.sel_b
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var n := absi(b.x - a.x) + 1
	if absi(b.y - a.y) + 1 != n:
		toast("O bloco giratório precisa ser quadrado (a seleção tem %d×%d)" % [n, absi(b.y - a.y) + 1])
		return
	_extra("spin_block", [lo.x, lo.y, n])
	if not model.data.extra.has("spin_cooldown"):
		_extra("spin_cooldown", 45)
	_sync_props()
	toast("Bloco giratório marcado. Ponha espinhos encostados nele.")


func _prop(key: String, v) -> void:
	if _syncing:
		return
	model.data.set(key, v)
	if key == "limiter":
		_limit_spin.editable = bool(v)
	model.dirty = true
	model.version += 1


func _process(delta: float) -> void:
	if model == null:
		return
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)
	if model.version != _last_version:
		_last_version = model.version
		_refresh_problems()
		_undo_btn.disabled = not model.can_undo()
		_redo_btn.disabled = not model.can_redo()
		_syncing = true
		_w_spin.value = model.data.width()
		_h_spin.value = model.data.height()
		_syncing = false
		_update_status()


func _refresh_problems() -> void:
	_problems.clear()
	var list: Array = model.data.validate()
	for p in list:
		var i := _problems.add_item(("✖ " if p["erro"] else "⚠ ") + p["msg"])
		_problems.set_item_custom_fg_color(i, Color("ff7a7a") if p["erro"] else Color("ffd23f"))
		_problems.set_item_metadata(i, p["pos"])
	if list.is_empty():
		_problems.add_item("Sem problemas.")
		_problems.set_item_disabled(0, true)
	if model.data.is_verified():
		_verified_label.text = "✔ Verificada: pode ser compartilhada"
		_verified_label.modulate = Color("8fe388")
	elif model.data.is_playable():
		_verified_label.text = "Ainda não verificada: vença a fase (▶ Jogar)"
		_verified_label.modulate = Color("ffd23f")
	else:
		_verified_label.text = "Corrija os erros para poder jogar"
		_verified_label.modulate = Color("ff7a7a")


func _update_status(cell := Vector2i(-1, -1)) -> void:
	var file := current_id if current_id != "" else "(não salva)"
	var mark := "*" if model.dirty else ""
	var c := "" if cell.x < 0 else "  ·  célula %d,%d" % [cell.x, cell.y]
	_status.text = "%s%s  ·  %dx%d  ·  %s%s" % [file, mark, model.data.width(), model.data.height(), EditTools.TOOL_NAMES[tools.tool], c]


func toast(text: String) -> void:
	_toast.text = text
	_toast_t = 2.5
	_toast.modulate.a = 1.0


func _on_hover(cell: Vector2i) -> void:
	_update_status(cell)


# ---------------------------------------------------------------- ferramentas e peças

func _on_tool(t: int) -> void:
	tools.set_tool(t)
	_highlight()


func _on_glyph(g: String) -> void:
	tools.set_glyph(g)
	_highlight()


func _select_glyph(g: String) -> void:
	tools.set_tool(EditTools.Tool.PENCIL)
	tools.set_glyph(g)
	_highlight()


func _highlight() -> void:
	for t in _tool_buttons:
		_tool_buttons[t].button_pressed = (t == tools.tool)
	for g in _glyph_buttons:
		_glyph_buttons[g].button_pressed = (g == tools.glyph and tools.tool != EditTools.Tool.SELECT and tools.tool != EditTools.Tool.ERASER)
	canvas.queue_redraw()


func _on_problem(i: int) -> void:
	var pos = _problems.get_item_metadata(i)
	if typeof(pos) == TYPE_VECTOR2I and pos.x >= 0:
		canvas.auto_fit = false
		canvas.offset = canvas.size * 0.5 - (Vector2(pos) + Vector2(0.5, 0.5)) * canvas.cell_size
		canvas.queue_redraw()


func _on_copy() -> void:
	if tools.copy_selection():
		toast("Copiado")
	else:
		toast("Selecione uma região (ferramenta Seleção)")


func _on_cut() -> void:
	if tools.cut_selection():
		toast("Recortado")
	else:
		toast("Selecione uma região (ferramenta Seleção)")


func _on_paste() -> void:
	if tools.start_paste():
		toast("Clique para colar. R gira, F espelha, Esc cancela")
	else:
		toast("Nada copiado")


func _on_resize() -> void:
	model.resize(int(_w_spin.value), int(_h_spin.value))
	canvas.fit()


# ---------------------------------------------------------------- arquivos

func _confirm_discard(then: Callable) -> void:
	if not model.dirty:
		then.call()
		return
	_dialog_confirm.title = "Mudanças não salvas"
	_dialog_confirm.dialog_text = "Há mudanças não salvas. Descartar?"
	_confirm_action = then
	_dialog_confirm.popup_centered()


func _on_new() -> void:
	_confirm_discard(new_level)


func _on_exit() -> void:
	_confirm_discard(func(): exit_requested.emit())


func _on_save() -> void:
	if model.data.name.strip_edges() == "":
		model.data.name = "Sem nome"
		_name_edit.text = model.data.name
	var id: String = LevelStore.save(model.data, current_id)
	if id == "":
		toast("Não consegui salvar")
		return
	current_id = id
	model.dirty = false
	model.version += 1
	toast("Salvo: %s" % id)


func _on_save_as() -> void:
	current_id = ""
	_on_save()


func _on_open() -> void:
	_confirm_discard(_show_open)


func _show_open() -> void:
	_open_list.clear()
	_open_entries = []
	var mine: Array = LevelStore.list()
	for e in mine:
		var d = e["data"]
		_open_list.add_item("%s%s  (%dx%d)" % ["✔ " if d.is_verified() else "", d.name if d.name != "" else e["id"], d.width(), d.height()])
		_open_entries.append({"kind": "mine", "id": e["id"]})
	var i := 0
	for cid in Levels.ids():
		i += 1
		_open_list.add_item("História %02d · %s" % [i, Levels.by_id(cid)["name"]])
		_open_entries.append({"kind": "campaign", "id": cid})
	_open_list.add_item("História · sala de início")
	_open_entries.append({"kind": "start"})
	if not mine.is_empty():
		_open_list.select(0)
	_dialog_open.popup_centered()


func _do_open() -> void:
	var sel := _open_list.get_selected_items()
	if sel.is_empty():
		return
	var e: Dictionary = _open_entries[sel[0]]
	if e["kind"] == "mine":
		var d: RefCounted = LevelStore.load_level(e["id"])
		if d == null:
			toast("Não consegui abrir")
			return
		load_level(d, e["id"])
		toast("Aberta: %s" % d.name)
	elif e["kind"] == "campaign":
		_open_campaign(e["id"])
	else:
		load_level(LevelData.from_def(Levels.START), "")
		model.dirty = true
		toast("Cópia da sala de início: salve com outro nome")


## Abre uma fase da história com a marca de verificada e o replay dela.
func _open_campaign(cid: String) -> void:
	var f := FileAccess.open(Levels.level_path(cid), FileAccess.READ)
	var d: RefCounted = LevelData.from_json(f.get_as_text()) if f != null else null
	if d == null:
		toast("Não consegui abrir %s" % cid)
		return
	load_level(d, "", cid)
	if OS.is_debug_build():
		toast("História %d · %s" % [Levels.index_of(cid) + 1, d.name])
	else:
		toast("Cópia da história: salve com outro nome")


# ---------------------------------------------------------------- campanha (modo história)

func _build_campaign_dialog() -> void:
	_dialog_campaign = AcceptDialog.new()
	_dialog_campaign.title = "Campanha (modo história)"
	_dialog_campaign.ok_button_text = "Fechar"
	_dialog_campaign.size = Vector2i(560, 470)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_dialog_campaign.add_child(box)
	_campaign_list = ItemList.new()
	_campaign_list.custom_minimum_size = Vector2(520, 300)
	_campaign_list.item_activated.connect(func(_i): _campaign_open_selected())
	box.add_child(_campaign_list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	_btn(row, "Abrir", _campaign_open_selected)
	_btn(row, "↑ Subir", func(): _campaign_move(-1))
	_btn(row, "↓ Descer", func(): _campaign_move(1))
	_btn(row, "Tirar da história", _campaign_remove)
	var canon := _btn(row, "Canonizar a fase aberta", _campaign_canonize)
	canon.tooltip_text = "Fase da história aberta: grava por cima, no mesmo lugar. Fase nova: entra logo depois da selecionada."
	_campaign_info = Label.new()
	_campaign_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_campaign_info.custom_minimum_size = Vector2(520, 0)
	box.add_child(_campaign_info)
	add_child(_dialog_campaign)


func _show_campaign() -> void:
	Levels.refresh()
	_refresh_campaign()
	_dialog_campaign.popup_centered()


func _refresh_campaign(select_id := "") -> void:
	_campaign_list.clear()
	var ids: Array = Levels.ids()
	for k in ids.size():
		var cid: String = ids[k]
		var proof := "replay" if FileAccess.file_exists(Levels.replay_path(cid)) else "sem replay"
		_campaign_list.add_item("%02d · %s   [%s]%s" % [k + 1, Levels.by_id(cid)["name"], proof, "  ← aberta" if cid == campaign_id else ""])
	var sel := ids.find(select_id if select_id != "" else campaign_id)
	if sel >= 0:
		_campaign_list.select(sel)
		_campaign_list.ensure_current_is_visible()
	var why := CampaignStore.why_not(model.data, last_replay)
	var what := "A fase aberta é a %02d da história" % (Levels.index_of(campaign_id) + 1) if campaign_id != "" else "A fase aberta é nova"
	_campaign_info.text = "%s. %s" % [what, "Pronta para canonizar." if why == "" else why]


func _campaign_selected_id() -> String:
	var sel := _campaign_list.get_selected_items()
	if sel.is_empty():
		return ""
	return Levels.ids()[sel[0]]


func _campaign_open_selected() -> void:
	var cid := _campaign_selected_id()
	if cid == "":
		return
	_dialog_campaign.hide()
	_confirm_discard(func(): _open_campaign(cid))


func _campaign_move(delta: int) -> void:
	var cid := _campaign_selected_id()
	if cid != "" and CampaignStore.move(cid, delta):
		_refresh_campaign(cid)


func _campaign_remove() -> void:
	var cid := _campaign_selected_id()
	if cid == "":
		return
	_dialog_confirm.title = "Tirar da história"
	_dialog_confirm.dialog_text = "Tirar '%s' da história? Ela vira um rascunho em Minhas fases." % Levels.by_id(cid)["name"]
	_confirm_action = func():
		var draft := CampaignStore.remove(cid)
		if draft == "":
			toast("Não consegui tirar da história")
			return
		if campaign_id == cid:
			campaign_id = ""
			current_id = draft
		_refresh_campaign()
		toast("Fora da história; rascunho: %s" % draft)
	_dialog_confirm.popup_centered()


func _campaign_canonize() -> void:
	var at := -1
	var sel := _campaign_list.get_selected_items()
	if not sel.is_empty():
		at = sel[0] + 1
	var res := CampaignStore.canonize(model.data, last_replay, campaign_id, at)
	if res.has("erro"):
		toast(res["erro"])
		_refresh_campaign()
		return
	campaign_id = res["id"]
	model.dirty = false
	model.version += 1
	_refresh_campaign(campaign_id)
	toast("Na história: %02d · %s. Faça commit para ir ao ar." % [Levels.index_of(campaign_id) + 1, model.data.name])


func _on_export() -> void:
	if not model.data.is_verified():
		toast("Só fases verificadas geram código: vença a fase (▶ Jogar)")
		return
	_export_text.text = LevelStore.export_code_to_clipboard(model.data)
	_dialog_export.popup_centered()
	toast("Código copiado para a área de transferência")


func _on_import() -> void:
	_import_text.text = DisplayServer.clipboard_get() if DisplayServer.clipboard_get().begins_with(LevelData.CODE_PREFIX) else ""
	_dialog_import.popup_centered()


func _do_import() -> void:
	var res: Dictionary = LevelStore.import_code(_import_text.text)
	if res.has("erro"):
		toast(res["erro"])
		return
	_confirm_discard(func():
		load_level(res["data"], res["id"])
		toast("Importada: %s" % res["data"].name))


# ---------------------------------------------------------------- desfazer e jogar

func _on_undo() -> void:
	model.undo()
	_sync_props()


func _on_redo() -> void:
	model.redo()
	_sync_props()


func _on_play() -> void:
	var errs: Array = model.data.errors()
	if not errs.is_empty():
		toast("Corrija: %s" % errs[0]["msg"])
		return
	playing = true
	play_requested.emit(model.data.to_def())


## Chamado pelo jogo quando o teste termina (venceu ou saiu).
func play_finished(won: bool, runs: Array = [], state := {}) -> void:
	playing = false
	if won:
		model.data.mark_verified()
		last_replay = Replay.pack(runs, model.data.content_hash(), state)
		model.dirty = true
		model.version += 1
		toast("Você venceu! Fase verificada e replay gravado. Salve, ou canonize em Campanha….")
	else:
		toast("Teste encerrado")
	canvas.refresh()


# ---------------------------------------------------------------- atalhos

func _input(event: InputEvent) -> void:
	if not visible or playing or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit or focus is SpinBox:
		return
	var ctrl: bool = event.ctrl_pressed or event.meta_pressed
	match event.keycode:
		KEY_Z:
			if ctrl:
				if event.shift_pressed:
					_on_redo()
				else:
					_on_undo()
				get_viewport().set_input_as_handled()
		KEY_Y:
			if ctrl:
				_on_redo()
				get_viewport().set_input_as_handled()
		KEY_S:
			if ctrl:
				_on_save()
				get_viewport().set_input_as_handled()
		KEY_C:
			if ctrl:
				_on_copy()
		KEY_X:
			if ctrl:
				_on_cut()
		KEY_V:
			if ctrl:
				_on_paste()
		KEY_DELETE, KEY_BACKSPACE:
			tools.delete_selection()
		KEY_ESCAPE:
			if not tools.escape():
				_on_exit()
			canvas.queue_redraw()
		KEY_R:
			if tools.pasting:
				tools.rotate_paste(-1 if event.shift_pressed else 1)
				canvas.queue_redraw()
		KEY_F:
			if tools.pasting:
				tools.mirror_paste()
				canvas.queue_redraw()
		KEY_P:
			_on_play()
		KEY_G:
			canvas.show_grid = not canvas.show_grid
			canvas.queue_redraw()
		KEY_HOME:
			canvas.fit()

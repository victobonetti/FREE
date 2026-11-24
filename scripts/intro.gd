extends Node2D
## Tela de início e cutscene de abertura (ver start-screen.jpeg).
##
## 1. Título "FREE", "PRESS ENTER" e uma janela com o coelho num campo ensolarado.
## 2. Abre-se um buraco sob o coelho; ele se assusta ("!"), olha para baixo e cai.
## 3. A janela fica vazia e some em fade.
## 4. Corte: o coelho cai girando no vazio.
## 5. Ele pousa numa pequena plataforma branca.
## 6. A plataforma se expande e contorna um quadrado, onde surge a porta.
## Ao terminar, main.gd carrega a sala de início (Levels.START), desenhada no mesmo lugar.
##
## Tudo é desenhado em código, na resolução interna (320x180). O tempo é contado em quadros
## (60 por segundo) por step(), chamado por main.gd.

signal started            # o jogador apertou Enter: a cutscene começou
signal finished           # fim: carregar a sala de início
signal sfx(name: String)
signal impact(strength: float)
signal level_picked(index: int)   # build de teste: começar direto nesta fase (0 = a primeira)
signal sandbox_picked             # build de teste: a sala -1, com todos os componentes (D99)
signal world_picked               # build de teste: o mundo (salas ligadas, teste metroidvania, D100)
signal continue_picked            # há um jogo salvo no mundo: Enter continua (D120)
const World := preload("res://scripts/world.gd")
## O primeiro cartão do carrossel: -2 = mundo, -1 = sandbox.
const MIN_SEL := -2
const SANDBOX_PATH := "res://levels/wip/sandbox.json"

const BuildInfo := preload("res://scripts/build_info.gd")
const Levels := preload("res://scripts/levels.gd")
## A fase escolhida no seletor (build de teste): -1 = sandbox, 0 = do início (abertura), n = fase n. Fica
## guardada enquanto o jogo está aberto.
static var beta_sel := 0

const RoomScript := preload("res://scripts/room.gd")

enum { TITLE, SURPRISE, DROP, EMPTY, FADE, FALL, LANDING, SETTLE, EXPAND_H, EXPAND_V, EXPAND_TOP, DOOR }
const DURATION := {
	SURPRISE: 70, DROP: 40, EMPTY: 50, FADE: 40, FALL: 150, LANDING: 50,
	SETTLE: 40, EXPAND_H: 40, EXPAND_V: 40, EXPAND_TOP: 40, DOOR: 55,
}

const WIN := Rect2(70, 78, 180, 62)   # a janela colorida
const GROUND_Y := 44.0                # chão, em coordenadas da janela
const HOLE_C := Vector2(90, 47)       # centro do buraco, em coordenadas da janela

# O quadrado final coincide com a sala de início: 14x14 tiles, centrada na tela.
const SQ_OUT := Rect2(104, 34, 112, 112)   # paredes
const SQ_IN := Rect2(112, 42, 96, 96)      # interior (as linhas brancas)
const FLOOR_Y := 138.0
const DOOR_RECT := Rect2(184, 106, 16, 32)

const C_WHITE := Color("e2ddcf")
const C_SKY_TOP := Color("6ec6ff")
const C_SKY_BOTTOM := Color("c8efff")
const C_SUN := Color("ffe066")
const C_HILL_FAR := Color("5fbf6a")
const C_HILL_MID := Color("49a85a")
const C_GROUND := Color("7ed957")
const C_GROUND_DARK := Color("5cbf4a")
const C_TRUNK := Color("8a5a3c")
const C_LEAF := Color("2f9e4f")
const C_LEAF_LIGHT := Color("48c266")
const C_DOOR := Color("f3cf3b")
const C_DOOR_INNER := Color("2a2209")

const GLYPHS := {
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
}

var phase := TITLE
var world_mode := false   # o jogo é o mundo (D120): a abertura acaba na queda, que emenda no Poço
var has_save := false     # há um jogo salvo: Enter continua, N começa de novo
var t := 0          # quadros dentro da fase
var frame := 0      # quadros desde o início
var art             # uma Room fora da árvore, só para gerar os quadros do coelho
var press_label: Label
var menu_label: Label
var sel_label: Label          # o seletor de fase (só na build de teste)
var _eat_start := 0           # quadros ignorando o "start" (o toque é do carrossel: decide ao soltar)
const SEL_Y := 148.0
# Carrossel do seletor (build de teste): um cartão por fase, com a miniatura; "do início" é o campo.
const CARD_GAP := 150.0       # distância entre os centros de dois cartões vizinhos
const ARROW_L := Vector2(26, 109)
const ARROW_R := Vector2(294, 109)
const ARROW_R_PX := 10.0
var _scroll := 0.0            # posição do carrossel, em cartões (anda até beta_sel)
var _dragging := false
var _drag_moved := false
var _drag_x0 := 0.0
var _drag_s0 := 0.0
var _tap_go := false          # um toque sem arrastar, fora das setas: começa
var _thumbs := {}             # índice da fase -> miniatura (ImageTexture)
var particles: Array = []
var jolt := 0.0
var jolt_phase := 0.0
var spin := 0.0          # rotação do coelho na queda
var spin_at_landing := 0.0
var squash := Vector2.ONE
var streaks: Array = []


func _ready() -> void:
	art = RoomScript.new()
	press_label = Label.new()
	press_label.text = "PRESS ENTER"
	press_label.position = Vector2(0, 56)
	press_label.size = Vector2(320, 12)
	press_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	press_label.add_theme_font_size_override("font_size", 8)
	press_label.add_theme_color_override("font_color", C_WHITE)
	add_child(press_label)
	menu_label = Label.new()
	menu_label.text = "E  EDITOR      L  MINHAS FASES"
	menu_label.position = Vector2(0, 72)
	menu_label.size = Vector2(320, 12)
	menu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_label.add_theme_font_size_override("font_size", 6)
	menu_label.add_theme_color_override("font_color", C_WHITE)
	menu_label.modulate.a = 0.55
	add_child(menu_label)
	if BuildInfo.BETA:
		sel_label = Label.new()
		sel_label.position = Vector2(0, SEL_Y)
		sel_label.size = Vector2(320, 12)
		sel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sel_label.add_theme_font_size_override("font_size", 8)
		sel_label.add_theme_color_override("font_color", Color("ffe08a"))
		add_child(sel_label)
		beta_sel = clampi(beta_sel, MIN_SEL, Levels.count())
		_scroll = float(beta_sel)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# os textos de cima sobem um pouco: o cartão do carrossel não encosta neles
		press_label.position.y = 52
		menu_label.position.y = 64
		_update_sel()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 16:
		streaks.append({
			"x": rng.randf_range(20.0, 300.0), "y": rng.randf_range(0.0, 180.0),
			"speed": rng.randf_range(5.0, 10.0), "len": rng.randf_range(10.0, 26.0),
			"a": rng.randf_range(0.2, 0.6),
		})


## O mundo tem um jogo salvo? Então Enter continua, e N começa um novo.
func set_save(on: bool) -> void:
	has_save = on
	if on:
		press_label.text = "ENTER  CONTINUAR"
		menu_label.text = "N  NOVO JOGO      E  EDITOR      L  MINHAS FASES"
	else:
		press_label.text = "PRESS ENTER"
		menu_label.text = "E  EDITOR      L  MINHAS FASES"


## Celular: troca o "PRESS ENTER" pelo convite ao toque.
func set_touch_mode() -> void:
	press_label.text = "TAP TO CONTINUE" if has_save else "TAP TO START"
	menu_label.visible = false   # E e L não existem no celular


func _exit_tree() -> void:
	if art != null:
		art.free()
		art = null


func _process(_delta: float) -> void:
	queue_redraw()


## Seletor de fase (build de teste): `d` = -1 ou +1.
func change_sel(d: int) -> void:
	if sel_label == null or phase != TITLE:
		return
	var nv := clampi(beta_sel + d, MIN_SEL, Levels.count())
	if nv == beta_sel:
		return
	beta_sel = nv
	_update_sel()
	sfx.emit("plate_on")


func _update_sel() -> void:
	if sel_label == null:
		return
	if beta_sel == -2:
		sel_label.text = "BETA · MUNDO (TESTE METROIDVANIA)"
	elif beta_sel == -1:
		sel_label.text = "BETA · SANDBOX (TODOS OS COMPONENTES)"
	elif beta_sel == 0:
		sel_label.text = "BETA · DO INÍCIO"
	else:
		sel_label.text = "BETA · FASE %d DE %d · %s" % [beta_sel, Levels.count(), str(Levels.def_at(beta_sel - 1).get("name", "")).to_upper()]


## Carrossel (build de teste), com o mouse ou o dedo (o toque também chega como mouse): tocar nas
## setas troca a fase; arrastar rola os cartões e, ao soltar, encaixa no mais perto; um toque sem
## arrastar começa. O "start" do toque (touch_controls aperta no dedo baixar) é ignorado aqui: o
## carrossel decide ao soltar.
func _input(event: InputEvent) -> void:
	if sel_label == null or phase != TITLE:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = make_input_local(event).position
		if event.pressed:
			_eat_start = 3
			if p.distance_to(ARROW_L) <= ARROW_R_PX + 4.0:
				change_sel(-1)
				return
			if p.distance_to(ARROW_R) <= ARROW_R_PX + 4.0:
				change_sel(1)
				return
			_dragging = true
			_drag_moved = false
			_drag_x0 = p.x
			_drag_s0 = _scroll
		elif _dragging:
			_dragging = false
			if _drag_moved:
				var nv := clampi(roundi(_scroll), MIN_SEL, Levels.count())
				if nv != beta_sel:
					beta_sel = nv
					_update_sel()
					sfx.emit("plate_on")
			else:
				_tap_go = true
	elif event is InputEventMouseMotion and _dragging:
		var p2: Vector2 = make_input_local(event).position
		var dx := p2.x - _drag_x0
		if absf(dx) > 4.0:
			_drag_moved = true
		if _drag_moved:
			_scroll = clampf(_drag_s0 - dx / CARD_GAP, float(MIN_SEL), float(Levels.count()))


## A miniatura do mundo: as salas em escala (1 px a cada 4 tiles), a inicial em amarelo.
func _world_thumb() -> Texture2D:
	var w := World.load_world()
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for r in World.rooms(w):
		var rr := World.rect_of(w, str(r["id"]))
		lo = Vector2i(mini(lo.x, rr.position.x), mini(lo.y, rr.position.y))
		hi = Vector2i(maxi(hi.x, rr.end.x), maxi(hi.y, rr.end.y))
	if hi.x < lo.x:
		lo = Vector2i.ZERO
		hi = Vector2i(4, 4)
	const K := 4
	var img := Image.create(maxi((hi.x - lo.x) / K + 2, 2), maxi((hi.y - lo.y) / K + 2, 2), false, Image.FORMAT_RGBA8)
	img.fill(Color("0c0c12"))
	for r in World.rooms(w):
		var rr := World.rect_of(w, str(r["id"]))
		var col := Color("f3cf3b") if str(r["id"]) == str(w.get("start", "")) else Color("8a8a9e")
		img.fill_rect(Rect2i(1 + (rr.position.x - lo.x) / K, 1 + (rr.position.y - lo.y) / K, maxi(rr.size.x / K - 1, 1), maxi(rr.size.y / K - 1, 1)), col)
	return ImageTexture.create_from_image(img)


## A miniatura de uma fase: um pixel por tile, nas cores do tema dela, já girada como começa.
func _thumb(i: int) -> Texture2D:
	if _thumbs.has(i):
		return _thumbs[i]
	if i == -2:
		_thumbs[i] = _world_thumb()
		return _thumbs[i]
	var d: Dictionary = Levels.def_at(i) if i >= 0 else JSON.parse_string(FileAccess.get_file_as_string(SANDBOX_PATH))
	var rows: Array = d.get("rows", [])
	var w := 1
	for r in rows:
		w = maxi(w, String(r).length())
	var h := maxi(rows.size(), 1)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color("0c0c12"))
	var wall := _thumb_wall(str(d.get("theme", "")))
	for y in rows.size():
		var line := String(rows[y])
		for x in line.length():
			img.set_pixel(x, y, _thumb_col(line[x], wall))
	var sr := int(d.get("start_rot", 0))
	for k in absi(sr):
		img.rotate_90(CLOCKWISE if sr > 0 else COUNTERCLOCKWISE)
	var tex := ImageTexture.create_from_image(img)
	_thumbs[i] = tex
	return tex


static func _thumb_wall(theme: String) -> Color:
	match theme:
		"raizes":
			return Color("6b4e35")
		"caverna":
			return Color("50546a")
		"aquifero":
			return Color("40606a")
		"despensa":
			return Color("6a4c33")
		"fungos":
			return Color("5e5070")
		"transicao":
			return Color("6a6458")
		"industrial":
			return Color("5e6370")
	return Color("3e3e50")


static func _thumb_col(ch: String, wall: Color) -> Color:
	match ch:
		"#":
			return wall
		".":
			return Color("0c0c12")
		"~":
			return Color("2f86e0")
		"%":
			return Color("5fd63a")
		"^", ">", "v", "<":
			return Color("e0657c")
		"D":
			return Color("f3cf3b")
		"P":
			return Color("ffffff")
		"B":
			return Color("3aa0ff")
		"S", "a", "b", "c", "d", "e", "f", "g", "h", "i":
			return Color("8a8a9a")
		"=", "}", "_", "{":
			return Color("9a86d6")
		"↑", "→", "↓", "←":
			return Color("9fe6c1")
		"|", "-":
			return Color("a07a4a")
		"+":
			return Color("ffd23f")
		"L", "H":
			return Color("9aa0ad")
	if "123456789¹²³⁴⁵⁶⁷⁸⁹".contains(ch):
		return Color("c58cff")
	return Color("0c0c12")


## Um quadro da cutscene. `pressed`: Enter/Start apertado neste quadro.
func step(pressed: bool) -> void:
	frame += 1
	t += 1
	_update_fx()
	if phase == TITLE:
		press_label.modulate.a = 1.0 if (frame / 30) % 2 == 0 else 0.25
		if _eat_start > 0:
			_eat_start -= 1
			pressed = false
		if _tap_go:
			_tap_go = false
			pressed = true
		if sel_label != null and not _dragging:
			_scroll = lerpf(_scroll, float(beta_sel), 0.25)
			if absf(_scroll - beta_sel) < 0.005:
				_scroll = float(beta_sel)
		if pressed and frame > 20:
			if sel_label != null and beta_sel > 0:
				level_picked.emit(beta_sel - 1)
				return
			if sel_label != null and beta_sel == -1:
				sandbox_picked.emit()
				return
			if sel_label != null and beta_sel == -2:
				world_picked.emit()
				return
			if has_save:
				continue_picked.emit()
				return
			_go(SURPRISE)
			started.emit()
		return
	if pressed and frame > 20:
		finished.emit()  # pular a cutscene
		return
	if phase == SURPRISE:
		press_label.modulate.a = maxf(press_label.modulate.a - 0.08, 0.0)
		menu_label.modulate.a = maxf(menu_label.modulate.a - 0.08, 0.0)
		if t == 2:
			impact.emit(0.5)   # o chão cede
		if t == 12:
			sfx.emit("jump")  # o sobressalto
	elif phase == FALL:
		spin += 0.17
	elif phase == LANDING:
		if t == DURATION[LANDING]:
			_land()
	if t >= DURATION[phase]:
		if phase == DOOR or (world_mode and phase == FALL):
			finished.emit()   # no mundo, a queda continua no Poço
		else:
			if phase == FALL:
				spin_at_landing = spin
			if phase == EXPAND_TOP:
				sfx.emit("sensor_on")  # a porta surge
			_go(phase + 1)


func _go(p: int) -> void:
	if sel_label != null and p != TITLE:
		sel_label.visible = false
	phase = p
	t = 0
	if p == DROP:
		sfx.emit("falling")  # o coelho começa a cair: main.gd toca a música da queda


func _land() -> void:
	impact.emit(1.5)
	jolt = 4.0
	jolt_phase = 0.0
	squash = Vector2(1.4, 0.6)
	for i in 14:
		var dir := -1.0 if i % 2 == 0 else 1.0
		particles.append({
			"pos": Vector2(160.0 + dir * randf_range(2.0, 8.0), FLOOR_Y - 1.0),
			"vel": Vector2(dir * randf_range(20.0, 70.0), -randf_range(8.0, 40.0)),
			"life": randi_range(12, 24),
		})


func _update_fx() -> void:
	jolt_phase += 1.15
	jolt *= 0.84
	if jolt < 0.05:
		jolt = 0.0
	squash = squash.lerp(Vector2.ONE, 0.16)
	for p in particles:
		p["pos"] += p["vel"] / 60.0
		p["vel"].y += 2.0
		p["vel"].x *= 0.93
		p["life"] -= 1
	particles = particles.filter(func(p): return p["life"] > 0)
	for s in streaks:
		s["y"] -= s["speed"]
		if s["y"] < -30.0:
			s["y"] = 190.0


func _k() -> float:
	return clampf(float(t) / float(DURATION.get(phase, 1)), 0.0, 1.0)


func _smooth(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


# ---------------------------------------------------------------- desenho

func _draw() -> void:
	if phase <= FADE:
		_draw_title_scene()
	else:
		_draw_void_scene()


func _draw_title_scene() -> void:
	var text_a := 1.0
	if phase == SURPRISE:
		text_a = 1.0 - clampf(t / 25.0, 0.0, 1.0)
	elif phase > SURPRISE:
		text_a = 0.0
	if text_a > 0.0:
		_draw_word("FREE", Vector2(102, 14), 5.0, Color(C_WHITE, text_a))

	if sel_label != null and phase == TITLE:
		_draw_carousel()
		return
	draw_set_transform(WIN.position)
	_draw_meadow()
	draw_set_transform(Vector2.ZERO)
	draw_rect(WIN, C_WHITE, false, 1.0)
	if phase == FADE:
		draw_rect(WIN.grow(1.0), Color(0, 0, 0, _smooth(_k())))


## O carrossel da build de teste: o cartão do meio do tamanho da janela, os vizinhos menores e
## apagados dos lados, e as setas redondas.
func _draw_carousel() -> void:
	var n := Levels.count() + 1
	var order: Array = []
	for i in range(maxi(MIN_SEL, int(floor(_scroll)) - 2), mini(n, int(floor(_scroll)) + 3)):
		order.append(i)
	order.sort_custom(func(a, b): return absf(a - _scroll) > absf(b - _scroll))   # os de longe primeiro
	for i in order:
		var off: float = float(i) - _scroll
		var k := minf(absf(off), 1.0)
		if absf(off) > 1.8:
			continue
		var sc := 1.0 - 0.42 * k
		var size := WIN.size * sc
		var cx := 160.0 + off * CARD_GAP
		var rect := Rect2(Vector2(cx - size.x / 2.0, WIN.position.y + (WIN.size.y - size.y) / 2.0), size)
		if i == 0:
			draw_set_transform(rect.position, 0.0, Vector2(sc, sc))
			_draw_meadow()
			draw_set_transform(Vector2.ZERO)
		else:
			draw_rect(rect, Color(0.04, 0.04, 0.06))
			var tex := _thumb(i - 1 if i > 0 else i)
			var ts := Vector2(tex.get_width(), tex.get_height())
			var fit := minf((rect.size.x - 4.0) / ts.x, (rect.size.y - 4.0) / ts.y)
			var tsz := ts * fit
			draw_texture_rect(tex, Rect2(rect.get_center() - tsz / 2.0, tsz), false)
		draw_rect(rect, Color(C_WHITE, 1.0 - 0.6 * k), false, 1.0)
		if k > 0.02:
			draw_rect(rect, Color(0, 0, 0, 0.55 * k))
	# setas
	for side in [-1, 1]:
		var c: Vector2 = ARROW_L if side < 0 else ARROW_R
		var live: bool = (side < 0 and beta_sel > MIN_SEL) or (side > 0 and beta_sel < n - 1)
		var a := 0.9 if live else 0.25
		draw_circle(c, ARROW_R_PX, Color(0.05, 0.05, 0.08, 0.85))
		draw_arc(c, ARROW_R_PX, 0.0, TAU, 24, Color(C_WHITE, a), 1.0)
		var dx: float = 2.5 * side
		draw_line(c + Vector2(-dx, -4), c + Vector2(dx, 0), Color(C_WHITE, a), 2.0)
		draw_line(c + Vector2(dx, 0), c + Vector2(-dx, 4), Color(C_WHITE, a), 2.0)
	# pontinhos: onde está no carrossel
	var dots := mini(n - MIN_SEL, 28)
	var x0 := 160.0 - (dots - 1) * 2.5
	for i in dots:
		var on := i + MIN_SEL == beta_sel
		draw_rect(Rect2(x0 + i * 5.0 - (1.0 if on else 0.5), 143.0 - (1.0 if on else 0.5), 2.0 if on else 1.0, 2.0 if on else 1.0), Color(C_WHITE, 0.9 if on else 0.3))


func _draw_word(word: String, at: Vector2, px: float, col: Color) -> void:
	var x := at.x
	for ch in word:
		var g: Array = GLYPHS[ch]
		for r in g.size():
			var line: String = g[r]
			for c in line.length():
				if line[c] == "#":
					draw_rect(Rect2(x + c * px, at.y + r * px, px, px), col)
		x += 6.0 * px


## O campo ensolarado, em coordenadas da janela (180 x 62). Nada passa das bordas dela.
func _draw_meadow() -> void:
	var w := WIN.size.x
	var h := WIN.size.y
	# céu em faixas
	for i in 11:
		var k := float(i) / 10.0
		draw_rect(Rect2(0, i * 4.0, w, 4.0), C_SKY_TOP.lerp(C_SKY_BOTTOM, k))
	# sol com raios girando
	var sun := Vector2(150, 13)
	for i in 8:
		var a := frame * 0.01 + i * TAU / 8.0
		draw_line(sun + Vector2(cos(a), sin(a)) * 9.0, sun + Vector2(cos(a), sin(a)) * 12.0, Color(C_SUN, 0.8), 1.0)
	draw_circle(sun, 7.0, C_SUN)
	draw_circle(sun, 5.0, Color("fff3a8"))
	# nuvens passando
	for i in 3:
		var cx := fposmod(20.0 + i * 70.0 + frame * (0.05 + 0.02 * i), w + 40.0) - 20.0
		var cy := 8.0 + i * 6.0
		for part in [Rect2(0, 2, 18, 4), Rect2(3, 0, 8, 6), Rect2(9, 1, 6, 5)]:
			var r := Rect2(cx + part.position.x, cy + part.position.y, part.size.x, part.size.y)
			var x0 := maxf(r.position.x, 0.0)
			var x1 := minf(r.end.x, w)
			if x1 > x0:
				draw_rect(Rect2(x0, r.position.y, x1 - x0, r.size.y), Color(1, 1, 1, 0.9))
	# colinas
	_draw_hill(w, 34.0, 9.0, 0.045, 1.0, C_HILL_FAR)
	_draw_hill(w, 40.0, 6.0, 0.07, 4.0, C_HILL_MID)
	# árvores
	_draw_tree(Vector2(30, GROUND_Y), 1.0)
	_draw_tree(Vector2(128, GROUND_Y), 0.8)
	_draw_tree(Vector2(162, GROUND_Y), 1.1)
	# chão
	draw_rect(Rect2(0, GROUND_Y, w, h - GROUND_Y), C_GROUND)
	draw_rect(Rect2(0, GROUND_Y, w, 1), Color("a6f07a"))
	for i in 9:
		draw_rect(Rect2(6.0 + i * 20.0, GROUND_Y + 6.0 + (i % 3) * 4.0, 7, 1), C_GROUND_DARK)
	# flores (longe do centro, onde o buraco se abre)
	var flower_cols := [Color("ff7eb6"), Color("ffd23f"), Color("ffffff"), Color("ff9a5c")]
	for i in 12:
		var fx := 8.0 + i * 14.5
		if absf(fx - HOLE_C.x) < 24.0:
			continue
		var fy := GROUND_Y + 3.0 + (i * 5 % 11)
		draw_rect(Rect2(fx, fy + 1, 1, 2), C_LEAF)
		draw_rect(Rect2(fx - 1, fy - 1, 3, 2), flower_cols[i % 4])
	# buraco
	var hole := _hole_size()
	if hole.x > 0.5:
		draw_colored_polygon(_ellipse(HOLE_C, hole, 0.0, TAU), Color.BLACK)
	# coelho
	_draw_title_rabbit()
	# a borda da frente do buraco cobre o coelho que afunda
	if hole.x > 0.5:
		draw_rect(Rect2(HOLE_C.x - hole.x - 3.0, HOLE_C.y, hole.x * 2.0 + 6.0, h - HOLE_C.y), C_GROUND)
		draw_colored_polygon(_ellipse(HOLE_C, hole, 0.0, PI), Color.BLACK)


func _hole_size() -> Vector2:
	if phase == TITLE:
		return Vector2.ZERO
	var k := 1.0
	if phase == SURPRISE:
		k = _smooth(clampf(t / 40.0, 0.0, 1.0))
	return Vector2(15.0, 4.5) * k


func _ellipse(c: Vector2, r: Vector2, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		var a := lerpf(a0, a1, i / 16.0)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


func _draw_hill(w: float, base: float, amp: float, freq: float, shift: float, col: Color) -> void:
	# em colunas de 2 px: robusto mesmo quando a colina encosta no chão
	var x := 0.0
	while x < w:
		var y := minf(roundf(base - amp * sin(x * freq + shift)), GROUND_Y)
		draw_rect(Rect2(x, y, 2.0, GROUND_Y + 1.0 - y), col)
		x += 2.0


func _draw_tree(base: Vector2, s: float) -> void:
	draw_rect(Rect2(base.x - 1.5 * s, base.y - 12.0 * s, 3.0 * s, 12.0 * s), C_TRUNK)
	draw_circle(base + Vector2(0, -16.0 * s), 7.0 * s, C_LEAF)
	draw_circle(base + Vector2(-4.0 * s, -13.0 * s), 5.0 * s, C_LEAF)
	draw_circle(base + Vector2(4.0 * s, -13.0 * s), 5.0 * s, C_LEAF)
	draw_circle(base + Vector2(-2.0 * s, -18.0 * s), 3.5 * s, C_LEAF_LIGHT)


func _draw_title_rabbit() -> void:
	if phase >= EMPTY:
		return
	var feet := Vector2(HOLE_C.x, GROUND_Y)
	var tex: ImageTexture
	var alpha := 1.0
	if phase == TITLE:
		# parado, piscando; de vez em quando dá um pulinho
		var c := frame % 200
		var hop := 0.0
		if c < 24:
			hop = sin(c / 24.0 * PI) * 5.0
		feet.y -= hop
		var blink := frame % 160 >= 120 and frame % 160 < 127
		tex = art._rabbit_tex("back" if hop > 0.5 else "up", "air" if hop > 0.5 else "stand", blink)
	elif phase == SURPRISE:
		# sobressalto, depois olha para baixo
		if t >= 12 and t < 30:
			feet.y -= sin((t - 12) / 18.0 * PI) * 6.0
		tex = art._rabbit_tex("twitch" if t < 12 else "fall", "stand" if t < 12 or t >= 30 else "air", false)
		if t >= 12:
			_draw_bang(feet + Vector2(9, -27))
	else:  # DROP
		var k := _k()
		feet.y += k * k * 34.0
		tex = art._rabbit_tex("fall", "air", false)
	# recorta na borda de baixo da janela: o coelho que cai no buraco não pode aparecer fora dela
	var pos := feet + Vector2(-6, -16)
	var vis_h := minf(tex.get_size().y, WIN.size.y - pos.y)
	if vis_h > 0.0:
		draw_texture_rect_region(tex, Rect2(pos, Vector2(tex.get_size().x, vis_h)),
			Rect2(Vector2.ZERO, Vector2(tex.get_size().x, vis_h)), Color(1, 1, 1, alpha))


## O ponto de exclamação do susto.
func _draw_bang(at: Vector2) -> void:
	var bob := sin(frame * 0.5) * 0.6
	var p := at + Vector2(0, bob)
	draw_rect(Rect2(p + Vector2(-1, -1), Vector2(4, 11)), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(p, Vector2(2, 6)), Color("e0334a"))
	draw_rect(Rect2(p + Vector2(0, 7), Vector2(2, 2)), Color("e0334a"))


func _draw_void_scene() -> void:
	var off := Vector2(0.0, roundf(jolt * sin(jolt_phase)))
	draw_set_transform(off)

	# riscos de velocidade, só enquanto cai
	var streak_a := 0.0
	if phase == FALL:
		streak_a = clampf(t / 20.0, 0.0, 1.0)
	elif phase == LANDING:
		streak_a = 1.0 - _k()
	if streak_a > 0.0:
		for s in streaks:
			draw_rect(Rect2(s["x"], s["y"], 1, s["len"]), Color(C_WHITE, s["a"] * streak_a))

	# o quadrado e a porta
	if phase >= DOOR:
		var a := _smooth(_k())
		draw_rect(SQ_OUT, Color(RoomScript.C_WALL, a))
		draw_rect(SQ_IN, Color(RoomScript.C_BG, a))
		var d := DOOR_RECT
		draw_rect(d.grow(2.0), Color(C_DOOR, 0.15 * a))
		draw_rect(d, Color(C_DOOR, a))
		draw_rect(d.grow(-2.0), Color(C_DOOR_INNER, a))
		for i in 3:
			var py := d.position.y - 3.0 - fmod(frame * 0.3 + i * 7.0, 14.0)
			draw_rect(Rect2(d.position.x + 3.0 + i * 5.0, py, 1, 2), Color(C_DOOR, a * 0.8))
	_draw_outline()

	# coelho
	var center := Vector2(160, 84)
	var scale_k := 2.0
	var rot := spin
	var alpha := 1.0
	var tex: ImageTexture = art._rabbit_tex("fall", "air", false)
	if phase == FALL:
		alpha = clampf(t / 18.0, 0.0, 1.0)
		center.y += sin(frame * 0.12) * 2.0
		center.x += sin(frame * 0.07) * 3.0
	elif phase == LANDING:
		var k := _k()
		scale_k = lerpf(2.0, 1.0, k)
		center.y = lerpf(84.0, FLOOR_Y - 8.0, k * k)
		center.x = 160.0
		rot = lerpf(spin_at_landing, ceilf(spin_at_landing / TAU) * TAU, _smooth(k))
	if phase <= LANDING:
		draw_set_transform(off + center, rot, Vector2(scale_k, scale_k))
		draw_texture(tex, Vector2(-6, -8), Color(1, 1, 1, alpha))
	else:
		var blink := frame % 160 >= 120 and frame % 160 < 127
		draw_set_transform(off + Vector2(160, FLOOR_Y), 0.0, squash)
		draw_texture(art._rabbit_tex("up", "stand", blink), Vector2(-6, -16))
	draw_set_transform(off)

	# faíscas do impacto (os raios do esboço)
	if phase == SETTLE and t < 14:
		var a2 := 1.0 - t / 14.0
		for sgn in [-1.0, 1.0]:
			var b := Vector2(160.0 + sgn * 15.0, FLOOR_Y - 14.0)
			var pts := PackedVector2Array([b, b + Vector2(sgn * 4, -3), b + Vector2(sgn * 1, -5), b + Vector2(sgn * 6, -9)])
			draw_polyline(pts, Color(C_WHITE, a2), 1.0)
	for p in particles:
		draw_rect(Rect2(p["pos"] - Vector2(1, 1), Vector2(2, 2)), Color(C_WHITE, clampf(p["life"] / 14.0, 0.0, 1.0)))
	draw_set_transform(Vector2.ZERO)


## A plataforma branca: sobe, se alonga, sobe pelos lados e fecha em cima.
func _draw_outline() -> void:
	if phase < LANDING:
		return
	var half := 14.0
	var y := FLOOR_Y
	if phase == LANDING:
		y = lerpf(200.0, FLOOR_Y, 1.0 - pow(1.0 - _k(), 2.0))
	elif phase == EXPAND_H:
		half = lerpf(14.0, SQ_IN.size.x / 2.0, _smooth(_k()))
	elif phase > EXPAND_H:
		half = SQ_IN.size.x / 2.0
	draw_rect(Rect2(160.0 - half, y, half * 2.0, 1), C_WHITE)
	if phase < EXPAND_V:
		return
	var up := SQ_IN.size.y
	if phase == EXPAND_V:
		up *= _smooth(_k())
	# as linhas ficam 1 px para fora do interior, como as bordas das paredes da sala real
	draw_rect(Rect2(SQ_IN.position.x - 1.0, FLOOR_Y - up, 1, up), C_WHITE)
	draw_rect(Rect2(SQ_IN.end.x, FLOOR_Y - up, 1, up), C_WHITE)
	if phase < EXPAND_TOP:
		return
	var across := SQ_IN.size.x / 2.0
	if phase == EXPAND_TOP:
		across *= _smooth(_k())
	draw_rect(Rect2(SQ_IN.position.x, SQ_IN.position.y - 1.0, across, 1), C_WHITE)
	draw_rect(Rect2(SQ_IN.end.x - across, SQ_IN.position.y - 1.0, across, 1), C_WHITE)

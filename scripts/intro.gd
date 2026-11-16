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
var t := 0          # quadros dentro da fase
var frame := 0      # quadros desde o início
var art             # uma Room fora da árvore, só para gerar os quadros do coelho
var press_label: Label
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
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 16:
		streaks.append({
			"x": rng.randf_range(20.0, 300.0), "y": rng.randf_range(0.0, 180.0),
			"speed": rng.randf_range(5.0, 10.0), "len": rng.randf_range(10.0, 26.0),
			"a": rng.randf_range(0.2, 0.6),
		})


## Celular: troca o "PRESS ENTER" pelo convite ao toque.
func set_touch_mode() -> void:
	press_label.text = "TAP TO START"


func _exit_tree() -> void:
	if art != null:
		art.free()
		art = null


func _process(_delta: float) -> void:
	queue_redraw()


## Um quadro da cutscene. `pressed`: Enter/Start apertado neste quadro.
func step(pressed: bool) -> void:
	frame += 1
	t += 1
	_update_fx()
	if phase == TITLE:
		press_label.modulate.a = 1.0 if (frame / 30) % 2 == 0 else 0.25
		if pressed and frame > 20:
			_go(SURPRISE)
			started.emit()
		return
	if pressed and frame > 20:
		finished.emit()  # pular a cutscene
		return
	if phase == SURPRISE:
		press_label.modulate.a = maxf(press_label.modulate.a - 0.08, 0.0)
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
		if phase == DOOR:
			finished.emit()
		else:
			if phase == FALL:
				spin_at_landing = spin
			if phase == EXPAND_TOP:
				sfx.emit("sensor_on")  # a porta surge
			_go(phase + 1)


func _go(p: int) -> void:
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

	draw_set_transform(WIN.position)
	_draw_meadow()
	draw_set_transform(Vector2.ZERO)
	draw_rect(WIN, C_WHITE, false, 1.0)
	if phase == FADE:
		draw_rect(WIN.grow(1.0), Color(0, 0, 0, _smooth(_k())))


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

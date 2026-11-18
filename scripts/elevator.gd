extends Node2D
## O elevador entre o ato 2 e o ato 3 (D107). Ator da sala (campo "actors"): a sala é a cabine, com
## teto e sem giro ("rotate": false). O coelho anda à vontade lá dentro; a porta só destrava no fim.
##
##   parado -> sobe (o poço passa para baixo, cada vez mais rápido) -> tranco perto do topo (alarme,
##   faíscas, luz vermelha) -> o cabo estoura e a cabine cai (o poço passa para cima, a luz pisca)
##   -> o impacto (escuro total) -> uma lâmpada roxa, abafada, acende -> a porta destrava.
##
## Tudo é desenhado em volta da cabine (o poço) e por cima dela (a luz). Tempos em quadros.

const T_START := 70        # parado
const T_UP := 330          # fim da subida
const T_JAM := 430         # fim do tranco
const T_FALL := 590        # o impacto
const T_DARK := 660        # fim do escuro total
const T_LIGHT := 760       # a luz roxa chega ao máximo; a porta destrava

const C_SHAFT := Color("1b1c22")
const C_BEAM := Color("3a3d47")
const C_RAIL := Color("55585f")
const C_LAMP := Color(1.0, 0.86, 0.55)
const C_ALARM := Color("ff3b4e")
const C_PURPLE := Color(0.62, 0.45, 0.85)

var room
var t := 0
var scroll := 0.0          # quanto o poço já andou (px; positivo = a cabine subiu)
var speed := 0.0           # px/s do poço (positivo: subindo)
var cracked := false


func on_reset(r) -> void:
	room = r
	t = 0
	scroll = 0.0
	speed = 0.0
	cracked = false


func on_rotate(_r, _dir: int) -> void:
	pass


func step(r) -> void:
	room = r
	t += 1
	if t < T_START:
		speed = 0.0
	elif t < T_UP:
		speed = minf(speed + 1.2, 110.0)
		room.shake = maxf(room.shake, 0.3)
	elif t < T_JAM:
		if t == T_UP:
			speed = 0.0
			room.shake = 5.0
			room.impact.emit(1.6)
			room.sfx.emit("crunch")
		if t % 24 == 0:
			room.sfx.emit("mover_warn")   # alarme
		if t % 5 == 0:
			_sparks(Vector2(randf_range(8.0, room.pw - 8.0), 9.0), 3)
		room.shake = maxf(room.shake, 1.0 + 0.6 * sin(t * 0.9))
	elif t < T_FALL:
		if t == T_JAM:
			cracked = true
			room.sfx.emit("steam_burst")
			room.shake = 4.0
			_sparks(Vector2(room.pw / 2.0, 8.0), 14)
		speed = maxf(speed - 9.0, -720.0)
		room.shake = maxf(room.shake, 2.0)
	elif t == T_FALL:
		speed = 0.0
		room.shake = 9.0
		room.impact.emit(3.0)
		room.sfx.emit("slam")
		room.sfx.emit("blast")
		for i in 26:
			room.particles.append({
				"pos": Vector2(randf_range(8.0, room.pw - 8.0), room.ph - 10.0),
				"vel": Vector2(randf_range(-60.0, 60.0), -randf_range(20.0, 90.0)),
				"life": randi_range(20, 40), "col": Color(0.6, 0.55, 0.62, 0.8), "grav": 60.0,
			})
	elif t == T_LIGHT:
		room.door_unlocked = true
		room.sfx.emit("gate_open")
	scroll += speed / 60.0


func _sparks(p: Vector2, n: int) -> void:
	for i in n:
		room.particles.append({
			"pos": p, "vel": Vector2(randf_range(-70.0, 70.0), randf_range(-10.0, 80.0)),
			"life": randi_range(8, 18), "col": C_LAMP if i % 2 == 0 else Color("fff4c2"), "grav": 220.0,
		})


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if room == null:
		return
	var base := Transform2D(room.view_angle, Vector2.ZERO) * Transform2D(0.0, -room.cam.round())
	draw_set_transform_matrix(base)
	var pw: float = room.pw
	var ph: float = room.ph
	var top := -260.0
	var bot := ph + 260.0
	if t < T_FALL:
		# o poço: paredes, trilhos, vigas e lâmpadas passando
		draw_rect(Rect2(-90, top, 82, bot - top), C_SHAFT)
		draw_rect(Rect2(pw + 8, top, 82, bot - top), C_SHAFT)
		for x in [-14.0, pw + 10.0]:
			draw_rect(Rect2(x, top, 4, bot - top), C_RAIL)
		var off := fposmod(scroll, 48.0)
		var y := top + off
		while y < bot:
			draw_rect(Rect2(-90, y, 82, 3), C_BEAM)
			draw_rect(Rect2(pw + 8, y, 82, 3), C_BEAM)
			y += 48.0
		var loff := fposmod(scroll, 150.0)
		var ly := top + loff
		while ly < bot:
			for lx in [-40.0, pw + 40.0]:
				draw_circle(Vector2(lx, ly), 16.0, Color(C_LAMP, 0.06))
				draw_rect(Rect2(lx - 3, ly - 1, 6, 3), C_LAMP)
			ly += 150.0
		# os cabos, presos no teto da cabine (o do meio estoura no tranco)
		for cx in [pw * 0.3, pw * 0.7]:
			draw_line(Vector2(cx, top), Vector2(cx, 0), C_RAIL, 1.0)
		if not cracked:
			draw_line(Vector2(pw * 0.5, top), Vector2(pw * 0.5, 0), C_RAIL, 2.0)
		else:
			var whip := sin(t * 0.5) * 6.0
			draw_line(Vector2(pw * 0.5, top), Vector2(pw * 0.5 + whip, top + 120.0), C_RAIL, 2.0)
	# luz dentro da cabine
	var cab := Rect2(0, 0, pw, ph)
	if t >= T_UP and t < T_JAM:
		var a := 0.18 if (t / 12) % 2 == 0 else 0.04
		draw_rect(cab.grow(90), Color(C_ALARM, a))
	elif t >= T_JAM and t < T_FALL:
		if (t / 3) % 4 == 0:
			draw_rect(cab.grow(90), Color(0, 0, 0, 0.55))
		elif (t / 12) % 2 == 0:
			draw_rect(cab.grow(90), Color(C_ALARM, 0.12))
	elif t >= T_FALL:
		var dark := 1.0
		if t >= T_DARK:
			dark = 1.0 - 0.62 * clampf(float(t - T_DARK) / float(T_LIGHT - T_DARK), 0.0, 1.0)
		draw_rect(cab.grow(400), Color(0.02, 0.01, 0.03, dark))
		if t >= T_DARK:
			# a lâmpada roxa, abafada de poeira, pendurada torta no teto da cabine
			var k := clampf(float(t - T_DARK) / float(T_LIGHT - T_DARK), 0.0, 1.0)
			var flick := 1.0 if (t / 5) % 23 != 0 else 0.4
			var lp := Vector2(pw * 0.62, 14.0)
			for i in 4:
				draw_circle(lp, 14.0 + i * 10.0, Color(C_PURPLE, 0.045 * k * flick))
			draw_line(Vector2(pw * 0.62 - 4, 8), lp, C_RAIL, 1.0)
			draw_rect(Rect2(lp - Vector2(2, 1), Vector2(5, 3)), Color(C_PURPLE, 0.4 + 0.6 * k * flick))
	draw_set_transform_matrix(Transform2D.IDENTITY)

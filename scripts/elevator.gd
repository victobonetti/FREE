extends Node2D
## O elevador entre o ato 2 e o ato 3 (D107). Ator da sala (campo "actors"), em dois modos (campo
## "elevator" da sala):
##
##   "hall": a plataforma de embarque, no fim da fábrica. A porta da sala é a do elevador: aberta,
##            com a cabine acesa lá dentro, o indicador e o painel de chamada.
##   "ride" (padrão): a sala é a cabine, com teto e sem giro ("rotate": false). O coelho anda à vontade
##            lá dentro; a porta só destrava no fim.
##
##   parado -> sobe (o poço passa para baixo; as luzes do poço varrem a cabine) -> tranco perto do topo
##   (alarme, faíscas, luz de emergência) -> o cabo estoura e a cabine cai (a luz falha, tudo treme)
##   -> o impacto (escuro total, poeira) -> a cabine destruída: rachaduras, o painel do teto pendurado,
##   a luminária quebrada soltando faíscas, entulho, e o mofo do fungário entrando pelas frestas, com
##   uma luz roxa vinda de fora -> a porta destrava.
##
## O fundo (painéis, mofo, rachaduras) é desenhado por draw_back, atrás do coelho; o poço e a luz, por
## cima de tudo. Tempos em quadros.

const T_START := 90        # parado
const T_UP := 360          # fim da subida
const T_JAM := 460         # fim do tranco
const T_FALL := 620        # o impacto
const T_DARK := 700        # fim do escuro total
const T_LIGHT := 820       # a luz de fora chega ao máximo; a porta destrava

const C_SHAFT := Color("15161b")
const C_BEAM := Color("2f323b")
const C_RAIL := Color("4c4f57")
const C_LAMP := Color(1.0, 0.86, 0.55)
const C_TUBE := Color(0.86, 0.93, 1.0)
const C_ALARM := Color("ff3b4e")
const C_PURPLE := Color(0.62, 0.45, 0.85)
const C_PANEL := Color("23252d")
const C_PANEL_LINE := Color("30333d")
const C_MOLD := Color("7c6596")
const C_MYCEL := Color("d9cfe6")
const C_CAP := Color("9b6bc4")

var room
var mode := "ride"
var t := 0
var scroll := 0.0          # quanto o poço já andou (px; positivo = a cabine subiu)
var speed := 0.0           # px/s do poço (positivo: subindo)
var cracked := false


func on_reset(r) -> void:
	room = r
	mode = str(r.def.get("elevator", "ride"))
	t = 0
	scroll = 0.0
	speed = 0.0
	cracked = false
	if mode == "hall":
		r.door_unlocked = true


func on_rotate(_r, _dir: int) -> void:
	pass


func step(r) -> void:
	room = r
	t += 1
	if mode == "hall":
		return
	if t < T_START:
		speed = 0.0
	elif t < T_UP:
		speed = minf(speed + 1.0, 120.0)
		room.shake = maxf(room.shake, 0.35)
	elif t < T_JAM:
		if t == T_UP:
			speed = 0.0
			room.shake = 5.0
			room.impact.emit(1.6)
			room.sfx.emit("crunch")
		if t % 24 == 0:
			room.sfx.emit("mover_warn")   # alarme
		if t % 5 == 0:
			_sparks(Vector2(randf_range(10.0, room.pw - 10.0), 9.0), 3)
		room.shake = maxf(room.shake, 1.0 + 0.6 * sin(t * 0.9))
	elif t < T_FALL:
		if t == T_JAM:
			cracked = true
			room.sfx.emit("steam_burst")
			room.shake = 4.0
			_sparks(Vector2(room.pw / 2.0, 8.0), 16)
		speed = maxf(speed - 9.0, -760.0)
		room.shake = maxf(room.shake, 2.0 + float(t - T_JAM) / 60.0)
		if t % 9 == 0:
			_sparks(Vector2(randf_range(10.0, room.pw - 10.0), 9.0), 2)
	elif t == T_FALL:
		speed = 0.0
		room.shake = 10.0
		room.impact.emit(3.0)
		room.sfx.emit("slam")
		room.sfx.emit("blast")
		for i in 40:
			room.particles.append({
				"pos": Vector2(randf_range(10.0, room.pw - 10.0), room.ph - 18.0),
				"vel": Vector2(randf_range(-70.0, 70.0), -randf_range(20.0, 110.0)),
				"life": randi_range(24, 50), "col": Color(0.55, 0.5, 0.58, 0.85), "grav": 50.0,
			})
		for i in 14:
			room.particles.append({
				"pos": Vector2(randf_range(10.0, room.pw - 10.0), 10.0),
				"vel": Vector2(randf_range(-30.0, 30.0), randf_range(10.0, 60.0)),
				"life": randi_range(20, 40), "col": Color("3a3d47"), "grav": 300.0,
			})
	elif t > T_FALL:
		if t == T_LIGHT:
			room.door_unlocked = true
			room.sfx.emit("gate_open")
		if t > T_DARK and t % 47 == 0:
			_sparks(_tube_pos() + Vector2(4, 6), 4)   # a luminária quebrada
		if t > T_DARK and t % 4 == 0:
			room.particles.append({   # esporos entrando pela fresta da porta
				"pos": _door_c() + Vector2(randf_range(-6.0, 6.0), randf_range(-12.0, 12.0)),
				"vel": Vector2(randf_range(-14.0, -4.0), randf_range(-6.0, 6.0)),
				"life": randi_range(40, 80), "col": Color(C_PURPLE, 0.7), "grav": 4.0,
			})
	scroll += speed / 60.0


func _sparks(p: Vector2, n: int) -> void:
	for i in n:
		room.particles.append({
			"pos": p, "vel": Vector2(randf_range(-70.0, 70.0), randf_range(-10.0, 80.0)),
			"life": randi_range(8, 18), "col": C_LAMP if i % 2 == 0 else Color("fff4c2"), "grav": 220.0,
		})


func _inside() -> Rect2:
	return Rect2(8, 8, room.pw - 16, room.ph - 24)


func _tube_pos() -> Vector2:
	return Vector2(_inside().get_center().x - 10, 9)


func _door_c() -> Vector2:
	var d: Rect2i = room.door
	return Vector2(d.position) + Vector2(d.size) / 2.0


func _crashed() -> bool:
	return t >= T_FALL


func _process(_d: float) -> void:
	queue_redraw()


# ---------------------------------------------------------------- fundo (atrás do coelho)

func draw_back(r) -> void:
	room = r
	if mode == "hall":
		_draw_hall_back(r)
		return
	var ins := _inside()
	# painéis da parede do fundo, corrimão e o painel de botões
	r.draw_rect(ins, C_PANEL)
	var x := ins.position.x
	while x < ins.end.x:
		r.draw_rect(Rect2(x, ins.position.y, 1, ins.size.y), C_PANEL_LINE)
		x += 16.0
	r.draw_rect(Rect2(ins.position.x, ins.end.y - 22, ins.size.x, 2), Color("4c4f57"))
	r.draw_rect(Rect2(ins.position.x, ins.end.y - 20, ins.size.x, 1), Color("1a1b20"))
	var pnl := Rect2(ins.end.x - 34, ins.position.y + 16, 8, 14)
	r.draw_rect(pnl, Color("2c2f37"))
	for i in 4:
		var on := not _crashed() and ((i == 3 and t < T_UP) or (t >= T_UP and t < T_FALL and (t / 6 + i) % 2 == 0))
		r.draw_rect(Rect2(pnl.position + Vector2(3, 2 + i * 3), Vector2(2, 2)), (C_ALARM if t >= T_UP else C_LAMP) if on else Color("3a3d47"))
	if not _crashed():
		return
	# --- a cabine destruída
	var k := clampf(float(t - T_FALL) / 300.0, 0.0, 1.0)   # o mofo se espalha com o tempo
	var cracks := [[Vector2(20, 12), Vector2(26, 22), Vector2(23, 30), Vector2(30, 42)],
		[Vector2(ins.end.x - 16, 10), Vector2(ins.end.x - 22, 20), Vector2(ins.end.x - 18, 27)],
		[Vector2(ins.get_center().x + 8, ins.end.y - 2), Vector2(ins.get_center().x + 12, ins.end.y - 12), Vector2(ins.get_center().x + 6, ins.end.y - 20)]]
	for cr in cracks:
		r.draw_polyline(PackedVector2Array(cr), Color("0c0c10"), 1.0)
	# mofo: manchas que crescem a partir dos cantos e das rachaduras
	var spots := [Vector2(10, ins.end.y - 3), Vector2(18, ins.end.y - 6), Vector2(ins.end.x - 4, ins.end.y - 4),
		Vector2(ins.end.x - 10, 12), Vector2(24, 24), Vector2(ins.get_center().x + 10, ins.end.y - 14),
		Vector2(12, 14), Vector2(ins.end.x - 26, ins.end.y - 2)]
	for i in spots.size():
		var rad: float = (4.0 + float(i % 3) * 2.0) * k
		var c: Vector2 = spots[i]
		r.draw_circle(c, rad + 2.0, Color(C_MOLD, 0.18))
		r.draw_circle(c, rad, Color(C_MOLD, 0.45))
		if k > 0.5 and i % 2 == 0:
			r.draw_rect(Rect2(c + Vector2(-1, -rad - 2), Vector2(1, 2)), Color("cfc6d8"))
			r.draw_rect(Rect2(c + Vector2(-2, -rad - 3), Vector2(3, 1)), C_CAP)
	# entulho no chão
	for i in 7:
		var dx := ins.position.x + 6.0 + float((i * 37) % int(ins.size.x - 12))
		r.draw_rect(Rect2(dx, ins.end.y - 2 - (i % 2), 3 + i % 3, 2 + (i % 2)), Color("2f323b"))


func _draw_hall_back(r) -> void:
	var d := Rect2(r.door)
	var fr := d.grow_individual(4, 6, 4, 0)
	# a moldura do elevador, as portas de correr abertas e a cabine acesa lá dentro
	r.draw_rect(fr, Color("3a3d47"))
	r.draw_rect(d, Color("2a2c33"))
	r.draw_rect(Rect2(d.position.x, d.position.y, d.size.x, 2), Color(C_TUBE, 0.7))
	r.draw_colored_polygon(PackedVector2Array([d.position + Vector2(2, 2), d.position + Vector2(d.size.x - 2, 2),
		d.end + Vector2(4, 0), Vector2(d.position.x - 4, d.end.y)]), Color(C_TUBE, 0.10))
	r.draw_rect(Rect2(d.position.x - 6, d.position.y, 4, d.size.y), Color("4c4f57"))
	r.draw_rect(Rect2(d.end.x + 2, d.position.y, 4, d.size.y), Color("4c4f57"))
	# indicador (seta acesa) e o painel de chamada
	var ind := Vector2(d.get_center().x, fr.position.y - 5)
	r.draw_rect(Rect2(ind - Vector2(6, 3), Vector2(12, 6)), Color("1a1b20"))
	r.draw_colored_polygon(PackedVector2Array([ind + Vector2(-3, 2), ind + Vector2(3, 2), ind + Vector2(0, -2)]), Color(C_LAMP, 0.6 + 0.4 * sin(t * 0.1)))
	var pnl := Rect2(fr.position.x - 10, d.get_center().y - 4, 5, 9)
	r.draw_rect(pnl, Color("2c2f37"))
	r.draw_rect(Rect2(pnl.position + Vector2(1, 2), Vector2(3, 2)), C_LAMP)
	r.draw_rect(Rect2(pnl.position + Vector2(1, 5), Vector2(3, 2)), Color("3a3d47"))
	# listras de aviso no chão em frente
	for i in 6:
		r.draw_rect(Rect2(fr.position.x - 4 + i * 6, d.end.y - 2, 3, 2), Color("d9b440") if i % 2 == 0 else Color("1c1c20"))


# ---------------------------------------------------------------- frente (por cima de tudo)

func _draw() -> void:
	if room == null:
		return
	var base := Transform2D(room.view_angle, Vector2.ZERO) * Transform2D(0.0, -room.cam.round())
	draw_set_transform_matrix(base)
	if mode == "hall":
		# a luz fria saindo da cabine pelo chão do hall
		var d := Rect2(room.door)
		draw_colored_polygon(PackedVector2Array([d.position + Vector2(0, d.size.y), d.end,
			d.end + Vector2(20, 0), Vector2(d.position.x - 40, d.end.y)]), Color(C_TUBE, 0.06))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	var pw: float = room.pw
	var ph: float = room.ph
	var ins := _inside()
	var top := -300.0
	var bot := ph + 300.0
	if t < T_FALL:
		_draw_shaft(pw, ph, top, bot)
	# --- luz e escuro
	var world := Rect2(-400, -400, pw + 800, ph + 800)
	if t < T_UP:
		# a luminária fluorescente do teto, com um cone; o resto na penumbra
		draw_rect(world, Color(0.01, 0.01, 0.02, 0.38))
		_draw_tube(1.0 if (t / 4) % 53 != 0 else 0.3)
		# as luzes do poço varrem a cabine na subida
		if t >= T_START:
			var band := fposmod(scroll * 1.0, 150.0) - 40.0
			if band > -20.0 and band < ph + 20.0:
				draw_rect(Rect2(ins.position.x, band, ins.size.x, 10), Color(C_LAMP, 0.07))
	elif t < T_JAM:
		draw_rect(world, Color(0.02, 0.0, 0.01, 0.5))
		var a := 0.20 if (t / 12) % 2 == 0 else 0.05
		draw_rect(ins, Color(C_ALARM, a))
		draw_circle(Vector2(ins.end.x - 6, 10), 22.0, Color(C_ALARM, a * 0.8))
		_draw_tube(0.25)
	elif t < T_FALL:
		draw_rect(world, Color(0.01, 0.0, 0.01, 0.62))
		if (t / 3) % 5 != 0 and (t / 12) % 2 == 0:
			draw_rect(ins, Color(C_ALARM, 0.12))
		_draw_tube(1.0 if (t / 2) % 7 == 0 else 0.0)
		# a luz do poço passa rápido para cima
		var band2 := fposmod(scroll * 1.0, 150.0) - 40.0
		draw_rect(Rect2(ins.position.x, band2, ins.size.x, 6), Color(C_LAMP, 0.06))
	else:
		var dark := 1.0
		if t >= T_DARK:
			dark = 1.0 - 0.55 * clampf(float(t - T_DARK) / float(T_LIGHT - T_DARK), 0.0, 1.0)
		draw_rect(world, Color(0.02, 0.01, 0.03, dark))
		if t >= T_DARK:
			var k := clampf(float(t - T_DARK) / float(T_LIGHT - T_DARK), 0.0, 1.0)
			# luz roxa de fora, entrando pela fresta da porta e pelas rachaduras
			var dc := _door_c()
			draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -14), dc + Vector2(0, 14), dc + Vector2(-60, 22), dc + Vector2(-70, -4)]), Color(C_PURPLE, 0.10 * k))
			for i in 3:
				draw_circle(dc, 10.0 + i * 9.0, Color(C_PURPLE, 0.05 * k))
			draw_line(Vector2(26, 22), Vector2(46, 60), Color(C_PURPLE, 0.08 * k), 3.0)
			# o painel do teto, solto de um lado, pendurado
			var hinge := Vector2(ins.end.x - 30, ins.position.y)
			var sw := sin(t * 0.04) * 0.08
			var tip := hinge + Vector2.from_angle(1.15 + sw) * 20.0
			draw_line(hinge, tip, Color("3a3d47"), 3.0)
			draw_line(hinge, tip, Color("4c4f57"), 1.0)
			# a luminária quebrada: pendurada torta por um fio, piscando
			var lp := _tube_pos() + Vector2(6, 8)
			var on := (t / 5) % 9 == 0 or (t / 3) % 31 == 0
			draw_line(_tube_pos(), lp, C_RAIL, 1.0)
			draw_line(lp, lp + Vector2(10, 4), Color(C_TUBE, 0.9 if on else 0.25), 2.0)
			if on:
				draw_circle(lp + Vector2(5, 2), 18.0, Color(C_TUBE, 0.06))
			# fios de micélio descendo pelas frestas do teto
			for i in 5:
				var mx := ins.position.x + 10.0 + i * (ins.size.x - 20.0) / 4.0
				var ln := (6.0 + float((i * 7) % 9)) * k
				for j in int(ln):
					draw_rect(Rect2(mx + sin(j * 0.5 + i + t * 0.02) * 0.8, ins.position.y + j, 1, 1), Color(C_MYCEL, 0.45))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_tube(on: float) -> void:
	var tp := _tube_pos()
	draw_rect(Rect2(tp - Vector2(1, 1), Vector2(22, 4)), Color("3a3d47"))
	draw_rect(Rect2(tp, Vector2(20, 2)), Color(C_TUBE, 0.25 + 0.75 * on))
	if on > 0.0:
		var ins := _inside()
		draw_colored_polygon(PackedVector2Array([tp + Vector2(-2, 2), tp + Vector2(22, 2),
			Vector2(tp.x + 44, ins.end.y), Vector2(tp.x - 24, ins.end.y)]), Color(C_TUBE, 0.07 * on))


func _draw_shaft(pw: float, ph: float, top: float, bot: float) -> void:
	# o poço: paredes, trilhos, vigas e lâmpadas passando
	draw_rect(Rect2(-110, top, 102, bot - top), C_SHAFT)
	draw_rect(Rect2(pw + 8, top, 102, bot - top), C_SHAFT)
	for x in [-14.0, pw + 10.0]:
		draw_rect(Rect2(x, top, 4, bot - top), C_RAIL)
		draw_rect(Rect2(x + 1, top, 1, bot - top), Color("6a6d75"))
	var off := fposmod(scroll, 48.0)
	var y := top + off
	while y < bot:
		draw_rect(Rect2(-110, y, 102, 3), C_BEAM)
		draw_rect(Rect2(pw + 8, y, 102, 3), C_BEAM)
		y += 48.0
	var loff := fposmod(scroll, 150.0)
	var ly := top + loff
	while ly < bot:
		for lx in [-44.0, pw + 44.0]:
			for i in 3:
				draw_circle(Vector2(lx, ly), 8.0 + i * 8.0, Color(C_LAMP, 0.035))
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

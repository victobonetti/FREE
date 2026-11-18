extends Node2D
## O mapa do mundo, no alto da tela (modo mundo, D100). Uma casa por sala: visitadas cheias, a atual
## piscando, as vizinhas que se veem pelas saídas (ainda não visitadas) só com o contorno; um
## tracinho em cada saída das salas visitadas. Coordenadas da tela (320 de largura).

const World := preload("res://scripts/world.gd")

const CELL := Vector2(11, 7)
const GAP := 3.0
const TOP := 3.0
const C_FILL := Color("8a8a9e")
const C_HERE := Color("f3cf3b")
const C_KNOWN := Color(1, 1, 1, 0.35)
const C_PANEL := Color(0.03, 0.03, 0.05, 0.6)

var world: Dictionary = {}
var current := ""
var visited := {}
var sides := {}      # id -> lados com saída (cache)
var anim := 0
var screen_w := 320.0


func _process(_d: float) -> void:
	anim += 1
	queue_redraw()


func _sides_of(id: String) -> Array:
	if not sides.has(id):
		var d = World.load_room_data(id)
		sides[id] = World.exit_sides(d.rows) if d != null else []
	return sides[id]


func _draw() -> void:
	if world.is_empty():
		return
	# quais casas aparecem: as visitadas e as vizinhas delas por uma saída
	var show := {}
	for id in visited:
		show[id] = true
		for sd in _sides_of(id):
			var nb := World.neighbor(world, id, sd)
			if nb != "":
				show[nb] = show.get(nb, false)
	if show.is_empty():
		return
	var lo := Vector2i(9999, 9999)
	var hi := Vector2i(-9999, -9999)
	for id in show:
		var p := World.pos_of(world, id)
		lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
		hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
	var cols := hi.x - lo.x + 1
	var rows := hi.y - lo.y + 1
	var step := CELL + Vector2(GAP, GAP)
	var size := Vector2(cols, rows) * step - Vector2(GAP, GAP)
	var origin := Vector2(roundf((screen_w - size.x) / 2.0), TOP)
	draw_rect(Rect2(origin - Vector2(3, 2), size + Vector2(6, 4)), C_PANEL)
	for id in show:
		var p := World.pos_of(world, id) - lo
		var r := Rect2(origin + Vector2(p) * step, CELL)
		var seen: bool = show[id]
		if id == current:
			var a := 0.75 + 0.25 * sin(anim * 0.15)
			draw_rect(r, Color(C_HERE, a))
		elif seen:
			draw_rect(r, C_FILL)
		else:
			draw_rect(r, C_KNOWN, false, 1.0)
		if seen:
			for sd in _sides_of(id):
				var c := r.get_center()
				var v: Vector2 = Vector2(World.SIDES[sd])
				var a0 := c + v * Vector2(CELL.x / 2.0, CELL.y / 2.0)
				draw_line(a0, a0 + v * (GAP / 2.0 + 0.5), Color(C_HERE, 0.8) if id == current else C_FILL, 1.0)

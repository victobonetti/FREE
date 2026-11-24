extends Node2D
## O mapa do mundo (D100, D120), desenhado em coordenadas da tela (320×180).
##
## No alto, o mapinho: as salas visitadas perto da atual, em escala (cada sala com o tamanho dela), a
## atual piscando em amarelo, as vizinhas vistas pelas saídas (ainda não visitadas) só com o contorno.
## Com `full` (M, Tab ou Select), o mapa inteiro do que já foi visitado, com a sala atual, as tocas de
## salvar, os chefes vencidos e os itens vistos e ainda não pegos.

const World := preload("res://scripts/world.gd")

const C_FILL := Color("5c5c70")
const C_HERE := Color("f3cf3b")
const C_KNOWN := Color(1, 1, 1, 0.35)
const C_PANEL := Color(0.03, 0.03, 0.05, 0.6)
const C_DOOR := Color("c9c3b6")
const THEME_COL := {"raizes": Color("8a6a48"), "caverna": Color("7a6450"), "aquifero": Color("4a6a80"),
	"despensa": Color("8a7a4a"), "industrial": Color("4f6a88"), "transicao": Color("6a6a74"),
	"fungos": Color("6e5a8c"), "laboratorio": Color("8a4a54"), "campo": Color("5e7a4a")}

var world: Dictionary = {}
var state: RefCounted        # world_state.gd
var current := ""
var anim := 0
var screen_w := 320.0
var full := false


func _process(_d: float) -> void:
	anim += 1
	queue_redraw()


## As salas a mostrar: as visitadas e, só com o contorno, as vizinhas delas pelas saídas.
func _shown() -> Dictionary:
	var show := {}
	if state == null:
		return show
	for id in state.visited:
		if not World.has_room(world, id):
			continue
		show[id] = true
		var exs: Array = World.info(id)["exits"]
		for k in exs.size():
			var to := World.link(world, id, k, 0, state.roses)
			if not to.is_empty():
				show[str(to["room"])] = show.get(str(to["room"]), false)
	return show


func _draw() -> void:
	if world.is_empty() or state == null:
		return
	var show := _shown()
	if show.is_empty():
		return
	if full:
		_draw_full(show)
	else:
		_draw_mini(show)


func _room_col(id: String) -> Color:
	return THEME_COL.get(World.info(id)["theme"], C_FILL)


## O mapinho: uma janela de 3×2 telas em volta da sala atual, a 1 px por 4 tiles.
func _draw_mini(show: Dictionary) -> void:
	var k := 0.25
	var win := Vector2(World.UNIT) * Vector2(3, 2) * k
	var origin := Vector2(roundf((screen_w - win.x) / 2.0), 3.0)
	var here := World.rect_of(world, current)
	var center := Vector2(here.get_center())
	draw_rect(Rect2(origin - Vector2(2, 2), win + Vector2(4, 4)), C_PANEL)
	var clip := Rect2(origin, win)
	for id in show:
		var r := World.rect_of(world, id)
		var p := origin + win / 2.0 + (Vector2(r.position) - center) * k
		var rr := Rect2(p, Vector2(r.size) * k).intersection(clip)
		if rr.size.x <= 0.5 or rr.size.y <= 0.5:
			continue
		if id == current:
			draw_rect(rr, Color(C_HERE, 0.75 + 0.25 * sin(anim * 0.15)))
		elif show[id]:
			draw_rect(rr, _room_col(id))
		else:
			draw_rect(rr, C_KNOWN, false, 1.0)


## O mapa inteiro (pausa): encaixa tudo que foi visitado na tela.
func _draw_full(show: Dictionary) -> void:
	draw_rect(Rect2(0, 0, screen_w, 180), Color(0.02, 0.02, 0.04, 0.92))
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for id in show:
		var r := World.rect_of(world, id)
		lo = Vector2(minf(lo.x, r.position.x), minf(lo.y, r.position.y))
		hi = Vector2(maxf(hi.x, r.end.x), maxf(hi.y, r.end.y))
	var area := Vector2(screen_w - 20.0, 140.0)
	var span := (hi - lo).max(Vector2(1, 1))
	var k := minf(area.x / span.x, area.y / span.y)
	k = minf(k, 0.5)
	var origin := Vector2(10, 22) + (area - span * k) / 2.0
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(10, 14), "Mapa", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.9))
	var hab := ""
	for a in ["A1", "A2", "A3", "A4", "A5", "A6", "A7"]:
		if state.abilities.has(a):
			hab += a + " "
	draw_string(font, Vector2(60, 14), hab, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("6fc8ff"))
	for id in show:
		var r := World.rect_of(world, id)
		var rr := Rect2(origin + (Vector2(r.position) - lo) * k, Vector2(r.size) * k)
		if id == current:
			draw_rect(rr, Color(C_HERE, 0.75 + 0.25 * sin(anim * 0.15)))
		elif show[id]:
			draw_rect(rr, _room_col(id))
			draw_rect(rr, Color(1, 1, 1, 0.15), false, 1.0)
		else:
			draw_rect(rr, C_KNOWN, false, 1.0)
			continue
		# as saídas: um tracinho na borda
		for ex in World.info(id)["exits"]:
			var er: Rect2i = ex["rect"]
			var c := origin + (Vector2(r.position + er.position) + Vector2(er.size) / 2.0 - lo) * k
			draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), C_DOOR)
		_draw_marks(id, rr, k, r)
	draw_string(font, Vector2(10, 174), "M / Tab: voltar", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.5))


## Os ícones da sala no mapa inteiro: toca (verde), chefe vencido (estrela), item visto e não pego.
func _draw_marks(id: String, rr: Rect2, k: float, r: Rect2i) -> void:
	var d := World.load_room_def(id)
	for t in d.get("tocas", []):
		var a: Array = t["rect"]
		draw_rect(Rect2(rr.position + Vector2(int(a[0]), int(a[1])) * k, Vector2(2, 2)), Color("7fe08a"))
	var il: Array = d.get("items", [])
	for i in il.size():
		if state.taken.has("%s:%d" % [id, i]):
			continue
		var a: Array = il[i]["rect"]
		draw_rect(Rect2(rr.position + Vector2(int(a[0]), int(a[1])) * k - Vector2(1, 1), Vector2(2, 2)), Color("6fc8ff"))
	if state.bosses.has(id):
		draw_string(ThemeDB.fallback_font, rr.get_center() - Vector2(3, -3), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, C_HERE)

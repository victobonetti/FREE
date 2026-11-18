extends Node2D
## O presságio do chefe do ato 3 (D111). Ator da sala (campo "actors"); a área do gatilho é o campo
## "omen" da sala ([coluna, linha, largura, altura], em tiles, como a fase foi desenhada). Quando o
## coelho entra nela, a terra treme três vezes, cai poeira do teto e uma sombra enorme, com dois olhos
## apagados, passa devagar ao fundo da sala. Não interfere no jogo.

const LEN := 200

var room
var zone := Rect2i()
var t := -1


func on_reset(r) -> void:
	room = r
	var z: Array = r.def.get("omen", [0, 0, 0, 0])
	zone = Rect2i(int(z[0]) * 8, int(z[1]) * 8, int(z[2]) * 8, int(z[3]) * 8)
	t = -1


func on_rotate(r, dir: int) -> void:
	zone = r._rot_rect(zone, dir)


func step(r) -> void:
	room = r
	if t < 0:
		if zone.size.x > 0 and r.overlaps(r.rabbit.rect, zone):
			t = 0
		return
	if t >= LEN:
		return
	t += 1
	if t == 1 or t == 55 or t == 115:
		r.shake = maxf(r.shake, 3.5 if t > 1 else 2.0)
		r.impact.emit(1.2)
		r.sfx.emit("crunch")
		for i in 10:
			r.particles.append({
				"pos": Vector2(randf_range(8.0, r.pw - 8.0), 9.0),
				"vel": Vector2(randf_range(-6.0, 6.0), randf_range(10.0, 40.0)),
				"life": randi_range(30, 60), "col": Color(0.55, 0.5, 0.6, 0.8), "grav": 40.0,
			})


func _process(_d: float) -> void:
	queue_redraw()


## A sombra passa ao fundo, atrás das peças e do coelho.
func draw_back(r) -> void:
	if t < 0 or t >= LEN:
		return
	var k := float(t) / LEN
	var a := sin(k * PI) * 0.55
	var c := Vector2(lerpf(r.pw + 60.0, -60.0, k), r.ph * 0.45 + sin(t * 0.05) * 6.0)
	var body := Color(0.03, 0.02, 0.05, a)
	r.draw_circle(c, 70.0, body)
	r.draw_circle(c + Vector2(60, 18), 50.0, body)
	r.draw_circle(c + Vector2(-50, 24), 44.0, body)
	# dois olhos foscos, que piscam devagar
	if (t / 30) % 5 != 3:
		for e in [Vector2(-22, -14), Vector2(14, -18)]:
			r.draw_circle(c + e, 5.0, Color(0.75, 0.5, 0.95, a * 0.5))
			r.draw_circle(c + e, 2.0, Color(0.95, 0.85, 1.0, a * 0.8))

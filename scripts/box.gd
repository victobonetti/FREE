extends RefCounted
## Caixa: movimento cinemático em pixels inteiros. Só desliza (empurrada) e cai reta.

const SIZE := 16

var pos := Vector2i.ZERO
var vel_y := 0.0
var rem_y := 0.0
var fall_dist := 0  # pixels percorridos na queda atual; vira a força do impacto ao pousar
var settled := false  # true quando está apoiada (usado pelo compartimento)

var rect: Rect2i:
	get:
		return Rect2i(pos, Vector2i(SIZE, SIZE))


func _init(p: Vector2i = Vector2i.ZERO) -> void:
	pos = p

extends RefCounted
## Coelho: controlador escrito à mão, em pixels inteiros (estilo Celeste).
## Todo o jogo roda no referencial "lógico", onde a gravidade é sempre para baixo;
## quando a sala gira, os dados são rotacionados (ver room.gd), então o controle nunca muda.

const SIZE := 12  # hitbox quadrada: gira sem mudar de forma
const DT := 1.0 / 60.0

# --- Ajuste fino (px, s) ---
const MAX_SPEED := 72.0
const PUSH_SPEED := 36.0
const GROUND_ACCEL := 800.0
const GROUND_DECEL := 650.0
const AIR_ACCEL := 520.0
const AIR_DECEL := 260.0
const GRAVITY := 900.0
const APEX_MULT := 0.5        # gravidade pela metade perto do ápice, segurando o botão
const APEX_THRESHOLD := 40.0
const MAX_FALL := 160.0
const JUMP_SPEED := 110.0
const VAR_JUMP_FRAMES := 12   # segurando o pulo, a velocidade de subida é mantida por este tempo
const COYOTE_FRAMES := 6
const BUFFER_FRAMES := 6
const CORNER_CORRECT := 4
const LEDGE_ASSIST := 3

var pos := Vector2i.ZERO  # canto superior esquerdo da hitbox
var rem := Vector2.ZERO
var vel := Vector2.ZERO
var facing := 1
var on_ground := false
var was_ground := false
var coyote := 0
var jump_buf := 0
var var_jump := 0
var air_rot := true  # um giro no ar por pulo
var pushing := false
var impact := 0.0
var squash := Vector2.ONE
var anim := 0.0       # pixels realmente andados, para alternar os quadros da corrida
var run_t := 0        # quadros restantes de "correndo" (histerese: evita piscar contra a parede)
var push_t := 0       # idem, para "empurrando"
var ev_jump := false  # eventos de um quadro, lidos pela sala (poeira)
var ev_land := false

var rect: Rect2i:
	get:
		return Rect2i(pos, Vector2i(SIZE, SIZE))


func on_rotate() -> void:
	vel = Vector2.ZERO
	rem = Vector2.ZERO
	coyote = 0
	jump_buf = 0
	var_jump = 0
	on_ground = false
	was_ground = false
	impact = 0.0


func update(room, inp: Dictionary) -> void:
	var mx: float = inp.get("move", 0.0)
	var jump_pressed: bool = inp.get("jump_pressed", false)
	var jump_held: bool = inp.get("jump_held", false)
	ev_jump = false
	ev_land = false

	was_ground = on_ground
	on_ground = _grounded(room)
	if on_ground:
		coyote = COYOTE_FRAMES
		air_rot = true
		if not was_ground and impact > 60.0:
			var k := clampf(impact / MAX_FALL, 0.0, 1.0)
			squash = Vector2(1.0 + 0.3 * k, 1.0 - 0.3 * k)
			ev_land = true
		impact = 0.0
	else:
		coyote = maxi(coyote - 1, 0)
	if jump_pressed:
		jump_buf = BUFFER_FRAMES
	else:
		jump_buf = maxi(jump_buf - 1, 0)

	# --- Horizontal ---
	var target := mx * MAX_SPEED
	var rate := 0.0
	pushing = false
	if absf(mx) > 0.1:
		facing = 1 if mx > 0.0 else -1
		if on_ground and room.box_at(Rect2i(pos + Vector2i(facing, 0), Vector2i(SIZE, SIZE)), null) != null:
			target = mx * PUSH_SPEED
			pushing = true
		rate = GROUND_ACCEL if on_ground else AIR_ACCEL
		if signf(vel.x) != 0.0 and signf(vel.x) != signf(mx):
			rate *= 1.5
	else:
		rate = GROUND_DECEL if on_ground else AIR_DECEL
	vel.x = move_toward(vel.x, target, rate * DT)

	# --- Vertical ---
	var g := GRAVITY
	if not on_ground and jump_held and absf(vel.y) < APEX_THRESHOLD:
		g *= APEX_MULT
	vel.y = minf(vel.y + g * DT, MAX_FALL)

	if var_jump > 0:
		if jump_held:
			vel.y = minf(vel.y, -JUMP_SPEED)
			var_jump -= 1
		else:
			var_jump = 0

	if jump_buf > 0 and coyote > 0:
		vel.y = -JUMP_SPEED
		var_jump = VAR_JUMP_FRAMES
		jump_buf = 0
		coyote = 0
		on_ground = false
		squash = Vector2(0.8, 1.2)
		ev_jump = true

	var x0 := pos.x
	_move_x(room, vel.x * DT)
	_move_y(room, vel.y * DT)
	# A animação segue o movimento real: andar contra a parede não troca de quadro.
	var dx := absi(pos.x - x0)
	anim += dx
	if dx > 0 and on_ground:
		run_t = 5
		push_t = 5 if pushing else maxi(push_t - 1, 0)
	else:
		run_t = maxi(run_t - 1, 0)
		push_t = maxi(push_t - 1, 0)
	squash = squash.lerp(Vector2.ONE, 0.18)


func _grounded(room) -> bool:
	var r := Rect2i(pos + Vector2i(0, 1), Vector2i(SIZE, SIZE))
	return room.solid_static(r) or room.box_at(r, null) != null


func _free(room, r: Rect2i) -> bool:
	return not room.solid_static(r) and room.box_at(r, null) == null


func _move_x(room, amount: float) -> void:
	rem.x += amount
	var steps := int(roundf(rem.x))
	rem.x -= steps
	var s := signi(steps)
	while steps != 0:
		var nxt := Rect2i(pos + Vector2i(s, 0), Vector2i(SIZE, SIZE))
		var blocked := false
		if room.solid_static(nxt):
			blocked = true
		else:
			var b = room.box_at(nxt, null)
			if b != null and not room.push_box(b, Vector2i(s, 0)):
				blocked = true
		if blocked:
			if vel.y < 0.0 and _ledge_assist(room, s):
				continue
			vel.x = 0.0
			rem.x = 0.0
			break
		pos.x += s
		steps -= s


func _move_y(room, amount: float) -> void:
	rem.y += amount
	var steps := int(roundf(rem.y))
	rem.y -= steps
	var s := signi(steps)
	while steps != 0:
		var nxt := Rect2i(pos + Vector2i(0, s), Vector2i(SIZE, SIZE))
		if not _free(room, nxt):
			if s < 0 and _corner_correct(room):
				continue
			if s > 0:
				impact = maxf(impact, vel.y)
			else:
				var_jump = 0
			vel.y = 0.0
			rem.y = 0.0
			break
		pos.y += s
		steps -= s


## Bate a cabeça de leve na quina: empurra para o lado até 4 px.
func _corner_correct(room) -> bool:
	for k in range(1, CORNER_CORRECT + 1):
		for sgn in [-1, 1]:
			var up := Rect2i(pos + Vector2i(sgn * k, -1), Vector2i(SIZE, SIZE))
			var same := Rect2i(pos + Vector2i(sgn * k, 0), Vector2i(SIZE, SIZE))
			if _free(room, up) and _free(room, same):
				pos.x += sgn * k
				return true
	return false


## Subindo e batendo na quina de um degrau: sobe até 3 px para encaixar.
func _ledge_assist(room, s: int) -> bool:
	for k in range(1, LEDGE_ASSIST + 1):
		var r := Rect2i(pos + Vector2i(s, -k), Vector2i(SIZE, SIZE))
		var column := Rect2i(pos + Vector2i(0, -k), Vector2i(SIZE, SIZE))
		if _free(room, r) and _free(room, column):
			pos.y -= k
			return true
	return false

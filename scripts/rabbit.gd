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

# --- Corda (pêndulo) ---
const ROPE_GRAVITY := 900.0
const ROPE_DAMP := 0.997      # perda de velocidade angular por quadro, no arco depois do giro
const ROPE_REST_DAMP := 0.9   # idem com a corda pendendo do teto: o coelho logo fica parado
const ROPE_MIN := 10.0        # raio mínimo do pêndulo (px)
const ROPE_REGRAB := 18       # quadros sem agarrar de novo depois de soltar
const ROPE_HOP := 40.0        # impulso para cima ao soltar com o botão de pulo
const ROPE_CLIMB := 44.0      # velocidade descendo pela corda (px/s); não dá para subir
const LAUNCH_DRAG := 90.0     # no ar, acima de MAX_SPEED, a velocidade cai devagar (arremesso)
const FALL_DECEL := 300.0     # idem para a queda acima de MAX_FALL

# --- Água ---
const FLOAT_FRAC := 0.6       # fração submersa em que o coelho boia (cabeça para fora)
const WATER_DRAG := 0.08      # perda de velocidade por quadro, totalmente submerso
const SWIM_SPEED := 0.6       # multiplicador da velocidade horizontal na água
const SWIM_JUMP := 100.0      # pulo a partir da superfície
const SWIM_MIN := 0.3         # fração submersa a partir da qual conta como "na água"
const SWIM_CD := 15           # quadros entre dois pulos na água

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
var ev_grab := false
var ev_release := false
var ev_splash := 0.0  # velocidade de entrada na água (0 = não entrou neste quadro)

var rope = null       # corda em que está pendurado (dicionário da sala), ou null
var rope_r := 0.0     # raio do pêndulo: distância da âncora ao centro do coelho
var rope_a := 0.0     # ângulo a partir da vertical (0 = pendurado reto; + para a direita)
var rope_w := 0.0     # velocidade angular
var rope_cd := 0
var jumping := false  # no ar por causa de um pulo (ou de ter soltado a corda): só assim agarra
var last_rope = null  # a corda que acabou de soltar: só volta a agarrá-la depois de pousar

var fast := false     # acima das velocidades normais neste quadro (arremesso da corda)
var wet := 0.0        # fração do corpo dentro da água (0 a 1)
var swim_cd := 0

var rect: Rect2i:
	get:
		return Rect2i(pos, Vector2i(SIZE, SIZE))


## Pode girar a sala: no chão, com o giro do ar, pendurado na corda ou boiando.
func can_rotate() -> bool:
	return on_ground or air_rot or rope != null or wet >= SWIM_MIN


## O giro sem apoio gasta o giro do ar; pendurado ou na água, não.
func free_rotate() -> bool:
	return on_ground or rope != null or wet >= SWIM_MIN


func on_rotate() -> void:
	if rope != null:
		# a sala já girou a âncora e o coelho: o pêndulo continua, a partir do novo ângulo
		var d: Vector2 = Vector2(pos) + Vector2(6, 6) - rope["anchor"]
		rope_a = atan2(d.x, d.y)
		rem = Vector2.ZERO
		return
	# "jumping" continua valendo: quem pulou e girou no ar pode agarrar a corda que o giro
	# acabou de pôr no teto. Quem girou do chão está com ele falso e passa pela corda.
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
	ev_grab = false
	ev_release = false
	ev_splash = 0.0
	rope_cd = maxi(rope_cd - 1, 0)
	swim_cd = maxi(swim_cd - 1, 0)
	if rope != null:
		_update_rope(room, jump_pressed, inp.get("climb", 0.0))
		return

	var wet_before := wet
	wet = room.water_frac(rect)
	if wet_before < 0.05 and wet >= 0.05 and vel.y > 70.0:
		ev_splash = vel.y
	if wet >= SWIM_MIN:
		air_rot = true

	was_ground = on_ground
	on_ground = _grounded(room)
	if on_ground:
		coyote = COYOTE_FRAMES
		air_rot = true
		jumping = false
		last_rope = null
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
	var top_speed := MAX_SPEED * lerpf(1.0, SWIM_SPEED, clampf(wet / FLOAT_FRAC, 0.0, 1.0))
	var target := mx * top_speed
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
	if not on_ground and wet < SWIM_MIN and absf(vel.x) > MAX_SPEED and (absf(mx) <= 0.1 or signf(mx) == signf(vel.x)):
		# arremessado pela corda: mantém o impulso, perdendo velocidade aos poucos
		vel.x = move_toward(vel.x, signf(vel.x) * MAX_SPEED, LAUNCH_DRAG * DT)
	else:
		vel.x = move_toward(vel.x, target, rate * DT)

	# --- Vertical ---
	var g := GRAVITY
	if not on_ground and jump_held and absf(vel.y) < APEX_THRESHOLD:
		g *= APEX_MULT
	if wet > 0.0:
		g -= GRAVITY / FLOAT_FRAC * wet  # empuxo: equilibra a gravidade com FLOAT_FRAC submerso
	if vel.y > MAX_FALL:
		vel.y = maxf(vel.y - FALL_DECEL * DT, MAX_FALL)
	else:
		vel.y = minf(vel.y + g * DT, MAX_FALL)
	if wet > 0.0:
		vel.y *= 1.0 - WATER_DRAG * wet
		# boiando em repouso: para de vez, sem ficar oscilando 1 px
		if not on_ground and absf(wet - FLOAT_FRAC) < 0.06 and absf(vel.y) < 10.0 and var_jump == 0:
			vel.y = 0.0
			rem.y = 0.0

	if var_jump > 0:
		if jump_held:
			vel.y = minf(vel.y, -JUMP_SPEED)
			var_jump -= 1
		else:
			var_jump = 0

	var swim := coyote == 0 and wet >= SWIM_MIN and wet < 0.95 and swim_cd == 0
	if jump_buf > 0 and (coyote > 0 or swim):
		vel.y = -(SWIM_JUMP if swim else JUMP_SPEED)
		var_jump = int(VAR_JUMP_FRAMES * 0.5) if swim else VAR_JUMP_FRAMES
		if swim:
			swim_cd = SWIM_CD
		jump_buf = 0
		coyote = 0
		on_ground = false
		jumping = true
		squash = Vector2(0.8, 1.2)
		ev_jump = true

	var x0 := pos.x
	# arremessado (acima das velocidades normais): confere porta e espinhos a cada pixel
	fast = absf(vel.x) > MAX_SPEED + 1.0 or absf(vel.y) > MAX_FALL + 1.0
	_move_x(room, vel.x * DT)
	if room.state == "play":
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

	# Só agarra a corda quem pulou (ou acabou de soltar outra): caindo depois de um giro, o
	# coelho passa por ela.
	if rope_cd == 0 and not on_ground and jumping:
		var rp = room.rope_at(rect)
		if rp != null and rp != last_rope:
			_grab(rp)


# ---------------------------------------------------------------- corda

func _grab(rp: Dictionary) -> void:
	rope = rp
	var d: Vector2 = Vector2(pos) + Vector2(6, 6) - rp["anchor"]
	rope_r = clampf(d.length(), ROPE_MIN, float(rp["len"]))
	rope_a = atan2(d.x, d.y)
	rope_w = 0.0
	vel = Vector2.ZERO
	rem = Vector2.ZERO
	var_jump = 0
	coyote = 0
	jump_buf = 0
	air_rot = true
	wet = 0.0
	squash = Vector2(0.9, 1.1)
	ev_grab = true


## Solta a corda, saindo com a velocidade do arco.
func _release(hop: bool) -> void:
	vel = Vector2(cos(rope_a), -sin(rope_a)) * rope_r * rope_w
	if hop:
		vel.y -= ROPE_HOP
	last_rope = rope
	jumping = true
	rope = null
	rope_cd = ROPE_REGRAB
	rem = Vector2.ZERO
	impact = 0.0
	ev_release = true


## Pendurado: um pêndulo em torno da âncora. O coelho não controla o balanço; quem dá
## movimento é o giro da sala. Baixo desce pela corda (aumenta o raio); não dá para subir.
## Pulo solta; bater em algo também.
func _update_rope(room, jump_pressed: bool, climb: float) -> void:
	on_ground = false
	was_ground = false
	coyote = 0
	var_jump = 0
	run_t = 0
	push_t = 0
	pushing = false
	if jump_pressed:
		_release(true)
		return
	var r_before := rope_r
	if climb > 0.1:
		rope_r = minf(rope_r + ROPE_CLIMB * DT, float(rope["len"]))
		# raio maior, giro mais lento (conserva o momento angular)
		rope_w *= (r_before / rope_r) * (r_before / rope_r)
		anim += absf(rope_r - r_before)
	rope_w -= ROPE_GRAVITY / rope_r * sin(rope_a) * DT
	rope_w *= ROPE_REST_DAMP if rope["facing"] == 2 else ROPE_DAMP
	rope_a += rope_w * DT
	vel = Vector2(cos(rope_a), -sin(rope_a)) * rope_r * rope_w
	if absf(vel.x) > 8.0:
		facing = 1 if vel.x > 0.0 else -1
	var c: Vector2 = rope["anchor"] + Vector2(sin(rope_a), cos(rope_a)) * rope_r
	var goal := Vector2i(roundi(c.x - 6.0), roundi(c.y - 6.0))
	while pos != goal:
		var d := goal - pos
		var st := Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
		if not _free(room, Rect2i(pos + st, Vector2i(SIZE, SIZE))):
			if rope_r != r_before and absf(rope_w * rope_r) < 30.0:
				rope_r = r_before  # descendo contra algo: só para
				return
			_release(false)
			return
		pos += st
		# rápido demais para conferir só no fim do quadro: porta e espinhos, pixel a pixel
		if room.touch_check():
			return
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
		if fast and room.touch_check():
			return


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
		if fast and room.touch_check():
			return


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

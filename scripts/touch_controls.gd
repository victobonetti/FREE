extends Node2D
## Controles de toque (celular/tablet): joystick flutuante à esquerda; pulo e os dois giros à direita;
## reiniciar no canto de cima. Só "apertam" as ações do InputMap (Input.action_press), então o
## resto do jogo não sabe que existe toque. Fica invisível até a primeira vez que a tela é tocada.
##
## Celular deitado é mais largo que 16:9: main alarga a tela para o formato do aparelho e os
## controles vão para as faixas laterais (set_layout), sem cobrir a sala. Em telas quase 16:9
## (tablets) as faixas não cabem os botões, e eles ficam por cima do jogo, translúcidos.
## Coordenadas em pixels da tela do jogo (altura 180).

signal touch_detected

const C_LINE := Color(0.93, 0.91, 0.85, 0.35)
const C_FILL := Color(0.93, 0.91, 0.85, 0.10)
const C_ON := Color(0.93, 0.91, 0.85, 0.45)
const C_GUTTER := Color(0.03, 0.03, 0.045, 1)   # mesma cor de fundo do projeto
const MIN_GUTTER := 30          # largura mínima (px) das faixas para os controles irem para elas

const STICK_DEAD := 0.35       # fração do raio para começar a andar
const STICK_DOWN := 0.55       # fração do raio (para baixo) para descer a corda

# Layout atual (set_layout). Botões: centro, raio desenhado, raio de toque (mais generoso).
var screen_w := 320
var gutter := 0                # largura de cada faixa lateral (0 = sem faixas)
var stick_home := Vector2(42, 140)   # o joystick nasce onde o dedo encosta; em repouso, aqui
var stick_radius := 18.0       # deslocamento máximo do miolo
var left_zone_x := 150.0       # toques à esquerda daqui são do joystick
var buttons := {}

var active := false            # já houve toque (ou é celular): desenha e responde
var hide_ui := false           # main esconde os controles na abertura
var stick_finger := -1
var stick_origin := Vector2(42, 140)
var stick_vec := Vector2.ZERO  # -1..1
var button_finger := {}        # nome do botão -> dedo
var fingers := {}              # dedos encostados agora


func _ready() -> void:
	# No navegador de celular já começa ativo, para a tela de início dizer "toque".
	active = OS.has_feature("web_android") or OS.has_feature("web_ios")
	visible = false
	set_layout(320, 0)


## Posiciona os controles para uma tela `w` px de largura com faixas laterais de `g` px.
func set_layout(w: int, g: int) -> void:
	screen_w = w
	gutter = g if g >= MIN_GUTTER else 0
	left_zone_x = w / 2.0
	if gutter > 0:
		var lx := gutter / 2.0
		var rx := w - gutter / 2.0
		var r := minf(gutter / 2.0 - 2.0, 15.0)
		stick_radius = minf(gutter / 2.0 - 5.0, 16.0)
		stick_home = Vector2(lx, 138)
		buttons = {
			"jump": {"pos": Vector2(rx, 152), "r": r, "hit": 24.0},
			"rotate_cw": {"pos": Vector2(rx, 114), "r": r - 3.0, "hit": 17.0},
			"rotate_ccw": {"pos": Vector2(rx, 84), "r": r - 3.0, "hit": 15.0},
			"restart": {"pos": Vector2(rx, 14), "r": 7.0, "hit": 13.0},
		}
	else:
		stick_radius = 18.0
		stick_home = Vector2(42, 140)
		buttons = {
			"jump": {"pos": Vector2(w - 30, 146), "r": 15.0, "hit": 24.0},
			"rotate_ccw": {"pos": Vector2(w - 76, 120), "r": 10.0, "hit": 17.0},
			"rotate_cw": {"pos": Vector2(w - 44, 106), "r": 10.0, "hit": 17.0},
			"restart": {"pos": Vector2(w - 11, 11), "r": 7.0, "hit": 13.0},
		}
	if stick_finger == -1:
		stick_origin = stick_home
	queue_redraw()


func _process(_delta: float) -> void:
	visible = active and not hide_ui


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not active:
			active = true
			touch_detected.emit()
		if event.pressed:
			_on_down(event.index, event.position)
		else:
			_on_up(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == stick_finger:
			_move_stick(event.position)
		get_viewport().set_input_as_handled()


func _on_down(finger: int, p: Vector2) -> void:
	fingers[finger] = true
	# qualquer toque confirma a tela de início ("start" não é usado dentro das salas)
	Input.action_press("start")
	var b := _button_at(p)
	if b != "":
		if not button_finger.has(b):
			button_finger[b] = finger
			_press(b)
		queue_redraw()
		return
	if p.x < left_zone_x and stick_finger == -1:
		stick_finger = finger
		stick_origin = p
		_move_stick(p)


func _on_up(finger: int) -> void:
	fingers.erase(finger)
	if fingers.is_empty():
		Input.action_release("start")
	if finger == stick_finger:
		stick_finger = -1
		stick_origin = stick_home
		stick_vec = Vector2.ZERO
		_apply_stick()
	for b in button_finger.keys():
		if button_finger[b] == finger:
			button_finger.erase(b)
			_release(b)
	queue_redraw()


func _button_at(p: Vector2) -> String:
	var best := ""
	var best_d := INF
	for b in buttons:
		var d: float = p.distance_to(buttons[b].pos)
		if d <= buttons[b].hit and d < best_d:
			best = b
			best_d = d
	return best


func _move_stick(p: Vector2) -> void:
	var v := (p - stick_origin) / stick_radius
	if v.length() > 1.0:
		# o joystick acompanha o dedo quando ele passa do limite
		stick_origin = p - v.normalized() * stick_radius
		v = v.normalized()
	stick_vec = v
	_apply_stick()
	queue_redraw()


func _apply_stick() -> void:
	_set_action("move_left", stick_vec.x < -STICK_DEAD)
	_set_action("move_right", stick_vec.x > STICK_DEAD)
	_set_action("climb_down", stick_vec.y > STICK_DOWN)


func _set_action(action: String, on: bool) -> void:
	if on and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not on and Input.is_action_pressed(action):
		Input.action_release(action)


func _press(b: String) -> void:
	Input.action_press(b)


func _release(b: String) -> void:
	Input.action_release(b)


# ---------------------------------------------------------------- desenho

func _draw() -> void:
	if gutter > 0:
		# faixas laterais opacas: salas maiores que a tela não aparecem por baixo dos controles
		draw_rect(Rect2(0, 0, gutter, 180), C_GUTTER)
		draw_rect(Rect2(screen_w - gutter, 0, gutter, 180), C_GUTTER)
	# joystick
	var held := stick_finger != -1
	draw_circle(stick_origin, stick_radius + 4, C_FILL, true, -1.0, false)
	draw_arc(stick_origin, stick_radius + 4, 0, TAU, 32, C_ON if held else C_LINE, 1.0, false)
	draw_circle(stick_origin + stick_vec * stick_radius, 7, C_ON if held else C_LINE, true, -1.0, false)
	# botões
	for b in buttons:
		var c: Vector2 = buttons[b].pos
		var r: float = buttons[b].r
		var on := button_finger.has(b)
		draw_circle(c, r, C_ON if on else C_FILL, true, -1.0, false)
		draw_arc(c, r, 0, TAU, 32, C_ON if on else C_LINE, 1.0, false)
		var ic := Color(0.93, 0.91, 0.85, 0.8 if on else 0.55)
		match b:
			"jump":
				draw_polyline([c + Vector2(-6, 3), c + Vector2(0, -3), c + Vector2(6, 3)], ic, 2.0, false)
			"rotate_ccw":
				_draw_turn(c, -1, ic)
			"rotate_cw":
				_draw_turn(c, 1, ic)
			"restart":
				draw_arc(c, 3.5, deg_to_rad(-60), deg_to_rad(240), 12, ic, 1.0, false)
				draw_line(c + Vector2(1.5, -4.5), c + Vector2(3.5, -2.5), ic, 1.0, false)


## Seta curva de giro: dir = 1 horário, -1 anti-horário.
func _draw_turn(c: Vector2, dir: int, col: Color) -> void:
	# Na tela o y cresce para baixo, então ângulo crescente = sentido horário.
	# Horário: da esquerda-baixo, por cima, até a direita-baixo; anti-horário é o espelho.
	var r := 5.0
	var a0 := deg_to_rad(150.0) if dir > 0 else deg_to_rad(30.0)
	var a1 := deg_to_rad(390.0) if dir > 0 else deg_to_rad(-210.0)
	draw_arc(c, r, a0, a1, 16, col, 1.5, false)
	# ponta da seta no fim do arco
	var tip := c + Vector2(cos(a1), sin(a1)) * r
	var tangent := Vector2(-sin(a1), cos(a1)) * signf(a1 - a0)
	var side := Vector2(cos(a1), sin(a1))
	draw_colored_polygon([tip + tangent * 3.0, tip + side * 2.5, tip - side * 2.5], col)

extends RefCounted
## O robô do mundo (D124): segue na física de verdade o caminho que o modelo (world_check.gd) acha
## numa sala, de onde o coelho está até uma saída (ou um item), e grava os comandos. A rota gravada é
## a prova de que a sala se atravessa; os testes rodam de novo e conferem por onde o coelho sai.
##
## O controle é por realimentação: a cada quadro acha em que ponto do caminho o coelho está (o estado
## mais adiante que bate com a célula e o giro dele) e decide: andar até o próximo ponto de ação,
## pular (de onde o caminho sobe), girar (de onde o caminho muda de giro, no chão ou no ar), subir ou
## descer pendurado e, no ar, dirigir para o x do caminho naquela altura. Saiu do caminho (caiu num
## lugar que o modelo não previa), planeja de novo dali.

const Check := preload("res://scripts/world_check.gd")

var room: Node2D
var def: Dictionary
var ab: Dictionary
var target                     # índice da saída, "iN" (item) ou "k@o" (abertura da rosa no giro o)
var path: Array = []           # [[giro, x, y, modo]] (células, na sala girada como está na tela)
var runs: Array = []           # os comandos gravados (formato do replay)
var i := 0
var log := ""
var jump_hold := 0
var rot_cool := 0
var lost := 0
var replans := 0
var debug := 0                 # imprime a cada N quadros (0: não)


## Leva o coelho até `done` ficar verdadeiro. Devolve true se chegou antes de `limit` quadros, sem morrer.
func drive(r: Node2D, d: Dictionary, abilities: Dictionary, tgt, done: Callable, limit := 6000) -> bool:
	room = r
	def = d
	ab = abilities
	target = tgt
	if not _replan():
		log = "o modelo não acha caminho de %s (giro %d) até %s" % [str(_cell()), posmod(room.orientation, 4), str(tgt)]
		return false
	var stuck := 0
	var best_i := 0
	for f in limit:
		if done.call():
			return true
		if room.state == "dead":
			log = "morreu no quadro %d, perto do passo %d %s (coelho %s)" % [f, i, str(path[mini(i, path.size() - 1)]), str(room.rabbit.pos)]
			return false
		if room.state != "play":
			_tick({})
			continue
		var matched := _locate()
		var settled: bool = (room.rabbit.on_ground or room.rabbit.rope != null) and not room.rotating
		if matched:
			lost = 0
		elif settled and i < path.size() - 4:
			lost += 1
			if lost >= 4:
				if not _replan():
					log = "perdeu o caminho em %s (giro %d) e o modelo não acha outro" % [str(_cell()), posmod(room.orientation, 4)]
					return false
				lost = 0
				best_i = 0
		if i > best_i:
			best_i = i
			stuck = 0
		else:
			stuck += 1
		if stuck > 300:
			if replans < 60 and settled and _replan():
				stuck = 0
				best_i = 0
			else:
				log = "parado no passo %d de %d %s (coelho %s, chão %s)" % [i, path.size(), str(path[mini(i, path.size() - 1)]), str(room.rabbit.pos), str(room.rabbit.on_ground)]
				return false
		var dec := _decide()
		if debug and f % debug == 0:
			print("    q%4d coelho %s chão %s giro %d  passo %d/%d %s  -> %s" % [f, str(room.rabbit.pos), str(room.rabbit.on_ground),
				posmod(room.orientation, 4), i, path.size(), str(path[mini(i, path.size() - 1)]), str(dec)])
		_tick(dec)
	log = "acabou o tempo no passo %d de %d" % [i, path.size()]
	return false


func _replan() -> bool:
	replans += 1
	Check.rot_extra = 12
	Check.ignore_exit = int(def.get("_entry_exit", -1))
	var p: Array = Check.trace_from(def, ab, _cell(), posmod(room.orientation, 4), target)
	Check.rot_extra = 0
	Check.ignore_exit = -1
	if p.is_empty():
		return false
	path = p
	i = 0
	return true


func _tick(inp: Dictionary) -> void:
	var cmd := {}
	if float(inp.get("move", 0.0)) != 0.0:
		cmd["move"] = snappedf(float(inp["move"]), 0.01)
	if inp.get("jump_pressed", false):
		cmd["jump_pressed"] = true
	if inp.get("jump_held", false):
		cmd["jump_held"] = true
	if int(inp.get("rotate", 0)) != 0:
		cmd["rotate"] = int(inp["rotate"])
	if inp.get("rotate2", false):
		cmd["rotate2"] = true
	if float(inp.get("climb", 0.0)) != 0.0:
		cmd["climb"] = snappedf(float(inp["climb"]), 0.01)
	if not runs.is_empty() and runs[-1][1] == cmd:
		runs[-1][0] += 1
	else:
		runs.append([1, cmd])
	room.step(cmd)


func _cell() -> Vector2i:
	var p: Vector2i = room.rabbit.pos
	return Vector2i(int(floor((p.x + 2) / 8.0)), int(floor((p.y + 2) / 8.0)))


## O ponto do caminho em que o coelho está: o mais adiante (numa janela) com o mesmo giro e a célula
## a até 1 de distância. false se nenhum bate.
func _locate() -> bool:
	var c := _cell()
	var o: int = posmod(room.orientation, 4)
	var best := -1
	var grounded: bool = room.rabbit.on_ground or room.rabbit.rope != null
	for j in range(maxi(i - 2, 0), mini(i + 80, path.size())):
		var s: Array = path[j]
		if int(s[0]) != o:
			continue
		# no ar, só estados no ar; no chão, só estados no chão (senão o robô "pousa" antes da hora)
		if (int(s[3]) == 0) != grounded:
			continue
		if absi(int(s[1]) - c.x) <= 1 and absi(int(s[2]) - c.y) <= 1:
			best = j
	if best >= 0:
		i = maxi(i, best) if best >= i - 2 else i
		i = best if best > i else i
		return true
	return false


func _decide() -> Dictionary:
	var rb = room.rabbit
	rot_cool = maxi(rot_cool - 1, 0)
	if room.rotating:
		return {"move": _steer_x(_air_target())}
	var cur: Array = path[i]
	var inp := {}
	if not rb.on_ground and rb.rope == null:
		# no ar: dirige; se o caminho gira no ar aqui, gira
		if i + 1 < path.size() and int(path[i + 1][0]) != int(cur[0]) and rot_cool == 0:
			rot_cool = 20
			if posmod(int(path[i + 1][0]) - int(cur[0]), 4) == 2:
				return {"rotate2": true, "move": _steer_x(_air_target())}
			inp["rotate"] = _rot_dir(int(cur[0]), int(path[i + 1][0]))
		inp["move"] = _steer_x(_air_target())
		inp["jump_held"] = jump_hold > 0
		jump_hold = maxi(jump_hold - 1, 0)
		return inp
	if i + 1 >= path.size():
		return _push_out()
	var nx: Array = path[i + 1]
	var c := _cell()
	var at_x: bool = c.x == int(cur[1])
	var dx := (float(cur[1]) + 1.0) * 8.0 - (float(rb.pos.x) + 6.0)
	# giro: só no ponto exato do caminho
	if int(nx[0]) != int(cur[0]):
		if not at_x or absf(dx) > 3.0:
			return {"move": clampf(dx / 6.0, -1.0, 1.0)}
		if rot_cool == 0:
			rot_cool = 20
			if posmod(int(nx[0]) - int(cur[0]), 4) == 2:
				return {"rotate2": true}
			return {"rotate": _rot_dir(int(cur[0]), int(nx[0]))}
		return {}
	# pulo: do ponto exato, dirigindo para onde o caminho pousa
	if int(nx[3]) != 0 and int(nx[2]) < int(cur[2]):
		if absf(dx) > 3.0:
			return {"move": clampf(dx / 6.0, -1.0, 1.0)}
		# segura o pulo o tanto da altura que o caminho sobe (110 px/s segurando; ~6,7 px depois)
		var top := int(cur[2])
		for j in range(i + 1, mini(i + 30, path.size())):
			if int(path[j][3]) == 0 or int(path[j][0]) != int(cur[0]):
				break
			top = mini(top, int(path[j][2]))
		var rise_px := float(int(cur[2]) - top) * 8.0 + 3.0
		jump_hold = clampi(roundi((rise_px - 6.7) / 1.83), 1, 13)
		return {"jump_pressed": true, "jump_held": true, "move": signf(float(_air_target_from(i + 1)) - float(cur[1]))}
	# pendurado (corda) ou nadando: sobe ou desce
	if int(nx[3]) == 0 and int(nx[2]) != int(cur[2]):
		if int(nx[2]) < int(cur[2]):
			return {"jump_held": true, "jump_pressed": rb.rope == null}
		return {"climb": 1.0}
	# andar (ou sair da beirada): para o x do passo seguinte (ou um pouco adiante, no mesmo rumo)
	var ahead := int(nx[1])
	for j in range(i + 1, mini(i + 6, path.size())):
		var s: Array = path[j]
		if int(s[0]) != int(cur[0]) or int(s[2]) != int(cur[2]) or int(s[3]) != 0:
			break
		ahead = int(s[1])
	var tx := (float(ahead) + 1.0) * 8.0 - (float(rb.pos.x) + 6.0)
	if int(nx[3]) != 0 and int(nx[1]) == int(cur[1]):
		# cai reto daqui: anda até estar sobre o vão
		return {"move": clampf(dx / 4.0, -1.0, 1.0) if absf(dx) > 1.0 else signf(dx)}
	return {"move": clampf(tx / 4.0, -1.0, 1.0)}


## No fim do caminho: atravessa a saída (anda para o lado dela; a de cima, pula).
func _push_out() -> Dictionary:
	if typeof(target) == TYPE_STRING and not String(target).contains("@"):
		# um item: vai até ele (e pula, se estiver acima)
		var pr: Rect2i = room.pickups[int(String(target).substr(1))]["rect"]
		var d := float(pr.get_center().x) - (float(room.rabbit.pos.x) + 6.0)
		var out := {"move": clampf(d / 4.0, -1.0, 1.0)}
		if pr.end.y < room.rabbit.pos.y:
			jump_hold = 13
			out["jump_pressed"] = true
			out["jump_held"] = true
		return out
	var k := int(String(target).split("@")[0]) if typeof(target) == TYPE_STRING else int(target)
	for ex in room.exits:
		if int(ex["index"]) == k:
			match room.exit_cur_side(ex):
				0:
					jump_hold = 13   # pulo inteiro: segurar o botão
					return {"jump_pressed": true, "jump_held": true}
				1:
					return {"move": 1.0}
				3:
					return {"move": -1.0}
	return {}


func _rot_dir(a: int, b: int) -> int:
	return 1 if posmod(b - a, 4) == 1 else -1


## No ar: o x (em células) de onde o caminho pousa (o próximo estado no chão, no mesmo giro); se o
## caminho gira antes de pousar, o x de onde ele gira.
func _air_target() -> int:
	var o: int = posmod(room.orientation, 4)
	var tgt := _cell().x
	for j in range(i, mini(i + 80, path.size())):
		var s: Array = path[j]
		if int(s[0]) != o:
			break
		tgt = int(s[1])
		if int(s[3]) == 0 and j > i:
			break
	return tgt


func _air_target_from(k: int) -> int:
	var tgt := int(path[k][1])
	for j in range(k, mini(k + 40, path.size())):
		tgt = int(path[j][1])
		if int(path[j][3]) == 0:
			break
	return tgt


func _steer_x(cell_x: int) -> float:
	var d := (float(cell_x) + 1.0) * 8.0 - (float(room.rabbit.pos.x) + 6.0)
	if absf(d) < 2.0:
		return 0.0
	return clampf(d / 6.0, -1.0, 1.0)

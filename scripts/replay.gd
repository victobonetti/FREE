extends RefCounted
## Replay: os comandos de cada quadro de uma partida, para provar que uma fase tem solução.
## O editor grava quando o autor testa a fase (main.gd chama `record`); os testes rodam o
## replay de cada fase da campanha e conferem que o coelho chega à porta.
##
## A simulação é determinística: posições em pixels inteiros, 60 quadros fixos por segundo e
## nenhum sorteio que afete o jogo (o boss tem sorteio próprio com semente fixa). Então os
## mesmos comandos levam ao mesmo resultado.
##
## Formato (JSON): {"version": 1, "hash": <content_hash da fase>, "frames": N,
##   "runs": [[repetições, comando], ...]}. Um comando é o dicionário passado a room.step()
## ({"move", "jump_pressed", "jump_held", "climb", "rotate"}), só com o que não é zero/falso,
## ou {"reset": true} quando o jogador apertou R. Quadros iguais seguidos viram uma entrada.

const RoomScript := preload("res://scripts/room.gd")

const VERSION := 1
const EXTRA_FRAMES := 600   # depois do último comando, quadros parados para a vitória acontecer


## Um comando sem os campos neutros, com números arredondados (o JSON fica pequeno e estável).
static func compact(inp: Dictionary) -> Dictionary:
	var out := {}
	for k in inp:
		var v = inp[k]
		if typeof(v) == TYPE_BOOL:
			if v:
				out[k] = true
		elif typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			var f := snappedf(float(v), 0.01)
			if f != 0.0:
				out[k] = f
	return out


## Grava: acrescenta um quadro à lista (em compactação).
static func record(runs: Array, inp: Dictionary) -> void:
	var c := compact(inp)
	if not runs.is_empty() and runs[-1][1] == c:
		runs[-1][0] += 1
	else:
		runs.append([1, c])


## Grava `n` quadros iguais de uma vez (para quem converte uma rota pronta em replay).
static func record_n(runs: Array, n: int, inp: Dictionary) -> void:
	var c := compact(inp)
	if not runs.is_empty() and runs[-1][1] == c:
		runs[-1][0] += n
	else:
		runs.append([n, c])


## Estado de partida dos atores da fase que vive fora da sala (ex.: o Jeffrey lembra se a
## abertura dele já foi vista). Um ator com esse estado tem as funções estáticas
## `replay_state() -> Dictionary` e `apply_replay_state(d)`.
static func capture_state(def: Dictionary) -> Dictionary:
	var out := {}
	for path in def.get("actors", []):
		var sc: Script = load(path)
		if sc.has_method("replay_state"):
			out[path] = sc.call("replay_state")
	return out


static func _apply_state(state: Dictionary) -> void:
	for path in state:
		var sc: Script = load(path)
		if sc.has_method("apply_replay_state"):
			sc.call("apply_replay_state", state[path])


static func pack(runs: Array, content_hash: String, state := {}) -> Dictionary:
	var n := 0
	for r in runs:
		n += int(r[0])
	var out := {"version": VERSION, "hash": content_hash, "frames": n, "runs": runs.duplicate(true)}
	if not state.is_empty():
		out["state"] = state
	return out


static func is_for(replay: Dictionary, content_hash: String) -> bool:
	return not replay.is_empty() and str(replay.get("hash", "")) == content_hash


## Roda o replay numa sala nova, sem janela. Devolve {"won": bool, "frame": quadro da vitória,
## "end": retrato do fim dos comandos (estado, posição do coelho, corações do boss)}.
static func run(def: Dictionary, replay: Dictionary) -> Dictionary:
	var before := capture_state(def)
	_apply_state(replay.get("state", {}))
	var room: Node2D = RoomScript.new()
	room.setup(def)
	var frame := 0
	var won := false
	for r in replay.get("runs", []):
		var cmd: Dictionary = r[1]
		for i in int(r[0]):
			if cmd.get("reset", false):
				room.reset()
			else:
				room.step(_expand(cmd))
			frame += 1
			if room.state == "won" or room.state == "done":
				won = true
				break
		if won:
			break
	# retrato do fim dos comandos (antes dos quadros parados): os testes comparam com a partida
	var snap := {"state": room.state, "rabbit": room.rabbit.pos, "frame": frame}
	for a in room.actors:
		if "hearts" in a:
			snap["hearts"] = a.hearts
	var extra := 0
	while not won and extra < EXTRA_FRAMES:
		room.step({})
		frame += 1
		extra += 1
		won = room.state == "won" or room.state == "done"
	room.free()
	_apply_state(before)   # devolve o estado do jogo como estava
	return {"won": won, "frame": frame, "end": snap}


static func _expand(cmd: Dictionary) -> Dictionary:
	return {
		"move": float(cmd.get("move", 0.0)),
		"jump_pressed": bool(cmd.get("jump_pressed", false)),
		"jump_held": bool(cmd.get("jump_held", false)),
		"climb": float(cmd.get("climb", 0.0)),
		"rotate": int(cmd.get("rotate", 0)),
	}


static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var v = JSON.parse_string(f.get_as_text())
	f.close()
	return v if typeof(v) == TYPE_DICTIONARY else {}


static func save_file(path: String, replay: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(replay) + "\n")
	f.close()
	return true

extends RefCounted
## Mudanças na campanha (modo história) feitas pelo editor: canonizar uma fase, mudar a ordem,
## tirar da história. Grava em `Levels.campaign_dir` (res://levels/campaign), que só aceita
## escrita rodando do projeto (build de depuração, run.ps1). Para ir ao ar: commit e deploy.
##
## Canonizar exige a prova: a fase verificada (o autor venceu esta versão) e um replay dessa
## mesma versão (mesmo content_hash). O replay vai junto, em <id>.replay.json, e os testes o
## rodam para garantir que a fase continua com solução.

const Levels := preload("res://scripts/levels.gd")
const LevelData := preload("res://scripts/level_data.gd")
const LevelStore := preload("res://scripts/level_store.gd")
const Replay := preload("res://scripts/replay.gd")


static func _save_order(ids: Array) -> bool:
	DirAccess.make_dir_recursive_absolute(Levels.campaign_dir)
	var f := FileAccess.open(Levels.order_path(), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"ordem": ids}, "\t") + "\n")
	f.close()
	Levels.refresh()
	return true


## Um id livre na campanha, a partir do nome.
static func free_id(name: String) -> String:
	var base := LevelStore.slug(name)
	var id := base
	var n := 2
	while FileAccess.file_exists(Levels.level_path(id)):
		id = "%s-%d" % [base, n]
		n += 1
	return id


## Por que esta fase ainda não pode entrar na história ("" = pode).
static func why_not(data: RefCounted, replay: Dictionary) -> String:
	var errs: Array = data.errors()
	if not errs.is_empty():
		return "Corrija: %s" % errs[0]["msg"]
	if not data.is_verified():
		return "Vença a fase (▶ Jogar) antes de canonizar"
	if not Replay.is_for(replay, data.content_hash()):
		return "Falta o replay desta versão: vença a fase de novo (▶ Jogar)"
	return ""


## Canoniza: grava a fase e o replay. Se `id` já está na campanha, substitui no mesmo lugar;
## senão cria um id novo e insere na posição `at` (-1 = no fim).
## Devolve {"id": ...} ou {"erro": ...}.
static func canonize(data: RefCounted, replay: Dictionary, id := "", at := -1) -> Dictionary:
	var why := why_not(data, replay)
	if why != "":
		return {"erro": why}
	var ids: Array = Levels.ids()
	if id == "" or not ids.has(id):
		id = free_id(data.name if data.name != "" else "fase")
		ids.insert(clampi(at, 0, ids.size()) if at >= 0 else ids.size(), id)
	DirAccess.make_dir_recursive_absolute(Levels.campaign_dir)
	var f := FileAccess.open(Levels.level_path(id), FileAccess.WRITE)
	if f == null:
		return {"erro": "Não consegui gravar em %s (só funciona rodando do projeto)" % Levels.campaign_dir}
	f.store_string(data.to_json() + "\n")
	f.close()
	if not Replay.save_file(Levels.replay_path(id), replay):
		return {"erro": "Não consegui gravar o replay"}
	if not _save_order(ids):
		return {"erro": "Não consegui gravar a ordem"}
	return {"id": id}


## Sobe (-1) ou desce (+1) uma fase na ordem.
static func move(id: String, delta: int) -> bool:
	var ids: Array = Levels.ids()
	var i := ids.find(id)
	var j := i + delta
	if i < 0 or j < 0 or j >= ids.size():
		return false
	ids[i] = ids[j]
	ids[j] = id
	return _save_order(ids)


## Tira da história: a fase vira um rascunho em "Minhas fases" e os arquivos saem da campanha.
## Devolve o id do rascunho, ou "".
static func remove(id: String) -> String:
	var ids: Array = Levels.ids()
	if not ids.has(id):
		return ""
	var data: RefCounted = LevelData.from_def(Levels.by_id(id))
	var draft := LevelStore.save(data)
	if draft == "":
		return ""
	ids.erase(id)
	if not _save_order(ids):
		return ""
	DirAccess.remove_absolute(Levels.level_path(id))
	DirAccess.remove_absolute(Levels.replay_path(id))
	Levels.refresh()
	return draft


static func load_replay(id: String) -> Dictionary:
	return Replay.load_file(Levels.replay_path(id))

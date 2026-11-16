extends RefCounted
## Fases do jogador em disco: `user://levels/<id>.json`. Também importa e exporta o código de
## texto de compartilhamento (área de transferência).

const LevelData := preload("res://scripts/level_data.gd")

const DIR := "user://levels"


## Pasta onde as fases são guardadas; os testes trocam por uma pasta temporária.
static var dir_override := ""


static func dir() -> String:
	return dir_override if dir_override != "" else DIR


static func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(dir())


## "Minha fase 1!" -> "minha-fase-1"
static func slug(text: String) -> String:
	var out := ""
	for ch in text.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif out != "" and not out.ends_with("-"):
			out += "-"
	out = out.trim_suffix("-")
	return out if out != "" else "fase"


static func path_of(id: String) -> String:
	return "%s/%s.json" % [dir(), id]


## Um id livre a partir do nome.
static func free_id(text: String) -> String:
	var base := slug(text)
	var id := base
	var n := 2
	while FileAccess.file_exists(path_of(id)):
		id = "%s-%d" % [base, n]
		n += 1
	return id


## Salva e devolve o id. Sem id, cria um novo a partir do nome.
static func save(data: RefCounted, id := "") -> String:
	_ensure_dir()
	if id == "":
		id = free_id(data.name)
	var f := FileAccess.open(path_of(id), FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(data.to_json())
	f.close()
	return id


static func load_level(id: String) -> RefCounted:
	if not FileAccess.file_exists(path_of(id)):
		return null
	var f := FileAccess.open(path_of(id), FileAccess.READ)
	if f == null:
		return null
	var d: RefCounted = LevelData.from_json(f.get_as_text())
	f.close()
	return d


static func delete(id: String) -> bool:
	if not FileAccess.file_exists(path_of(id)):
		return false
	return DirAccess.remove_absolute(path_of(id)) == OK


## Todas as fases salvas, mais recentes primeiro: [{"id", "data", "time"}].
static func list() -> Array:
	var out: Array = []
	_ensure_dir()
	var d := DirAccess.open(dir())
	if d == null:
		return out
	for f in d.get_files():
		if not f.ends_with(".json"):
			continue
		var id := f.trim_suffix(".json")
		var data := load_level(id)
		if data != null:
			out.append({"id": id, "data": data, "time": FileAccess.get_modified_time(path_of(id))})
	out.sort_custom(func(a, b): return a["time"] > b["time"])
	return out


## Importa um código de texto e salva como fase nova. Devolve {"id", "data"} ou {"erro": msg}.
static func import_code(code: String) -> Dictionary:
	var data: RefCounted = LevelData.from_code(code)
	if data == null:
		return {"erro": "Código inválido: tem de começar com %s." % LevelData.CODE_PREFIX}
	var errs: Array = data.errors()
	if not errs.is_empty():
		return {"erro": "A fase tem problemas: %s" % errs[0]["msg"]}
	if data.name == "":
		data.name = "Fase importada"
	var id := save(data)
	return {"id": id, "data": data}


static func export_code_to_clipboard(data: RefCounted) -> String:
	var code: String = data.to_code()
	DisplayServer.clipboard_set(code)
	return code

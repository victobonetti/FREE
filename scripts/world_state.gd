extends RefCounted
## O progresso no mundo (metroidvania, D120): o que o coelho já tem e o que já mudou no mapa. Fica
## salvo em `user://` quando o coelho dorme numa toca (e ao pegar uma habilidade ou um item-chave).
##
## Habilidades (D118): A1 batida de pata (girar), A2 giro no ar, A3 mergulho, A4 puxar caixas,
## A5 meia-volta (180°), A6 pata firme (o amortecedor não desfaz o giro; o cristal quebra), A7 seringa
## (a gosma quebra). Itens (D119): noz (a noz-mestra do Jeffrey), cracha (do Gatsby), lanterna, as
## chaves chave1..chave3, os corações extras e as pistas.

const ABILITIES := ["A1", "A2", "A3", "A4", "A5", "A6", "A7"]
const ABILITY_NAMES := {
	"A1": "Batida de pata", "A2": "Giro no ar", "A3": "Mergulho", "A4": "Puxar caixas",
	"A5": "Meia-volta", "A6": "Pata firme", "A7": "Seringa",
}
const ABILITY_HINTS := {
	"A1": "Q / E giram a sala", "A2": "dá para girar no ar, uma vez por pulo", "A3": "na água, para baixo afunda",
	"A4": "encostado na caixa, para trás puxa", "A5": "Q e E juntos: meia-volta", "A6": "o amortecedor não te segura mais",
	"A7": "a gosma não te segura mais",
}
const ITEM_NAMES := {
	"noz": "Noz-mestra", "cracha": "Crachá do Gatsby", "lanterna": "Lanterna", "chave1": "Chave (verde)",
	"chave2": "Chave (azul)", "chave3": "Chave (roxa)", "coracao": "Coração", "pista": "Pista",
}
## Habilidades de quem joga fora do mundo (campanha, editor): o giro e o giro no ar, como sempre foi.
const CLASSIC := {"A1": true, "A2": true}

static var save_path := "user://free_mundo.json"

var abilities := {}   # "A1" -> true
var items := {}       # "noz" -> 1; "coracao" -> quantos; "pista" -> quantas
var solved := {}      # id da sala -> true (as saídas trancadas abriram)
var opened := {}      # "sala:índice" -> true (barreira aberta: cristal, gosma, raiz, catraca)
var taken := {}       # "sala:índice" -> true (item pego)
var roses := {}       # id da rosa -> giro (0..3) em que ficou
var visited := {}     # id da sala -> true
var bosses := {}      # id da sala do chefe -> true (vencido)
var toca := {}        # {"room": id, "exit": índice} onde o coelho dormiu por último ({}: o início)


func has(key: String) -> bool:
	return abilities.has(key) or int(items.get(key, 0)) > 0


func give(key: String) -> void:
	if ABILITIES.has(key):
		abilities[key] = true
	else:
		items[key] = int(items.get(key, 0)) + 1


func hearts_extra() -> int:
	return int(items.get("coracao", 0))


func to_dict() -> Dictionary:
	return {"version": 1, "abilities": abilities, "items": items, "solved": solved, "opened": opened, "taken": taken,
		"roses": roses, "visited": visited, "bosses": bosses, "toca": toca}


static func from_dict(d: Dictionary) -> RefCounted:
	var s: RefCounted = load("res://scripts/world_state.gd").new()
	s.abilities = d.get("abilities", {})
	s.items = d.get("items", {})
	s.solved = d.get("solved", {})
	s.opened = d.get("opened", {})
	s.taken = d.get("taken", {})
	s.visited = d.get("visited", {})
	s.bosses = d.get("bosses", {})
	s.toca = d.get("toca", {})
	s.roses = {}
	for k in d.get("roses", {}):
		s.roses[k] = int(d["roses"][k])
	return s


func save() -> bool:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(), "\t") + "\n")
	f.close()
	return true


static func has_save() -> bool:
	return FileAccess.file_exists(save_path)


static func load_saved() -> RefCounted:
	if not has_save():
		return null
	var v = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(v) != TYPE_DICTIONARY:
		return null
	return from_dict(v)


static func erase_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path) if save_path.begins_with("user://") else save_path)

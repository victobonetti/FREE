extends RefCounted
## A campanha (modo história). As fases são dados, feitos no editor: um arquivo por fase em
## `res://levels/campaign/<id>.json`, e a ordem em `res://levels/campaign/ordem.json`.
## Aqui ficam só o carregador, a sala de início (presa à cutscene) e a legenda do formato.
## A prova de que cada fase tem solução é um replay gravado no editor (`<id>.replay.json`),
## rodado pelos testes; as fases antigas ainda têm bots em tests/run_tests.gd.
##
## Cada sala é uma grade de tiles de 8 px, de qualquer tamanho
## (todas as linhas com o mesmo comprimento, cercadas de parede).
##
## Legenda:
##   #  parede             .  vazio
##   P  coelho (bloco 2x2)  B  caixa (bloco 2x2)
##   S  compartimento da porta (bloco 2x2)
##   D  porta (retângulo)
##   1..9  comporta: parede que some enquanto os compartimentos dela têm caixa
##   a..i  compartimento de comporta (bloco 2x2): "a" abre a comporta "1", "b" a "2"...
##   ¹²³⁴⁵⁶⁷⁸⁹  comporta inversa, com o mesmo número: abre e fecha ao contrário da comporta comum.
##        Usa o mesmo compartimento: com a caixa lá, a comporta "1" abre e a inversa fecha.
##   = } _ {  barra sólida por orientação, com a seta para cima, direita, baixo, esquerda;
##            só existe quando a seta aponta para cima na tela, e aí bloqueia de todos os lados
##   ↑ → ↓ ←  barra de passagem: igual, mas de mão única (atravessa pulando por baixo ou de
##            lado; só segura quem chega por cima)
##   ^ > v <  espinhos (a ponta aponta para a direção do símbolo)
##   | -  corda: uma sequência reta de "|" (ou de "-") é uma corda esticada; a ponta encostada
##        numa parede é a âncora. Só dá para agarrar a corda que pende do teto.
##   ~  água (o tile começa cheio; ao carregar, a água escorre até assentar)
##   o  ralo: engole aos poucos a água que encosta nele
##
## "start_rot": quantos giros de 90° (horário > 0) aplicar ao desenho ao carregar.
## Permite desenhar a sala na orientação em que ela é resolvida e começar girada.
## Atenção: o que está solto precisa estar apoiado na orientação inicial.
## "rotate": false desliga o giro.
## "limiter": true: o giro é desfeito sozinho quando a recarga (2,5 s) termina.
## "hint" (opcional): só os controles básicos (andar, pular, girar). As mecânicas o jogador descobre.
## "hint_touch" (opcional): a mesma dica para quem joga no celular (aparece no lugar de "hint").
## "door_open" (opcional): true deixa a porta sempre aberta, sem compartimento.
## "spin_block": [coluna, linha, lado]: a sala não gira; Q/E giram só esse bloco quadrado e os
##     espinhos encostados nele, sem pausar o jogo. "spin_cooldown": a recarga desse giro (quadros).
## "actors": scripts que a sala cria e chama a cada quadro (o boss). Um ator pode abrir a porta.
## "music" (opcional): faixa da sala; sem o campo, toca DEFAULT_MUSIC. Se duas salas
## seguidas usam a mesma faixa, ela continua sem reiniciar.
## "notes" (opcional): notas de projeto da fase; o jogo ignora.

const DEFAULT_MUSIC := "res://music/first-levels-theme.mp3"
const LevelData := preload("res://scripts/level_data.gd")

## Pasta da campanha. Os testes trocam por uma pasta temporária.
static var campaign_dir := "res://levels/campaign"

static var _loaded_from := ""
static var _ids: Array = []
static var _defs := {}


static func order_path() -> String:
	return "%s/ordem.json" % campaign_dir


static func level_path(id: String) -> String:
	return "%s/%s.json" % [campaign_dir, id]


static func replay_path(id: String) -> String:
	return "%s/%s.replay.json" % [campaign_dir, id]


## Relê a campanha do disco (o editor chama depois de mudar algo).
static func refresh() -> void:
	_loaded_from = campaign_dir
	_ids = []
	_defs = {}
	var order = _read_json(order_path())
	if typeof(order) != TYPE_DICTIONARY:
		push_error("campanha: não consegui ler %s" % order_path())
		return
	for id in order.get("ordem", []):
		var raw = _read_json(level_path(str(id)))
		if typeof(raw) != TYPE_DICTIONARY:
			push_error("campanha: fase '%s' não encontrada" % id)
			continue
		var def: Dictionary = LevelData.from_def(raw).to_def()
		def["id"] = str(id)
		_ids.append(str(id))
		_defs[str(id)] = def


static func _ensure() -> void:
	if _loaded_from != campaign_dir:
		refresh()


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var v = JSON.parse_string(f.get_as_text())
	f.close()
	return v


## Ids das fases, na ordem da história.
static func ids() -> Array:
	_ensure()
	return _ids.duplicate()


static func count() -> int:
	_ensure()
	return _ids.size()


## As fases, na ordem (dicionários que `room.setup()` consome; cada um tem "id").
static func rooms() -> Array:
	_ensure()
	var out: Array = []
	for id in _ids:
		out.append(_defs[id])
	return out


static func def_at(i: int) -> Dictionary:
	_ensure()
	return _defs[_ids[clampi(i, 0, _ids.size() - 1)]]


static func by_id(id: String) -> Dictionary:
	_ensure()
	return _defs.get(id, {})


static func index_of(id: String) -> int:
	_ensure()
	return _ids.find(id)


const START := {
	"name": "",
	"hint": "Ande com A/D ou as setas",
	"hint_touch": "Ande com o joystick",
	"music": "",
	"door_open": true,
	"rotate": false,
	"start_rot": 0,
	"rows": [
		"##############",
		"#............#",
		"#............#",
		"#............#",
		"#............#",
		"#............#",
		"#............#",
		"#............#",
		"#............#",
		"#.........DD.#",
		"#.........DD.#",
		"#.....PP..DD.#",
		"#.....PP..DD.#",
		"##############",
	],
}

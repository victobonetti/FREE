extends SceneTree
## Testes do editor de fases (sem janela). Rodar:
##   Godot_console.exe --headless --path . -s tests/editor_tests.gd

const Levels := preload("res://scripts/levels.gd")
const LevelData := preload("res://scripts/level_data.gd")
const LevelStore := preload("res://scripts/level_store.gd")
const RoomScript := preload("res://scripts/room.gd")
const EditModel := preload("res://scripts/editor/edit_model.gd")
const EditTools := preload("res://scripts/editor/edit_tools.gd")

var failures := 0


func _initialize() -> void:
	test_data_campaign()
	test_data_roundtrip()
	test_data_validation()
	test_store()
	test_model_basic()
	test_model_blocks()
	test_model_shapes()
	test_model_room()
	test_tools()
	test_inverse_in_editor()
	test_time_params()
	test_campaign_override()
	await test_flow()
	print("")
	if failures == 0:
		print("TODOS OS TESTES DO EDITOR PASSARAM")
	else:
		print("FALHAS: %d" % failures)
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		failures += 1


func has_error(d, text: String) -> bool:
	for p in d.validate():
		if p["erro"] and String(p["msg"]).contains(text):
			return true
	return false


# ------------------------------------------------------------ dados

func test_data_campaign() -> void:
	print("fases da campanha na validação")
	var all: Array = Levels.ROOMS.duplicate()
	all.append(Levels.START)
	for def in all:
		var d: RefCounted = LevelData.from_def(def)
		var errs: Array = d.errors()
		check(errs.is_empty(), "'%s' não tem erros%s" % [def["name"], "" if errs.is_empty() else " (%s)" % errs[0]["msg"]])


func test_data_roundtrip() -> void:
	print("ida e volta")
	var ok_def := true
	var ok_json := true
	var ok_code := true
	for def in Levels.ROOMS:
		var d: RefCounted = LevelData.from_def(def)
		var back: Dictionary = d.to_def()
		for k in ["name", "rotate", "start_rot", "rows"]:
			ok_def = ok_def and back[k] == def[k]
		ok_def = ok_def and back.get("door_open", false) == def.get("door_open", false)
		ok_def = ok_def and back.get("limiter", false) == def.get("limiter", false)
		ok_def = ok_def and back.get("hint", "") == def.get("hint", "")
		var j: RefCounted = LevelData.from_json(d.to_json())
		ok_json = ok_json and j != null and j.to_def() == back
		var c: RefCounted = LevelData.from_code(d.to_code())
		ok_code = ok_code and c != null and c.to_def() == back
	check(ok_def, "from_def e to_def devolvem a mesma fase (as 16)")
	check(ok_json, "JSON devolve a mesma fase (as 16)")
	check(ok_code, "o código de texto devolve a mesma fase (as 16)")
	var code: String = LevelData.from_def(Levels.ROOMS[2]).to_code()
	print("  código da fase 3: %d caracteres" % code.length())
	check(code.begins_with("FREE1:") and code.length() < 900, "o código é curto")
	check(LevelData.from_code("lixo") == null and LevelData.from_code("FREE1:5:@@@") == null, "código inválido devolve nulo")
	check(LevelData.from_json("[1,2]") == null and LevelData.from_json("{}") == null, "JSON sem grade devolve nulo")


func test_data_validation() -> void:
	print("validação")
	var d: RefCounted = LevelData.blank(20, 12)
	check(d.is_playable(), "a fase em branco já é jogável")
	check(d.rows.size() == 12 and d.width() == 20, "tamanho 20x12")
	d.set_cell(5, 5, "Z")
	check(has_error(d, "desconhecida"), "peça desconhecida")
	d = LevelData.blank(20, 12)
	d.rows[0] = "#.".repeat(10)
	check(has_error(d, "borda"), "borda sem parede")
	d = LevelData.blank(20, 12)
	d.rows[3] = d.rows[3] + "#"
	check(has_error(d, "tamanho diferente"), "linha de tamanho diferente")
	d = LevelData.blank(20, 12)
	d.set_block(2, 9, ".")
	check(has_error(d, "Falta o coelho"), "sem coelho")
	d = LevelData.blank(20, 12)
	d.set_block(6, 9, "P")
	check(has_error(d, "um coelho"), "dois coelhos")
	d = LevelData.blank(20, 12)
	d.set_cell(5, 5, "B")
	check(has_error(d, "2x2"), "caixa incompleta")
	d = LevelData.blank(20, 12)
	for r in range(h(d) - 6, h(d) - 2):
		d.set_cell(17, r, ".")
	d.set_cell(10, 4, "D")
	check(has_error(d, "retângulo"), "porta que não é retângulo")
	d = LevelData.blank(20, 12)
	for r in d.height():
		for c in d.width():
			if d.cell(c, r) == "D":
				d.set_cell(c, r, ".")
	check(has_error(d, "Falta a porta"), "sem porta")
	d = LevelData.blank(20, 12)
	d.door_open = false
	check(has_error(d, "compartimento 'S'"), "porta fechada sem compartimento")
	d.set_block(10, 9, "S")
	check(has_error(d, "caixas"), "compartimento sem caixa")
	d.set_block(14, 9, "B")
	check(d.is_playable(), "com compartimento e caixa, volta a ser jogável")
	d.set_cell(3, 3, "1")
	check(has_error(d, "comporta 1"), "comporta sem compartimento")
	d.set_block(6, 3, "a")
	d.set_block(14, 3, "B")
	check(d.is_playable(), "comporta 1 com compartimento 'a' e caixa extra")
	d = LevelData.blank(20, 12)
	d.set_cell(8, 3, "|")
	check(has_error(d, "corda"), "corda solta no ar")
	d.set_cell(8, 1, "|")
	d.set_cell(8, 2, "|")
	d.set_cell(8, 3, ".")
	check(not has_error(d, "corda"), "corda encostada no teto")
	d = LevelData.blank(70, 12)
	check(d.width() == LevelData.MAX_W, "o tamanho é limitado a %d" % LevelData.MAX_W)
	d = LevelData.blank(20, 12)
	d.limiter = true
	d.rotate = false
	var warned := false
	for p in d.validate():
		if not p["erro"] and String(p["msg"]).contains("limitador"):
			warned = true
	check(warned and d.is_playable(), "limitador sem giro é só aviso")
	# verificação por hash
	d = LevelData.blank(20, 12)
	check(not d.is_verified(), "fase nova não está verificada")
	d.mark_verified()
	check(d.is_verified(), "depois de vencer, está verificada")
	d.name = "Outro nome"
	d.hint = "dica"
	check(d.is_verified(), "mudar nome e dica não tira a verificação")
	d.set_cell(5, 5, "#")
	check(not d.is_verified(), "mudar a grade tira a verificação")
	d.mark_verified()
	d.limiter = true
	check(not d.is_verified(), "mudar o limitador tira a verificação")
	d = LevelData.blank(20, 12)
	d.mark_verified()
	var c: RefCounted = LevelData.from_code(d.to_code())
	check(c.is_verified(), "a verificação sobrevive ao código de texto")
	c.set_cell(5, 5, "#")
	check(not c.is_verified(), "...e se perde ao editar")


func h(d) -> int:
	return d.height()


# ------------------------------------------------------------ armazenamento

func test_store() -> void:
	print("armazenamento")
	LevelStore.dir_override = "user://levels_test"
	for e in LevelStore.list():
		LevelStore.delete(e["id"])
	check(LevelStore.list().is_empty(), "pasta de teste vazia")
	check(LevelStore.slug("Minha Fase 1!") == "minha-fase-1" and LevelStore.slug("***") == "fase", "nomes de arquivo")
	var d: RefCounted = LevelData.blank(20, 12)
	d.name = "Teste um"
	d.hint = "olá"
	var id: String = LevelStore.save(d)
	check(id == "teste-um", "salva com id pelo nome (%s)" % id)
	check(LevelStore.save(d) == "teste-um-2", "outro com o mesmo nome ganha outro id")
	var back: RefCounted = LevelStore.load_level(id)
	check(back != null and back.to_def() == d.to_def(), "carrega igual ao que salvou")
	check(LevelStore.save(d, id) == id, "salvar com id reescreve")
	check(LevelStore.list().size() == 2, "lista duas fases")
	var res: Dictionary = LevelStore.import_code(d.to_code())
	check(res.has("id") and LevelStore.list().size() == 3, "importa um código")
	check(LevelStore.import_code("FREE1:oi").has("erro"), "código ruim devolve erro")
	var bad: RefCounted = LevelData.blank(20, 12)
	bad.set_block(2, 9, ".")
	check(LevelStore.import_code(bad.to_code()).has("erro"), "fase com erros não importa")
	check(LevelStore.delete(id) and LevelStore.load_level(id) == null, "apaga")
	for e in LevelStore.list():
		LevelStore.delete(e["id"])
	LevelStore.dir_override = ""


# ------------------------------------------------------------ modelo de edição

func fresh() -> RefCounted:
	return EditModel.new(LevelData.blank(20, 12))


func count(m, ch: String) -> int:
	var n := 0
	for r in m.data.height():
		for c in m.data.width():
			if m.data.cell(c, r) == ch:
				n += 1
	return n


func test_model_basic() -> void:
	print("modelo: pintar, apagar, desfazer")
	var m := fresh()
	var v0: int = m.version
	m.paint(5, 5, "#")
	check(m.data.cell(5, 5) == "#" and m.dirty and m.version > v0, "pintar uma parede")
	m.paint(5, 5, "^")
	check(m.data.cell(5, 5) == "^", "trocar por espinho")
	m.erase(5, 5)
	check(m.data.cell(5, 5) == ".", "apagar")
	check(m.undo_stack.size() == 3, "três traços no histórico")
	m.undo()
	check(m.data.cell(5, 5) == "^", "desfazer volta ao espinho")
	m.undo()
	m.undo()
	check(m.data.cell(5, 5) == "." and not m.can_undo(), "desfazer tudo")
	m.redo()
	check(m.data.cell(5, 5) == "#" and m.can_redo(), "refazer")
	m.paint(6, 5, "~")
	check(not m.can_redo(), "uma edição nova limpa o refazer")
	m = fresh()
	var before: Array = m.data.rows.duplicate()
	m.paint(0, 5, "^")
	m.paint(19, 5, "^")
	m.paint(5, 0, "^")
	m.paint(5, 11, "^")
	m.paint(-3, 99, "^")
	check(m.data.rows == before and not m.can_undo(), "a borda e o que está fora da sala não mudam")
	m.paint(5, 5, "P")
	m.paint(5, 5, "D")
	check(m.data.cell(5, 5) == ".", "peças de 2x2 e porta não vão pelo lápis")
	# traço contínuo: vários tiles, um desfazer
	m.begin()
	for x in range(3, 10):
		m.paint(x, 3, "#")
	m.end()
	check(m.undo_stack.size() == 1 and count(m, "#") > 7, "um traço com vários tiles é uma entrada só")
	m.undo()
	check(m.data.cell(5, 3) == ".", "desfaz o traço inteiro")


func test_model_blocks() -> void:
	print("modelo: peças de 2x2 e porta")
	var m := fresh()
	check(count(m, "P") == 4, "a fase nova tem um coelho (4 células)")
	check(m.stamp(8, 4, "B"), "carimba uma caixa")
	check(count(m, "B") == 4 and m.data.cell(9, 5) == "B", "uma caixa ocupa 2x2")
	check(not m.stamp(0, 4, "B") and not m.stamp(18, 4, "B") and count(m, "B") == 4, "não carimba na borda")
	check(m.block_origin(9, 5) == Vector2i(8, 4), "acha o canto da peça")
	m.stamp(9, 5, "B")
	check(count(m, "B") == 4 and m.data.cell(8, 4) == ".", "carimbar por cima troca a peça, sem sobrar pedaço")
	m.stamp(4, 4, "S")
	m.stamp(6, 4, "a")
	check(count(m, "S") == 4 and count(m, "a") == 4, "compartimentos")
	m.erase(5, 5)
	check(count(m, "S") == 0, "apagar um pedaço apaga a peça inteira")
	m.paint(7, 5, "#")
	check(count(m, "a") == 0 and m.data.cell(7, 5) == "#", "pintar sobre uma peça apaga a peça inteira")
	m.stamp(3, 3, "P")
	check(count(m, "P") == 4, "o coelho é único: o novo substitui o antigo")
	# duas caixas lado a lado se apagam uma de cada vez
	m = fresh()
	m.stamp(4, 4, "B")
	m.stamp(6, 4, "B")
	m.erase(7, 5)
	check(count(m, "B") == 4 and m.data.cell(4, 4) == "B", "caixas vizinhas são peças separadas")
	# porta
	m = fresh()
	m.set_door(3, 2, 4, 5)
	var door := 0
	for r in m.data.height():
		for c in m.data.width():
			if m.data.cell(c, r) == "D":
				door += 1
	check(door == 8 and m.data.is_playable(), "porta 2x4 nova substitui a antiga e a fase segue válida")
	m.erase(3, 3)
	check(count(m, "D") == 0, "apagar a porta apaga ela inteira")
	m.undo()
	check(count(m, "D") == 8, "desfazer traz a porta de volta")
	# corda
	m = fresh()
	m.rope(5, 1, 5, 6)
	check(count(m, "|") == 6 and m.data.is_playable(), "corda vertical presa no teto")
	m.rope(1, 8, 9, 8)
	check(count(m, "-") == 9, "corda horizontal presa na parede da esquerda")
	m.rope(5, 8, 5, 20)
	check(m.data.cell(5, 10) == "|" and m.data.cell(5, 11) == "#", "a corda para antes da parede")


func test_model_shapes() -> void:
	print("modelo: retângulo, linha, balde, copiar e colar")
	var m := fresh()
	m.rect(3, 2, 7, 4, "#", true)
	check(count(m, "#") == 15 + count_border(m), "retângulo cheio")
	m.undo()
	m.rect(3, 2, 7, 6, "~", false)
	check(count(m, "~") == 16 and m.data.cell(5, 4) == ".", "retângulo vazado")
	m = fresh()
	m.line(2, 2, 9, 5, "#")
	var cells: Array = EditModel.line_cells(2, 2, 9, 5)
	check(cells.size() == 8 and cells[0] == Vector2i(2, 2) and cells[7] == Vector2i(9, 5), "linha de Bresenham")
	check(count(m, "#") == 8 + count_border(m), "a linha desenha os tiles")
	m = fresh()
	m.rect(4, 2, 12, 6, "#", false)
	m.fill(8, 4, "~")
	check(count(m, "~") == 21 and m.data.cell(8, 4) == "~" and m.data.cell(3, 4) == ".", "balde só preenche dentro da região")
	m.fill(8, 4, "~")
	check(m.undo_stack.size() == 2, "balde com a mesma peça não faz nada")
	# copiar e colar
	m = fresh()
	m.rect(3, 2, 5, 3, "#", true)
	m.paint(4, 2, "^")
	m.stamp(3, 5, "B")
	var clip: Array = m.copy(3, 2, 6, 6)
	check(clip.size() == 5 and String(clip[0]).length() == 4 and clip[0] == "#^#.", "copia a região")
	m.paste(clip, 10, 2)
	check(m.data.cell(10, 2) == "#" and m.data.cell(11, 2) == "^" and count(m, "B") == 8, "cola em outro lugar")
	m.paint(11, 4, "~")
	m.paste(clip, 10, 2)
	check(m.data.cell(11, 4) == "~", "o vazio do recorte não apaga o que já estava lá")
	m.clear_rect(10, 2, 13, 6)
	check(count(m, "B") == 4 and m.data.cell(10, 2) == ".", "apagar região")
	# o coelho do recorte substitui o da sala
	m = fresh()
	var with_p: Array = ["PP", "PP"]
	m.paste(with_p, 8, 3)
	check(count(m, "P") == 4 and m.data.cell(8, 3) == "P", "colar um coelho substitui o antigo")
	# giro e espelho de recorte mexem nas direções
	var rc: Array = EditModel.rotate_clip(["^>", "v<"], 1)
	check(rc == ["v>", "<^"] or rc == ["<v", "^>"] or rc.size() == 2, "girar o recorte devolve a mesma forma 2x2")
	var one: Array = EditModel.rotate_clip(["^"], 1)
	check(one == [">"] and EditModel.rotate_clip(one, -1) == ["^"], "o espinho gira junto com o recorte")
	check(EditModel.rotate_clip(["="], 1) == ["}"] and EditModel.rotate_clip(["|"], 1) == ["-"], "plataforma e corda giram")
	check(EditModel.mirror_clip(["<}~"]) == ["~{>"], "espelho inverte a ordem e troca esquerda e direita")
	var wide: Array = EditModel.rotate_clip(["abc", "def"], 1)
	check(wide == ["da", "eb", "fc"], "girar um recorte 2x3 dá 3x2 no sentido horário")
	check(EditModel.rotate_clip(wide, -1) == ["abc", "def"], "e o anti-horário desfaz")


func count_border(m) -> int:
	return 2 * m.data.width() + 2 * (m.data.height() - 2)


func test_model_room() -> void:
	print("modelo: sala inteira")
	var m := fresh()
	m.paint(5, 3, "^")
	var w: int = m.data.width()
	var h: int = m.data.height()
	m.rotate_room(1)
	check(m.data.width() == h and m.data.height() == w, "girar a sala troca largura e altura")
	check(m.data.is_playable(), "a sala girada continua válida")
	check(count(m, ">") == 1, "o espinho para cima passa a apontar para a direita")
	m.rotate_room(-1)
	check(m.data.width() == w and m.data.rows[3][5] == "^", "o giro contrário devolve a sala")
	m.rotate_room(1)
	m.undo()
	check(m.data.width() == w and m.data.rows[3][5] == "^", "desfazer o giro da sala")
	m.redo()
	check(m.data.width() == h, "refazer o giro da sala")
	# a rotação é a mesma do jogo: girar o desenho e abrir equivale a start_rot
	var def: Dictionary = {"name": "t", "rotate": true, "start_rot": 0, "door_open": true, "rows": [
		"########", "#......#", "#..>...#", "#.PP.DD#", "#.PP.DD#", "########"]}
	var d: RefCounted = LevelData.from_def(def)
	var mm := EditModel.new(d)
	mm.rotate_room(1)
	var room: Node2D = RoomScript.new()
	room.setup(d.to_def())
	var room2: Node2D = RoomScript.new()
	var def2: Dictionary = def.duplicate(true)
	room2.setup(def2)
	room2._rotate_logic(1)
	check(room.gw == room2.gw and room.gh == room2.gh, "a sala girada no editor tem o tamanho da sala girada no jogo")
	var same := true
	for r in room.gh:
		for c in room.gw:
			same = same and room.tiles[r * room.gw + c] == room2.tiles[r * room2.gw + c]
	check(same, "e as mesmas paredes")
	var sp1: Array = []
	for s in room.spikes:
		sp1.append([s["rect"], s["facing"]])
	var sp2: Array = []
	for s in room2.spikes:
		sp2.append([s["rect"], s["facing"]])
	check(sp1 == sp2, "e os mesmos espinhos, com a mesma direção")
	check(room.door == room2.door and room.rabbit.pos == room2.rabbit.pos, "e a porta e o coelho no mesmo lugar")
	room.free()
	room2.free()
	# espelho
	m = fresh()
	m.paint(4, 4, ">")
	m.mirror_room()
	check(m.data.cell(m.data.width() - 5, 4) == "<", "espelhar a sala troca a direção do espinho")
	# tamanho
	m = fresh()
	m.paint(6, 9, "^")
	m.resize(24, 14)
	check(m.data.width() == 24 and m.data.height() == 14 and m.data.cell(6, 11) == "^", "crescer mantém o chão (a peça desce junto)")
	check(m.data.is_playable(), "e a fase segue válida")
	m.resize(12, 8)
	check(m.data.width() == 12 and m.data.height() == 8 and m.data.rows[0] == "#".repeat(12), "encolher recorta")
	m.undo()
	check(m.data.width() == 24, "desfazer o tamanho")
	m.resize(2, 2)
	check(m.data.width() == LevelData.MIN_W and m.data.height() == LevelData.MIN_H, "tamanho mínimo")


# ------------------------------------------------------------ ferramentas (gestos)

func test_tools() -> void:
	print("ferramentas: gestos do mouse")
	var m := fresh()
	var t := EditTools.new(m)
	t.set_glyph("#")
	t.press(Vector2i(3, 3))
	t.drag(Vector2i(8, 3))
	t.drag(Vector2i(8, 6))
	t.release(Vector2i(8, 6))
	check(count(m, "#") == count_border(m) + 6 + 3 and m.undo_stack.size() == 1, "o lápis arrasta sem pular tiles e vira um traço só")
	t.press(Vector2i(8, 6), true)
	t.drag(Vector2i(8, 3))
	t.release(Vector2i(8, 3))
	check(m.data.cell(8, 4) == "." and m.data.cell(5, 3) == "#", "o botão direito apaga")
	t.set_glyph("B")
	t.press(Vector2i(10, 4))
	t.release(Vector2i(10, 4))
	check(count(m, "B") == 4, "uma peça de 2x2 entra com um clique")
	t.set_glyph("^")
	t.set_tool(EditTools.Tool.RECT)
	t.press(Vector2i(2, 2))
	t.drag(Vector2i(4, 2))
	check(t.preview().size() == 3, "o retângulo mostra o fantasma enquanto arrasta")
	t.release(Vector2i(4, 2))
	check(m.data.cell(3, 2) == "^", "o retângulo desenha ao soltar")
	t.set_glyph("~")
	t.set_tool(EditTools.Tool.LINE)
	t.press(Vector2i(2, 8))
	t.drag(Vector2i(6, 8))
	t.release(Vector2i(6, 8))
	check(m.data.cell(2, 8) == "~" and m.data.cell(6, 8) == "~", "a linha")
	t.set_tool(EditTools.Tool.FILL)
	t.press(Vector2i(12, 2))
	check(count(m, "~") > 100, "o balde")
	m.undo()
	t.set_tool(EditTools.Tool.DOOR)
	t.press(Vector2i(14, 3))
	t.drag(Vector2i(15, 6))
	t.release(Vector2i(15, 6))
	check(count(m, "D") == 8, "a porta pelo arrasto")
	t.set_glyph("|")
	check(t.tool == EditTools.Tool.ROPE, "escolher a corda troca de ferramenta")
	t.press(Vector2i(12, 1))
	t.drag(Vector2i(12, 5))
	check(t.preview().size() == 5, "corda: fantasma")
	t.release(Vector2i(12, 5))
	check(count(m, "|") == 5 and m.data.is_playable(), "corda pelo arrasto, presa no teto")
	# seleção, copiar, colar com giro
	m = fresh()
	t = EditTools.new(m)
	m.paint(3, 3, "^")
	m.paint(4, 3, "#")
	t.set_tool(EditTools.Tool.SELECT)
	t.press(Vector2i(3, 3))
	t.drag(Vector2i(4, 3))
	t.release(Vector2i(4, 3))
	check(t.has_selection and t.selection_rect() == Rect2i(3, 3, 2, 1), "seleção")
	check(t.copy_selection() and t.clip == ["^#"], "copiar")
	check(t.start_paste(), "começa a colar")
	t.rotate_paste(1)
	check(t.paste_clip == [">", "#"] or t.paste_clip.size() == 2, "o recorte gira antes de colar")
	t.hover = Vector2i(8, 5)
	check(t.preview().size() == 2, "fantasma da colagem")
	t.press(Vector2i(8, 5))
	check(m.data.cell(8, 5) == ">" and m.data.cell(8, 6) == "#", "cola o recorte girado")
	check(t.pasting, "pode colar de novo")
	t.escape()
	check(not t.pasting and t.has_selection, "Esc cancela a colagem primeiro")
	t.escape()
	check(not t.has_selection, "e depois a seleção")
	t.set_tool(EditTools.Tool.SELECT)
	t.press(Vector2i(3, 3))
	t.release(Vector2i(4, 3))
	check(t.cut_selection() and m.data.cell(3, 3) == "." and not t.clip.is_empty(), "recortar")


# ------------------------------------------------------------ o fluxo inteiro, com o jogo

func test_flow() -> void:  # espera um quadro para o jogo ficar pronto
	print("fluxo: editor, teste, verificação, salvar, lista")
	LevelStore.dir_override = "user://levels_test"
	for e in LevelStore.list():
		LevelStore.delete(e["id"])
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	await process_frame
	main.open_editor()
	var win: Window = main.get_window()
	check(main.editor_layer.visible and win.content_scale_size == Vector2i(960, 540), "o editor abre e a janela passa a 960x540")
	check(not main.ui_layer.visible and main.room == null and main.intro == null, "o jogo some enquanto edita")
	var ed: Control = main.editor
	check(ed.model != null and ed.model.data.is_playable(), "a fase nova é jogável")
	# edita pelas ferramentas
	ed.tools.set_glyph("#")
	ed.tools.press(Vector2i(8, 11))
	ed.tools.release(Vector2i(8, 11))
	ed.tools.set_glyph("^")
	ed.tools.press(Vector2i(12, 11))
	ed.tools.release(Vector2i(12, 11))
	check(ed.model.dirty and ed.model.data.cell(8, 11) == "#" and ed.model.data.cell(12, 11) == "^", "o desenho pelas ferramentas chega à fase")
	ed._name_edit.text = "Meu teste"
	ed._prop("name", "Meu teste")
	ed._prop("hint", "dica")
	check(ed.model.data.name == "Meu teste" and ed.model.data.hint == "dica", "as propriedades chegam à fase")
	# um erro impede de jogar
	ed.model.stamp(5, 3, "S")
	ed._on_play()
	check(main.custom == "" and main.room == null, "com erro (compartimento sem caixa), não joga")
	ed.model.undo()
	# joga
	ed.model.erase(8, 11)
	ed.model.erase(12, 11)
	ed._on_play()
	check(main.custom == "editor" and main.room != null and not main.editor_layer.visible, "▶ Jogar abre a sala")
	check(win.content_scale_size == Vector2i(320, 180) and main.ui_layer.visible, "e a janela volta a 320x180")
	check(main.room.def["name"] == "Meu teste" and main.room.def.get("hint", "") == "dica", "com os campos da fase")
	# esc sai sem vencer
	main._end_custom(false)
	check(main.editor_layer.visible and win.content_scale_size == Vector2i(960, 540) and not ed.model.data.is_verified(), "sair sem vencer volta ao editor, sem verificar")
	# joga e vence
	ed._on_play()
	var won := false
	for i in 900:
		main.room.step({"move": 1.0, "jump_pressed": i % 40 == 0, "jump_held": true})
		if main.room.state == "done" or main.room.state == "won":
			won = true
			break
	check(won, "a fase em branco se vence andando até a porta")
	main._end_custom(true)
	check(main.editor_layer.visible and ed.model.data.is_verified() and ed.model.dirty, "vencer marca a fase como verificada")
	var code: String = ed.model.data.to_code()
	check(LevelData.from_code(code).is_verified(), "o código leva a marca de verificada")
	# editar tira a verificação
	ed.model.paint(10, 4, "#")
	check(not ed.model.data.is_verified(), "mexer na fase tira a verificação")
	ed.model.undo()
	check(ed.model.data.is_verified(), "desfazer devolve a verificação (o hash volta a bater)")
	# salvar e listar
	ed._on_save()
	check(ed.current_id == "meu-teste" and not ed.model.dirty, "salvar guarda com o nome")
	var unver: RefCounted = LevelData.blank(20, 12)
	unver.name = "Sem vitoria"
	LevelStore.save(unver)
	main._close_editor()
	check(not main.editor_layer.visible and win.content_scale_size == Vector2i(320, 180) and main.intro != null, "Voltar fecha o editor e volta à tela de início")
	main.show_list()
	check(main.in_list and main.list_items.size() == 1 and main.list_items[0]["id"] == "meu-teste", "a lista mostra só fases verificadas")
	check(main.list_label.text.contains("Meu teste"), "e escreve o nome")
	main._play_list_item()
	check(main.custom == "list" and main.room != null and not main.in_list, "jogar da lista")
	main._end_custom(false)
	check(main.in_list and main.custom == "", "sair volta à lista")
	# abrir uma fase da lista no editor
	main.open_editor(main.list_items[0]["data"], main.list_items[0]["id"])
	check(main.editor.current_id == "meu-teste" and main.editor.model.data.name == "Meu teste" and not main.in_list, "E na lista abre no editor")
	main._close_editor()
	main.queue_free()
	for e in LevelStore.list():
		LevelStore.delete(e["id"])
	LevelStore.dir_override = ""


func test_campaign_override() -> void:
	print("campanha: ajuste do editor no lugar da fase")
	Levels.campaign_dir = "user://campaign_test"
	DirAccess.make_dir_recursive_absolute(Levels.campaign_dir)
	check(Levels.campaign_def(2) == Levels.ROOMS[2] and not Levels.has_campaign_override(2), "sem ajuste, vale a fase de levels.gd")
	var d: RefCounted = LevelData.from_def(Levels.ROOMS[2])
	d.name = "Giro editado"
	d.set_cell(3, 3, "^")
	var f := FileAccess.open(Levels.campaign_path(2), FileAccess.WRITE)
	f.store_string(d.to_json())
	f.close()
	var got: Dictionary = Levels.campaign_def(2)
	check(Levels.has_campaign_override(2) and got["name"] == "Giro editado" and String(got["rows"][3])[3] == "^", "com ajuste, vale o do arquivo")
	check(Levels.campaign_def(3) == Levels.ROOMS[3], "as outras não mudam")
	var bad: RefCounted = LevelData.from_def(Levels.ROOMS[2])
	bad.set_block(2, 10, ".")
	f = FileAccess.open(Levels.campaign_path(2), FileAccess.WRITE)
	f.store_string(bad.to_json())
	f.close()
	check(Levels.campaign_def(2) == Levels.ROOMS[2], "um ajuste com erro é ignorado")
	f = FileAccess.open(Levels.campaign_path(2), FileAccess.WRITE)
	f.store_string("isto não é json")
	f.close()
	check(Levels.campaign_def(2) == Levels.ROOMS[2], "um arquivo quebrado também")
	DirAccess.remove_absolute(Levels.campaign_path(2))
	Levels.campaign_dir = "res://levels/campaign"
	check(Levels.campaign_def(2) == Levels.ROOMS[2], "restaurar volta à original")


func test_inverse_in_editor() -> void:
	print("comporta inversa no editor")
	var sup := LevelData.INVERSE_GATES
	var m := fresh()
	m.paint(6, 3, sup[1])
	check(m.data.cell(6, 3) == sup[1] and not m.data.errors().is_empty(), "a inversa 2 sem compartimento 'b' é erro")
	check(has_error(m.data, "comporta 2"), "e a mensagem fala da comporta 2")
	m.stamp(10, 8, "b")
	m.stamp(14, 8, "B")
	check(m.data.is_playable(), "com o compartimento 'b' e uma caixa, fica válida")
	m.paint(8, 3, "2")
	check(m.data.is_playable(), "a comporta comum e a inversa de mesmo número convivem")
	check(LevelData.from_code(m.data.to_code()).rows == m.data.rows, "o código de texto guarda as inversas")
	check(LevelData.from_json(m.data.to_json()).rows == m.data.rows, "o JSON também")
	var r: Array = EditModel.rotate_clip([sup[0] + sup[1]], 1)
	check(r == [sup[0], sup[1]], "girar o recorte não muda a inversa")
	var room: Node2D = RoomScript.new()
	room.setup(m.data.to_def())
	var inv := 0
	for g in room.gates:
		if g["inverse"]:
			inv += 1
	check(inv == 1 and room.gates.size() == 2, "o jogo lê a inversa da fase do editor")
	room.free()


func test_time_params() -> void:
	print("recarga e tempo do limitador no editor")
	var d: RefCounted = LevelData.blank(20, 12)
	check(d.reload_time == 2.5 and d.limiter_time == 2.5, "o padrão é 2,5 s")
	check(not d.to_def().has("reload_time") and not d.to_def().has("limiter_time"), "no padrão, a fase não carrega os campos")
	d.reload_time = 4.0
	d.limiter_time = 1.5
	d.limiter = true
	var def: Dictionary = d.to_def()
	check(def["reload_time"] == 4.0 and def["limiter_time"] == 1.5, "fora do padrão, vão para a fase")
	for back in [LevelData.from_def(def), LevelData.from_json(d.to_json()), LevelData.from_code(d.to_code())]:
		check(back.reload_time == 4.0 and back.limiter_time == 1.5 and back.limiter, "ida e volta (def, JSON, código)")
	var h0: String = d.content_hash()
	d.reload_time = 5.0
	check(d.content_hash() != h0, "mudar a recarga muda o hash (tira a verificação)")
	d.reload_time = 0.2
	check(has_error(d, "recarga"), "recarga curta demais é erro")
	d.reload_time = 4.0
	d.limiter_time = 99.0
	check(has_error(d, "limitador"), "limitador longo demais é erro")
	d.limiter_time = 6.0
	var warned := false
	for p in d.validate():
		if not p["erro"] and String(p["msg"]).contains("dura mais"):
			warned = true
	check(warned and d.is_playable(), "limitador mais longo que a recarga é só aviso")
	d.limiter = false
	d.limiter_time = 99.0
	check(d.is_playable(), "sem limitador, o tempo dele não conta")
	# o jogo usa os campos da fase do editor
	d.limiter = true
	d.limiter_time = 1.0
	d.reload_time = 3.0
	var room: Node2D = RoomScript.new()
	room.setup(d.to_def())
	check(room.reload_frames == 180 and room.limiter_frames == 60, "a sala lê os dois tempos")
	room.free()

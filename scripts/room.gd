extends Node2D
## Uma sala: grade de tiles, coelho, caixas, compartimentos, porta, espinhos, comportas,
## plataformas por orientação, cordas, água e ralos. A sala pode ter qualquer tamanho; a câmera segue o coelho.
##
## Rotação: a simulação sempre acontece com a gravidade para baixo. Ao girar, todos os
## dados da sala (tiles, caixas, coelho, câmera...) são rotacionados 90° de verdade, e só o
## desenho faz a animação (de -90° até 0°). Assim a física nunca precisa saber de orientação.

signal completed
signal exited(side: int, vel: Vector2)   # modo mundo: o coelho saiu por uma saída (lado como desenhado: 0 N, 1 L, 2 S, 3 O)
## "jump" | "death" | "win" | "sensor_on" | "sensor_off" | "gate_open" | "gate_close" | "platform"
## | "rope" (agarrou a corda) | "splash" (caiu na água)
signal sfx(name: String)
signal music_request(path: String)   # um ator pede outra faixa (o boss, ao entrar)
signal impact(strength: float)  # pouso de caixa; 0 a 2,5 (mais altura e mais caixas = mais forte)

const TILE := 8
const VIEW := Vector2(320, 180)  # tamanho da tela (resolução interna)
const CAM_SMOOTH := 0.12
const LOOK_RETURN := 0.08   # fração do olhar que volta para o coelho a cada quadro, ao soltar
const ROT_FRAMES := 16       # duração da animação do giro
const SPIN_FRAMES := 9       # giro do bloco (sala de boss): mais curto que o da sala, sem pausar
const FLIP_FRAMES := 24      # cambalhota do coelho ao girar (passa um pouco do giro, já caindo)
const C_FLIP := Color("8fd0ff")       # faíscas azuis do giro
const C_PASS := Color("9fe6c1")       # barra de passagem (verde-água: diferente da sólida)
# Subsoil (ato 1): o subsolo embaixo do campo, em quatro trechos. Só aparência (D82).
const SUBSOIL := ["raizes", "caverna", "aquifero", "despensa"]
const C_SOIL := {
	"raizes": [Color("3a291f"), Color("43301f"), Color("4e3826")],
	"caverna": [Color("2a2c37"), Color("30323d"), Color("383b47")],
	"aquifero": [Color("223038"), Color("283841"), Color("2f424b")],
	"despensa": [Color("37281d"), Color("402e21"), Color("4a3726")],
}
const C_MOSS := {"raizes": Color("6f9e4a"), "caverna": Color("56784a"), "aquifero": Color("3f7a62"), "despensa": Color("7a8a3e")}
const C_ROOT := Color("6b4a33")
const C_DRIP := Color("9fd4ff")
const C_SHROOM := [Color("c58cff"), Color("7fe0d0")]
const C_CRYSTAL := Color("7fd6e8")
const C_NUT_DECOR := Color("9a6a3a")
const C_ANCHOR := Color("ff3b4e")      # o amortecedor das salas com limitador (a barra vermelha)
# Profundidade (D84): a luz vem do alto à esquerda da tela; paredes e objetos projetam sombra no
# fundo, o miolo das paredes é mais escuro, e o fundo anda mais devagar que a sala (paralaxe).
const SHADOW_OFF := Vector2(4, 5)
const C_SHADOW := Color(0, 0, 0, 0.42)
const PARALLAX := 0.2          # o fundo pintado na sala anda um pouco mais devagar que ela
const FAR_K := [0.18, 0.32]    # o mundo lá fora (duas profundidades): anda bem mais devagar e não gira
const ROT_COOLDOWN := 134    # recarga padrão do bloco que gira (Jeffrey): com a animação, 2,5 s
const DEFAULT_RELOAD := 0.4   # s: recarga do giro do coelho, se a fase não disser outro (D92)
const DEFAULT_LIMITER := 2.5  # s: tempo até o limitador desfazer, contado do primeiro giro
const ROT_BUFFER := 6        # apertar até 6 quadros antes do fim da recarga ainda vale
const DT := 1.0 / 60.0
const BOX_GRAVITY := 900.0
const BOX_MAX_FALL := 160.0
const IMPACT_MIN_DIST := 8     # queda mínima (px) para o pouso virar efeito
const IMPACT_FULL_DIST := 128  # queda (px) que dá força 1 a uma caixa sozinha
const IMPACT_MAX := 2.5
const IMPACT_CHAIN := 0.6      # quanto da força recente soma ao próximo pouso (várias caixas)
const SENSOR_FRAMES := 16
const SWITCH_FRAMES := 12      # efeito de comporta/plataforma mudando de estado
const WIN_FRAMES := 44
const DEATH_FRAMES := 20
const INVERSE_GATES := "¹²³⁴⁵⁶⁷⁸⁹"   # comporta inversa: fecha quando a comporta de mesmo número abre
const GATE_SOCKETS := "abcdefghi"  # compartimento "a" abre a comporta "1", e assim por diante
const PLATFORM_CHARS := "=}_{"     # barra sólida (bloqueia de todos os lados): seta para cima, direita, baixo, esquerda
const PASS_CHARS := "↑→↓←"         # barra de passagem (mão única: atravessa por baixo, pousa por cima), D93
# Saídas na parede de fora (modo mundo, D100): X livre, Z trancada (abre como a porta: caixa no
# compartimento, sem água). Uma por lado; levam à sala vizinha desse lado no mapa do mundo.
const EXIT_FREE := "X"
const EXIT_LOCKED := "Z"
const EXIT_DEPTH := 48             # quanto o coelho pode sair da sala pela abertura (px)
const WATER_REACH := [1, 2, 4, 8, 16, 32, 64, 128]  # distâncias (px) em que duas colunas trocam água
const WATER_NU := 0.5          # parcela do desnível que colunas vizinhas igualam por subpasso
const WATER_NU_FAR := 0.3      # idem para as trocas a distância: dá a velocidade com que a água corre
const WATER_SUBSTEPS := 3
const RIPPLE_TENSION := 0.03   # ondas da superfície: mola que puxa de volta ao nível
const RIPPLE_SPREAD := 0.22    # quanto uma coluna puxa as vizinhas
const RIPPLE_DAMP := 0.955
const RIPPLE_MAX := 5.0        # amplitude máxima (px)
const WATER_FALL_G := 900.0    # queda de um bloco de água solto no ar depois do giro
const WATER_MAX_FALL := 260.0
const WATER_CALM_Q := 0.004    # troca (px por subpasso) abaixo da qual a água conta como parada
const WATER_CALM_FRAMES := 20
const WATER_FILM := 0.4        # lâmina mais fina que isto (px) seca sozinha quando a água está quase parada
const WATER_SETTLE := 1500     # máximo de quadros para assentar a água ao carregar a sala
const DRAIN_RATE := 2.5        # px de altura por quadro que o ralo engole em cada coluna dele (D95: 2,5x)
const ROPE_SEG := 4.0          # distância entre os pontos da corda (px)
const ROPE_ITERS := 10         # iterações das restrições de distância por quadro
const ROPE_AIR := 0.985        # perda de velocidade dos pontos por quadro
const DOOR_FLOOD := 0.3        # fração da porta coberta de água que a bloqueia
const DOOR_DRY_FRAMES := 30    # a porta só destrava depois de ficar seca por este tempo
const BOX_WET := 0.25          # fração submersa a partir da qual a caixa afunda devagar
const BOX_WATER_GRAVITY := 300.0
const BOX_WATER_FALL := 45.0

const CRUSH_SPIKE := 6          # altura dos dentes da placa de espinhos (px)
const CRUSH_CATCHUP := 5.0      # com "leash": vezes a velocidade enquanto o coelho está longe demais
const CRUSH_FACE_MIN := 44      # avanço (px) a partir do qual a carinha pichada cabe na placa
const MOVER_WARN := 16          # quadros de aviso (encaixes piscando) antes de um canal mudar
const CRUMBLE_FRAMES := 26      # quadros entre pisar numa chapa solta e ela desabar
const DANGER_FAR := 150.0       # px: a esta distância da placa o perigo é 0
const DANGER_NEAR := 30.0       # px: a esta distância o perigo é 1
const CRUSH_BEAM := 6           # viga da frente, onde os dentes estão presos (px)

const Rabbit := preload("res://scripts/rabbit.gd")
const Box := preload("res://scripts/box.gd")

const C_BG := Color("0c0c12")
const C_WALL := Color("181821")
const C_EDGE := Color("e2ddcf")
const C_BOX := Color("2aa6ee")
const C_BOX_DARK := Color("1b78b3")
const C_BOX_MID := Color("1f8fd0")
const C_SOCKET := Color("34343d")
const C_SOCKET_FRAME := Color("85858f")
const C_SOCKET_ON := Color("d8c25c")
const C_DOOR_LOCKED := Color("5d76a6")
const C_DOOR_LOCKED_DARK := Color("46597d")
const C_DOOR_OPEN := Color("f3cf3b")
const C_DOOR_INNER := Color("2a2209")
const C_SPIKE := Color("e0657c")
const C_DUST := Color("bdb8ab")
const C_GATE := Color("6fd3b8")
const C_GATE_DARK := Color("1d3a35")
const C_IGATE := Color("f0a05a")
const C_IGATE_DARK := Color("3d2a16")
const C_PLAT := Color("b9a3f0")
const C_PLAT_DARK := Color("3a3158")
const C_ROPE := Color("e39a4c")
const C_WATER := Color("2f86e0")
const C_WATER_TOP := Color("9fd4ff")
const C_ACID := Color("5fd63a")
const C_ACID_TOP := Color("d8ff7a")
const C_BAT := Color("f0b428")
const C_KNOB_LEVER := Color("e0657c")
const C_BAT_DARK := Color("8a5a12")
const BAT_PICK := 2             # folga (px) em volta da bateria para o coelho pegá-la
const LEVER_PAN := 34           # quadros da câmera indo até a alavanca
const LEVER_HIT := 20           # quadro (depois do PAN) em que a alavanca vira
const LEVER_PULL := 40          # duração do gesto da alavanca
const LEVER_WATCH := 52         # quadros da câmera acompanhando a caixa saindo da calha
const ACID_TOUCH := 0.5         # fração do coelho dentro do ácido a partir da qual ele morre: metade do
                                 # corpo. Cair dentro mata; encostar o pé, um respingo ou o giro, não.
const C_DRAIN := Color("8d8d99")
# Engenhocas do Gatsby (ato 2): aço em chapas remendadas, rebites, ferrugem e tinta de pichação.
const C_STEEL := [Color("2b2d35"), Color("31343d"), Color("26282f")]
const C_STEEL_LIGHT := Color("454852")
const C_SEAM := Color("0e0f13")
const C_RIVET := Color("7b7f8a")
const C_RUST := Color("5a4034")
const C_PAINT := Color("e9e4d6")
# Canais dos blocos motorizados: a tinta da peça e do encaixe dela (cor = quem a aciona).
const C_CHANNEL := [Color("8fd16a"), Color("e07ac8"), Color("4fd8d0"), Color("f0a05a"),
		Color("d4bf45"), Color("7aa0ff"), Color("f4c8e8"), Color("6fe0a0")]

# --- Sprite do coelho (12x16, virado para a direita), montado por partes ---
# w branco | g sombra | p rosa | r olho
const EARS := {
	"up": [
		"......w..w..",
		".....ww.ww..",
		".....wp.wp..",
		".....wp.wp..",
		".....wp.wp..",
		".....wp.wp..",
		".....ww.ww..",
	],
	"back": [
		"............",
		"..ww..ww....",
		"..wpw.wpw...",
		"...wpw.wpw..",
		"....wpwwpw..",
		".....wwwww..",
		".....ww.ww..",
	],
	"fall": [
		"....w....w..",
		"....ww..ww..",
		"....wp..pw..",
		".....wp.pw..",
		".....wp.pw..",
		".....wp.wp..",
		".....ww.ww..",
	],
	"twitch": [
		"......w.....",
		".....ww.....",
		".....wp..ww.",
		".....wp.wpw.",
		".....wp.wp..",
		".....wp.wp..",
		".....ww.ww..",
	],
}
const BODY := [
	".....wwwwww.",
	"....wwwwwrw.",
	"....wwwwwwwp",
	".....wwwwww.",
	"...wwwwww...",
	"wwwwwwwww...",
	".wwwwwwww...",
	"..wwwwwwg...",
]
const FEET := {
	"stand": "..ww..www...",
	"run_a": ".ww.....www.",
	"run_b": "...wwwww....",
	"air": ".ww..ww.....",
	"push_a": "..ww....www.",
	"push_b": "...www.ww...",
}

var def: Dictionary = {}
var allow_rotate := true

# tamanho atual da sala (troca de largura e altura a cada giro)
var gw := 20  # em tiles
var gh := 20
var pw := 160  # em pixels
var ph := 160

var tiles := PackedByteArray()
var boxes: Array = []
var sockets: Array = []        # Rect2i
var socket_group: Array = []   # 0 = porta de saída; 1..9 = comporta
var socket_filled: Array = []
var socket_fx: Array = []      # quadros restantes do efeito de sensor, por compartimento
var door := Rect2i()
var has_door := false
var door_open := false
var door_flash := 0
var spikes: Array = []
var gates: Array = []      # {"id", "inverse", "rects": Array[Rect2i], "closed", "anim", "fx"}
var platforms: Array = []  # {"rect": Rect2i, "facing", "solid", "fx"}
# cordas: {"anchor": Vector2, "facing", "len", "pts", "old"}. facing 2 = presa no teto (ativa).
# pts/old são os pontos da corda (Verlet): a forma dela é simulada, cai e balança de verdade.
var ropes: Array = []
var drains: Array = []     # {"rect": Rect2i, "t", "spin"}
# Placas de espinhos (campo "crushers"): avançam por uma faixa da sala, matam e destroem o que
# alcançam. {"lane": Rect2i, "dir", "adv", "speed", "wait", "leash", "face", "fx"}
var crushers: Array = []
# Blocos motorizados (campo "movers"): peças de aço pintadas que correm entre dois encaixes quando
# o canal delas muda de estado (um ator chama mover_toggle). Sólidas; carregam e empurram.
# {"off": Rect2i, "on": Rect2i, "r": Rect2i (atual), "pf": Vector2, "ch", "speed", "spikes", "fx"}
var movers: Array = []
var mover_state := {}    # canal -> true (peças em "on")
# Peças dinâmicas de plataforma (campos de sala; cada uma é uma lista de objetos, veja _init_dynamics):
#   "conveyors" esteira sobre uma fileira de parede; carrega o coelho e as caixas em cima dela
#   "springs"   mola: lança quem toca
#   "fans"      ventilador: corrente de ar numa área (força no coelho e, para cima, nas caixas)
#   "vents"     jato de vapor: perigo periódico, com aviso
var conveyors: Array = []
var springs: Array = []
var fans: Array = []
var vents: Array = []
var belt_acc := {}       # corpo -> resto fracionário do carregamento da esteira
var fan_gain := 0.0      # 0 a 1: o quanto há ventilador perto do coelho (som)
var belt_gain := 0.0     # idem para esteiras
var _base := Transform2D()
var _bg_shift := Vector2.ZERO  # deslocamento do fundo (paralaxe), em px da fase como foi desenhada
var _bw := 0.0                 # largura e altura da fase como foi desenhada (o fundo é pintado nela)
var _bh := 0.0
var _world_off := Vector2.ZERO # quanto a câmera andou, na tela, desde o início (o mundo lá fora rola com isto)
var _prev_cam := Vector2.ZERO
var _bg_cam := Vector2.ZERO    # a câmera, em px da fase como foi desenhada
var sway_frame := -1000        # quadro em que as coisas penduradas começam a balançar (depois de um giro)
var sway_dir := 0              # sentido do último giro
var _fx_live := false          # falso durante o reset (o giro de start_rot não solta poeira)
var _metal_cells: Array = []   # tiles de aço na tela (para os enfeites da fábrica)
const STEP_PX := 11.0          # um passo a cada tantos px andados no chão
var bubbles: Array = []        # bolhas subindo no líquido (só desenho): {"k": vão, "y", "r", "vy", "ph"}
var _step_idx := 0
var query_up := false          # o coelho está testando um passo para cima (a barra de passagem deixa passar)
var query_rabbit := false      # a consulta de colisão é do coelho (só ele passa pelas saídas)
var exits: Array = []          # {"side": lado como desenhado, "rect": Rect2i (as células da abertura), "locked", "flooded"}
var exits_unlocked := false    # as saídas trancadas já abriram (ou a sala já foi resolvida antes: "_solved")
var _vignette: Texture2D       # escurecimento nas bordas da tela (gerado uma vez)
var cycle_t := 0         # quadros de simulação desde o início: os conectores em ciclo seguem este relógio
var plate_on := {}       # canal -> true enquanto um botão de pressão dele está apertado
# Botões de pressão (campo "plates": {"rect": [coluna, linha, largura] em tiles, "ch": canal, "mode":
# "hold" (padrão: ligado enquanto apertado), "once" (liga e fica) ou "timed" (cada pisada liga por
# "time" segundos, contados depois de soltar; depois desliga e pode ser chamado de novo)}. O coelho ou
# uma caixa em cima aperta. Servem a conectores do mesmo canal.
var plates: Array = []
var mover_pending: Array = []   # trocas de canal avisadas e ainda não feitas: [canal, quadros]
# Chapas soltas (campo "crumbles"): chão que desaba pouco depois de o coelho pisar. Não voltam
# (só ao reiniciar a sala). {"rect": Rect2i, "t" (-1 parada; senão quadros desde o pisão)}
var crumbles: Array = []
var danger := 0.0        # 0 a 1: o quanto a placa de espinhos mais próxima está perto do coelho
var danger_dir := -1     # de que lado da tela ela vem (o "dir" dela), ou -1
var crunch_cd := 0       # intervalo mínimo entre dois sons de mastigada
# Água: modelo de colunas. Cada coluna de 1 px tem "vãos" (trechos verticais livres entre
# sólidos); cada vão guarda uma altura de água (fracionária) apoiada no fundo dele. Vãos
# ligados trocam água até igualar o nível; por cima disso, a superfície tem ondas.
var wt_x := PackedInt32Array()      # coluna do vão
var wt_top := PackedInt32Array()    # primeira linha livre
var wt_bot := PackedInt32Array()    # primeira linha sólida abaixo
var wt_h := PackedFloat64Array()    # altura de água
var wt_air := PackedFloat64Array()  # distância do fundo (> 0: bloco de água ainda caindo)
var wt_vy := PackedFloat64Array()
var wt_o := PackedFloat64Array()    # onda: deslocamento da superfície (px, + para baixo)
var wt_v := PackedFloat64Array()    # onda: velocidade
var wcol := PackedInt32Array()      # índice do primeiro vão de cada coluna (pw + 1 entradas)
# ligações: o vão a troca água com o vão b, à direita. As primeiras we_near são entre colunas
# vizinhas; as demais, a distância (só existem se há passagem livre entre as duas).
var we_a := PackedInt32Array()
var we_b := PackedInt32Array()
var we_sill := PackedInt32Array()   # soleira: o fundo mais alto no caminho
var we_nu := PackedFloat64Array()
var we_fall := PackedFloat64Array() # cascata visível nesta ligação (só desenho)
var we_near := 0
var ripples := false       # há ondas na superfície
# Ácido (glifo "%"): o mesmo fluido da água (escorre, nivela, gira com a sala), em verde, e mata o
# coelho ao toque. A sala tem um tipo de fluido só: se há "%" em qualquer lugar, todo o fluido é ácido
# (o validador do editor recusa misturar "~" e "%").
var fluid_acid := false
# Baterias, alavanca e calha (glifos "+", "L" e "H"; 1 a MAX_BATTERIES baterias): com todas as
# baterias coletadas a alavanca se puxa sozinha e a calha solta uma caixa, que abre a porta.
# {"rect": Rect2i, "taken": bool, "fx": quadros do brilho do pegar}
var batteries: Array = []
var bat_got := 0
var lever = null     # {"rect": Rect2i, "t": -1 parada; senão quadros desde o disparo, "pulled": bool}
var chute = null     # {"rect": Rect2i, "open": quadros desde que abriu (0 = fechada)}
var theme := ""      # "", "industrial", "transicao" ou um trecho do subsolo (SUBSOIL): só muda o desenho
var soil := ""       # a paleta de terra em uso ("" sem terra; na transição, a da despensa)
# Amortecedores: nas salas com limitador, a peça que puxa a sala de volta (cristal vermelho no
# subsolo, estabilizador na fábrica). Só desenho; giram com a sala. {"rect": Rect2i, "facing": 0..3}
var anchors: Array = []
var anchor_fx := 0           # quadros do pulso quando o limitador desfaz o giro
# Despertar do giro (campo "awaken", fase 3): o coelho, encurralado, bate a pata pela primeira vez.
static var awakened := false
var awaken_t := -1           # quadros desde o início da sala (-1: não há despertar aqui)
var awaken_flash := 0
var water_vol := 0.0       # volume total (px²)
var water_calm := false    # parada: a simulação descansa
var water_dirty := true    # os vãos precisam ser refeitos (comporta ou plataforma mudou)
var water_still := 0       # quadros seguidos quase sem vazão
var door_flooded := false   # bloqueada pela água (inclui o tempo de secar)
var door_dry := 0           # quadros seguidos com menos de DOOR_FLOOD de água na porta
var rabbit
# Para atores (o Gatsby): giro pedido por um ator, entrada travada e câmera presa numa cena.
var actor_rot := 0
var input_lock := false
var cam_focus = null     # Vector2 (px da sala) ou null

var state := "play"  # play | dead | won | done
var timer := 0
var frame := 0

var rotating := false
var flip_t := 0          # quadros restantes da cambalhota do coelho
# Bloco que gira (campo "spin_block" da sala): a sala não gira; Q/E giram só um bloco quadrado
# e os espinhos presos nele. Por ser quadrado, a colisão não muda: só a face com espinhos.
# O jogo não pausa durante esse giro, e os espinhos passam para a face nova no fim dele.
var has_spin := false
var spin_rect := Rect2i()    # o bloco, em px
var spin_face := 0           # face com espinhos (0 cima, 1 direita, 2 baixo, 3 esquerda)
var spinning := false
var spin_frame := 0
var spin_dir := 0
var rot_lock_max := ROT_FRAMES + ROT_COOLDOWN
# Atores (campo "actors": scripts com step(room) e on_reset(room)), como o boss da sala.
var actors: Array = []
var door_unlocked := false   # um ator (o boss derrotado) abriu a porta
var music_override := ""        # faixa pedida por um ator; vale também para quem conecta depois
var invuln := 0              # quadros em que o coelho pisca e nada o mata (dano com vidas, no boss)
var flip_dir := 1        # sentido da cambalhota (o mesmo do giro)
var rot_frame := 0
var rot_from := 0.0
var rot_len := ROT_FRAMES   # duração da animação deste giro (a volta de 180° do limitador é mais longa)
var view_angle := 0.0
var pending_rot := 0
var rot_lock := 0  # quadros até poder girar de novo (animação + recarga)
# Limitador (campo "limiter" da sala): o giro é desfeito sozinho quando a recarga termina.
var limit_net := 0   # giros acumulados desde o estado inicial da sala
var limit_t := 0     # quadros até o giro ser desfeito (0 = nada a desfazer)
var reload_frames := ROT_FRAMES + ROT_COOLDOWN    # recarga do giro, com a animação (campo "reload_time")
var limiter_frames := ROT_FRAMES + ROT_COOLDOWN   # tempo até o limitador desfazer (campo "limiter_time")
var orientation := 0  # giros acumulados (0..3), só informativo

var cam := Vector2.ZERO  # ponto da sala (px) que fica no centro da tela
# Olhar (celular: arrastar o dedo pela tela): deslocamento da câmera em relação ao coelho.
# Limitado às bordas da sala; ao soltar, volta para o coelho.
var look := Vector2.ZERO
var looking := false     # dedo arrastando agora

var particles: Array = []
var rabbit_frames := {}
var shake := 0.0  # tremor de tela (px), decai sozinho
var jolt_amp := 0.0    # solavanco na direção da gravidade (px): oscila e amortece
var jolt_phase := 0.0
var impact_recent := 0.0  # força dos pousos dos últimos quadros; decai e soma com o próximo


func _process(_delta: float) -> void:
	queue_redraw()


func setup(room_def: Dictionary) -> void:
	def = room_def
	allow_rotate = room_def.get("rotate", true)
	reload_frames = seconds_to_frames(float(room_def.get("reload_time", DEFAULT_RELOAD)))
	rot_lock_max = reload_frames
	limiter_frames = seconds_to_frames(float(room_def.get("limiter_time", DEFAULT_LIMITER)))
	for path in room_def.get("actors", []):
		var a: Node = load(path).new()
		add_child(a)
		actors.append(a)
	reset()


func reset() -> void:
	var rows: Array = def["rows"]
	gh = rows.size()
	gw = 0
	for line in rows:
		gw = maxi(gw, String(line).length())
	pw = gw * TILE
	ph = gh * TILE
	_fx_live = false
	sway_frame = -1000
	bubbles.clear()
	tiles = PackedByteArray()
	tiles.resize(gw * gh)
	water_vol = 0.0
	water_calm = false
	water_dirty = false
	water_still = 0
	door_flooded = false
	door_dry = DOOR_DRY_FRAMES
	ropes.clear()
	drains.clear()
	crushers.clear()
	movers.clear()
	mover_state.clear()
	mover_pending.clear()
	plate_on.clear()
	plates.clear()
	conveyors.clear()
	springs.clear()
	fans.clear()
	vents.clear()
	belt_acc.clear()
	fan_gain = 0.0
	belt_gain = 0.0
	cycle_t = 0
	crumbles.clear()
	danger = 0.0
	danger_dir = -1
	boxes.clear()
	sockets.clear()
	socket_group.clear()
	socket_filled.clear()
	socket_fx.clear()
	spikes.clear()
	gates.clear()
	platforms.clear()
	particles.clear()
	jolt_amp = 0.0
	impact_recent = 0.0
	shake = 0.0
	door = Rect2i()
	has_door = false
	door_open = false
	door_flash = 0
	rotating = false
	rot_frame = 0
	flip_t = 0
	spinning = false
	spin_frame = 0
	door_unlocked = false
	actor_rot = 0
	input_lock = false
	cam_focus = null
	invuln = 0
	view_angle = 0.0
	pending_rot = 0
	rot_lock = 0
	limit_net = 0
	limit_t = 0
	orientation = 0
	state = "play"
	timer = 0
	rabbit = Rabbit.new()
	var water_tiles: Array = []
	fluid_acid = false
	batteries.clear()
	exits.clear()
	exits_unlocked = bool(def.get("_solved", false))
	bat_got = 0
	lever = null
	chute = null
	theme = str(def.get("theme", ""))
	soil = theme if SUBSOIL.has(theme) else ("despensa" if theme == "transicao" else "")
	_parse(rows, water_tiles)
	_find_anchors()
	anchor_fx = 0
	awaken_flash = 0
	awaken_t = 0 if def.get("awaken", false) and not awakened else -1
	_init_crushers()
	_init_movers()
	_init_dynamics()
	for pd in def.get("plates", []):
		plates.append({"rect": _tile_rect(pd["rect"]),
			"ch": int(pd.get("ch", 0)), "once": str(pd.get("mode", "hold")) == "once", "down": false, "latched": false, "k": 0.0,
			"timed": str(pd.get("mode", "hold")) == "timed", "time": seconds_to_frames(float(pd.get("time", 4.0))), "left": 0})
	for cr in def.get("crumbles", []):
		crumbles.append({"rect": Rect2i(int(cr[0]) * TILE, int(cr[1]) * TILE, int(cr[2]) * TILE, int(cr[3]) * TILE), "t": -1})
	_water_build()
	for t in water_tiles:
		for dx in TILE:
			var k := _tank_at(t.x * TILE + dx, t.y * TILE)
			if k >= 0:
				wt_h[k] += TILE
				water_vol += TILE
	var sr: int = def.get("start_rot", 0)
	for i in absi(sr):
		_rotate_logic(1 if sr > 0 else -1)
	_update_sockets()
	_update_mechanisms(true)
	_settle_water()
	for i in 300:
		_update_ropes()
	_update_sockets()
	if int(def.get("_entry", -1)) >= 0:
		_place_at_entry(int(def["_entry"]), def.get("_entry_vel", Vector2.ZERO))
	look = Vector2.ZERO
	cam = _cam_target()
	_init_spin_block()
	for a in actors:
		a.on_reset(self)
	_fx_live = true


## 0.0 logo após girar, 1.0 quando o giro está disponível de novo.
## Segundos -> quadros (60 por segundo), de pouco mais que a animação do giro até 30 s.
static func seconds_to_frames(s: float) -> int:
	return clampi(roundi(s * 60.0), ROT_FRAMES + 1, 1800)


func rot_ratio() -> float:
	return 1.0 - float(rot_lock) / float(rot_lock_max)


# ---------------------------------------------------------------- bloco que gira

## "spin_block": [coluna, linha, lado] em tiles. Os espinhos encostados nele giram junto.
## "spin_cooldown" (opcional): recarga do giro do bloco, em quadros.
func _init_spin_block() -> void:
	has_spin = def.has("spin_block")
	if not has_spin:
		return
	var b: Array = def["spin_block"]
	spin_rect = Rect2i(int(b[0]) * TILE, int(b[1]) * TILE, int(b[2]) * TILE, int(b[2]) * TILE)
	var ring := spin_rect.grow(TILE)
	for sp in spikes:
		if ring.encloses(sp["rect"]) and not spin_rect.intersects(sp["rect"]):
			sp["block"] = true
			spin_face = sp["facing"]


## A face que terá espinhos quando o giro em andamento terminar (ou a atual, sem giro).
func spin_face_next() -> int:
	return (spin_face + spin_dir + 4) % 4 if spinning else spin_face


func _begin_spin(dir: int) -> void:
	if not rabbit.free_rotate():
		rabbit.air_rot = false
	_flip_fx(dir)
	sfx.emit("platform")
	spinning = true
	spin_frame = 0
	spin_dir = dir
	rot_lock_max = SPIN_FRAMES + int(def.get("spin_cooldown", ROT_COOLDOWN))
	rot_lock = rot_lock_max


func _update_spin() -> void:
	if not spinning:
		return
	spin_frame += 1
	if spin_frame < SPIN_FRAMES:
		return
	spinning = false
	# os espinhos passam para a face nova: giro de 90° em torno do centro do bloco
	var c := Vector2(spin_rect.position) + Vector2(spin_rect.size) / 2.0
	for sp in spikes:
		if not sp.get("block", false):
			continue
		var cell := Vector2(sp["rect"].position) + Vector2(TILE, TILE) / 2.0 - c
		cell = Vector2(-cell.y, cell.x) if spin_dir > 0 else Vector2(cell.y, -cell.x)
		var np := (c + cell - Vector2(TILE, TILE) / 2.0).round()
		sp["rect"] = Rect2i(Vector2i(np), Vector2i(TILE, TILE))
		sp["facing"] = (int(sp["facing"]) + spin_dir + 4) % 4
	spin_face = (spin_face + spin_dir + 4) % 4
	shake = maxf(shake, 1.0)


## Retângulos que machucam dos espinhos do bloco (para o boss saber se bateu neles).
func spin_hurt_rects() -> Array:
	var out: Array = []
	for sp in spikes:
		if sp.get("block", false):
			out.append(_spike_hurt(sp["rect"], sp["facing"]))
	return out


# ---------------------------------------------------------------- blocos motorizados

## "movers": lista de {"ch": canal, "off": [coluna, linha, largura, altura] (tiles; onde a peça fica
## com o canal desligado), "on": [coluna, linha] (onde ela vai quando o canal liga), "speed": px/s,
## "spikes": lado dos espinhos (0 cima, 1 direita, 2 baixo, 3 esquerda; opcional)}. Os dois lugares
## têm de estar na mesma linha ou na mesma coluna. As peças do mesmo canal têm a mesma cor.
func _init_movers() -> void:
	for d in def.get("movers", []):
		var o: Array = d["off"]
		var n: Array = d["on"]
		var off := Rect2i(int(o[0]) * TILE, int(o[1]) * TILE, int(o[2]) * TILE, int(o[3]) * TILE)
		var on := Rect2i(int(n[0]) * TILE, int(n[1]) * TILE, off.size.x, off.size.y)
		movers.append({
			"off": off, "on": on, "r": off, "pf": Vector2(off.position),
			"ch": int(d.get("ch", 0)), "speed": float(d.get("speed", 40.0)),
			"spikes": int(d.get("spikes", -1)), "fx": 0,
			"launch": float(d.get("launch", 0.0)), "last": Vector2i.ZERO,
			# gatilhos próprios (além de um ator chamar mover_toggle): "cycle" (s por meio ciclo, com
			# "phase" em s de deslocamento) e "bat" (liga quando se pegou tantas baterias)
			"cycle": roundi(float(d.get("cycle", 0.0)) * 60.0),
			"phase": roundi(float(d.get("phase", 0.0)) * 60.0),
			"bat": int(d.get("bat", 0)),
			# "delay" (s): depois do gatilho (botão, bateria, canal), espera esse tempo, com os encaixes
			# piscando no fim, antes de se mover. Não vale para os de ciclo.
			"delay": roundi(float(d.get("delay", 0.0)) * 60.0),
			"raw": false, "eff": false, "trig_t": 0,
			"want": false, "warn": false,
		})


## Liga ou desliga um canal: os encaixes piscam por MOVER_WARN quadros (o aviso) e então as
## peças dele correm para o outro encaixe. `instant`: sem aviso.
func mover_toggle(ch: int, instant := false) -> void:
	if instant:
		_mover_flip(ch)
		return
	mover_pending.append([ch, MOVER_WARN])
	sfx.emit("mover_warn")


func _mover_flip(ch: int) -> void:
	mover_state[ch] = not mover_state.get(ch, false)
	sfx.emit("mover_go")
	for m in movers:
		if m["ch"] == ch:
			m["fx"] = 0


## O canal está no aviso (vai mudar em instantes)?
func mover_warning(ch: int) -> bool:
	for p in mover_pending:
		if p[0] == ch:
			return true
	return false


func mover_wants_on(m: Dictionary) -> bool:
	if m["cycle"] > 0:
		return m["want"]
	return m["eff"]


## O que o gatilho pede agora (antes do atraso).
func _mover_raw(m: Dictionary) -> bool:
	if m["bat"] > 0:
		return bat_got >= m["bat"]
	return mover_state.get(m["ch"], false) or plate_on.get(m["ch"], false)


## A peça está encaixada (parada no lugar a que o canal a manda).
func mover_docked(m: Dictionary) -> bool:
	var tgt: Rect2i = m["on"] if mover_wants_on(m) else m["off"]
	return m["r"].position == tgt.position


func _update_movers() -> void:
	cycle_t += 1
	for m in movers:
		var P: int = m["cycle"]
		if P <= 0:
			var raw := _mover_raw(m)
			if raw != m["raw"]:
				m["raw"] = raw
				m["trig_t"] = 0
			else:
				m["trig_t"] += 1
			if m["eff"] != raw and m["trig_t"] >= m["delay"]:
				m["eff"] = raw
				m["fx"] = 0
			m["warn"] = m["eff"] != raw and m["delay"] > 0 and m["delay"] - m["trig_t"] <= MOVER_WARN
			if m["delay"] > 0 and m["eff"] != raw and m["delay"] - m["trig_t"] == MOVER_WARN \
					and Vector2(m["r"].position).distance_to(cam) < VIEW.length() * 0.8:
				sfx.emit("mover_warn")
			continue
		var t: int = cycle_t + m["phase"]
		var on: bool = (t / P) % 2 == 1
		if on != m["want"] and cycle_t > 1:
			if Vector2(m["r"].position).distance_to(cam) < VIEW.length():
				sfx.emit("mover_go")
			m["fx"] = 0
		m["want"] = on
		# o aviso: os encaixes piscam nos últimos MOVER_WARN quadros de cada meio ciclo
		m["warn"] = P > 2 * MOVER_WARN and P - (t % P) <= MOVER_WARN
		if m["warn"] and P - (t % P) == MOVER_WARN and Vector2(m["r"].position).distance_to(cam) < VIEW.length() * 0.8:
			sfx.emit("mover_warn")
	for p in mover_pending:
		p[1] -= 1
		if p[1] <= 0:
			_mover_flip(p[0])
	mover_pending = mover_pending.filter(func(p): return p[1] > 0)
	for m in movers:
		if m["fx"] >= 0:
			m["fx"] += 1
		var tgt: Rect2i = m["on"] if mover_wants_on(m) else m["off"]
		var was: bool = m["r"].position == tgt.position
		if not was:
			var delta: Vector2 = Vector2(tgt.position) - m["pf"]
			var dist: float = delta.length()
			var mv: float = minf(dist, float(m["speed"]) * DT)
			m["pf"] += delta / dist * mv
			var d: Vector2i = Vector2i(m["pf"].round()) - m["r"].position
			while d != Vector2i.ZERO:
				var st: Vector2i = Vector2i(signi(d.x), 0) if d.x != 0 else Vector2i(0, signi(d.y))
				if not _mover_step(m, st):
					m["pf"] = Vector2(m["r"].position)
					break
				m["last"] = st
				d -= st
				if state != "play":
					return
			if m["r"].position == tgt.position:
				# encaixou: um estalo curto, com o brilho do encaixe
				m["pf"] = Vector2(tgt.position)
				m["fx"] = 0
				shake = maxf(shake, 0.5)
				sfx.emit("mover_dock")
				_mover_launch(m)


## Catapulta ("launch": px/s): a peça que chega ao encaixe subindo arremessa o coelho que
## está em cima dela. É o jeito rápido de subir: a pressa de quem as aciona vira carona.
func _mover_launch(m: Dictionary) -> void:
	if m["launch"] <= 0.0 or m["last"] != Vector2i(0, -1):
		return
	var rr: Rect2i = rabbit.rect
	if not overlaps(Rect2i(rr.position.x, rr.end.y, rr.size.x, 1), m["r"]):
		return
	rabbit.vel.y = -float(m["launch"])
	rabbit.var_jump = 0
	rabbit.on_ground = false
	rabbit.coyote = 0
	rabbit.squash = Vector2(0.7, 1.35)
	sfx.emit("launch")
	shake = maxf(shake, 1.5)
	var feet := Vector2(rr.position.x + 6, rr.end.y)
	particles.append({"pos": feet, "vel": Vector2.ZERO, "life": 12, "col": C_CHANNEL[m["ch"] % C_CHANNEL.size()], "grav": 0.0, "ring": 3.0})
	for i in 8:
		particles.append({
			"pos": feet + Vector2(randf_range(-6.0, 6.0), 0), "vel": Vector2(randf_range(-40.0, 40.0), randf_range(10.0, 50.0)),
			"life": randi_range(10, 18), "col": C_PAINT, "grav": 200.0,
		})


# ---------------------------------------------------------------- esteiras, molas, ventiladores e vapor

const BELT_TOP_SKIP := 0
const SPRING_CD := 10
const VENT_WARN := 30           # quadros de aviso antes de o jato abrir
const FAN_BOX_LIFT := 0.85      # fração da velocidade do coelho com que o ar sobe uma caixa
const DIR_VEC := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]


func _tile_rect(a: Array) -> Rect2i:
	return Rect2i(int(a[0]) * TILE, int(a[1]) * TILE, int(a[2]) * TILE, (int(a[3]) if a.size() > 3 else 1) * TILE)


## "conveyors": [{"rect": [coluna, linha, largura], "dir": 1 (direita) ou 3 (esquerda), "speed": px/s,
##   "ch": canal que inverte o sentido (opcional), "cycle": s entre inversões (opcional)}].
##   A esteira vai por cima de tiles de parede: a superfície é o alto da fileira.
## "springs": [{"rect": [coluna, linha, largura], "power": px/s (padrão 280), "dir": 0}]
##   A mola fica no tile em cima do chão; quem a toca é lançado no sentido de "dir".
## "fans": [{"rect": [coluna, linha, largura, altura], "dir": 0, "accel": px/s² (1500), "cap": px/s (70)}]
## "vents": [{"rect": [coluna, linha, largura, altura], "dir": 0, "period": s, "on": s, "phase": s}]
##   O jato abre nos últimos "on" segundos de cada período; os 0,5 s antes dele são o aviso.
func _init_dynamics() -> void:
	for d in def.get("conveyors", []):
		conveyors.append({
			"rect": _tile_rect(d["rect"]), "dir": posmod(int(d.get("dir", 1)), 4), "speed": float(d.get("speed", 40.0)),
			"ch": int(d.get("ch", -1)), "cycle": roundi(float(d.get("cycle", 0.0)) * 60.0), "phase": 0.0,
		})
	for d in def.get("springs", []):
		springs.append({
			"rect": _tile_rect(d["rect"]), "power": float(d.get("power", 280.0)), "dir": posmod(int(d.get("dir", 0)), 4),
			"k": 0.0, "cd": 0,
		})
	for d in def.get("fans", []):
		fans.append({
			"rect": _tile_rect(d["rect"]), "dir": posmod(int(d.get("dir", 0)), 4),
			"accel": float(d.get("accel", 1500.0)), "cap": float(d.get("cap", 70.0)), "spin": 0.0,
		})
	for d in def.get("vents", []):
		vents.append({
			"rect": _tile_rect(d["rect"]), "dir": posmod(int(d.get("dir", 0)), 4),
			"period": maxi(roundi(float(d.get("period", 3.0)) * 60.0), 10), "on": maxi(roundi(float(d.get("on", 1.0)) * 60.0), 1),
			"phase": roundi(float(d.get("phase", 0.0)) * 60.0), "active": false, "warn": false, "age": 0,
		})


## Sentido atual de uma esteira: -1, +1 (só vale na horizontal) e 0 se está de lado.
func belt_sign(c: Dictionary) -> int:
	if c["dir"] % 2 == 0:
		return 0
	var sg := 1 if c["dir"] == 1 else -1
	var rev := false
	if c["ch"] >= 0:
		rev = mover_state.get(c["ch"], false) or plate_on.get(c["ch"], false)
	if c["cycle"] > 0 and (cycle_t / c["cycle"]) % 2 == 1:
		rev = not rev
	return -sg if rev else sg


func _update_conveyors() -> void:
	belt_gain = 0.0
	if conveyors.is_empty():
		return
	var bodies: Array = [rabbit]
	bodies.append_array(boxes)
	for c in conveyors:
		var sg := belt_sign(c)
		var cr: Rect2i = c["rect"]
		c["phase"] = fposmod(c["phase"] + sg * float(c["speed"]) * DT, 8.0)
		var dist := Vector2(cr.get_center()).distance_to(Vector2(rabbit.pos) + Vector2(6, 6))
		belt_gain = maxf(belt_gain, clampf(1.0 - dist / 140.0, 0.0, 1.0))
		if sg == 0:
			continue
		for b in bodies:
			var br: Rect2i = b.rect
			if br.end.y != cr.position.y or br.end.x <= cr.position.x or br.position.x >= cr.end.x:
				continue
			if b == rabbit:
				if not rabbit.on_ground or rabbit.rope != null:
					continue
			elif not b.settled:
				continue
			var acc: float = belt_acc.get(b, 0.0) + sg * float(c["speed"]) * DT
			while absf(acc) >= 1.0:
				var st := Vector2i(1 if acc > 0.0 else -1, 0)
				var nxt := Rect2i(b.pos + st, b.rect.size)
				var blocked := not _body_can_move(b, st, Rect2i())
				if b != rabbit and overlaps(nxt, rabbit.rect):
					blocked = true
				if blocked:
					acc = 0.0
					break
				b.pos += st
				acc -= float(st.x)
			belt_acc[b] = acc


func _update_springs() -> void:
	for sp in springs:
		sp["k"] = maxf(sp["k"] - 0.12, 0.0)
		sp["cd"] = maxi(sp["cd"] - 1, 0)
		if sp["cd"] > 0 or rabbit.rope != null:
			continue
		var dv: Vector2 = DIR_VEC[sp["dir"]]
		if overlaps(rabbit.rect, sp["rect"]) and rabbit.vel.dot(dv) < sp["power"] * 0.5:
			sp["cd"] = SPRING_CD
			sp["k"] = 1.0
			rabbit.vel = rabbit.vel * (Vector2.ONE - dv.abs()) + dv * float(sp["power"])
			rabbit.var_jump = 0
			rabbit.on_ground = false
			rabbit.coyote = 0
			rabbit.jumping = true
			rabbit.air_rot = true
			rabbit.squash = Vector2(0.7, 1.35)
			sfx.emit("spring")
			shake = maxf(shake, 0.6)
			var c := Vector2(sp["rect"].get_center())
			particles.append({"pos": c, "vel": Vector2.ZERO, "life": 10, "col": C_PAINT, "grav": 0.0, "ring": 3.0})


## O ventilador age no coelho antes de ele se mover (rabbit.ext), e nas caixas dentro do campo dele.
func _update_fans() -> void:
	rabbit.ext = Vector2.ZERO
	fan_gain = 0.0
	if fans.is_empty():
		return
	var center := Vector2(rabbit.pos) + Vector2(6, 6)
	for f in fans:
		var fr: Rect2i = f["rect"]
		f["spin"] += 0.35
		fan_gain = maxf(fan_gain, clampf(1.0 - Vector2(fr.get_center()).distance_to(center) / 150.0, 0.0, 1.0))
		if rabbit.rope == null and overlaps(rabbit.rect, fr):
			var dv: Vector2 = DIR_VEC[f["dir"]]
			rabbit.ext = dv * float(f["accel"])
			rabbit.ext_dir = dv
			rabbit.ext_cap = float(f["cap"])
		# poeira de ar subindo, só o que está na tela
		if frame % 3 == 0 and Vector2(fr.get_center()).distance_to(cam) < VIEW.length() * 0.75:
			var dv2: Vector2 = DIR_VEC[f["dir"]]
			var along: Vector2 = dv2 * randf() * (fr.size.y if f["dir"] % 2 == 0 else fr.size.x)
			var across := Vector2(dv2.y, -dv2.x) * (randf() - 0.5) * (fr.size.x if f["dir"] % 2 == 0 else fr.size.y)
			var origin := Vector2(fr.get_center()) - dv2 * (fr.size.y if f["dir"] % 2 == 0 else fr.size.x) / 2.0
			particles.append({"pos": origin + along + across, "vel": dv2 * 30.0, "life": randi_range(10, 18), "col": Color(C_PAINT, 0.5), "grav": 0.0})


## Caixa no campo de um ventilador que sopra para cima: sobe, no lugar de cair.
func box_fan_lift(b) -> Dictionary:
	for f in fans:
		if f["dir"] == 0 and overlaps(b.rect, f["rect"]):
			return f
	return {}


func _update_vents() -> void:
	for v in vents:
		var t: int = (cycle_t + v["phase"]) % v["period"]
		var open_at: int = v["period"] - v["on"]
		var was_active: bool = v["active"]
		var was_warn: bool = v["warn"]
		v["active"] = t >= open_at
		v["warn"] = not v["active"] and t >= open_at - VENT_WARN
		v["age"] = v["age"] + 1 if v["active"] else 0
		var near: bool = Vector2(v["rect"].get_center()).distance_to(cam) < VIEW.length() * 0.8
		if near and v["warn"] and not was_warn:
			sfx.emit("steam_warn")
		if near and v["active"] and not was_active:
			sfx.emit("steam_burst")
			shake = maxf(shake, 0.5)


## O vapor, em grãos: centenas de bolinhas que saem do bocal, sobem espalhando e crescendo e vão
## sumindo. Cada grão tem velocidade, posição lateral e tamanho fixos (saem de um hash do número dele),
## então o desenho não pisca; só o relógio (`frame`) o move. No aviso, só um fiapo curto e ralo.
func _draw_steam(lw: float, ll: float, by: float, active: bool, age: int) -> void:
	var n := int(lw * ll / 7.0) if active else maxi(int(lw * ll / 45.0), 4)
	var reach := ll - 6.0
	if active:
		reach *= clampf(float(age) / 8.0, 0.15, 1.0)   # o jato abre rápido, mas não de uma vez
	else:
		reach *= 0.22
	for k in n:
		var h1 := fposmod(sin(k * 12.9898) * 43758.5453, 1.0)
		var h2 := fposmod(sin(k * 78.233 + 1.7) * 24634.6345, 1.0)
		var h3 := fposmod(sin(k * 39.346 + 5.1) * 12345.6789, 1.0)
		var u := fposmod(float(frame) * (0.016 + h1 * 0.022) + h2, 1.0)        # 0 no bocal, 1 no alto
		var y := by - 6.0 - u * reach
		var x := (h3 - 0.5) * (lw - 3.0) * (0.3 + 0.9 * u) + sin(float(frame) * 0.08 + k) * (0.5 + 1.8 * u)
		var rad := 0.8 + u * 2.2 + h1 * 0.8
		var a := (1.0 - u) * (0.62 if active else 0.3)
		if not active:
			a *= smoothstep(0.0, 0.2, u)
		draw_circle(Vector2(x, y), rad * 1.9, Color(0.86, 0.93, 1.0, a * 0.22))   # névoa grande e fraca
		draw_circle(Vector2(x, y), rad, Color(0.96, 0.98, 1.0, a))                 # o grão


## Põe o desenho no referencial da peça: origem no centro, "para cima" no sentido de `dir`.
func _local_begin(center: Vector2, dir: int) -> void:
	draw_set_transform_matrix(_base * Transform2D(dir * PI / 2.0, center))


func _local_end() -> void:
	draw_set_transform_matrix(_base)


func _on_screen(r: Rect2i, margin := 24.0) -> bool:
	return (Vector2(r.get_center()) - cam).length() <= VIEW.length() / 2.0 + margin + float(maxi(r.size.x, r.size.y)) / 2.0


func _draw_conveyors() -> void:
	for c in conveyors:
		var r := Rect2(c["rect"])
		if not _on_screen(c["rect"]):
			continue
		var sg := belt_sign(c)
		var col: Color = C_CHANNEL[c["ch"] % C_CHANNEL.size()] if c["ch"] >= 0 else C_STEEL_LIGHT
		draw_rect(r, C_SEAM)
		draw_rect(r.grow(-1.0), C_STEEL[2])
		if sg == 0:
			# de lado (a sala girou): só as listras, sem movimento
			for i in range(0, int(maxf(r.size.x, r.size.y)), 4):
				var o := Vector2(0, i) if r.size.x < r.size.y else Vector2(i, 0)
				draw_rect(Rect2(r.position + o, Vector2(r.size.x, 1) if r.size.x < r.size.y else Vector2(1, r.size.y)), Color(col, 0.3))
			continue
		# a esteira de cima: tira escura com setas correndo no sentido dela
		draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 4)), C_SEAM)
		var ph: float = c["phase"]
		var x := r.position.x - 8.0 + ph
		while x < r.end.x:
			var cx := x
			if cx >= r.position.x + 1 and cx + 3 <= r.end.x - 1:
				var tip := cx + (3.0 if sg > 0 else 0.0)
				var back := cx + (0.0 if sg > 0 else 3.0)
				draw_line(Vector2(back, r.position.y + 1.5), Vector2(tip, r.position.y + 3.0), col, 1.0)
				draw_line(Vector2(tip, r.position.y + 3.0), Vector2(back, r.position.y + 4.5), col, 1.0)
			x += 8.0
		draw_rect(Rect2(r.position + Vector2(1, 5), Vector2(r.size.x - 2, 1)), Color(col, 0.35))
		# roletes nas pontas
		draw_circle(Vector2(r.position.x + 2.5, r.position.y + 3.0), 2.5, C_STEEL_LIGHT)
		draw_circle(Vector2(r.end.x - 2.5, r.position.y + 3.0), 2.5, C_STEEL_LIGHT)
		draw_circle(Vector2(r.position.x + 2.5, r.position.y + 3.0), 0.9, C_SEAM)
		draw_circle(Vector2(r.end.x - 2.5, r.position.y + 3.0), 0.9, C_SEAM)


func _draw_springs() -> void:
	for sp in springs:
		var r: Rect2i = sp["rect"]
		if not _on_screen(r):
			continue
		var lw: float = r.size.x if sp["dir"] % 2 == 0 else r.size.y
		var lh: float = TILE
		_local_begin(Vector2(r.get_center()), sp["dir"])
		var k: float = sp["k"]
		var half_w := lw / 2.0
		var base_y := lh / 2.0
		var pad_y := -lh / 2.0 + 1.0 + 3.0 * k          # a mola comprime ao ser pisada
		# base de aço, mola em zigue-zague, tampa âmbar
		draw_rect(Rect2(-half_w, base_y - 2, lw, 2), C_SEAM)
		draw_rect(Rect2(-half_w + 1, base_y - 2, lw - 2, 1), C_STEEL_LIGHT)
		var n := maxi(int(lw / 6.0), 1)
		for i in n:
			var cx := -half_w + lw * (i + 0.5) / n
			var pts := PackedVector2Array()
			var steps := 5
			for j in steps + 1:
				var yy := lerpf(pad_y + 2.0, base_y - 2.0, float(j) / steps)
				pts.append(Vector2(cx + (2.0 if j % 2 == 0 else -2.0), yy))
			draw_polyline(pts, C_RIVET, 1.0)
		draw_rect(Rect2(-half_w, pad_y, lw, 2), C_BAT)
		draw_rect(Rect2(-half_w, pad_y, lw, 1), Color(1, 1, 1, 0.5))
		_local_end()


func _draw_fans() -> void:
	for f in fans:
		var r: Rect2i = f["rect"]
		if not _on_screen(r):
			continue
		var lw: float = r.size.x if f["dir"] % 2 == 0 else r.size.y
		var ll: float = r.size.y if f["dir"] % 2 == 0 else r.size.x
		_local_begin(Vector2(r.get_center()), f["dir"])
		# a coluna de ar e as listras correndo para cima
		draw_rect(Rect2(-lw / 2.0, -ll / 2.0, lw, ll), Color(C_PAINT, 0.08))
		draw_rect(Rect2(-lw / 2.0, -ll / 2.0, 1, ll), Color(C_PAINT, 0.12))
		draw_rect(Rect2(lw / 2.0 - 1, -ll / 2.0, 1, ll), Color(C_PAINT, 0.12))
		for i in int(lw / 6.0):
			var sx := -lw / 2.0 + 3.0 + i * 6.0
			var off := fposmod(float(frame) * 1.6 + i * 9.0, ll)
			draw_rect(Rect2(sx, ll / 2.0 - off, 1, 5), Color(C_PAINT, 0.28))
		# caixa do ventilador na base, com as pás vistas de lado
		var by := ll / 2.0
		draw_rect(Rect2(-lw / 2.0, by - 6, lw, 6), C_SEAM)
		draw_rect(Rect2(-lw / 2.0 + 1, by - 5, lw - 2, 4), C_STEEL[1])
		var bl := absf(cos(f["spin"]))
		var cx := 0.0
		draw_line(Vector2(cx - (lw / 2.0 - 3.0) * bl, by - 3), Vector2(cx + (lw / 2.0 - 3.0) * bl, by - 3), C_STEEL_LIGHT, 2.0)
		draw_rect(Rect2(-1, by - 4, 2, 2), C_RIVET)
		for q in [-lw / 2.0 + 2.0, lw / 2.0 - 3.0]:
			draw_rect(Rect2(q, by - 5, 1, 1), C_RIVET)
		_local_end()


func _draw_vents() -> void:
	for v in vents:
		var r: Rect2i = v["rect"]
		if not _on_screen(r):
			continue
		var lw: float = r.size.x if v["dir"] % 2 == 0 else r.size.y
		var ll: float = r.size.y if v["dir"] % 2 == 0 else r.size.x
		_local_begin(Vector2(r.get_center()), v["dir"])
		var by := ll / 2.0
		if v["active"] or v["warn"]:
			_draw_steam(lw, ll, by, v["active"], v["age"])
		# bocal na base, com uma luz de aviso: pisca no aviso, vermelha enquanto aberto
		draw_rect(Rect2(-lw / 2.0 - 1, by - 5, lw + 2, 5), C_SEAM)
		draw_rect(Rect2(-lw / 2.0, by - 4, lw, 3), C_STEEL[1])
		for i in int(lw / 4.0):
			draw_rect(Rect2(-lw / 2.0 + 1 + i * 4, by - 4, 2, 3), C_BAT if i % 2 == 0 else C_SEAM)   # listras de aviso
		var lamp := Color("5a4034")
		if v["active"]:
			lamp = C_SPIKE
		elif v["warn"] and (frame / 4) % 2 == 0:
			lamp = C_BAT
		draw_rect(Rect2(-1, by - 7, 2, 2), lamp)
		if v["warn"] and (frame / 4) % 2 == 0:
			draw_circle(Vector2(0, by - 6), 4.0, Color(C_BAT, 0.18))
		_local_end()


# ---------------------------------------------------------------- botões de pressão

func _update_plates() -> void:
	if plates.is_empty():
		return
	plate_on.clear()
	var bodies: Array = [rabbit]
	bodies.append_array(boxes)
	for p in plates:
		var pr: Rect2i = p["rect"]
		var zone := Rect2i(pr.position.x, pr.position.y + 3, pr.size.x, 5)
		var pressed := false
		for b in bodies:
			if overlaps(b.rect, zone):
				pressed = true
				break
		if p["once"]:
			p["latched"] = p["latched"] or pressed
			pressed = p["latched"]
		elif p["timed"]:
			if pressed:
				p["left"] = p["time"]
			else:
				p["left"] = maxi(p["left"] - 1, 0)
			pressed = pressed or p["left"] > 0
		if pressed != p["down"]:
			p["down"] = pressed
			if Vector2(pr.position).distance_to(cam) < VIEW.length():
				sfx.emit("plate_on" if pressed else "plate_off")
		p["k"] = move_toward(p["k"], 1.0 if pressed else 0.0, 0.25)
		if pressed:
			plate_on[p["ch"]] = true


func _draw_plates() -> void:
	for p in plates:
		var pr := Rect2(p["rect"])
		if (pr.get_center() - cam).length() > VIEW.length() / 2.0 + 24.0:
			continue
		var col: Color = C_CHANNEL[p["ch"] % C_CHANNEL.size()]
		var dip: float = p["k"] * 2.0
		var cx := pr.get_center().x
		# brilho no chão em volta, na cor do canal (mais forte apertado)
		var glow: float = 0.10 + 0.08 * sin(frame * 0.12) + 0.25 * p["k"]
		draw_circle(Vector2(cx, pr.end.y - 3), pr.size.x * 0.9, Color(col, glow * 0.5))
		# base mais larga que o botão, e o botão com a borda na cor do canal
		draw_rect(Rect2(pr.position.x - 2, pr.end.y - 3, pr.size.x + 4, 3), C_SEAM)
		draw_rect(Rect2(pr.position.x - 2, pr.end.y - 3, pr.size.x + 4, 1), C_STEEL_LIGHT)
		draw_rect(Rect2(pr.position.x + 1, pr.end.y - 5 + dip, pr.size.x - 2, 3), col.darkened(0.35))
		draw_rect(Rect2(pr.position.x + 1, pr.end.y - 5 + dip, pr.size.x - 2, 1), col.lightened(0.2 + 0.3 * p["k"]))
		draw_rect(Rect2(pr.position.x + 2, pr.end.y - 4 + dip, 1, 1), Color(1, 1, 1, 0.6))
		if p["k"] < 0.5 and not (p["once"] and p["latched"]):
			# seta pulsando acima: "pise aqui"
			var bob := roundf(sin(frame * 0.15) * 1.5)
			var ty := pr.end.y - 12.0 + bob
			var ac := Color(col, 0.55 + 0.35 * sin(frame * 0.15))
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 3, ty), Vector2(cx + 3, ty), Vector2(cx, ty + 3)]), ac)
			draw_rect(Rect2(cx - 0.5, ty - 3, 1, 3), ac)
		if p["timed"] and p["left"] > 0:
			# quanto falta para desligar
			var f := float(p["left"]) / float(p["time"])
			draw_rect(Rect2(pr.position.x - 1, pr.end.y - 9, pr.size.x + 2, 2), C_SEAM)
			draw_rect(Rect2(pr.position.x - 1, pr.end.y - 9, (pr.size.x + 2) * f, 2), col)


# ---------------------------------------------------------------- chapas soltas

func _update_crumbles() -> void:
	if crumbles.is_empty():
		return
	var rr: Rect2i = rabbit.rect
	var feet := Rect2i(rr.position.x, rr.end.y, rr.size.x, 1)
	var fell := false
	for c in crumbles:
		if c["t"] < 0:
			if rabbit.on_ground and overlaps(feet, c["rect"]):
				c["t"] = 0
				sfx.emit("crumble_warn")
		else:
			c["t"] += 1
			if c["t"] >= CRUMBLE_FRAMES:
				fell = true
				var r: Rect2i = c["rect"]
				for i in maxi(r.size.x / 4, 2):
					particles.append({
						"pos": Vector2(r.position.x + randf() * r.size.x, r.position.y + randf() * r.size.y),
						"vel": Vector2(randf_range(-25.0, 25.0), randf_range(-10.0, 40.0)),
						"life": randi_range(16, 28), "col": C_RUST if i % 2 == 0 else C_STEEL_LIGHT, "grav": 420.0,
					})
	if fell:
		crumbles = crumbles.filter(func(c): return c["t"] < CRUMBLE_FRAMES)
		sfx.emit("crumble")
		shake = maxf(shake, 0.8)


# ---------------------------------------------------------------- perigo (placa perto)

## 0 a 1 conforme a placa mais próxima (já ligada) chega perto do coelho. O jogo usa para o
## som (ronco e alarme) e para o brilho vermelho na borda da tela de onde ela vem.
func _update_danger() -> void:
	crunch_cd = maxi(crunch_cd - 1, 0)
	var best := 0.0
	var bdir := -1
	for c in crushers:
		if c["wait"] != 0 or c["adv"] <= 0.0 or c["adv"] >= float(_crusher_len(c)):
			continue
		var d := clampf((DANGER_FAR - crusher_gap(c)) / (DANGER_FAR - DANGER_NEAR), 0.0, 1.0)
		if d > best:
			best = d
			bdir = c["dir"]
	danger = lerpf(danger, best, 0.15)
	danger_dir = bdir if best > 0.0 else danger_dir
	if danger < 0.01:
		danger = 0.0


## Anda a peça 1 px. Quem está em cima vai junto; quem estava no caminho é empurrado, e é
## esmagado se não tem para onde ir. Devolve false se a peça não pôde andar (caixa travando).
func _mover_step(m: Dictionary, st: Vector2i) -> bool:
	var old: Rect2i = m["r"]
	var nr := Rect2i(old.position + st, old.size)
	var riders: Array = []
	var pushed: Array = []
	var bodies: Array = [rabbit]
	bodies.append_array(boxes)
	for b in bodies:
		var br: Rect2i = b.rect
		if overlaps(Rect2i(br.position.x, br.end.y, br.size.x, 1), old):
			riders.append(b)
		elif overlaps(br, nr):
			pushed.append(b)
	for b in pushed:
		if b != rabbit and not _body_can_move(b, st, nr):
			return false
	m["r"] = nr
	for b in riders + pushed:
		if _body_can_move(b, st, Rect2i()):
			b.pos += st
		elif b == rabbit:
			kill()   # esmagado entre a peça e a parede
			return true
	return true


func _body_can_move(b, st: Vector2i, ignore_rect: Rect2i) -> bool:
	var nxt := Rect2i(b.pos + st, b.rect.size)
	if tile_solid_rect(nxt):
		return false
	for g in gates:
		if g["closed"]:
			for gr in g["rects"]:
				if overlaps(nxt, gr):
					return false
	for p in platforms:
		if _plat_blocks(p, nxt, st.y < 0):
			return false
	for ex in exits:
		if not exit_open(ex) and overlaps(nxt, ex["rect"]):
			return false
	for o in movers:
		if overlaps(nxt, o["r"]) and o["r"] != ignore_rect and not overlaps(b.rect, o["r"]):
			return false
	for c in crumbles:
		if overlaps(nxt, c["rect"]):
			return false
	return box_at(nxt, b) == null


## As células de espinho de uma peça: uma por tile ao longo da face, do lado de fora dela.
func _mover_teeth(m: Dictionary) -> Array:
	var r: Rect2i = m["r"]
	var out: Array = []
	var f: int = m["spikes"]
	var n: int = (r.size.x if f % 2 == 0 else r.size.y) / TILE
	for i in n:
		match f:
			0:
				out.append(Rect2i(r.position.x + i * TILE, r.position.y - TILE, TILE, TILE))
			1:
				out.append(Rect2i(r.end.x, r.position.y + i * TILE, TILE, TILE))
			2:
				out.append(Rect2i(r.position.x + i * TILE, r.end.y, TILE, TILE))
			_:
				out.append(Rect2i(r.position.x - TILE, r.position.y + i * TILE, TILE, TILE))
	return out


# ---------------------------------------------------------------- placa de espinhos

## "crushers": lista de {"rect": [coluna, linha, largura, altura] (a faixa que ela varre, em
## tiles), "dir" (para onde avança: 0 cima, 1 direita, 2 baixo, 3 esquerda), "speed" (px/s),
## "delay" (s até começar; negativo: espera um ator chamar crusher_start), "start" (px já
## avançados ao carregar), "leash" (px; se o coelho abre mais que isso, ela acelera; 0 = não),
## "face" ("happy" ou "sad")}.
func _init_crushers() -> void:
	for d in def.get("crushers", []):
		var r: Array = d["rect"]
		var c := {
			"lane": Rect2i(int(r[0]) * TILE, int(r[1]) * TILE, int(r[2]) * TILE, int(r[3]) * TILE),
			"dir": posmod(int(d.get("dir", 0)), 4),
			"adv": 0.0,
			"speed": float(d.get("speed", 9.0)),
			"wait": roundi(float(d.get("delay", 0.0)) * 60.0),
			"leash": float(d.get("leash", 0.0)),
			"face": String(d.get("face", "happy")),
			"turn": 0,   # giros desde o desenho da fase: a carinha é pintada na placa e gira com ela
		}
		c["adv"] = clampf(float(d.get("start", 0.0)), 0.0, float(_crusher_len(c)))
		crushers.append(c)
		_crusher_eat(c, true)


## Um ator gira a sala (o Gatsby). Acontece no quadro seguinte, fora da animação de outro giro.
func actor_rotate(dir: int) -> void:
	actor_rot = signi(dir)


## Um ator liga a placa `i` (as que têm "delay" negativo esperam por isto).
func crusher_start(i: int) -> void:
	if i >= 0 and i < crushers.size():
		if crushers[i]["wait"] != 0:
			sfx.emit("crusher_wake")
			shake = maxf(shake, 3.0)
		crushers[i]["wait"] = 0


func _crusher_len(c: Dictionary) -> int:
	var lane: Rect2i = c["lane"]
	return lane.size.y if c["dir"] % 2 == 0 else lane.size.x


## O trecho da faixa entre dois avanços (px a partir do lado de onde a placa vem).
func _crusher_rect(c: Dictionary, a0: int, a1: int) -> Rect2i:
	var l: Rect2i = c["lane"]
	match c["dir"]:
		0:
			return Rect2i(l.position.x, l.end.y - a1, l.size.x, a1 - a0)
		1:
			return Rect2i(l.position.x + a0, l.position.y, a1 - a0, l.size.y)
		2:
			return Rect2i(l.position.x, l.position.y + a0, l.size.x, a1 - a0)
	return Rect2i(l.end.x - a1, l.position.y, a1 - a0, l.size.y)


## Distância (px) da frente da placa até o coelho, no sentido em que ela avança.
func crusher_gap(c: Dictionary) -> float:
	var l: Rect2i = c["lane"]
	var a: float = c["adv"]
	match c["dir"]:
		0:
			return (l.end.y - a) - (rabbit.pos.y + Rabbit.SIZE)
		1:
			return rabbit.pos.x - (l.position.x + a)
		2:
			return rabbit.pos.y - (l.position.y + a)
	return (l.end.x - a) - (rabbit.pos.x + Rabbit.SIZE)


func _update_crushers() -> void:
	for c in crushers:
		if c["wait"] != 0:
			if c["wait"] > 0:
				c["wait"] -= 1
			continue
		var total := float(_crusher_len(c))
		if c["adv"] >= total:
			continue
		var v: float = c["speed"]
		if c["leash"] > 0.0 and crusher_gap(c) > c["leash"]:
			v *= CRUSH_CATCHUP
		c["adv"] = minf(c["adv"] + v * DT, total)
		_crusher_eat(c, false)


## Destrói o que os dentes alcançaram: paredes, espinhos, plataformas, comportas, ralos,
## compartimentos e caixas. `all`: confere a placa inteira (ao carregar); senão, só a frente.
## Cordas ficam (o coelho pode estar pendurado numa).
func _crusher_eat(c: Dictionary, all: bool) -> void:
	var a1 := int(c["adv"]) + CRUSH_SPIKE
	if c["adv"] <= 0.0:
		return
	var hurt := _crusher_rect(c, 0, a1)
	var strip := hurt if all else _crusher_rect(c, maxi(a1 - 2 * TILE, 0), a1)
	var changed := false
	var x0 := maxi(strip.position.x, 0) >> 3
	var y0 := maxi(strip.position.y, 0) >> 3
	var x1 := mini(strip.end.x - 1, pw - 1) >> 3
	var y1 := mini(strip.end.y - 1, ph - 1) >> 3
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if tiles[ty * gw + tx] != 0:
				tiles[ty * gw + tx] = 0
				changed = true
				if not all:
					_crush_debris(Vector2(tx * TILE + 4, ty * TILE + 4), c["dir"])
	var n := spikes.size() + platforms.size() + drains.size() + boxes.size() + movers.size()
	spikes = spikes.filter(func(s): return not overlaps(hurt, s["rect"]))
	platforms = platforms.filter(func(p): return not overlaps(hurt, p["rect"]))
	drains = drains.filter(func(d): return not overlaps(hurt, d["rect"]))
	movers = movers.filter(func(m): return not overlaps(hurt, m["r"]))
	var nc := crumbles.size() + plates.size() + conveyors.size() + springs.size() + fans.size() + vents.size()
	crumbles = crumbles.filter(func(cr): return not overlaps(hurt, cr["rect"]))
	plates = plates.filter(func(pl): return not overlaps(hurt, pl["rect"]))
	conveyors = conveyors.filter(func(o): return not overlaps(hurt, o["rect"]))
	springs = springs.filter(func(o): return not overlaps(hurt, o["rect"]))
	fans = fans.filter(func(o): return not overlaps(hurt, o["rect"]))
	vents = vents.filter(func(o): return not overlaps(hurt, o["rect"]))
	if nc != crumbles.size() + plates.size() + conveyors.size() + springs.size() + fans.size() + vents.size():
		changed = true
	boxes = boxes.filter(func(b): return not overlaps(hurt, b.rect))
	if n != spikes.size() + platforms.size() + drains.size() + boxes.size() + movers.size():
		changed = true
	for g in gates:
		var rs: Array = g["rects"]
		var keep := rs.filter(func(r): return not overlaps(hurt, r))
		if keep.size() != rs.size():
			g["rects"] = keep
			changed = true
	for i in range(sockets.size() - 1, -1, -1):
		if overlaps(hurt, sockets[i]):
			sockets.remove_at(i)
			socket_group.remove_at(i)
			socket_filled.remove_at(i)
			socket_fx.remove_at(i)
	if changed:
		if not all:
			shake = maxf(shake, 0.8)
			if crunch_cd == 0:
				crunch_cd = 9
				sfx.emit("crunch")
		if water_vol > 0.0:
			water_dirty = true


func _crush_debris(p: Vector2, dir: int) -> void:
	var fwd: Vector2 = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][dir]
	for i in 2:
		particles.append({
			"pos": p + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)),
			"vel": fwd * randf_range(20.0, 60.0) + Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 10.0)),
			"life": randi_range(12, 22), "col": C_EDGE if i == 0 else C_DUST, "grav": 300.0,
		})


# ---------------------------------------------------------------- parsing

func _parse(rows: Array, water_tiles: Array) -> void:
	var visited := {}
	var door_cells: Array = []
	var exit_cells: Array = []
	var gate_cells := {}  # id (negativo: comporta inversa) -> Array[Rect2i]
	var rope_cells := {}  # Vector2i -> "|" ou "-"
	for r in gh:
		var line: String = rows[r]
		for c in gw:
			var ch: String = line[c] if c < line.length() else "#"
			var key := Vector2i(c, r)
			var cell := Rect2i(c * TILE, r * TILE, TILE, TILE)
			if ch == "#":
				tiles[r * gw + c] = 1
			elif ch == "^":
				_add_spike(c, r, 0)
			elif ch == ">":
				_add_spike(c, r, 1)
			elif ch == "v":
				_add_spike(c, r, 2)
			elif ch == "<":
				_add_spike(c, r, 3)
			elif ch == "+":
				batteries.append({"rect": cell, "taken": false, "fx": 0})
			elif ch == "~":
				water_tiles.append(key)
			elif ch == "%":
				water_tiles.append(key)
				fluid_acid = true
			elif ch == "o":
				drains.append({"rect": cell, "t": 0, "spin": 0.0})
			elif ch == "|" or ch == "-":
				rope_cells[key] = ch
			elif ch == "D":
				door_cells.append(key)
			elif ch == EXIT_FREE or ch == EXIT_LOCKED:
				var side := -1
				if r == 0:
					side = 0
				elif r == gh - 1:
					side = 2
				elif c == 0:
					side = 3
				elif c == gw - 1:
					side = 1
				if side < 0:
					tiles[r * gw + c] = 1   # saída fora da parede de fora: vira parede (a validação avisa)
				else:
					exit_cells.append([side, cell, ch == EXIT_LOCKED])
			elif ch >= "1" and ch <= "9":
				var gid := int(ch)
				if not gate_cells.has(gid):
					gate_cells[gid] = []
				gate_cells[gid].append(cell)
			elif INVERSE_GATES.contains(ch):
				var iid := -(INVERSE_GATES.find(ch) + 1)
				if not gate_cells.has(iid):
					gate_cells[iid] = []
				gate_cells[iid].append(cell)
			elif PLATFORM_CHARS.contains(ch):
				platforms.append({"rect": cell, "facing": PLATFORM_CHARS.find(ch), "solid": false, "fx": 0, "oneway": false})
			elif PASS_CHARS.contains(ch):
				platforms.append({"rect": cell, "facing": PASS_CHARS.find(ch), "solid": false, "fx": 0, "oneway": true})
			elif (ch == "P" or ch == "B" or ch == "S" or ch == "L" or ch == "H" or GATE_SOCKETS.contains(ch)) and not visited.has(key):
				for dy in 2:
					for dx in 2:
						visited[Vector2i(c + dx, r + dy)] = true
				var origin := Vector2i(c * TILE, r * TILE)
				if ch == "P":
					rabbit.pos = origin + Vector2i(2, 2)  # hitbox 12x12 centrada no bloco 16x16
				elif ch == "B":
					boxes.append(Box.new(origin))
				elif ch == "L":
					lever = {"rect": Rect2i(origin, Vector2i(16, 16)), "t": -1, "pulled": false}
				elif ch == "H":
					chute = {"rect": Rect2i(origin, Vector2i(16, 16)), "open": 0}
				else:
					sockets.append(Rect2i(origin, Vector2i(16, 16)))
					socket_group.append(0 if ch == "S" else GATE_SOCKETS.find(ch) + 1)
	if not door_cells.is_empty():
		var lo: Vector2i = door_cells[0]
		var hi: Vector2i = door_cells[0]
		for k in door_cells:
			lo = Vector2i(mini(lo.x, k.x), mini(lo.y, k.y))
			hi = Vector2i(maxi(hi.x, k.x), maxi(hi.y, k.y))
		door = Rect2i(lo * TILE, (hi - lo + Vector2i.ONE) * TILE)
		has_door = true
	for side in 4:
		var rect := Rect2i()
		var locked := false
		var any := false
		for ec in exit_cells:
			if ec[0] == side:
				rect = ec[1] if not any else rect.merge(ec[1])
				locked = locked or ec[2]
				any = true
		if any:
			exits.append({"side": side, "rect": rect, "locked": locked, "flooded": false})
	_parse_ropes(rows, rope_cells)
	var ids := gate_cells.keys()
	ids.sort()
	for gid in ids:
		var inv: bool = gid < 0
		gates.append({"id": absi(gid), "inverse": inv, "rects": gate_cells[gid], "closed": not inv, "anim": 0.0 if not inv else 1.0, "fx": 0})


## Cada sequência reta de "|" ou "-" é uma corda esticada. A ponta encostada numa parede é a
## âncora; o comprimento é o da sequência.
func _parse_ropes(rows: Array, cells: Dictionary) -> void:
	var keys := cells.keys()
	keys.sort_custom(func(a, b): return a.y < b.y if a.y != b.y else a.x < b.x)
	var seen := {}
	for k in keys:
		if seen.has(k):
			continue
		var vertical: bool = cells[k] == "|"
		var st: Vector2i = Vector2i(0, 1) if vertical else Vector2i(1, 0)
		var last: Vector2i = k
		while cells.get(last + st, "") == cells[k]:
			last += st
		var n: int = (last.y - k.y if vertical else last.x - k.x) + 1
		for i in n:
			seen[k + st * i] = true
		var start_wall := _char_at(rows, k - st) == "#"
		var end_wall := _char_at(rows, last + st) == "#"
		var rope := {"len": n * TILE, "anchor": Vector2.ZERO, "facing": 2}
		if vertical:
			if start_wall or not end_wall:
				rope["anchor"] = Vector2(k.x * TILE + 4, k.y * TILE)
				rope["facing"] = 2
			else:
				rope["anchor"] = Vector2(k.x * TILE + 4, (last.y + 1) * TILE)
				rope["facing"] = 0
		else:
			if start_wall or not end_wall:
				rope["anchor"] = Vector2(k.x * TILE, k.y * TILE + 4)
				rope["facing"] = 1
			else:
				rope["anchor"] = Vector2((last.x + 1) * TILE, k.y * TILE + 4)
				rope["facing"] = 3
		_rope_init(rope)
		ropes.append(rope)


func _char_at(rows: Array, k: Vector2i) -> String:
	if k.y < 0 or k.y >= rows.size():
		return "#"
	var line: String = rows[k.y]
	return line[k.x] if k.x >= 0 and k.x < line.length() else "#"


func _add_spike(c: int, r: int, facing: int) -> void:
	spikes.append({"rect": Rect2i(c * TILE, r * TILE, TILE, TILE), "facing": facing})


# ---------------------------------------------------------------- rotação

## Gira um retângulo junto com a sala (usa o tamanho atual, antes da troca de largura/altura).
func _rot_rect(r: Rect2i, dir: int) -> Rect2i:
	if dir > 0:  # horário: (x, y) -> (H - y, x)
		return Rect2i(ph - (r.position.y + r.size.y), r.position.x, r.size.y, r.size.x)
	# anti-horário: (x, y) -> (y, W - x)
	return Rect2i(r.position.y, pw - (r.position.x + r.size.x), r.size.y, r.size.x)


func _rot_point(p: Vector2, dir: int) -> Vector2:
	if dir > 0:
		return Vector2(ph - p.y, p.x)
	return Vector2(p.y, pw - p.x)


func _rotate_logic(dir: int) -> void:
	var nw := gh
	var nh := gw
	var nt := PackedByteArray()
	nt.resize(nw * nh)
	for r in gh:
		for c in gw:
			if tiles[r * gw + c] != 0:
				var nc: int
				var nr: int
				if dir > 0:
					nc = gh - 1 - r
					nr = c
				else:
					nc = r
					nr = gw - 1 - c
				nt[nr * nw + nc] = 1
	for b in boxes:
		b.pos = _rot_rect(b.rect, dir).position
		b.vel_y = 0.0
		b.rem_y = 0.0
		b.fall_dist = 0
		b.settled = false
	for i in sockets.size():
		sockets[i] = _rot_rect(sockets[i], dir)
	if has_door:
		door = _rot_rect(door, dir)
	for s in spikes:
		s["rect"] = _rot_rect(s["rect"], dir)
		s["facing"] = posmod(s["facing"] + dir, 4)
	for g in gates:
		var rs: Array = g["rects"]
		for i in rs.size():
			rs[i] = _rot_rect(rs[i], dir)
	for p in platforms:
		p["rect"] = _rot_rect(p["rect"], dir)
		p["facing"] = posmod(p["facing"] + dir, 4)
	for rp in ropes:
		rp["anchor"] = _rot_point(rp["anchor"], dir)
		rp["facing"] = posmod(rp["facing"] + dir, 4)
		# a corda gira na forma em que estava e, daí, cai com a nova gravidade
		var pts: PackedVector2Array = rp["pts"]
		var old: PackedVector2Array = rp["old"]
		for i in pts.size():
			pts[i] = _rot_point(pts[i], dir)
			old[i] = _rot_point(old[i], dir)
		rp["pts"] = pts
		rp["old"] = old
	for d in drains:
		d["rect"] = _rot_rect(d["rect"], dir)
	for b in batteries:
		b["rect"] = _rot_rect(b["rect"], dir)
	if lever != null:
		lever["rect"] = _rot_rect(lever["rect"], dir)
	if chute != null:
		chute["rect"] = _rot_rect(chute["rect"], dir)
	for m in movers:
		m["off"] = _rot_rect(m["off"], dir)
		m["on"] = _rot_rect(m["on"], dir)
		m["r"] = _rot_rect(m["r"], dir)
		m["pf"] = Vector2(m["r"].position)
		if m["spikes"] >= 0:
			m["spikes"] = posmod(m["spikes"] + dir, 4)
	for c in crumbles:
		c["rect"] = _rot_rect(c["rect"], dir)
	for p in plates:
		p["rect"] = _rot_rect(p["rect"], dir)
	for o in conveyors + springs + fans + vents:
		o["rect"] = _rot_rect(o["rect"], dir)
		o["dir"] = posmod(o["dir"] + dir, 4)
	belt_acc.clear()
	for ex in exits:
		ex["rect"] = _rot_rect(ex["rect"], dir)
	for an in anchors:
		an["rect"] = _rot_rect(an["rect"], dir)
		an["facing"] = posmod(an["facing"] + dir, 4)
	for c in crushers:
		c["lane"] = _rot_rect(c["lane"], dir)
		c["dir"] = posmod(c["dir"] + dir, 4)
		c["turn"] = posmod(c["turn"] + dir, 4)
	for a in actors:
		if a.has_method("on_rotate"):
			a.on_rotate(self, dir)
	var slivers := _water_slivers(dir)
	rabbit.pos = _rot_rect(rabbit.rect, dir).position
	rabbit.on_rotate()
	cam = _rot_point(cam, dir)
	_prev_cam = _rot_point(_prev_cam, dir)
	look = Vector2.ZERO   # depois do giro, a vista volta para o coelho
	for p in particles:
		p["pos"] = _rot_point(p["pos"], dir)
		p["vel"] = Vector2(-p["vel"].y, p["vel"].x) if dir > 0 else Vector2(p["vel"].y, -p["vel"].x)
	# só agora a sala troca de largura e altura
	tiles = nt
	gw = nw
	gh = nh
	pw = gw * TILE
	ph = gh * TILE
	orientation = posmod(orientation + dir, 4)
	_water_build()
	_water_deposit(slivers)
	bubbles.clear()   # os vãos de água são refeitos no giro
	if _fx_live:
		sway_frame = frame + ROT_FRAMES
		sway_dir = dir
		_ceiling_dust()


## Fração (0 a 1) do tempo que falta para o limitador desfazer o giro.
func limiter_ratio() -> float:
	return float(limit_t) / float(limiter_frames)


func _begin_rotate(dir: int, forced := false) -> void:
	if not forced and not rabbit.free_rotate():
		rabbit.air_rot = false
	if def.get("limiter", false):
		# a contagem começa no primeiro giro e não recomeça com os seguintes; voltar à orientação
		# de antes (à mão) a desliga
		if limit_net == 0:
			limit_t = limiter_frames
		limit_net += dir
		if posmod(limit_net, 4) == 0:
			limit_net = 0
			limit_t = 0
	_rotate_logic(dir)
	if not forced:
		_flip_fx(dir)
	rotating = true
	rot_frame = 0
	rot_len = ROT_FRAMES
	rot_from = -dir * PI / 2.0
	view_angle = rot_from
	rot_lock_max = reload_frames
	rot_lock = rot_lock_max


## O limitador desfaz tudo de uma vez: a sala volta à orientação de antes do primeiro giro, num giro
## só (de 90° ou 180°), com o laser do amortecedor e o som distorcido.
func _limiter_revert() -> void:
	var n := posmod(limit_net, 4)
	var d := -signi(limit_net)
	limit_net = 0
	limit_t = 0
	if n == 0:
		return
	var k := 1
	if n == 2:
		k = 2
	elif n == 1:
		d = -1
	else:
		d = 1
	for i in k:
		_rotate_logic(d)
	rotating = true
	rot_frame = 0
	rot_len = ROT_FRAMES if k == 1 else ROT_FRAMES * 3 / 2
	rot_from = -d * k * PI / 2.0
	view_angle = rot_from
	rot_lock_max = reload_frames
	rot_lock = rot_lock_max
	anchor_fx = 24
	sfx.emit("limiter")


## O coelho "faz" o giro: cambalhota encolhida e faíscas azuis saindo do corpo.
## Só no giro do jogador; o giro desfeito pelo limitador não tem.
func _flip_fx(dir: int) -> void:
	flip_t = FLIP_FRAMES
	flip_dir = dir
	# a batida de pata: um baque no chão, poeira e uma onda azul rente aos pés
	sfx.emit("thump")
	var feet := Vector2(rabbit.pos) + Vector2(6, 12)
	particles.append({"pos": feet, "vel": Vector2.ZERO, "life": 10, "col": C_FLIP, "grav": 0.0, "ring": 4.0})
	for i in 6:
		var sd := -1.0 if i % 2 == 0 else 1.0
		particles.append({"pos": feet + Vector2(sd * 2.0, 0), "vel": Vector2(sd * randf_range(25.0, 55.0), -randf_range(5.0, 20.0)),
			"life": randi_range(8, 12), "col": C_DUST, "grav": 60.0})
	if awaken_t >= 0 and not awakened:
		# o despertar: a primeira batida da vida dele
		awakened = true
		awaken_flash = 30
		shake = maxf(shake, 4.0)
		sfx.emit("charge")
		particles.append({"pos": feet, "vel": Vector2.ZERO, "life": 18, "col": C_FLIP, "grav": 0.0, "ring": 8.0})
		for i in 18:
			var a := TAU * i / 18.0
			particles.append({"pos": feet, "vel": Vector2(cos(a), sin(a)) * randf_range(60.0, 110.0),
				"life": randi_range(14, 22), "col": C_FLIP, "grav": 0.0})
	var c := Vector2(rabbit.pos) + Vector2(6, 6)
	particles.append({"pos": c, "vel": Vector2.ZERO, "life": 12, "col": C_FLIP, "grav": 0.0, "ring": 2.0})
	for i in 12:
		var a := TAU * (i + randf_range(-0.3, 0.3)) / 12.0
		var v := Vector2(cos(a), sin(a)) * randf_range(40.0, 75.0)
		particles.append({
			"pos": c + Vector2(cos(a), sin(a)) * 3.0, "vel": v,
			"life": randi_range(12, 20), "col": C_BOX if i % 3 == 0 else C_FLIP, "grav": 12.0,
		})


func _ease(t: float) -> float:
	if t < 0.5:
		return 4.0 * t * t * t
	return 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0


# ---------------------------------------------------------------- câmera

## Onde a câmera quer estar: centralizada no eixo em que a sala cabe na tela; no outro,
## seguindo o coelho, sem mostrar além das bordas da sala.
## O olhar arrastado (look) soma por cima disso, ainda dentro das bordas.
func _cam_target() -> Vector2:
	return _cam_clamp(_cam_follow() + look)


func _cam_follow() -> Vector2:
	if cam_focus != null:
		return _cam_clamp(cam_focus)
	return _cam_clamp(Vector2(rabbit.pos) + Vector2(6, 2))


func _cam_clamp(p: Vector2) -> Vector2:
	var t := Vector2.ZERO
	t.x = pw / 2.0 if pw <= VIEW.x else clampf(p.x, VIEW.x / 2.0, pw - VIEW.x / 2.0)
	t.y = ph / 2.0 if ph <= VIEW.y else clampf(p.y, VIEW.y / 2.0, ph - VIEW.y / 2.0)
	return t


func _update_camera() -> void:
	if looking:
		cam = _cam_target()   # arrastando: a sala acompanha o dedo, sem atraso
	else:
		look = look.lerp(Vector2.ZERO, LOOK_RETURN)
		if look.length() < 0.5:
			look = Vector2.ZERO
		cam = cam.lerp(_cam_target(), CAM_SMOOTH)


## Arrasta a vista `delta` px (sentido do dedo: arrastar para a esquerda mostra o que está à
## direita). Só tem efeito no eixo em que a sala é maior que a tela.
func pan(delta: Vector2) -> void:
	looking = true
	look -= delta
	_clamp_look()


func end_pan() -> void:
	looking = false


## Não deixa o olhar acumular além das bordas: ao soltar, a volta começa na hora.
func _clamp_look() -> void:
	var base := _cam_follow()
	look = _cam_clamp(base + look) - base


# ---------------------------------------------------------------- colisão

func overlaps(a: Rect2i, b: Rect2i) -> bool:
	return a.position.x < b.position.x + b.size.x \
		and a.position.x + a.size.x > b.position.x \
		and a.position.y < b.position.y + b.size.y \
		and a.position.y + a.size.y > b.position.y


func tile_solid_rect(r: Rect2i) -> bool:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.position.x + r.size.x - 1
	var y1 := r.position.y + r.size.y - 1
	if x0 < 0 or y0 < 0 or x1 >= pw or y1 >= ph:
		# fora da sala: só o coelho, e só pelo vão de uma saída aberta
		if not query_rabbit or not _in_exit_corridor(r):
			return true
		x0 = maxi(x0, 0)
		y0 = maxi(y0, 0)
		x1 = mini(x1, pw - 1)
		y1 = mini(y1, ph - 1)
		if x1 < x0 or y1 < y0:
			return false
	for ty in range(y0 >> 3, (y1 >> 3) + 1):
		for tx in range(x0 >> 3, (x1 >> 3) + 1):
			if tiles[ty * gw + tx] != 0:
				return true
	return false


# ---------------------------------------------------------------- saídas (modo mundo, D100)

## A saída deixa passar? Só com a sala de pé do jeito que foi desenhada (a saída no lado dela): o
## mapa liga as salas pelos lados desenhados, e girada ela levaria para o lugar errado.
func exit_open(ex: Dictionary) -> bool:
	if exit_cur_side(ex) != int(ex["side"]):
		return false
	return not ex["locked"] or (exits_unlocked and not ex["flooded"])


## Em que lado da sala de agora a saída está (0 cima, 1 direita, 2 baixo, 3 esquerda).
func exit_cur_side(ex: Dictionary) -> int:
	var er: Rect2i = ex["rect"]
	if er.position.y == 0:
		return 0
	if er.end.y == ph:
		return 2
	if er.position.x == 0:
		return 3
	return 1


## O vão por onde o coelho pode sair: a abertura, esticada para fora da sala (e um pouco para dentro).
func _exit_corridor(ex: Dictionary) -> Rect2i:
	var er: Rect2i = ex["rect"]
	match exit_cur_side(ex):
		0:
			return Rect2i(er.position.x, -EXIT_DEPTH, er.size.x, EXIT_DEPTH + 2 * TILE + 12)
		2:
			return Rect2i(er.position.x, ph - 2 * TILE - 12, er.size.x, EXIT_DEPTH + 2 * TILE + 12)
		3:
			return Rect2i(-EXIT_DEPTH, er.position.y, EXIT_DEPTH + 2 * TILE + 12, er.size.y)
	return Rect2i(pw - 2 * TILE - 12, er.position.y, EXIT_DEPTH + 2 * TILE + 12, er.size.y)


## O tile logo para dentro da sala, colado na abertura (para ver se a água a cobre).
func _exit_inner(ex: Dictionary) -> Rect2i:
	var er: Rect2i = ex["rect"]
	match exit_cur_side(ex):
		0:
			return Rect2i(er.position.x, er.end.y, er.size.x, TILE)
		2:
			return Rect2i(er.position.x, er.position.y - TILE, er.size.x, TILE)
		3:
			return Rect2i(er.end.x, er.position.y, TILE, er.size.y)
	return Rect2i(er.position.x - TILE, er.position.y, TILE, er.size.y)


func _in_exit_corridor(r: Rect2i) -> bool:
	for ex in exits:
		if exit_open(ex) and _exit_corridor(ex).encloses(r):
			return true
	return false


## Entrando pela saída `side` (como desenhada): o coelho aparece logo para dentro dela, já entrando.
func _place_at_entry(side: int, vel_in: Vector2) -> void:
	for ex in exits:
		if ex["side"] != side:
			continue
		var er: Rect2i = ex["rect"]
		var cx := er.position.x + er.size.x / 2 - 6
		var cy := er.position.y + er.size.y / 2 - 6
		var spd := clampf(vel_in.length(), 30.0, 90.0)
		match exit_cur_side(ex):
			3:
				rabbit.pos = Vector2i(er.end.x + 1, er.end.y - Rabbit.SIZE)
				rabbit.vel = Vector2(spd, 0)
				rabbit.facing = 1
			1:
				rabbit.pos = Vector2i(er.position.x - Rabbit.SIZE - 1, er.end.y - Rabbit.SIZE)
				rabbit.vel = Vector2(-spd, 0)
				rabbit.facing = -1
			0:
				rabbit.pos = Vector2i(cx, er.end.y + 1)
				rabbit.vel = Vector2(0, 40)
			2:
				# subindo pelo chão: um impulso para cima e para o lado, para não cair de volta no buraco
				var dirx := 1.0 if er.position.x < pw / 2 else -1.0
				rabbit.pos = Vector2i(cx, er.position.y - Rabbit.SIZE - 1)
				rabbit.vel = Vector2(dirx * 70.0, -190.0)
				rabbit.facing = int(dirx)
		return


## O coelho saiu da sala por uma saída? (o centro dele passou da borda)
func _check_exit() -> bool:
	if exits.is_empty():
		return false
	var rc := Vector2(rabbit.pos) + Vector2(6, 6)
	if rc.x >= 0.0 and rc.y >= 0.0 and rc.x <= pw and rc.y <= ph:
		return false
	var best: Dictionary = {}
	var bd := INF
	for ex in exits:
		var d := Rect2(ex["rect"]).get_center().distance_to(rc)
		if d < bd:
			bd = d
			best = ex
	state = "exit"
	exited.emit(int(best["side"]), rabbit.vel)
	return true


## As saídas na parede: aberta, um vão com batente dourado e uma seta pulsando para fora; trancada,
## a grade azul com um cadeado (coberta de água, azul-água).
func _draw_exits() -> void:
	for ex in exits:
		var er := Rect2(ex["rect"])
		var cs := exit_cur_side(ex)
		var open := exit_open(ex)
		var vertical := cs == 1 or cs == 3          # abertura numa parede do lado (vão em pé)
		var col := C_DOOR_OPEN if open else C_DOOR_LOCKED
		if ex["flooded"]:
			col = C_WATER_TOP
		var outward: Vector2 = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][cs]
		if open:
			draw_rect(er, Color(C_DOOR_OPEN, 0.10 + 0.05 * sin(frame * 0.1)))
			var k := float(frame % 40) / 40.0
			var c := er.get_center() + outward * (k * 6.0 - 3.0)
			var side_v := Vector2(-outward.y, outward.x)
			var ac := Color(C_DOOR_OPEN, 0.7 * sin(k * PI))
			draw_line(c - outward * 2.0 + side_v * 3.0, c + outward * 1.0, ac, 1.0)
			draw_line(c - outward * 2.0 - side_v * 3.0, c + outward * 1.0, ac, 1.0)
		else:
			draw_rect(er, C_DOOR_LOCKED_DARK if not ex["flooded"] else Color(C_WATER, 0.8))
			var n := int((er.size.y if vertical else er.size.x) / 3.0)
			for i in range(1, n):
				if vertical:
					draw_rect(Rect2(er.position.x, er.position.y + i * 3, er.size.x, 1), col)
				else:
					draw_rect(Rect2(er.position.x + i * 3, er.position.y, 1, er.size.y), col)
			var lc := er.get_center()
			draw_rect(Rect2(lc - Vector2(1.5, 0.5), Vector2(3, 3)), C_DOOR_OPEN if door_flash == 0 else Color.WHITE)
			draw_arc(lc + Vector2(0, -0.5), 1.5, PI, TAU, 6, C_DOOR_OPEN, 1.0)
		# batentes nas duas pontas da abertura
		if vertical:
			draw_rect(Rect2(er.position.x, er.position.y - 2, er.size.x, 2), col)
			draw_rect(Rect2(er.position.x, er.end.y, er.size.x, 2), col)
		else:
			draw_rect(Rect2(er.position.x - 2, er.position.y, 2, er.size.y), col)
			draw_rect(Rect2(er.end.x, er.position.y, 2, er.size.y), col)


## Paredes, comportas fechadas e plataformas sólidas. A porta nunca bloqueia ninguém.
func solid_static(r: Rect2i) -> bool:
	if tile_solid_rect(r):
		return true
	for ex in exits:
		if not exit_open(ex) and overlaps(r, ex["rect"]):
			return true
	for g in gates:
		if g["closed"]:
			for gr in g["rects"]:
				if overlaps(r, gr):
					return true
	for p in platforms:
		if _plat_blocks(p, r):
			return true
	for m in movers:
		if overlaps(r, m["r"]):
			return true
	for c in crumbles:
		if overlaps(r, c["rect"]):
			return true
	return false


func box_at(r: Rect2i, ignore):
	for b in boxes:
		if b != ignore and overlaps(r, b.rect):
			return b
	return null


## Há coelho ou caixa ocupando este retângulo? (comportas e plataformas nunca esmagam)
## A barra bloqueia este retângulo? A sólida, sempre que ativa. A de passagem só segura quem chega
## por cima: o retângulo pode encostar só na primeira linha dela (os pés vindo de cima, 1 px por vez).
## Subindo por baixo ou entrando de lado, o corpo já está dentro e passa.
func _plat_blocks(p: Dictionary, r: Rect2i, up := false) -> bool:
	if not p["solid"] or not overlaps(r, p["rect"]):
		return false
	if p["oneway"]:
		if up or query_up:
			return false   # subindo, sempre atravessa (inclusive o último pixel, o pé passando)
		return r.position.y + r.size.y - 1 <= p["rect"].position.y
	return true


func _occupied(r: Rect2i) -> bool:
	if rabbit != null and overlaps(r, rabbit.rect):
		return true
	return box_at(r, null) != null


func push_box(b, d: Vector2i) -> bool:
	var nxt := Rect2i(b.pos + d, Vector2i(Box.SIZE, Box.SIZE))
	if solid_static(nxt):
		return false
	var other = box_at(nxt, b)
	if other != null and not push_box(other, d):
		return false
	b.pos += d
	return true


# ---------------------------------------------------------------- simulação

func step(inp: Dictionary) -> void:
	frame += 1
	_update_particles()
	anchor_fx = maxi(anchor_fx - 1, 0)
	awaken_flash = maxi(awaken_flash - 1, 0)
	if awaken_t >= 0 and state == "play":
		awaken_t += 1
	flip_t = maxi(flip_t - 1, 0)
	door_flash = maxi(door_flash - 1, 0)
	if state == "won":
		timer -= 1
		# ondas de luz saindo da porta, uma depois da outra
		if timer == WIN_FRAMES - 8 or timer == WIN_FRAMES - 16:
			_door_ring()
		if timer <= 0:
			state = "done"
			completed.emit()
		return
	if state == "dead":
		timer -= 1
		if timer <= 0:
			reset()
		return
	if state != "play":
		return

	if input_lock:
		inp = {}
	rot_lock = maxi(rot_lock - 1, 0)
	if limit_t > 0:
		limit_t -= 1
		if limit_t == 0:
			if rotating:
				limit_t = 1   # espera a animação do giro acabar
			else:
				pending_rot = 0
				_limiter_revert()
				return
	var req: int = inp.get("rotate", 0)
	if req != 0 and rot_lock <= ROT_BUFFER:
		pending_rot = req
	if rotating:
		rot_frame += 1
		var t := float(rot_frame) / float(rot_len)
		if t >= 1.0:
			rotating = false
			view_angle = 0.0
		else:
			view_angle = rot_from * (1.0 - _ease(t))
			return
	if actor_rot != 0:
		# giro feito por um ator: não mexe na recarga nem no limitador do coelho, e fica
		var ad := actor_rot
		actor_rot = 0
		_rotate_logic(ad)
		rotating = true
		rot_frame = 0
		rot_len = ROT_FRAMES
		rot_from = -ad * PI / 2.0
		view_angle = rot_from
		sfx.emit("limiter")
		return
	if pending_rot != 0 and rot_lock == 0:
		var dir := pending_rot
		pending_rot = 0
		if has_spin:
			if rabbit.can_rotate():
				_begin_spin(dir)
		elif allow_rotate and rabbit.can_rotate():
			_begin_rotate(dir)
			return
	_update_spin()

	_update_mechanisms(false)
	_update_movers()
	if state != "play":
		return
	_update_fans()
	rabbit.update(self, inp)
	if state != "play":
		return
	if _check_exit():
		return
	if rabbit.ev_jump:
		_dust(3, 30.0)
		_jump_ring()
		sfx.emit("jump")
	if rabbit.ev_land:
		_dust(5, 45.0)
		sfx.emit("step_" + _surface())
	elif rabbit.on_ground and absf(rabbit.vel.x) > 15.0:
		var si := int(rabbit.anim / STEP_PX)
		if si != _step_idx:
			_step_idx = si
			sfx.emit("step_" + _surface())
	if rabbit.ev_grab:
		sfx.emit("rope")
		_rope_puff()
	if rabbit.ev_release:
		sfx.emit("jump")
	if rabbit.ev_splash > 0.0:
		sfx.emit("acid_splash" if fluid_acid else "splash")
		_splash(rabbit.ev_splash)
		_water_push(rabbit.pos.x, rabbit.pos.x + Rabbit.SIZE, rabbit.ev_splash * 0.02)
	elif rabbit.wet > 0.2 and absf(rabbit.vel.x) > 12.0 and frame % 5 == 0:
		# nadando: marolas
		_water_push(rabbit.pos.x + 1, rabbit.pos.x + 11, 0.12 if frame % 10 == 0 else -0.12)
	if rabbit.push_t > 0 and frame % 7 == 0:
		_push_dust()
	_update_ropes()
	_update_boxes()
	if state != "play":
		return
	_update_conveyors()
	_update_springs()
	_update_vents()
	_update_plates()
	_update_batteries()
	for a in actors:
		a.step(self)
	if state != "play":
		return
	_acid_bubbles()
	_update_crumbles()
	_update_crushers()
	_update_danger()
	_update_water()
	_update_sockets()
	_update_camera()
	if state != "play":
		return
	_check_hazards()
	if state != "play":
		return
	_check_win()


func _update_boxes() -> void:
	boxes.sort_custom(func(a, b): return a.pos.y > b.pos.y)
	for b in boxes:
		_box_step(b)
		if state != "play":
			return


func _box_supported(b) -> bool:
	# Só a faixa central da base apoia: a caixa "tomba" no buraco quando o centro passa da borda.
	var s := Rect2i(b.pos.x + 3, b.pos.y + Box.SIZE, Box.SIZE - 6, 1)
	return solid_static(s) or box_at(s, b) != null


func _box_blocked(b, r: Rect2i) -> bool:
	return solid_static(r) or box_at(r, b) != null


## Caixa que bate no chão: poeira, anel, detritos, som e um solavanco na direção da gravidade.
## A força cresce com a altura da queda e com quantas caixas pousaram há pouco.
func _box_impact(b, dist: int) -> void:
	var e := clampf(float(dist) / float(IMPACT_FULL_DIST), 0.0, 1.0)
	var s := minf(e + IMPACT_CHAIN * impact_recent, IMPACT_MAX)
	impact_recent = s
	var base_pos := Vector2(b.pos.x + Box.SIZE / 2.0, b.pos.y + Box.SIZE)
	# poeira: mais, mais rápida e mais alta quanto mais forte
	for i in 4 + int(8.0 * s):
		var dir := -1.0 if i % 2 == 0 else 1.0
		particles.append({
			"pos": base_pos + Vector2(dir * randf_range(2.0, 7.0), -1.0),
			"vel": Vector2(dir * randf_range(0.4, 1.0) * (30.0 + 40.0 * minf(s, 1.5)), -randf_range(6.0, 14.0 + 14.0 * s)),
			"life": randi_range(9, 14 + int(4.0 * s)), "col": C_DUST, "grav": 25.0,
		})
	particles.append({"pos": base_pos, "vel": Vector2.ZERO, "life": 10 + int(3.0 * s), "col": C_BOX, "grav": 0.0, "ring": 3.0})
	if s > 1.0:
		# impacto forte: segundo anel e lascas da caixa saltando
		particles.append({"pos": base_pos, "vel": Vector2.ZERO, "life": 14, "col": C_DUST, "grav": 0.0, "ring": 1.0})
		for i in 2 + int((s - 1.0) * 5.0):
			particles.append({
				"pos": base_pos + Vector2(randf_range(-6.0, 6.0), -2.0),
				"vel": Vector2(randf_range(-45.0, 45.0), -randf_range(50.0, 90.0)),
				"life": randi_range(12, 22), "col": C_BOX, "grav": 380.0,
			})
		shake = maxf(shake, 0.8 * (s - 1.0))
	jolt_amp = maxf(jolt_amp, 0.6 + 2.4 * s)
	jolt_phase = 0.0
	impact.emit(s)


func _box_step(b) -> void:
	# ventilador: no ar soprado para cima, a caixa sobe em vez de ficar parada ou cair
	var fan := box_fan_lift(b)
	if not fan.is_empty():
		b.settled = false
		b.vel_y = move_toward(b.vel_y, -float(fan["cap"]) * FAN_BOX_LIFT, float(fan["accel"]) * DT)
		b.rem_y += b.vel_y * DT
		var up := int(-b.rem_y)
		b.rem_y += up
		while up > 0:
			var nx := Rect2i(b.pos + Vector2i(0, -1), Vector2i(Box.SIZE, Box.SIZE))
			if _box_blocked(b, nx):
				b.vel_y = 0.0
				b.rem_y = 0.0
				break
			b.pos.y -= 1
			up -= 1
		b.fall_dist = 0
		return
	if _box_supported(b):
		if b.fall_dist >= IMPACT_MIN_DIST:
			_box_impact(b, b.fall_dist)
		b.fall_dist = 0
		b.vel_y = 0.0
		b.rem_y = 0.0
		b.settled = true
		return
	b.settled = false
	# na água a caixa continua afundando, mas devagar, e pousa sem estrondo
	var wet := water_frac(b.rect) >= BOX_WET
	if not wet:
		b.vel_y = minf(b.vel_y + BOX_GRAVITY * DT, BOX_MAX_FALL)
	elif b.vel_y > BOX_WATER_FALL:
		b.vel_y = maxf(b.vel_y * 0.8, BOX_WATER_FALL)
	else:
		b.vel_y = minf(b.vel_y + BOX_WATER_GRAVITY * DT, BOX_WATER_FALL)
	b.rem_y += b.vel_y * DT
	var steps := int(b.rem_y)
	b.rem_y -= steps
	while steps > 0:
		var nxt := Rect2i(b.pos + Vector2i(0, 1), Vector2i(Box.SIZE, Box.SIZE))
		if _box_blocked(b, nxt):
			if _box_nudge(b):
				continue
			b.vel_y = 0.0
			b.rem_y = 0.0
			break
		if overlaps(nxt, rabbit.rect):
			var rn := Rect2i(rabbit.pos + Vector2i(0, 1), Vector2i(Rabbit.SIZE, Rabbit.SIZE))
			if solid_static(rn) or box_at(rn, b) != null:
				kill()
				return
			rabbit.pos.y += 1
		b.pos.y += 1
		if not wet:
			b.fall_dist += 1
		steps -= 1


## Alinha a caixa com um buraco logo abaixo (até 4 px), para encaixar sem precisão de pixel.
func _box_nudge(b) -> bool:
	for k in range(1, 5):
		for sgn in [-1, 1]:
			var below := Rect2i(b.pos + Vector2i(sgn * k, 1), Vector2i(Box.SIZE, Box.SIZE))
			var side := Rect2i(b.pos + Vector2i(sgn, 0), Vector2i(Box.SIZE, Box.SIZE))
			if not _box_blocked(b, below) and not _box_blocked(b, side):
				b.pos.x += sgn
				return true
	return false


func _update_sockets() -> void:
	var old_n := socket_fx.size()
	socket_filled.resize(sockets.size())
	socket_fx.resize(sockets.size())
	for k in range(old_n, sockets.size()):
		socket_fx[k] = 0
		socket_filled[k] = false
	for i in sockets.size():
		var s: Rect2i = sockets[i]
		var f := false
		for b in boxes:
			if b.settled and absi(b.pos.x - s.position.x) <= 3 and absi(b.pos.y - s.position.y) <= 3:
				f = true
		var was: bool = socket_filled[i] == true
		if f != was and state == "play":
			socket_fx[i] = SENSOR_FRAMES
			sfx.emit("sensor_on" if f else "sensor_off")
		socket_filled[i] = f
	# Água na porta a bloqueia; ela só destrava depois de um tempo seca. Sem essa espera, bastava
	# ficar dentro da porta e girar a sala: a água cai, a porta abre e o coelho ainda está lá.
	if has_door and water_frac(door) >= DOOR_FLOOD:
		door_dry = 0
	else:
		door_dry = mini(door_dry + 1, DOOR_DRY_FRAMES)
	door_flooded = door_dry < DOOR_DRY_FRAMES
	var open: bool = (group_filled(0) or def.get("door_open", false) or door_unlocked) and not door_flooded
	if open != door_open:
		door_open = open
		door_flash = 14
	if not exits.is_empty():
		if not exits_unlocked and (group_filled(0) or def.get("door_open", false)):
			exits_unlocked = true
			door_flash = 14
			if state == "play":
				sfx.emit("gate_open")
		for ex in exits:
			# água encostada na saída trancada a mantém fechada ("com água, a porta se fecha")
			ex["flooded"] = ex["locked"] and water_frac(_exit_inner(ex)) >= DOOR_FLOOD


## Todos os compartimentos do grupo têm caixa? (grupo 0 = porta; sem compartimentos = não)
func group_filled(group: int) -> bool:
	var any := false
	for i in sockets.size():
		if socket_group[i] == group:
			any = true
			if not socket_filled[i]:
				return false
	return any


## Comportas e plataformas mudam de estado; nenhuma fica sólida em cima de alguém.
func _update_mechanisms(instant: bool) -> void:
	var gate_sfx: Array = []   # sons das comportas que mudaram (a comum e a inversa podem mudar juntas)
	for g in gates:
		var filled := group_filled(g["id"])
		var want_closed: bool = filled if g.get("inverse", false) else not filled
		if want_closed != g["closed"]:
			var can := true
			if want_closed:
				for gr in g["rects"]:
					if _occupied(gr):
						can = false
						break
			if can:
				water_dirty = true
				g["closed"] = want_closed
				g["fx"] = SWITCH_FRAMES
				var snd := "gate_close" if want_closed else "gate_open"
				if not gate_sfx.has(snd):
					gate_sfx.append(snd)
		var target := 0.0 if g["closed"] else 1.0
		g["anim"] = target if instant else move_toward(g["anim"], target, 0.12)
		g["fx"] = maxi(g["fx"] - 1, 0)
	var plat_changed := false
	for p in platforms:
		var want: bool = p["facing"] == 0
		if want != p["solid"]:
			if not want or not _occupied(p["rect"]):
				p["solid"] = want
				water_dirty = true
				p["fx"] = SWITCH_FRAMES
				plat_changed = true
		p["fx"] = maxi(p["fx"] - 1, 0)
	if instant:
		for g in gates:
			g["fx"] = 0
		for p in platforms:
			p["fx"] = 0
		return
	for snd in gate_sfx:
		sfx.emit(snd)
	if plat_changed:
		sfx.emit("platform")


# ---------------------------------------------------------------- corda

## A corda presa no teto que passa por este retângulo, ou null. Vale a forma real da corda:
## logo depois de um giro ela ainda está balançando.
func rope_at(r: Rect2i):
	# alcance generoso (D95): 3 px de folga em volta do coelho e os trechos entre os pontos da corda
	var box := Rect2(r).grow(3.0)
	for rp in ropes:
		if rp["facing"] != 2:
			continue
		var pts: PackedVector2Array = rp["pts"]
		for i in range(1, pts.size()):
			if box.has_point(pts[i]) or box.has_point((pts[i] + pts[i - 1]) * 0.5):
				return rp
	return null


func _rope_init(rp: Dictionary) -> void:
	var dirv: Vector2 = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT][rp["facing"]]
	var pts := PackedVector2Array()
	for i in int(rp["len"] / ROPE_SEG) + 1:
		pts.append(rp["anchor"] + dirv * (i * ROPE_SEG))
	rp["pts"] = pts
	rp["old"] = pts.duplicate()


func _pt_solid(p: Vector2) -> bool:
	return solid_static(Rect2i(int(floorf(p.x)), int(floorf(p.y)), 1, 1))


## Física da corda (Verlet): cada ponto cai com a gravidade, as distâncias entre vizinhos são
## mantidas, e os pontos não entram nas paredes. A âncora é fixa; se o coelho está pendurado,
## o ponto que ele segura acompanha a mão dele, e a sobra balança solta.
func _update_ropes() -> void:
	for rp in ropes:
		var pts: PackedVector2Array = rp["pts"]
		var old: PackedVector2Array = rp["old"]
		var n := pts.size()
		var hold := -1
		var hand := Vector2.ZERO
		if rabbit != null and rabbit.rope == rp:
			hold = clampi(roundi(rabbit.rope_r / ROPE_SEG), 1, n - 1)
			hand = Vector2(rabbit.pos) + Vector2(6, 6)
		for i in range(1, n):
			var v := (pts[i] - old[i]) * ROPE_AIR
			old[i] = pts[i]
			# um sopro mínimo de lado: sem ele, uma corda apontando reta para cima ficaria em pé
			pts[i] += v + Vector2(0.004 * sin(i * 1.7 + frame * 0.05), BOX_GRAVITY * DT * DT)
		for it in ROPE_ITERS:
			pts[0] = rp["anchor"]
			if hold > 0:
				pts[hold] = hand
			for i in n - 1:
				var d := pts[i + 1] - pts[i]
				var dist := d.length()
				if dist < 0.0001:
					continue
				var corr := d * (1.0 - ROPE_SEG / dist)
				var pin_a := i == 0 or i == hold
				var pin_b := i + 1 == hold
				if pin_a and pin_b:
					continue
				if pin_a:
					pts[i + 1] -= corr
				elif pin_b:
					pts[i] += corr
				else:
					pts[i] += corr * 0.5
					pts[i + 1] -= corr * 0.5
		for i in range(1, n):
			if i == hold:
				continue
			var p := pts[i]
			if _pt_solid(p):
				var o := old[i]
				if not _pt_solid(Vector2(p.x, o.y)):
					# apoiou em cima ou embaixo de algo: para na vertical e arrasta na horizontal
					pts[i] = Vector2(lerpf(p.x, o.x, 0.4), o.y)
				elif not _pt_solid(Vector2(o.x, p.y)):
					pts[i] = Vector2(o.x, p.y)
				else:
					pts[i] = o
		rp["pts"] = pts
		rp["old"] = old


func _rope_puff() -> void:
	var c := Vector2(rabbit.pos) + Vector2(6, 2)
	for i in 5:
		particles.append({
			"pos": c + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)),
			"vel": Vector2(randf_range(-30.0, 30.0), randf_range(-25.0, 5.0)),
			"life": randi_range(8, 14), "col": C_ROPE, "grav": 60.0,
		})


# ---------------------------------------------------------------- água

## Fração (0 a 1) de um retângulo que está dentro da água.
func water_frac(r: Rect2i) -> float:
	if water_vol <= 0.0:
		return 0.0
	var x0 := maxi(r.position.x, 0)
	var x1 := mini(r.position.x + r.size.x, pw)
	var y0 := float(r.position.y)
	var y1 := float(r.position.y + r.size.y)
	var area := 0.0
	for x in range(x0, x1):
		for k in range(wcol[x], wcol[x + 1]):
			var h := wt_h[k]
			if h <= 0.0:
				continue
			var b := wt_bot[k] - wt_air[k]
			var lo := maxf(b - h, y0)
			var hi := minf(b, y1)
			if hi > lo:
				area += hi - lo
	return area / float(r.size.x * r.size.y)


func _tile_blocked(c: int, r: int) -> bool:
	if tiles[r * gw + c] != 0:
		return true
	var cell := Rect2i(c * TILE, r * TILE, TILE, TILE)
	for g in gates:
		if g["closed"] and g["rects"].has(cell):
			return true
	for p in platforms:
		if p["solid"] and p["rect"] == cell:
			return true
	return false


## Monta os vãos de cada coluna e os canos entre vãos vizinhos. Começa sem água.
func _water_build() -> void:
	water_dirty = false
	wt_x = PackedInt32Array()
	wt_top = PackedInt32Array()
	wt_bot = PackedInt32Array()
	wcol = PackedInt32Array()
	wcol.resize(pw + 1)
	for c in gw:
		# trechos livres desta coluna de tiles, iguais para as 8 colunas de pixels dela
		var segs: Array = []
		var start := -1
		for r in gh + 1:
			var blocked := r == gh or _tile_blocked(c, r)
			if not blocked and start < 0:
				start = r
			elif blocked and start >= 0:
				segs.append(Vector2i(start * TILE, r * TILE))
				start = -1
		for dx in TILE:
			wcol[c * TILE + dx] = wt_x.size()
			for sg in segs:
				wt_x.append(c * TILE + dx)
				wt_top.append(sg.x)
				wt_bot.append(sg.y)
	var n := wt_x.size()
	wcol[pw] = n
	wt_h = PackedFloat64Array()
	wt_h.resize(n)
	wt_air = PackedFloat64Array()
	wt_air.resize(n)
	wt_vy = PackedFloat64Array()
	wt_vy.resize(n)
	wt_o = PackedFloat64Array()
	wt_o.resize(n)
	wt_v = PackedFloat64Array()
	wt_v.resize(n)
	ripples = false
	# ligações entre colunas vizinhas: [a, b, soleira, teto da passagem]
	var level: Array = []
	for x in pw - 1:
		for a in range(wcol[x], wcol[x + 1]):
			for b in range(wcol[x + 1], wcol[x + 2]):
				var roof := maxi(wt_top[a], wt_top[b])
				var sill := mini(wt_bot[a], wt_bot[b])
				if roof < sill:
					level.append([a, b, sill, roof])
	we_a = PackedInt32Array()
	we_b = PackedInt32Array()
	we_sill = PackedInt32Array()
	we_nu = PackedFloat64Array()
	we_near = level.size()
	var reach := 1
	while true:
		var stride := maxi(reach / 2, 1)
		for ed in level:
			if wt_x[ed[0]] % stride == 0:
				we_a.append(ed[0])
				we_b.append(ed[1])
				we_sill.append(ed[2])
				we_nu.append(WATER_NU if reach == 1 else WATER_NU_FAR)
		if reach >= WATER_REACH[WATER_REACH.size() - 1]:
			break
		# o dobro da distância: emenda duas ligações que passam pelo mesmo vão do meio
		var from := {}
		for ed in level:
			if not from.has(ed[0]):
				from[ed[0]] = []
			from[ed[0]].append(ed)
		var longer: Array = []
		for e1 in level:
			for e2 in from.get(e1[1], []):
				var roof := maxi(e1[3], e2[3])
				var sill := mini(e1[2], e2[2])
				if roof < sill:
					longer.append([e1[0], e2[1], sill, roof])
		level = longer
		reach *= 2
	we_fall = PackedFloat64Array()
	we_fall.resize(we_a.size())
	water_calm = false
	water_still = 0


## O vão da coluna x que contém a linha y, ou -1.
func _tank_at(x: int, y: int) -> int:
	if x < 0 or x >= pw:
		return -1
	for k in range(wcol[x], wcol[x + 1]):
		if y >= wt_top[k] and y < wt_bot[k]:
			return k
	return -1


## Comporta ou plataforma mudou: refaz os vãos e recoloca a água no vão onde ela estava.
func _water_rebuild_keep() -> void:
	var keep: Array = []
	for k in wt_x.size():
		if wt_h[k] > 0.0:
			keep.append([wt_x[k], wt_bot[k] - wt_air[k], wt_h[k]])
	_water_build()
	water_vol = 0.0
	for w in keep:
		var k := _tank_at(w[0], int(ceilf(w[1])) - 1)
		if k < 0:
			continue
		var room_left := float(wt_bot[k] - wt_top[k]) - wt_h[k]
		var add := minf(w[2], room_left)
		wt_air[k] = maxf(wt_bot[k] - w[1], 0.0) if wt_h[k] <= 0.0 else wt_air[k]
		wt_h[k] += add
		water_vol += add


## Antes do giro: a água como faixas horizontais já giradas: [linha, x inicial, x final].
func _water_slivers(dir: int) -> Array:
	var out: Array = []
	for k in wt_x.size():
		var h := wt_h[k]
		if h <= 0.0:
			continue
		var y1 := wt_bot[k] - wt_air[k]
		var y0 := y1 - h
		if dir > 0:
			out.append([wt_x[k], ph - y1, ph - y0])
		else:
			out.append([pw - 1 - wt_x[k], y0, y1])
	return out


## Depois do giro: distribui as faixas pelas colunas novas. Em cada vão a água fica onde
## estava; se não há nada embaixo dela, vai cair (wt_air > 0).
func _water_deposit(slivers: Array) -> void:
	water_vol = 0.0
	var low := {}  # vão -> linha de água mais baixa
	for sl in slivers:
		var row: int = sl[0]
		var xa: float = sl[1]
		var xb: float = sl[2]
		for cx in range(int(floorf(xa)), int(ceilf(xb))):
			var cov := minf(xb, cx + 1.0) - maxf(xa, float(cx))
			var k := _tank_at(cx, row)
			if k < 0 or cov <= 0.0:
				continue
			wt_h[k] += cov
			if cov >= 0.5:
				low[k] = maxi(low.get(k, -1), row)
	for k in wt_x.size():
		if wt_h[k] <= 0.0:
			continue
		if low.has(k):
			wt_air[k] = float(wt_bot[k] - 1 - low[k])
		wt_h[k] = minf(wt_h[k], float(wt_bot[k] - wt_top[k]) - wt_air[k])
		water_vol += wt_h[k]
	water_calm = false
	water_still = 0


## Um quadro da água. Blocos soltos caem; depois, cada ligação iguala uma parcela do desnível
## entre os dois vãos (só passa a água que está acima da soleira). É estável por construção:
## cada troca só aproxima os dois níveis. Devolve a maior troca do quadro.
func _water_sim() -> float:
	var n := wt_x.size()
	var falling := false
	for k in n:
		if wt_air[k] > 0.0:
			if wt_h[k] <= 0.0:
				wt_air[k] = 0.0
				continue
			wt_vy[k] = minf(wt_vy[k] + WATER_FALL_G * DT, WATER_MAX_FALL)
			wt_air[k] -= wt_vy[k] * DT
			if wt_air[k] <= 0.0:
				wt_air[k] = 0.0
				wt_v[k] += wt_vy[k] * 0.02  # o bloco bate no fundo: onda
				wt_vy[k] = 0.0
				ripples = true
			else:
				falling = true
	var ne := we_a.size()
	var peak := 0.0
	for e in ne:
		we_fall[e] *= 0.8
	for s in WATER_SUBSTEPS:
		for i in ne:
			var e := i if (s + frame) % 2 == 0 else ne - 1 - i
			var a := we_a[e]
			var b := we_b[e]
			var ha := wt_h[a]
			var hb := wt_h[b]
			if ha <= 0.0 and hb <= 0.0:
				continue
			if wt_air[a] > 0.0 or wt_air[b] > 0.0:
				continue
			var sill := float(we_sill[e])
			var sa := wt_bot[a] - ha
			var sb := wt_bot[b] - hb
			var drive := minf(sb, sill) - minf(sa, sill)
			if drive == 0.0:
				continue
			var q := we_nu[e] * drive
			if q > 0.0:
				q = minf(q, float(wt_bot[b] - wt_top[b]) - hb)
				if e < we_near and sb > sill + 1.0:
					we_fall[e] = maxf(we_fall[e], q)
			else:
				q = -minf(-q, float(wt_bot[a] - wt_top[a]) - ha)
				if e < we_near and sa > sill + 1.0:
					we_fall[e] = minf(we_fall[e], q)
			wt_h[a] = ha - q
			wt_h[b] = hb + q
			var aq := absf(q)
			if aq > peak:
				peak = aq
			if e < we_near and aq > 0.25:
				# água correndo: agita a superfície, em ondulações largas (não coluna a coluna)
				var jit := minf(aq, 2.0) * 0.03 * sin(frame * 0.35 + wt_x[a] * 0.3)
				wt_v[a] += jit
				wt_v[b] += jit
				ripples = true
	return INF if falling else peak


## Ondas da superfície: cada coluna é uma mola presa ao nível da água e puxada pelas vizinhas.
## Não mexem no volume nem na física; só no desenho.
func _ripple_sim() -> void:
	var live := false
	for e in we_near:
		var a := we_a[e]
		var b := we_b[e]
		if wt_h[a] < 1.0 or wt_h[b] < 1.0:
			continue
		if absf((wt_bot[a] - wt_h[a]) - (wt_bot[b] - wt_h[b])) > 3.0:
			continue  # não é a mesma superfície (degrau, cascata)
		var d := (wt_o[b] - wt_o[a]) * RIPPLE_SPREAD
		wt_v[a] += d
		wt_v[b] -= d
	for k in wt_x.size():
		var o := wt_o[k]
		var v := wt_v[k]
		if o == 0.0 and v == 0.0:
			continue
		v = (v - RIPPLE_TENSION * o) * RIPPLE_DAMP
		o = clampf(o + v, -RIPPLE_MAX, minf(RIPPLE_MAX, wt_h[k]))
		if wt_h[k] < 1.0 or (absf(o) < 0.02 and absf(v) < 0.02):
			o = 0.0
			v = 0.0
		else:
			live = true
		wt_o[k] = o
		wt_v[k] = v
	ripples = live


func _update_water() -> void:
	if wt_x.is_empty() or (water_vol <= 0.0 and not water_dirty):
		return
	if water_dirty:
		_water_rebuild_keep()
	if not water_calm:
		var peak := _water_sim()
		if peak < WATER_CALM_Q * 6.0:
			_water_dry_films()
		water_still = water_still + 1 if peak < WATER_CALM_Q else 0
		if water_still >= WATER_CALM_FRAMES:
			water_calm = true
			for e in we_fall.size():
				we_fall[e] = 0.0
	if ripples:
		_ripple_sim()
	for d in drains:
		_drain_step(d)


## Lâminas finas demais para ver secam, em vez de ficarem escorrendo para sempre.
func _water_dry_films() -> void:
	for k in wt_x.size():
		var h := wt_h[k]
		if h > 0.0 and h < WATER_FILM and wt_air[k] <= 0.0:
			var take := minf(h, 0.02)
			wt_h[k] -= take
			water_vol -= take


## O ralo engole, aos poucos, a água que encosta nele.
func _drain_step(d: Dictionary) -> void:
	var r: Rect2i = d["rect"]
	var took := 0.0
	for x in range(r.position.x, r.position.x + r.size.x):
		var k := _tank_at(x, r.position.y + r.size.y - 1)
		if k < 0 or wt_h[k] <= 0.0 or wt_air[k] > 0.0:
			continue
		if wt_bot[k] - wt_h[k] >= r.position.y + r.size.y:
			continue  # a água desta coluna está abaixo do ralo
		var take := minf(wt_h[k], DRAIN_RATE)
		wt_h[k] -= take
		took += take
	if took <= 0.0:
		return
	water_vol = maxf(water_vol - took, 0.0)
	water_calm = false
	water_still = 0
	d["spin"] += 0.35
	if frame % 6 == 0:
		var c := Vector2(r.position) + Vector2(4, 4)
		particles.append({
			"pos": c + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)),
			"vel": Vector2(randf_range(-12.0, 12.0), -randf_range(10.0, 30.0)),
			"life": randi_range(8, 14), "col": C_WATER_TOP, "grav": 0.0,
		})


## Ao carregar a sala: deixa a água escorrer até parar, para nada se mexer sozinho no início.
func _settle_water() -> void:
	if water_dirty:
		_water_rebuild_keep()
	if water_vol <= 0.0:
		return
	water_calm = false
	water_still = 0
	for i in WATER_SETTLE:
		var peak := _water_sim()
		water_still = water_still + 1 if peak < WATER_CALM_Q else 0
		if water_still >= WATER_CALM_FRAMES:
			break
	water_calm = true
	for e in we_fall.size():
		we_fall[e] = 0.0
	for k in wt_o.size():
		wt_o[k] = 0.0
		wt_v[k] = 0.0
	ripples = false


## Algo caiu na água entre as colunas x0 e x1: afunda a superfície ali e a onda se espalha.
func _water_push(x0: int, x1: int, strength: float) -> void:
	for x in range(maxi(x0, 0), mini(x1, pw)):
		for k in range(wcol[x], wcol[x + 1]):
			if wt_h[k] >= 1.0:
				wt_v[k] += strength
				ripples = true


# ---------------------------------------------------------------- baterias, alavanca e calha

func lever_ready() -> bool:
	return lever != null and chute != null and not batteries.is_empty() and bat_got >= batteries.size()


func _update_batteries() -> void:
	for b in batteries:
		if b["fx"] > 0:
			b["fx"] -= 1
		if not b["taken"] and overlaps(rabbit.rect, Rect2i(b["rect"]).grow(BAT_PICK)):
			b["taken"] = true
			b["fx"] = 16
			bat_got += 1
			sfx.emit("battery")
			var c := Vector2(b["rect"].position) + Vector2(4, 4)
			particles.append({"pos": c, "vel": Vector2.ZERO, "life": 12, "col": C_BAT, "grav": 0.0, "ring": 3.0})
			for i in 8:
				var a := TAU * i / 8.0
				particles.append({"pos": c, "vel": Vector2(cos(a), sin(a)) * randf_range(30.0, 70.0), "life": randi_range(10, 18), "col": C_BAT, "grav": 60.0})
			if lever_ready() and lever["t"] < 0:
				_lever_fire()
	if lever != null and lever["t"] >= 0:
		_update_lever()


## Todas as baterias: a câmera vai até a alavanca, ela se puxa sozinha, e a câmera segue a caixa
## saindo da calha. A entrada fica travada durante a cena.
func _lever_fire() -> void:
	lever["t"] = 0
	input_lock = true
	sfx.emit("charge")


func _update_lever() -> void:
	var t: int = lever["t"]
	var total := LEVER_PAN + LEVER_PULL + LEVER_WATCH
	if t >= total:
		return
	var lc := Vector2(lever["rect"].position) + Vector2(8, 8)
	var cc := Vector2(chute["rect"].position) + Vector2(8, 12)
	cam_focus = lc if t < LEVER_PAN + LEVER_PULL else cc
	if t == LEVER_PAN + LEVER_HIT:
		lever["pulled"] = true
		sfx.emit("lever")
		shake = maxf(shake, 1.5)
		for i in 6:
			particles.append({"pos": lc + Vector2(4, -2), "vel": Vector2(randf_range(-50.0, 50.0), randf_range(-70.0, -10.0)), "life": randi_range(8, 16), "col": C_BAT, "grav": 260.0})
	if t == LEVER_PAN + LEVER_PULL:
		chute["open"] = 1
		sfx.emit("hatch")
		shake = maxf(shake, 1.0)
		boxes.append(Box.new(chute["rect"].position))
		for i in 8:
			particles.append({"pos": cc + Vector2(randf_range(-6.0, 6.0), 0), "vel": Vector2(randf_range(-20.0, 20.0), randf_range(10.0, 40.0)), "life": randi_range(10, 18), "col": C_DUST, "grav": 120.0})
	if chute["open"] > 0:
		chute["open"] += 1
	lever["t"] = t + 1
	if t + 1 >= total:
		input_lock = false
		cam_focus = null


func _draw_batteries() -> void:
	for b in batteries:
		var r: Rect2i = b["rect"]
		if (Vector2(r.position) - cam).length() > VIEW.length() / 2.0 + 24.0:
			continue
		var p := Vector2(r.position)
		if b["taken"]:
			continue
		var bob := roundf(sin(frame * 0.1 + float(r.position.x) * 0.3) * 1.2)
		var pulse := 0.5 + 0.5 * sin(frame * 0.12 + float(r.position.y))
		draw_circle(p + Vector2(4, 4 + bob), 5.5 + pulse, Color(C_BAT, 0.10 + 0.08 * pulse))
		p.y += bob
		draw_rect(Rect2(p + Vector2(1, 1), Vector2(6, 7)), C_SEAM)
		draw_rect(Rect2(p + Vector2(2, 2), Vector2(4, 5)), C_BAT)
		draw_rect(Rect2(p + Vector2(2, 5), Vector2(4, 2)), C_BAT_DARK)
		draw_rect(Rect2(p + Vector2(3, 0), Vector2(2, 1)), C_RIVET)
		draw_rect(Rect2(p + Vector2(2, 2), Vector2(1, 2)), Color(1, 1, 1, 0.7))


func _draw_lever_and_chute() -> void:
	if chute != null:
		_draw_chute()
	if lever != null:
		_draw_lever()
		# o raio da alavanca para a calha, no momento em que ela vira
		var t: int = lever["t"]
		var t0 := LEVER_PAN + LEVER_HIT
		if t >= t0 and t < t0 + 26 and chute != null:
			var a := 1.0 - float(t - t0) / 26.0
			var from := Vector2(lever["rect"].position) + Vector2(8, 8)
			var to := Vector2(chute["rect"].position) + Vector2(8, 8)
			var pts := PackedVector2Array([from])
			var nrm := (to - from).orthogonal().normalized()
			for k in range(1, 7):
				pts.append(from.lerp(to, float(k) / 7.0) + nrm * sin(float(frame * 3 + k * 7)) * 4.0)
			pts.append(to)
			draw_polyline(pts, Color(C_BAT, a), 1.0)


func _draw_lever() -> void:
	var r := Rect2(lever["rect"])
	var n := batteries.size()
	draw_rect(r, C_SEAM)
	draw_rect(r.grow(-1.0), C_STEEL[1])
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(14, 1)), C_STEEL_LIGHT)
	var ready: bool = lever_ready() and not lever["pulled"]
	# as vagas das baterias, no alto: acesas conforme se pega
	var w := 14.0 / maxf(n, 1.0)
	for i in n:
		var lit := i < bat_got
		var sx := r.position.x + 1.0 + i * w
		draw_rect(Rect2(sx + 1, r.position.y + 3, w - 2, 3), C_BAT if lit else C_SEAM)
		if lit:
			draw_rect(Rect2(sx + 1, r.position.y + 3, w - 2, 1), Color(1, 1, 1, 0.5))
	# o trilho (com batentes claros nas pontas) e o cabo
	draw_rect(Rect2(r.position.x + 6, r.position.y + 6, 4, 9), C_SEAM)
	draw_rect(Rect2(r.position.x + 6, r.position.y + 6, 4, 1), C_STEEL_LIGHT)
	draw_rect(Rect2(r.position.x + 6, r.position.y + 14, 4, 1), C_STEEL_LIGHT)
	draw_rect(Rect2(r.position.x + 7, r.position.y + 7, 2, 7), Color(0, 0, 0, 0.8))
	var pulled: bool = lever["pulled"]
	var k := 0.0
	if lever["t"] >= LEVER_PAN + LEVER_HIT - 6 or pulled:
		k = clampf(float(lever["t"] - (LEVER_PAN + LEVER_HIT - 6)) / 12.0, 0.0, 1.0) if not pulled else 1.0
	var hy := r.position.y + lerpf(8.5, 12.0, k)
	draw_line(Vector2(r.position.x + 8, r.position.y + 8), Vector2(r.position.x + 8, hy), C_RIVET, 1.0)
	draw_circle(Vector2(r.position.x + 8, hy), 2.4, C_KNOB_LEVER)
	draw_rect(Rect2(r.position.x + 7, hy - 1.5, 1, 1), Color(1, 1, 1, 0.7))
	for q in [Vector2(1, 14), Vector2(14, 14)]:
		draw_rect(Rect2(r.position + q, Vector2(1, 1)), C_RIVET)
	if ready:
		var pulse := 0.4 + 0.4 * sin(frame * 0.3)
		draw_rect(r.grow(1.0), Color(C_BAT, pulse), false, 1.0)


func _draw_chute() -> void:
	var r := Rect2(chute["rect"])
	var open: int = chute["open"]
	# caixa guardada, só a silhueta, até a calha abrir
	if open == 0:
		draw_rect(Rect2(r.position + Vector2(3, 2), Vector2(10, 9)), Color(C_BOX, 0.28))
		draw_rect(Rect2(r.position + Vector2(3, 2), Vector2(10, 9)), Color(C_BOX, 0.5), false, 1.0)
	# funil de aço
	var funnel := PackedVector2Array([r.position, r.position + Vector2(16, 0), r.position + Vector2(13, 11), r.position + Vector2(3, 11)])
	draw_polyline(PackedVector2Array([funnel[0], funnel[3], funnel[2], funnel[1]]), C_STEEL_LIGHT, 1.5)
	draw_rect(Rect2(r.position + Vector2(0, 0), Vector2(16, 2)), C_STEEL[1])
	draw_rect(Rect2(r.position + Vector2(0, 0), Vector2(16, 1)), C_STEEL_LIGHT)
	# portinholas no fundo: fechadas (duas abas) ou abertas (caídas para os lados)
	var k := clampf(float(open) / 8.0, 0.0, 1.0)
	var y := r.position.y + 11.0
	var col := C_RUST if open == 0 else C_STEEL[2]
	draw_line(Vector2(r.position.x + 3, y), Vector2(r.position.x + 8 - 5 * k, y + 4 * k + 1), col, 2.0)
	draw_line(Vector2(r.position.x + 13, y), Vector2(r.position.x + 8 + 5 * k, y + 4 * k + 1), col, 2.0)
	if open == 0:
		draw_rect(Rect2(r.position.x + 7, y - 1, 2, 3), C_BAT_DARK)


## Marcador das baterias no alto da tela: um quadradinho por bateria da sala, aceso quando pega.
func _draw_battery_hud() -> void:
	var n := batteries.size()
	if n == 0 or state == "won" or state == "done":
		return
	draw_set_transform_matrix(Transform2D())
	var x0 := -float(n) * 7.0 / 2.0
	for i in n:
		var lit := i < bat_got
		var q := Vector2(x0 + i * 7.0, -VIEW.y / 2.0 + 5.0)
		draw_rect(Rect2(q - Vector2(1, 1), Vector2(6, 9)), Color(C_SEAM, 0.7))
		draw_rect(Rect2(q, Vector2(4, 7)), C_BAT if lit else Color(1, 1, 1, 0.15))
		draw_rect(Rect2(q + Vector2(1, -1), Vector2(2, 1)), C_RIVET if lit else Color(1, 1, 1, 0.2))


## O coelho tocou o ácido: chiado e fumaça verde.
func _acid_burn() -> void:
	if state != "play" or invuln > 0:
		return
	sfx.emit("acid_splash")   # o coelho morre antes de a água teria tempo de espirrar: o respingo vem junto
	sfx.emit("acid_burn")
	_splash(maxf(rabbit.vel.y, 60.0))
	var c := Vector2(rabbit.pos.x + 6, rabbit.pos.y + 8)
	for i in 14:
		particles.append({
			"pos": c + Vector2(randf_range(-5.0, 5.0), randf_range(-4.0, 4.0)),
			"vel": Vector2(randf_range(-30.0, 30.0), -randf_range(20.0, 80.0)),
			"life": randi_range(14, 28), "col": C_ACID_TOP if i % 2 == 0 else C_ACID, "grav": -20.0,
		})


## Bolhas que estouram na superfície do ácido (só desenho).
func _acid_bubbles() -> void:
	_update_bubbles()
	if fluid_acid and water_vol > 0.0 and frame % 11 == 0 and not wt_x.is_empty():
		# vapor tóxico: fiapos verdes subindo devagar da superfície
		var kk := randi() % wt_x.size()
		if wt_h[kk] >= 3.0:
			var fy := wt_bot[kk] - wt_air[kk] - wt_h[kk] + wt_o[kk]
			var fx := float(wt_x[kk])
			if absf(fx - cam.x) < VIEW.x * 0.7 and absf(fy - cam.y) < VIEW.y * 0.7:
				particles.append({"pos": Vector2(fx, fy - 1), "vel": Vector2(randf_range(-3.0, 3.0), -randf_range(6.0, 12.0)),
					"life": randi_range(30, 50), "col": Color(C_ACID_TOP, 0.45), "grav": -4.0})
	if not fluid_acid or water_vol <= 0.0 or frame % 5 != 0 or wt_x.is_empty():
		return
	var k := randi() % wt_x.size()
	if wt_h[k] < 3.0:
		return
	var x := float(wt_x[k])
	var y := wt_bot[k] - wt_air[k] - wt_h[k] + wt_o[k]
	if absf(x - cam.x) > VIEW.x * 0.75 or absf(y - cam.y) > VIEW.y * 0.75:
		return
	particles.append({"pos": Vector2(x, y), "vel": Vector2(randf_range(-4.0, 4.0), -randf_range(8.0, 22.0)),
		"life": randi_range(8, 14), "col": C_ACID_TOP, "grav": 30.0})


## Bolhas: nascem no fundo do líquido (muitas no ácido, poucas na água), sobem balançando e estouram
## na superfície com um anelzinho. Só o que está perto da tela.
func _update_bubbles() -> void:
	if water_vol <= 0.0 or wt_x.is_empty():
		bubbles.clear()
		return
	var every := 2 if fluid_acid else 26
	if frame % every == 0 and bubbles.size() < (60 if fluid_acid else 12):
		for tries in 4:
			var k := randi() % wt_x.size()
			if wt_h[k] < 8.0 or wt_air[k] > 0.5:
				continue
			var x := float(wt_x[k])
			var bot := wt_bot[k] - wt_air[k]
			if absf(x - cam.x) > VIEW.x * 0.7 or absf(bot - cam.y) > VIEW.y * 0.8:
				continue
			bubbles.append({"k": k, "y": bot - 2.0, "r": randf_range(0.9, 2.6 if fluid_acid else 1.3),
				"vy": randf_range(10.0, 22.0) * (1.0 if fluid_acid else 0.8), "ph": randf() * TAU})
			break
	var keep: Array = []
	for b in bubbles:
		var k: int = b["k"]
		if k >= wt_x.size() or wt_h[k] < 1.0:
			continue
		b["y"] -= b["vy"] / 60.0
		var surf := wt_bot[k] - wt_air[k] - wt_h[k] + wt_o[k]
		if b["y"] <= surf + 1.0:
			if fluid_acid or randf() < 0.5:
				particles.append({"pos": Vector2(wt_x[k], surf), "vel": Vector2.ZERO, "life": 8,
					"col": C_ACID_TOP if fluid_acid else C_WATER_TOP, "grav": 0.0, "ring": b["r"] + 0.8})
			continue
		keep.append(b)
	bubbles = keep


func _splash(speed: float) -> void:
	var k := clampf(speed / 160.0, 0.3, 1.5)
	var c := Vector2(rabbit.pos.x + 6, rabbit.pos.y + 10)
	for i in 6 + int(6.0 * k):
		var dir := -1.0 if i % 2 == 0 else 1.0
		particles.append({
			"pos": c + Vector2(dir * randf_range(1.0, 6.0), 0),
			"vel": Vector2(dir * randf_range(10.0, 45.0) * k, -randf_range(40.0, 110.0) * k),
			"life": randi_range(12, 22), "col": C_ACID_TOP if fluid_acid else C_WATER_TOP, "grav": 380.0,
		})


func _spike_hurt(r: Rect2i, facing: int) -> Rect2i:
	var p := r.position
	match facing:
		0:
			return Rect2i(p.x + 1, p.y + 3, 6, 5)
		1:
			return Rect2i(p.x, p.y + 1, 5, 6)
		2:
			return Rect2i(p.x + 1, p.y, 6, 5)
	return Rect2i(p.x + 3, p.y + 1, 5, 6)


## Chamado pelo coelho a cada pixel quando ele está rápido (na corda ou arremessado): o que
## ele toca primeiro decide. Devolve true se a sala deixou de estar em jogo.
func touch_check() -> bool:
	if state != "play":
		return true
	_check_win()
	if state == "play":
		_check_hazards()
	return state != "play"


func _check_hazards() -> void:
	var rr: Rect2i = rabbit.rect
	if fluid_acid and water_vol > 0.0 and water_frac(rr) > ACID_TOUCH:
		_acid_burn()
		kill()
		return
	for s in spikes:
		if overlaps(rr, _spike_hurt(s["rect"], s["facing"])):
			kill()
			return
	for m in movers:
		if m["spikes"] >= 0:
			for cell in _mover_teeth(m):
				if overlaps(rr, _spike_hurt(cell, m["spikes"])):
					kill()
					return
	for v in vents:
		if v["active"] and overlaps(rr, Rect2i(v["rect"]).grow(-1)):
			kill()
			return
	for c in crushers:
		# 2 px de folga na ponta dos dentes
		if c["adv"] > 0.0 and overlaps(rr, _crusher_rect(c, 0, int(c["adv"]) + CRUSH_SPIKE - 2)):
			kill()
			return


func _check_win() -> void:
	if door_open and has_door and overlaps(rabbit.rect, door):
		state = "won"
		timer = WIN_FRAMES
		shake = 1.5
		sfx.emit("win")
		_door_ring()
		var c := Vector2(door.position) + Vector2(door.size) / 2.0
		for i in 26:
			var a := randf() * TAU
			var sp := randf_range(20.0, 90.0)
			particles.append({
				"pos": c, "vel": Vector2(cos(a), sin(a)) * sp - Vector2(0, 25),
				"life": randi_range(22, 40), "col": C_DOOR_OPEN, "grav": 60.0,
			})
		# faíscas subindo, como poeira de luz
		for i in 10:
			particles.append({
				"pos": c + Vector2(randf_range(-4.0, 4.0), randf_range(-8.0, 8.0)),
				"vel": Vector2(0, -randf_range(20.0, 55.0)),
				"life": randi_range(26, 44), "col": Color("fff4c2"), "grav": 0.0,
			})


func _door_ring() -> void:
	var c := Vector2(door.position) + Vector2(door.size) / 2.0
	particles.append({"pos": c, "vel": Vector2.ZERO, "life": 22, "col": C_DOOR_OPEN, "grav": 0.0, "ring": 4.0})


func _jump_ring() -> void:
	var feet := Vector2(rabbit.pos.x + 6, rabbit.pos.y + 12)
	particles.append({"pos": feet, "vel": Vector2.ZERO, "life": 10, "col": C_DUST, "grav": 0.0, "ring": 2.0})


func _push_dust() -> void:
	var feet := Vector2(rabbit.pos.x + 6 - rabbit.facing * 5, rabbit.pos.y + 11)
	particles.append({
		"pos": feet, "vel": Vector2(-rabbit.facing * randf_range(8.0, 20.0), -randf_range(4.0, 12.0)),
		"life": randi_range(8, 12), "col": C_DUST, "grav": 20.0,
	})


func kill() -> void:
	if state != "play" or invuln > 0:
		return
	# um ator pode transformar a morte em dano (o boss dá vidas ao coelho)
	for a in actors:
		if a.has_method("absorb_kill") and a.absorb_kill(self):
			return
	state = "dead"
	timer = DEATH_FRAMES
	shake = 4.0
	sfx.emit("death")
	var c := Vector2(rabbit.pos) + Vector2(6, 6)
	particles.append({"pos": c, "vel": Vector2.ZERO, "life": 14, "col": Color("efeadf"), "grav": 0.0, "ring": 3.0})
	for i in 14:
		var a := randf() * TAU
		var sp := randf_range(30.0, 110.0)
		particles.append({
			"pos": c, "vel": Vector2(cos(a), sin(a)) * sp - Vector2(0, 30),
			"life": randi_range(14, 26), "col": Color("efeadf"), "grav": 300.0,
		})


func _dust(n: int, speed: float) -> void:
	var feet := Vector2(rabbit.pos.x + 6, rabbit.pos.y + 11)
	for i in n:
		var dir := -1.0 if i % 2 == 0 else 1.0
		particles.append({
			"pos": feet + Vector2(dir * randf_range(1.0, 4.0), 0),
			"vel": Vector2(dir * randf_range(0.3, 1.0) * speed, -randf_range(4.0, 16.0)),
			"life": randi_range(8, 14), "col": C_DUST, "grav": 20.0,
		})


func _update_particles() -> void:
	shake = maxf(shake - 0.35, 0.0)
	jolt_phase += 1.15
	jolt_amp *= 0.84  # forças maiores duram um pouco mais
	impact_recent *= 0.9
	if jolt_amp < 0.05:
		jolt_amp = 0.0
	for i in socket_fx.size():
		socket_fx[i] = maxi(socket_fx[i] - 1, 0)
	for p in particles:
		p["pos"] += p["vel"] * DT
		p["vel"].y += p["grav"] * DT
		p["vel"].x *= 0.92
		p["life"] -= 1
		if p.has("ring"):
			p["ring"] += 1.1
	particles = particles.filter(func(p): return p["life"] > 0)


# ---------------------------------------------------------------- desenho

func _rabbit_tex(ears: String, feet: String, blink: bool) -> ImageTexture:
	var key := "%s|%s|%s" % [ears, feet, blink]
	if rabbit_frames.has(key):
		return rabbit_frames[key]
	var rows: Array = []
	rows.append_array(EARS[ears])
	rows.append_array(BODY)
	rows.append(FEET[feet])
	var palette := {
		"w": Color("efeadf"),
		"g": Color("b7b2a6"),
		"p": Color("e8a0b0"),
		"r": Color("b7b2a6") if blink else Color("e0334a"),
	}
	var img := Image.create_empty(12, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 16:
		var line: String = rows[y]
		for x in 12:
			var ch := line[x]
			if palette.has(ch):
				img.set_pixel(x, y, palette[ch])
	var tex := ImageTexture.create_from_image(img)
	rabbit_frames[key] = tex
	return tex


## Escolhe o quadro do coelho: [textura, deslocamento vertical].
func _rabbit_frame() -> Array:
	if rabbit.rope != null:
		return [_rabbit_tex("back", "air", false), 0]
	if not rabbit.on_ground and rabbit.wet >= Rabbit.SWIM_MIN and absf(rabbit.vel.y) < 40.0:
		# boiando: orelhas em pé, patas remando devagar
		var paddle := "air" if int(frame / 14.0) % 2 == 0 else "run_a"
		return [_rabbit_tex("up", paddle, frame % 260 >= 120 and frame % 260 < 127), 0]
	if not rabbit.on_ground:
		if rabbit.vel.y < -15.0:
			return [_rabbit_tex("back", "air", false), 0]
		return [_rabbit_tex("fall", "air", false), 0]
	if rabbit.push_t > 0:
		# empurrando: orelhas para trás, pernas abertas, passos curtos e lentos
		if int(rabbit.anim / 5.0) % 2 == 0:
			return [_rabbit_tex("back", "push_a", false), 0]
		return [_rabbit_tex("back", "push_b", false), 0]
	if rabbit.run_t > 0:
		if int(rabbit.anim / 6.0) % 2 == 0:
			return [_rabbit_tex("back", "run_a", false), -1]
		return [_rabbit_tex("up", "run_b", false), 0]
	var t := frame % 260
	var blink := t >= 120 and t < 127
	var ears := "twitch" if (t >= 200 and t < 214) else "up"
	return [_rabbit_tex(ears, "stand", blink), 0]


## Triângulo apontando para `facing` dentro de um tile (0 cima, 1 direita, 2 baixo, 3 esquerda).
func _spike_points(r: Rect2i, facing: int) -> PackedVector2Array:
	return _tri_points(r, facing, [Vector2(1, 8), Vector2(4, 3), Vector2(7, 8)])


func _tri_points(r: Rect2i, facing: int, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		var q: Vector2 = p
		for i in facing:
			q = Vector2(8.0 - q.y, q.x)  # 90° horário em volta do centro do tile
		out.append(Vector2(r.position) + q)
	return out


func _draw() -> void:
	var jitter := Vector2.ZERO
	if shake > 0.0:
		jitter = Vector2(roundf(randf_range(-shake, shake)), roundf(randf_range(-shake, shake)))
	# solavanco no sentido da gravidade (para baixo na tela): a sala "afunda" e volta
	var jolt := Vector2(0.0, roundf(jolt_amp * sin(jolt_phase)))
	var base := Transform2D(0.0, jolt) * Transform2D(view_angle, Vector2.ZERO) * Transform2D(0.0, -cam.round() + jitter)
	draw_set_transform_matrix(base)
	_base = base
	var room_rect := Rect2(0, 0, pw, ph)

	draw_rect(room_rect, C_BG)
	if theme != "":
		_draw_world_far(base)
		# o fundo do meio é pintado na fase como foi desenhada e gira junto com ela (não pula no giro)
		var to := _orig_xform()
		var cam_o := to.affine_inverse() * cam
		_bw = float(pw if orientation % 2 == 0 else ph)
		_bh = float(ph if orientation % 2 == 0 else pw)
		_bg_shift = (cam_o - Vector2(_bw, _bh) / 2.0) * PARALLAX
		draw_set_transform_matrix(base * to * Transform2D(0.0, _bg_shift.round()))
		_bg_cam = cam_o
	if theme == "industrial":
		_draw_industrial_back()
	elif theme == "transicao":
		_draw_transition_back()
	elif SUBSOIL.has(theme):
		_draw_subsoil_back()
	draw_set_transform_matrix(base)
	_draw_ambient_motion()
	_draw_cast_shadows()

	# compartimentos (fundo)
	for s in sockets:
		draw_rect(Rect2(s), C_SOCKET)

	# porta e seus brilhos: desenhados ANTES das paredes, para a parede e a linha branca
	# da borda sempre ficarem por cima e nada da porta vazar para dentro delas
	if has_door:
		_draw_door()
		_draw_door_beam()

	_draw_walls()
	_draw_exits()
	_draw_conveyors()
	_draw_gates()
	_draw_platforms()
	_draw_springs()
	_draw_fans()
	_draw_vents()
	_draw_movers()
	_draw_crumbles()
	_draw_plates()
	_draw_drains()
	_draw_ropes()

	# espinhos (os do bloco, durante o giro dele, são desenhados girando)
	for s in spikes:
		if spinning and s.get("block", false):
			continue
		draw_colored_polygon(_spike_points(s["rect"], s["facing"]), C_SPIKE)
	if spinning:
		_draw_spin_block(base)

	# caixas
	for b in boxes:
		var p := Vector2(b.pos)
		draw_rect(Rect2(p, Vector2(16, 16)), C_BOX_DARK)
		draw_rect(Rect2(p + Vector2(1, 1), Vector2(14, 14)), C_BOX)
		draw_rect(Rect2(p + Vector2(5, 5), Vector2(6, 6)), C_BOX_MID)

	# moldura dos compartimentos (por cima da caixa: ela parece encaixada)
	for i in sockets.size():
		var s: Rect2i = sockets[i]
		var filled: bool = i < socket_filled.size() and socket_filled[i]
		var col := _socket_color(i, filled)
		var o := Vector2(s.position)
		draw_rect(Rect2(o, Vector2(16, 2)), col)
		draw_rect(Rect2(o + Vector2(0, 14), Vector2(16, 2)), col)
		draw_rect(Rect2(o + Vector2(0, 2), Vector2(2, 12)), col)
		draw_rect(Rect2(o + Vector2(14, 2), Vector2(2, 12)), col)
		_draw_sensor_fx(s, i)

	_draw_lever_and_chute()
	_draw_batteries()

	# coelho
	if rabbit != null and (state == "play" or state == "won"):
		_draw_contact_shadow()
		_draw_rabbit(base)
		_draw_awaken()
		_draw_limiter_beam()

	_draw_crushers(base)
	_draw_water()

	# partículas
	for p in particles:
		var a := clampf(float(p["life"]) / 14.0, 0.0, 1.0)
		var col: Color = p["col"]
		if p.has("ring"):
			draw_arc(p["pos"], p["ring"], 0.0, TAU, 20, Color(col, a * 0.8), 1.0)
		else:
			draw_rect(Rect2(p["pos"] - Vector2(1, 1), Vector2(2, 2)), Color(col, a))

	# entrada no portal: véu dourado que cresce sobre a sala inteira
	if (state == "won" or state == "done") and has_door:
		var t := 1.0 - float(timer) / float(WIN_FRAMES)
		draw_rect(room_rect, Color(1.0, 0.9, 0.45, 0.35 * smoothstep(0.55, 1.0, t)))

	# clarão da morte
	if state == "dead":
		var f := float(timer) / float(DEATH_FRAMES)
		draw_rect(room_rect, Color(1, 1, 1, 0.35 * f * f))

	_draw_vignette()
	draw_set_transform_matrix(base)
	_draw_battery_hud()
	draw_set_transform_matrix(base)

	# perigo: brilho vermelho pulsando na borda da tela de onde a placa vem
	if danger > 0.02 and danger_dir >= 0 and not rotating:
		draw_set_transform_matrix(Transform2D())
		var pulse := 0.55 + 0.45 * sin(frame * (0.12 + 0.22 * danger))
		var half := VIEW / 2.0
		for k in 5:
			var w := 4.0 + k * 4.0
			var col := Color(C_SPIKE, 0.11 * danger * pulse)
			match danger_dir:
				0:
					draw_rect(Rect2(-half.x, half.y - w, VIEW.x, w), col)
				1:
					draw_rect(Rect2(-half.x, -half.y, w, VIEW.y), col)
				2:
					draw_rect(Rect2(-half.x, -half.y, VIEW.x, w), col)
				_:
					draw_rect(Rect2(half.x - w, -half.y, w, VIEW.y), col)
		draw_set_transform_matrix(base)


## Blocos motorizados e os encaixes deles: trilho, moldura em cada ponta (acende quando a peça
## está encaixada), a peça de aço com a borda na cor do canal e rebites; espinhos se tiver.
func _draw_movers() -> void:
	var reach := VIEW.length() / 2.0 + 40.0
	for m in movers:
		var r: Rect2i = m["r"]
		if (Vector2(r.position) - cam).length() > reach and (Vector2(m["off"].position) - cam).length() > reach \
				and (Vector2(m["on"].position) - cam).length() > reach:
			continue
		var col: Color = C_CHANNEL[m["ch"] % C_CHANNEL.size()]
		var off: Rect2i = m["off"]
		var on: Rect2i = m["on"]
		# trilho: uma linha pontilhada entre os centros
		var ca := Vector2(off.position) + Vector2(off.size) / 2.0
		var cb := Vector2(on.position) + Vector2(on.size) / 2.0
		var len := ca.distance_to(cb)
		var dirv := (cb - ca) / maxf(len, 1.0)
		var k := 0.0
		while k < len:
			draw_rect(Rect2((ca + dirv * k).round(), Vector2(1, 1)), Color(col, 0.35))
			k += 4.0
		# molduras dos encaixes
		for dock in [off, on]:
			var lit: bool = r.position == dock.position
			var fx: float = 0.0
			if lit and m["fx"] >= 0 and m["fx"] < 14:
				fx = 1.0 - float(m["fx"]) / 14.0
			# no aviso, os dois encaixes piscam: é a deixa de que este canal vai mudar
			if (mover_warning(m["ch"]) or m["warn"]) and (frame / 3) % 2 == 0:
				lit = true
				fx = maxf(fx, 0.8)
			_draw_dock(Rect2(dock), col, lit, fx)
		_draw_mover_body(m, col)
		if m["launch"] > 0.0:
			# catapulta: duas setas para cima pintadas na peça
			var mr := Rect2(m["r"])
			for q in 2:
				var cx := mr.position.x + mr.size.x * (0.3 + 0.4 * q)
				draw_polyline(PackedVector2Array([Vector2(cx - 2, mr.position.y + mr.size.y - 2), Vector2(cx, mr.position.y + mr.size.y - 4), Vector2(cx + 2, mr.position.y + mr.size.y - 2)]), C_PAINT, 1.0)


## Chapas soltas: aço fino enferrujado, com uma trinca; tremem depois de pisadas.
func _draw_crumbles() -> void:
	for c in crumbles:
		var r := Rect2(c["rect"])
		if (r.get_center() - cam).length() > VIEW.length() / 2.0 + 40.0:
			continue
		if c["t"] >= 0:
			r.position += Vector2(float((frame / 2) % 2) * 2.0 - 1.0, float(c["t"]) / float(CRUMBLE_FRAMES) * 2.0)
		draw_rect(r, C_SEAM)
		draw_rect(r.grow(-1.0), C_RUST)
		draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1)), C_STEEL_LIGHT)
		# trinca em zigue-zague no meio, e um rebite em cada ponta
		var mx := r.position.x + r.size.x / 2.0
		draw_polyline(PackedVector2Array([Vector2(mx - 1, r.position.y + 1), Vector2(mx + 1, r.position.y + r.size.y / 2.0), Vector2(mx - 1, r.end.y - 1)]), C_SEAM, 1.0)
		draw_rect(Rect2(r.position + Vector2(2, r.size.y / 2.0 - 0.5), Vector2(1, 1)), C_RIVET)
		draw_rect(Rect2(Vector2(r.end.x - 3, r.position.y + r.size.y / 2.0 - 0.5), Vector2(1, 1)), C_RIVET)


func _draw_dock(d: Rect2, col: Color, lit: bool, fx: float) -> void:
	draw_rect(d, Color(col, 0.10 + 0.12 * fx))
	var c := Color(col, 0.95 if lit else 0.5)
	var L := minf(4.0, minf(d.size.x, d.size.y) / 2.0)
	# cantoneiras nos quatro cantos
	for q in [[Vector2(0, 0), 1, 1], [Vector2(d.size.x, 0), -1, 1], [Vector2(0, d.size.y), 1, -1], [Vector2(d.size.x, d.size.y), -1, -1]]:
		var o: Vector2 = d.position + q[0]
		draw_rect(Rect2(o + Vector2(0 if q[1] > 0 else -L, 0 if q[2] > 0 else -1), Vector2(L, 1)), c)
		draw_rect(Rect2(o + Vector2(0 if q[1] > 0 else -1, 0 if q[2] > 0 else -L), Vector2(1, L)), c)
	if fx > 0.0:
		draw_rect(d.grow(1.0), Color(1, 1, 1, 0.5 * fx), false, 1.0)


func _draw_mover_body(m: Dictionary, col: Color) -> void:
	var r: Rect2 = Rect2(m["r"])
	var seed: int = (m["ch"] + 1) * 7919 + int(m["off"].position.x) * 31 + int(m["off"].position.y)
	draw_rect(r, C_SEAM)
	draw_rect(r.grow(-1.0), C_STEEL[absi(seed) % 3])
	# a tinta do canal: uma faixa de 2 px na face de cima e na de baixo
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 2)), col)
	draw_rect(Rect2(r.position + Vector2(1, r.size.y - 3), Vector2(r.size.x - 2, 2)), Color(col, 0.55))
	# emendas e rebites a cada tile
	var tiles_x := int(r.size.x) / TILE
	for i in tiles_x:
		var x := r.position.x + i * TILE
		if i > 0:
			draw_rect(Rect2(x, r.position.y + 3, 1, maxf(r.size.y - 6, 1.0)), C_SEAM)
		draw_rect(Rect2(x + 3, r.position.y + r.size.y / 2.0 - 0.5, 2, 1), C_RIVET)
	# remendo enferrujado em algumas peças
	if absi(seed) % 3 == 0 and r.size.x >= 16:
		draw_rect(Rect2(r.position + Vector2(r.size.x - 11, 3), Vector2(8, maxf(r.size.y - 6, 1.0))), C_RUST)
	# encaixe macho: duas pontas na cor do canal, na direção do movimento
	var tgt: Vector2 = Vector2(m["on"].position - m["off"].position)
	if tgt.x != 0.0:
		var sx := signf(tgt.x if mover_wants_on(m) else -tgt.x)
		var ex: float = r.end.x if sx > 0 else r.position.x - 2
		draw_rect(Rect2(ex, r.position.y + r.size.y / 2.0 - 2, 2, 4), col)
	elif tgt.y != 0.0:
		var sy := signf(tgt.y if mover_wants_on(m) else -tgt.y)
		var ey: float = r.end.y if sy > 0 else r.position.y - 2
		draw_rect(Rect2(r.position.x + r.size.x / 2.0 - 2, ey, 4, 2), col)
	if m["spikes"] >= 0:
		for cell in _mover_teeth(m):
			draw_colored_polygon(_spike_points(cell, m["spikes"]), C_SPIKE)


## Um retângulo em coordenadas da placa: `u` ao longo da frente, `v` para trás a partir dela.
func _crusher_local(c: Dictionary, u: int, v: int, w: int, h: int) -> Rect2i:
	var l: Rect2i = c["lane"]
	var a := int(c["adv"])
	match c["dir"]:
		0:
			return Rect2i(l.position.x + u, l.end.y - a + v, w, h)
		1:
			return Rect2i(l.position.x + a - v - h, l.position.y + u, h, w)
		2:
			return Rect2i(l.position.x + u, l.position.y + a - v - h, w, h)
	return Rect2i(l.end.x - a + v, l.position.y + u, h, w)


## Placa de espinhos: chapas de aço remendadas e rebitadas, uma viga na frente com os dentes
## e a carinha pichada no meio (pintada na placa: não se mexe e gira com a sala).
func _draw_crushers(base: Transform2D) -> void:
	var reach := int(VIEW.length() / 2.0) + 8
	for c in crushers:
		var a := int(c["adv"])
		if a <= 0:
			continue
		var d: int = c["dir"]
		var l: Rect2i = c["lane"]
		var width: int = l.size.x if d % 2 == 0 else l.size.y
		draw_rect(Rect2(_crusher_rect(c, 0, a)), C_SEAM)
		# a câmera em coordenadas da placa, para só desenhar as chapas que estão na tela
		var uc: int
		var vc: int
		match d:
			0:
				uc = int(cam.x) - l.position.x
				vc = int(cam.y) - (l.end.y - a)
			1:
				uc = int(cam.y) - l.position.y
				vc = (l.position.x + a) - int(cam.x)
			2:
				uc = int(cam.x) - l.position.x
				vc = (l.position.y + a) - int(cam.y)
			_:
				uc = int(cam.y) - l.position.y
				vc = int(cam.x) - (l.end.x - a)
		var u0 := maxi(uc - reach, 0)
		var u1 := mini(uc + reach, width)
		var v0 := maxi(vc - reach, CRUSH_BEAM)
		var v1 := mini(vc + reach, a)
		if u1 > u0 and v1 > v0:
			for j in range((v0 - CRUSH_BEAM) / 16, (v1 - CRUSH_BEAM) / 16 + 1):
				var off := 16 if j % 2 == 1 else 0
				for i in range((u0 + off) / 32, (u1 + off) / 32 + 1):
					_draw_crusher_panel(c, i * 32 - off, CRUSH_BEAM + j * 16, width, a, i * 7919 + j * 104729)
		# viga da frente, com um parafuso por dente
		if a >= CRUSH_BEAM:
			draw_rect(Rect2(_crusher_local(c, 0, 0, width, CRUSH_BEAM - 1)), C_STEEL_LIGHT)
			draw_rect(Rect2(_crusher_local(c, 0, 0, width, 1)), C_RIVET)
		var fwd: Vector2 = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][d]
		var along := Vector2(1, 0) if d % 2 == 0 else Vector2(0, 1)
		var p0 := Vector2(_crusher_rect(c, 0, a).position)
		if d == 1:
			p0.x += a
		elif d == 2:
			p0.y += a
		for i in range(u0 / TILE, (u1 + TILE - 1) / TILE):
			var o := p0 + along * (i * TILE)
			draw_colored_polygon(PackedVector2Array([
				o + along * 1.0, o + along * 4.0 + fwd * CRUSH_SPIKE, o + along * 7.0,
			]), C_SPIKE)
			if a >= CRUSH_BEAM:
				draw_rect(Rect2(_crusher_local(c, i * TILE + 3, 2, 2, 2)), C_SEAM)
		if a >= CRUSH_FACE_MIN and width >= 40:
			var fc := _crusher_local(c, width / 2, 26, 0, 0).position
			draw_set_transform_matrix(base * Transform2D(c["turn"] * PI / 2.0, Vector2(fc)))
			_draw_graffiti_face(c["face"] == "sad")
			draw_set_transform_matrix(base)


## Uma chapa de 32x16 (recortada à placa), com rebites nos cantos e, às vezes, um remendo.
func _draw_crusher_panel(c: Dictionary, u: int, v: int, width: int, a: int, key: int) -> void:
	var h := absi(key * 2654435761) >> 4
	var cu0 := maxi(u, 0)
	var cu1 := mini(u + 31, width)
	var cv1 := mini(v + 15, a)
	if cu1 <= cu0 or cv1 <= v:
		return
	draw_rect(Rect2(_crusher_local(c, cu0, v, cu1 - cu0, cv1 - v)), C_STEEL[h % 3])
	if cu1 - cu0 < 31 or cv1 - v < 15:
		return
	for q in [Vector2i(2, 2), Vector2i(28, 2), Vector2i(2, 12), Vector2i(28, 12)]:
		draw_rect(Rect2(_crusher_local(c, u + q.x, v + q.y, 1, 1)), C_RIVET)
	if h % 4 == 0:
		# remendo: chapa menor, de outra cor, presa por quatro rebites
		var px := u + 5 + (h >> 3) % 10
		var pw2 := 9 + (h >> 7) % 5
		draw_rect(Rect2(_crusher_local(c, px - 1, v + 3, pw2 + 2, 10)), C_SEAM)
		draw_rect(Rect2(_crusher_local(c, px, v + 4, pw2, 8)), C_RUST if (h >> 11) % 2 == 0 else C_STEEL_LIGHT)
		for q in [Vector2i(1, 5), Vector2i(pw2 - 2, 5), Vector2i(1, 10), Vector2i(pw2 - 2, 10)]:
			draw_rect(Rect2(_crusher_local(c, px + q.x, v + q.y, 1, 1)), C_RIVET)
	elif h % 7 == 0:
		# risco de solda
		draw_rect(Rect2(_crusher_local(c, u + 6 + (h >> 5) % 8, v + 7, 12, 1)), C_SEAM)


## Carinha pichada com tinta clara: traço grosso e torto, tinta escorrendo, respingos.
## Desenhada em volta de (0, 0); quem chama põe a transformação.
func _draw_graffiti_face(sad: bool) -> void:
	var col := Color(C_PAINT, 0.92)
	var thin := Color(C_PAINT, 0.6)
	for r in [Rect2(-12, -10, 5, 6), Rect2(-13, -8, 1, 3), Rect2(-11, -11, 3, 1),
			Rect2(7, -10, 5, 6), Rect2(12, -9, 1, 3), Rect2(8, -11, 3, 1)]:
		draw_rect(r, col)
	# tinta escorrendo dos olhos
	draw_rect(Rect2(-10, -4, 1, 5), thin)
	draw_rect(Rect2(9, -4, 1, 8 if sad else 4), thin)
	var pts: PackedVector2Array
	if sad:
		pts = PackedVector2Array([Vector2(-13, 13), Vector2(-10, 8), Vector2(-5, 5), Vector2(1, 4), Vector2(6, 5), Vector2(11, 8), Vector2(14, 13)])
		draw_rect(Rect2(-14, 13, 1, 4), thin)
		draw_rect(Rect2(13, 13, 1, 6), thin)
	else:
		pts = PackedVector2Array([Vector2(-14, 2), Vector2(-11, 7), Vector2(-5, 10), Vector2(1, 11), Vector2(6, 10), Vector2(11, 7), Vector2(14, 1)])
		draw_rect(Rect2(-12, 7, 1, 6), thin)
		draw_rect(Rect2(1, 12, 1, 4), thin)
		draw_rect(Rect2(10, 8, 1, 3), thin)
	draw_polyline(pts, col, 2.0)
	# respingos
	for q in [Vector2(-17, -3), Vector2(16, -12), Vector2(-4, -14), Vector2(17, 5), Vector2(-16, 9), Vector2(4, 16)]:
		draw_rect(Rect2(q, Vector2(1, 1)), thin)


## O bloco no meio do giro: tapa o bloco parado e desenha um girando, com os espinhos.
func _draw_spin_block(base: Transform2D) -> void:
	var t := _ease(float(spin_frame) / float(SPIN_FRAMES))
	var c := Vector2(spin_rect.position) + Vector2(spin_rect.size) / 2.0
	var half := Vector2(spin_rect.size) / 2.0
	var ang := spin_dir * PI / 2.0 * t
	# a sombra do bloco no fundo, inclinada junto com ele (a luz não gira: o deslocamento é o mesmo)
	draw_set_transform_matrix(base * Transform2D(ang, c + SHADOW_OFF))
	draw_rect(Rect2(-half, half * 2.0), C_SHADOW)
	draw_set_transform_matrix(base * Transform2D(ang, c))
	# o bloco gira com a textura do tema (tile a tile, em volta do centro)
	var ci := Vector2i(c.round())
	for ty in range(spin_rect.position.y, spin_rect.end.y, TILE):
		for tx in range(spin_rect.position.x, spin_rect.end.x, TILE):
			var lx := tx - ci.x
			var ly := ty - ci.y
			if theme == "industrial" or (theme == "transicao" and _metal_frac(Vector2(tx, ty)) > 0.5):
				_draw_steel_tile(tx / TILE, ty / TILE, lx, ly, true)
			elif soil != "":
				_draw_soil_tile(tx / TILE, ty / TILE, lx, ly)
			else:
				draw_rect(Rect2(lx, ly, TILE, TILE), C_WALL)
			_draw_block_depth(tx, ty, lx, ly)
	draw_rect(Rect2(-half, half * 2.0), C_EDGE, false, 1.0)
	for s in spikes:
		if s.get("block", false):
			var pts := _spike_points(s["rect"], s["facing"])
			for i in pts.size():
				pts[i] -= c
			draw_colored_polygon(pts, C_SPIKE)
	draw_set_transform_matrix(base)


## O volume de um tile do bloco que gira (o mesmo de _draw_wall_depth, olhando só o bloco).
func _draw_block_depth(tx: int, ty: int, lx: int, ly: int) -> void:
	var inner := Rect2i(spin_rect.position + Vector2i(TILE, TILE), spin_rect.size - Vector2i(2 * TILE, 2 * TILE))
	var p := Vector2i(tx, ty)
	if inner.has_point(p):
		var deep := Rect2i(inner.position + Vector2i(TILE, TILE), inner.size - Vector2i(2 * TILE, 2 * TILE))
		draw_rect(Rect2(lx, ly, TILE, TILE), Color(0, 0, 0, 0.30 if deep.has_point(p) else 0.16))
		return
	if ty == spin_rect.end.y - TILE:
		draw_rect(Rect2(lx, ly + TILE - 3, TILE, 2), Color(0, 0, 0, 0.22))
	if tx == spin_rect.end.x - TILE:
		draw_rect(Rect2(lx + TILE - 3, ly, 2, TILE), Color(0, 0, 0, 0.18))
	if ty == spin_rect.position.y:
		draw_rect(Rect2(lx, ly + 1, TILE, 1), Color(1, 1, 1, 0.07))
	if tx == spin_rect.position.x:
		draw_rect(Rect2(lx + 1, ly, 1, TILE), Color(1, 1, 1, 0.05))


## Compartimentos da porta: cinza/amarelo. Compartimentos de comporta: na cor da comporta.
func _socket_color(i: int, filled: bool) -> Color:
	if socket_group[i] == 0:
		return C_SOCKET_ON if filled else C_SOCKET_FRAME
	return C_GATE if filled else Color(C_GATE, 0.45)


func _draw_walls() -> void:
	# só desenha o que está na tela (salas grandes). Durante a animação do giro a tela mostra
	# um círculo em volta da câmera: o raio é a meia diagonal.
	var half := VIEW / 2.0 + Vector2(24, 24)
	if rotating:
		var rad := VIEW.length() / 2.0 + 24.0
		half = Vector2(rad, rad)
	var c0 := maxi(int((cam.x - half.x) / TILE), 0)
	var c1 := mini(int((cam.x + half.x) / TILE), gw - 1)
	var r0 := maxi(int((cam.y - half.y) / TILE), 0)
	var r1 := mini(int((cam.y + half.y) / TILE), gh - 1)
	_metal_cells.clear()
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			if tiles[r * gw + c] == 0:
				continue
			if spinning and spin_rect.has_point(Vector2i(c * TILE, r * TILE)):
				continue   # o bloco girando é desenhado à parte, com a sombra e o volume dele
			var x := c * TILE
			var y := r * TILE
			var metal := theme == "industrial"
			if theme == "transicao":
				# terra virando metal: chapas aparecem soltas na terra e tomam conta
				var hm := absi((c * 19349663) ^ (r * 83492791)) % 100
				metal = _metal_frac(Vector2(x + 4, y + 4)) * 100.0 > 25.0 + hm * 0.5
			if metal:
				_draw_steel_tile(c, r, x, y)
				_metal_cells.append(Vector2i(c, r))
			elif soil != "":
				_draw_soil_tile(c, r, x, y)
			else:
				draw_rect(Rect2(x, y, TILE, TILE), C_WALL)
			_draw_wall_depth(c, r, x, y)
			if r > 0 and tiles[(r - 1) * gw + c] == 0:
				draw_rect(Rect2(x, y, TILE, 1), C_EDGE)
			if r < gh - 1 and tiles[(r + 1) * gw + c] == 0:
				draw_rect(Rect2(x, y + TILE - 1, TILE, 1), C_EDGE)
			if c > 0 and tiles[r * gw + c - 1] == 0:
				draw_rect(Rect2(x, y, 1, TILE), C_EDGE)
			if c < gw - 1 and tiles[r * gw + c + 1] == 0:
				draw_rect(Rect2(x + TILE - 1, y, 1, TILE), C_EDGE)
			_round_corners(c, r, x, y)
			if soil != "" and (theme != "transicao" or _metal_frac(Vector2(x + 4, y + 4)) < 0.55):
				_draw_soil_decor(c, r, x, y)
	# enfeites da fábrica depois de todas as paredes (as lâmpadas ficam por cima delas)
	for mc in _metal_cells:
		_draw_industrial_decor(mc.x, mc.y, mc.x * TILE, mc.y * TILE)
	_draw_anchors()


## Tema industrial: a parede vira chapas de aço de 2×2 tiles, com emendas, rebites nos cantos e,
## em algumas, um remendo enferrujado. A cor e o remendo saem de um hash da posição da chapa.
func _draw_steel_tile(c: int, r: int, x: int, y: int, loose := false) -> void:
	var pc := c >> 1
	var pr := r >> 1
	var h := (pc * 73856093) ^ (pr * 19349663)
	h = absi(h)
	draw_rect(Rect2(x, y, TILE, TILE), C_STEEL[h % 3])
	var lx := c & 1
	var ly := r & 1
	# emendas entre chapas (só onde há parede dos dois lados: a borda branca desenha o resto)
	if lx == 1 and (loose or (c < gw - 1 and tiles[r * gw + c + 1] != 0)):
		draw_rect(Rect2(x + TILE - 1, y, 1, TILE), C_SEAM)
	if ly == 1 and (loose or (r < gh - 1 and tiles[(r + 1) * gw + c] != 0)):
		draw_rect(Rect2(x, y + TILE - 1, TILE, 1), C_SEAM)
	# rebites nos quatro cantos da chapa
	var rx := x + (1 if lx == 0 else TILE - 2)
	var ry := y + (1 if ly == 0 else TILE - 2)
	draw_rect(Rect2(rx, ry, 1, 1), C_RIVET)
	# remendo enferrujado em uma a cada sete chapas, e um brilho de luz no alto de outras
	if h % 7 == 0 and lx == 0 and ly == 0:
		draw_rect(Rect2(x + 2, y + 2, 12, 11), Color(C_RUST, 0.55))
	elif h % 5 == 0 and ly == 0:
		draw_rect(Rect2(x, y, TILE, 1), Color(C_STEEL_LIGHT, 0.4))


## Fundo do tema industrial: dutos e tubulações apagadas atrás de tudo, e manchas de luz âmbar.
## Só o que está na tela, com contraste baixo para não atrapalhar a leitura das plataformas.
func _draw_industrial_back() -> void:
	var half := Vector2(VIEW.x, VIEW.x) / 2.0 + Vector2(24, 24)   # quadrado: a fase pode estar girada
	var bc := _bg_cam - _bg_shift   # o fundo está deslocado (paralaxe)
	var lo := (-_bg_shift).max(Vector2.ZERO)
	var hi := Vector2(_bw, _bh) - _bg_shift.max(Vector2.ZERO)
	var x0 := maxi(int(bc.x - half.x), int(lo.x))
	var x1 := mini(int(bc.x + half.x), int(hi.x))
	var y0 := maxi(int(bc.y - half.y), int(lo.y))
	var y1 := mini(int(bc.y + half.y), int(hi.y))
	# tubulações horizontais: uma faixa a cada 12 tiles, em alturas variadas
	var row0 := maxi(y0 / (12 * TILE) - 1, 0)
	for k in range(row0, y1 / (12 * TILE) + 2):
		var hy := absi(k * 2654435761) % (6 * TILE)
		var y := k * 12 * TILE + 3 * TILE + hy
		draw_rect(Rect2(x0, y, x1 - x0, 5), Color(C_STEEL_LIGHT, 0.16))
		draw_rect(Rect2(x0, y, x1 - x0, 1), Color(C_STEEL_LIGHT, 0.22))
		var bx0 := int(floor(float(x0) / (7 * TILE))) * 7 * TILE
		for bx in range(bx0, x1 + 1, 7 * TILE):
			draw_rect(Rect2(bx, y - 2, 3, 9), Color(C_STEEL_LIGHT, 0.2))
	# dutos verticais: um a cada 16 tiles
	var col0 := maxi(x0 / (16 * TILE) - 1, 0)
	for k in range(col0, x1 / (16 * TILE) + 2):
		var hx := absi(k * 40503) % (8 * TILE)
		var x := k * 16 * TILE + 4 * TILE + hx
		draw_rect(Rect2(x, y0, 6, y1 - y0), Color(C_STEEL_LIGHT, 0.10))
		draw_rect(Rect2(x, y0, 1, y1 - y0), Color(C_STEEL_LIGHT, 0.16))
	# manchas de luz âmbar, bem fracas
	var lcol0 := maxi(x0 / (22 * TILE) - 1, 0)
	for k in range(lcol0, x1 / (22 * TILE) + 2):
		for j in range(maxi(y0 / (14 * TILE) - 1, 0), y1 / (14 * TILE) + 2):
			var hh := absi(k * 92837111 ^ j * 689287499)
			if hh % 3 != 0:
				continue
			var cx := k * 22 * TILE + hh % (14 * TILE) + 4 * TILE
			var cy := j * 14 * TILE + (hh / 7) % (8 * TILE) + 2 * TILE
			draw_circle(Vector2(cx, cy), 26.0, Color(C_BAT, 0.025))
			draw_circle(Vector2(cx, cy), 14.0, Color(C_BAT, 0.03))


# ---------------------------------------------------------------- subsolo (ato 1, D82)

## A direção do "cima" da fase como foi desenhada, na sala de agora (depois dos giros).
func _orig_up() -> Vector2i:
	var u := Vector2i(0, -1)
	for i in posmod(orientation, 4):
		u = Vector2i(-u.y, u.x)
	return u


func _cell_empty(c: int, r: int) -> bool:
	return c >= 0 and r >= 0 and c < gw and r < gh and tiles[r * gw + c] == 0


## Um retângulo encostado na face `u` do tile (x, y): `a` ao longo da face, `b` para fora dela.
func _face_rect(x: int, y: int, u: Vector2i, a: float, b: float, w: float, h: float) -> Rect2:
	var o := Vector2(x, y)
	var tg := Vector2(1, 0)
	if u == Vector2i(0, 1):
		o = Vector2(x, y + TILE)
	elif u == Vector2i(-1, 0):
		tg = Vector2(0, 1)
	elif u == Vector2i(1, 0):
		o = Vector2(x + TILE, y)
		tg = Vector2(0, 1)
	var uf := Vector2(u)
	var p0 := o + tg * a + uf * b
	var p1 := o + tg * (a + w) + uf * (b + h)
	return Rect2(p0, Vector2.ZERO).expand(p1)


## Terra (raízes, despensa) ou pedra (caverna, lençol d'água): cor e pedrinhas por hash da posição
## atual do tile (ao girar, o padrão se refaz; com cores tão próximas, não se percebe).
func _draw_soil_tile(c: int, r: int, x: int, y: int) -> void:
	var pal: Array = C_SOIL[soil]
	var h := absi((c * 73856093) ^ (r * 19349663))
	draw_rect(Rect2(x, y, TILE, TILE), pal[1])
	if h % 3 == 0:
		# manchas de terra mais escura ou mais clara, menores que o tile: sem xadrez
		draw_rect(Rect2(x + (h >> 4) % 4, y + (h >> 6) % 4, 4, 3), pal[0] if (h >> 8) % 2 == 0 else pal[2])
	if h % 5 == 0:
		draw_rect(Rect2(x + 1 + (h >> 4) % 5, y + 1 + (h >> 7) % 5, 2, 1), pal[2])
	if h % 7 == 1:
		draw_rect(Rect2(x + (h >> 5) % 7, y + (h >> 9) % 7, 1, 1), Color(pal[0], 1.0).darkened(0.35))
	if soil == "caverna" and h % 23 == 3:
		draw_rect(Rect2(x + 2, y + 3, 1, 1), Color(C_CRYSTAL, 0.5))   # veio de cristal na pedra


## Musgo e grama no que era o chão quando a fase foi desenhada (depois de um giro, ficam na parede ou
## no teto: mostra que o mundo virou); raízes ou pingos no que era o teto; cogumelos, cristais, nozes.
func _draw_soil_decor(c: int, r: int, x: int, y: int) -> void:
	var h := absi((c * 2654435761) ^ (r * 40503))
	var up := _orig_up()
	var moss: Color = C_MOSS[soil]
	if _cell_empty(c + up.x, r + up.y):
		# grama e musgo: numa parede (depois de um giro) pendem para baixo da tela
		var tg := Vector2(1, 0) if up.y != 0 else Vector2(0, 1)
		var lean := Vector2(0, 1).dot(tg) + sin(_sway()) * 0.8
		for i in 4:
			var hh := 1 + ((h >> (i * 3)) % 3)
			if soil == "aquifero":
				hh = 1 + ((h >> (i * 3)) % 2)
			var bc: Color = moss if i % 2 == 0 else moss.darkened(0.25)
			for j in hh:
				draw_rect(_face_rect(x, y, up, i * 2 + ((h >> i) & 1) + roundf(lean * j * 0.6), j, 1, 1), bc)
		if soil == "caverna" and h % 9 == 0:
			var col: Color = C_SHROOM[(h >> 4) % 2]
			var pulse := 0.10 + 0.05 * sin(frame * 0.05 + h % 17)
			var cap := _face_rect(x, y, up, 2, 2, 4, 1)
			draw_circle(cap.get_center(), 5.0, Color(col, pulse))
			draw_rect(_face_rect(x, y, up, 3, 0, 1, 2), Color("d8cfc0"))
			draw_rect(cap, col)
		elif soil == "despensa" and h % 6 == 0:
			var nut := _face_rect(x, y, up, 2 + (h >> 5) % 3, 0, 3, 2)
			draw_rect(nut, C_NUT_DECOR)
			draw_rect(Rect2(nut.position, Vector2(1, 1)), Color(C_NUT_DECOR, 1.0).lightened(0.3))
	var dn := -up
	if _cell_empty(c + dn.x, r + dn.y):
		if (soil == "raizes" or soil == "despensa") and h % 3 == 0:
			# raiz pendurada: pende para baixo da tela e balança depois do giro
			var n := 3 + (h >> 4) % 8
			var a0 := 2.0 + float((h >> 2) % 4)
			var st := _face_rect(x, y, dn, a0, 0, 1, 1).position
			_draw_hanging(st, Vector2(dn), n, C_ROOT, 1.2, h)
		elif soil == "aquifero" and h % 5 == 1:
			# musgo pendurado (fios verdes) no lençol d'água
			var st2 := _face_rect(x, y, dn, 2.0 + float((h >> 2) % 4), 0, 1, 1).position
			_draw_hanging(st2, Vector2(dn), 3 + (h >> 4) % 6, C_MOSS["aquifero"], 0.8, h)
		elif (soil == "caverna" or soil == "aquifero") and h % 4 == 0:
			var a1 := 2.0 + float((h >> 3) % 4)
			draw_rect(_face_rect(x, y, dn, a1, 0, 3, 1), C_SOIL[soil][2])
			draw_rect(_face_rect(x, y, dn, a1 + 1, 1, 1, 2), C_SOIL[soil][2])
	if soil == "aquifero" and h % 4 == 0 and _cell_empty(c, r + 1):
		# um pingo que se forma e cai, sempre para baixo da tela (no teto de agora)
		var period := 90 + h % 60
		var tt := (frame + h % 97) % period
		var fall := float(tt - 30) * float(tt - 30) * 0.02 if tt > 30 else 0.0
		if fall < 40.0:
			draw_rect(Rect2(x + 3 + (h >> 3) % 3, y + TILE + 2 + fall, 1, 2), Color(C_DRIP, 0.7))
	if soil == "caverna" and h % 19 == 5:
		for side in [Vector2i(-up.y, up.x), Vector2i(up.y, -up.x)]:
			if _cell_empty(c + side.x, r + side.y):
				var gl := 0.12 + 0.06 * sin(frame * 0.04 + h % 11)
				var cr := _face_rect(x, y, side, 3, 0, 2, 3)
				draw_circle(cr.get_center(), 4.0, Color(C_CRYSTAL, gl))
				draw_rect(cr, C_CRYSTAL)
				break


## Fundo do subsolo: camadas de terra onduladas e, conforme o trecho, raízes e um feixe de luz
## (logo abaixo do buraco), estalactites ao longe e brilhos, veios de água, montes de nozes.
## Contraste baixo, só o que está na tela.
func _draw_subsoil_back() -> void:
	var half := Vector2(VIEW.x, VIEW.x) / 2.0 + Vector2(24, 24)   # quadrado: a fase pode estar girada
	var bc := _bg_cam - _bg_shift   # o fundo está deslocado (paralaxe)
	var lo := (-_bg_shift).max(Vector2.ZERO)
	var hi := Vector2(_bw, _bh) - _bg_shift.max(Vector2.ZERO)
	var x0 := maxi(int(bc.x - half.x), int(lo.x))
	var x1 := mini(int(bc.x + half.x), int(hi.x))
	var y0 := maxi(int(bc.y - half.y), int(lo.y))
	var y1 := mini(int(bc.y + half.y), int(hi.y))
	var pal: Array = C_SOIL[soil]
	var band := Color(pal[2], 0.22)
	# camadas de terra
	var k0 := maxi(y0 / 64 - 1, 0)
	for k in range(k0, y1 / 64 + 2):
		var by := k * 64 + absi(k * 7919) % 24
		var xx := x0 - x0 % 8
		while xx < x1 and by < _bh - 12:
			var wy := by + roundf(sin(xx * 0.035 + k * 1.7) * 4.0)
			draw_rect(Rect2(xx, wy, mini(8, x1 - xx), 3), band)
			xx += 8
	# pedras soltas no fundo
	var gx0 := x0 / 40
	for gx in range(gx0, x1 / 40 + 1):
		for gy in range(y0 / 40, y1 / 40 + 1):
			var hh := absi(gx * 92837111 ^ gy * 689287499)
			if hh % 4 != 0:
				continue
			var p := Vector2(gx * 40 + hh % 32, gy * 40 + (hh >> 5) % 32)
			if p.x > _bw - 12 or p.y > _bh - 8:
				continue
			draw_rect(Rect2(p, Vector2(4 + hh % 3, 2)), Color(pal[2], 0.25))
	match theme:
		"raizes":
			# o buraco lá em cima: um feixe de luz quente, bem fraco
			var lx := _bw * 0.35
			draw_colored_polygon(PackedVector2Array([Vector2(lx - 12, 0), Vector2(lx + 14, 0), Vector2(lx + 70, _bh), Vector2(lx + 10, _bh)]), Color(1.0, 0.92, 0.66, 0.035))
			for i in range(int(x0 / 26), int(x1 / 26) + 1):
				var hh := absi(i * 2654435761)
				var rx := i * 26 + hh % 18
				if rx < 10 or rx > _bw - 12:
					continue
				var depth := mini(30 + hh % 90, int(_bh) - 16)
				for yy in range(0, mini(depth, y1), 2):
					if yy < y0:
						continue
					draw_rect(Rect2(rx + roundf(sin(yy * 0.12 + i) * 2.0), yy, 1, 2), Color(C_ROOT, 0.35))
			# poeira dourada flutuando no feixe
			for i in 16:
				var mx := lx - 6.0 + float((i * 37) % 64) + sin(frame * 0.012 + i) * 6.0 + float(i % 5) * 4.0
				var my := fposmod(float(i * 53) - frame * 0.12, float(_bh))
				if my > y0 and my < y1:
					draw_rect(Rect2(mx + my * 0.25, my, 1, 1), Color(1.0, 0.9, 0.6, 0.30 + 0.2 * sin(frame * 0.05 + i)))
		"caverna":
			for i in range(int(x0 / 30), int(x1 / 30) + 1):
				var hh := absi(i * 40503 ^ 77)
				var sx := float(i * 30 + hh % 20)
				var ln := 10.0 + float(hh % 24)
				draw_colored_polygon(PackedVector2Array([Vector2(sx - 4, 0), Vector2(sx + 4, 0), Vector2(sx, ln)]), Color(pal[2], 0.35))
				var gpos := Vector2(sx + 7, 30 + (hh >> 3) % maxi(int(_bh) - 40, 1))
				if gpos.y > y0 and gpos.y < y1 and (frame / 20 + hh) % 9 == 0:
					draw_rect(Rect2(gpos, Vector2(1, 1)), Color(C_CRYSTAL, 0.6))
		"aquifero":
			pass   # os veios de água escorrem para baixo da tela: estão em _draw_ambient_motion
		"despensa":
			for i in range(int(x0 / 22), int(x1 / 22) + 1):
				var hh := absi(i * 31337)
				var nx := float(i * 22 + hh % 12)
				for j in 3 + hh % 3:
					var q := Vector2(nx + j * 4 - (j / 3) * 8, _bh - 10 - (j / 3) * 4)
					draw_circle(q, 2.5, Color(C_NUT_DECOR, 0.18))


# ---------------------------------------------------------------- reação ao giro (D84)

## Quanto as coisas penduradas estão fora do prumo agora (rad): logo depois do giro, apontam para
## onde era o "baixo" (90° de diferença) e balançam até se acomodar.
func _sway() -> float:
	var t := float(frame - sway_frame)
	if t < 0.0:
		return sway_dir * PI / 2.0
	if t > 150.0:
		return 0.0
	return sway_dir * PI / 2.0 * exp(-t / 24.0) * cos(t * 0.17)


## A direção de uma coisa pendurada numa face de normal `n`: para baixo da tela (com o balanço),
## sem entrar na parede (no máximo 75° da normal). Numa face que virou chão (sala de cabeça para
## baixo), ela tomba e fica deitada rente ao chão, como a corda (até 88°).
func _hang_dir(n: Vector2) -> Vector2:
	var want := PI / 2.0 + _sway()
	var na := n.angle()
	var diff := wrapf(want - na, -PI, PI)
	var lim := 1.54 if _on_floor_face(n) else 1.31
	return Vector2.from_angle(na + clampf(diff, -lim, lim))


## A face de normal `n` está virada para cima na tela (é chão agora)?
func _on_floor_face(n: Vector2) -> bool:
	return n.y < -0.7


## Uma coisa pendurada (raiz, musgo, cabo): nasce reta para fora da face e se curva para baixo.
func _draw_hanging(start: Vector2, n: Vector2, length: int, col: Color, wiggle: float, seed_v: int) -> Vector2:
	var hd := _hang_dir(n)
	if _on_floor_face(n):
		wiggle *= 0.15   # deitada no chão: quase não mexe
	var p := start
	for i in length:
		var k := minf(1.0, float(i) / 2.5)
		var d := n.lerp(hd, k).normalized()
		p += d
		var w := sin(frame * 0.03 + i * 0.6 + seed_v % 13) * wiggle * float(i) / length
		draw_rect(Rect2((p + d.orthogonal() * w).round(), Vector2(1, 1)), col)
	return p


## Onde uma coisa pendurada na face `dn` do tile (c, r) ocupa (o cabo e o cone da lâmpada).
func _hang_area(c: int, r: int, dn: Vector2i) -> Rect2i:
	var a := Rect2i(c * TILE, r * TILE, TILE, TILE)
	var far := Rect2i((c + dn.x * 5 - absi(dn.y) * 2) * TILE, (r + dn.y * 5 - absi(dn.x) * 2) * TILE, TILE * (1 + absi(dn.y) * 4), TILE * (1 + absi(dn.x) * 4))
	return a.merge(far)


## Os enfeites não ficam em cima das peças da sala: esteira, mola, ventilador, jato, conector, botão,
## bateria, alavanca, calha, porta, compartimentos, corda, placa de espinhos, saídas.
func _decor_blocked(area: Rect2i) -> bool:
	for o in conveyors + springs + fans + vents:
		if overlaps(area, o["rect"]):
			return true
	for m in movers:
		if overlaps(area, m["off"]) or overlaps(area, m["on"]):
			return true
	for pl in plates:
		if overlaps(area, pl["rect"]):
			return true
	for b in batteries:
		if overlaps(area, b["rect"]):
			return true
	if lever != null and overlaps(area, Rect2i(lever["rect"]).grow(4)):
		return true
	if chute != null and overlaps(area, Rect2i(chute["rect"]).grow(4)):
		return true
	if has_door and overlaps(area, door.grow(4)):
		return true
	for sk in sockets:
		if overlaps(area, sk):
			return true
	for rp in ropes:
		var an: Vector2 = rp["anchor"]
		if area.has_point(Vector2i(an)) or overlaps(area, Rect2i(Vector2i(an) - Vector2i(6, 6), Vector2i(12, 12))):
			return true
	for cr in crushers:
		if overlaps(area, cr["lane"]):
			return true
	for ex in exits:
		if overlaps(area, ex["rect"]):
			return true
	return false


## Fábrica: lâmpadas penduradas (cabo que balança, cone de luz), correntes e listras de aviso.
## Penduradas no teto da fase como foi desenhada; depois de um giro, pendem para baixo da tela.
func _draw_industrial_decor(c: int, r: int, x: int, y: int) -> void:
	# o hash sai da célula na fase como foi desenhada: girar não muda onde ficam as lâmpadas
	# (antes saía da célula de agora, e a cada giro lâmpadas sumiam e apareciam em outras)
	var oc := _orig_cell(c, r)
	var h := absi((oc.x * 2654435761) ^ (oc.y * 40503))
	var up := _orig_up()
	var dn := -up
	if _cell_empty(c + dn.x, r + dn.y) and (h % 23 == 0 or h % 17 == 3) and not _decor_blocked(_hang_area(c, r, dn)):
		if h % 23 == 0:
			var st := _face_rect(x, y, dn, 4, 0, 1, 1).position
			var tip := _draw_hanging(st, Vector2(dn), 6 + h % 8, C_RIVET, 0.4, h)
			var hd := _hang_dir(Vector2(dn))
			var nrm := hd.orthogonal()
			var lamp_on := (frame / 7 + h) % 97 != 0   # pisca de vez em quando
			# no chão, deitada: o cone de luz quase some (só o brilho da lâmpada)
			var cone_a := 0.055 * clampf(hd.dot(Vector2(dn)) * 2.0 + 0.2, 0.0, 1.0)
			draw_colored_polygon(PackedVector2Array([tip + nrm * 2.0, tip + hd * 34.0 + nrm * 13.0, tip + hd * 34.0 - nrm * 13.0, tip - nrm * 2.0]),
				Color(1.0, 0.86, 0.55, cone_a if lamp_on else 0.0))
			draw_circle(tip + hd * 2.0, 5.0, Color(1.0, 0.86, 0.55, 0.10 if lamp_on else 0.02))
			draw_rect(Rect2(tip - Vector2(2, 1), Vector2(5, 2)), C_STEEL_LIGHT)
			draw_rect(Rect2((tip + hd * 2.0).round(), Vector2(1, 1)), Color("ffe6a8") if lamp_on else C_SEAM)
		elif h % 17 == 3:
			var st2 := _face_rect(x, y, dn, 3, 0, 1, 1).position
			var hd2 := _hang_dir(Vector2(dn))
			var p := st2
			for i in 8 + h % 9:
				var k := minf(1.0, float(i) / 2.5)
				p += Vector2(dn).lerp(hd2, k).normalized()
				draw_rect(Rect2(p.round(), Vector2(1, 1)), C_RIVET if i % 2 == 0 else C_STEEL_LIGHT.darkened(0.2))
	if theme == "industrial" and h % 9 == 0 and _cell_empty(c + up.x, r + up.y) \
			and not _decor_blocked(Rect2i(c * TILE, r * TILE, TILE, TILE).merge(Rect2i((c + up.x) * TILE, (r + up.y) * TILE, TILE, TILE))):
		# listras de aviso na borda (amarelo e preto)
		for i in 4:
			draw_rect(_face_rect(x, y, up, i * 2, -3, 2, 2), Color("d9b440") if i % 2 == 0 else Color("1c1c20"))


## O que está embaixo dos pés do coelho, para o som do passo: grass, dirt, stone, wet, metal,
## wood (caixa), plate (chapa solta, plataforma) ou water (água rasa).
func _surface() -> String:
	if rabbit.wet > 0.05:
		return "water"
	var q := Rect2i(rabbit.pos.x + 2, rabbit.pos.y + Rabbit.SIZE, Rabbit.SIZE - 4, 2)
	if box_at(q, null) != null:
		return "wood"
	for cr in crumbles:
		if cr["t"] < 0 and overlaps(q, cr["rect"]):
			return "plate"
	for pl in platforms:
		if pl["solid"] and overlaps(q, pl["rect"]):
			return "plate"
	for m in movers:
		if overlaps(q, m["r"]):
			return "metal"
	for o in conveyors:
		if overlaps(q, o["rect"]):
			return "metal"
	for g in gates:
		if g["closed"]:
			for gr in g["rects"]:
				if overlaps(q, gr):
					return "metal"
	match theme:
		"industrial":
			return "metal"
		"transicao":
			return "metal" if _metal_frac(Vector2(q.position)) > 0.5 else "dirt"
		"raizes":
			return "grass"
		"despensa":
			return "dirt"
		"aquifero":
			return "wet"
	return "stone"


## Poeira e pedrinhas caem do novo teto a cada giro (na fábrica, fagulhas e ferrugem).
func _ceiling_dust() -> void:
	var half := VIEW / 2.0 + Vector2(8, 8)
	var c0 := maxi(int((cam.x - half.x) / TILE), 0)
	var c1 := mini(int((cam.x + half.x) / TILE), gw - 1)
	var r0 := maxi(int((cam.y - half.y) / TILE), 0)
	var r1 := mini(int((cam.y + half.y) / TILE), gh - 2)
	var made := 0
	var metal := theme == "industrial"
	var col := C_RIVET if metal else (Color(C_SOIL[soil][2], 1.0).lightened(0.25) if soil != "" else C_DUST)
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			if made >= 40:
				return
			if tiles[r * gw + c] != 0 and tiles[(r + 1) * gw + c] == 0 and randf() < 0.18:
				made += 1
				var p := Vector2(c * TILE + randf_range(1.0, 7.0), (r + 1) * TILE)
				particles.append({"pos": p, "vel": Vector2(randf_range(-6.0, 6.0), randf_range(5.0, 30.0)),
					"life": randi_range(30, 60), "col": C_BAT if metal and randf() < 0.3 else col, "grav": 140.0})


# ---------------------------------------------------------------- profundidade (D84)

func _solid_at(c: int, r: int) -> bool:
	if spinning and spin_rect.has_point(Vector2i(c * TILE, r * TILE)):
		return false   # durante o giro do bloco, ele é desenhado à parte (com a sombra dele)
	return c >= 0 and r >= 0 and c < gw and r < gh and tiles[r * gw + c] != 0


## Da fase como foi desenhada para a sala de agora (depois dos giros). O fundo do meio é pintado
## nas coordenadas da fase como foi desenhada e desenhado com esta transformação: gira junto com a
## sala, como as paredes, em vez de ser recalculado (e pular) a cada giro.
## A célula (c, r) da sala de agora, na fase como foi desenhada.
func _orig_cell(c: int, r: int) -> Vector2i:
	var p: Vector2 = _orig_xform().affine_inverse() * Vector2(c * TILE + TILE / 2.0, r * TILE + TILE / 2.0)
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func _orig_xform() -> Transform2D:
	match posmod(orientation, 4):
		1:
			return Transform2D(Vector2(0, 1), Vector2(-1, 0), Vector2(pw, 0))
		2:
			return Transform2D(Vector2(-1, 0), Vector2(0, -1), Vector2(pw, ph))
		3:
			return Transform2D(Vector2(0, -1), Vector2(1, 0), Vector2(0, ph))
	return Transform2D.IDENTITY


## O mundo lá fora: colunas de rocha largas (subsoil) ou colunas e treliças de aço (fábrica), bem ao
## fundo, SEMPRE EM PÉ NA TELA: não giram com a sala (no giro, a sala gira na frente delas). Rolam
## com o quanto a câmera andou na tela (`_world_off`, contínuo também no giro), em duas
## profundidades. Recortadas pelo retângulo da sala (só aparecem lá dentro).
func _draw_world_far(base: Transform2D) -> void:
	var d := cam - _prev_cam
	if d.length() < 64.0:   # trocou de sala ou recomeçou: não arrasta o mundo
		_world_off += d.rotated(view_angle)
	_prev_cam = cam
	var corners := PackedVector2Array([base * Vector2(0, 0), base * Vector2(pw, 0), base * Vector2(pw, ph), base * Vector2(0, ph)])
	var half := VIEW / 2.0 + Vector2(40, 40)
	var mf := 0.0
	if theme == "industrial":
		mf = 1.0
	elif theme == "transicao":
		mf = _metal_frac(cam)
	for layer in 2:
		var k: float = FAR_K[layer]
		var off := (_world_off * k).round()
		var room := PackedVector2Array()
		for cpt in corners:
			room.append(cpt + off)
		draw_set_transform_matrix(Transform2D(0.0, -off))
		var vx0 := off.x - half.x
		var vx1 := off.x + half.x
		var vy0 := off.y - half.y
		var vy1 := off.y + half.y
		var dim := 0.55 if layer == 0 else 1.0
		if mf < 1.0:
			_far_rock_columns(room, vx0, vx1, vy0, vy1, layer, dim * (1.0 - mf))
		if mf > 0.0:
			_far_steel(room, vx0, vx1, vy0, vy1, layer, dim * mf)
	draw_set_transform_matrix(base)


## Desenha `pts` só dentro do retângulo da sala (`room`, já no espaço do mundo lá fora).
func _far_poly(pts: PackedVector2Array, room: PackedVector2Array, col: Color) -> void:
	for piece in Geometry2D.intersect_polygons(pts, room):
		if piece.size() >= 3:
			draw_colored_polygon(piece, col)


## Colunas de rocha que atravessam a tela de cima a baixo, de bordas onduladas: sem pontas.
func _far_rock_columns(room: PackedVector2Array, vx0: float, vx1: float, vy0: float, vy1: float, layer: int, a: float) -> void:
	var pal: Array = C_SOIL[soil if soil != "" else "caverna"]
	var spacing := 70.0 if layer == 0 else 96.0
	var mass := Color(pal[0], 0.30 * a)
	var rim := Color(pal[2], 0.22 * a)
	for i in range(int(floor(vx0 / spacing)) - 1, int(ceil(vx1 / spacing)) + 1):
		var hh := absi((i + layer * 7919) * 2246822519)
		if hh % 3 == 0:
			continue
		var cx := i * spacing + float(hh % 30)
		var wdt := (10.0 if layer == 0 else 16.0) + float(hh % 14)
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		var y := floorf(vy0 / 16.0) * 16.0 - 16.0
		while y <= vy1 + 16.0:
			var wob := sin(y * 0.035 + float(hh % 11)) * 4.0 + sin(y * 0.11 + float(hh % 5)) * 1.5
			var narrow := 0.75 + 0.25 * sin(y * 0.018 + float(hh % 7))
			left.append(Vector2(cx - wdt * narrow + wob, y))
			right.append(Vector2(cx + wdt * narrow + wob * 0.6, y))
			y += 16.0
		right.reverse()
		var poly := left.duplicate()
		poly.append_array(right)
		_far_poly(poly, room, mass)
		# a borda da esquerda pega a luz: uma faixa estreita mais clara
		var lit := PackedVector2Array()
		for q in left:
			lit.append(q)
		for idx in range(left.size() - 1, -1, -1):
			lit.append(left[idx] + Vector2(2, 0))
		_far_poly(lit, room, rim)


## Colunas de aço e treliças horizontais, ao fundo da fábrica.
func _far_steel(room: PackedVector2Array, vx0: float, vx1: float, vy0: float, vy1: float, layer: int, a: float) -> void:
	var beam := Color(C_STEEL_LIGHT, (0.05 if layer == 0 else 0.08) * a)
	var spacing := 110.0 if layer == 0 else 150.0
	for i in range(int(floor(vx0 / spacing)) - 1, int(ceil(vx1 / spacing)) + 1):
		var cx := i * spacing + float(absi(i * 40503) % 40)
		var w := 6.0 if layer == 0 else 9.0
		_far_poly(PackedVector2Array([Vector2(cx, vy0 - 10), Vector2(cx + w, vy0 - 10), Vector2(cx + w, vy1 + 10), Vector2(cx, vy1 + 10)]), room, beam)
	var rs := 90.0 if layer == 0 else 120.0
	for j in range(int(floor(vy0 / rs)) - 1, int(ceil(vy1 / rs)) + 1):
		var by := j * rs + 30.0
		_far_poly(PackedVector2Array([Vector2(vx0 - 10, by), Vector2(vx1 + 10, by), Vector2(vx1 + 10, by + 3), Vector2(vx0 - 10, by + 3)]), room, beam)
		_far_poly(PackedVector2Array([Vector2(vx0 - 10, by + 16), Vector2(vx1 + 10, by + 16), Vector2(vx1 + 10, by + 18), Vector2(vx0 - 10, by + 18)]), room, beam)
		var bx := floorf(vx0 / 24.0) * 24.0
		while bx < vx1:
			for seg in [[Vector2(bx, by + 3), Vector2(bx + 24, by + 16)], [Vector2(bx, by + 16), Vector2(bx + 24, by + 3)]]:
				var p0: Vector2 = seg[0]
				var p1: Vector2 = seg[1]
				var nn := (p1 - p0).orthogonal().normalized() * 0.5
				_far_poly(PackedVector2Array([p0 - nn, p1 - nn, p1 + nn, p0 + nn]), room, beam)
			bx += 24.0


## O que se move no fundo segue a gravidade de agora (para baixo da tela), não a fase como foi
## desenhada: torrões caindo (raízes), veios e pingos escorrendo (lençol d'água), esporos subindo
## (caverna). Em px da sala atual.
func _draw_ambient_motion() -> void:
	if soil == "":
		return
	var half := VIEW / 2.0 + Vector2(16, 16)
	var x0 := maxf(cam.x - half.x, 8.0)
	var x1 := minf(cam.x + half.x, pw - 8.0)
	var y0 := maxf(cam.y - half.y, 8.0)
	var y1 := minf(cam.y + half.y, ph - 8.0)
	match soil:
		"raizes", "despensa":
			for i in 4:
				var tt := float((frame + i * 97) % 260) / 260.0
				var fx := fposmod(float(i * 131 + 40), maxf(pw - 16.0, 1.0)) + 8.0 + sin(tt * 6.0 + i) * 3.0
				var fy := 8.0 + tt * (ph - 16.0)
				if fx > x0 and fx < x1 and fy > y0 and fy < y1:
					draw_rect(Rect2(fx, fy, 1, 1), Color(C_ROOT, 0.6))
		"aquifero":
			for i in range(int(x0 / 34), int(x1 / 34) + 1):
				var hh := absi(i * 92821)
				var vx := float(i * 34 + hh % 20)
				draw_rect(Rect2(vx, y0, 1, y1 - y0), Color(C_DRIP, 0.05))
				var tt := 8.0 + fposmod(float(frame * 2 + hh), maxf(ph - 16.0, 1.0))
				if tt > y0 and tt < y1:
					draw_rect(Rect2(vx, tt, 1, 3), Color(C_DRIP, 0.25))
		"caverna":
			for i in 14:
				var sp := Vector2(8.0 + fposmod(float(i * 71) + sin(frame * 0.01 + i) * 10.0, maxf(pw - 16.0, 1.0)),
					8.0 + fposmod(float(i * 97) - frame * 0.18, maxf(ph - 16.0, 1.0)))
				if sp.x > x0 and sp.x < x1 and sp.y > y0 and sp.y < y1:
					var scol: Color = C_SHROOM[i % 2]
					draw_circle(sp, 2.5, Color(scol, 0.07))
					draw_rect(Rect2(sp.round(), Vector2(1, 1)), Color(scol, 0.6))


## Sombra das paredes no fundo: cada célula vazia escurece onde a parede de cima, da esquerda ou da
## diagonal a cobriria (a luz vem do alto à esquerda). Faixas que não se sobrepõem: sem listras.
## Depois, a sombra dos objetos (caixas, conectores, chapas, plataformas, comportas, coelho), que as
## paredes desenhadas por cima escondem onde cairia nelas.
func _draw_cast_shadows() -> void:
	var half := VIEW / 2.0 + Vector2(24, 24)
	if rotating:
		var rad := VIEW.length() / 2.0 + 24.0
		half = Vector2(rad, rad)
	var c0 := maxi(int((cam.x - half.x) / TILE), 0)
	var c1 := mini(int((cam.x + half.x) / TILE), gw - 1)
	var r0 := maxi(int((cam.y - half.y) / TILE), 0)
	var r1 := mini(int((cam.y + half.y) / TILE), gh - 1)
	var sx := int(SHADOW_OFF.x)
	var sy := int(SHADOW_OFF.y)
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			if tiles[r * gw + c] != 0:
				continue
			var x := c * TILE
			var y := r * TILE
			var top := _solid_at(c, r - 1)
			var left := _solid_at(c - 1, r)
			var diag := _solid_at(c - 1, r - 1)
			if top:
				var ox := 0 if (diag or left) else sx
				draw_rect(Rect2(x + ox, y, TILE - ox, sy), C_SHADOW)
			if left:
				var oy := sy if top else (0 if diag else sy)
				draw_rect(Rect2(x, y + oy, sx, TILE - oy), C_SHADOW)
			if diag and not top and not left:
				draw_rect(Rect2(x, y, sx, sy), C_SHADOW)
	var so := SHADOW_OFF
	for b in boxes:
		draw_rect(Rect2(Vector2(b.pos) + so, Vector2(16, 16)), C_SHADOW)
	for m in movers:
		draw_rect(Rect2(Vector2(m["r"].position) + so, Vector2(m["r"].size)), C_SHADOW)
	for cr in crumbles:
		if cr["t"] < 0:
			draw_rect(Rect2(Vector2(cr["rect"].position) + so, Vector2(cr["rect"].size)), C_SHADOW)
	for pl in platforms:
		if pl["solid"]:
			var psz := Vector2(pl["rect"].size)
			if pl["oneway"]:
				psz.y = 3.0   # a barra de passagem é só o trilho: a sombra também
			draw_rect(Rect2(Vector2(pl["rect"].position) + so, psz), C_SHADOW)
	for g in gates:
		if g["closed"]:
			for gr in g["rects"]:
				draw_rect(Rect2(Vector2(gr.position) + so, Vector2(gr.size)), C_SHADOW)
	if rabbit != null and (state == "play" or state == "won"):
		draw_rect(Rect2(Vector2(rabbit.pos) + so + Vector2(2, 3), Vector2(8, 9)), Color(C_SHADOW, 0.22))


## Quinas expostas arredondadas (só desenho, D96): onde duas faces vizinhas dão para o ar, o pixel
## da quina some e a borda branca faz a curva por dentro. Combina com a folga das quinas.
func _round_corners(c: int, r: int, x: int, y: int) -> void:
	var up := r > 0 and tiles[(r - 1) * gw + c] == 0
	var dn := r < gh - 1 and tiles[(r + 1) * gw + c] == 0
	var lf := c > 0 and tiles[r * gw + c - 1] == 0
	var rt := c < gw - 1 and tiles[r * gw + c + 1] == 0
	for q in [[up, lf, 0, 0, 1, 1], [up, rt, TILE - 1, 0, -1, 1], [dn, lf, 0, TILE - 1, 1, -1], [dn, rt, TILE - 1, TILE - 1, -1, -1]]:
		if q[0] and q[1]:
			draw_rect(Rect2(x + q[2], y + q[3], 1, 1), C_BG)
			draw_rect(Rect2(x + q[2] + q[4], y + q[3] + q[5], 1, 1), C_EDGE)


## Volume da parede: o miolo (sem ar em volta) é mais escuro; as faces de baixo e da direita, que
## não pegam a luz, têm uma faixa de sombra por dentro.
func _draw_wall_depth(c: int, r: int, x: int, y: int) -> void:
	var up := not _solid_at(c, r - 1) and r > 0
	var dn := not _solid_at(c, r + 1) and r < gh - 1
	var lf := not _solid_at(c - 1, r) and c > 0
	var rt := not _solid_at(c + 1, r) and c < gw - 1
	if not (up or dn or lf or rt):
		var near := false
		for d in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
			if c + d.x >= 0 and r + d.y >= 0 and c + d.x < gw and r + d.y < gh and not _solid_at(c + d.x, r + d.y):
				near = true
				break
		if not near:
			# dois tiles para dentro: mais escuro ainda, se não houver ar a 2 tiles
			var deep := true
			for d in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2)]:
				var cc: int = c + d.x
				var rr: int = r + d.y
				if cc >= 0 and rr >= 0 and cc < gw and rr < gh and not _solid_at(cc, rr):
					deep = false
					break
			draw_rect(Rect2(x, y, TILE, TILE), Color(0, 0, 0, 0.30 if deep else 0.16))
		return
	if dn:
		draw_rect(Rect2(x, y + TILE - 3, TILE, 2), Color(0, 0, 0, 0.22))
	if rt:
		draw_rect(Rect2(x + TILE - 3, y, 2, TILE), Color(0, 0, 0, 0.18))
	if up:
		draw_rect(Rect2(x, y + 1, TILE, 1), Color(1, 1, 1, 0.07))
	if lf:
		draw_rect(Rect2(x + 1, y, 1, TILE), Color(1, 1, 1, 0.05))


## Sombra de contato: uma elipse no chão embaixo do coelho, menor e mais clara quanto mais alto ele está.
func _draw_contact_shadow() -> void:
	var feet := Vector2(rabbit.pos) + Vector2(6, 12)
	var d := -1
	for k in range(0, 49, 2):
		var q := Rect2i(int(feet.x) - 3, int(feet.y) + k, 6, 1)
		if solid_static(q) or box_at(q, null) != null:
			d = k
			break
	if d < 0:
		return
	var f := 1.0 - float(d) / 48.0
	var w := 6.5 * f + 1.5
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		pts.append(feet + Vector2(0, d) + Vector2(cos(a) * w, sin(a) * 1.6))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.45 * f))


## Escurece as bordas da tela (desenhado por último, sem a câmera da sala).
func _draw_vignette() -> void:
	if _vignette == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.0))
		g.set_color(1, Color(0, 0, 0, 0.55))
		g.add_point(0.55, Color(0, 0, 0, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.05, 0.5)
		tex.width = 128
		tex.height = 72
		_vignette = tex
	var vs := get_viewport_rect().size if is_inside_tree() else VIEW
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_texture_rect(_vignette, Rect2(-vs / 2.0, vs), false)


## Na transição (corredor entre a terra e a fábrica): quanto de metal há neste ponto, de 0 (o começo
## da fase como foi desenhada) a 1 (o fim). Segue a fase mesmo depois dos giros.
func _metal_frac(p: Vector2) -> float:
	match posmod(orientation, 4):
		1:
			return clampf(p.y / ph, 0.0, 1.0)
		2:
			return clampf(1.0 - p.x / pw, 0.0, 1.0)
		3:
			return clampf(1.0 - p.y / ph, 0.0, 1.0)
	return clampf(p.x / pw, 0.0, 1.0)


## Fundo da transição: as camadas de terra somem aos poucos e os canos da fábrica aparecem.
func _draw_transition_back() -> void:
	var half := Vector2(VIEW.x, VIEW.x) / 2.0 + Vector2(24, 24)   # quadrado: a fase pode estar girada
	var bc := _bg_cam - _bg_shift   # o fundo está deslocado (paralaxe)
	var lo := (-_bg_shift).max(Vector2.ZERO)
	var hi := Vector2(_bw, _bh) - _bg_shift.max(Vector2.ZERO)
	var x0 := maxi(int(bc.x - half.x), int(lo.x))
	var x1 := mini(int(bc.x + half.x), int(hi.x))
	var y0 := maxi(int(bc.y - half.y), int(lo.y))
	var y1 := mini(int(bc.y + half.y), int(hi.y))
	var pal: Array = C_SOIL["despensa"]
	x0 -= x0 % 8
	y0 -= y0 % 8
	# camadas de terra e canos, em pedaços de 8 px: cada pedaço com a mistura do lugar
	for k in range(maxi(y0 / 64 - 1, 0), y1 / 64 + 2):
		var by := k * 64 + absi(k * 7919) % 24
		var py := k * 64 + 24 + absi(k * 2654435761) % 20
		var xx := x0
		while xx < x1:
			var f := clampf(float(xx) / _bw, 0.0, 1.0)
			if by < _bh - 12 and f < 0.85:
				draw_rect(Rect2(xx, by + roundf(sin(xx * 0.035 + k * 1.7) * 4.0), 8, 3), Color(pal[2], 0.22 * (1.0 - f)))
			var fp := clampf(float(xx) / _bw, 0.0, 1.0)
			if py < _bh - 12 and fp > 0.3:
				draw_rect(Rect2(xx, py, 8, 5), Color(C_STEEL_LIGHT, 0.16 * fp))
				draw_rect(Rect2(xx, py, 8, 1), Color(C_STEEL_LIGHT, 0.22 * fp))
			xx += 8
	# raízes no começo, dutos verticais no fim
	for i in range(int(x0 / 26), int(x1 / 26) + 1):
		var hh := absi(i * 2654435761)
		var rx := i * 26 + hh % 18
		if rx < 10 or rx > _bw - 12:
			continue
		var f := clampf(float(rx) / _bw, 0.0, 1.0)
		if f < 0.45:
			for yy in range(maxi(y0, 0), mini(30 + hh % 70, y1), 2):
				draw_rect(Rect2(rx + roundf(sin(yy * 0.12 + i) * 2.0), yy, 1, 2), Color(C_ROOT, 0.35 * (1.0 - f / 0.45)))
		elif f > 0.6 and i % 3 == 0:
			draw_rect(Rect2(rx, y0, 6, y1 - y0), Color(C_STEEL_LIGHT, 0.10 * f))
			draw_rect(Rect2(rx, y0, 1, y1 - y0), Color(C_STEEL_LIGHT, 0.16 * f))


## Amortecedores das salas com limitador: um por trecho do teto da fase como foi desenhada.
func _find_anchors() -> void:
	anchors.clear()
	if not def.get("limiter", false):
		return
	for a in actors:
		if a.has_method("limiter_source"):
			return   # um ator faz o papel do amortecedor (o Gatsby na corrida)
	var n := maxi(1, gw / 26)
	for k in n:
		var c := clampi(int((k + 0.5) * gw / n), 2, gw - 3)
		for dc in [0, 1, -1, 2, -2, 3, -3]:
			var cc: int = c + dc
			var found := false
			for r in gh - 2:
				if tiles[r * gw + cc] != 0 and tiles[(r + 1) * gw + cc] == 0:
					anchors.append({"rect": Rect2i(cc * TILE, r * TILE, TILE, TILE), "facing": 2})
					found = true
					break
			if found:
				break


## Cristal vermelho (subsolo) ou estabilizador com antena (fábrica). Pulsa forte enquanto o
## giro está "esticado" (o limitador conta), e solta uma onda quando puxa a sala de volta.
func _draw_anchors() -> void:
	if anchors.is_empty():
		return
	var live := limit_t > 0
	var pulse := (0.28 + 0.18 * sin(frame * 0.35)) if live else (0.07 + 0.03 * sin(frame * 0.05))
	for an in anchors:
		var rc: Rect2i = an["rect"]
		var dv: Vector2 = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][an["facing"]]
		var basep := Vector2(rc.position) + Vector2(4, 4) + dv * 4.0
		draw_set_transform_matrix(_base * Transform2D((an["facing"] - 2) * PI / 2.0, basep))
		draw_circle(Vector2(0, 5), 9.0, Color(C_ANCHOR, pulse * 0.6))
		if theme == "industrial":
			draw_rect(Rect2(-6, 0, 12, 5), C_STEEL[1])
			draw_rect(Rect2(-6, 4, 12, 1), C_SEAM)
			draw_rect(Rect2(-5, 1, 1, 1), C_RIVET)
			draw_rect(Rect2(4, 1, 1, 1), C_RIVET)
			draw_line(Vector2(0, 5), Vector2(0, 10), C_RIVET, 1.0)
			draw_rect(Rect2(-1, 10, 3, 3), C_ANCHOR if live or (frame / 30) % 2 == 0 else Color(C_ANCHOR, 0.4))
		else:
			var dark := Color(C_ANCHOR, 1.0).darkened(0.45)
			draw_colored_polygon(PackedVector2Array([Vector2(-6, 0), Vector2(-2, 0), Vector2(-4, 5)]), dark)
			draw_colored_polygon(PackedVector2Array([Vector2(2, 0), Vector2(6, 0), Vector2(4, 6)]), dark)
			draw_colored_polygon(PackedVector2Array([Vector2(-2.5, 0), Vector2(2.5, 0), Vector2(0, 10)]), Color(C_ANCHOR, 1.0).darkened(0.15))
			draw_line(Vector2(0, 1), Vector2(0, 7), Color(1, 0.75, 0.78, 0.5 + pulse), 1.0)
		if anchor_fx > 0:
			var kf := 1.0 - float(anchor_fx) / 24.0
			draw_arc(Vector2(0, 5), 6.0 + kf * 40.0, 0.0, TAU, 28, Color(C_ANCHOR, 0.6 * (1.0 - kf)), 1.0)
	draw_set_transform_matrix(_base)


## De onde vem o puxão do limitador: o ator que faz esse papel (o Gatsby na corrida) ou o
## amortecedor mais perto do coelho (a ponta do cristal). Vector2 em px da sala, ou null.
func _limiter_source() -> Variant:
	for a in actors:
		if a.has_method("limiter_source"):
			return a.limiter_source()
	var best: Variant = null
	var rc := Vector2(rabbit.pos) + Vector2(6, 6)
	for an in anchors:
		var rr: Rect2i = an["rect"]
		var dv: Vector2 = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][an["facing"]]
		var tip := Vector2(rr.position) + Vector2(4, 4) + dv * 13.0
		if best == null or tip.distance_to(rc) < (best as Vector2).distance_to(rc):
			best = tip
	return best


## O laser do limitador: enquanto o tempo corre, um fio vermelho fraco liga a fonte ao coelho (fica
## mais forte no fim); quando desfaz o giro, um feixe forte. Mostra quem puxou a sala de volta.
func _draw_limiter_beam() -> void:
	if not def.get("limiter", false) or (limit_t <= 0 and anchor_fx <= 0):
		return
	var src: Variant = _limiter_source()
	if src == null:
		return
	var a: Vector2 = src
	var b := Vector2(rabbit.pos) + Vector2(6, 6)
	draw_set_transform_matrix(_base)
	if anchor_fx > 0:
		var kf := float(anchor_fx) / 24.0
		draw_line(a, b, Color(C_ANCHOR, 0.30 * kf), 6.0)
		draw_line(a, b, Color(C_ANCHOR, 0.9 * kf), 2.0)
		draw_line(a, b, Color(1, 0.85, 0.85, 0.8 * kf), 1.0)
		draw_circle(b, 7.0 * kf + 2.0, Color(C_ANCHOR, 0.35 * kf))
		draw_circle(a, 4.0, Color(C_ANCHOR, 0.6 * kf))
	elif limit_t > 0:
		var end := 1.0 - limiter_ratio()          # 0 no começo, 1 quando vai desfazer
		var al := 0.10 + 0.35 * end * end + 0.05 * sin(frame * 0.4)
		var n := int(a.distance_to(b) / 4.0)
		for i in n:
			# fio tracejado que corre da fonte para o coelho
			if (i + frame / 3) % 3 != 0:
				draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), Color(C_ANCHOR, al), 1.0)
		draw_circle(a, 2.0 + 2.0 * end, Color(C_ANCHOR, 0.25 + 0.4 * end))


## O despertar (fase 3): encurralado, o coelho se assusta ("!") antes de descobrir a batida; na
## primeira, um clarão azul.
func _draw_awaken() -> void:
	draw_set_transform_matrix(_base)
	if awaken_t >= 20 and awaken_t < 150 and not awakened:
		var p := Vector2(rabbit.pos) + Vector2(13, -13 + (1 if (awaken_t / 8) % 2 == 0 else 0))
		draw_rect(Rect2(p, Vector2(2, 5)), C_EDGE)
		draw_rect(Rect2(p + Vector2(0, 6), Vector2(2, 2)), C_EDGE)
	if awaken_flash > 0:
		var a := float(awaken_flash) / 30.0
		draw_rect(Rect2(0, 0, pw, ph), Color(C_FLIP, 0.35 * a * a))


## Comporta: bloco escuro com barras. Ao abrir, as barras encolhem para o centro e somem.
func _draw_gates() -> void:
	for g in gates:
		var k: float = g["anim"]  # 0 fechada, 1 aberta
		var fx := float(g["fx"]) / float(SWITCH_FRAMES)
		var inv: bool = g.get("inverse", false)
		if inv:
			_draw_inverse_gate(g, k, fx)
			continue
		if k >= 1.0 and fx <= 0.0:
			continue
		for gr in g["rects"]:
			var r := Rect2(gr)
			if k < 1.0:
				var inner := r.grow(-3.5 * k)
				draw_rect(inner, Color(C_GATE_DARK, 1.0 - k))
				draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y * 0.25, inner.size.x, 1), Color(C_GATE, 1.0 - k))
				draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y * 0.7, inner.size.x, 1), Color(C_GATE, 1.0 - k))
				draw_rect(Rect2(inner.position.x + inner.size.x * 0.25, inner.position.y, 1, inner.size.y), Color(C_GATE, 0.6 * (1.0 - k)))
				draw_rect(Rect2(inner.position.x + inner.size.x * 0.7, inner.position.y, 1, inner.size.y), Color(C_GATE, 0.6 * (1.0 - k)))
			if fx > 0.0:
				draw_rect(r.grow(1.0 + 2.0 * (1.0 - fx)), Color(C_GATE, 0.5 * fx), false, 1.0)


## Comporta inversa: âmbar, com hachura em X. Fica fechada quando o compartimento do mesmo
## número está cheio e aberta quando está vazio (o contrário da comporta comum). Aberta, só
## um contorno tênue.
func _draw_inverse_gate(g: Dictionary, k: float, fx: float) -> void:
	for gr in g["rects"]:
		var r := Rect2(gr)
		var solid := 1.0 - k
		if solid > 0.0:
			var inner := r.grow(-3.5 * k)
			draw_rect(inner, Color(C_IGATE_DARK, solid))
			draw_line(inner.position, inner.end, Color(C_IGATE, solid), 1.0)
			draw_line(Vector2(inner.end.x, inner.position.y), Vector2(inner.position.x, inner.end.y), Color(C_IGATE, solid), 1.0)
			draw_rect(inner, Color(C_IGATE, 0.7 * solid), false, 1.0)
		if k > 0.0:
			draw_rect(r.grow(-1.0), Color(C_IGATE, 0.22 * k), false, 1.0)
		if fx > 0.0:
			draw_rect(r.grow(1.0 + 2.0 * (1.0 - fx)), Color(C_IGATE, 0.5 * fx), false, 1.0)


## Plataforma por orientação: sólida (preenchida) só com a seta para cima; fora disso, contorno
## tracejado com a seta mostrando para onde ela precisa apontar.
func _draw_platforms() -> void:
	for p in platforms:
		var r := Rect2(p["rect"])
		var fx := float(p["fx"]) / float(SWITCH_FRAMES)
		if p["oneway"]:
			_draw_pass_bar(p, r)
		elif p["solid"]:
			# barra sólida: placa cheia, borda nos quatro lados e rebites (bloqueia de todo lado)
			draw_rect(r, C_PLAT_DARK)
			draw_rect(r, C_PLAT, false, 1.0)
			draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1)), Color(C_PLAT, 0.7))
			for q in [Vector2(1, 1), Vector2(6, 1), Vector2(1, 6), Vector2(6, 6)]:
				draw_rect(Rect2(r.position + q, Vector2(1, 1)), C_PLAT)
			draw_colored_polygon(_tri_points(p["rect"], p["facing"], [Vector2(2.5, 6.0), Vector2(4, 3.5), Vector2(5.5, 6.0)]), Color(C_PLAT, 0.8))
		else:
			var col := Color(C_PLAT, 0.4)
			for i in 4:
				var a := Vector2(i * 2, 0)
				draw_rect(Rect2(r.position + a, Vector2(1, 1)), col)
				draw_rect(Rect2(r.position + Vector2(i * 2 + 1, 7), Vector2(1, 1)), col)
				draw_rect(Rect2(r.position + Vector2(0, i * 2 + 1), Vector2(1, 1)), col)
				draw_rect(Rect2(r.position + Vector2(7, i * 2), Vector2(1, 1)), col)
			draw_colored_polygon(_tri_points(p["rect"], p["facing"], [Vector2(1.5, 6.5), Vector2(4, 2), Vector2(6.5, 6.5)]), Color(C_PLAT, 0.6))
		if fx > 0.0:
			draw_rect(r.grow(1.0 + 2.0 * (1.0 - fx)), Color(C_PLAT, 0.6 * fx), false, 1.0)


## Barra de passagem: ativa (seta para cima), só um trilho fino em cima, vazado embaixo, com
## setinhas subindo devagar por baixo dele: "dá para atravessar pulando". Inativa, o contorno
## pontilhado e a seta, mais apagados que os da barra sólida.
func _draw_pass_bar(p: Dictionary, r: Rect2) -> void:
	var col := C_PASS
	if p["solid"]:
		draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), col)
		draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(r.size.x, 1)), Color(col, 0.35))
		draw_rect(Rect2(r.position + Vector2(0, 0), Vector2(1, 4)), Color(col, 0.6))
		draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 0), Vector2(1, 4)), Color(col, 0.6))
		# setinhas subindo, em loop, por baixo do trilho
		var k := float((frame + int(r.position.x) * 3) % 40) / 40.0
		var cy := r.position.y + 8.0 - k * 5.0
		var ca := Color(col, 0.55 * sin(k * PI))
		var cx := r.position.x + 4.0
		draw_line(Vector2(cx - 2, cy + 2), Vector2(cx, cy), ca, 1.0)
		draw_line(Vector2(cx, cy), Vector2(cx + 2, cy + 2), ca, 1.0)
	else:
		var c2 := Color(col, 0.3)
		for i in 4:
			draw_rect(Rect2(r.position + Vector2(i * 2, 0), Vector2(1, 1)), c2)
			draw_rect(Rect2(r.position + Vector2(i * 2 + 1, 7), Vector2(1, 1)), c2)
		draw_colored_polygon(_tri_points(p["rect"], p["facing"], [Vector2(2, 6), Vector2(4, 3), Vector2(6, 6)]), Color(col, 0.45))


## Ralo: grade redonda com raios; gira enquanto engole água.
func _draw_drains() -> void:
	for d in drains:
		var c := Vector2(d["rect"].position) + Vector2(4, 4)
		draw_circle(c, 4.0, Color(C_DRAIN, 0.25))
		draw_arc(c, 3.5, 0.0, TAU, 16, C_DRAIN, 1.0)
		for i in 3:
			var a: float = d["spin"] + i * PI / 3.0
			var v := Vector2(cos(a), sin(a)) * 3.0
			draw_line(c - v, c + v, C_DRAIN, 1.0)


## Corda: uma linha pelos pontos simulados. Presa no teto (dá para agarrar) ou na mão do
## coelho, na cor cheia; nas outras orientações, apagada.
func _draw_ropes() -> void:
	for rp in ropes:
		var pts: PackedVector2Array = rp["pts"]
		var live: bool = rp["facing"] == 2 or (rabbit != null and rabbit.rope == rp)
		var col := C_ROPE if live else Color(C_ROPE, 0.5)
		draw_polyline(pts, col, 1.0)
		var tip := pts[pts.size() - 1].floor()
		draw_rect(Rect2(tip - Vector2(1, 1), Vector2(3, 3)), col)
		draw_rect(Rect2(rp["anchor"] - Vector2(1, 1), Vector2(3, 3)), C_ROPE)


## Água: uma faixa por coluna, da superfície ao fundo, com a linha da superfície mais clara.
## Colunas vizinhas iguais viram um retângulo só. Cascatas: um fio da soleira até a água.
func _draw_water() -> void:
	if water_vol <= 0.0:
		return
	var body := Color(C_ACID, 0.62) if fluid_acid else Color(C_WATER, 0.55)
	var top := Color(C_ACID_TOP, 0.95) if fluid_acid else Color(C_WATER_TOP, 0.85)
	var run_x := 0
	var run_y0 := -1
	var run_y1 := -1
	var run_w := 0
	for k in wt_x.size():
		var y0 := -1
		var y1 := -1
		if wt_h[k] >= 0.5:
			var b := wt_bot[k] - wt_air[k]
			y1 = roundi(b)
			y0 = mini(roundi(b - wt_h[k] + wt_o[k]), y1 - 1)
		if run_w > 0 and y0 == run_y0 and y1 == run_y1 and wt_x[k] == run_x + run_w:
			run_w += 1
			continue
		if run_w > 0:
			_water_run(run_x, run_y0, run_y1, run_w, body, top)
		run_w = 0
		if y1 > y0:
			run_x = wt_x[k]
			run_y0 = y0
			run_y1 = y1
			run_w = 1
	if run_w > 0:
		_water_run(run_x, run_y0, run_y1, run_w, body, top)
	# bolhas
	for b in bubbles:
		var k: int = b["k"]
		if k >= wt_x.size():
			continue
		var bp := Vector2(wt_x[k] + sin(frame * 0.15 + b["ph"]) * 1.2, b["y"])
		var bc := C_ACID_TOP if fluid_acid else C_WATER_TOP
		if b["r"] < 1.2:
			draw_rect(Rect2(bp.round(), Vector2(1, 1)), Color(bc, 0.8))
		else:
			draw_arc(bp, b["r"], 0.0, TAU, 8, Color(bc, 0.85), 1.0)
			draw_rect(Rect2((bp + Vector2(-0.5, -0.8)).round(), Vector2(1, 1)), Color(1, 1, 1, 0.6))
	for e in we_a.size():
		var q := we_fall[e]
		if absf(q) < 0.004:
			continue
		var to := we_b[e] if q > 0.0 else we_a[e]
		var y_from := float(we_sill[e])
		var y_to := wt_bot[to] - wt_air[to] - wt_h[to]
		if y_to > y_from + 1.0:
			var w := 2.0 if absf(q) > 0.05 else 1.0
			var x := float(wt_x[to]) if q > 0.0 else float(wt_x[to]) + 1.0 - w
			draw_rect(Rect2(x, y_from, w, y_to - y_from), Color(C_ACID_TOP if fluid_acid else C_WATER_TOP, clampf(absf(q) * 30.0, 0.35, 0.8)))


## Um trecho de líquido com a mesma superfície: corpo, mais escuro no fundo, manchas de luz que
## correm dentro, a linha da superfície e um brilho que cintila logo abaixo dela.
func _water_run(x: int, y0: int, y1: int, w: int, body: Color, top: Color) -> void:
	var h := y1 - y0
	draw_rect(Rect2(x, y0, w, h), body)
	if h > 6:
		var deep := Color(0.0, 0.05, 0.12, 0.16) if not fluid_acid else Color(0.05, 0.12, 0.0, 0.18)
		draw_rect(Rect2(x, y0 + h * 0.45, w, h * 0.55), deep)
		draw_rect(Rect2(x, y0 + h * 0.75, w, h * 0.25), deep)
	# manchas de luz (cáusticas): pontos que andam devagar
	if h > 4:
		var lc := Color(C_ACID_TOP if fluid_acid else C_WATER_TOP, 0.13)
		var xx := x - x % 5
		while xx < x + w:
			if xx >= x:
				var cy := y0 + 2 + int(fposmod(xx * 1.7 + frame * 0.35 + sin(xx * 0.2) * 9.0, maxf(h - 3, 1)))
				draw_rect(Rect2(xx, cy, 2, 1), lc)
			xx += 5
	draw_rect(Rect2(x, y0, w, 1), top)
	# cintilado sob a superfície
	for i in w:
		var px := x + i
		if sin(px * 0.45 + frame * 0.09) + sin(px * 0.17 - frame * 0.05) > 1.35:
			draw_rect(Rect2(px, y0 + 1, 1, 1), Color(1, 1, 1, 0.35))


func _draw_rabbit(base: Transform2D) -> void:
	var fr := _rabbit_frame()
	var pivot := Vector2(rabbit.pos.x + 6, rabbit.pos.y + 12)
	var sc := Vector2(rabbit.squash.x * rabbit.facing, rabbit.squash.y)
	if rabbit.push_t > 0:
		# inclina o corpo para a frente, fazendo força
		pivot.x += rabbit.facing
		sc *= Vector2(1.06, 0.94)
	var alpha := 1.0
	if state == "won":
		# o coelho é puxado para dentro da porta, encolhendo
		var t := 1.0 - float(timer) / float(WIN_FRAMES)
		var k := smoothstep(0.0, 0.5, t)
		var target := Vector2(door.position) + Vector2(door.size) / 2.0 + Vector2(0, 6)
		pivot = pivot.lerp(target, k)
		sc *= 1.0 - 0.85 * k
		alpha = 1.0 - smoothstep(0.35, 0.55, t)
		fr = [_rabbit_tex("back", "air", false), 0]
	if alpha <= 0.0 or (invuln / 3) % 2 == 1:
		return
	var spin := 0.0
	var off := Vector2(-6, -16 + fr[1])
	if flip_t > 0 and state != "won":
		# cambalhota: uma volta inteira em torno do meio do corpo, encolhendo no meio dela
		var t := 1.0 - float(flip_t) / float(FLIP_FRAMES)
		spin = flip_dir * TAU * _ease(t)
		sc *= 1.0 - 0.35 * sin(PI * t)
		pivot.y -= 6.0
		off.y += 6.0
	draw_set_transform_matrix(base * Transform2D(-view_angle + spin, sc, 0.0, pivot))
	draw_texture(fr[0], off, Color(1, 1, 1, alpha))
	draw_set_transform_matrix(base)


## Feixe de luz subindo da porta ao vencer. Fica atrás das paredes, então é cortado por elas.
func _draw_door_beam() -> void:
	if state != "won" and state != "done":
		return
	var t := 1.0 - float(timer) / float(WIN_FRAMES)
	var beam := sin(clampf(t / 0.8, 0.0, 1.0) * PI)
	var c := Vector2(door.position.x + door.size.x / 2.0, door.position.y)
	draw_rect(Rect2(c.x - 3.0 - 3.0 * beam, 0.0, 6.0 + 6.0 * beam, c.y), Color(1.0, 0.93, 0.55, 0.22 * beam))
	draw_rect(Rect2(c.x - 1.0, 0.0, 2.0, c.y), Color(1.0, 0.98, 0.8, 0.5 * beam))


## Sensor ativando: uma linha de varredura cruza o compartimento e um contorno fino se expande.
func _draw_sensor_fx(s: Rect2i, i: int) -> void:
	if i >= socket_fx.size() or socket_fx[i] <= 0:
		return
	var t := 1.0 - float(socket_fx[i]) / float(SENSOR_FRAMES)  # 0 -> 1
	var on: bool = socket_filled[i] == true
	var col := _socket_color(i, on)
	var r := Rect2(s)
	# contorno que se expande e some
	draw_rect(r.grow(1.0 + 4.0 * t), Color(col, 0.7 * (1.0 - t)), false, 1.0)
	# linha de varredura (desce ao ativar, sobe ao desativar)
	var yy := r.position.y + 2.0 + (r.size.y - 5.0) * (t if on else 1.0 - t)
	draw_rect(Rect2(r.position.x + 2.0, floorf(yy), r.size.x - 4.0, 1.0), Color(1.0, 0.97, 0.8, 0.9 * (1.0 - t)))


func _draw_door() -> void:
	var r := Rect2(door)
	if not door_open:
		# Fechada: translúcida e vazada, para não parecer um bloco sólido (dá para atravessar).
		draw_rect(r, Color(C_DOOR_LOCKED, 0.35))
		draw_rect(r, C_DOOR_LOCKED, false, 1.0)
		draw_rect(r.grow(-3.0), Color(C_DOOR_LOCKED_DARK, 0.5))
		var c := r.position + r.size / 2.0
		draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), Color(C_DOOR_LOCKED, 0.8))
		return

	# Porta aberta: um vão escuro com moldura amarela e luz pulsando por dentro.
	var ph_ := sin(frame * 0.1) * 0.5 + 0.5
	var pulse := float(door_flash) / 14.0
	var win_t := 0.0
	if state == "won" or state == "done":
		win_t = 1.0 - float(timer) / float(WIN_FRAMES)
	# ao vencer: clarão, depois a porta se fecha em uma linha
	var close := smoothstep(0.6, 1.0, win_t)
	var center := r.position + r.size / 2.0
	var sz := r.size
	if sz.x <= sz.y:
		sz.x *= 1.0 - close
	else:
		sz.y *= 1.0 - close
	r = Rect2(center - sz / 2.0, sz)
	if r.size.x < 1.0 or r.size.y < 1.0:
		return

	draw_rect(r.grow(3.0 + 3.0 * pulse), Color(C_DOOR_OPEN, 0.07 + 0.06 * ph_ + 0.2 * pulse))
	draw_rect(r.grow(1.0), Color(C_DOOR_OPEN, 0.22))
	draw_rect(r, C_DOOR_OPEN)
	if r.size.x > 4.0 and r.size.y > 4.0:
		var inner := r.grow(-2.0)
		draw_rect(inner, C_DOOR_INNER)
		draw_rect(inner.grow(-1.0), Color(C_DOOR_OPEN, 0.18 + 0.16 * ph_))
		# faíscas subindo dentro do vão
		for i in 4:
			var px := inner.position.x + 1.0 + fmod(i * 5.3 + 2.0, maxf(inner.size.x - 2.0, 1.0))
			var py := inner.end.y - 1.0 - fmod(frame * (0.25 + 0.07 * i) + i * 9.0, maxf(inner.size.y - 1.0, 1.0))
			draw_rect(Rect2(floorf(px), floorf(py), 1, 1), Color(1.0, 0.95, 0.7, 0.9))
	# clarão quando o coelho entra
	if win_t > 0.0:
		var f := sin(clampf(win_t / 0.7, 0.0, 1.0) * PI)
		draw_rect(r.grow(5.0 * f), Color(1.0, 0.96, 0.75, 0.55 * f))

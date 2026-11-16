extends RefCounted
## Salas do piloto. Cada sala é uma grade de tiles de 8 px, de qualquer tamanho
## (todas as linhas com o mesmo comprimento, cercadas de parede).
##
## Legenda:
##   #  parede             .  vazio
##   P  coelho (bloco 2x2)  B  caixa (bloco 2x2)
##   S  compartimento da porta (bloco 2x2)
##   D  porta (retângulo)
##   1..9  comporta: parede que some enquanto os compartimentos dela têm caixa
##   a..i  compartimento de comporta (bloco 2x2): "a" abre a comporta "1", "b" a "2"...
##   = } _ {  plataforma por orientação, com a seta para cima, direita, baixo, esquerda;
##            só é sólida quando a seta aponta para cima na tela
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
## "music" (opcional): faixa da sala; sem o campo, toca DEFAULT_MUSIC. Se duas salas
## seguidas usam a mesma faixa, ela continua sem reiniciar.

const DEFAULT_MUSIC := "res://music/first-levels-theme.mp3"

const VERTIGEM := {
		# Desenhada na orientação em que a 1ª etapa se resolve; começa girada (alta), como o
		# esboço. Etapa 1: o puzzle do esboço abre a comporta. Etapa 2: derrubar a caixa no
		# poço, girar de novo; a caixa escorrega até "S" e as plataformas viram ponte sobre
		# os espinhos até a porta.
		"name": "Vertigem",
		"rotate": true,
		"start_rot": -1,
		"rows": [
			"######################################",
			"#..................#.................#",
			"#..................#.............DDDD#",
			"#..................#.............DDDD#",
			"#PP................#.................#",
			"#PP................#.................#",
			"#..................#.................#",
			"#..................#..............{..#",
			"#..................#..............{.<#",
			"###................#..............{.<#",
			"###BB..............#..............{.<#",
			"###BB..............#..............{.<#",
			"###................1..............{..#",
			"#..................1.................#",
			"#..................1BB...............#",
			"#..................1BB...............#",
			"#............##########..............#",
			"#................aa####............SS#",
			"#................aa####^^^^^^^^^^^^SS#",
			"######################################",
		],
}

const DERRAME := {
		# Etapa 1: caixa no nicho "a" mantém a comporta aberta. Etapa 2: caixa no nicho "S"
		# e giro de 180° até a porta pendurada no teto. Os dois nichos se abrem para a
		# esquerda: girar no sentido horário os mantém; anti-horário derrama as duas caixas.
		"name": "Derrame",
		"rotate": true,
		"start_rot": 0,
		"rows": [
			"####################################",
			"#...............#.........DD.......#",
			"#...............#.........DD.......#",
			"#...............#.........DD.......#",
			"#...............#.........DD.......#",
			"#...............#..................#",
			"#...............#..................#",
			"#...............#..................#",
			"#...............1..................#",
			"#...............1..................#",
			"#...............1..................#",
			"#...............1..................#",
			"#..........#########..........######",
			"#PP.BB........aa####.....BB......SS#",
			"#PP.BB........aa####.....BB......SS#",
			"####################################",
		],
}

const ESPINHOS := {
		# Pular e girar no ar para cruzar o campo de espinhos; a caixa atravessa pelo chão e
		# cai no buraco junto à parede. A parede da direita tem espinhos: as plataformas na
		# frente deles só existem depois do giro e amparam o coelho. A volta é outro pulo
		# com giro, no sentido oposto, até a porta.
		"name": "Espinhos",
		"rotate": true,
		"start_rot": 0,
		"rows": [
			"############################",
			"#..........................#",
			"#..........................#",
			"#..........................#",
			"#..........................#",
			"#..........................#",
			"#..........................#",
			"#..........................#",
			"#..........................#",
			"#........................{<#",
			"#........................{<#",
			"#........................{<#",
			"#........................{<#",
			"#DD......................{<#",
			"#DD......................{<#",
			"#DDPP.BB..................<#",
			"#DDPP.BB.^^^^^^^^^^^^^^...<#",
			"#########################SS#",
			"#########################SS#",
			"############################",
		],
}

const FUGA := {
	# Sala alta, com o limitador: cada giro dura 2,5 s e é desfeito sozinho. Embaixo: pular e
	# girar no ar para cruzar os espinhos; ao voltar, a caixa cai no buraco "a" e abre a
	# comporta do teto. Volta pelo ar, e a escadaria de plataformas (só sólidas sem giro)
	# sobe até a comporta. Em cima: a porta está na parede da direita, alta demais. Dá para
	# chegar ao pé da parede e girar no sentido horário: a parede vira chão por 2,5 s, tempo
	# de subir por ela, pulando os espinhos, até a porta; o teto é de espinhos e há uma
	# plataforma de espinhos suspensa acima da porta.
	"name": "Fuga",
	"door_open": true,
	"rotate": true,
	"limiter": true,
	"start_rot": 0,
	"rows": [
		"################################",
		"#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvv#",
		"#..............................#",
		"#..............................#",
		"#..............................#",
		"#..........................^^^^#",
		"#..........................#####",
		"#..........................DDDD#",
		"#..........................DDDD#",
		"#..............................#",
		"#..............................#",
		"#.............................<#",
		"#.............................<#",
		"#..............................#",
		"#..............................#",
		"#..............................#",
		"#111############################",
		"#..............................#",
		"#..............................#",
		"#===...........................#",
		"#..............................#",
		"#...===........................#",
		"#..............................#",
		"#..............................#",
		"#......===...................{<#",
		"#............................{<#",
		"#............................{<#",
		"#...===......................{<#",
		"#............................{<#",
		"#............................{<#",
		"#===...PPBB...................<#",
		"#......PPBB.^^^^^^^^^^^^^^^...<#",
		"#############################aa#",
		"#############################aa#",
		"################################",
		"################################",
	],
}

const PASSOS := {
	# A primeira sala: andar, empurrar a caixa para o buraco, entrar na porta.
	"name": "Primeiros passos",
	"hint": "Ande com A/D ou as setas  ·  Pule com W, seta para cima ou Espaço",
	"hint_touch": "Ande com o joystick  ·  Pule com o botão grande",
	"rotate": false,
	"start_rot": 0,
	"rows": [
		"####################",
		"#..................#",
		"#..................#",
		"#...............DD.#",
		"#...............DD.#",
		"#.PP...BB.......DD.#",
		"#.PP...BB.......DD.#",
		"###########SS#######",
		"###########SS#######",
		"####################",
	],
}

const DEGRAUS := {
	# Pular: um degrau baixo, um bloco de 3 tiles e um vão no chão; depois, a caixa no buraco.
	"name": "Degraus",
	"rotate": false,
	"start_rot": 0,
	"rows": [
		"#############################",
		"#...........................#",
		"#...........................#",
		"#...........................#",
		"#...........................#",
		"#...........................#",
		"#...........................#",
		"#.........................DD#",
		"#.........###.............DD#",
		"#.PP..##..###.......BB....DD#",
		"#.PP..##..###.......BB....DD#",
		"###############..#######SS###",
		"###############..#######SS###",
		"#############################",
	],
}

const COMPORTA := {
	# Apresenta a comporta: a caixa no buraco "a" abre a passagem. Depois, um par de
	# espinhos para pular e a segunda caixa no buraco da porta. Dá para girar, mas o teto e o
	# vão acima da porta são de espinhos: girar do chão é cair neles.
	"name": "Comporta",
	"rotate": true,
	"start_rot": 0,
	"rows": [
		"##############################",
		"#vvvvvvvvvvvv1vvvvvvvvvvvvvvv#",
		"#............1...............#",
		"#............1.............^^#",
		"#............1.............###",
		"#............1.............DD#",
		"#............1.............DD#",
		"#PP..BB......1.......BB....DD#",
		"#PP..BB......1..^^...BB....DD#",
		"#########aa##############SS###",
		"#########aa##############SS###",
		"##############################",
	],
}

const GIRO := {
	# O primeiro giro. A caixa vai fácil para o buraco, mas a porta está deitada na parede
	# da direita, alta demais. Girando no sentido horário, essa parede vira chão.
	"name": "Giro",
	"hint": "Q e E giram a sala (no controle, LB e RB)",
	"hint_touch": "Os botões de seta giram a sala",
	"rotate": true,
	"start_rot": 0,
	"rows": [
		"##################",
		"#................#",
		"#................#",
		"#............DDDD#",
		"#............DDDD#",
		"#................#",
		"#................#",
		"#................#",
		"#................#",
		"#................#",
		"#.PP..BB.........#",
		"#.PP..BB.........#",
		"###########SS#####",
		"###########SS#####",
		"##################",
	],
}

const SETAS := {
	# Apresenta as plataformas por orientação. Caixa no nicho, sala virada de cabeça para
	# baixo (como em Derrame): o teto vira chão cheio de espinhos, e a fileira de setas que
	# apontava para baixo passa a apontar para cima e vira uma ponte até a porta.
	"name": "Setas",
	"rotate": true,
	"start_rot": 0,
	"rows": [
		"####################",
		"#DD..vvvvvvvv......#",
		"#DD................#",
		"#DD.__________.....#",
		"#DD................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..............#####",
		"#PP.BB...........SS#",
		"#PP.BB...........SS#",
		"####################",
	],
}

const AGUA := {
	# Apresenta a água e o ralo (esboço water-mechanics.png). A água cobre boa parte da porta e
	# a bloqueia. O ralo fica num nicho alto da parede esquerda, seco. Girando no sentido
	# anti-horário essa parede vira chão, o nicho vira um poço e a água escorre para o ralo.
	# Depois de escoar o bastante, girar de volta: a porta fica livre.
	"name": "Água",
	"door_open": true,
	"rotate": true,
	"start_rot": 0,
	"rows": [
		"########################",
		"###....................#",
		"###....................#",
		"###....................#",
		"#......................#",
		"#o.....................#",
		"#......................#",
		"###....................#",
		"###....................#",
		"###....................#",
		"###....................#",
		"###....................#",
		"###....................#",
		"###....................#",
		"###....................#",
		"###....................#",
		"###....................#",
		"###.................DD.#",
		"###~~~~~~~~~~~~~~~~~DD~#",
		"###~~PP~~~~~~~~~~~~~DD~#",
		"###~~PP~~~~~~~~~~~~~DD~#",
		"########################",
	],
}

const TOCA := {
	# Respiro de plataforma: pilares de alturas diferentes sobre espinhos; no fim, a caixa no
	# buraco abre a porta. Dá para girar, mas o teto é de espinhos e há uma plataforma de espinhos suspensa acima da porta.
	"name": "Toca",
	"rotate": true,
	"start_rot": 0,
	"rows": [
		"######################################",
		"#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv#",
		"#....................................#",
		"#....................................#",
		"#....................................#",
		"#..................................^^#",
		"#..................................###",
		"#..................................DD#",
		"#..........##.........###..........DD#",
		"#.PP..##...##....##...###...BB.....DD#",
		"#.PP..##^^^##^^^^##^^^###...BB.....DD#",
		"################################SS####",
		"################################SS####",
		"######################################",
	],
}

const PRUMO := {
	# Descer pela corda escolhe o arco. Só a parede da esquerda é segura (o resto tem
	# espinhos), e o coelho começa em pé nela, com a sala girada: a corda, presa no teto
	# desenhado, está deitada. Pular, girar a sala no ar e agarrar a corda que cai; descer
	# até a ponta e girar de novo: o arco passa pela porta.
	"name": "Prumo",
	"door_open": true,
	"rotate": true,
	"start_rot": -1,
	"rows": [
		"####################################",
		"#vvv|vvvvvvvvvvvvvvvvvvvvvvvvvvvvv<#",
		"#...|.............................<#",
		"#PP.|.............................<#",
		"#PP.|.............................<#",
		"#...|.............................<#",
		"#...|.............................<#",
		"#...|.............................<#",
		"#...|.............................<#",
		"#...|.............................<#",
		"#...|..............DD.............<#",
		"#...|..............DD.............<#",
		"#...|.............................<#",
		"#...|.............................<#",
		"#...|.............................<#",
		"#...|.............................<#",
		"#...|.............................<#",
		"#...|.............................<#",
		"#.................................<#",
		"#.................................<#",
		"#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#",
		"####################################",
	],
}

const MARE := {
	# A água como elevador, com o limitador: o giro é desfeito sozinho quando a recarga
	# termina (barra vermelha). Desenhada em pé; começa deitada, com a água espalhada pelo
	# chão. Girando, a sala vira um poço estreito e a água sobe; só as duas últimas
	# plataformas ficaram, então é a água que leva o coelho até a primeira delas. Quando o
	# limitador desfaz o giro, a água se espalha de novo e tudo cai.
	"name": "Maré",
	"door_open": true,
	"rotate": true,
	"limiter": true,
	"start_rot": -1,
	"rows": [
		"############",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		"#DD........#",
		"#DD........#",
		"#DD........#",
		"#DD........#",
		"#####......#",
		"#..........#",
		"#..........#",
		"#~~~~~~#####",
		"#~~~~~~~~~~#",
		"#~~~~~~~~~~#",
		"#~~~~~~~~~~#",
		"#~~~~~~~~~~#",
		"#PP~~~~~~~~#",
		"#PP~~~~~~~~#",
		"#~~~~~~~~~~#",
		"############",
	],
}

const REPRESA := {
	# A água alaga a porta, que está no fundo de uma cuia. Girando no sentido horário a cuia
	# derrama e a água corre para a parede da direita; voltando, ela cai na cuia da direita,
	# separada por uma plataforma, e a porta fica seca. O coelho cai junto, nas duas vezes.
	# O fundo da cuia da porta tem espinhos: é preciso pular para cair em cima da porta.
	"name": "Represa",
	"door_open": true,
	"rotate": true,
	"start_rot": 0,
	"rows": [
		"########################################",
		"#......................................#",
		"#......................................#",
		"#......................................#",
		"#......................................#",
		"#......................................#",
		"#......................................#",
		"#......................................#",
		"#......................................#",
		"#......................................#",
		"#..............PP......................#",
		"#..............PP......................#",
		"##~~~~~~~DD~##############.............#",
		"##~~~~~~~DD~##############.............#",
		"##~~~~~~~DD~##############.............#",
		"##^^^^^^^DD^##############.............#",
		"########################################",
	],
}

const NAUFRAGIO := {
	# As duas caixas precisam ir para os compartimentos do outro lado de um poço de espinhos
	# cheio de água; empurrá-las para dentro é perdê-las (afundam). Girando no sentido
	# horário, o coelho e as caixas caem rente à parede, passam do poço e se empilham na
	# parede da direita; ao voltar, as caixas caem nos compartimentos. A porta está do lado
	# de lá: a volta é a nado, por cima dos espinhos, e um espinho solitário guarda a porta.
	"name": "Naufrágio",
	"rotate": true,
	"start_rot": 0,
	"rows": [
		"########################################",
		"#......................................#",
		"#......................................#",
		"#......................................#",
		"#......................................#",
		"#......................................#",
		"#......................................#",
		"#......................................#",
		"#DD....................................#",
		"#DD....................................#",
		"#DD.PPBBBB.............................#",
		"#DD^PPBBBB.............................#",
		"###########....................####SSSS#",
		"#############~~~~~~~~~~~~~~~~~~####SSSS#",
		"#############~~~~~~~~~~~~~~~~~~#########",
		"#############~~~~~~~~~~~~~~~~~~#########",
		"#############~~~~~~~~~~~~~~~~~~#########",
		"#############~~^^^^^^^^^^^^~~~~#########",
		"########################################",
	],
}

const MERGULHO := {
	# Corda sobre a água, com a porta trancada por uma caixa: no palco do começo, empurrar a caixa para o compartimento. Depois, a corda. Desenhada depois do giro; começa com a corda no teto e a água rasa
	# no chão. Girando pendurado, o arco leva o coelho até a parede oposta, e a água escorre
	# para o poço fundo ao pé dela: cair ali é seguro, apesar dos espinhos do fundo. Quem gira
	# sem a corda cai na parte rasa. Do poço, um pulo alcança a porta na borda.
	"name": "Mergulho",
	"rotate": true,
	"start_rot": -1,
	"rows": [
		"######################",
		"###..................#",
		"###PP................#",
		"###PP................#",
		"###.-----------------#",
		"###BB................#",
		"###BB................#",
		"###..................#",
		"#SS..................#",
		"#SS..................#",
		"###..................#",
		"###..................#",
		"###..................#",
		"###..................#",
		"###..................#",
		"#....................#",
		"#....................#",
		"#....................#",
		"#....................#",
		"#....................#",
		"#....................#",
		"#....................#",
		"#....................#",
		"#....................#",
		"#....................#",
		"#....................#",
		"#..........DD........#",
		"#..........DD........#",
		"#..........DD........#",
		"#^^^^^^^^^^DD~~~~....#",
		"#############~~~~~~~~#",
		"#############~~~~~~~~#",
		"#############~~~~~~~~#",
		"#############~~~~~~~~#",
		"#############^^^^^^^^#",
		"######################",
	],
}

## Sala de início: o quadrado em que a cutscene de abertura termina (scripts/intro.gd desenha
## o mesmo quadrado, no mesmo lugar). Só o coelho e a porta, já aberta. Não é um nível.
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

## A ordem dos níveis: cada bloco apresenta um elemento numa fase curta, usa-o em puzzles e
## fecha com uma combinação.
const ROOMS := [
	# o básico
	PASSOS,     # 1  empurrar a caixa no buraco abre a porta
	DEGRAUS,    # 2  pular degraus e um vão
	GIRO,       # 3  o primeiro giro: a parede vira chão
	COMPORTA,   # 4  comporta; espinhos baixos; girar do chão é cair nos espinhos do teto
	# girar com intenção
	DERRAME,    # 5  nichos, o sentido do giro, virar a sala de cabeça para baixo
	TOCA,       # 6  respiro de plataforma: pilares sobre espinhos; teto de espinhos
	SETAS,      # 7  plataformas por orientação
	ESPINHOS,   # 8  o giro no ar valendo a vida
	# corda
	PRUMO,      # 9  agarrar a corda no giro e descer até a ponta
	VERTIGEM,   # 10 combinação
	# água
	AGUA,       # 11 a água tranca a porta; o ralo
	MARE,       # 12 a água como elevador, com o limitador
	REPRESA,    # 13 despejar a água na cuia certa
	NAUFRAGIO,  # 14 carregar as caixas pela gravidade; a volta a nado
	# tudo junto
	MERGULHO,   # 15 caixa, corda e água
	FUGA,       # 16 giro limitado até a porta, na parede
]

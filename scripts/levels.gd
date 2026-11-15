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
##
## "start_rot": quantos giros de 90° (horário > 0) aplicar ao desenho ao carregar.
## Permite desenhar a sala na orientação em que ela é resolvida e começar girada.
## Atenção: o que está solto precisa estar apoiado na orientação inicial.
## "rotate": false desliga o giro.
## "hint" (opcional): texto de ajuda mostrado embaixo da tela durante a sala.
## "music" (opcional): faixa da sala; sem o campo, toca DEFAULT_MUSIC. Se duas salas
## seguidas usam a mesma faixa, ela continua sem reiniciar.

const DEFAULT_MUSIC := "res://music/first-levels-theme.mp3"

const TOCA := {
		# Corredor sem giro. Pular o bloco; caixa no buraco "a" abre a comporta; pulos curtos
		# entre pilares sobre espinhos; segunda caixa no buraco "S" abre a porta.
		"name": "Toca",
		"rotate": false,
		"start_rot": 0,
		"rows": [
			"##############################################",
			"#....................1.......................#",
			"#....................1.......................#",
			"#....................1.......................#",
			"#....................1.......................#",
			"#....................1.......................#",
			"#....................1.......................#",
			"#....................1.....................DD#",
			"#.....###............1.....................DD#",
			"#.PP..###...BB.......1...##..##......BB....DD#",
			"#.PP..###...BB.......1.^^##^^##^^....BB....DD#",
			"#################aa######################SS###",
			"#################aa######################SS###",
			"##############################################",
		],
}

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
		# Sala alta, em duas etapas. Embaixo: pular e girar no ar para cruzar os espinhos;
		# a caixa escorrega até o buraco "a" e abre a comporta do teto. Volta pelo ar, e a
		# escadaria de plataformas (só sólidas nesta orientação, atravessáveis durante os
		# voos) sobe até a comporta. Em cima: a segunda caixa está presa entre dois tocos;
		# virar a sala de cabeça para baixo a joga no compartimento do teto, e o coelho
		# atravessa o teto (agora chão) com espinhos até a porta.
		"name": "Fuga",
		"rotate": true,
		"start_rot": 0,
		"rows": [
			"################################",
			"#............#SS#...vvv.DD.....#",
			"#............#SS#.......DD.....#",
			"#.......................DD.....#",
			"#.......................DD.....#",
			"#..............................#",
			"#..............................#",
			"#..............................#",
			"#..............................#",
			"#..............................#",
			"#..............................#",
			"#..............................#",
			"#..............................#",
			"#..............................#",
			"#............#BB#..............#",
			"#............#BB#..............#",
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
	"hint": "Ande com A/D ou as setas  ·  Pule com W, seta para cima ou Espaço\nEmpurre a caixa até o buraco para abrir a porta",
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
	# espinhos para pular e a segunda caixa no buraco da porta.
	"name": "Comporta",
	"rotate": false,
	"start_rot": 0,
	"rows": [
		"##############################",
		"#............1...............#",
		"#............1...............#",
		"#............1...............#",
		"#............1...............#",
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
	"hint": "Q e E giram a sala (no controle, LB e RB)\nTudo o que está solto cai para o novo chão",
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

## A ordem dos níveis: uma ideia nova por vez, e a dificuldade sobe aos poucos.
const ROOMS := [
	PASSOS,     # 1  empurrar a caixa no buraco abre a porta
	DEGRAUS,    # 2  pular degraus e um vão
	COMPORTA,   # 3  comporta; espinhos baixos
	TOCA,       # 4  tudo isso junto, sem girar
	GIRO,       # 5  o primeiro giro: a parede vira chão
	DERRAME,    # 6  nichos, o sentido do giro, virar a sala de cabeça para baixo
	SETAS,      # 7  plataformas por orientação
	VERTIGEM,   # 8  o esboço; a ponte que aparece ao girar
	ESPINHOS,   # 9  giro no ar
	FUGA,       # 10 síntese
]

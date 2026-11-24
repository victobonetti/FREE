"""As receitas das salas do mundo (D120). Cada uma recebe a sala (wkit.Room) já com as saídas
(rm.doors, rm.door_to(id)) e escava o conteúdo. Sala sem receita fica provisória (build_world.generic).

Regra do giro (D121): nenhuma sala pode ser atravessada só girando. Nada de muito espaço vazio em
cima com plataformas embaixo: o que separa uma saída da outra precisa de paredes, pilares e andares
que cortem as quedas compridas em qualquer giro. O check_world.gd recusa a sala que o giro pula.
"""
RECIPES = {}


def recipe(id):
    def deco(f):
        RECIPES[id] = f
        return f
    return deco


# ---------------------------------------------------------------- ajudas

PLAT = {0: "=", 1: "{", 2: "_", 3: "}"}   # a barra que fica sólida (seta para cima) no giro o


def rose_cell(n, o, sx, sy):
    """A célula da rosa (lado n) que, com a rosa girada o vezes (horário), aparece na tela em (sx, sy)."""
    if o == 0:
        return sx, sy
    if o == 1:
        return sy, n - 1 - sx
    if o == 2:
        return n - 1 - sx, n - 1 - sy
    return n - 1 - sy, sx


def rose_ladder(rm, o, plats):
    """Barras que só seguram no giro o: [(linha na tela, coluna 0, coluna 1)]."""
    for sy, a, b in plats:
        for sx in range(a, b + 1):
            c, r = rose_cell(rm.w, o, sx, sy)
            assert rm.at(c, r) == ".", "%s: a escada do giro %d bate em (%d, %d) = %r" % (rm.id, o, c, r, rm.at(c, r))
            rm.set(c, r, PLAT[o])


def only_door(rm, nb):
    """A rosa tem uma abertura só: as outras ligações dela são as posições giradas desta."""
    rm.doors = [d for d in rm.doors if d.nb == nb]


# ---------------------------------------------------------------- o Poço

@recipe("P1")
def p1(rm):
    """A queda do Campo: andares de túnel na rocha, ligados por poços em lados alternados. Descer é
    cair de andar em andar; subir pede o giro (A1). O buraco do primeiro andar é tampado de cristal
    (A6), como o fundo: de cima se vê que o poço está fechado (não é uma barra que parece passagem) e
    que o caminho é pela esquerda; na volta do fim, com a pata firme, ele quebra por baixo."""
    rm.theme = "raizes"
    rm.hint = "Ande com A/D ou as setas  ·  Pule com W, seta para cima ou Espaço\nO poço está tampado: o caminho segue pela esquerda"
    rm.carve(17, 1, 22, 14)                    # a queda da entrada
    floors = [19, 30, 41, 52, 63, 74, 85]
    for k, f in enumerate(floors):
        rm.carve(1, f - 4, rm.w - 2, f - 1)    # o andar: um túnel de 4
        if k + 1 < len(floors):
            nxt = floors[k + 1]
            a = 30 if k % 2 == 0 else 2         # o poço para o andar de baixo, em lados alternados
            rm.carve(a, f, a + 5, nxt - 5)
    rm.barrier(30, 19, 6, 2, "A6")
    rm.seal(rm.door_to("P2"), "A6")
    rm.toca(8, 19)
    rm.extra["entry_only_until"] = "L7"   # vencido o amortecedor-mor, a queda vira a subida para o Campo
    rm.notes = "O Poço (D120): a queda do começo. Andares de túnel e poços alternados (o giro não cai de uma vez)."


# ---------------------------------------------------------------- as Raízes

@recipe("r1")
def r1(rm):
    """Primeiros passos (refeita, D123): a saída para os Degraus fica no alto de uma parede de 5 (o
    pulo não alcança). A caixa é o degrau: empurrada até a parede, dá para subir. Ela fica onde o
    coelho a deixou (na volta, continua lá); R recomeça a sala com ela no lugar do começo."""
    rm.theme = "raizes"
    rm.rotate = False
    rm.extra["puzzle"] = True
    rm.carve(25, 15, 38, 18)                      # a entrada (chão 19)
    rm.carve(7, 7, 24, 17)                        # a câmara (chão 18: um degrau para cima)
    rm.carve(1, 10, 6, 12)                        # em cima da parede de 5 (cols 1..6, linhas 13..17)
    rm.block(16, 16, "B")
    for c in (10, 15, 21):
        rm.set(c, 7, "#")                         # pontas de raiz no teto
    rm.set(30, 15, "#")
    rm.notes = "Primeiros passos (refeita, D123): a caixa é o degrau até a saída no alto."


@recipe("r3")
def r3(rm):
    """Raiz torta (nova, sem giro): a caixa da prateleira cai no vão e vira o degrau da parede."""
    rm.theme = "raizes"
    rm.rotate = False
    rm.extra["puzzle"] = True
    rm.tunnel(78, 19, 62, 14)
    rm.carve(48, 9, 62, 13)          # a prateleira (chão 14)
    rm.block(52, 12, "B")
    rm.carve(33, 9, 47, 18)          # o vão (chão 19), com a parede de 5 à esquerda (cols 31..32)
    rm.carve(48, 15, 58, 18)         # embaixo da prateleira: a caixa caída não fica presa contra ela
    rm.carve(20, 9, 32, 13)          # em cima da parede
    rm.tunnel(20, 14, 1, 19)
    for c in (24, 40, 55):
        rm.set(c, 9, "#")            # pontas de raiz no teto
    rm.notes = "Raiz torta (nova): empurrar a caixa da prateleira para o vão; ela vira o degrau da parede."


@recipe("r4")
def r4(rm):
    """Toca do susto: a cápsula da batida de pata (A1) no corredor; o vão leva à câmara de baixo, onde
    as paredes só se passam girando (por cima delas há um vão estreito). O corredor segue até a
    Fresta (o segredo do giro no ar)."""
    rm.theme = "raizes"
    rm.carve(1, 16, 38, 18)
    rm.item(28, 17, "A1")
    rm.carve(19, 19, 21, 29)          # o vão para a câmara de baixo
    rm.carve(11, 30, 28, 40)          # a câmara do meio
    rm.carve(1, 30, 8, 40)            # à esquerda (saída para a Toca longa)
    rm.carve(31, 30, 38, 40)          # à direita (saída para a Comporta)
    rm.carve(9, 30, 10, 32)           # os vãos por cima das paredes (cols 9..10 e 29..30)
    rm.carve(29, 30, 30, 32)
    rm.fill(1, 30, 6, 33)             # tetos baixos dos lados: girado, não se cai reto
    rm.fill(33, 30, 38, 33)
    for c in (6, 13, 33):
        rm.set(c, 16, "#")
    rm.notes = "Toca do susto: a cápsula do giro (A1); embaixo, as paredes de 9 só passam girando."


# ---------------------------------------------------------------- as Cavernas

@recipe("c5")
def c5(rm):
    rm.theme = "raizes"
    rm.rotate = False
    rm.carve(1, 6, rm.w - 2, 18)
    rm.shaft(35, 1, 18)
    rm.ledge(46, rm.w - 2, 13)
    rm.ledge(42, 44, 16)
    rm.toca(10, 19)
    rm.item(37, 17, "A2")                         # no pé do poço da Comporta: quem desce pega
    rm.notes = "Ninho (toca de salvar, sem giro): a cápsula do giro no ar (A2), antes das salas que pedem ele (D124)."


ROT_GLYPH = {"=": "}", "}": "_", "_": "{", "{": "=", "↑": "→", "→": "↓", "↓": "←", "←": "↑",
             "^": ">", ">": "v", "v": "<", "<": "^", "|": "-", "-": "|"}


def rose_build(rm, turns=0):
    """O miolo das rosas: o patamar da abertura e as escadas de barras por giro (a abertura à
    esquerda). `turns` gira tudo (no horário) para a rosa cuja abertura, de pé, fica em outro lado."""
    rm.extra["rose"] = True
    rm.carve(1, 1, rm.w - 2, rm.h - 2)
    rm.ledge(1, 5, 13)
    rose_ladder(rm, 0, [(18, 9, 12), (15, 6, 9)])
    rose_ladder(rm, 1, [(18, 14, 17), (15, 9, 12), (12, 14, 17), (9, 9, 12), (6, 14, 17), (4, 9, 12)])
    rose_ladder(rm, 2, [(18, 11, 14), (15, 16, 18), (13, 16, 20)])
    n = rm.w
    for _ in range(turns):
        g = [["#"] * n for _ in range(n)]
        for r in range(n):
            for c in range(n):
                ch = rm.g[r][c]
                nc, nr = n - 1 - r, c
                g[nr][nc] = ROT_GLYPH.get(ch, ch)
        rm.g = g


@recipe("rA")
def rA(rm):
    """A rosa das raízes: a abertura (à esquerda, de pé) aponta para o Ninho; girada, para a Comporta
    (90°), o Derrame (180°) e os Espinhos (270°). Barras por giro fazem a escada até ela."""
    rm.theme = "caverna"
    only_door(rm, "c5")
    rose_build(rm)
    rm.notes = "Rosa das raízes (D119): a abertura gira com a sala e guarda o giro."


def spiky_shaft(rm, c0, c1, r0, r1, openings=(), bottom=True, hole=None):
    """Uma câmara (colunas c0..c1, linhas r0..r1) forrada de espinhos (paredes, fundo e teto, menos o
    vão `hole` = (col0, col1) do teto, por onde se cai) e com aberturas [(lado 'L'/'R', linha0,
    linha1)]. É a trava do giro no ar (A2): sem chão lá dentro, só girando em plena queda se cai de
    lado na abertura, longe do vão."""
    rm.carve(c0, r0, c1, r1)
    if hole is not None:
        for c in range(c0 + 1, c1):
            if not hole[0] <= c <= hole[1]:
                rm.set(c, r0, "v")
    for r in range(r0, r1 + 1):
        if not any(s == "L" and a <= r <= b for s, a, b in openings):
            rm.set(c0, r, ">")
        if not any(s == "R" and a <= r <= b for s, a, b in openings):
            rm.set(c1, r, "<")
    for s, a, b in openings:
        cc = c0 - 1 if s == "L" else c1 + 1
        rm.carve(cc, a, cc, b)
    if bottom:
        rm.spikes(c0, c1, r1, "^")


@recipe("c7")
def c7(rm):
    """Prumo (refeita): da saída do Ninho, um corredor; a corda desce o poço até o corredor de baixo
    (e sobe de volta). No corredor, um vão de 3 sobre a câmara de espinhos: caindo, só quem gira no
    ar (A2) chega à abertura do outro lado, que dá na rosa funda."""
    rm.theme = "caverna"
    rm.carve(45, 16, 78, 18)
    rm.carve(53, 19, 55, 19)                       # o vão
    spiky_shaft(rm, 52, 66, 20, 34, openings=[("R", 24, 31)], hole=(53, 55))
    rm.carve(67, 24, 72, 42)                       # a câmara sobre a rosa
    rm.carve(45, 19, 49, 40)                       # o poço da corda
    for r in range(20, 38):
        rm.set(50, r, "|")
    rm.carve(50, 38, 50, 40)
    rm.carve(1, 34, 49, 40)                        # o corredor de baixo
    rm.fill(1, 34, 8, 37)
    for a in (14, 26, 38):
        rm.spikes(a, a + 2, 40)
    rm.fill(20, 34, 22, 36)
    rm.fill(32, 34, 34, 36)
    rm.notes = "Prumo (refeita, D120): a corda no poço; o vão sobre os espinhos leva à rosa funda com o giro no ar (A2)."


@recipe("c9")
def c9(rm):
    """Galeria: duas câmaras de espinhos (do Derrame, em cima; dos Espinhos, à esquerda). Cai-se
    por um vão num canto; só girando no ar (A2) se chega à abertura do outro lado. Embaixo, o
    corredor leva à escada de volta (barras de passagem no alto) e à caixa presa (A4) da Despensa."""
    rm.theme = "caverna"
    # do Derrame: o patamar da entrada e a câmara A
    rm.carve(34, 1, 43, 3)
    rm.carve(35, 4, 37, 4)
    spiky_shaft(rm, 34, 50, 5, 20, openings=[("R", 9, 15)], hole=(35, 37))
    rm.carve(52, 9, 60, 15)
    rm.tunnel(52, 16, 62, 16)
    rm.carve(61, 16, 66, 40)                       # descida para o corredor de baixo
    rm.shaft(61, 16, 40)
    # dos Espinhos: o corredor e a câmara B
    rm.carve(1, 16, 15, 18)
    rm.carve(13, 19, 15, 19)
    spiky_shaft(rm, 12, 28, 20, 35, openings=[("R", 24, 30)], hole=(13, 15))
    rm.tunnel(30, 31, 40, 31)
    rm.carve(38, 31, 41, 36)
    # o corredor de baixo
    rm.carve(9, 37, 66, 40)
    rm.fill(24, 37, 26, 38)
    rm.fill(46, 37, 48, 38)
    # a escada de volta para o corredor dos Espinhos (barras de passagem em cima)
    rm.shaft(2, 20, 40)
    rm.carve(2, 19, 7, 19)
    rm.put(2, 19, "↑" * 6)
    rm.carve(8, 37, 8, 40)
    rm.seal(rm.door_to("d1"), "A4")
    rm.notes = "Galeria (nova): câmaras de espinhos que só se cruzam com o giro no ar (A2); a caixa presa (A4) leva à Despensa."


@recipe("cx")
def cx(rm):
    """Fresta (segredo): o poço de espinhos largo demais para pular; o coração fica no bloco do outro
    lado. Girar no chão (A1) faz cair de lado nos espinhos da parede do bloco; só pulando e girando no
    ar (A2) se voa por cima deles e se pousa no bloco."""
    rm.theme = "caverna"
    rm.carve(1, 9, 38, 18)
    rm.spikes(6, 30, 18)              # o fundo do poço (no chão)
    rm.fill(1, 14, 5, 18)             # o bloco do coração (em cima: linha 14)
    for r in range(16, 18):
        rm.set(6, r, ">")             # a cara do bloco: espinhos embaixo, rocha em cima
    rm.spikes(6, 30, 9, "v")          # o teto do poço
    rm.item(2, 12, "coracao")
    rm.notes = "Fresta (segredo): o coração 1, com o giro no ar (A2)."


# ---------------------------------------------------------------- o Aquífero

@recipe("rB")
def rB(rm):
    """A rosa funda: a abertura (em cima, de pé) dá na Prumo; girada, na câmara de cristal (90°, a
    escondida), na Represa (180°) e na Água (270°)."""
    rm.theme = "aquifero"
    only_door(rm, "c7")
    rose_build(rm, 1)
    rm.notes = "Rosa funda (D119): a abertura gira com a sala; a 90° mostra a câmara escondida."


@recipe("hx")
def hx(rm):
    rm.theme = "aquifero"
    rm.rotate = False
    rm.carve(1, 6, 34, 12)
    rm.spikes(10, 11, 12)            # espinhos de 2: o pulo passa com folga (3 era no limite)
    rm.spikes(20, 21, 12)
    rm.ledge(15, 17, 9)
    rm.item(30, 11, "coracao")
    for c in (6, 14, 25, 32):
        rm.set(c, 6, "#")
    rm.notes = "Câmara de cristal (escondida: só pela rosa funda a 90°): o coração 5."


@recipe("a6")
def a6(rm):
    rm.theme = "aquifero"
    rm.rotate = False
    rm.carve(1, 10, 38, 18)
    rm.carve(18, 19, 21, 20)
    rm.ledge(15, 24, 16)
    rm.toca(30, 19)
    rm.notes = "Fonte (toca de salvar, sem giro)."


@recipe("ax")
def ax(rm):
    rm.theme = "aquifero"
    rm.carve(60, 34, 78, 40)
    rm.carve(10, 14, 62, 41)
    rm.water(10, 22, 62, 41)
    for c in (22, 36, 50):
        rm.fill(c, 30, c + 1, 41)
    rm.item(15, 39, "coracao")
    rm.notes = "Poço d'água (segredo): o coração 2, no fundo; só afundando (A3)."


@recipe("a7")
def a7(rm):
    """Lagoa funda: cai-se no lago pela direita; a parede do meio desce até perto do fundo, e só
    afundando (A3) se passa por baixo dela até a margem da esquerda, de onde se desce para a Margem
    do Fungário (a gosma do lado de lá pede a seringa)."""
    rm.theme = "aquifero"
    rm.carve(97, 1, 102, 8)
    rm.carve(12, 9, 110, 40)
    rm.water(12, 18, 110, 40)
    rm.fill(60, 9, 63, 35)                        # a parede do meio: passa-se por baixo
    rm.fill(31, 9, 59, 17)                        # à esquerda, só a margem tem ar
    rm.ledge(12, 30, 17)
    rm.carve(26, 17, 29, 17)                      # o vão para sair d'água
    rm.ledge(92, 96, 17)                          # à direita, o patamar sob a queda
    rm.carve(9, 13, 11, 16)                       # da margem para o poço da saída
    rm.shaft(3, 13, 42)
    rm.notes = "Lagoa funda (nova): o lago se atravessa por baixo da parede (A3)."


# ---------------------------------------------------------------- a Despensa

@recipe("d1")
def d1(rm):
    rm.theme = "despensa"
    rm.rotate = False
    rm.carve(1, 10, 78, 18)
    rm.shaft(57, 1, 9)
    rm.carve(44, 19, 47, 20)
    rm.ledge(41, 50, 16)
    rm.toca(10, 19)
    rm.item(28, 17, "pista")
    for c in (18, 34, 66):
        rm.block(c, 17, "#")
    rm.notes = "Despensa (toca de salvar): nozes, uma pista; o vão desce para o Jeffrey."


@recipe("P2")
def p2(rm):
    """O Poço, no trecho da Despensa: andares de túnel como no alto. Chega-se pela Fuga (mão única); a
    raiz da noz-mestra fecha a Passagem, e os cristais (A6) fecham o Poço em cima e embaixo."""
    rm.theme = "despensa"
    rm.carve(17, 1, 22, 7)
    floors = [12, 24, 36, 51, 63, 75, 87, 99, 107]
    for k, f in enumerate(floors):
        rm.carve(1, f - 4, rm.w - 2, f - 1)
        if k + 1 < len(floors):
            a = 30 if k % 2 == 0 else 2
            rm.carve(a, f, a + 5, floors[k + 1] - 5)
    rm.toca(10, 51)
    rm.notes = "O Poço (D120), trecho da Despensa: andares de túnel e poços alternados."


@recipe("t1")
def t1(rm):
    """A Passagem (refeita, D121): a antiga tinha um salão vazio em cima das plataformas, e girada se
    caía de uma ponta à outra. Agora são quatro câmaras baixas separadas por pilares: a esteira
    contra, a plataforma que vai e vem sobre os espinhos, as chapas que desabam e o elevador que leva
    ao alto; dali, a escada desce até a Fábrica."""
    rm.theme = "transicao"
    # A: a entrada, com a esteira contra
    rm.carve(1, 15, 20, 18)
    rm.carve(17, 11, 20, 14)
    rm.add("conveyors", {"rect": [4, 19, 14, 1], "dir": -1, "speed": 30})
    # B: espinhos e a plataforma que vai e vem
    rm.carve(21, 11, 44, 18)
    rm.spikes(25, 40, 18)
    rm.fill(21, 16, 24, 18)
    rm.fill(41, 16, 44, 18)
    rm.add("movers", {"ch": 3, "off": [25, 16, 4, 1], "on": [37, 16], "speed": 40, "cycle": 3.0})
    # pilar, com o vão no meio
    rm.fill(45, 11, 47, 18)
    rm.carve(45, 13, 47, 15)
    # C: as chapas que desabam sobre os espinhos
    rm.carve(48, 11, 71, 18)
    rm.spikes(48, 67, 18)
    for c in (50, 56, 62):
        rm.add("crumbles", [c, 16, 3, 1])
    rm.fill(68, 16, 71, 18)
    rm.fill(72, 11, 74, 18)
    rm.carve(72, 13, 74, 15)
    # D: a segunda plataforma sobre o fosso, até o patamar do alto
    rm.carve(75, 9, 100, 18)
    rm.spikes(79, 100, 18)
    rm.fill(75, 16, 78, 18)
    rm.fill(86, 9, 88, 11)
    rm.fill(96, 13, 100, 18)
    rm.add("movers", {"ch": 4, "off": [79, 16, 4, 1], "on": [91, 16], "speed": 30, "cycle": 3.5})
    # E: a escada até a Fábrica
    rm.tunnel(100, 13, 118, 19)
    rm.notes = "Passagem (refeita, D121): câmaras baixas e pilares; o giro não atravessa mais a sala de uma vez."


# ---------------------------------------------------------------- a Fábrica

def floors_shaft(rm, floors, top_chute=None, a_right=30, a_left=2):
    """Um poço de andares (como o Poço): túneis de 4 nos chãos dados, ligados por poços de 6 em
    lados alternados. `top_chute` = (col0, col1): a queda da entrada, de cima até o 1º andar."""
    if top_chute:
        rm.carve(top_chute[0], 1, top_chute[1], floors[0] - 5)
    for k, f in enumerate(floors):
        rm.carve(1, f - 4, rm.w - 2, f - 1)
        if k + 1 < len(floors):
            a = a_right if k % 2 == 0 else a_left
            rm.carve(a, f, a + 5, floors[k + 1] - 5)


@recipe("f1")
def f1(rm):
    rm.theme = "industrial"
    rm.rotate = False
    rm.carve(1, 8, 38, 18)
    rm.ladder(30, 19)                             # a escada até o Escritório
    rm.carve(6, 19, 9, 20)                        # a descida para o Almoxarifado
    rm.ledge(4, 11, 16)                           # a ponte sobre ela
    rm.toca(16, 19)
    rm.notes = "Portaria (toca de salvar, sem giro): a entrada da Fábrica."


@recipe("f4")
def f4(rm):
    """Almoxarifado (novo): as duas baterias do corredor de cima soltam a caixa da calha no de baixo;
    a caixa no buraco abre as Prensas. A barra sobre o vão da Casa de força só deixa subir."""
    rm.theme = "industrial"
    rm.extra["puzzle"] = True
    rm.carve(5, 6, 64, 9)
    rm.ladder(6, 10)                              # a escada até a Portaria
    rm.shaft(59, 6, 18)
    rm.carve(20, 15, 78, 18)
    rm.set(22, 9, "+")
    rm.set(44, 9, "+")
    rm.block(48, 13, "H")
    rm.block(54, 17, "L")
    rm.block(70, 19, "S")
    rm.carve(38, 19, 41, 20)
    rm.put(38, 19, "↑" * 4)
    rm.door_to("f5").kind = "Z"
    rm.notes = "Almoxarifado (novo): baterias, a calha e a caixa no buraco."


@recipe("f7")
def f7(rm):
    """Caldeira (nova): o ácido, pela primeira vez. Poças dos dois lados, plataformas por cima; a
    caixa no buraco abre as duas saídas. Sem giro (o ácido derramaria)."""
    rm.theme = "industrial"
    rm.rotate = False
    rm.extra["puzzle"] = True
    rm.carve(1, 9, 78, 18)
    rm.carve(38, 1, 41, 8)
    for a, b in ((12, 26), (52, 66)):
        rm.carve(a, 19, b, 20)
        rm.water(a, 19, b, 20, "%")
    for c in (15, 21, 55, 61):
        rm.ledge(c, c + 2, 16)
    rm.block(32, 17, "B")
    rm.block(44, 19, "S")
    rm.door_to("f8").kind = "Z"
    rm.door_to("f9").kind = "Z"
    rm.notes = "Caldeira (nova): o ácido; a caixa no buraco abre as saídas."


@recipe("f8")
def f8(rm):
    """Tanques (nova, sem giro): o salão de cima, dos Dutos à rosa da caldeira, com um tanque de ácido
    no chão e plataformas por cima; na ponta esquerda, a descida para o corredor de baixo (até a
    Caldeira), com outra poça de ácido."""
    rm.theme = "industrial"
    rm.rotate = False
    rm.carve(69, 1, 74, 4)                        # a queda dos Dutos
    rm.carve(30, 5, 96, 12)                       # o salão de cima (chão 13)
    rm.carve(45, 13, 60, 14)
    rm.water(45, 13, 60, 14, "%")
    for c in (47, 52, 57):
        rm.ledge(c, c + 1, 10)
    rm.carve(1, 12, 34, 18)                       # o corredor de baixo (chão 19) e a descida
    rm.ledge(29, 31, 16)                          # o degrau da subida
    rm.carve(12, 19, 24, 20)
    rm.water(12, 19, 24, 20, "%")
    for c in (13, 18, 23):
        rm.ledge(c, c + 1, 16)
    rm.notes = "Tanques (nova): ácido nos dois andares; sem giro."


@recipe("rC")
def rC(rm):
    """A rosa da caldeira: de pé, dá nos Tanques; a 180°, no Elevador (com a pata firme, A6); a 270°,
    no cofre escondido do Gatsby. A 90°, rocha."""
    rm.theme = "industrial"
    only_door(rm, "f8")
    rose_build(rm)
    rm.notes = "Rosa da caldeira (D119)."


@recipe("fx")
def fx(rm):
    rm.theme = "industrial"
    rm.rotate = False
    rm.carve(3, 1, 18, 19)
    rm.ledge(3, 8, 16)
    rm.ledge(13, 18, 13)
    rm.item(15, 11, "pista")
    rm.notes = "Cofre do Gatsby (escondido: só pela rosa da caldeira a 270°): uma pista."


@recipe("fa")
def fa(rm):
    rm.theme = "industrial"
    rm.rotate = False
    rm.carve(1, 8, 38, 18)
    rm.ladder(18, 19)                             # a escada até a catraca da corrida
    rm.carve(30, 19, 33, 20)                      # a descida para a Portaria
    rm.toca(6, 19)
    rm.item(34, 17, "pista")
    rm.notes = "Escritório do Gatsby (toca de salvar): a catraca do crachá leva à corrida."


@recipe("fd")
def fd(rm):
    """Telhado (segredo): o amortecedor desfaz o giro em 2,5 s; com a pata firme (A6), não desfaz mais.
    O coração 3 fica no fim das câmaras de espinhos."""
    rm.theme = "industrial"
    rm.limiter = True
    rm.shaft(57, 1, 12)
    rm.carve(10, 8, 62, 12)
    rm.carve(10, 13, 15, 30)
    rm.carve(10, 26, 90, 30)
    for a in (24, 40, 56, 72):
        rm.spikes(a, a + 3, 30)
    rm.carve(86, 13, 90, 25)
    rm.carve(86, 9, 110, 12)
    rm.item(106, 11, "coracao")
    rm.notes = "Telhado (segredo): o coração 3."


@recipe("fp")
def fp(rm):
    """Plataforma: o telhado da fábrica, da mecha ao elevador. Câmaras baixas (o giro não atravessa)."""
    rm.theme = "industrial"
    rm.tunnel(1, 21, 30, 19)
    for k, c in enumerate(range(30, 160, 26)):
        f0 = 19 if k % 2 == 0 else 15
        f1_ = 15 if k % 2 == 0 else 19
        rm.tunnel(c, f0, c + 26, f1_)
    rm.tunnel(160, 15, 168, 19) if (160 - 30) // 26 % 2 == 1 else rm.tunnel(160, 19, 168, 19)
    rm.carve(106, 16, 113, 18)
    rm.notes = "Plataforma (D120): o telhado entre a mecha e o elevador."


@recipe("fe")
def fe(rm):
    """O elevador da fábrica (sem a cena): um poço de andares até o Fungário (mão única)."""
    rm.theme = "industrial"
    floors = [27] + list(range(38, 190, 11)) + [200, 211, 218]
    floors = sorted(set(f for f in floors if f <= 218))
    if 189 not in floors:
        floors.append(189)
        floors.sort()
    floors_shaft(rm, floors)
    rm.seal(rm.door_to("rC"), "A6")
    rm.notes = "Elevador (D120): o poço de andares até o Fungário; da rosa da caldeira, o cristal (A6)."


# ---------------------------------------------------------------- o Fungário

@recipe("g1")
def g1(rm):
    rm.theme = "fungos"
    rm.rotate = False
    rm.carve(57, 1, 62, 9)
    rm.carve(1, 10, 78, 18)
    rm.toca(40, 19)
    rm.notes = "Câmara do elevador (toca de salvar): a chegada ao Fungário (mão única)."


@recipe("g6")
def g6(rm):
    """Micélio (novo): o corredor dos Murchos acaba numa chaminé estreita entre espinhos. Girar 90°
    ali é morrer; só a meia-volta (A5, 180° de uma vez) faz o coelho cair para cima, até o corredor
    de cima. Dali, a rosa do micélio e a descida para a Colônia."""
    rm.theme = "fungos"
    rm.carve(40, 15, 96, 18)
    rm.carve(40, 5, 41, 14)
    for r in range(5, 15):
        rm.set(39, r, ">")
        rm.set(42, r, "<")
    rm.carve(20, 1, 47, 4)
    rm.shaft(14, 1, 12)
    rm.carve(1, 9, 19, 12)
    rm.shaft(2, 9, 42)
    rm.carve(2, 39, 50, 42)
    rm.door_to("g8").kind = "X"
    for c in (60, 75, 88):
        rm.set(c, 15, "#")
    rm.notes = "Micélio (novo): a chaminé de espinhos só se sobe com a meia-volta (A5)."


@recipe("g7")
def g7(rm):
    rm.theme = "fungos"
    rm.rotate = False
    rm.carve(1, 9, 78, 18)
    rm.ladder(64, 19)                             # a escada até os Murchos
    rm.carve(38, 19, 41, 20)
    rm.ledge(35, 44, 16)
    rm.toca(10, 19)
    rm.item(25, 17, "pista")
    rm.notes = "Caramujário (toca de salvar): os caramujos e uma pista."


@recipe("rD")
def rD(rm):
    """A rosa do micélio: de pé, dá no Micélio; a 180°, no Poço (atalho); a 270°, no ninho escondido
    dos vagalumes (a lanterna). A 90°, rocha."""
    rm.theme = "fungos"
    only_door(rm, "g6")
    rose_build(rm, 2)
    rm.notes = "Rosa do micélio (D119)."


@recipe("gx")
def gx(rm):
    rm.theme = "fungos"
    rm.rotate = False
    rm.carve(4, 4, 30, 20)
    rm.ledge(4, 8, 18)
    rm.ledge(12, 17, 15)
    rm.ledge(20, 25, 12)
    rm.ledge(27, 30, 9)
    rm.item(28, 7, "lanterna")
    rm.notes = "Ninho de vagalumes (escondido: só pela rosa do micélio a 270°): a lanterna."


@recipe("ga")
def ga(rm):
    rm.theme = "fungos"
    rm.extra["dark"] = True
    rm.tunnel(78, 19, 60, 15)
    rm.tunnel(60, 15, 40, 19)
    rm.tunnel(40, 19, 20, 15)
    rm.tunnel(20, 15, 1, 19)
    rm.notes = "Túnel dos caramujos (escuro): liga o Poço ao Fungário oeste; o véu do fim pede a lanterna."


@recipe("gb")
def gb(rm):
    rm.theme = "fungos"
    rm.extra["dark"] = True
    rm.tunnel(158, 19, 130, 15)
    rm.carve(100, 10, 130, 18)
    rm.carve(105, 19, 125, 22)
    rm.water(105, 20, 125, 22)
    rm.ledge(110, 113, 16)
    rm.ledge(118, 121, 16)
    rm.add("puffs", {"rect": [114, 10, 2, 2], "period": 3.0, "phase": 0.0})
    rm.tunnel(100, 19, 70, 25)
    rm.carve(40, 22, 70, 30)
    rm.spikes(46, 64, 30)
    rm.ledge(46, 48, 27)
    rm.ledge(53, 55, 26)
    rm.ledge(60, 62, 27)
    rm.add("puffs", {"rect": [55, 22, 2, 2], "period": 2.5, "phase": 1.0})
    rm.tunnel(40, 31, 20, 25)
    rm.tunnel(20, 25, 1, 19)
    rm.notes = "Esporal (novo, escuro): esporos e água; a gosma do fim pede a seringa (A7)."


@recipe("gc")
def gc(rm):
    """Raízes podres (segredo): o caminho sobe em túneis; num deles, a gosma (A7) guarda o nicho do
    coração 4, embaixo."""
    rm.theme = "fungos"
    rm.tunnel(118, 41, 100, 37)
    rm.tunnel(100, 37, 60, 29)
    rm.tunnel(60, 29, 30, 23)
    rm.tunnel(30, 23, 1, 19)
    rm.carve(64, 29, 67, 33)
    rm.barrier(64, 29, 4, 2, "A7")
    rm.carve(58, 34, 74, 37)
    rm.item(70, 36, "coracao")
    rm.notes = "Raízes podres (segredo): o coração 4, atrás da gosma (A7)."


@recipe("gd")
def gd(rm):
    rm.theme = "fungos"
    rm.tunnel(118, 41, 80, 35)
    rm.carve(30, 26, 80, 34)
    rm.carve(34, 35, 76, 38)
    rm.water(34, 36, 76, 38)
    rm.ledge(45, 48, 31)
    rm.ledge(60, 63, 31)
    rm.tunnel(30, 35, 12, 27)
    rm.shaft(3, 1, 27)
    rm.carve(9, 24, 12, 26)
    rm.notes = "Margem (nova): a beira d'água do Fungário oeste; a gosma de cima (A7) dá na Lagoa funda."


@recipe("P3")
def p3(rm):
    rm.theme = "fungos"
    floors_shaft(rm, [9, 20, 31, 42, 57, 63, 74, 85], top_chute=(17, 22))
    rm.toca(10, 63)
    rm.notes = "O Poço (D120), trecho do Fungário: andares de túnel; embaixo, a gosma (A7)."


@recipe("P4")
def p4(rm):
    rm.theme = "caverna"
    floors_shaft(rm, [9, 20, 31, 41, 52, 63], top_chute=(17, 22))
    rm.toca(10, 41)
    rm.notes = "O fundo do Poço (D120): a porta das três luzes (as três chaves) leva ao Laboratório."


@recipe("C1")
def c1_campo(rm):
    rm.theme = ""
    rm.rotate = False
    rm.carve(1, 6, rm.w - 2, 18)
    rm.carve(137, 19, 142, 20)
    rm.extra["ending"] = True
    rm.notes = "O Campo, de novo: chegar aqui (subindo o Poço inteiro) é o fim."


# ---------------------------------------------------------------- o Laboratório

@recipe("L1")
def l1(rm):
    rm.theme = ""
    rm.rotate = False
    rm.carve(1, 13, 38, 18)                       # o corredor (chão 19)
    rm.shaft(17, 1, 18)                           # da porta das três luzes, com patamares
    rm.shaft(8, 19, 40)                           # do Teste: fungário (embaixo), subindo
    rm.put(8, 19, "↑" * 6)                        # em cima, barras de passagem: o corredor segue por cima
    rm.carve(1, 37, 13, 40)
    rm.toca(28, 19)
    rm.item(32, 17, "pista")
    rm.notes = "Antecâmara (toca de salvar): a verdade começa."


def lab_test(rm, level, at, mirror=False):
    rm.theme = ""
    rm.embed(level, at[0], at[1], mirror=mirror)
    for d in rm.doors:
        if d.side in (1, 3):
            ic, ir = d.inner()
            target = at[0] + (2 if d.side == 3 else 0)
            rm.tunnel(1 if d.side == 3 else rm.w - 2, d.r1 + 1, at[0] if d.side == 3 else at[0] + 40, d.r1 + 1)
        else:
            rm.carve(d.c0, 1 if d.side == 0 else rm.h - 3, d.c1, at[1] if d.side == 0 else rm.h - 2)


@recipe("L6")
def l6(rm):
    rm.theme = ""
    rm.rotate = False
    rm.carve(1, 13, 60, 18)
    rm.shaft(55, 13, 40)
    rm.carve(1, 35, 78, 40)
    rm.carve(20, 10, 30, 12)
    rm.notes = "Biotério (novo): as gaiolas dos animais. Provisória (D120)."




# ---------------------------------------------------------------- as fases da campanha (portais, D124)
# Cada uma entra inteira, sem mudar nada, e a prova dela (replay ou robô) vale no mundo: entra-se no
# começo (P) vindo da primeira vizinha e a porta (D) leva à segunda. (fase, vizinha do P, vizinha da
# porta, o que dá ao sair pela porta)
PORTALS = {
    "r2": ("degraus", "r1", "r3", []),
    "c1": ("comporta", "r4", "c5", []),
    "c2": ("derrame", "rA", "c3", []),
    "c3": ("setas", "c2", "P1", []),
    "c4": ("toca", "r4", "c8", []),
    "c6": ("espinhos", "rA", "c9", []),
    "c8": ("vertigem", "c4", "c7", ['pista']),
    "a1": ("agua", "rB", "a2", []),
    "a2": ("mare", "a1", "a6", []),
    "a3": ("represa", "rB", "a4", []),
    "a4": ("naufragio", "a3", "a5", []),
    "a5": ("mergulho", "a4", "d1", ['A3']),
    "d2": ("jeffrey", "d1", "d3", ['A4', 'chave1', 'noz']),
    "d3": ("fuga", "d2", "P2", []),
    "f2": ("linha-de-montagem", "f1", "f3", []),
    "f3": ("esteiras", "f2", "f6", []),
    "f5": ("prensas-e-vapor", "f4", "f7", []),
    "f6": ("dutos", "f3", "f8", ['A5']),
    "f9": ("casa-de-forca", "f7", "f4", ['cracha']),
    "fb": ("gatsby", "fa", "fc", []),
    "fc": ("a-mecha", "fb", "fp", ['A6', 'chave2']),
    "g2": ("broto", "g1", "g3", []),
    "g3": ("chapeus", "g2", "g5", []),
    "g5": ("esporos", "g3", "g7", []),
    "g4": ("murchos", "g7", "g6", []),
    "g8": ("colonia", "g6", "g9", []),
    "g9": ("senzi", "g8", "P4", ['A7', 'chave3']),
    "L2": ("derrame", "L1", "L4", []),
    "L3": ("prensas-e-vapor", "L1", "L5", []),
    "L4": ("esporos", "L2", "L1", []),
    "L5": ("dutos", "L3", "L6", []),
    "L7": ("giro", "L6", "L6", []),
}


def _portal_recipe(rid):
    lv, a, b, rw = PORTALS[rid]

    def build(rm):
        rm.portal(lv, a, b, reward=rw)
        if rid == "fb":
            rm.extra["win_exit"] = [rm.exit_order().index(rm.door_to("fc"))]
            rm.extra["flip_exempt"] = ("a corrida: a placa de espinhos persegue pelo corredor de cima; "
                                       "o validador acha um atalho girando lá. Rever jogando (D121).")
        if rid == "L7":
            rm.extra["win_exit"] = [rm.exit_order().index(rm.door_to("L6"))]
        rm.notes = "%s (fase da campanha, inteira: entra-se no começo, a porta leva adiante; D124)." % rm.name
    return build


for _rid in PORTALS:
    RECIPES[_rid] = _portal_recipe(_rid)

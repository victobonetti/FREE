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
    cair de andar em andar; subir pede o giro (A1). O buraco do primeiro andar tem uma barra de
    passagem (de cima segura; de baixo passa): quem chega sem o giro não cai onde não sai mais. O
    fundo é o cristal (A6)."""
    rm.theme = "raizes"
    rm.hint = "Ande com A/D ou as setas  ·  Pule com W, seta para cima ou Espaço"
    rm.carve(17, 1, 22, 14)                    # a queda da entrada
    floors = [19, 30, 41, 52, 63, 74, 85]
    for k, f in enumerate(floors):
        rm.carve(1, f - 4, rm.w - 2, f - 1)    # o andar: um túnel de 4
        if k + 1 < len(floors):
            nxt = floors[k + 1]
            a = 30 if k % 2 == 0 else 2         # o poço para o andar de baixo, em lados alternados
            rm.carve(a, f, a + 5, nxt - 5)
    rm.put(30, 19, "↑" * 6)
    rm.seal(rm.door_to("P2"), "A6")
    rm.toca(8, 19)
    rm.extra["entry_only_until"] = "L7"   # vencido o amortecedor-mor, a queda vira a subida para o Campo
    rm.notes = "O Poço (D120): a queda do começo. Andares de túnel e poços alternados (o giro não cai de uma vez)."


# ---------------------------------------------------------------- as Raízes

@recipe("r1")
def r1(rm):
    rm.theme = "raizes"
    rm.embed("passos", 10, 12, mirror=True)
    rm.carve(1, 16, 10, 18)
    rm.carve(29, 16, 38, 18)
    rm.door_to("r2").kind = "Z"
    rm.notes = "Primeiros passos (fase 1, espelhada): a caixa no buraco abre a saída da esquerda."


@recipe("r2")
def r2(rm):
    rm.theme = "raizes"
    rm.embed("degraus", 25, 4, mirror=True)
    rm.tunnel(78, 19, 53, 15)
    rm.tunnel(1, 19, 25, 15)
    rm.door_to("r3").kind = "Z"
    rm.notes = "Degraus (fase 2, espelhada), mais alta que os corredores."


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
    rm.carve(20, 9, 32, 13)          # em cima da parede
    rm.tunnel(20, 14, 1, 19)
    for c in (24, 40, 55):
        rm.set(c, 9, "#")            # pontas de raiz no teto
    rm.notes = "Raiz torta (nova): empurrar a caixa da prateleira para o vão; ela vira o degrau da parede."


@recipe("r4")
def r4(rm):
    """Toca do susto: a cápsula da batida de pata (A1) no corredor; o poço leva à câmara de baixo,
    onde as paredes só se passam girando (por cima delas há um vão estreito)."""
    rm.theme = "raizes"
    rm.tunnel(38, 19, 24, 19)
    rm.tunnel(24, 19, 14, 17)
    rm.item(28, 17, "A1")
    rm.carve(14, 17, 19, 29)          # o poço para baixo
    rm.carve(11, 30, 28, 40)          # a câmara do meio
    rm.carve(1, 30, 8, 40)            # à esquerda (saída para a Toca longa)
    rm.carve(31, 30, 38, 40)          # à direita (saída para a Comporta)
    rm.carve(9, 30, 10, 32)           # os vãos por cima das paredes (cols 9..10 e 29..30)
    rm.carve(29, 30, 30, 32)
    rm.fill(1, 30, 6, 33)             # tetos baixos dos lados: girado, não se cai reto
    rm.fill(33, 30, 38, 33)
    rm.notes = "Toca do susto: a cápsula do giro (A1); embaixo, as paredes de 9 só passam girando."


# ---------------------------------------------------------------- as Cavernas

@recipe("c1")
def c1(rm):
    rm.theme = "caverna"
    rm.embed("comporta", 5, 10)
    rm.carve(1, 16, 5, 18)
    rm.tunnel(34, 19, 45, 17)
    rm.tunnel(45, 17, 58, 17)
    rm.tunnel(58, 17, 72, 19)
    rm.carve(36, 19, 39, 20)
    rm.carve(67, 19, 70, 20)
    rm.door_to("c5").kind = "Z"
    rm.door_to("rA").kind = "Z"
    rm.notes = "Comporta (fase 4): resolvida, abre as descidas para o Ninho e para a rosa."


@recipe("c5")
def c5(rm):
    rm.theme = "raizes"
    rm.rotate = False
    rm.carve(1, 6, rm.w - 2, 18)
    rm.shaft(35, 1, 18)
    rm.ledge(46, rm.w - 2, 13)
    rm.ledge(42, 44, 16)
    rm.toca(10, 19)
    rm.notes = "Ninho (toca de salvar, sem giro)."


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


@recipe("c2")
def c2(rm):
    rm.theme = "caverna"
    rm.embed("derrame", 1, 20)
    rm.tunnel(36, 35, 78, 41)
    rm.carve(38, 36, 41, 42)
    rm.door_to("c3").kind = "Z"
    rm.notes = "Derrame (fase 5): comportas em cadeia; resolvido, abre as Setas."


@recipe("c3")
def c3(rm):
    rm.theme = "caverna"
    rm.embed("setas", 10, 26)
    rm.carve(1, 38, 10, 40)
    rm.carve(29, 38, 38, 40)
    rm.door_to("P1").kind = "Z"
    rm.notes = "Setas (fase 7): resolvida, abre o atalho de volta ao Poço (mão única)."


@recipe("c4")
def c4(rm):
    rm.theme = "caverna"
    rm.embed("toca", 36, 8, mirror=True)
    rm.carve(74, 16, 78, 18)
    rm.tunnel(36, 19, 24, 19)
    rm.carve(20, 16, 24, 18)
    rm.carve(20, 19, 23, 20)
    rm.door_to("c8").kind = "Z"
    rm.notes = "Toca longa (fase 6, espelhada): resolvida, abre a descida para a Vertigem."


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


@recipe("c6")
def c6(rm):
    rm.theme = "caverna"
    rm.embed("espinhos", 48, 1, mirror=True)
    rm.tunnel(75, 18, 78, 19)
    rm.carve(75, 15, 76, 17)
    rm.door_to("c9").kind = "Z"
    rm.notes = "Espinhos (fase 8, espelhada): cai-se da rosa; resolvida, abre a Galeria."


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


@recipe("c8")
def c8(rm):
    rm.theme = "caverna"
    rm.embed("vertigem", 41, 12)
    rm.carve(79, 13, 83, 15)                       # o nicho da cápsula, atrás da trava da sala
    rm.carve(78, 13, 78, 15)
    rm.barrier(79, 13, 2, 3, "sala")
    rm.item(81, 14, "A2")
    rm.carve(78, 28, 78, 30)
    rm.tunnel(78, 31, 96, 35)
    rm.tunnel(96, 35, 106, 35)
    rm.tunnel(106, 35, 118, 41)
    rm.shaft(99, 1, 34)
    rm.tunnel(1, 19, 41, 19)
    rm.notes = "Vertigem (fase 10): resolvida, a trava abre o nicho do giro no ar (A2)."


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
    """Fresta (segredo): do corredor de cima, um vão sobre a câmara de espinhos; só girando no ar
    (A2) se cai de lado no nicho do coração, do outro lado."""
    rm.theme = "caverna"
    rm.carve(50, 16, 78, 18)
    rm.shaft(52, 2, 18)
    rm.carve(29, 2, 57, 4)                         # o corredor de cima (chão 5)
    rm.carve(30, 5, 32, 5)
    spiky_shaft(rm, 14, 33, 6, 20, openings=[("L", 10, 15)], hole=(30, 32))
    rm.carve(3, 10, 12, 15)                        # o nicho
    rm.item(6, 14, "coracao")
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
    rm.spikes(10, 12, 12)
    rm.spikes(20, 22, 12)
    rm.ledge(15, 17, 9)
    rm.item(30, 11, "coracao")
    for c in (6, 14, 25, 32):
        rm.set(c, 6, "#")
    rm.notes = "Câmara de cristal (escondida: só pela rosa funda a 90°): o coração 5."


@recipe("a1")
def a1(rm):
    rm.theme = "aquifero"
    rm.embed("agua", 60, 0)
    rm.tunnel(1, 19, 55, 19)
    rm.tunnel(55, 19, 60, 21)
    rm.carve(47, 19, 50, 20)
    rm.put(47, 19, "↑" * 4)
    rm.tunnel(83, 21, 96, 13)
    rm.notes = "Água (fase 11): o ralo e a água; a barra sobre o vão da Represa só deixa subir."


@recipe("a2")
def a2(rm):
    rm.theme = "aquifero"
    rm.embed("mare", 14, 8)
    rm.tunnel(25, 21, 38, 19)
    rm.carve(13, 28, 14, 30)
    rm.tunnel(13, 31, 9, 31)
    rm.shaft(3, 28, 62)
    rm.carve(1, 60, 2, 62)
    rm.notes = "Maré (fase 12): entra-se pelo alto (onde era a porta), sai-se pelo fundo."


@recipe("a3")
def a3(rm):
    rm.theme = "aquifero"
    rm.embed("represa", 40, 4)
    rm.carve(47, 1, 50, 4)
    rm.shaft(106, 1, 19)
    rm.tunnel(106, 20, 79, 20)
    rm.carve(90, 20, 93, 20)
    rm.put(90, 20, "↑" * 4)
    rm.door_to("a4").kind = "Z"
    rm.notes = "Represa (fase 13): entra-se de cima (da Água ou da rosa funda)."


@recipe("a4")
def a4(rm):
    rm.theme = "aquifero"
    rm.embed("naufragio", 60, 2)
    rm.carve(90, 1, 93, 2)
    rm.carve(99, 11, 99, 13)
    rm.tunnel(99, 14, 118, 19)
    rm.door_to("a5").kind = "Z"
    rm.notes = "Naufrágio (fase 14): as duas caixas nos buracos abrem o Mergulho."


@recipe("a5")
def a5(rm):
    """Mergulho: a cápsula do mergulho (A3) na entrada; a saída para a Despensa passa por baixo d'água
    (o canal no fundo do poço): só afundando."""
    rm.theme = "aquifero"
    rm.embed("mergulho", 9, 14)
    rm.extra.pop("puzzle", None)
    rm.tunnel(1, 41, 4, 41)
    rm.shaft(3, 16, 40)
    rm.carve(9, 15, 12, 17)
    rm.item(5, 39, "A3")
    rm.carve(30, 44, 38, 47)                      # o canal, embaixo d'água
    rm.water(30, 44, 38, 47)
    rm.shaft(33, 16, 43)
    rm.notes = "Mergulho (fase 15): a cápsula do mergulho (A3); a Despensa fica do outro lado do canal submerso."


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


@recipe("d2")
def d2(rm):
    rm.theme = "despensa"
    rm.embed("jeffrey", 0, 0)
    rm.extra.pop("puzzle", None)
    rm.door_to("d3").kind = "Z"
    rm.item(10, 19, "A4", after_boss=True)
    rm.item(15, 19, "chave1", after_boss=True)
    rm.item(26, 19, "noz", after_boss=True)
    rm.notes = "Covil do Jeffrey (chefe, fase 17): vencido, deixa o puxar caixas (A4), a chave 1 e a noz-mestra."


@recipe("d3")
def d3(rm):
    rm.theme = "despensa"
    rm.embed("fuga", 10, 20)
    rm.extra.pop("puzzle", None)
    rm.carve(1, 40, 8, 42)
    rm.shaft(3, 40, 51)
    rm.carve(9, 49, 10, 51)
    rm.seal(rm.door_to("d2"), "A4")
    rm.carve(41, 26, 41, 28)
    rm.tunnel(41, 29, 78, 29)
    rm.notes = "Fuga (fase 16): a caixa presa da entrada só sai puxando (A4); no alto, a queda de volta ao Poço."


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
    rm.shaft(29, 1, 18)
    rm.carve(6, 19, 9, 20)
    rm.ledge(4, 11, 16)
    rm.toca(16, 19)
    rm.notes = "Portaria (toca de salvar, sem giro): a entrada da Fábrica."


@recipe("f2")
def f2(rm):
    rm.theme = "industrial"
    rm.embed("linha-de-montagem", 26, 9)
    rm.tunnel(1, 19, 26, 17)
    rm.tunnel(53, 17, 78, 19)
    rm.door_to("f3").kind = "Z"
    rm.notes = "Linha de montagem (fase 19)."


@recipe("f3")
def f3(rm):
    rm.theme = "industrial"
    rm.embed("esteiras", 24, 9)
    rm.tunnel(1, 19, 24, 17)
    rm.tunnel(55, 17, 78, 19)
    rm.door_to("f6").kind = "Z"
    rm.notes = "Esteiras (fase 20)."


@recipe("f4")
def f4(rm):
    """Almoxarifado (novo): as duas baterias do corredor de cima soltam a caixa da calha no de baixo;
    a caixa no buraco abre as Prensas. A barra sobre o vão da Casa de força só deixa subir."""
    rm.theme = "industrial"
    rm.extra["puzzle"] = True
    rm.shaft(5, 1, 9)
    rm.carve(5, 6, 64, 9)
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


@recipe("f5")
def f5(rm):
    rm.theme = "industrial"
    rm.embed("prensas-e-vapor", 40, 6)
    rm.tunnel(1, 19, 40, 17)
    rm.tunnel(75, 17, 118, 19)
    rm.carve(38, 19, 41, 20)
    rm.put(38, 19, "↑" * 4)
    rm.door_to("f6").kind = "Z"
    rm.notes = "Prensas e vapor (fase 21)."


@recipe("f6")
def f6(rm):
    """Dutos: resolvido, a trava abre o nicho da meia-volta (A5) e a descida para os Tanques."""
    rm.theme = "industrial"
    rm.embed("dutos", 10, 30)
    rm.shaft(1, 38, 62)
    rm.tunnel(6, 41, 10, 46)
    rm.carve(29, 43, 29, 45)
    rm.carve(30, 42, 33, 45)
    rm.barrier(30, 43, 2, 3, "sala")
    rm.item(32, 44, "A5")
    rm.carve(30, 46, 33, 64)
    rm.notes = "Dutos (fase 22): resolvida, a trava abre a meia-volta (A5) e a descida para os Tanques."


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
    rm.theme = "industrial"
    rm.rotate = False
    rm.carve(69, 1, 74, 4)
    rm.carve(40, 5, 96, 12)
    rm.carve(48, 13, 62, 15)
    rm.water(48, 14, 62, 15, "%")
    rm.ledge(53, 56, 11)
    rm.shaft(30, 5, 18)
    rm.carve(30, 5, 40, 12)
    rm.carve(1, 15, 35, 18)
    rm.carve(12, 19, 24, 20)
    rm.water(12, 19, 24, 20, "%")
    rm.ledge(17, 19, 16)
    rm.notes = "Tanques (nova): ácido nos dois andares; sem giro."


@recipe("f9")
def f9(rm):
    rm.theme = "industrial"
    rm.embed("casa-de-forca", 20, 24)
    rm.shaft(37, 1, 23)
    rm.carve(59, 34, 59, 36)
    rm.carve(60, 33, 64, 36)
    rm.barrier(60, 34, 2, 3, "sala")
    rm.item(62, 35, "cracha")
    rm.tunnel(64, 37, 78, 19)
    rm.door_to("f4").kind = "Z"
    rm.notes = "Casa de força (fase 23): o Gatsby foge; resolvida, a trava abre o crachá e a Caldeira."


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
    rm.shaft(17, 1, 18)
    rm.carve(30, 19, 33, 20)
    rm.toca(6, 19)
    rm.item(25, 17, "pista")
    rm.notes = "Escritório do Gatsby (toca de salvar): a catraca do crachá leva à corrida."


@recipe("fb")
def fb(rm):
    """A corrida do Gatsby (fase 24, inteira). Da Portaria, o túnel de baixo leva ao começo; no fim,
    a porta antiga dá na mecha (sair por ela é vencer a corrida); do meio da subida, a queda de volta
    ao Poço."""
    rm.theme = "industrial"
    rm.embed("gatsby", 7, 1)   # "puzzle": a corrida é provada por replay; o modelo não usa as catapultas
    rm.carve(138, 100, 141, 108)
    rm.carve(10, 103, 141, 105)
    rm.shaft(9, 97, 105)
    rm.tunnel(185, 16, 198, 29)
    rm.carve(1, 82, 8, 84)
    rm.extra["win_exit"] = [rm.exit_order().index(rm.door_to("fc"))]
    rm.extra["flip_exempt"] = ("a corrida: a placa de espinhos persegue pelo corredor de cima; o validador acha "
                               "um atalho girando lá. Rever jogando (D121).")
    rm.notes = "Corrida do Gatsby (fase 24): sair pela saída do fim vence a corrida."


@recipe("fc")
def fc(rm):
    rm.theme = "industrial"
    rm.embed("a-mecha", 0, 0)
    rm.extra.pop("puzzle", None)
    rm.door_to("fp").kind = "Z"
    rm.door_to("fb").kind = "Z"
    rm.item(11, 27, "A6", after_boss=True)
    rm.item(16, 27, "chave2", after_boss=True)
    rm.notes = "A mecha (chefe, fase 25): vencida, deixa a pata firme (A6) e a chave 2."


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


@recipe("g2")
def g2(rm):
    rm.theme = "fungos"
    rm.embed("broto", 18, 4, mirror=True)
    rm.tunnel(78, 19, 61, 17)
    rm.carve(44, 1, 47, 4)
    rm.tunnel(44, 4, 6, 4)
    rm.shaft(1, 1, 18)
    rm.notes = "Broto (fase 28, espelhada): sai-se pelo alto (onde era a porta)."


@recipe("g3")
def g3(rm):
    rm.theme = "fungos"
    rm.embed("chapeus", 20, 2, mirror=True)
    rm.tunnel(78, 19, 59, 17)
    rm.carve(19, 14, 20, 16)
    rm.carve(13, 14, 18, 16)
    rm.shaft(13, 14, 40)
    rm.tunnel(13, 41, 1, 41)
    rm.tunnel(18, 41, 41, 41)
    rm.carve(38, 41, 41, 42)
    rm.door_to("g4").kind = "Z"
    rm.notes = "Chapéus (fase 29, espelhada)."


@recipe("g4")
def g4(rm):
    rm.theme = "fungos"
    rm.embed("murchos", 18, 3, mirror=True)
    # D121: o teto da fase era alto demais (girada, caía-se por cima dos chapéus até a porta)
    rm.fill(19, 4, 60, 6)
    for c in (26, 36, 46, 54):
        rm.fill(c, 7, c + 1, 8)
    rm.tunnel(78, 19, 62, 16)
    rm.tunnel(18, 16, 1, 19)
    rm.carve(64, 19, 67, 20)
    rm.put(64, 19, "↑" * 4)
    rm.notes = "Murchos (fase 30, espelhada): o teto baixou e ganhou estalactites (D121)."


@recipe("g5")
def g5(rm):
    rm.theme = "fungos"
    rm.embed("esporos", 20, 4)
    rm.carve(38, 1, 41, 4)
    rm.tunnel(20, 17, 1, 19)
    rm.door_to("g7").kind = "Z"
    rm.notes = "Esporos (fase 31): cai-se do alto."


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
    rm.shaft(63, 1, 18)
    rm.carve(38, 19, 41, 20)
    rm.ledge(35, 44, 16)
    rm.toca(10, 19)
    rm.item(25, 17, "pista")
    rm.notes = "Caramujário (toca de salvar): os caramujos e uma pista."


@recipe("g8")
def g8(rm):
    rm.theme = "fungos"
    rm.embed("colonia", 60, 2, mirror=True)
    rm.shaft(157, 1, 16)
    rm.tunnel(157, 17, 115, 17)
    rm.carve(69, 1, 72, 2)
    rm.tunnel(60, 17, 20, 17)
    rm.carve(16, 14, 20, 16)
    rm.carve(16, 17, 19, 20)
    rm.door_to("g9").kind = "Z"
    rm.notes = "Colônia (fase 32, espelhada): todos os fungos; o presságio."


@recipe("g9")
def g9(rm):
    rm.theme = "fungos"
    rm.embed("senzi", 0, 0)
    rm.extra.pop("puzzle", None)
    rm.door_to("P4").kind = "Z"
    rm.item(12, 17, "A7", after_boss=True)
    rm.item(22, 17, "chave3", after_boss=True)
    rm.notes = "Arena do Senzi (chefe, fase 33): vencido, deixa a seringa (A7) e a chave 3."


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
    rm.shaft(17, 1, 18)
    rm.carve(1, 13, 38, 18)
    rm.shaft(2, 19, 40)
    rm.carve(1, 37, 12, 40)
    rm.toca(28, 19)
    rm.item(10, 17, "pista")
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


@recipe("L2")
def l2(rm):
    rm.embed("vertigem", 40, 2, mirror=True)
    rm.theme = ""
    rm.tunnel(118, 19, 78, 19)
    rm.carve(90, 19, 93, 20)
    rm.tunnel(40, 19, 30, 19)
    rm.door_to("L4").kind = "Z"
    rm.notes = "Teste: subsolo (remix da Vertigem, espelhada). Provisória (D120)."


@recipe("L3")
def l3(rm):
    rm.embed("prensas-e-vapor", 42, 6)
    rm.theme = ""
    rm.tunnel(1, 19, 42, 17)
    rm.tunnel(77, 17, 118, 19)
    rm.carve(100, 19, 103, 20)
    rm.door_to("L5").kind = "Z"
    rm.door_to("L1").kind = "Z"
    rm.notes = "Teste: fábrica (remix das Prensas). Provisória (D120)."


@recipe("L4")
def l4(rm):
    rm.embed("chapeus", 40, 3)
    rm.theme = ""
    rm.shaft(89, 1, 17)
    rm.tunnel(79, 18, 118, 19)
    rm.door_to("L1").kind = "Z"
    rm.notes = "Teste: fungário (remix dos Chapéus). Provisória (D120)."


@recipe("L5")
def l5(rm):
    rm.embed("dutos", 50, 2)
    rm.theme = ""
    rm.shaft(99, 1, 15)
    rm.tunnel(69, 16, 118, 19)
    rm.door_to("L6").kind = "Z"
    rm.notes = "Sala de controle (remix dos Dutos): desligar os amortecedores. Provisória (D120)."


@recipe("L6")
def l6(rm):
    rm.theme = ""
    rm.rotate = False
    rm.carve(1, 13, 60, 18)
    rm.shaft(55, 13, 40)
    rm.carve(1, 35, 78, 40)
    rm.carve(20, 10, 30, 12)
    rm.notes = "Biotério (novo): as gaiolas dos animais. Provisória (D120)."


@recipe("L7")
def l7(rm):
    rm.theme = ""
    rm.embed("giro", 30, 26)
    rm.limiter = True
    rm.tunnel(1, 41, 30, 37)
    rm.extra["boss_on_solve"] = True
    rm.notes = ("O amortecedor-mor: o primeiro giro, de novo, com o amortecedor puxando de volta. Resolvido, o "
                "Poço vira a subida para o Campo (o fim). Provisória (D120).")

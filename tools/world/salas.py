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


@recipe("rA")
def rA(rm):
    """A rosa das raízes: a abertura (à esquerda, de pé) aponta para o Ninho; girada, para a Comporta
    (90°), o Derrame (180°) e os Espinhos (270°). Barras por giro fazem a escada até ela."""
    rm.theme = "caverna"
    rm.extra["rose"] = True
    only_door(rm, "c5")
    rm.carve(1, 1, rm.w - 2, rm.h - 2)
    rm.ledge(1, 5, 13)
    rose_ladder(rm, 0, [(18, 9, 12), (15, 6, 9)])
    rose_ladder(rm, 1, [(18, 14, 17), (15, 9, 12), (12, 14, 17), (9, 9, 12), (6, 14, 17), (4, 9, 12)])
    rose_ladder(rm, 2, [(18, 11, 14), (15, 16, 18), (13, 16, 20)])
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


def spiky_shaft(rm, c0, c1, r0, r1, openings=(), bottom=True):
    """Um poço (colunas c0..c1, linhas r0..r1) com espinhos nas paredes de dentro e no fundo, menos
    nas aberturas [(lado 'L'/'R', linha0, linha1)]. É a trava do giro no ar (A2): sem chão lá dentro,
    só girando em plena queda se cai na abertura certa."""
    rm.carve(c0, r0, c1, r1)
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
    (e sobe de volta). Antes da corda, um vão de 3 sobre o poço de espinhos: quem gira no ar (A2) cai
    de lado na câmara da rosa funda."""
    rm.theme = "caverna"
    rm.carve(45, 16, 78, 18)
    rm.carve(59, 19, 61, 19)                       # o vão sobre o poço da rosa
    rm.carve(58, 20, 62, 33)
    rm.spikes(58, 62, 33)
    rm.carve(63, 24, 64, 31)                       # a abertura do lado
    rm.carve(65, 24, 72, 42)                       # a câmara sobre a rosa
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
    """Galeria: dois poços de espinhos (do Derrame, em cima, e dos Espinhos, à esquerda) que só se
    descem girando no ar (A2) para dentro do salão. Do salão, o corredor de baixo leva à escada de
    volta (barras de passagem no alto) e à caixa presa (A4) da Despensa."""
    rm.theme = "caverna"
    # do Derrame: o patamar da entrada e o poço
    rm.carve(35, 1, 42, 4)
    rm.ledge(39, 42, 4)
    spiky_shaft(rm, 35, 42, 5, 34, openings=[("L", 28, 33)])
    # dos Espinhos: o corredor e o poço
    rm.carve(1, 16, 20, 18)
    spiky_shaft(rm, 21, 26, 16, 34, openings=[("R", 22, 27)])
    rm.carve(27, 16, 27, 18)
    rm.set(27, 16, "#")
    rm.carve(28, 22, 33, 33)                       # o salão
    rm.carve(28, 34, 31, 36)
    rm.carve(9, 37, 33, 40)                        # o corredor de baixo
    rm.fill(24, 37, 26, 38)
    # a escada de volta para o corredor dos Espinhos (barras de passagem em cima)
    rm.shaft(2, 19, 40)
    rm.put(2, 19, "↑" * 6)
    rm.carve(8, 37, 8, 40)
    rm.seal(rm.door_to("d1"), "A4")
    rm.notes = "Galeria (nova): poços de espinhos que só se descem com o giro no ar (A2); a caixa presa (A4) leva à Despensa."


@recipe("cx")
def cx(rm):
    """Fresta (segredo): do corredor de cima, o poço de espinhos; girando no ar na altura certa, o
    coelho cai de lado no nicho do coração."""
    rm.theme = "caverna"
    rm.carve(50, 16, 78, 18)
    rm.shaft(52, 2, 18)
    rm.carve(21, 2, 57, 4)                         # o corredor de cima (chão 5)
    spiky_shaft(rm, 20, 25, 5, 20, openings=[("L", 12, 15)])
    rm.carve(21, 5, 24, 5)
    rm.carve(11, 12, 18, 15)                       # o nicho
    rm.item(14, 14, "coracao")
    rm.notes = "Fresta (segredo): o coração 1, com o giro no ar (A2)."

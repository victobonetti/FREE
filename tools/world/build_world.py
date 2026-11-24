"""Monta o mundo metroidvania (D118-D121) a partir do plano (tools/world/plano_mapa.py).

    python3 tools/world/build_world.py            # escreve levels/world/
    godot --headless --path . -s tools/world/check_world.gd   # confere (mapa, giro, progressão)

Cada sala do plano ocupa as casas dele (uma casa = 40x22 tiles, uma tela), salvo os ajustes de
LAYOUT (as rosas são quadradas; os chefes têm a arena do tamanho dela). As saídas saem das
ligações do plano: cada ligação vira uma abertura na parede que as duas salas dividem (3 de alto
no lado, 4 de largo em cima/embaixo), no lugar padrão ou no de DOORS. O tipo da ligação decide:
    ""        livre (X dos dois lados)
    "Z"       trancada na primeira sala (abre quando ela é resolvida)
    "1"       mão única: na segunda sala, a saída só recebe (entry_only)
    A6/A7/noz/crachá/lanterna/chaves   uma barreira logo para dentro da primeira sala
    A1..A5    livre: a sala é que pede a habilidade (o validador confere)
    R90.. / R180+A5+A6   rosa (a abertura da rosa encaixa nesse giro)

Depois disso o mundo é do editor (janela "Mundo"); rodar de novo sobrescreve as salas daqui.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from plano_mapa import R, LINKS  # noqa: E402
from wkit import Room, Door, ROOT  # noqa: E402

UX, UY = 40, 22
OUT = os.path.join(ROOT, "levels", "world")

THEME = {"C": "", "P": "raizes", "1": "caverna", "T": "transicao", "2": "industrial", "3": "fungos", "L": ""}

# ajustes da disposição (em tiles: x, y, w, h). As rosas são quadradas (22x22) e encostam nas quatro
# vizinhas; quem fica ao lado delas alarga para encostar.
LAYOUT = {
    "rA": (338, 66, 22, 22), "c5": (280, 66, 58, 22),
    "rB": (258, 110, 22, 22), "a1": (160, 110, 98, 22),
    "rC": (898, 198, 22, 22), "f8": (800, 198, 98, 44), "fx": (898, 220, 22, 22),
    "rD": (520, 264, 22, 22), "g6": (542, 264, 98, 44),
    # Jeffrey: a arena (40x22) embaixo da Despensa, colada na Fuga
    "d2": (360, 154, 40, 22),
    # Senzi: a arena (36x22) colada no Poço; a Colônia alarga para encostar em cima dela
    "g9": (520, 330, 36, 22), "g8": (520, 308, 200, 22),
    # a mecha (30x30) entre a corrida e a plataforma
    "fc": (720, 22, 30, 30), "fp": (750, 30, 170, 22), "fd": (800, 52, 120, 44),
    # a Toca longa cabe em duas telas
    "c4": (160, 44, 80, 22),
}

# saídas fora do lugar padrão: (a, b) -> (posição ao longo da parede, tamanho): y do topo (no lado)
# ou x da esquerda (em cima/embaixo), em tiles do mundo. As aberturas das rosas ficam no meio de
# cada lado (do 9 ao 12, de 4), para o giro levar uma na outra.
DOORS = {
    ("c5", "rA"): (75, 4), ("rA", "c1"): (347, 4), ("rA", "c2"): (75, 4), ("rA", "c6"): (347, 4),
    ("c7", "rB"): (267, 4), ("rB", "hx"): (119, 4), ("rB", "a3"): (267, 4), ("rB", "a1"): (119, 4),
    ("f8", "rC"): (207, 4), ("rC", "fe"): (207, 4), ("rC", "fx"): (907, 4),
    ("g6", "rD"): (273, 4), ("rD", "P3"): (273, 4), ("rD", "gx"): (529, 4),
    ("c1", "c5"): (316, 4), ("c4", "c8"): (180, 4),
    # chefes: as saídas no chão da arena
    ("d1", "d2"): (364, 4), ("d2", "d3"): (172, 3), ("fb", "fc"): (48, 3), ("fc", "fp"): (48, 3),
    ("d3", "P2"): (158, 3), ("a3", "a4"): (250, 4), ("gd", "a7"): (4, 4),
    ("f1", "fa"): (670, 4), ("f1", "f4"): (646, 4), ("f6", "f8"): (870, 4),
    ("g4", "g7"): (704, 4), ("L2", "L4"): (450, 4), ("L3", "L5"): (620, 4),
}

ROOMS = {}       # id -> Room


def rect_of(rid):
    if rid in LAYOUT:
        return LAYOUT[rid]
    r = next(x for x in R if x[0] == rid)
    return (r[3] * UX, r[4] * UY, r[5] * UX, r[6] * UY)


def make_rooms():
    for r in R:
        rid, name, wd = r[0], r[1], r[2]
        x, y, w, h = rect_of(rid)
        ROOMS[rid] = Room(rid, name, x, y, w, h, THEME.get(wd, ""))
        ROOMS[rid].world = wd
        ROOMS[rid].plan = r


def shared(a, b):
    """A parede que a e b dividem: (lado em a, início, fim) ao longo dela, em tiles do mundo."""
    ax, ay, aw, ah = a.x, a.y, a.w, a.h
    bx, by, bw, bh = b.x, b.y, b.w, b.h
    if ax + aw == bx or bx + bw == ax:
        side = 1 if ax + aw == bx else 3
        lo, hi = max(ay, by), min(ay + ah, by + bh)
        if hi - lo >= 4:
            return side, lo, hi
    if ay + ah == by or by + bh == ay:
        side = 2 if ay + ah == by else 0
        lo, hi = max(ax, bx), min(ax + aw, bx + bw)
        if hi - lo >= 6:
            return side, lo, hi
    return None


def make_doors():
    for a_id, b_id, kind in LINKS:
        a, b = ROOMS[a_id], ROOMS[b_id]
        sh = shared(a, b)
        if sh is None:
            raise SystemExit("ligação %s-%s: as salas não encostam" % (a_id, b_id))
        side, lo, hi = sh
        pos, size = DOORS.get((a_id, b_id), (None, None))
        if side in (1, 3):
            size = size or 3
            top = pos if pos is not None else hi - 6
            assert lo + 1 <= top and top + size <= hi - 1, (a_id, b_id, lo, hi, top)
            ys = [top + i for i in range(size)]
            ca = [((a.w - 1) if side == 1 else 0, yy - a.y) for yy in ys]
            cb = [(0 if side == 1 else b.w - 1, yy - b.y) for yy in ys]
        else:
            size = size or 4
            left = pos if pos is not None else (lo + hi) // 2 - 2
            assert lo + 1 <= left and left + size <= hi - 1, (a_id, b_id, lo, hi, left)
            xs = [left + i for i in range(size)]
            ca = [(xx - a.x, (a.h - 1) if side == 2 else 0) for xx in xs]
            cb = [(xx - b.x, 0 if side == 2 else b.h - 1) for xx in xs]
        da = Door(a, b_id, side, ca, "Z" if kind == "Z" else "X", link=kind)
        db = Door(b, a_id, (side + 2) % 4, cb, "X", entry_only=(kind == "1"), link=kind)
        a.doors.append(da)
        b.doors.append(db)
        da.peer, db.peer = db, da


BARRIER_LINKS = {"A6": "A6", "A7": "A7", "noz": "noz", "crachá": "cracha", "lanterna": "lanterna", "chaves": "chaves"}


def auto_barriers():
    """As barreiras das ligações (na primeira sala da ligação), se a receita não pôs."""
    for rm in ROOMS.values():
        for d in rm.doors:
            if d.peer.room is rm:
                continue
            need = None
            for part in d.link.split("+"):
                if part in BARRIER_LINKS:
                    need = BARRIER_LINKS[part]
            if need is None or getattr(d, "sealed", False) or getattr(d.peer, "sealed", False):
                continue
            # a barreira fica do lado de quem é "a" na ligação
            if any(l[0] == rm.id and l[1] == d.nb for l in LINKS):
                rm.seal(d, need)


def generic(rm):
    """Sala provisória: uma câmara no meio, com corredores até cada saída."""
    cc = rm.w // 2
    f = rm.h - 3 if rm.h <= UY else rm.h // 2
    rm.carve(cc - 8, f - 6, cc + 8, f - 1)
    for d in rm.doors:
        rm.connect(d, cc, f)
    rm.notes = "provisória (D120): a câmara do meio liga as saídas."


def main():
    make_rooms()
    make_doors()
    import salas  # as receitas
    for rid, rm in ROOMS.items():
        salas.RECIPES.get(rid, generic)(rm)
    auto_barriers()
    for rm in ROOMS.values():
        rm.stamp_doors()
    # escreve
    rdir = os.path.join(OUT, "rooms")
    os.makedirs(rdir, exist_ok=True)
    for f in os.listdir(rdir):
        if f.endswith(".json") and f[:-5] not in ROOMS:
            os.remove(os.path.join(rdir, f))
    world = {"version": 2, "start": "P1", "rooms": []}
    for rid, rm in ROOMS.items():
        with open(os.path.join(rdir, rid + ".json"), "w", encoding="utf-8") as f:
            f.write(json.dumps(rm.to_json(), indent="\t", ensure_ascii=False, sort_keys=True) + "\n")
        world["rooms"].append({"id": rid, "pos": [rm.x, rm.y]})
    p1 = ROOMS["P1"]
    world["start_exit"] = p1.exit_order().index(p1.door_to("C1"))
    with open(os.path.join(OUT, "mundo.json"), "w", encoding="utf-8") as f:
        f.write(json.dumps(world, indent="\t", ensure_ascii=False) + "\n")
    n_gen = sum(1 for rid in ROOMS if rid not in salas.RECIPES)
    print("mundo: %d salas (%d provisórias), %d ligações" % (len(ROOMS), n_gen, len(LINKS)))


if __name__ == "__main__":
    main()

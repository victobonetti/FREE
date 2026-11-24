"""Kit para montar as salas do mundo (D120): uma sala começa como rocha maciça e o conteúdo é
escavado nela (câmaras, corredores em degraus, poços com patamares), ou embutido de uma fase da
campanha (com os objetos deslocados e, se preciso, espelhada).

Coordenadas em tiles, locais da sala: (coluna, linha), linha 0 em cima. O coelho ocupa 2x2 tiles e
pula 3 tiles para cima (e uns 5 para o lado).
"""
import copy
import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
CAMP = os.path.join(ROOT, "levels", "campaign")

# espelhar na horizontal: as setas e as barras trocam de lado
MIRROR = {">": "<", "<": ">", "→": "←", "←": "→", "}": "{", "{": "}"}


def load_level(name):
    path = os.path.join(CAMP, name + ".json")
    if not os.path.exists(path):
        path = os.path.join(ROOT, "levels", "wip", name + ".json")
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _shift_rect(a, dc, dr, w=None, mirror_w=None):
    a = list(a)
    if mirror_w is not None:
        a[0] = mirror_w - a[0] - (a[2] if len(a) > 2 else 1)
    a[0] = int(a[0]) + dc
    a[1] = int(a[1]) + dr
    for i in range(2, len(a)):
        a[i] = int(a[i]) if float(a[i]).is_integer() else a[i]
    return a


class Door:
    def __init__(self, room, nb, side, cells, kind="X", entry_only=False, link=""):
        self.room = room
        self.nb = nb            # id da vizinha
        self.side = side        # 0 cima, 1 direita, 2 baixo, 3 esquerda
        self.cells = cells      # [(c, r)] locais, na borda
        self.kind = kind        # "X" ou "Z"
        self.entry_only = entry_only
        self.link = link        # o tipo da ligação no plano

    @property
    def c0(self):
        return min(c for c, r in self.cells)

    @property
    def c1(self):
        return max(c for c, r in self.cells)

    @property
    def r0(self):
        return min(r for c, r in self.cells)

    @property
    def r1(self):
        return max(r for c, r in self.cells)

    def inner(self):
        """A célula onde o coelho fica, logo para dentro da saída (o canto de cima à esquerda do 2x2),
        e a linha do chão sob ele (para as saídas do lado)."""
        if self.side == 3:
            return (1, self.r1 - 1)
        if self.side == 1:
            return (self.room.w - 3, self.r1 - 1)
        if self.side == 0:
            return (self.c0 + 1, 1)
        return (self.c0 + 1, self.room.h - 3)


class Room:
    def __init__(self, id, name, x, y, w, h, theme="", **extra):
        self.id = id
        self.name = name
        self.x, self.y, self.w, self.h = x, y, w, h
        self.theme = theme
        self.g = [["#"] * w for _ in range(h)]
        self.objs = {}
        self.extra = dict(extra)
        self.doors = []
        self.notes = ""
        self.hint = ""
        self.limiter = False
        self.rotate = True
        self.start_rot = 0
        self.portal_nb = None   # (vizinha do P, vizinha da D): sala de portais (D124)

    # ------------------------------------------------------------ grade
    def inside(self, c, r):
        return 0 <= c < self.w and 0 <= r < self.h

    def at(self, c, r):
        return self.g[r][c] if self.inside(c, r) else "#"

    def set(self, c, r, ch):
        if self.inside(c, r):
            self.g[r][c] = ch

    def put(self, c, r, text):
        for i, ch in enumerate(text):
            self.set(c + i, r, ch)

    def fill(self, c0, r0, c1, r1, ch="#"):
        for r in range(min(r0, r1), max(r0, r1) + 1):
            for c in range(min(c0, c1), max(c0, c1) + 1):
                if 0 < c < self.w - 1 and 0 < r < self.h - 1:
                    self.g[r][c] = ch

    def carve(self, c0, r0, c1, r1):
        """Abre (.) o retângulo, sem nunca abrir a borda da sala."""
        self.fill(c0, r0, c1, r1, ".")

    def carve_rock(self, c0, r0, c1, r1):
        """Abre só onde é rocha (não apaga peças já desenhadas)."""
        for r in range(min(r0, r1), max(r0, r1) + 1):
            for c in range(min(c0, c1), max(c0, c1) + 1):
                if 0 < c < self.w - 1 and 0 < r < self.h - 1 and self.g[r][c] == "#":
                    self.g[r][c] = "."

    def ledge(self, c0, c1, r, ch="#"):
        self.fill(c0, r, c1, r, ch)

    def block(self, c, r, ch):
        self.put(c, r, ch * 2)
        self.put(c, r + 1, ch * 2)

    def spikes(self, c0, c1, r, ch="^"):
        for c in range(c0, c1 + 1):
            self.set(c, r, ch)

    def water(self, c0, r0, c1, r1, ch="~"):
        self.fill(c0, r0, c1, r1, ch)

    def add(self, kind, obj):
        self.objs.setdefault(kind, []).append(obj)
        return len(self.objs[kind]) - 1

    # ------------------------------------------------------------ peças do mundo
    def toca(self, c, floor_r, w=3):
        """A toca de salvar: um ninho no chão (a linha `floor_r` é a do chão)."""
        self.add("tocas", {"rect": [c, floor_r - 2, w, 2]})

    def item(self, c, r, give, after_boss=False):
        self.add("items", {"rect": [c, r, 2, 2], "give": give, "after_boss": 1 if after_boss else 0})

    def barrier(self, c, r, w, h, need):
        self.add("barriers", {"rect": [c, r, w, h], "need": need})

    # ------------------------------------------------------------ escavar caminhos
    def tunnel(self, c0, f0, c1, f1, head=3, step=2, run=3):
        """Um corredor andável de (c0, chão f0) a (c1, chão f1): as linhas do chão são f0/f1 (a
        fileira de rocha sob os pés). Sobe ou desce em degraus de `step` a cada `run` colunas (o
        pulo vence 3). Abre `head` linhas acima do chão."""
        d = 1 if c1 >= c0 else -1
        f = f0
        since = 0   # as primeiras colunas (a boca da saída) ficam no chão da saída
        c = c0
        while True:
            if f != f1 and since >= run:
                nf = f + max(-step, min(step, f1 - f))
                lo, hi = min(f, nf), max(f, nf)
                # o degrau: 3 colunas de folga em cima (o coelho tem 1,5 tile de largura e pula de
                # antes da beirada)
                self.carve_rock(min(c, c - 2 * d), lo - head, max(c, c - 2 * d), hi - 1)
                f = nf
                since = 0
            self.carve_rock(c, f - head, c, f - 1)
            since += 1
            if c == c1:
                break
            c += d
        # se faltou subir/descer, um poço com patamares no fim
        if f != f1:
            self.shaft(c1 - 2 if d > 0 else c1 - 3, min(f, f1) - head, max(f, f1) - 1)
        return f

    def shaft(self, c0, r_top, r_bot, width=6, first_left=True):
        """Um poço vertical (colunas c0..c0+width-1) com patamares alternados a cada 3 linhas, para
        subir pulando; cair, cai de patamar em patamar."""
        self.carve_rock(c0, r_top, c0 + width - 1, r_bot)
        left = first_left
        r = r_bot - 2   # 3 acima do chão (r_bot + 1): o pulo alcança
        half = width // 2
        while r > r_top + 2:
            if left:
                self.ledge(c0, c0 + half - 1, r)
            else:
                self.ledge(c0 + width - half, c0 + width - 1, r)
            left = not left
            r -= 3

    def ladder(self, d0, floor):
        """A escada até uma saída no alto (colunas d0..d0+3, linha 0): patamares a cada 3 linhas,
        alternando à esquerda (d0-3..d0) e à direita (d0+3..d0+6), e o último embaixo da saída (linha
        4). Entre eles, um vão de 2 (o pulo de 3 para cima anda uns 3 para o lado); nada fica em cima de
        onde se pula."""
        self.carve_rock(max(d0 - 3, 1), 1, min(d0 + 6, self.w - 2), floor - 1)
        r = floor - 3
        left = True
        while r > 4:
            if left:
                self.ledge(max(d0 - 3, 1), d0, r)
            else:
                self.ledge(d0 + 3, min(d0 + 6, self.w - 2), r)
            left = not left
            r -= 3
        self.ledge(d0, d0 + 3, 4)

    def connect(self, door, c, f):
        """Liga a saída `door` ao ponto (c, chão f) dentro da sala, escavando."""
        if door.side in (1, 3):
            ic, ir = door.inner()
            fl = door.r1 + 1
            self.carve_rock(door.c0, door.r0, door.c1, door.r1)
            return self.tunnel(ic if door.side == 3 else ic + 1, fl, c, f)
        # cima ou baixo: um poço até a altura do chão, e o corredor dali
        sc = door.c0 - 1
        if door.side == 0:
            top = 1
            self.shaft(sc, top, f - 1)
            return self.tunnel(sc + 2, f, c, f)
        self.carve_rock(door.c0, self.h - 2, door.c1, self.h - 2)
        self.shaft(sc, f - 3, self.h - 2)
        return self.tunnel(sc + 2, f, c, f)

    # ------------------------------------------------------------ fases da campanha
    def embed(self, name, c, r, mirror=False, keep=("rows",), strip="PD", objs=True):
        """Embute a fase `name` com o canto em (c, r). Tira o começo e a porta (viram chão). Devolve
        a fase (dict), para quem quiser ler o resto."""
        d = load_level(name)
        rows = [list(x) for x in d["rows"]]
        lw = max(len(x) for x in rows)
        if mirror:
            rows = [[MIRROR.get(ch, ch) for ch in reversed(x + ["#"] * (lw - len(x)))] for x in rows]
        for rr, line in enumerate(rows):
            for cc, ch in enumerate(line):
                if ch in strip:
                    ch = "."
                self.set(c + cc, r + rr, ch)
        if objs:
            for kind, lst in d.items():
                if kind in SCALAR_KEYS:
                    continue
                if kind == "spin_block":
                    self.extra[kind] = [int(lst[0]) + c, int(lst[1]) + r, int(lst[2])]
                    continue
                if kind == "gatsby":
                    self.extra[kind] = shift_script(lst, c, r)
                    continue
                if kind in ("actors", "omen", "elevator"):
                    self.extra[kind] = lst
                    continue
                if not isinstance(lst, list):
                    continue
                for o in lst:
                    self.objs.setdefault(kind, []).append(shift_obj(kind, o, c, r, lw if mirror else None))
            for k in ("boss_music", "music", "spin_cooldown", "awaken"):
                if k in d and k != "awaken":
                    self.extra[k] = d[k]
        self.extra["puzzle"] = True   # o validador não empilha caixas: vale resolvida
        for k in ("limiter", "rotate", "reload_time", "limiter_time"):
            if k in d:
                if k == "limiter":
                    self.limiter = bool(d[k])
                elif k == "rotate":
                    self.rotate = bool(d[k])
                else:
                    self.extra[k] = d[k]
        return d

    def door_to(self, nb):
        for d in self.doors:
            if d.nb == nb:
                return d
        raise KeyError("%s não liga com %s" % (self.id, nb))

    def seal(self, d, need):
        """Uma barreira logo para dentro da saída d (2 de espessura)."""
        if d.side == 3:
            self.carve(1, d.r0, 2, d.r1)
            self.barrier(1, d.r0, 2, 3, need)
        elif d.side == 1:
            self.carve(self.w - 3, d.r0, self.w - 2, d.r1)
            self.barrier(self.w - 3, d.r0, 2, 3, need)
        elif d.side == 0:
            self.carve(d.c0, 1, d.c1, 2)
            self.barrier(d.c0, 1, 4, 2, need)
        else:
            self.carve(d.c0, self.h - 3, d.c1, self.h - 2)
            self.barrier(d.c0, self.h - 3, 4, 2, need)
        d.sealed = True

    def portal(self, level, p_nb, d_nb, reward=(), at=None):
        """Sala de portais (D124): a fase da campanha inteira, sem mudar nada (o começo P, a porta D,
        o giro inicial, a porta aberta), lacrada na rocha. As saídas da borda só ligam o mapa (são
        parede); entrando pela da vizinha `p_nb`, o coelho aparece no P; pela de `d_nb`, na porta.
        A porta aberta leva a `d_nb`; voltar ao P leva a `p_nb`. As provas da fase (replay ou robô)
        valem aqui. `reward`: o que a fase dá ao sair pela porta."""
        d = load_level(level)
        lw = max(len(x) for x in d["rows"])
        lh = len(d["rows"])
        if at is None:
            at = ((self.w - lw) // 2, (self.h - lh) // 2)
        assert lw <= self.w and lh <= self.h, "%s: a fase %s (%dx%d) não cabe" % (self.id, level, lw, lh)
        self.embed(level, at[0], at[1], strip="")
        self.extra["puzzle"] = True
        self.extra["virtual_exits"] = True
        self.extra["level"] = level
        self.portal_nb = (p_nb, d_nb)
        self.start_rot = int(d.get("start_rot", 0))
        if d.get("door_open"):
            self.extra["door_open"] = True
        if reward:
            self.extra["reward"] = list(reward)
        if d.get("theme"):
            self.theme = d["theme"]
        for dr in self.doors:
            dr.kind = "X"
        return d

    # ------------------------------------------------------------ saída
    def stamp_doors(self):
        for dr in self.doors:
            for (c, r) in dr.cells:
                self.g[r][c] = dr.kind
        # as saídas precisam ter ar logo para dentro (menos na sala de portais: lá a saída é parede)
        for dr in ([] if self.portal_nb else self.doors):
            for (c, r) in dr.cells:
                ic, ir = c, r
                if dr.side == 0:
                    ir = 1
                elif dr.side == 2:
                    ir = self.h - 2
                elif dr.side == 3:
                    ic = 1
                else:
                    ic = self.w - 2
                if self.g[ir][ic] == "#":
                    self.g[ir][ic] = "."

    def to_json(self):
        d = {
            "name": self.name, "rotate": self.rotate, "limiter": self.limiter, "start_rot": self.start_rot, "version": 1,
            "rows": ["".join(x) for x in self.g],
        }
        if self.portal_nb:
            order = self.exit_order()
            d["portal_p"] = order.index(self.door_to(self.portal_nb[0]))
            d["portal_d"] = order.index(self.door_to(self.portal_nb[1]))
        if self.theme:
            d["theme"] = self.theme
        if self.notes:
            d["notes"] = self.notes
        if self.hint:
            d["hint"] = self.hint
            d["hint_touch"] = self.hint
        eo = []
        for k, ex in enumerate(self.exit_order()):
            if ex.entry_only:
                eo.append(k)
        if eo:
            d["entry_only"] = eo
        for k, v in self.objs.items():
            d[k] = v
        d.update(self.extra)
        return d

    def exit_order(self):
        """As saídas na ordem de world.gd (parse_exits): por lado (cima, direita, baixo, esquerda) e,
        em cada lado, ao longo dele."""
        def key(dr):
            along = dr.c0 if dr.side in (0, 2) else dr.r0
            return (dr.side, along)
        return sorted(self.doors, key=key)


SCALAR_KEYS = {"rows", "name", "notes", "verified", "verified_hash", "version", "start_rot", "rotate", "theme", "hint",
               "hint_touch", "door_open", "limiter", "limiter_time", "reload_time", "boss_music", "music", "spin_cooldown",
               "awaken"}


def shift_script(g, dc, dr):
    """O roteiro do Gatsby (corrida, casa de força): os gatilhos em tiles, deslocados."""
    g = copy.deepcopy(g)
    if "start" in g:
        g["start"] = [int(g["start"][0]) + dc, int(g["start"][1]) + dr]
    for st in g.get("script", []):
        if "when" in st:
            w = st["when"]
            st["when"] = [int(w[0]) + dc, int(w[1]) + dr, int(w[2]), int(w[3])]
    return g


def shift_obj(kind, o, dc, dr, mirror_w=None):
    """Desloca um objeto da fase (os campos em tiles)."""
    if isinstance(o, list):
        return _shift_rect(o, dc, dr, mirror_w=mirror_w)
    o = copy.deepcopy(o)
    for k in ("rect",):
        if k in o:
            o[k] = _shift_rect(o[k], dc, dr, mirror_w=mirror_w)
    if "off" in o:
        w = o["off"][2]
        o["off"] = _shift_rect(o["off"], dc, dr, mirror_w=mirror_w)
        if "on" in o:
            on = list(o["on"])
            if mirror_w is not None:
                on[0] = mirror_w - on[0] - w
            o["on"] = [int(on[0]) + dc, int(on[1]) + dr]
    if mirror_w is not None and "dir" in o:
        dv = int(o["dir"])
        if kind in ("fans", "vents", "sprouts", "bouncers", "crushers"):
            o["dir"] = {1: 3, 3: 1}.get(dv, dv)
        elif kind == "conveyors":
            o["dir"] = -dv
    for k, v in list(o.items()):
        if isinstance(v, float) and v.is_integer():
            o[k] = int(v)
    return o

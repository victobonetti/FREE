"""Ferramenta para descrever uma fase e, junto, o roteiro do robô que a joga.

Cada fase é um script em tools/levels/<id>.py que usa esta biblioteca:

    from levelkit import Level
    lv = Level("montagem", "Linha de montagem", 80, 40)
    lv.ledge(7, 11, 34)                  # plataforma: colunas 7..11, superfície na linha 34
    lv.step("edge_jump", 1, 22, *lv.xr(7, 11))
    lv.save()                            # levels/wip/<id>.json e tools/plans/<id>.json

Depois: godot --headless --path . -s tools/robot.gd -- <id>   (joga e grava a rota, a prova).

Coordenadas em tiles: (coluna, linha), linha 0 em cima. Uma plataforma na linha r é uma fileira de
parede; o coelho fica em pé em cima dela. O robô trabalha em px do centro do coelho: `xr(c0, c1)`
dá o intervalo de px de uma plataforma. Canais (cores dos conectores): 0 verde, 1 rosa, 2 ciano,
3 laranja, 4 amarelo, 5 azul, 6 rosa-claro, 7 verde-água.
"""
import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


class Level:
    def __init__(self, id, name, w, h, floor=3, theme="industrial", hint="", hint_touch="", notes="", rotate=True, limiter=True, extra=None):
        self.id = id
        self.name = name
        self.w = w
        self.h = h
        self.floor = floor
        self.g = [["." for _ in range(w)] for _ in range(h)]
        for r in range(h):
            for c in range(w):
                if r == 0 or r == h - 1 or c == 0 or c == w - 1 or r >= h - floor:
                    self.g[r][c] = "#"
        self.theme = theme
        self.hint = hint
        self.hint_touch = hint_touch or hint
        self.notes = notes
        self.rotate = rotate
        self.limiter = limiter
        self.extra = extra or {}
        self.objs = {}
        self.steps = []

    # ------------------------------------------------------------ geometria
    @property
    def floor_row(self):
        """A linha da superfície do chão."""
        return self.h - self.floor

    def put(self, c, r, text):
        for i, ch in enumerate(text):
            self.g[r][c + i] = ch

    def solid(self, c0, r0, c1, r1):
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                self.g[r][c] = "#"

    def clear(self, c0, r0, c1, r1):
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                self.g[r][c] = "."

    def ledge(self, c0, c1, r, thick=1):
        self.solid(c0, r, c1, r + thick - 1)

    def block(self, c, r, ch):
        self.put(c, r, ch * 2)
        self.put(c, r + 1, ch * 2)

    def spikes(self, c0, c1, r, ch="^"):
        for c in range(c0, c1 + 1):
            self.g[r][c] = ch

    def add(self, kind, obj):
        self.objs.setdefault(kind, []).append(obj)
        return len(self.objs[kind]) - 1

    # ------------------------------------------------------------ medidas para o robô
    @staticmethod
    def xr(c0, c1, margin=3):
        """O intervalo de px (centro do coelho) para pousar nas colunas c0..c1."""
        return [c0 * 8 + margin, (c1 + 1) * 8 - margin]

    @staticmethod
    def cx(c):
        return c * 8 + 4

    # ------------------------------------------------------------ roteiro
    def step(self, *s):
        self.steps.append(list(s))

    def hop(self, dir, c0, c1, r, hold=22, ledge=True, safe=False):
        """Salta da beirada até a plataforma (colunas c0..c1, superfície na linha r).
        `safe`: pula com o centro do corpo na beirada, não no último instante (perto de ácido)."""
        if ledge:
            self.ledge(c0, c1, r)
        s = ["edge_jump", dir, hold, *self.xr(c0, c1), r]
        if safe:
            s.append(1)
        self.step(*s)

    def jump_from(self, dir, c0, c1, r, hold=22, ledge=True):
        """Pula já (sem esperar uma beirada), por exemplo do chão."""
        if ledge:
            self.ledge(c0, c1, r)
        self.step("jump_in_place", dir, hold, *self.xr(c0, c1), r)

    def drop(self, dir, c0, c1, r, ledge=False):
        """Anda até cair e pousa em c0..c1, na linha r."""
        if ledge:
            self.ledge(c0, c1, r)
        self.step("walk_off", dir, *self.xr(c0, c1), r)

    def mark(self, label):
        self.steps.append(["mark", label])

    # ------------------------------------------------------------ saída
    def to_json(self):
        d = {
            "name": self.name, "rotate": self.rotate, "limiter": self.limiter, "start_rot": 0, "version": 1,
            "theme": self.theme, "rows": ["".join(r) for r in self.g],
        }
        if self.hint:
            d["hint"] = self.hint
            d["hint_touch"] = self.hint_touch
        if self.notes:
            d["notes"] = self.notes
        for k, v in self.objs.items():
            d[k] = v
        d.update(self.extra)
        if not self.theme:
            del d["theme"]
        return d

    def ceiling(self, c0=1, c1=None, r=1):
        """Espinhos no teto em todas as células livres da linha r (a alavanca e a calha ficam de fora)."""
        for c in range(c0, (c1 if c1 is not None else self.w - 2) + 1):
            if self.g[r][c] == ".":
                self.g[r][c] = "v"

    def save(self):
        out = os.path.join(ROOT, "levels", "wip", self.id + ".json")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "w", encoding="utf-8") as f:
            json.dump(self.to_json(), f, ensure_ascii=False, indent="\t")
            f.write("\n")
        pout = os.path.join(ROOT, "tools", "plans", self.id + ".json")
        os.makedirs(os.path.dirname(pout), exist_ok=True)
        with open(pout, "w", encoding="utf-8") as f:
            json.dump({"steps": self.steps}, f, ensure_ascii=False)
            f.write("\n")
        n = {k: len(v) for k, v in self.objs.items()}
        print("%s: %dx%d, %d passos do robô, objetos %s" % (self.id, self.w, self.h, len(self.steps), n))

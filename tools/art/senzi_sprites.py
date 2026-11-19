"""Folha de sprites do Senzi (D112). Pixel art quadro a quadro, a partir de um esqueleto por quadro.

O Senzi é um caramujo que virou um corredor alto: o corpo é a mesma carne bege dos caramujos de enfeite,
mas mole, calombuda e escorrendo gosma; não tem rosto: no lugar da cabeça, um pescoço de caramujo com
dois tentáculos caídos e, em cima, a concha roxa pequena, como um chapéu. No estilo do jogo: cores
chapadas (um tom de sombra embaixo de cada parte), sem contorno, sem músculos desenhados. A forma
treme de um quadro para outro (gosma).

    python3 tools/art/senzi_sprites.py     ->  art/senzi.png  e  art/senzi.json

Quadros de 96x96, virado para a direita, pés na linha 93.
"""
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
FW, FH = 96, 96
GROUND = 93

GOO = (215, 205, 184, 255)       # a carne dos caramujos de enfeite (d7cdb8)
GOO_D = (172, 160, 140, 255)     # embaixo das partes
GOO_B = (150, 139, 122, 255)     # os membros de trás
GOO_B_D = (124, 114, 101, 255)
WET = (240, 235, 222, 255)       # brilho molhado (pontinhos)
SHELL = (138, 95, 158, 255)      # a concha dos de enfeite (8a5f9e / 6e4a82 / c9a6dd)
SHELL_D = (110, 74, 130, 255)
SHELL_L = (201, 166, 221, 255)
MOUTH = (58, 26, 36, 255)
# a seringa (o plot twist): vidro, o líquido verde bem vivo, a agulha
GLASS = (206, 232, 226, 255)
GLASS_D = (60, 92, 84, 255)
JUICE = (112, 255, 74, 255)
JUICE_D = (40, 170, 40, 255)
STEEL = (200, 204, 214, 255)
# o coelhão (D114): o pelo branco do coelho, as orelhas rosadas, o olho vermelho
FUR = (239, 234, 223, 255)
FUR_D = (198, 192, 180, 255)
FUR_B = (196, 190, 178, 255)
FUR_B_D = (160, 154, 144, 255)
EAR_IN = (240, 160, 176, 255)
EYE = (226, 46, 64, 255)


class Canvas:
    def __init__(self, seed=0):
        self.img = np.zeros((FH, FW, 4), dtype=np.uint8)
        self.rng = np.random.default_rng(seed)
        self.bottoms = []          # pontos de onde a gosma pode escorrer
        self.pump = 1.0            # o PUMP: tudo mais grosso

    @staticmethod
    def _shift(m, dx, dy):
        out = np.zeros_like(m)
        h, w = m.shape
        xs0, xs1 = max(0, -dx), min(w, w - dx)
        ys0, ys1 = max(0, -dy), min(h, h - dy)
        out[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx] = m[ys0:ys1, xs0:xs1]
        return out

    def _mask(self, shapes):
        m = Image.new("L", (FW, FH), 0)
        d = ImageDraw.Draw(m)
        for kind, a in shapes:
            if kind == "c":
                x, y, r = a
                d.ellipse([x - r, y - r, x + r, y + r], fill=255)
            else:
                d.polygon([tuple(q) for q in a], fill=255)
        return np.array(m) > 0

    def lump(self, p0, p1, r0, r1, n=None, wob=0.32):
        """Um pedaço de gosma de p0 a p1: uma fila de bolas de raio irregular."""
        ln = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        n = n or max(3, int(ln / 2.5))
        out = []
        for i in range(n + 1):
            t = i / n
            r = (r0 + (r1 - r0) * t) * (1.0 + self.rng.uniform(-wob, wob)) * self.pump
            q = lerp(p0, p1, t)
            j = self.rng.uniform(-0.5, 0.5, 2)
            out.append(("c", (q[0] + j[0], q[1] + j[1], max(0.8, r))))
        return out

    def part(self, shapes, base, dark, drip=True):
        """Cor chapada; a borda de baixo um tom mais escura (a gosma pesa para baixo)."""
        m = self._mask(shapes)
        if not m.any():
            return m
        self.img[m] = base
        under = m & ~self._shift(m, 0, -2)
        self.img[under] = dark
        if drip:
            ys, xs = np.nonzero(m & ~self._shift(m, 0, -1))
            for k in range(len(xs)):
                self.bottoms.append((int(xs[k]), int(ys[k]), base, dark))
        return m

    def px(self, x, y, col):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < FW and 0 <= y < FH:
            self.img[y, x] = col

    def line(self, p0, p1, col, w=1):
        im = Image.fromarray(self.img, "RGBA")
        ImageDraw.Draw(im).line([tuple(p0), tuple(p1)], fill=col, width=w)
        self.img = np.array(im)

    def goo(self, n, ground=GROUND, wind=0.0):
        """Gosma escorrendo das bordas de baixo: fios de 1 px e gotas (algumas já soltas)."""
        cand = [b for b in self.bottoms if b[1] < ground - 3]
        if not cand:
            return
        for _ in range(n):
            x, y, base, dark = cand[int(self.rng.integers(len(cand)))]
            ln = int(self.rng.integers(2, 6))
            for k in range(1, ln + 1):
                self.px(x + wind * k, y + k, dark if k == ln else base)
            if self.rng.random() < 0.5:
                g = y + ln + int(self.rng.integers(2, 5))
                if g < ground:
                    self.px(x + wind * ln, g, base)
                    self.px(x + wind * ln, g + 1, dark)

    def wet(self, n, base=GOO):
        sil = (self.img[:, :, 3] > 0) & (self.img[:, :, 0] == base[0])
        ys, xs = np.nonzero(sil & self._shift(sil, 0, 1) & self._shift(sil, 1, 0))
        for _ in range(n):
            if len(xs):
                k = int(self.rng.integers(len(xs)))
                self.img[ys[k], xs[k]] = WET


def ell(c, rx, ry):
    return lambda d: d.ellipse([c[0] - rx, c[1] - ry, c[0] + rx, c[1] + ry], fill=255)


def cap(p0, p1, r0, r1=None):
    r1 = r0 if r1 is None else r1

    def f(d):
        d.ellipse([p0[0] - r0, p0[1] - r0, p0[0] + r0, p0[1] + r0], fill=255)
        d.ellipse([p1[0] - r1, p1[1] - r1, p1[0] + r1, p1[1] + r1], fill=255)
        ang = math.atan2(p1[1] - p0[1], p1[0] - p0[0]) + math.pi / 2
        c, s = math.cos(ang), math.sin(ang)
        d.polygon([(p0[0] + c * r0, p0[1] + s * r0), (p1[0] + c * r1, p1[1] + s * r1),
                   (p1[0] - c * r1, p1[1] - s * r1), (p0[0] - c * r0, p0[1] - s * r0)], fill=255)
    return f


def poly(pts):
    return lambda d: d.polygon([tuple(p) for p in pts], fill=255)


def add(a, b, k=1.0):
    return (a[0] + b[0] * k, a[1] + b[1] * k)


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def polar(ang, ln):
    """Ângulo a partir da vertical para baixo; positivo = para a frente (direita)."""
    return (math.sin(ang) * ln, math.cos(ang) * ln)


def rot(v, a):
    c, s = math.cos(a), math.sin(a)
    return (v[0] * c - v[1] * s, v[0] * s + v[1] * c)


THIGH, CALF = 17.0, 16.0
UPPER, FORE = 12.0, 11.0
TORSO = 21.0


def ik(sh, target, l1, l2, bend=1.0):
    """Os ângulos (no jeito de polar) do braço para a mão chegar em target; bend escolhe o cotovelo."""
    dx, dy = target[0] - sh[0], target[1] - sh[1]
    d = max(1e-3, min(math.hypot(dx, dy), l1 + l2 - 0.01))
    base = math.atan2(dx, dy)
    c = (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)
    a1 = base + bend * math.acos(max(-1.0, min(1.0, c)))
    el = add(sh, polar(a1, l1))
    a2 = math.atan2(target[0] - el[0], target[1] - el[1])
    return (a1, a2)


def draw_syringe(cv, hand, ang, liquid):
    """A seringa na mão: o corpo ao longo de ang (polar), a agulha na frente, o êmbolo atrás."""
    d = polar(ang, 1.0)
    side = (-d[1], d[0])
    back = add(hand, d, -4.0)
    front = add(hand, d, 6.0)
    tip = add(front, d, 4.0)
    cv.line(front, tip, STEEL, 1)                                   # a agulha
    # o corpo de vidro (3 px), com o líquido verde do lado da agulha
    for k in (-1, 0, 1):
        o = (side[0] * k, side[1] * k)
        cv.line(add(back, o), add(front, o), GLASS_D if k != 0 else GLASS, 1)
    if liquid > 0.0:
        lq = lerp(front, back, liquid)
        cv.line(front, lq, JUICE, 1)
        cv.px(front[0] + side[0], front[1] + side[1], JUICE_D)
    plunger = add(back, d, -2.0 - 4.0 * (1.0 - liquid))
    cv.line(back, plunger, STEEL, 1)                                # o êmbolo
    cv.line(add(plunger, side, -2.0), add(plunger, side, 2.0), STEEL, 1)
    cv.line(add(back, side, -2.5), add(back, side, 2.5), GLASS_D, 1)  # as abas


def draw_senzi(p):
    cv = Canvas(p.get("seed", 0))
    C0, C1, C2, C3 = (FUR, FUR_D, FUR_B, FUR_B_D) if p.get("rabbit") else (GOO, GOO_D, GOO_B, GOO_B_D)
    cv.pump = p.get("pump", 1.0)
    hip = p["hip"]
    tilt = p["tilt"]          # inclinação do tronco: 0 em pé; ~0.85 na corrida

    def U(dx, dy):
        return add(hip, rot((dx, dy), tilt))

    neck = U(1.0, -TORSO)
    sh_b = U(-1.5, -TORSO + 3.0)
    sh_f = U(2.0, -TORSO + 3.5)

    def leg(lg, front):
        knee = add(hip, polar(lg[0], THIGH))
        foot = add(knee, polar(lg[1], CALF))
        fa = lg[2] if len(lg) > 2 else 0.0
        toe = add(foot, rot((5.0, 0.0), fa))
        sh = cv.lump(hip, knee, 5.0, 3.4) + cv.lump(knee, foot, 3.2, 2.2) + cv.lump(add(foot, (-1.0, 0)), toe, 2.4, 1.8, n=3)
        cv.part(sh, C0 if front else C2, C1 if front else C3)

    def arm(a, sh, front):
        if isinstance(a, dict):   # {"at": ponto, "bend": ±1}: a mão vai até o ponto
            a = ik(sh, a["at"], UPPER, FORE, a.get("bend", 1.0))
        el = add(sh, polar(a[0], UPPER))
        hand = add(el, polar(a[1], FORE))
        shp = cv.lump(sh, el, 3.4, 2.5) + cv.lump(el, hand, 2.4, 2.0)
        if front and p.get("open_f"):
            # a mão aberta, espalmada para cima: a palma e três dedos moles
            d = polar(a[1], 1.0)
            sd = (-d[1], d[0])
            shp.append(("c", (hand[0], hand[1], 2.4 * cv.pump)))
            for k in (-1.0, 0.0, 1.0):
                f0 = add(add(hand, d, 1.5), sd, k * 1.8)
                shp += cv.lump(f0, add(add(f0, d, 3.5), sd, k * 1.0), 1.1, 0.8, n=2, wob=0.1)
        else:
            shp.append(("c", (hand[0], hand[1], 2.6)))
        cv.part(shp, C0 if front else C2, C1 if front else C3)
        if front:
            p["_hand"] = hand
            p["_fore"] = a[1]

    arm(p["arm_b"], sh_b, False)
    leg(p["leg_b"], False)

    # o tronco: um saco mole, mais largo em cima, que escorre
    tor = cv.lump(U(0.0, 1.0), U(1.0, -TORSO + 2.0), 5.6, 6.4, wob=0.18)
    tor += [("c", add(U(-2.5, -1.0), (0, 0)) + (5.0,)), ("c", U(3.5, -TORSO + 5.0) + (5.0,))]
    cv.part(tor, C0, C1)

    leg(p["leg_f"], True)

    if p.get("rabbit"):
        # a cabeça do coelho: redonda, o focinho, o olho vermelho e as orelhas compridas para trás
        nd = p.get("neck", 0.0)
        hc = add(neck, rot((3.5, -6.0), tilt * 0.6 + nd))
        cv.part([("c", (hc[0], hc[1], 5.6)), ("c", (hc[0] + 3.2, hc[1] + 1.6, 3.6))] + cv.lump(neck, hc, 3.6, 4.0, n=2, wob=0.05), C0, C1, drip=False)
        cv.px(hc[0] + 6.6, hc[1] + 1.0, EAR_IN)                           # o nariz
        cv.px(hc[0] + 2.2, hc[1] - 1.2, EYE)
        cv.px(hc[0] + 2.2, hc[1] - 0.2, EYE)
        ea = p.get("ears", 0.0)
        for k, (ox, ln) in enumerate(((-1.5, 15.0), (1.0, 16.0))):
            e0 = add(hc, (ox, -4.0))
            a_ = -0.55 + tilt * 0.4 + ea + k * 0.22
            e1 = add(e0, (math.sin(a_) * ln, -math.cos(a_) * ln))
            cv.part(cv.lump(e0, e1, 2.4, 1.6, n=5, wob=0.06), C0 if k == 1 else C2, C1 if k == 1 else C3, drip=False)
            if k == 1:
                cv.line(lerp(e0, e1, 0.25), lerp(e0, e1, 0.85), EAR_IN, 1)
        tip = hc
    else:
        # o pescoço de caramujo, calombudo
        nd = p.get("neck", 0.0)
        seg = [neck]
        ang = tilt + 0.55 + nd
        for i, ln in enumerate((5.0, 5.0, 4.5)):
            a_ = ang + i * (0.18 + nd * 0.5)
            seg.append(add(seg[-1], (math.sin(a_) * ln, -math.cos(a_) * ln)))
        nk = []
        for i in range(3):
            nk += cv.lump(seg[i], seg[i + 1], 3.8 - i * 0.5, 3.3 - i * 0.5, n=3, wob=0.25)
        tip = seg[-1]
        nk.append(("c", (tip[0] + 1.2, tip[1] + 0.5, 3.0)))
        cv.part(nk, C0, C1)
        if p.get("face", "") == "roar":
            m = add(tip, (3.6, 1.0))
            for dx, dy in ((0, 0), (0, 1), (1, 0), (1, 1), (0, 2)):
                cv.px(m[0] + dx, m[1] + dy, MOUTH)
        # dois tentáculos moles (como os dos caramujos de enfeite, mas sem olhos)
        sway = p.get("tent", 0.0)
        for k, (ox, ln) in enumerate(((0.5, 7.0), (2.6, 8.5))):
            q = [add(tip, (ox + 1.0, -1.5))]
            a0 = 0.9 + k * 0.25 + sway
            for j in range(1, 5):
                a_ = a0 + j * (0.34 + p.get("droop", 0.0))
                q.append(add(q[-1], (math.sin(a_) * ln / 4.0, -math.cos(a_) * ln / 4.0)))
            for j in range(len(q) - 1):
                cv.line(q[j], q[j + 1], C1 if k == 0 else C0, 1)
        # a concha: a mesma dos caramujos de enfeite, um pouco maior, de chapéu
        hat = add(tip, (-1.0, -3.4))
        cv.part([("c", (hat[0], hat[1], 4.3))], SHELL, SHELL, drip=False)
        cv.part([("c", (hat[0] - 0.3, hat[1] + 0.3, 2.5))], SHELL_D, SHELL_D, drip=False)
        cv.px(hat[0] - 0.5, hat[1] - 0.5, SHELL_L)
        cv.px(hat[0] - 2.5, hat[1] - 2.5, SHELL_L)

    p["_neck"] = neck
    arm(p["arm_f"], sh_f, True)
    if p.get("syringe") is not None:
        sa, sl = p["syringe"]
        draw_syringe(cv, p["_hand"], p["_fore"] + sa if sa is not None else p["_fore"], sl)
    if not p.get("rabbit"):
        cv.goo(p.get("goo", 8), wind=p.get("wind", 0.0))
        cv.wet(4)
    return cv.img


def stand_hip(legs, dy=0.0, x=44.0):
    low = max(math.cos(l[0]) * THIGH + math.cos(l[1]) * CALF for l in legs)
    return (x, GROUND - 2.0 - low + dy)


RUN = [
    (0.95, 0.35, -0.2),
    (0.55, 0.15, -0.1),
    (0.05, -0.15, 0.0),
    (-0.55, -0.55, 0.1),
    (-1.05, -1.15, 0.4),
    (-0.75, -2.15, 0.6),
    (0.15, -2.05, 0.2),
    (0.85, -0.85, -0.2),
]
RUN_DY = [0.0, 1.6, 1.0, -0.8, -2.6, -2.8, -1.6, -0.4]


def run_pose(i):
    la, lb = RUN[i % 8], RUN[(i + 4) % 8]
    hip = stand_hip([la, lb], RUN_DY[i % 8] + (2.4 if i % 4 in (1, 2) else 0.0), x=46.0)
    a = 2 * math.pi * i / 8
    tilt = 0.85
    arms = []
    for k in (0, 1):
        s = math.sin(a + k * math.pi)
        arms.append((tilt * 0.5 - s * 1.15, tilt * 0.5 - s * 1.15 + 1.4 + max(0.0, s) * 0.6))
    return {"hip": hip, "tilt": tilt, "leg_f": la, "leg_b": lb, "arm_f": arms[1], "arm_b": arms[0],
            "neck": math.sin(a * 2) * 0.05, "tent": -0.35 + math.sin(a * 2) * 0.15, "wind": -0.6, "goo": 7}


def idle_pose(i):
    b = math.sin(2 * math.pi * i / 4)
    legs = [(0.2, 0.05), (-0.2, -0.05)]
    return {"hip": stand_hip(legs), "tilt": 0.12, "leg_f": legs[0], "leg_b": legs[1],
            "arm_f": (0.15, -0.05), "arm_b": (-0.1, 0.05), "neck": b * 0.06, "tent": b * 0.12}


def flex_pose(i):
    k = min(1.0, i / 2.0)
    legs = [(0.3, 0.1), (-0.3, -0.1)]
    return {"hip": stand_hip(legs), "tilt": 0.05 - 0.1 * k, "leg_f": legs[0], "leg_b": legs[1],
            "arm_f": (0.2 + 2.2 * k, 0.2 + 3.2 * k), "arm_b": (-0.2 - 2.0 * k, -0.2 - 3.0 * k),
            "neck": -0.25 * k + (0.06 if i % 2 else 0.0), "tent": -0.3 * k, "face": "roar" if i >= 2 else ""}


def throw_pose(i):
    w = [-1.2, -1.8, 0.5, 1.3][i]
    legs = [(0.45, 0.2), (-0.5, -0.2)]
    return {"hip": stand_hip(legs), "tilt": 0.1 if w < 0 else 0.45, "leg_f": legs[0], "leg_b": legs[1],
            "arm_f": (math.pi + w * 0.3 if w < 0 else 1.3 + w * 0.3, math.pi + w * 0.6 if w < 0 else 1.5 + w * 0.2),
            "arm_b": (-0.4, 0.2), "neck": 0.1, "tent": 0.0}


def die_pose(i):
    k = i / 3.0
    legs = [(0.3 + 0.9 * k, -0.4 - 1.0 * k), (-0.2 + 0.6 * k, -0.6 - 1.2 * k)]
    return {"hip": stand_hip(legs), "tilt": 0.3 + 0.9 * k, "leg_f": legs[0], "leg_b": legs[1],
            "arm_f": (0.2 + 0.8 * k, 0.1 + 0.8 * k), "arm_b": (0.1 + 0.6 * k, 0.1 + 0.6 * k),
            "neck": 0.5 * k, "tent": 0.4 * k, "droop": 0.2 * k}


def leap_pose(i):
    """0: agachado, mãos nos joelhos (o aviso); 1 e 2: a cambalhota, encolhido, mãos nos joelhos."""
    if i == 0:
        legs = [(1.1, -0.35, -0.1), (0.8, -0.6, 0.0)]
        hip = stand_hip(legs, x=38.0)
        return {"hip": hip, "tilt": 0.95, "leg_f": legs[0], "leg_b": legs[1],
                "arm_f": (0.1, -0.05), "arm_b": (0.0, -0.1), "neck": 0.3, "tent": -0.1}
    sq = 0.12 if i == 2 else 0.0
    legs = [(2.55 + sq, 0.35 + sq, 1.2), (2.4 + sq, 0.2 + sq, 1.1)]
    return {"hip": (40.0, 66.0), "tilt": 0.55 + sq, "leg_f": legs[0], "leg_b": legs[1],
            "arm_f": (0.75, 0.05), "arm_b": (0.65, -0.05), "neck": 0.75, "tent": -0.6 - sq, "droop": -0.05}


def punch_pose(i):
    """0: carrega (o punho atrás); 1: o soco, o braço esticado; 2: segura; 3: volta."""
    if i == 0:
        legs = [(0.55, 0.15, -0.1), (-0.5, -0.45)]
        return {"hip": stand_hip(legs, 2.0, x=40.0), "tilt": 0.2, "leg_f": legs[0], "leg_b": legs[1],
                "arm_f": (-1.25, 1.2), "arm_b": (0.9, 2.3), "neck": -0.1, "tent": 0.3}
    if i in (1, 2):
        legs = [(0.75, 0.05, -0.1), (-0.85, -0.7, 0.3)]
        ext = 0.0 if i == 1 else 0.06
        return {"hip": stand_hip(legs, 1.0, x=40.0), "tilt": 0.55, "leg_f": legs[0], "leg_b": legs[1],
                "arm_f": (1.62 - ext, 1.6 - ext), "arm_b": (-0.9, 0.2), "neck": 0.15, "tent": -0.45 - ext * 3,
                "face": "roar" if i == 1 else ""}
    legs = [(0.5, 0.15, -0.1), (-0.5, -0.35)]
    return {"hip": stand_hip(legs, x=42.0), "tilt": 0.3, "leg_f": legs[0], "leg_b": legs[1],
            "arm_f": (0.9, 1.9), "arm_b": (-0.4, 0.3), "neck": 0.05, "tent": -0.1}


def tired_pose(i):
    """Cansado: curvado, as mãos nos joelhos, ofegando (o corpo sobe e desce)."""
    b = (0.0, 1.0, 0.0, -0.6)[i]
    legs = [(0.75, -0.35, -0.1), (0.5, -0.55, 0.0)]
    hip = stand_hip(legs, b, x=40.0)
    return {"hip": hip, "tilt": 0.8 + b * 0.04, "leg_f": legs[0], "leg_b": legs[1],
            "arm_f": (0.25, 0.1), "arm_b": (0.15, 0.0), "neck": 0.35 + b * 0.05, "tent": 0.1, "droop": 0.15, "goo": 10}


def hold_pose(i):
    """A seringa: a mão da frente bem no alto, aberta, e ele ofegando (a seringa flutua, desenhada no jogo)."""
    b = (0.0, 0.8, 0.0, -0.5)[i]
    legs = [(0.3, 0.0, -0.05), (-0.25, -0.1)]
    return {"hip": stand_hip(legs, b, x=44.0), "tilt": 0.12, "leg_f": legs[0], "leg_b": legs[1],
            "arm_f": (math.pi - 0.08, math.pi - 0.02), "open_f": True, "arm_b": (0.12 + b * 0.05, 0.05),
            "neck": -0.15 + b * 0.04, "tent": -0.2 + b * 0.1, "goo": 9}


INJ = 12


def inject_pose(i):
    """A injeção, quadro a quadro: pega a seringa no alto, desce, crava no pescoço, aperta o êmbolo
    (o verde some), e o PUMP: tudo incha e ele ruge."""
    legs = [(0.35, 0.0, -0.05), (-0.3, -0.15)]
    hip = stand_hip(legs, x=44.0)
    base = {"hip": hip, "tilt": 0.12, "leg_f": legs[0], "leg_b": legs[1], "arm_b": (0.12, 0.05), "goo": 9}
    probe = dict(base, arm_f=(0.0, 0.0))
    draw_senzi(probe)
    neck = probe["_neck"]
    U = lambda dx, dy: add(hip, rot((dx, dy), 0.12))
    if i == 0:
        return dict(base, arm_f=(math.pi - 0.08, math.pi - 0.02), syringe=(None, 1.0), neck=-0.15, tent=-0.2)
    if i in (1, 2):
        at = [None, U(9.0, -TORSO - 16.0), U(12.0, -TORSO - 6.0)][i]
        return dict(base, arm_f={"at": at, "bend": -1.0}, syringe=(0.0, 1.0), neck=-0.1 + 0.15 * i, tent=-0.1)
    if i <= 7:
        liquid = [1.0, 0.85, 0.6, 0.35, 0.1][i - 3]
        jab = 1.0 if i == 3 else 0.0
        return dict(base, arm_f={"at": add(neck, (7.0 - jab, -1.0)), "bend": -1.0}, syringe=(1.9, liquid),
                    neck=0.3, tent=0.25 + 0.05 * (i % 2), droop=0.1, goo=12)
    k = i - 8
    pump = [1.32, 1.42, 1.3, 1.2][k]
    legs2 = [(0.4, 0.1), (-0.4, -0.1)]
    return {"hip": stand_hip(legs2, x=44.0), "tilt": 0.0, "leg_f": legs2[0], "leg_b": legs2[1],
            "arm_f": (2.3, 3.4), "arm_b": (-2.1, -3.2), "neck": -0.3, "tent": -0.5, "face": "roar",
            "pump": pump, "goo": 14}


# ---------------------------------------------------------------- o ringue (D114)

def guard_pose(i):
    """Em guarda: base aberta, punhos na frente do queixo, balançando."""
    b = (0.0, 0.8, 1.2, 0.6)[i]
    legs = [(0.42, -0.1, -0.05), (-0.45, -0.05)]
    return {"hip": stand_hip(legs, b, x=44.0), "tilt": 0.18, "leg_f": legs[0], "leg_b": legs[1],
            "arm_f": (0.95, 2.75), "arm_b": (0.7, 2.9), "neck": 0.05 + b * 0.02, "tent": -0.1 + b * 0.05, "ears": b * 0.04}


WALK = [0.42, 0.25, 0.0, -0.2, 0.0, 0.25]


def walk_pose(i):
    """Andando em guarda: passos curtos, os pés trocando."""
    a = WALK[i]
    legs = [(a, -0.1 - abs(a) * 0.3, -0.05), (-0.45 + (0.42 - a) * 0.9, -0.05 - (0.42 - a) * 0.4)]
    return {"hip": stand_hip(legs, (0.0, 0.8, 1.4, 0.8, 0.0, 0.6)[i], x=44.0), "tilt": 0.2, "leg_f": legs[0], "leg_b": legs[1],
            "arm_f": (0.95, 2.75), "arm_b": (0.7, 2.9), "neck": 0.05, "tent": -0.1, "ears": 0.05 * (i % 2)}


def jab_pose(i):
    """O jab: carrega um tiquinho, estica o braço da frente reto, segura, volta à guarda."""
    legs = [(0.5, -0.05, -0.05), (-0.55, -0.1)]
    arm = [(0.8, 2.5), (1.6, 1.6), (1.58, 1.62), (1.1, 2.4)][i]
    return {"hip": stand_hip(legs, 1.0 if i in (1, 2) else 0.0, x=42.0 if i in (1, 2) else 44.0), "tilt": 0.3 if i in (1, 2) else 0.2,
            "leg_f": legs[0], "leg_b": legs[1], "arm_f": arm, "arm_b": (0.7, 2.9), "neck": 0.1, "tent": -0.3 if i == 1 else -0.1,
            "ears": -0.15 if i == 1 else 0.0}


def block_pose(i):
    """Defendendo: os dois braços fechados na frente, o corpo para trás."""
    legs = [(0.35, -0.15, -0.05), (-0.55, -0.1)]
    return {"hip": stand_hip(legs, 1.5, x=46.0), "tilt": -0.05 - 0.04 * i, "leg_f": legs[0], "leg_b": legs[1],
            "arm_f": (1.35, 3.0), "arm_b": (1.25, 3.05), "neck": -0.1, "tent": 0.15, "ears": 0.2}


def hit_pose(i):
    """Apanhou: a cabeça para trás, os braços abertos."""
    legs = [(0.3, -0.1, -0.05), (-0.5, -0.2)]
    return {"hip": stand_hip(legs, 1.0, x=48.0 + i), "tilt": -0.3 - 0.1 * i, "leg_f": legs[0], "leg_b": legs[1],
            "arm_f": (0.6, 0.2), "arm_b": (-0.5, -0.2), "neck": -0.4, "tent": 0.5, "ears": 0.45, "face": "roar" if i else ""}


def jump_pose(i):
    legs = [(1.2, -0.3, 0.2), (0.6, -0.9, 0.2)] if i == 0 else [(0.6, -0.5, 0.1), (-0.2, -0.8, 0.2)]
    return {"hip": (44.0, 52.0), "tilt": 0.2, "leg_f": legs[0], "leg_b": legs[1],
            "arm_f": (0.95, 2.75), "arm_b": (0.7, 2.9), "neck": 0.0, "ears": -0.25}


def kick_pose(i):
    """O chute: dobra o joelho no alto, estica a perna da frente reta, segura, volta. O corpo vai para trás."""
    lf = [(1.35, -0.3, 0.6), (1.58, 1.58, 1.6), (1.52, 1.52, 1.5), (0.8, 0.1, 0.2)][i]
    lb = (-0.15, -0.05)
    hip = stand_hip([lb], 0.0, x=40.0)
    return {"hip": hip, "tilt": [-0.15, -0.35, -0.32, -0.1][i], "leg_f": lf, "leg_b": lb,
            "arm_f": (0.9, 2.6), "arm_b": (-0.6, 0.6), "neck": -0.15 if i in (1, 2) else 0.0, "ears": 0.3 if i in (1, 2) else 0.1,
            "tent": 0.0}


def upper_pose(i):
    """O gancho: agacha, sobe explodindo com o braço da frente de baixo para cima, segura, volta."""
    if i == 0:
        legs = [(0.9, -0.5, -0.1), (0.4, -0.7)]
        return {"hip": stand_hip(legs, 0.0, x=42.0), "tilt": 0.55, "leg_f": legs[0], "leg_b": legs[1],
                "arm_f": (0.2, 0.9), "arm_b": (0.7, 2.9), "neck": 0.3, "tent": 0.1}
    legs = [(0.25, -0.05, -0.05), (-0.45, -0.2)]
    arm = [(None), (2.3, 3.0), (2.5, 3.05), (1.3, 2.6)][i]
    return {"hip": stand_hip(legs, -1.0 if i == 1 else 0.0, x=46.0), "tilt": -0.1 if i in (1, 2) else 0.1,
            "leg_f": legs[0], "leg_b": legs[1], "arm_f": arm, "arm_b": (-0.4, 0.4), "neck": -0.25 if i == 1 else 0.0,
            "tent": -0.5 if i == 1 else -0.1, "face": "roar" if i == 1 else ""}


def sweep_pose(i):
    """A rasteira: agacha baixo e varre com a perna da frente esticada rente ao chão."""
    if i == 0:
        legs = [(1.2, -0.6, -0.1), (0.7, -0.9)]
        return {"hip": stand_hip(legs, 0.0, x=40.0), "tilt": 0.8, "leg_f": legs[0], "leg_b": legs[1],
                "arm_f": (0.4, 0.8), "arm_b": (0.2, 0.5), "neck": 0.4, "tent": 0.2}
    # quase sentado: o quadril perto do chão, a perna de trás dobrada embaixo, a da frente varrendo
    hip = (38.0, 81.0)
    lf = (1.5, 1.52, 1.45) if i == 1 else (1.25, 0.9, 0.8)
    lb = (2.2, -0.2, -0.4)
    return {"hip": hip, "tilt": 0.55, "leg_f": lf, "leg_b": lb, "arm_f": {"at": (30.0, 91.0), "bend": 1.0},
            "arm_b": {"at": (26.0, 91.0), "bend": 1.0}, "neck": 0.45, "tent": 0.1 if i == 1 else 0.3, "face": "roar" if i == 1 else ""}


def spit_pose(i):
    """O cuspe: inclina para trás enchendo, joga o pescoço para a frente e cospe a gosma."""
    legs = [(0.35, -0.05, -0.05), (-0.45, -0.15)]
    tilt = [-0.25, 0.45, 0.25][i]
    return {"hip": stand_hip(legs, 0.0, x=44.0), "tilt": tilt, "leg_f": legs[0], "leg_b": legs[1],
            "arm_f": (0.4, 0.3), "arm_b": (-0.3, 0.2), "neck": [-0.4, 0.6, 0.3][i], "tent": [0.4, -0.6, -0.3][i],
            "face": "roar" if i == 1 else "", "goo": 12}


def grab_pose(i):
    """O agarrão: os dois braços para a frente, fecha, levanta e arremessa por cima."""
    legs = [(0.5, -0.05, -0.05), (-0.5, -0.15)]
    arms = [((1.4, 1.5), (1.3, 1.45)), ((1.5, 2.0), (1.4, 1.9)), ((2.6, 3.0), (2.5, 2.9)), ((-0.8, 0.2), (-0.6, 0.0))][i]
    return {"hip": stand_hip(legs, 0.0, x=44.0), "tilt": [0.35, 0.3, -0.2, 0.2][i], "leg_f": legs[0], "leg_b": legs[1],
            "arm_f": arms[0], "arm_b": arms[1], "neck": [0.1, 0.1, -0.3, 0.2][i], "tent": [-0.2, 0.0, -0.5, 0.0][i],
            "face": "roar" if i == 2 else ""}


CROUCH_LEGS = [(1.3, -0.65, -0.05), (0.85, -0.95, 0.0)]


def crouch_pose(i):
    """Agachado em guarda: joelhos bem dobrados, os punhos na frente do queixo."""
    legs = CROUCH_LEGS
    return {"hip": stand_hip(legs, (0.0, 0.8)[i], x=42.0), "tilt": 0.35, "leg_f": legs[0], "leg_b": legs[1],
            "arm_f": (1.0, 2.7), "arm_b": (0.75, 2.85), "neck": 0.1, "ears": 0.1 + 0.05 * i}


def crouch_block_pose(i):
    legs = CROUCH_LEGS
    return {"hip": stand_hip(legs, 1.0, x=44.0), "tilt": 0.15, "leg_f": legs[0], "leg_b": legs[1],
            "arm_f": (1.35, 3.0), "arm_b": (1.25, 3.05), "neck": -0.05, "ears": 0.3}


def uppercut_pose(i):
    """O gancho de baixo para cima (estilo Mortal Kombat): agachado com o punho embaixo, explode para cima
    esticando o corpo todo, o punho lá no alto, e volta."""
    if i == 0:
        legs = CROUCH_LEGS
        return {"hip": stand_hip(legs, 1.0, x=40.0), "tilt": 0.45, "leg_f": legs[0], "leg_b": legs[1],
                "arm_f": (0.25, -0.35), "arm_b": (0.75, 2.85), "neck": 0.15, "ears": -0.1}
    if i in (1, 2):
        legs = [(0.35, 0.05, -0.2), (-0.35, -0.2, 0.3)] if i == 1 else [(0.15, 0.0, -0.4), (-0.3, -0.1, 0.5)]
        return {"hip": stand_hip(legs, -2.0 if i == 2 else 0.0, x=44.0), "tilt": -0.05 if i == 1 else -0.2,
                "leg_f": legs[0], "leg_b": legs[1], "arm_f": (2.55, 3.0) if i == 1 else (2.85, 3.1),
                "arm_b": (-0.5, 0.3), "neck": -0.2, "ears": -0.45}
    legs = [(0.6, -0.3, -0.05), (0.2, -0.6)]
    return {"hip": stand_hip(legs, 0.0, x=42.0), "tilt": 0.25, "leg_f": legs[0], "leg_b": legs[1],
            "arm_f": (1.6, 2.6), "arm_b": (0.75, 2.85), "neck": 0.05, "ears": 0.05}


def lowkick_pose(i):
    """A rasteira baixa do coelhão: agachado, varre com a perna da frente rente ao chão."""
    hip = (40.0, 80.0)
    lf = (1.5, 1.53, 1.45) if i == 1 else (1.3, 0.8, 0.7)
    lb = (2.1, -0.3, -0.4)
    return {"hip": hip, "tilt": 0.3, "leg_f": lf, "leg_b": lb, "arm_f": (1.0, 2.7), "arm_b": {"at": (32.0, 91.0), "bend": 1.0},
            "neck": 0.1, "ears": 0.2}


def rabbit(fn):
    """A mesma pose, no coelhão."""
    def f(i):
        q = fn(i)
        q["rabbit"] = True
        return q
    return f


RABBIT_ANIMS = [("guard", 4, rabbit(guard_pose)), ("walk", 6, rabbit(walk_pose)), ("jab", 4, rabbit(jab_pose)),
                ("block", 2, rabbit(block_pose)), ("hit", 2, rabbit(hit_pose)), ("jump", 2, rabbit(jump_pose)),
                ("flex", 6, rabbit(flex_pose)), ("die", 4, rabbit(die_pose)), ("kick", 4, rabbit(kick_pose)),
                ("crouch", 2, rabbit(crouch_pose)), ("crouch_block", 1, rabbit(crouch_block_pose)),
                ("uppercut", 4, rabbit(uppercut_pose)), ("lowkick", 3, rabbit(lowkick_pose))]


ANIMS = [("run", 8, run_pose), ("idle", 4, idle_pose), ("flex", 6, flex_pose), ("throw", 4, throw_pose), ("die", 4, die_pose),
         ("leap", 3, leap_pose), ("punch", 4, punch_pose), ("tired", 4, tired_pose), ("hold", 4, hold_pose),
         ("inject", INJ, inject_pose), ("guard", 4, guard_pose), ("walk", 6, walk_pose), ("block", 2, block_pose),
         ("hit", 2, hit_pose), ("upper", 4, upper_pose), ("sweep", 3, sweep_pose), ("spit", 3, spit_pose),
         ("grab", 4, grab_pose)]


def build(anims, name):
    cols = max(n for _, n, _ in anims)
    sheet = Image.new("RGBA", (cols * FW, len(anims) * FH), (0, 0, 0, 0))
    meta = {"frame": [FW, FH], "ground": GROUND, "anims": {}}
    for row, (an, n, fn) in enumerate(anims):
        for i in range(n):
            pose = fn(i)
            pose.setdefault("seed", row * 31 + i * 7 + 3)
            sheet.paste(Image.fromarray(draw_senzi(pose), "RGBA"), (i * FW, row * FH))
        meta["anims"][an] = {"row": row, "frames": n}
        if an == "hold":
            h = pose["_hand"]
            meta["hand_up"] = [round(h[0], 1), round(h[1], 1)]   # a mão aberta no alto (a seringa flutua ali)
    os.makedirs(os.path.join(ROOT, "art"), exist_ok=True)
    sheet.save(os.path.join(ROOT, "art", name + ".png"))
    with open(os.path.join(ROOT, "art", name + ".json"), "w") as f:
        json.dump(meta, f, indent="\t")
        f.write("\n")
    print("art/%s.png: %d animações, %dx%d" % (name, len(anims), sheet.width, sheet.height))


def main():
    build(ANIMS, "senzi")
    build(RABBIT_ANIMS, "coelhao")


if __name__ == "__main__":
    main()

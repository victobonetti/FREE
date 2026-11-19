"""Folha de sprites do Senzi (D112, 2ª arte). Pixel art quadro a quadro, a partir de um esqueleto por
quadro. O Senzi é alto e atlético, um velocista: pernas longas, cintura fina, músculos secos. Não tem
rosto: no lugar da cabeça, um pescoço mole e calombudo de caramujo, com dois tentáculos caídos e, em
cima, a concha pequena, como um chapéu. A corrida é o principal: tronco bem inclinado para a frente,
as pernas empurrando para trás, como um corredor profissional.

    python3 tools/art/senzi_sprites.py     ->  art/senzi.png  e  art/senzi.json

Quadros de 96x96, virado para a direita, pés na linha 93. Um contorno de nanquim só, em volta da
silhueta; por dentro, luz e sombra e poucas linhas finas.
"""
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
FW, FH = 96, 96
GROUND = 93

INK = (36, 28, 30, 255)
SKIN = (204, 190, 172, 255)      # carne de caramujo: bege acinzentado, úmido
SKIN_D = (146, 132, 124, 255)
SKIN_L = (234, 226, 212, 255)
SHELL = (138, 95, 158, 255)
SHELL_D = (94, 63, 112, 255)
SHELL_L = (186, 146, 206, 255)
MOUTH = (58, 26, 36, 255)
SHINE = (250, 248, 240, 255)


class Canvas:
    def __init__(self):
        self.img = np.zeros((FH, FW, 4), dtype=np.uint8)

    @staticmethod
    def _mask(draw_fn):
        m = Image.new("L", (FW, FH), 0)
        draw_fn(ImageDraw.Draw(m))
        return np.array(m) > 0

    @staticmethod
    def _shift(m, dx, dy):
        out = np.zeros_like(m)
        h, w = m.shape
        xs0, xs1 = max(0, -dx), min(w, w - dx)
        ys0, ys1 = max(0, -dy), min(h, h - dy)
        out[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx] = m[ys0:ys1, xs0:xs1]
        return out

    def _dilate(self, m):
        o = m.copy()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            o |= self._shift(m, dx, dy)
        return o

    def part(self, draw_fn, base, dark=None, light=None, sep=None, shade=1):
        m = self._mask(draw_fn)
        if not m.any():
            return m
        if sep is not None:
            ring = self._dilate(m) & ~m & (self.img[:, :, 3] > 0)
            self.img[ring] = sep
        self.img[m] = base
        if dark is not None:
            self.img[m & ~self._shift(m, -shade, -shade)] = dark
        if light is not None:
            self.img[m & ~self._shift(m, 1, 1)] = light
        return m

    def line(self, p0, p1, col, w=1):
        im = Image.fromarray(self.img, "RGBA")
        ImageDraw.Draw(im).line([tuple(p0), tuple(p1)], fill=col, width=w)
        self.img = np.array(im)

    def outline(self):
        sil = self.img[:, :, 3] > 0
        self.img[self._dilate(sil) & ~sil] = INK


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


def draw_senzi(p):
    cv = Canvas()
    hip = p["hip"]
    tilt = p["tilt"]          # inclinação do tronco: 0 em pé; ~0.85 na corrida

    def U(dx, dy):
        return add(hip, rot((dx, dy), tilt))

    neck = U(1.0, -TORSO)
    sh_b = U(-2.0, -TORSO + 2.0)
    sh_f = U(2.5, -TORSO + 2.5)

    def leg(lg, front):
        knee = add(hip, polar(lg[0], THIGH))
        foot = add(knee, polar(lg[1], CALF))
        base = SKIN if front else SKIN_D
        lt = SKIN_L if front else None
        sep = SKIN_D if front else None
        cv.part(cap(hip, knee, 5.4, 3.3), base, SKIN_D, lt, sep=sep)          # coxa de velocista
        cv.part(ell(lerp(hip, knee, 0.4), 4.6, 4.6), base, SKIN_D, lt)       # o quadríceps
        cv.part(cap(knee, foot, 3.2, 1.9), base, SKIN_D, lt, sep=sep)
        calf_c = lerp(knee, foot, 0.3)
        cv.part(ell(add(calf_c, rot((-1.6, 0), lg[1])), 2.2, 3.4), base, SKIN_D, lt)
        fa = lg[2] if len(lg) > 2 else 0.0
        toe = add(foot, rot((7.5, 0.0), fa))
        cv.part(cap(add(foot, (-1.5, 0)), toe, 2.0, 1.2), SKIN_D, None, None, sep=sep)
        if front:
            cv.line(lerp(hip, knee, 0.25), lerp(hip, knee, 0.75), SKIN_D)

    def arm(a, sh, front):
        el = add(sh, polar(a[0], UPPER))
        hand = add(el, polar(a[1], FORE))
        base = SKIN if front else SKIN_D
        lt = SKIN_L if front else None
        sep = SKIN_D if front else None
        cv.part(cap(sh, el, 3.6, 2.7), base, SKIN_D, lt, sep=sep)
        cv.part(cap(el, hand, 2.5, 1.9), base, SKIN_D, lt, sep=sep)
        cv.part(ell(hand, 2.4, 2.2), base, SKIN_D, lt, sep=sep)

    arm(p["arm_b"], sh_b, False)
    leg(p["leg_b"], False)

    torso = [U(-4.5, 2.0), U(-5.5, -10.0), U(-5.5, -TORSO + 1.0), U(1.0, -TORSO - 1.5),
             U(7.0, -TORSO + 2.0), U(7.5, -13.0), U(4.5, -5.0), U(3.5, 2.0)]
    cv.part(ell(U(-3.0, 0.5), 5.0, 4.4), SKIN, SKIN_D, SKIN_L)   # o glúteo
    cv.part(poly(torso), SKIN, SKIN_D, SKIN_L)
    cv.line(U(1.0, -14.0), U(6.0, -14.5), SKIN_D)
    cv.line(U(3.0, -12.5), U(3.5, -2.0), SKIN_D)
    for y in (-10.0, -7.0, -4.0):
        cv.line(U(2.0, y), U(5.0, y), SKIN_D)
    cv.line(U(-3.5, -9.0), U(-1.0, -3.0), SKIN_D)

    leg(p["leg_f"], True)

    nd = p.get("neck", 0.0)
    seg = [neck]
    ang = tilt + 0.55 + nd
    for i, ln in enumerate((5.0, 5.0, 4.5)):
        a_ = ang + i * (0.18 + nd * 0.5)
        seg.append(add(seg[-1], (math.sin(a_) * ln, -math.cos(a_) * ln)))
    for i in range(3):
        r0 = 3.6 - i * 0.4
        cv.part(cap(seg[i], seg[i + 1], r0, r0 - 0.4), SKIN, SKIN_D, SKIN_L)
        mid = lerp(seg[i], seg[i + 1], 0.5)
        cv.part(ell(add(mid, (-0.8, -1.2)), r0 * 0.75, r0 * 0.6), SKIN, SKIN_D, SKIN_L)
    tip = seg[-1]
    cv.part(ell(add(tip, (1.5, 0.5)), 3.6, 3.0), SKIN, SKIN_D, SKIN_L)
    face = p.get("face", "")
    mouth = add(tip, (4.0, 1.2))
    if face == "roar":
        cv.part(ell(mouth, 2.0, 2.6), MOUTH)
        cv.line(add(mouth, (-1, -2)), add(mouth, (1, -2)), SHINE)
    sway = p.get("tent", 0.0)
    for k, (ox, ln) in enumerate(((0.5, 8.0), (2.8, 9.5))):
        q = [add(tip, (ox + 1.0, -1.5))]
        a0 = 0.9 + k * 0.25 + sway
        for j in range(1, 6):
            a_ = a0 + j * (0.32 + p.get("droop", 0.0))
            q.append(add(q[-1], (math.sin(a_) * ln / 5.0, -math.cos(a_) * ln / 5.0)))
        for j in range(len(q) - 1):
            cv.line(q[j], q[j + 1], SKIN_D if k == 0 else SKIN, 2 if j < 2 else 1)
    hat = add(tip, (-1.0, -3.6))
    cv.part(ell(hat, 4.6, 3.8), SHELL, SHELL_D, SHELL_L)
    pts = []
    for i in range(24):
        a_ = i * 0.48 + 2.4
        r_ = 3.5 - i * 0.14
        pts.append((hat[0] + math.cos(a_) * r_ * 1.15, hat[1] + math.sin(a_) * r_))
    for i in range(len(pts) - 1):
        cv.line(pts[i], pts[i + 1], SHELL_D)
    cv.line(lerp(seg[0], seg[1], 0.3), lerp(seg[1], seg[2], 0.6), SKIN_L)

    arm(p["arm_f"], sh_f, True)
    cv.outline()
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
            "neck": math.sin(a * 2) * 0.05, "tent": -0.35 + math.sin(a * 2) * 0.15}


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


ANIMS = [("run", 8, run_pose), ("idle", 4, idle_pose), ("flex", 6, flex_pose), ("throw", 4, throw_pose), ("die", 4, die_pose)]


def main():
    cols = max(n for _, n, _ in ANIMS)
    sheet = Image.new("RGBA", (cols * FW, len(ANIMS) * FH), (0, 0, 0, 0))
    meta = {"frame": [FW, FH], "ground": GROUND, "anims": {}}
    for row, (name, n, fn) in enumerate(ANIMS):
        for i in range(n):
            sheet.paste(Image.fromarray(draw_senzi(fn(i)), "RGBA"), (i * FW, row * FH))
        meta["anims"][name] = {"row": row, "frames": n}
    os.makedirs(os.path.join(ROOT, "art"), exist_ok=True)
    sheet.save(os.path.join(ROOT, "art", "senzi.png"))
    with open(os.path.join(ROOT, "art", "senzi.json"), "w") as f:
        json.dump(meta, f, indent="\t")
        f.write("\n")
    print("art/senzi.png: %d animações, %dx%d" % (len(ANIMS), sheet.width, sheet.height))


if __name__ == "__main__":
    main()

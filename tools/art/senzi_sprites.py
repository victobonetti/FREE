"""Folha de sprites do Senzi, o caramujo marombado (D112). Pixel art desenhada quadro a quadro, a partir
de um esqueleto por quadro (quadril, joelhos, pés, ombros, cotovelos, punhos, cabeça), com partes
contornadas a nanquim e sombreadas (luz do alto à esquerda).

    python3 tools/art/senzi_sprites.py     ->  art/senzi.png  e  art/senzi.json

Cada quadro tem 80x88 px, virado para a direita, com os pés na linha 85. As linhas da folha são as
animações (art/senzi.json diz a linha e o número de quadros de cada uma).
"""
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
FW, FH = 80, 88
GROUND = 85

INK = (42, 29, 26, 255)
SKIN = (217, 191, 163, 255)
SKIN_D = (169, 140, 116, 255)
SKIN_L = (242, 222, 200, 255)
SHELL = (138, 95, 158, 255)
SHELL_D = (94, 63, 112, 255)
SHELL_L = (183, 140, 204, 255)
BAND = (224, 56, 78, 255)
BAND_D = (160, 30, 50, 255)
SHORTS = (184, 40, 60, 255)
SHORTS_D = (120, 22, 40, 255)
EYE = (250, 248, 240, 255)
PUPIL = (255, 59, 78, 255)
MOUTH = (58, 21, 32, 255)
TONGUE = (224, 101, 124, 255)
SWEAT = (150, 205, 255, 255)
WHITE = (255, 255, 255, 255)


K = 0.8                 # escala do desenho (o esqueleto é pensado em 1.0; o jogo usa os pixels 1:1)
ORIGIN = (40.0, 85.0)   # os pés: o ponto fixo da escala


def _sc(p):
    return (ORIGIN[0] + (p[0] - ORIGIN[0]) * K, ORIGIN[1] + (p[1] - ORIGIN[1]) * K)


class _ScaledDraw:
    """Um ImageDraw que escala as coordenadas (e os raios) por K em volta dos pés."""
    def __init__(self, d):
        self.d = d

    def ellipse(self, box, fill=None):
        a = _sc((box[0], box[1]))
        b = _sc((box[2], box[3]))
        self.d.ellipse([a[0], a[1], b[0], b[1]], fill=fill)

    def polygon(self, pts, fill=None):
        self.d.polygon([_sc(p) for p in pts], fill=fill)


class Canvas:
    def __init__(self):
        self.img = np.zeros((FH, FW, 4), dtype=np.uint8)

    def _mask(self, draw_fn):
        m = Image.new("L", (FW, FH), 0)
        draw_fn(_ScaledDraw(ImageDraw.Draw(m)))
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

    def part(self, draw_fn, base, dark=None, light=None, ink=True, shade=2):
        """Uma parte: contorno de nanquim em volta, a cor e, recortadas nela, a sombra (embaixo e à
        direita) e a luz (em cima e à esquerda)."""
        m = self._mask(draw_fn)
        if not m.any():
            return m
        if ink:
            self.img[self._dilate(m) & ~m] = INK
        self.img[m] = base
        if dark is not None:
            self.img[m & ~self._shift(m, -shade, -shade)] = dark
        if light is not None:
            self.img[m & ~self._shift(m, 1, 1)] = light
        return m

    def line(self, p0, p1, col, w=1):
        im = Image.fromarray(self.img, "RGBA")
        ImageDraw.Draw(im).line([_sc(p0), _sc(p1)], fill=col, width=max(1, int(round(w * K))))
        self.img = np.array(im)

    def px(self, p, col):
        p = _sc(p)
        x, y = int(round(p[0])), int(round(p[1]))
        if 0 <= x < FW and 0 <= y < FH:
            self.img[y, x] = col


def ell(c, rx, ry):
    return lambda d: d.ellipse([c[0] - rx, c[1] - ry, c[0] + rx, c[1] + ry], fill=255)


def cap(p0, p1, r0, r1=None):
    """Um membro: dois círculos unidos (cônico se r1 != r0)."""
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


def polar(ang, ln):
    return (math.sin(ang) * ln, math.cos(ang) * ln)   # 0 = para baixo


# ---------------------------------------------------------------- o boneco

def draw_senzi(pose):
    cv = Canvas()
    hip = pose["hip"]
    lean = pose.get("lean", 0.0)
    breath = pose.get("breath", 0.0)
    chest = add(hip, (lean * 6.0, -17.0 - breath))
    sh_w = 13.0
    sh_l = add(chest, (-sh_w, -1))
    sh_r = add(chest, (sh_w, -1))
    head = add(chest, (2.0 + lean * 3.0 + pose.get("head_dx", 0.0), -11.0 + pose.get("head_dy", 0.0)))

    # a concha nas costas, atrás de tudo
    shell_c = add(chest, (-11.0, 4.0 + pose.get("shell_dy", 0.0)))
    cv.part(ell(shell_c, 13, 13), SHELL, SHELL_D, SHELL_L, shade=3)
    pts = []
    for i in range(40):
        a = i * 0.36 + 0.6
        r = 11.5 - i * 0.27
        pts.append((shell_c[0] + math.cos(a) * r, shell_c[1] + math.sin(a) * r))
    for i in range(len(pts) - 1):
        cv.line(pts[i], pts[i + 1], INK, 1)

    # as fitas da faixa, esvoaçando atrás da cabeça
    flap = pose.get("flap", 0.0)
    tail0 = add(head, (-6, -4))
    cv.part(poly([tail0, add(tail0, (-7, -1 + flap)), add(tail0, (-8, 2 + flap)), add(tail0, (0, 2))]), BAND, BAND_D)

    # o braço de trás (atrás do tronco)
    def arm(sh, a):
        elbow = add(sh, polar(a["up"], 10.0))
        fist = add(elbow, polar(a["fore"], 9.0))
        bic = a.get("bic", 1.0)
        cv.part(cap(sh, elbow, 5.0, 4.4), SKIN, SKIN_D, SKIN_L)
        mid = add(sh, (elbow[0] - sh[0], elbow[1] - sh[1]), 0.5)
        # o bíceps: do lado de dentro do cotovelo
        nx, ny = -(elbow[1] - sh[1]), elbow[0] - sh[0]
        ln = math.hypot(nx, ny) or 1.0
        side = a.get("bic_side", 1.0)
        bc = add(mid, (nx / ln * 2.6 * side, ny / ln * 2.6 * side))
        cv.part(ell(bc, 5.2 * bic, 4.4 * bic), SKIN, SKIN_D, SKIN_L)
        cv.part(cap(elbow, fist, 4.4, 3.6), SKIN, SKIN_D, SKIN_L)
        fore_m = add(elbow, (fist[0] - elbow[0], fist[1] - elbow[1]), 0.4)
        cv.part(ell(fore_m, 4.0, 3.6), SKIN, SKIN_D, SKIN_L)
        cv.part(ell(fist, 4.4, 4.0), SKIN, SKIN_D, SKIN_L)
        cv.line(add(fist, (-2, -1)), add(fist, (2, -1)), INK)   # nós dos dedos
        if a.get("vein", True):
            cv.line(add(bc, (-2, 1)), add(bc, (0, -1)), SKIN_D)
            cv.line(add(bc, (0, -1)), add(bc, (2, 0)), SKIN_D)

    arm(sh_l, pose["arm_back"])

    # pernas (a de trás primeiro)
    def leg(hp, lg, dark_side=False):
        knee = add(hp, polar(lg["thigh"], 11.0))
        foot = add(knee, polar(lg["calf"], 11.0))
        base = SKIN_D if dark_side else SKIN
        cv.part(cap(hp, knee, 5.6, 4.4), base, SKIN_D, None if dark_side else SKIN_L)
        q = add(hp, (knee[0] - hp[0], knee[1] - hp[1]), 0.45)
        cv.part(ell(add(q, (1.5, 0)), 4.6, 5.0), base, SKIN_D, None if dark_side else SKIN_L)
        cv.part(cap(knee, foot, 4.0, 3.0), base, SKIN_D, None if dark_side else SKIN_L)
        c2 = add(knee, (foot[0] - knee[0], foot[1] - knee[1]), 0.3)
        cv.part(ell(add(c2, (-1.2, 0)), 3.4, 4.0), base, SKIN_D, None if dark_side else SKIN_L)
        # o pé: uma sola de caramujo, larga
        cv.part(ell(add(foot, (2.5, 1.0)), 5.5, 2.4), SKIN_D, INK)
        return foot

    hip_b = add(hip, (-4.0, 0))
    hip_f = add(hip, (4.0, 0))
    leg(hip_b, pose["leg_back"], dark_side=True)

    # o tronco em V: cintura fina, ombros largos; o trapézio subindo até o pescoço
    waist_l = add(hip, (-6.0, -2.0))
    waist_r = add(hip, (6.0, -2.0))
    cv.part(poly([waist_l, add(sh_l, (1, -2)), add(head, (-4, 5)), add(head, (4, 5)), add(sh_r, (-1, -2)), waist_r]), SKIN, SKIN_D, SKIN_L, shade=2)
    # deltoides
    cv.part(ell(sh_l, 6.4, 6.0), SKIN, SKIN_D, SKIN_L)
    # peitoral: duas placas
    pec_y = chest[1] + 2.0
    for dx in (-5.4, 5.4):
        cv.part(ell((chest[0] + dx, pec_y + breath * 0.3), 6.0, 4.6), SKIN, SKIN_D, SKIN_L)
    # abdômen: seis gomos
    for row in range(3):
        y = pec_y + 7.0 + row * 3.6
        for dx in (-2.4, 2.4):
            cv.part(ell((chest[0] + dx + lean * (1 - row) * 0.5, y), 2.2, 1.6), SKIN, SKIN_D, SKIN_L, shade=1)
    # serrátil
    for i in range(3):
        y = pec_y + 5.0 + i * 2.4
        cv.line((chest[0] - 9.0 + i * 0.6, y), (chest[0] - 6.6 + i * 0.6, y + 1), INK)
    # o short de academia
    cv.part(poly([add(hip, (-8, -3)), add(hip, (8, -3)), add(hip, (9, 4)), add(hip, (1, 5)), add(hip, (0, 2)), add(hip, (-1, 5)), add(hip, (-9, 4))]), SHORTS, SHORTS_D)
    cv.line(add(hip, (-8, -2)), add(hip, (8, -2)), BAND_D)

    leg(hip_f, pose["leg_front"])
    cv.part(ell(sh_r, 6.6, 6.2), SKIN, SKIN_D, SKIN_L)

    # a cabeça: pequena, queixo quadrado, faixa vermelha, olhos nas antenas
    cv.part(poly([add(head, (-4, 2)), add(head, (5, 2)), add(head, (5, 8)), add(head, (-4, 8))]), SKIN, SKIN_D, SKIN_L)
    cv.part(ell(head, 7.0, 6.6), SKIN, SKIN_D, SKIN_L)
    cv.part(poly([add(head, (0, 2)), add(head, (8, 1)), add(head, (8, 7)), add(head, (1, 7))]), SKIN, SKIN_D)   # o queixo quadrado
    cv.part(poly([add(head, (-7, -5)), add(head, (7, -6)), add(head, (7, -3)), add(head, (-7, -2))]), BAND, BAND_D)
    face = pose.get("face", "angry")
    stalk = pose.get("stalk", 0.0)
    for k, (ex, ln) in enumerate(((-1.5, 9.0), (2.5, 10.0))):
        base_p = add(head, (ex, -7))
        tip = add(base_p, (1.5 + stalk * (1 if k else -1), -ln + abs(stalk)))
        cv.line(base_p, tip, INK, 3)
        cv.line(base_p, tip, SKIN_D if k == 0 else SKIN, 1)
        cv.part(ell(tip, 2.6, 2.6), EYE, (210, 205, 200, 255))
        if face == "tired":
            cv.px(add(tip, (0, 0)), INK)
            cv.px(add(tip, (1, -1)), INK)
            cv.px(add(tip, (-1, 1)), INK)
        elif face == "pain":
            cv.line(add(tip, (-1, -1)), add(tip, (1, 1)), INK)
            cv.line(add(tip, (-1, 1)), add(tip, (1, -1)), INK)
        else:
            cv.part(ell(add(tip, (1, 0)), 1.0, 1.0), PUPIL, ink=False)
    # sobrancelha e boca
    if face in ("angry", "throw"):
        cv.line(add(head, (0, -1)), add(head, (5, 1)), INK, 1)
        cv.line(add(head, (1, 4)), add(head, (6, 3)), INK, 1)
    elif face == "roar":
        cv.line(add(head, (0, -2)), add(head, (5, 0)), INK, 1)
        cv.part(poly([add(head, (1, 2)), add(head, (7, 2)), add(head, (6, 7)), add(head, (2, 7))]), MOUTH)
        cv.line(add(head, (2, 3)), add(head, (6, 3)), WHITE)
        cv.line(add(head, (3, 6)), add(head, (5, 6)), WHITE)
    elif face == "pain":
        cv.part(ell(add(head, (4, 4)), 2.0, 2.5), MOUTH)
    elif face == "tired":
        cv.part(ell(add(head, (4, 4)), 2.0, 1.8), MOUTH)
        cv.part(ell(add(head, (5, 6)), 1.4, 1.6), TONGUE, ink=False)

    # o braço da frente (por cima de tudo)
    arm(sh_r, pose["arm_front"])

    for s in pose.get("sweat", []):
        cv.part(ell(add(head, s), 1.0, 1.6), SWEAT)
    return cv.img


# ---------------------------------------------------------------- as poses

def stand_hip(leg_b, leg_f, base_x=40.0, dy=0.0):
    """O quadril na altura em que o pé mais baixo encosta no chão."""
    def low(lg):
        return math.cos(lg["thigh"]) * 11.0 + math.cos(lg["calf"]) * 11.0 + 2.0
    drop = max(low(leg_b), low(leg_f))
    return (base_x, GROUND - drop + dy)


def run_pose(i, n=8):
    a = 2 * math.pi * i / n
    legs = []
    for k in (0, 1):
        s = math.sin(a + k * math.pi)
        c = math.cos(a + k * math.pi)
        thigh = -s * 0.75 + 0.1
        lift = max(0.0, c) * 1.1
        calf = thigh + lift + (0.15 if s < 0 else 0.0)
        legs.append({"thigh": thigh, "calf": calf})
    hip = stand_hip(legs[0], legs[1], dy=-abs(math.sin(a)) * 1.5)
    arms = []
    for k in (0, 1):
        s = math.sin(a + k * math.pi)
        arms.append({"up": s * 0.9 + 0.15, "fore": s * 0.9 + 2.1, "bic": 1.0})
    return {"hip": hip, "lean": 0.6, "breath": 0.0, "leg_back": legs[0], "leg_front": legs[1],
            "arm_back": arms[1], "arm_front": arms[0], "face": "angry", "flap": math.sin(a * 2) * 2,
            "stalk": math.sin(a * 2) * 1.0, "shell_dy": math.sin(a * 2) * 0.6}


def idle_pose(i, n=4):
    b = math.sin(2 * math.pi * i / n)
    legs = [{"thigh": 0.28, "calf": 0.05}, {"thigh": -0.28, "calf": -0.05}]
    hip = stand_hip(legs[0], legs[1])
    return {"hip": hip, "lean": 0.0, "breath": b * 0.8, "leg_back": legs[0], "leg_front": legs[1],
            "arm_back": {"up": -0.35, "fore": 0.25, "bic": 1.0 + b * 0.03}, "arm_front": {"up": 0.35, "fore": -0.25, "bic": 1.0 + b * 0.03},
            "face": "angry", "flap": b, "stalk": b * 0.5}


def flex_pose(i, n=6):
    k = min(1.0, i / 2.0)
    pulse = 0.0 if i < 2 else (0.08 if i % 2 == 0 else 0.0)
    legs = [{"thigh": 0.35, "calf": 0.1}, {"thigh": -0.35, "calf": -0.1}]
    hip = stand_hip(legs[0], legs[1])
    up = 1.9 * k
    return {"hip": hip, "lean": 0.0, "breath": 1.2 * k, "leg_back": legs[0], "leg_front": legs[1],
            "arm_back": {"up": -0.3 - up * 0.85, "fore": -0.3 - up * 1.55, "bic": 1.0 + 0.3 * k + pulse, "bic_side": -1.0},
            "arm_front": {"up": 0.3 + up * 0.85, "fore": 0.3 + up * 1.55, "bic": 1.0 + 0.3 * k + pulse},
            "face": "roar" if i >= 2 else "angry", "flap": 2.0 * k, "stalk": 1.5 * k}


def throw_pose(i, n=4):
    w = [-1.0, -1.6, 0.6, 1.4][i]
    legs = [{"thigh": 0.4, "calf": 0.2}, {"thigh": -0.45, "calf": -0.15}]
    hip = stand_hip(legs[0], legs[1])
    return {"hip": hip, "lean": 0.3 * (w > 0), "breath": 0.0, "leg_back": legs[0], "leg_front": legs[1],
            "arm_back": {"up": -0.4, "fore": 0.4}, "arm_front": {"up": math.pi - 0.3 * w if w < 0 else 1.2 + w * 0.3, "fore": math.pi - 0.5 * w if w < 0 else 1.4 + w * 0.2, "bic": 1.15},
            "face": "throw", "flap": w}


def hurt_pose(i, n=2):
    legs = [{"thigh": 0.5, "calf": 0.3}, {"thigh": -0.2, "calf": 0.4}]
    hip = stand_hip(legs[0], legs[1])
    return {"hip": hip, "lean": -0.6, "breath": 1.0, "leg_back": legs[0], "leg_front": legs[1],
            "arm_back": {"up": -1.6 - i * 0.2, "fore": -2.2}, "arm_front": {"up": 1.6 + i * 0.2, "fore": 2.2},
            "face": "pain", "head_dx": -2.0, "flap": -2.0 + i * 3}


def tired_pose(i, n=4):
    b = math.sin(2 * math.pi * i / n)
    legs = [{"thigh": 0.6, "calf": 0.2}, {"thigh": -0.5, "calf": -0.2}]
    hip = stand_hip(legs[0], legs[1])
    return {"hip": hip, "lean": 0.0, "breath": 1.5 + b * 1.4, "leg_back": legs[0], "leg_front": legs[1],
            "arm_back": {"up": -1.4, "fore": -1.2, "vein": False}, "arm_front": {"up": 1.4, "fore": 1.2, "vein": False},
            "face": "tired", "flap": 0.0, "stalk": 2.0, "head_dy": 1.0,
            "sweat": [(-8, -6 + i), (8, -4 + (i + 2) % 4)] if i % 2 == 0 else [(-9, -3)]}


def fly_pose(i, n=4):
    a = 2 * math.pi * i / n
    legs = [{"thigh": 0.9 + math.sin(a) * 0.4, "calf": 0.3}, {"thigh": -0.9 - math.sin(a) * 0.4, "calf": -0.4}]
    hip = (40.0, 52.0)
    return {"hip": hip, "lean": 0.0, "breath": 1.0, "leg_back": legs[0], "leg_front": legs[1],
            "arm_back": {"up": -2.2 + math.sin(a) * 0.5, "fore": -2.6}, "arm_front": {"up": 2.2 - math.sin(a + 1) * 0.5, "fore": 2.6},
            "face": "pain", "flap": math.sin(a * 2) * 3}


ANIMS = [
    ("run", 8, run_pose),
    ("idle", 4, idle_pose),
    ("flex", 6, flex_pose),
    ("throw", 4, throw_pose),
    ("hurt", 2, hurt_pose),
    ("tired", 4, tired_pose),
    ("fly", 4, fly_pose),
]


def main():
    cols = max(n for _, n, _ in ANIMS)
    sheet = Image.new("RGBA", (cols * FW, len(ANIMS) * FH), (0, 0, 0, 0))
    meta = {"frame": [FW, FH], "ground": GROUND, "anims": {}}
    for row, (name, n, fn) in enumerate(ANIMS):
        for i in range(n):
            img = Image.fromarray(draw_senzi(fn(i, n)), "RGBA")
            if name == "tired":
                # deitado de costas, em cima da concha (girado, centrado, encostado no chão)
                rot = img.rotate(90, resample=Image.NEAREST, expand=True)
                bb = rot.getbbox()
                rot = rot.crop(bb)
                if rot.width > FW - 2:
                    f = (FW - 2) / rot.width
                    rot = rot.resize((int(rot.width * f), int(rot.height * f)), Image.NEAREST)
                img = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
                img.paste(rot, ((FW - rot.width) // 2, GROUND + 2 - rot.height))
            sheet.paste(img, (i * FW, row * FH))
        meta["anims"][name] = {"row": row, "frames": n}
    os.makedirs(os.path.join(ROOT, "art"), exist_ok=True)
    sheet.save(os.path.join(ROOT, "art", "senzi.png"))
    with open(os.path.join(ROOT, "art", "senzi.json"), "w") as f:
        json.dump(meta, f, indent="\t")
        f.write("\n")
    print("art/senzi.png: %d animações, %dx%d" % (len(ANIMS), sheet.width, sheet.height))


if __name__ == "__main__":
    main()

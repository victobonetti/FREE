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

    def part(self, draw_fn, base, dark=None, light=None, ink=False, shade=2, sep=None):
        """Uma parte: a cor e, recortadas nela, a sombra (embaixo e à direita) e a luz (em cima e à
        esquerda). Sem contorno por parte (o nanquim vai só em volta da silhueta, no fim); `sep` é
        uma linha fina de separação em volta (para um membro na frente de outro)."""
        m = self._mask(draw_fn)
        if not m.any():
            return m
        if ink:
            self.img[self._dilate(m) & ~m] = INK
        elif sep is not None:
            ring = self._dilate(m) & ~m & (self.img[:, :, 3] > 0)
            self.img[ring] = sep
        self.img[m] = base
        if dark is not None:
            self.img[m & ~self._shift(m, -shade, -shade)] = dark
        if light is not None:
            self.img[m & ~self._shift(m, 1, 1)] = light
        return m

    def outline(self):
        """O nanquim: um contorno só, em volta da silhueta inteira."""
        sil = self.img[:, :, 3] > 0
        self.img[self._dilate(sil) & ~sil] = INK

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

def rot(v, a):
    """Gira o vetor (x, y) de tela por `a` rad (positivo: o alto vai para a frente, para a direita)."""
    c, s_ = math.cos(a), math.sin(a)
    return (v[0] * c - v[1] * s_, v[0] * s_ + v[1] * c)


SEP = SKIN_D     # a linha fina que separa um membro do que está atrás dele


def draw_senzi(pose):
    cv = Canvas()
    hip = pose["hip"]
    tilt = pose.get("tilt", 0.0)          # inclinação do tronco (a corrida de sprint: para a frente)
    breath = pose.get("breath", 0.0)

    def U(dx, dy):
        return add(hip, rot((dx, dy), tilt))

    chest = U(0, -17.0 - breath)
    sh_l = U(-12.0, -18.0 - breath)
    sh_r = U(12.0, -18.0 - breath)
    head = U(2.5 + pose.get("head_dx", 0.0), -29.0 + pose.get("head_dy", 0.0))
    head = add(head, (pose.get("head_fwd", 0.0), 0))

    # a concha nas costas, atrás de tudo
    shell_c = U(-11.0, -13.0 + pose.get("shell_dy", 0.0))
    cv.part(ell(shell_c, 13, 13), SHELL, SHELL_D, SHELL_L, shade=3)
    pts = []
    for i in range(40):
        a = i * 0.36 + 0.6
        r = 11.5 - i * 0.27
        pts.append((shell_c[0] + math.cos(a) * r, shell_c[1] + math.sin(a) * r))
    for i in range(len(pts) - 1):
        cv.line(pts[i], pts[i + 1], SHELL_D, 1)

    # as fitas da faixa, esvoaçando atrás da cabeça
    flap = pose.get("flap", 0.0)
    tail0 = add(head, (-6, -4))
    cv.part(poly([tail0, add(tail0, (-8, -2 + flap)), add(tail0, (-9, 2 + flap)), add(tail0, (0, 2))]), BAND, BAND_D)

    def arm(sh, a, front):
        up_a = a["up"] + tilt * a.get("follow", 1.0)
        fore_a = a["fore"] + tilt * a.get("follow", 1.0)
        elbow = add(sh, polar(up_a, 10.5))
        fist = add(elbow, polar(fore_a, 9.5))
        sep = SEP if front else None
        dk = SKIN_D
        base = SKIN if front else SKIN_D
        lt = SKIN_L if front else None
        cv.part(cap(sh, elbow, 5.4, 4.6), base, dk, lt, sep=sep)
        # o bíceps: volume no lado de dentro do braço, sem contorno (só a luz)
        mid = add(sh, (elbow[0] - sh[0], elbow[1] - sh[1]), 0.5)
        nx, ny = -(elbow[1] - sh[1]), elbow[0] - sh[0]
        ln = math.hypot(nx, ny) or 1.0
        side = a.get("bic_side", 1.0)
        bc = add(mid, (nx / ln * 2.0 * side, ny / ln * 2.0 * side))
        cv.part(ell(bc, 4.8 * a.get("bic", 1.0), 4.0 * a.get("bic", 1.0)), base, dk, lt)
        cv.part(cap(elbow, fist, 4.6, 3.8), base, dk, lt, sep=sep)
        cv.part(ell(fist, 4.2, 3.9), base, dk, lt, sep=sep)
        if front:
            cv.line(add(fist, (-1.5, -1.5)), add(fist, (1.5, -1.5)), SKIN_D)   # nós dos dedos

    def leg(hp, lg, front):
        knee = add(hp, polar(lg["thigh"], 11.5))
        foot = add(knee, polar(lg["calf"], 11.5))
        base = SKIN if front else SKIN_D
        lt = SKIN_L if front else None
        sep = SEP if front else None
        cv.part(cap(hp, knee, 6.0, 4.6), base, SKIN_D, lt, sep=sep)
        cv.part(cap(knee, foot, 4.4, 3.0), base, SKIN_D, lt, sep=sep)
        # a panturrilha (volume atrás da canela)
        c2 = add(knee, (foot[0] - knee[0], foot[1] - knee[1]), 0.32)
        cv.part(ell(add(c2, (-1.4, 0)), 3.4, 4.2), base, SKIN_D, lt)
        # o pé: sola de caramujo, apontando para a frente
        ang = lg.get("foot", 0.0)
        cv.part(poly([add(foot, (-3, -2)), add(foot, rot((6.5, -1.5), ang)), add(foot, rot((6.5, 1.5), ang)), add(foot, (-3, 2))]), SKIN_D, None, None, sep=sep)
        return foot

    # o braço e a perna de trás
    arm(sh_l, pose["arm_back"], False)
    leg(U(-3.5, 0), pose["leg_back"], False)

    # o tronco em V: cintura fina, ombros largos; o trapézio subindo até o pescoço
    torso = [U(-6, -2), U(-12, -19 - breath), U(-4, -24 - breath), U(5, -24 - breath), U(12, -19 - breath), U(6, -2)]
    cv.part(poly(torso), SKIN, SKIN_D, SKIN_L, shade=2)
    # peitoral: luz em cima, sombra embaixo, e a divisão (linha fina)
    for dx in (-5.0, 5.0):
        pc = U(dx, -15.5 - breath * 0.7)
        cv.part(ell(pc, 5.6, 3.8), SKIN, SKIN_D, SKIN_L, shade=1)
    cv.line(U(0, -18 - breath), U(0, -3), SKIN_D)
    cv.line(U(-9, -12.5), U(-1, -11.5), SKIN_D)
    cv.line(U(9, -12.5), U(1, -11.5), SKIN_D)
    # abdômen: só as linhas dos gomos (sem bolinhas)
    for row in range(3):
        y = -9.0 + row * 2.6
        cv.line(U(-3.5, y), U(3.5, y), SKIN_D)
    # oblíquo e serrátil
    cv.line(U(-7, -12), U(-5, -4), SKIN_D)
    # o short de academia
    cv.part(poly([U(-8, -3), U(8, -3), U(9, 4), U(1, 5), U(0, 2), U(-1, 5), U(-9, 4)]), SHORTS, SHORTS_D)
    cv.line(U(-8, -2), U(8, -2), BAND_D)

    # a perna da frente
    leg(U(3.5, 0), pose["leg_front"], True)
    # deltoide da frente
    cv.part(ell(sh_r, 6.2, 5.6), SKIN, SKIN_D, SKIN_L)

    # a cabeça: pequena, queixo quadrado, faixa vermelha, olhos nas antenas
    cv.part(poly([add(head, (-4, 2)), add(head, (5, 2)), add(head, (6, 9)), add(head, (-3, 9))]), SKIN, SKIN_D, SKIN_L)
    cv.part(ell(head, 6.6, 6.2), SKIN, SKIN_D, SKIN_L)
    cv.part(poly([add(head, (0, 2)), add(head, (8, 1)), add(head, (8, 7)), add(head, (1, 7))]), SKIN, SKIN_D)
    cv.part(poly([add(head, (-7, -5)), add(head, (7, -6)), add(head, (7, -3)), add(head, (-7, -2))]), BAND, BAND_D)
    face = pose.get("face", "angry")
    stalk = pose.get("stalk", 0.0)
    sweep = pose.get("stalk_back", 0.0)   # na corrida, as antenas vão para trás com o vento
    for k, (ex, ln) in enumerate(((-1.5, 9.0), (2.5, 10.0))):
        base_p = add(head, (ex, -7))
        tip = add(base_p, (1.5 + stalk * (1 if k else -1) - sweep, -ln + abs(stalk) + abs(sweep) * 0.4))
        cv.line(base_p, tip, SKIN_D if k == 0 else SKIN, 2)
        cv.part(ell(tip, 2.5, 2.5), EYE, (210, 205, 200, 255))
        if face == "tired":
            cv.px(tip, INK)
            cv.px(add(tip, (1, -1)), INK)
            cv.px(add(tip, (-1, 1)), INK)
        elif face == "pain":
            cv.line(add(tip, (-1, -1)), add(tip, (1, 1)), INK)
            cv.line(add(tip, (-1, 1)), add(tip, (1, -1)), INK)
        else:
            cv.part(ell(add(tip, (1, 0)), 1.0, 1.0), PUPIL)
    if face in ("angry", "throw"):
        cv.line(add(head, (0, -1)), add(head, (5, 1)), INK, 1)
        cv.line(add(head, (2, 4)), add(head, (6, 3)), INK, 1)
    elif face == "roar":
        cv.line(add(head, (0, -2)), add(head, (5, 0)), INK, 1)
        cv.part(poly([add(head, (1, 2)), add(head, (7, 2)), add(head, (6, 7)), add(head, (2, 7))]), MOUTH)
        cv.line(add(head, (2, 3)), add(head, (6, 3)), WHITE)
        cv.line(add(head, (3, 6)), add(head, (5, 6)), WHITE)
    elif face == "pain":
        cv.part(ell(add(head, (4, 4)), 2.0, 2.5), MOUTH)
    elif face == "tired":
        cv.part(ell(add(head, (4, 4)), 2.0, 1.8), MOUTH)
        cv.part(ell(add(head, (5, 6)), 1.4, 1.6), TONGUE)

    # o braço da frente (por cima de tudo)
    arm(sh_r, pose["arm_front"], True)
    for sw in pose.get("sweat", []):
        cv.part(ell(add(head, sw), 1.0, 1.6), SWEAT)
    cv.outline()
    return cv.img


# ---------------------------------------------------------------- as poses

def stand_hip(leg_b, leg_f, base_x=40.0, dy=0.0):
    """O quadril na altura em que o pé mais baixo encosta no chão."""
    def low(lg):
        return math.cos(lg["thigh"]) * 11.5 + math.cos(lg["calf"]) * 11.5 + 2.0
    drop = max(low(leg_b), low(leg_f))
    return (base_x, GROUND - drop + dy)


# O ciclo de sprint, pose a pose (ângulos a partir da vertical, positivo = para a frente): a perna A;
# a B é a mesma com meio ciclo de atraso.
RUN_LEG = [
    (0.65, 0.25),    # 0 contato: o pé da frente pousa à frente
    (0.30, -0.05),   # 1 apoio: o peso desce
    (0.00, -0.15),   # 2 passagem: a perna debaixo do corpo
    (-0.55, -0.55),  # 3 impulso
    (-0.85, -1.35),  # 4 saída: a perna esticada atrás, o pé no ar
    (-0.25, -2.05),  # 5 recuperação: o calcanhar sobe
    (0.95, -0.45),   # 6 joelho alto
    (1.15, 0.45),    # 7 alcance: a canela abre para a frente
]
RUN_HIP = [0.0, 1.2, 0.8, -0.6, -2.0, -2.2, -1.0, -0.2]   # sobe no voo, desce no apoio


def run_pose(i, n=8):
    """Sprint: tronco inclinado para a frente, joelho alto, a perna de trás esticada no impulso, os
    braços bombeando em arco grande (o punho da frente sobe até a altura do rosto)."""
    la = RUN_LEG[i % 8]
    lb = RUN_LEG[(i + 4) % 8]
    legs = [{"thigh": la[0], "calf": la[1], "foot": -0.2}, {"thigh": lb[0], "calf": lb[1], "foot": -0.2}]
    # o pé de apoio no chão: o mais baixo dos dois, menos nos quadros de voo
    hip = stand_hip(legs[0], legs[1], base_x=38.0, dy=RUN_HIP[i % 8] + (2.0 if i % 4 in (0, 1) else 0.0))
    a = 2 * math.pi * i / 8
    arms = []
    for k in (0, 1):
        s_ = math.sin(a + k * math.pi)        # oposto à perna do mesmo lado
        arms.append({"up": -s_ * 1.0 + 0.15, "fore": -s_ * 0.9 + 2.0 + max(0.0, -s_) * 0.5, "bic": 1.0, "follow": 0.5})
    return {"hip": hip, "tilt": 0.42, "breath": 0.0, "leg_back": legs[1], "leg_front": legs[0],
            "arm_back": arms[0], "arm_front": arms[1], "face": "angry", "flap": math.sin(a * 2) * 2 - 1,
            "stalk": 0.0, "stalk_back": 3.0 + math.sin(a * 2), "head_fwd": 1.0, "shell_dy": math.sin(a * 2) * 0.6}


def idle_pose(i, n=4):
    b = math.sin(2 * math.pi * i / n)
    legs = [{"thigh": 0.28, "calf": 0.05}, {"thigh": -0.28, "calf": -0.05}]
    hip = stand_hip(legs[0], legs[1])
    return {"hip": hip, "tilt": 0.05, "breath": b * 0.8, "leg_back": legs[0], "leg_front": legs[1],
            "arm_back": {"up": -0.3, "fore": 0.2}, "arm_front": {"up": 0.3, "fore": -0.2},
            "face": "angry", "flap": b, "stalk": b * 0.5}


def flex_pose(i, n=6):
    k = min(1.0, i / 2.0)
    pulse = 0.0 if i < 2 else (0.08 if i % 2 == 0 else 0.0)
    legs = [{"thigh": 0.35, "calf": 0.1}, {"thigh": -0.35, "calf": -0.1}]
    hip = stand_hip(legs[0], legs[1])
    up = 1.9 * k
    return {"hip": hip, "tilt": 0.0, "breath": 1.2 * k, "leg_back": legs[0], "leg_front": legs[1],
            "arm_back": {"up": -0.3 - up * 0.85, "fore": -0.3 - up * 1.55, "bic": 1.0 + 0.3 * k + pulse, "bic_side": -1.0},
            "arm_front": {"up": 0.3 + up * 0.85, "fore": 0.3 + up * 1.55, "bic": 1.0 + 0.3 * k + pulse},
            "face": "roar" if i >= 2 else "angry", "flap": 2.0 * k, "stalk": 1.5 * k}


def throw_pose(i, n=4):
    w = [-1.0, -1.6, 0.6, 1.4][i]
    legs = [{"thigh": 0.5, "calf": 0.25}, {"thigh": -0.5, "calf": -0.15}]
    hip = stand_hip(legs[0], legs[1])
    return {"hip": hip, "tilt": -0.15 if w < 0 else 0.3, "breath": 0.0, "leg_back": legs[0], "leg_front": legs[1],
            "arm_back": {"up": -0.4, "fore": 0.4},
            "arm_front": {"up": math.pi - 0.3 * w if w < 0 else 1.2 + w * 0.3, "fore": math.pi - 0.5 * w if w < 0 else 1.4 + w * 0.2, "bic": 1.15, "follow": 0.0},
            "face": "throw", "flap": w}


def hurt_pose(i, n=2):
    legs = [{"thigh": 0.5, "calf": 0.3}, {"thigh": -0.2, "calf": 0.4}]
    hip = stand_hip(legs[0], legs[1])
    return {"hip": hip, "tilt": -0.35, "breath": 1.0, "leg_back": legs[0], "leg_front": legs[1],
            "arm_back": {"up": -1.6 - i * 0.2, "fore": -2.2}, "arm_front": {"up": 1.6 + i * 0.2, "fore": 2.2},
            "face": "pain", "head_dx": -2.0, "flap": -2.0 + i * 3}


def tired_pose(i, n=4):
    b = math.sin(2 * math.pi * i / n)
    legs = [{"thigh": 0.6, "calf": 0.2}, {"thigh": -0.5, "calf": -0.2}]
    hip = stand_hip(legs[0], legs[1])
    return {"hip": hip, "tilt": 0.0, "breath": 1.5 + b * 1.4, "leg_back": legs[0], "leg_front": legs[1],
            "arm_back": {"up": -1.4, "fore": -1.2}, "arm_front": {"up": 1.4, "fore": 1.2},
            "face": "tired", "flap": 0.0, "stalk": 2.0, "head_dy": 1.0,
            "sweat": [(-8, -6 + i), (8, -4 + (i + 2) % 4)] if i % 2 == 0 else [(-9, -3)]}


def fly_pose(i, n=4):
    a = 2 * math.pi * i / n
    legs = [{"thigh": 0.9 + math.sin(a) * 0.4, "calf": 0.3}, {"thigh": -0.9 - math.sin(a) * 0.4, "calf": -0.4}]
    hip = (40.0, 52.0)
    return {"hip": hip, "tilt": 0.0, "breath": 1.0, "leg_back": legs[0], "leg_front": legs[1],
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

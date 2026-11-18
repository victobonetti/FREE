"""Fase 4 do ato 3: Esporos (40x16). D111.

Apresenta a bufa-esporos: o cogumelo redondo solta, no ritmo (e quando alguém encosta nele), uma
nuvem de esporos que cai devagar para o chão de agora e fere ao encostar. Dois chapéus-mola por cima
dos espinhos, com bufas no teto: quique no momento certo. Depois, o muro alto com a fresta lá em cima
(girar no alto do quique, como em Chapéus) e, do outro lado, a volta a pé até a porta, debaixo da
chuva de esporos.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("esporos", "Esporos", 40, 16, theme="fungos",
           hint="As nuvens de esporos caem para o chão de agora. Não encoste nelas",
           notes="Ato 3, fase 4 (D111). Chapéus-mola sob bufas-esporos (no ritmo); o muro com a fresta no alto (girar no "
                 "alto do quique); do outro lado, a porta, debaixo da chuva de esporos.",
           extra={"door_open": True})
lv.ascii([
    "########################################",
    "#......................................#",
    "#......................................#",
    "#.....................##....##.##......#",
    "#.....................##...............#",
    "#.....................##...............#",
    "#.....................##...............#",
    "#.....................##...............#",
    "#.....................##...............#",
    "#.....................##.DD............#",
    "#.....................##.DD............#",
    "#PP...................##.DD............#",
    "#PP.^^..^^^..^^.......##.DD............#",
    "########################################",
    "########################################",
    "########################################",
])
for c in (6, 11):
    lv.add("bouncers", {"rect": [c, 12, 2, 1], "power": 300.0, "dir": 0})
lv.add("bouncers", {"rect": [19, 12, 2, 1], "power": 440.0, "dir": 0})
lv.add("puffs", {"rect": [6, 1, 2, 2], "period": 2.4, "phase": 0.0})
lv.add("puffs", {"rect": [11, 1, 2, 2], "period": 2.4, "phase": 1.2})
lv.add("puffs", {"rect": [28, 4, 2, 2], "period": 3.5, "phase": 0.0})
lv.add("puffs", {"rect": [31, 4, 2, 2], "period": 3.5, "phase": 1.75})
cx = lv.cx
lv.step("wait", 5)
lv.step("jump", 1, 10)
lv.step("steer", *lv.xr(6, 7), 30)
lv.mark("chapéu 1")
lv.step("steer", *lv.xr(11, 12), 40)
lv.mark("chapéu 2")
lv.step("steer", *lv.xr(16, 17), 40)
lv.mark("chão")
lv.step("run_to", cx(19) + 4)
lv.mark("chapéu forte")
lv.step("steer", *lv.xr(19, 20), 4)
lv.step("apex", *lv.xr(19, 20))
lv.step("rotate", 1)
lv.step("wait_ground")
lv.mark("do outro lado")
lv.step("rotate", -1)              # volta logo: as nuvens também caem para a parede
lv.step("wait_ground")
lv.mark("voltou")
lv.step("wait_spores", 24 * 8, 38 * 8, 0)   # espera a chuva de esporos dar uma folga
lv.step("to_door")
lv.save()

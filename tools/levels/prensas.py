"""Fase 3 do ato 2: Prensas e vapor (36x14, 2 baterias). Refeita no D105 (2ª versão): uma ideia só.

A prensa fecha a passagem para o resto da sala e só sobe com o botão do chão apertado. A caixa está
numa prateleira alta, fora do alcance. Girando a sala para a direita, a caixa escorrega pela
prateleira até a divisória; quando a sala volta, ela cai no rebaixo do botão, bem na frente da prensa,
e a prensa sobe. Do outro lado, um jato de vapor no ritmo antes da porta.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("prensas", "Prensas e vapor", 36, 14,
           hint="A prensa só sobe com o botão apertado. Gire: a caixa escorrega até ele",
           notes="Ato 2, fase 3 (D105, 2ª versão). A prensa fecha a passagem e sobe com o botão do chão apertado. A "
                 "caixa está numa prateleira alta; girando para a direita, ela escorrega até a divisória e, na volta "
                 "da sala, cai no botão. Depois, um jato de vapor no ritmo antes da porta.",
           extra={"music": "res://music/industrial-theme.mp3"})
lv.ascii([
    "####################################",
    "#..........LL....##...........HH...#",
    "#......BB..LL....##...........HH...#",
    "#......BB..........................#",
    "#.....####.........................#",
    "#..................................#",
    "#..................................#",
    "#................................DD#",
    "#................................DD#",
    "#PP..............................DD#",
    "#PP.#................+......+....DD#",
    "###############..#############SS####",
    "###############..#############SS####",
    "####################################",
])
lv.add("plates", {"rect": [15, 12, 2], "ch": 0})
lv.add("movers", {"ch": 0, "off": [17, 7, 2, 4], "on": [17, 3], "speed": 90.0, "spikes": 2})
lv.add("vents", {"rect": [25, 4, 2, 7], "dir": 0, "period": 2.5, "on": 0.8, "phase": 0.0})
cx = lv.cx
lv.step("wait", 5)
lv.step("rotate", 1)
lv.step("wait_revert")
lv.step("wait_until", "box_settled")
lv.mark("caixa no botão")
lv.step("wait", 40)
lv.step("jump_in_place", 1, 22, *lv.xr(6, 10), 11)
lv.step("run_to", cx(12))
lv.step("run_to", cx(21))
lv.mark("bateria 1")
lv.step("wait_vent", 0, 60)
lv.step("run_to", cx(28))
lv.mark("bateria 2")
lv.step("wait_cutscene")
lv.step("wait_until", "door_open")
lv.step("to_door")
lv.save()

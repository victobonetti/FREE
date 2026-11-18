"""Fase 1 do ato 3: Broto (30x14, 1 bateria). D107.

Apresenta o broto: o cogumelo cresce contra a gravidade de agora. Três brotos nascem na parede da
esquerda, recolhidos. Girando a sala para a esquerda, a parede vira chão e eles crescem; quando a sala
volta, ficam de lado, como uma escada de chapéus flutuando, e vão murchando devagar para a parede.
Sobe-se por eles até a bateria no alto, antes que murchem.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("broto", "Broto", 30, 14, theme="fungos",
           hint="Cogumelos crescem para cima. Gire: depois eles murcham devagar",
           notes="Ato 3, fase 1 (D107). Três brotos na parede da esquerda; girar para a esquerda os faz crescer; "
                 "na volta da sala, viram uma escada de chapéus que murcha devagar até a parede. Sobe-se até a "
                 "bateria no alto antes que murchem.")
lv.ascii([
    "##############################",
    "#........................HHLL#",
    "#........................HHLL#",
    "#....................+.......#",
    "#..................#####.....#",
    "#............................#",
    "#............................#",
    "#..........................DD#",
    "#..........................DD#",
    "#..PP......................DD#",
    "#..PP......................DD#",
    "#########################SS###",
    "#########################SS###",
    "##############################",
])
for row, ln in ((8, 6), (6, 11), (4, 16)):
    lv.add("sprouts", {"rect": [1, row, 2, 2], "dir": 1, "len": ln, "speed": 80.0, "back": 16.0})
cx = lv.cx
lv.step("wait", 5)
lv.step("rotate", -1)
lv.step("wait_revert")
lv.step("wait_ground")
lv.mark("voltou")
lv.step("jump_in_place", -1, 22, *lv.xr(5, 7), 8)
lv.mark("chapéu 1")
lv.step("jump_in_place", 1, 22, *lv.xr(10, 13), 6)
lv.mark("chapéu 2")
lv.step("jump_in_place", 1, 22, *lv.xr(15, 18), 4)
lv.mark("chapéu 3")
lv.step("jump_in_place", 1, 22, *lv.xr(19, 22), 4)
lv.mark("bateria")
lv.step("wait_cutscene")
lv.step("wait_until", "door_open")
lv.step("to_door")
lv.save()

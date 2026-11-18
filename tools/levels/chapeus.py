"""Fase 2 do ato 3: Chapéus (40x18). D111.

Apresenta o cogumelo-mola: o chapéu quica quem cai nele, para onde ele aponta. Uma corrente de três
chapéus por cima dos espinhos; depois, um chapéu mais forte diante de um muro alto, com uma fresta lá
em cima. O quique sozinho não leva pela fresta; girar no alto do quique põe a gravidade de lado e o
coelho "cai" pela fresta (o embalo do quique sobrevive ao giro). Do outro lado, a sala volta e ele
pousa perto da porta.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("chapeus", "Chapéus", 40, 18, theme="fungos",
           hint="Cogumelos quicam. Gire no alto do pulo para cair de lado",
           notes="Ato 3, fase 2 (D111). Três chapéus-mola sobre espinhos e um mais forte diante de um muro alto com uma "
                 "fresta no alto: girar no alto do quique faz o coelho cair de lado pela fresta.",
           extra={"door_open": True})
lv.ascii([
    "########################################",
    "#......................................#",
    "#......................................#",
    "#..........................##..........#",
    "#..........................##..........#",
    "#..........................##..........#",
    "#..........................##..........#",
    "#..........................##..........#",
    "#..........................##..........#",
    "#..........................##..........#",
    "#..........................##..........#",
    "#..........................##.......DD.#",
    "#..........................##.......DD.#",
    "#.PP.......................##.......DD.#",
    "#.PP..^^^..^^^..^^^..^.....##.......DD.#",
    "########################################",
    "########################################",
    "########################################",
])
for c in (9, 14, 19):
    lv.add("bouncers", {"rect": [c, 14, 2, 1], "power": 300.0, "dir": 0})
lv.add("bouncers", {"rect": [24, 14, 2, 1], "power": 440.0, "dir": 0})
cx = lv.cx
lv.step("wait", 5)
lv.step("run_to", cx(4))
lv.step("jump", 1, 10)
lv.step("steer", *lv.xr(9, 10), 30)
lv.mark("chapéu 1")
lv.step("steer", *lv.xr(14, 15), 40)
lv.mark("chapéu 2")
lv.step("steer", *lv.xr(19, 20), 40)
lv.mark("chapéu 3")
lv.step("steer", *lv.xr(24, 25), 40)
lv.mark("chapéu forte")
lv.step("steer", *lv.xr(24, 25), 15)
lv.step("rotate", 1)               # no alto do quique: a gravidade fica de lado
lv.mark("girou")
lv.step("wait_ground")
lv.mark("do outro lado")
lv.step("wait_revert")
lv.step("to_door")
lv.save()

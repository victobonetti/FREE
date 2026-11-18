"""Fase 3 do ato 3: Murchos (44x16). D111.

Apresenta o cogumelo murcho: o chapéu aguenta o coelho só um instante e murcha (rebrota depois).
Uma corrente de chapéus por cima dos espinhos, sem poder parar; no meio, um vão largo demais para
pular. Do último chapéu antes do vão, girar para a direita faz o coelho "cair" de lado até a
estalactite do outro lado; quando a sala volta, ele cai nos chapéus seguintes, e corre até a porta.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("murchos", "Murchos", 44, 16, theme="fungos",
           hint="Os chapéus murcham logo depois de pisados: não pare",
           notes="Ato 3, fase 3 (D111). Corrente de cogumelos murchos sobre espinhos; no vão largo, girar para a direita "
                 "faz o coelho cair de lado até a estalactite; na volta da sala, ele cai nos chapéus seguintes.",
           extra={"door_open": True})
lv.ascii([
    "############################################",
    "#..............................#...........#",
    "#..............................#...........#",
    "#..............................#...........#",
    "#..............................#...........#",
    "#..............................#...........#",
    "#..............................#...........#",
    "#..............................#...........#",
    "#..........................................#",
    "#........................................DD#",
    "#........................................DD#",
    "#.PP.....................................DD#",
    "#.PP.^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^.....DD#",
    "############################################",
    "############################################",
    "############################################",
])
for c0 in (6, 11, 16):
    lv.add("wilts", {"rect": [c0, 9, 3, 1], "regrow": 2.5})
lv.add("wilts", {"rect": [28, 10, 3, 1], "regrow": 2.5})
lv.add("wilts", {"rect": [32, 10, 4, 1], "regrow": 2.5})
cx = lv.cx
lv.step("wait", 5)
lv.step("run_to", cx(3))
lv.step("jump_in_place", 1, 22, *lv.xr(6, 8), 9)
lv.step("jump_in_place", 1, 22, *lv.xr(11, 13), 9)
lv.step("jump_in_place", 1, 22, *lv.xr(16, 18), 9)
lv.mark("último chapéu")
lv.step("rotate", 1)
lv.step("wait_ground")
lv.mark("na estalactite")
lv.step("wait_revert")
lv.step("wait_ground")
lv.mark("do outro lado")
lv.step("run_to", cx(35))
lv.step("jump_in_place", 1, 22, *lv.xr(38, 40), 13)
lv.step("to_door")
lv.save()

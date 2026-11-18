"""Fase 5 do ato 2: Casa de força (40x16, 3 baterias). Refeita no D105: pouco mais de uma tela.

Junta as quatro anteriores, uma bateria em cada trecho: pelo teto por cima do poço (Linha de
montagem); o ventilador até o degrau e o giro de lado até a divisória (Dutos); de cabeça para baixo,
a esteira do teto por cima dos espinhos (Esteiras). O Gatsby só aparece no fim, ao lado da porta: ri
e foge (ensaio da fuga).
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

gatsby = {"start": [43, 4], "hidden": True, "script": [
    {"when": [38, 1, 1, 3], "cut": True, "fly": [[33, 6]], "mood": "smug", "wait": 1.2},
    {"mood": "amused", "flee": True},
]}
lv = Level("forca", "Casa de força", 40, 16,
           hint="Tudo o que você aprendeu, uma bateria em cada trecho",
           notes="Ato 2, fase 5 (D105). Pouco mais de uma tela. Três trechos, uma bateria em cada: pelo teto por cima "
                 "do poço; o ventilador até o degrau e o giro de lado até a divisória; a esteira do teto, de cabeça "
                 "para baixo. O Gatsby só aparece no fim, ao lado da porta, e foge.",
           extra={"music": "res://music/industrial-theme.mp3", "limiter_time": 3.0, "actors": ["res://scripts/boss_gatsby.gd"], "gatsby": gatsby})
lv.ascii([
    "########################################",
    "#...........+.......LL............HH..+#",
    "#...................LL............HH...#",
    "#......................................#",
    "#......................................#",
    "#............................#.........#",
    "#............................#.........#",
    "#...........................+#.........#",
    "#...............##...........#.........#",
    "#...............##...........#.......DD#",
    "#...............##...........#.......DD#",
    "#PP.............##...........#.......DD#",
    "#PP.^^^^^^^.....##^^^^^^^^^..#^^^^...DD#",
    "##################################SS####",
    "##################################SS####",
    "########################################",
])
lv.add("fans", {"rect": [14, 4, 2, 9], "dir": 0, "accel": 1500.0, "cap": 70.0})
lv.add("conveyors", {"rect": [22, 0, 12], "dir": 1, "speed": 160.0})
cx = lv.cx
W = 40 * 8
lv.step("wait", 5)
# A: pelo teto
lv.step("rotate", -1)
lv.step("rotate", -1)
lv.step("wait_ground")
lv.step("run_to", W - cx(12))
lv.mark("bateria 1")
lv.step("wait_revert")
lv.step("wait_ground")
# B: ventilador, degrau, giro de lado
lv.step("lift", cx(14) + 4, 40)
lv.step("run_to", cx(16) + 4)
lv.step("wait_ground")
lv.mark("degrau")
lv.step("rotate", 1)
lv.step("wait_ground")
lv.mark("bateria 2")
lv.step("wait_revert")
lv.step("wait_ground")
# C: esteira do teto
lv.step("rotate", 1)
lv.step("rotate", 1)
lv.step("wait_ground")
lv.step("run_to", W - cx(38))
lv.mark("bateria 3")
lv.step("wait_revert")
lv.step("wait_ground")
lv.step("wait_until", "door_open")
lv.step("to_door")
lv.save()

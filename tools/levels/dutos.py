"""Fase 4 do ato 2: Dutos (20x19, 3 baterias). Refeita no D105: uma tela, foco no giro.

O ventilador leva o coelho ao alto da esquerda. Daí, o giro de 90° vira uma queda para o lado: girando
para a direita, ele "cai" pela sala até a parede da direita (a bateria do canto) e, quando a sala
volta, pousa na plataforma da direita. Dela, girando para a esquerda, ele cai de volta por cima dos
espinhos, pega a bateria do meio do caminho e, na volta da sala, pousa no chão da esquerda.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("dutos", "Dutos", 20, 19,
           hint="Girada de lado, a sala vira um poço: caia para a parede",
           notes="Ato 2, fase 4 (D105). Uma tela. O ventilador sobe até a bateria do alto; girar para a direita faz "
                 "o coelho cair até a parede da direita (bateria do canto) e pousar na plataforma da direita quando "
                 "a sala volta; girar para a esquerda o traz de volta por cima dos espinhos (bateria do meio).",
           extra={"music": "res://music/industrial-theme.mp3"})
lv.ascii([
    "####################",
    "#......LL..........#",
    "#......LL..........#",
    "#..................#",
    "#...+.............+#",
    "#..##..............#",
    "#...#HH............#",
    "#...#HH............#",
    "#..................#",
    "#........+.........#",
    "#..................#",
    "#.............######",
    "#.......DD.........#",
    "#.......DD.........#",
    "#..PP...DD.........#",
    "#..PP...DD^^^^^^^^^#",
    "#####SS#############",
    "#####SS#############",
    "####################",
])
lv.add("fans", {"rect": [1, 4, 2, 12], "dir": 0, "accel": 1500.0, "cap": 70.0})
cx = lv.cx
lv.step("wait", 5)
lv.step("lift", cx(1) + 4, 30)
lv.step("run_to", cx(4))
lv.mark("bateria 1")
lv.step("rotate", 1)
lv.step("wait_ground")
lv.mark("parede da direita")
lv.step("wait_revert")
lv.step("wait_ground")
lv.mark("plataforma da direita")
lv.step("rotate", -1)
lv.step("wait_ground")
lv.mark("parede da esquerda")
lv.step("wait_revert")
lv.step("run_to", cx(5))          # sai da coluna de ar
lv.step("wait_ground")
lv.mark("chão")
lv.step("wait_cutscene")
lv.step("wait_until", "door_open")
lv.step("to_door")
lv.save()

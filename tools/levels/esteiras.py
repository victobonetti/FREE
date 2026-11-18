"""Fase 2 do ato 2: Esteiras (32x11, 2 baterias). Refeita no D105: uma tela, foco no giro.

Uma divisória separa o começo do resto; a esteira está no teto. Girada 180°, a sala põe a esteira no
chão: ela leva o coelho (e depois a caixa) por cima da divisória e dos espinhos, até o batente no fim.
Quando a sala volta, quem está no fim da esteira cai do lado certo. A caixa cai da calha no começo; é
preciso girar de novo para a esteira levá-la até cima do compartimento.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("esteiras", "Esteiras", 32, 11,
           hint="De cabeça para baixo, a esteira do teto vira chão",
           notes="Ato 2, fase 2 (D105). Uma tela. Divisória no começo, espinhos no chão, esteira no teto até um "
                 "batente. Girar 180°: a esteira leva o coelho (bateria no caminho) e, depois, a caixa até cima do "
                 "compartimento; o limitador devolve a sala e quem está no fim cai do lado certo.",
           extra={"music": "res://music/industrial-theme.mp3"})
lv.ascii([
    "################################",
    "#.HH.....................##..LL#",
    "#.HH.........+...........##..LL#",
    "#..............................#",
    "#.....#........................#",
    "#.....#.....................DD.#",
    "#.PP..#.....................DD.#",
    "#.PP..#^^^^^^^^^^^..+.......DD.#",
    "#######################SS#######",
    "#######################SS#######",
    "################################",
])
lv.add("conveyors", {"rect": [1, 0, 24], "dir": 1, "speed": 120.0})
cx = lv.cx
W = 32 * 8
lv.step("wait", 5)
lv.step("rotate", -1)
lv.step("rotate", -1)
lv.step("wait_ground")
lv.mark("na esteira")
lv.step("run_to", W - cx(23))      # sala girada: x espelhado; vai até o batente
lv.mark("no batente")
lv.step("wait_revert")
lv.step("wait_ground")
lv.step("jump_in_place", -1, 22, *lv.xr(18, 21), 8)   # sai do compartimento
lv.step("run_to", cx(20))
lv.mark("bateria 2")
lv.step("wait_cutscene")
lv.step("wait_until", "box_settled")
lv.mark("caixa caiu")
lv.step("run_to", cx(27))
lv.step("rotate", 1)
lv.step("rotate", 1)
lv.step("wait_ground")
lv.mark("caixa na esteira")
for i in range(6):
    lv.step("wait", 15)
    lv.mark("t")
lv.step("wait_revert")
lv.mark("voltou")
for i in range(4):
    lv.step("wait", 20)
    lv.mark("t2")
lv.step("wait_ground")
lv.step("wait_until", "door_open")
lv.step("to_door")
lv.save()

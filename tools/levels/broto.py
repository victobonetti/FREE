"""Fase 1 do ato 3: Broto (44x16). D107; 3ª versão (D111): sem bateria, dois voos.

O broto-catapulta cresce contra a gravidade de agora, rápido, e arremessa quem está em cima; o
arremesso mantém o embalo no giro. Primeiro voo: da prateleira da esquerda, girar para a esquerda
dispara o broto; girando de volta no ar, o coelho voa de lado por cima do poço de espinhos. Do outro
lado, uma escada até a prateleira alta, com outro broto na parede da direita: girar para a direita
dispara de volta, mais alto, direto na porta (no alto, numa plataforma suspensa).
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("broto", "Broto", 44, 16, theme="fungos",
           hint="Encoste no broto e gire: ele dispara. Gire de volta no ar para voar",
           notes="Ato 3, fase 1 (D111). Sem bateria: a porta está aberta, numa plataforma suspensa. Dois brotos-catapulta: "
                 "o da esquerda leva por cima do poço de espinhos; o da direita, mais alto, de volta até a porta.",
           extra={"door_open": True})
lv.ascii([
    "############################################",
    "#..............DD..........................#",
    "#..............DD..........................#",
    "#..............DD..........................#",
    "#.............#####....................#####",
    "#..........................................#",
    "#..........................................#",
    "#...................................##.....#",
    "#####......................................#",
    "#..........................................#",
    "#......................................##..#",
    "#.PP.##....................................#",
    "#.PP....^^^^^^^^^^^^^^^^^^^^^^^^...........#",
    "############################################",
    "############################################",
    "############################################",
])
lv.add("sprouts", {"rect": [1, 6, 2, 2], "dir": 1, "len": 3, "speed": 260.0, "back": 30.0, "launch": 640.0})
lv.add("sprouts", {"rect": [41, 2, 2, 2], "dir": 3, "len": 3, "speed": 260.0, "back": 30.0, "launch": 640.0})
cx = lv.cx
lv.step("wait", 5)
lv.step("jump_in_place", 1, 22, *lv.xr(5, 6), 11)
lv.step("jump_in_place", -1, 22, *lv.xr(3, 4), 8)
lv.mark("prateleira 1")
lv.step("rotate", -1)
lv.step("wait", 22)
lv.step("rotate", 1)
lv.step("air_to", *lv.xr(33, 36))
lv.mark("pousou")
lv.step("run_to", cx(37) + 2)
lv.step("jump_in_place", 1, 22, *lv.xr(39, 40), 10)
lv.step("jump_in_place", -1, 22, *lv.xr(36, 37), 7)
lv.step("jump_in_place", 1, 22, *lv.xr(39, 40), 4)
lv.mark("prateleira 2")
lv.step("rotate", 1)
lv.step("wait", 60)          # o arremesso atravessa a porta, lá no alto
lv.mark("porta")
lv.step("to_door")
lv.save()

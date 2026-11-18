"""Fase 1 do ato 3: Broto (40x14, 1 bateria). D107, 2ª versão: o broto-catapulta.

O broto cresce contra a gravidade de agora; o da catapulta cresce rápido e, chegando ao alto,
arremessa quem está em cima. Ele nasce na parede da esquerda, numa prateleira alta, recolhido.
Encostado nele, girar para a esquerda põe a parede no chão: o broto dispara e joga o coelho para o
"alto". Girando de volta ainda no ar, o arremesso vira um voo de lado, por cima do poço de espinhos,
pegando a bateria no caminho.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("broto", "Broto", 40, 14, theme="fungos",
           hint="Encoste no broto e gire: ele dispara. Gire de volta no ar para voar",
           notes="Ato 3, fase 1 (D107, 2ª versão). O broto-catapulta na parede da esquerda, numa prateleira alta: "
                 "girando, a parede vira chão, o broto dispara e arremessa o coelho; girando de volta no ar, o "
                 "arremesso vira um voo de lado por cima do poço de espinhos, com a bateria no meio do voo.")
lv.ascii([
    "########################################",
    "#.................................HH.LL#",
    "#.................................HH.LL#",
    "#......................................#",
    "#.............................+........#",
    "#####..................................#",
    "#......................................#",
    "#....................................DD#",
    "#....##..............................DD#",
    "#.PP.................................DD#",
    "#.PP....^^^^^^^^^^^^^^^^^^^^^^^^.....DD#",
    "##################################SS####",
    "##################################SS####",
    "########################################",
])
lv.add("sprouts", {"rect": [1, 3, 2, 2], "dir": 1, "len": 3, "speed": 260.0, "back": 30.0, "launch": 640.0})
cx = lv.cx
lv.step("wait", 5)
lv.step("jump_in_place", 1, 22, *lv.xr(5, 6), 8)
lv.step("jump_in_place", -1, 22, *lv.xr(3, 4), 5)
lv.mark("prateleira")
lv.step("rotate", -1)
lv.mark("disparou")
lv.step("wait", 22)
lv.step("rotate", 1)
lv.mark("voando")
lv.step("air_to", *lv.xr(35, 38))
lv.mark("pousou")
lv.step("wait_until", "door_open")
lv.step("to_door")
lv.save()

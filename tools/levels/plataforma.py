"""Fim da fábrica: a plataforma do elevador (26x10). D107.

Uma salinha de embarque, sem giro: o coelho anda até o elevador, aberto e aceso, e entra. A porta da
sala é a do elevador; o ator scripts/elevator.gd (modo "hall") desenha a moldura, as portas abertas,
a cabine lá dentro, o indicador e o painel de chamada.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("plataforma", "Plataforma", 26, 10, rotate=False, limiter=False,
           notes="Fim da fábrica (D107): a plataforma de embarque. O elevador está aberto e aceso; entrar nele leva à cabine.",
           extra={"actors": ["res://scripts/elevator.gd"], "elevator": "hall", "music": "res://music/industrial-theme.mp3"})
lv.ascii([
    "##########################",
    "#........................#",
    "#........................#",
    "#........................#",
    "#...................DD...#",
    "#...................DD...#",
    "#.PP................DD...#",
    "#.PP................DD...#",
    "##########################",
    "##########################",
])
lv.step("wait", 5)
lv.step("to_door")
lv.save()

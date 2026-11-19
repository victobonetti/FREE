"""Boss do ato 3: Senzi, o caramujo (36x22). D112.

A arena é uma sala do fungário, vazia: um caramujo um pouco maior passeia no chão. Chegando perto, ele
se revela (o caramujo marombado). Ator scripts/boss_snail.gd. A porta destrava quando ele perde os 3
corações. Sem limitador: girar é a arma (com ele cansado).
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("senzi", "Senzi", 36, 22, theme="fungos", limiter=False,
           hint="Fuja dele. Cansado, ele se solta: gire para jogá-lo no cogumelo vermelho",
           notes="Boss do ato 3 (D112): Senzi, o caramujo. Fúria grudado nas superfícies, muros de cogumelo, cansaço, "
                 "cogumelos vermelhos e espinhos. Provado pelo teste-bot test_senzi_bot.",
           extra={"actors": ["res://scripts/boss_snail.gd"]})
lv.ascii([
    "####################################",
    "#..................................#",
    "#..................................#",
    "#..................................#",
    "#..................................#",
    "#..................................#",
    "#..................................#",
    "#..................................#",
    "#..................................#",
    "#..................................#",
    "#..................................#",
    "#..................................#",
    "#..................................#",
    "#..................................#",
    "#..................................#",
    "#...............................DD.#",
    "#...............................DD.#",
    "#.PP............................DD.#",
    "#.PP............................DD.#",
    "####################################",
    "####################################",
    "####################################",
])
lv.step("wait", 5)
lv.save()

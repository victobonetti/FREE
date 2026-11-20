"""Boss do ato 3: Senzi, o caramujo (36x22). D112.

A arena é uma sala do fungário, vazia: um caramujo um pouco maior passeia no chão. Chegando perto, ele
se revela. Ator scripts/boss_snail.gd. A porta destrava quando ele perde os 3 corações (no ringue).
Sem dica na tela (Victor: "remova o texto que está na batalha do Senzi").
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("senzi", "Senzi", 36, 22, theme="fungos", limiter=False,
           notes="Boss do ato 3 (D112–D117): Senzi, o caramujo. Perseguição grudado nas superfícies, cogumelos em "
                 "padrões, a seringa, o coelhão e o ringue. Provado pelo teste-bot test_senzi_bot.",
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

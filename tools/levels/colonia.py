"""Fase 5 do ato 3: Colônia (56x18). D111.

Tudo junto, sem pausa: os cogumelos murchos por cima dos espinhos; o chapéu forte diante do muro,
girando no alto do quique para cair de lado pela fresta até o pilar; de volta ao chão, a chuva de
esporos; a escada até a prateleira do broto-catapulta, encostado no pilar; e o voo por cima do
último poço até a porta. Perto da porta, a terra treme e algo enorme passa ao fundo (o chefe do ato
se anunciando, ator scripts/omen.gd).
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("colonia", "Colônia", 56, 18, theme="fungos",
           hint="Tudo o que os cogumelos ensinaram, sem parar",
           notes="Ato 3, fase 5 (D111). Murchos, o quique com giro pela fresta, a chuva de esporos, o broto-catapulta e o "
                 "voo até a porta. Perto da porta, o tremor e a sombra do chefe ao fundo.",
           extra={"door_open": True, "actors": ["res://scripts/omen.gd"], "omen": [44, 1, 11, 16]})
lv.ascii([
    "########################################################",
    "#..............................#.......................#",
    "#..............................#.......................#",
    "#................##.##..##.....#.......................#",
    "#................##............#.......................#",
    "#................##............#.......................#",
    "#................##............#.......................#",
    "#................##............#.......................#",
    "#................##............#.......................#",
    "#................##............#####...................#",
    "#................##....................................#",
    "#................##.................................DD.#",
    "#................##.................##..............DD.#",
    "#PP..............##.................................DD.#",
    "#PP.^^^^^^^^.....##...................^^^^^^^^^^^...DD.#",
    "########################################################",
    "########################################################",
    "########################################################",
])
for c0 in (5, 9):
    lv.add("wilts", {"rect": [c0, 12, 2, 1], "regrow": 2.5})
lv.add("bouncers", {"rect": [14, 14, 2, 1], "power": 440.0, "dir": 0})
lv.add("puffs", {"rect": [20, 4, 2, 2], "period": 3.0, "phase": 0.0})
lv.add("puffs", {"rect": [24, 4, 2, 2], "period": 3.0, "phase": 1.5})
lv.add("sprouts", {"rect": [32, 7, 2, 2], "dir": 1, "len": 3, "speed": 260.0, "back": 30.0, "launch": 640.0})
cx = lv.cx
lv.step("wait", 5)
lv.step("jump_in_place", 1, 22, *lv.xr(5, 6), 12)
lv.step("jump_in_place", 1, 22, *lv.xr(9, 10), 12)
lv.step("jump_in_place", 1, 22, *lv.xr(12, 13), 15)
lv.mark("passou os murchos")
lv.step("run_to", cx(14) + 4)
lv.step("steer", *lv.xr(14, 15), 4)
lv.step("apex", *lv.xr(14, 15))
lv.step("rotate", 1)
lv.step("wait_ground")
lv.mark("no pilar")
lv.step("rotate", -1)
lv.step("wait_ground")
lv.mark("chão dos esporos")
lv.step("wait_spores", 19 * 8, 31 * 8, 0)
lv.step("run_to", cx(34))
lv.step("jump_in_place", 1, 22, *lv.xr(36, 37), 12)
lv.step("jump_in_place", -1, 22, *lv.xr(34, 35), 9)
lv.mark("prateleira do broto")
lv.step("rotate", -1)
lv.step("wait", 22)
lv.step("rotate", 1)
lv.step("steer", *lv.xr(51, 53), 60)
lv.mark("voou")
lv.step("to_door")
lv.save()

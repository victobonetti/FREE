"""Fase 5 do ato 2: Casa de força (130x50, 3 baterias).

A mistura de tudo, subindo em ziguezague: ponte de chapas soltas sobre espinhos, duas esteiras, uma coluna
de ar, vapor, uma mola e um elevador, com uma bateria em cada andar do meio e a terceira no alto. No
corredor final o Gatsby aparece rapidinho, puxa uma alavanca e liga a parede de espinhos (o ensaio da
fuga). A caixa viaja numa esteira até o compartimento ao lado da porta.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

gatsby = {"start": [76, 6], "script": [
    {"when": [68, 4, 4, 8], "mood": "smug", "cut": True, "lever": True, "crusher": 0, "wait": 0.3, "flee": True},
]}
lv = Level("forca", "Casa de força", 130, 50, rotate=False,
           hint="Pegue as três baterias",
           notes="Ato 2, fase 5 (D76). Hall em ziguezague (chapas soltas, esteiras, coluna de ar, vapor, mola, elevador) até a bateria 3 no "
                 "alto; corredor final onde o Gatsby aparece rápido e liga a parede de espinhos (ensaio da fuga). A caixa viaja numa esteira.",
           extra={"actors": ["res://scripts/boss_gatsby.gd"], "gatsby": gatsby,
                  "crushers": [{"rect": [58, 4, 70, 8], "dir": 1, "speed": 36.0, "delay": -1, "face": "sad"}]})
F = lv.floor_row  # 47
xr = lv.xr
cx = lv.cx

lv.block(2, F - 2, "P")
lv.step("wait", 5)
lv.spikes(12, 56, F - 1)

# --- andar 0: a ponte de chapas soltas sobre os espinhos, e a primeira plataforma fixa
for c in (12, 15, 18, 21):
    lv.add("crumbles", [c, 44, 3, 1])
lv.step("run_to", cx(9))
lv.step("jump_in_place", 1, 22, *xr(12, 14), 44)
lv.hop(1, 26, 31, 44)
lv.mark("A")

# --- andar 1: duas esteiras (contra, a favor)
lv.ledge(34, 43, 41)
lv.add("conveyors", {"rect": [34, 41, 10, 1], "dir": 3, "speed": 36.0})
lv.hop(1, 34, 43, 41, ledge=False)
lv.ledge(46, 55, 38)
lv.add("conveyors", {"rect": [46, 38, 10, 1], "dir": 1, "speed": 48.0})
lv.hop(1, 46, 55, 38, ledge=False)
lv.mark("B2")

# --- andar 2: a coluna de ar até uma plataforma com dois jatos de vapor e a bateria 1
lv.add("fans", {"rect": [53, 23, 3, 15], "dir": 0, "accel": 1500.0, "cap": 70.0})
lv.step("lift", cx(54), 188)
lv.ledge(36, 52, 25)
lv.step("walk_off", -1, *xr(48, 52), 25)
v0 = lv.add("vents", {"rect": [46, 19, 2, 6], "dir": 0, "period": 3.0, "on": 1.2, "phase": 0.0})
v1 = lv.add("vents", {"rect": [42, 19, 2, 6], "dir": 0, "period": 3.0, "on": 1.2, "phase": 1.1})
lv.step("run_to", 398)                           # antes do primeiro jato
lv.step("wait_vent", v0, 50)
lv.step("run_to", 360)                           # entre os dois jatos (a fresta tem 2 tiles)
lv.step("wait_vent", v1, 50)
lv.step("run_to", 322)
lv.put(38, 24, "+")
lv.step("run_to", cx(38))
lv.mark("bateria 1")

# --- a mola leva ao andar 3, com a bateria 2
lv.add("springs", {"rect": [36, 24, 2, 1], "power": 320.0})
lv.ledge(30, 35, 19)
lv.drop(-1, 30, 35, 19)
lv.put(32, 18, "+")
lv.step("run_to", cx(32))
lv.mark("bateria 2")

# --- o elevador leva ao alto, onde está a passarela e a bateria 3
e2 = lv.add("movers", {"ch": 2, "off": [26, 19, 3, 1], "on": [26, 12], "speed": 50.0, "cycle": 3.2})
lv.step("wait_mover", e2, "off", 90)
lv.hop(-1, 26, 28, 19, hold=12, ledge=False)
lv.step("wait_mover", e2, "on", 80)
lv.solid(30, 12, 57, 12)                         # a passarela
lv.solid(58, 12, 128, 14)                        # o chão do corredor (3 de espessura)
lv.solid(30, 1, 128, 3)                          # o teto do corredor e da passarela
lv.put(34, 11, "+")
lv.step("run_to", cx(34))
lv.mark("bateria 3")

# --- a alavanca (hall), a calha (no corredor, sob o teto), a esteira da caixa e o compartimento
lv.block(2, 28, "L")
lv.block(66, 4, "H")
lv.add("conveyors", {"rect": [62, 12, 57, 1], "dir": 1, "speed": 36.0})
lv.block(119, 12, "S")
lv.put(124, 9, "DD")
lv.put(124, 10, "DD")
lv.put(124, 11, "DD")
lv.step("wait_cutscene")
lv.step("run_to", cx(70))                        # entra no corredor: o Gatsby aparece e liga a parede (atrás dele)
lv.step("wait", 160)
lv.step("wait_until", "door_open", 2400)
lv.step("to_door")
lv.save()

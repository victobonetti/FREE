"""Fase 3 do ato 2: Prensas e vapor (28x13, 2 baterias). Refeita no D105: uma tela, foco no giro.

O botão está no teto. Empurra-se a caixa até o rebaixo do chão, bem embaixo dele, e gira-se 180°: o
rebaixo segura a caixa no meio do giro e ela cai em cima do botão, que abre a comporta da bateria (e
fica aberta). Depois, a prensa (no ritmo) guarda a segunda bateria, e um jato de vapor, a passagem.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("prensas", "Prensas e vapor", 28, 13,
           hint="O botão está no teto: ponha a caixa embaixo dele e vire a sala",
           notes="Ato 2, fase 3 (D105). Uma tela. Caixa no rebaixo embaixo do botão do teto; girar 180° derruba a "
                 "caixa no botão, que abre a comporta da bateria. A prensa no ritmo guarda a outra bateria e um "
                 "jato de vapor, a passagem.",
           extra={"music": "res://music/industrial-theme.mp3"})
lv.ascii([
    "############################",
    "#...+..................HH..#",
    "#......................HH..#",
    "######.....................#",
    "#..........................#",
    "#..........................#",
    "#.LL.....................DD#",
    "#.LL.....................DD#",
    "#......PPBB..............DD#",
    "#.....#PPBB...+..........DD#",
    "###########..##########SS###",
    "#######################SS###",
    "############################",
])
lv.add("plates", {"rect": [11, 1, 2], "ch": 0})
lv.add("movers", {"ch": 0, "off": [6, 1, 1, 2], "on": [6, 3], "speed": 90.0})
lv.add("movers", {"ch": 1, "off": [17, 1, 2, 2], "on": [17, 7], "speed": 150.0, "spikes": 2, "cycle": 2.0})
lv.add("vents", {"rect": [21, 4, 2, 6], "dir": 0, "period": 2.5, "on": 0.8, "phase": 0.0})
cx = lv.cx
W = 28 * 8
lv.step("wait", 5)
lv.step("push_box", 88)
lv.mark("caixa no rebaixo")
lv.step("rotate", -1)
lv.step("rotate", -1)
lv.step("wait_ground")
lv.mark("girada")
lv.step("run_to", W - cx(4))       # sala girada: x espelhado; entra no nicho
lv.mark("bateria do nicho")
lv.step("run_to", W - cx(8))       # e sai antes de a sala voltar
lv.step("wait_revert")
lv.step("wait_ground")
lv.mark("voltou")
lv.step("run_to", cx(9) - 2)
lv.jump_from(1, 14, 15, 10, ledge=False)   # por cima da caixa, que voltou para o rebaixo
lv.step("run_to", cx(15))
lv.mark("bateria 2")
lv.step("wait_cutscene")
lv.step("wait_mover", 1, "off", 70)
lv.step("run_to", cx(19) + 4)
lv.step("wait_vent", 0, 50)
lv.step("wait_until", "door_open")
lv.step("to_door")
lv.save()

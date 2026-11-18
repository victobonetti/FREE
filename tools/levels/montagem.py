"""Fase 1 do ato 2: Linha de montagem (28x11, 1 bateria). Refeita no D105: uma tela, foco no giro.

Ensina o giro do ato 2: o teto vira chão por pouco tempo. Um poço de espinhos corta o chão; a
bateria fica no teto, depois do poço. Gira-se 180° na beira do poço, anda-se pelo teto por cima dele
e pega-se a bateria antes de o limitador trazer a sala de volta: aí o coelho cai do outro lado. A
calha solta a caixa em cima do compartimento, ao lado da porta.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("montagem", "Linha de montagem", 28, 11,
           hint="O teto vira chão por pouco tempo: atravesse por cima antes de a sala voltar",
           notes="Ato 2, fase 1 (D105). Uma tela. Poço de espinhos no chão; a bateria no teto, depois dele. "
                 "Girar 180°, andar pelo teto, pegar a bateria; o limitador devolve a sala e o coelho cai do "
                 "outro lado. A caixa cai da calha no compartimento.",
           extra={"music": "res://music/industrial-theme.mp3", "limiter_time": 3.0})
lv.ascii([
    "############################",
    "#..LL................HH....#",
    "#..LL.........+......HH....#",
    "#..........................#",
    "#.......................DD.#",
    "#.......................DD.#",
    "#.PP....................DD.#",
    "#.PP^^^^^^^^............DD.#",
    "#####################SS#####",
    "#####################SS#####",
    "############################",
])
cx = lv.cx
W = 28 * 8
lv.step("wait", 5)
lv.step("run_to", cx(2))
lv.mark("beira do poço")
lv.step("rotate", -1)
lv.step("rotate", -1)
lv.step("wait_ground")
lv.mark("no teto")
lv.step("run_to", W - cx(14))     # na sala girada, o x é espelhado
lv.mark("bateria")
lv.step("wait_revert")
lv.step("wait_ground")
lv.step("wait_cutscene")
lv.step("wait_until", "door_open")
lv.step("to_door")
lv.save()

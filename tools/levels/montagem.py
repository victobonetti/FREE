"""Fase 1 do ato 2: Linha de montagem (80x40, 1 bateria). Com giro (limitador de 2,5 s).

Ensina o ciclo inteiro (bateria, alavanca sozinha, caixa da calha, porta) em cima de plataforming que já
cobra: plataformas de 4 tiles, uma plataforma em ciclo sobre espinhos, uma ponte de chapas soltas, um
elevador, um estampador na plataforma de pouso e uma subida de saltos de 3 tiles com outro estampador.
O teto tem espinhos: girar de qualquer jeito é arriscado.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("montagem", "Linha de montagem", 80, 40,
           hint="Pegue a bateria: ela puxa a alavanca e solta a caixa",
           notes="Ato 2, fase 1 (D76, D78). Plataformas estreitas, plataforma em ciclo sobre espinhos, ponte de chapas soltas, "
                 "elevador, dois estampadores e a subida de saltos de 3 tiles até a bateria (1). Giro liberado, com limitador; "
                 "o teto tem espinhos. A caixa cai da calha direto no compartimento ao lado da porta.")
F = lv.floor_row  # 37
xr = lv.xr
cx = lv.cx

lv.spikes(21, 74, 1, "v")                      # teto de espinhos (menos acima da alavanca e da calha)
lv.put(12, 1, "..")
lv.put(75, 1, "..")
lv.block(2, F - 2, "P")
lv.step("wait", 5)

# --- degraus estreitos
lv.jump_from(1, 7, 10, 34)
lv.hop(1, 14, 17, 32)
lv.hop(1, 21, 24, 30)
lv.mark("c")

# --- a plataforma em ciclo sobre espinhos
lv.spikes(25, 52, F - 1)
m0 = lv.add("movers", {"ch": 3, "off": [27, 30, 3, 1], "on": [35, 30], "speed": 100.0, "cycle": 2.0})
lv.step("wait_mover", m0, "off", 55)
lv.hop(1, 27, 29, 30, ledge=False)
lv.step("wait_mover", m0, "on", 45)

# --- a ponte de chapas soltas (a plataforma de cima do ciclo chega ao primeiro pedaço)
for c in (40, 43):
    lv.add("crumbles", [c, 30, 3, 1])
lv.hop(1, 40, 42, 30, ledge=False)
lv.hop(1, 46, 48, 30)                           # a plataforma fixa depois da ponte: dá para esperar
lv.mark("ponte")

# --- o elevador
e0 = lv.add("movers", {"ch": 2, "off": [51, 30, 3, 1], "on": [51, 22], "speed": 80.0, "cycle": 3.0})
lv.step("wait_mover", e0, "off", 50)
lv.hop(1, 51, 53, 30, ledge=False)
lv.step("wait_mover", e0, "on", 70)
lv.step("wait", 50)
lv.ledge(56, 60, 22)
lv.hop(1, 56, 60, 22, ledge=False)
lv.mark("e")

# --- a subida em zigue-zague (saltos de 3), com um estampador em cima do patamar do meio
lv.hop(1, 63, 66, 20)
s1 = lv.add("movers", {"ch": 1, "off": [72, 12, 2, 2], "on": [72, 14], "speed": 160.0, "spikes": 2, "cycle": 1.8, "phase": 0.0})
lv.hop(1, 69, 72, 17)
lv.step("wait_mover", s1, "off", 50)
lv.hop(-1, 62, 66, 14)
lv.hop(1, 69, 72, 11)
lv.hop(-1, 62, 66, 8)
lv.mark("j")

# --- a bateria, a alavanca (longe, no alto à esquerda) e a calha (acima do compartimento)
lv.put(64, 7, "+")
lv.step("run_to", cx(64))
lv.mark("bateria")
lv.block(12, 1, "L")
lv.block(75, 1, "H")
lv.step("wait_cutscene")

# --- a volta: cai pela esquerda até a plataforma do elevador e daí ao chão; vai à porta
lv.drop(-1, 56, 60, 22)
lv.drop(-1, 54, 55, F)
lv.block(75, F, "S")
lv.put(77, F - 3, "DD")
lv.put(77, F - 2, "DD")
lv.put(77, F - 1, "DD")
lv.step("wait_until", "door_open", 1500)
lv.step("to_door")
lv.save()

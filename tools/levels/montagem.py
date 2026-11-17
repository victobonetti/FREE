"""Fase 1 do ato 2: Linha de montagem (80x40, 1 bateria).

Ensina o ciclo inteiro: plataforming até uma bateria alta, a alavanca que se puxa sozinha, a caixa
que cai da calha no compartimento e a porta. Peças novas: bateria, alavanca, calha, plataforma
em ciclo (horizontal) e elevador (vertical).
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("montagem", "Linha de montagem", 80, 40, rotate=False,
           hint="Pegue a bateria: ela puxa a alavanca e solta a caixa",
           notes="Ato 2, fase 1 (D76). Sobe em zigue-zague até a bateria (1), com uma plataforma em ciclo sobre espinhos, "
                 "um elevador e cinco saltos de 3 tiles. A caixa cai da calha direto no compartimento ao lado da porta.")
F = lv.floor_row  # 37
xr = lv.xr

# --- começo
lv.block(2, F - 2, "P")
lv.step("run_to", 40)
# a (7..11, 34): sobe 3 do chão
lv.jump_from(1, 7, 11, 34)
lv.mark("a")
# b, c: dois degraus de 2
lv.hop(1, 15, 19, 32)
lv.hop(1, 23, 27, 30)
lv.mark("c")

# --- plataforma em ciclo sobre espinhos (cols 28..41)
lv.spikes(28, 41, F - 1)
m0 = lv.add("movers", {"ch": 3, "off": [29, 30, 3, 1], "on": [37, 30], "speed": 100.0, "cycle": 2.4})
lv.step("wait_mover", m0, "off", 60)
lv.hop(1, 29, 31, 30, ledge=False)
lv.step("wait_mover", m0, "on", 50)
lv.hop(1, 42, 47, 30)
lv.mark("d")

# --- elevador (cols 50..52, de 30 a 22)
e0 = lv.add("movers", {"ch": 2, "off": [50, 30, 3, 1], "on": [50, 22], "speed": 60.0, "cycle": 2.4, "phase": 0.0})
lv.step("wait_mover", e0, "off", 50)
lv.hop(1, 50, 52, 30, ledge=False)
lv.step("wait_mover", e0, "on", 40)
lv.hop(1, 55, 60, 22)
lv.mark("e")

# --- a subida em zigue-zague até a bateria (saltos de 3)
lv.hop(1, 63, 67, 20)
lv.hop(1, 70, 74, 17)
lv.hop(-1, 63, 67, 14)
lv.hop(1, 70, 74, 11)
lv.hop(-1, 62, 67, 8)
lv.mark("j")

# --- a bateria, a alavanca (longe, no alto à esquerda) e a calha (acima do compartimento)
lv.put(64, 7, "+")
lv.step("run_to", lv.cx(64))
lv.mark("bateria")
lv.block(12, 1, "L")
lv.block(75, 1, "H")
lv.step("wait_cutscene")

# --- a volta: cai pela esquerda até o chão e vai à porta
lv.drop(-1, 55, 60, 22)
lv.drop(-1, 53, 54, F)
lv.block(75, F, "S")
lv.put(77, F - 3, "DD")
lv.put(77, F - 2, "DD")
lv.put(77, F - 1, "DD")
lv.step("wait_until", "door_open", 1500)
lv.step("to_door")
lv.save()

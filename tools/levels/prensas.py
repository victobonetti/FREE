"""Fase 3 do ato 2: Prensas e vapor (110x50, 2 baterias).

Três prensas em ritmo num corredor baixo; um botão de pressão chama o elevador que sobe o poço;
no alto, um corredor com quatro jatos de vapor defasados. A caixa cai da calha, lá do alto, direto
no compartimento. Peças novas: jato de vapor e botão de pressão.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("prensas", "Prensas e vapor", 110, 50, rotate=False,
           hint="Pise no botão para chamar o elevador",
           notes="Ato 2, fase 3 (D76). Corredor com três prensas em ritmo; botão de pressão (modo 'once') chama o elevador; "
                 "corredor alto com quatro jatos de vapor defasados; a caixa cai de uma calha no alto até o compartimento.")
F = lv.floor_row  # 47
xr = lv.xr
cx = lv.cx

lv.block(2, F - 2, "P")
lv.step("wait", 5)

# --- zona A: o corredor das prensas (teto nas linhas 36..38, interior 39..46)
lv.solid(5, 36, 36, 38)
lv.solid(37, 1, 37, 38)                      # parede esquerda do poço (a boca do corredor fica aberta)
stampers = []
for c, ph in ((10, 0.0), (18, 0.6), (26, 1.2)):
    stampers.append((c, lv.add("movers", {"ch": 0, "off": [c, 39, 2, 2], "on": [c, 43], "speed": 140.0, "spikes": 2, "cycle": 1.8, "phase": ph})))
for c, i in stampers:
    lv.step("run_to", c * 8 - 14)
    lv.step("wait_mover", i, "off", 55)
    lv.step("run_to", (c + 2) * 8 + 16)
lv.mark("passou as prensas")

# --- zona B: o poço (colunas 38..58), o botão e o elevador
lv.solid(59, 1, 59, 7)                       # parede direita do poço, acima do corredor alto
lv.solid(59, 16, 59, F - 1)                  # e abaixo dele
lv.add("plates", {"rect": [41, 46, 2, 1], "ch": 5, "mode": "once"})
lv.step("run_to", cx(41) + 4)
lv.add("movers", {"ch": 5, "off": [44, 46, 4, 1], "on": [44, 16], "speed": 50.0, "delay": 1.0})
EL = len(lv.objs["movers"]) - 1
lv.step("jump_in_place", 1, 22, *xr(44, 47), 46)
lv.step("wait_mover", EL, "on", 0)
lv.mark("no alto do elevador")
# o topo: plataforma e a primeira bateria
lv.ledge(48, 58, 16)
lv.put(53, 15, "+")
lv.step("run_to", cx(53))
lv.mark("bateria 1")

# --- zona C: o corredor alto com quatro jatos de vapor (linhas 10..15), do poço até a coluna 99
lv.solid(59, 8, 99, 9)                       # teto do corredor
lv.solid(59, 16, 99, 16)                     # chão do corredor
vents = []
for c, ph in ((66, 0.0), (74, 0.7), (82, 1.4), (90, 2.1)):
    vents.append((c, lv.add("vents", {"rect": [c, 10, 2, 6], "dir": 0, "period": 3.0, "on": 1.2, "phase": ph})))
for c, i in vents:
    lv.step("run_to", c * 8 - 14)
    lv.step("wait_vent", i, 50)
    lv.step("run_to", (c + 2) * 8 + 14)
lv.mark("passou os jatos")
lv.put(97, 15, "+")
lv.step("run_to", cx(97))
lv.mark("bateria 2")

# --- a alavanca (alto do poço), a calha e o compartimento (à direita), a porta
lv.block(52, 1, "L")
lv.block(100, 1, "H")
lv.block(100, F, "S")
lv.put(106, F - 3, "DD")
lv.put(106, F - 2, "DD")
lv.put(106, F - 1, "DD")
lv.step("wait_cutscene")
lv.step("wait_until", "door_open", 1800)
lv.drop(1, 102, 105, F)
lv.step("to_door")
lv.save()

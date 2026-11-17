"""Passagem: o corredor entre a despensa do Jeffrey (fim do ato 1) e a fábrica do Gatsby (ato 2).

Um corredor longo (150x26) em que a terra vira metal aos poucos (tema "transicao": as chapas de
aço aparecem soltas na terra e tomam conta; no fundo, as camadas de terra somem e os canos da
fábrica aparecem). Plataforming leve, de respiro depois do boss, que já apresenta as peças do ato 2:
fossos de espinhos na terra, uma ponte de chapas soltas no meio, e no fim uma esteira contra e dois
estampadores. Sem caixa: a porta já está aberta. Giro liberado, sem limitador (ainda não há
amortecedor: a fábrica começa depois da porta).
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("passagem", "Passagem", 150, 26, theme="transicao", limiter=False,
           hint="A terra acaba aqui. Siga em frente",
           notes="Transição do ato 1 para o ato 2 (D83): corredor em que a terra vira metal. Fossos de espinhos, "
                 "ponte de chapas soltas, esteira contra e dois estampadores. Porta aberta, sem caixa.",
           extra={"door_open": True})
F = lv.floor_row  # 23
xr = lv.xr
cx = lv.cx

lv.block(2, F - 2, "P")
lv.step("wait", 5)

# --- terra: dois fossos de espinhos e um degrau de 3
lv.clear(14, F, 16, F + 1)
lv.spikes(14, 16, F + 1)
lv.hop(1, 17, 24, F, ledge=False)
lv.clear(28, F, 31, F + 1)
lv.spikes(28, 31, F + 1)
lv.hop(1, 32, 38, F, ledge=False)
lv.solid(42, F - 3, 47, F - 1)
lv.step("run_to", cx(39))
lv.step("jump_in_place", 1, 22, *xr(42, 47), F - 3)
lv.mark("terra")

# --- a mistura: ponte de chapas soltas sobre espinhos (vãos de 1 tile: dá para correr direto)
lv.spikes(48, 60, F - 1)
for c in (49, 53, 57):
    lv.add("crumbles", [c, F - 3, 3, 1])
lv.solid(61, F - 3, 66, F - 1)
lv.step("run_to", cx(64))
lv.mark("ponte")
lv.drop(1, 68, 74, F)

# --- metal: esteira contra, um fosso e dois estampadores
lv.add("conveyors", {"rect": [76, F, 17, 1], "dir": 3, "speed": 30.0})
lv.step("run_to", cx(95))
lv.clear(97, F, 100, F + 1)
lv.spikes(97, 100, F + 1)
lv.hop(1, 101, 107, F, ledge=False)
m0 = lv.add("movers", {"ch": 1, "off": [110, F - 8, 2, 2], "on": [110, F - 2], "speed": 140.0, "spikes": 2, "cycle": 2.6})
m1 = lv.add("movers", {"ch": 1, "off": [120, F - 8, 2, 2], "on": [120, F - 2], "speed": 140.0, "spikes": 2, "cycle": 2.6, "phase": 1.3})
lv.step("run_to", cx(107))
lv.step("wait_mover", m0, "off", 60)
lv.step("run_to", cx(116))
lv.step("wait_mover", m1, "off", 60)
lv.step("run_to", cx(126))
lv.mark("estampadores")

for r in (F - 3, F - 2, F - 1):
    lv.put(144, r, "DD")
lv.step("to_door")
lv.save()

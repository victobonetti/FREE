"""Fase 4 do ato 2: Dutos (80x70, 3 baterias).

Uma subida vertical de 57 tiles em três ramais, sobre um piso de espinhos: molas, uma coluna de ar,
um elevador em ciclo e uma segunda coluna de ar levam ao alto, onde ficam a terceira bateria, o
compartimento e a porta. Peças novas: mola e ventilador.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("dutos", "Dutos", 80, 70,
           hint="As molas lançam para cima; a coluna de ar levanta quem entra nela",
           notes="Ato 2, fase 4 (D76). Subida vertical em três ramais: mola e coluna de ar na esquerda, mola e elevador no meio, "
                 "coluna de ar na direita. Uma bateria por ramal; piso de espinhos. A caixa cai da calha no compartimento do alto.")
F = lv.floor_row  # 67
xr = lv.xr
cx = lv.cx

lv.block(3, F - 2, "P")
lv.step("wait", 5)
lv.spikes(24, 78, F - 1)                       # o piso de espinhos: quem cai dos ramais do meio e da direita morre

# --- ramal 1: mola e coluna de ar
lv.add("springs", {"rect": [8, 66, 2, 1], "power": 300.0})
lv.ledge(10, 20, 62)
lv.drop(1, 10, 16, 62)                          # corre, a mola o lança
lv.step("mark", "L1")
lv.add("fans", {"rect": [18, 44, 3, 18], "dir": 0, "accel": 1500.0, "cap": 70.0})
lv.step("lift", cx(19), 352)
lv.ledge(22, 26, 46)
lv.drop(1, 22, 26, 46)
lv.put(24, 45, "+")
lv.step("run_to", cx(24))
lv.mark("bateria 1")

# --- ramal 2: salto, mola, elevador
lv.ledge(29, 34, 43)
lv.hop(1, 29, 31, 43, ledge=False)              # pousa na parte de trás da plataforma, longe da mola
lv.add("springs", {"rect": [33, 42, 2, 1], "power": 320.0})
lv.ledge(35, 41, 38)
lv.drop(1, 35, 41, 38)
lv.mark("M2")
e0 = lv.add("movers", {"ch": 2, "off": [44, 38, 3, 1], "on": [44, 28], "speed": 60.0, "cycle": 2.6})
lv.step("wait_mover", e0, "off", 50)
lv.hop(1, 44, 46, 38, ledge=False)
lv.step("wait_mover", e0, "on", 40)
lv.hop(1, 49, 53, 28)
lv.put(51, 27, "+")
lv.step("run_to", cx(51))
lv.mark("bateria 2")

# --- ramal 3: salto e a segunda coluna de ar
lv.hop(1, 56, 61, 25)
lv.add("fans", {"rect": [59, 9, 3, 16], "dir": 0, "accel": 1500.0, "cap": 70.0})
lv.step("lift", cx(60), 80)
lv.solid(63, 11, 75, 13)                        # a plataforma do alto: bateria 3, compartimento e porta
lv.step("walk_off", 1, *xr(63, 68), 11)
lv.put(65, 10, "+")
lv.step("run_to", cx(65))
lv.mark("bateria 3")

# --- a alavanca (esquerda), a calha (acima do compartimento), o compartimento e a porta
lv.block(2, 30, "L")
lv.block(70, 1, "H")
lv.block(70, 11, "S")
lv.put(74, 8, "DD")
lv.put(74, 9, "DD")
lv.put(74, 10, "DD")
lv.step("wait_cutscene")
lv.step("wait_until", "door_open", 1500)
lv.step("to_door")
lv.ceiling()   # teto de espinhos: girar sem pensar é arriscado
lv.save()

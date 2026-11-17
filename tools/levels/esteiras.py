"""Fase 2 do ato 2: Esteiras (100x44, 2 baterias, lago de ácido).

Plataforming sobre esteiras (contra e a favor) e uma ponte de chapas soltas, tudo acima de um lago de
ácido: cair é morrer. A caixa sai da calha, viaja por uma esteira e cai entre duas paredes direto no
compartimento. Peças novas: esteira e ácido.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("esteiras", "Esteiras", 100, 44,
           hint="Pegue as duas baterias. O ácido mata ao toque",
           notes="Ato 2, fase 2 (D76). Três esteiras (contra, a favor, contra) e uma ponte de chapas soltas sobre o ácido, "
                 "uma bateria no fim de cada trecho. A caixa viaja por uma esteira até o compartimento.")
F = lv.floor_row  # 41
xr = lv.xr
ACID_TOP = 36

# --- ilhas e o lago de ácido (linhas 36..40)
lv.solid(1, ACID_TOP, 10, F - 1)
lv.solid(80, ACID_TOP, 98, F - 1)
for r in range(ACID_TOP, F):
    for c in range(11, 80):
        lv.g[r][c] = "%"
lv.block(3, ACID_TOP - 2, "P")
lv.step("wait", 5)

# --- esteiras
lv.ledge(14, 25, 34)
lv.add("conveyors", {"rect": [14, 34, 12, 1], "dir": 3, "speed": 30.0})
lv.hop(1, 14, 25, 34, ledge=False, safe=True)
lv.step("mark", "B1")
lv.ledge(28, 39, 31)
lv.add("conveyors", {"rect": [28, 31, 12, 1], "dir": 1, "speed": 50.0})
lv.hop(1, 28, 39, 31, ledge=False, safe=True)
lv.step("mark", "B2")
lv.ledge(42, 53, 28)
lv.add("conveyors", {"rect": [42, 28, 12, 1], "dir": 3, "speed": 40.0})
lv.hop(1, 42, 53, 28, ledge=False, safe=True)
lv.step("mark", "B3")

# --- primeira bateria
lv.hop(1, 56, 62, 25, safe=True)
lv.put(59, 24, "+")
lv.step("run_to", lv.cx(59))
lv.mark("bateria 1")

# --- a ponte de chapas soltas, e a segunda bateria
for c in (65, 68, 71, 74):
    lv.add("crumbles", [c, 25, 3, 1])
lv.hop(1, 65, 67, 25, ledge=False, safe=True)
lv.hop(1, 79, 84, 25, safe=True)
lv.put(81, 24, "+")
lv.step("run_to", lv.cx(81))
lv.mark("bateria 2")

# --- a alavanca (no alto, no meio), a calha e a esteira da caixa (à direita, sobre o compartimento)
lv.block(46, 2, "L")
lv.solid(78, 10, 83, 11)                      # suporte da calha
lv.block(80, 12, "H")
lv.ledge(80, 90, 20)
lv.add("conveyors", {"rect": [80, 20, 11, 1], "dir": 1, "speed": 40.0})
lv.solid(90, 21, 90, 33)                      # parede esquerda do canal
lv.solid(93, 20, 93, 33)                      # parede direita do canal
lv.block(91, ACID_TOP, "S")
lv.put(96, 33, "DD")
lv.put(96, 34, "DD")
lv.put(96, 35, "DD")
lv.step("wait_cutscene")

# --- desce pela direita para a ilha e vai à porta
lv.drop(1, 85, 88, ACID_TOP)
lv.step("wait_until", "door_open", 1500)
lv.step("to_door")
lv.ceiling()   # teto de espinhos: girar sem pensar é arriscado
lv.save()

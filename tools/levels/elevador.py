"""Entre o ato 2 e o ato 3: o elevador (14x10). D107.

A cabine (com teto, sem giro) sobe pelo poço; perto do topo, um tranco, alarme e faíscas; o cabo
estoura e ela despenca. No escuro do impacto, uma lâmpada roxa abafada acende, e a porta destrava:
dá para o fungário. A cena é do ator scripts/elevator.gd; o coelho anda à vontade na cabine.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("elevador", "Elevador", 14, 10, rotate=False, limiter=False,
           notes="Entre o ato 2 e o ato 3 (D107). A cabine sobe, trava perto do topo, o cabo estoura e ela cai. "
                 "No escuro, uma lâmpada roxa acende e a porta destrava. Sem giro (a cabine tem teto).",
           extra={"actors": ["res://scripts/elevator.gd"], "elevator": "ride", "music": "res://music/industrial-theme.mp3"})
lv.ascii([
    "##############",
    "#............#",
    "#............#",
    "#............#",
    "#.........DD.#",
    "#.........DD.#",
    "#.....PP..DD.#",
    "#.....PP..DD.#",
    "##############",
    "##############",
])
lv.step("wait", 5)
lv.step("wait_until", "door_open", 1200)
lv.step("to_door")
lv.save()

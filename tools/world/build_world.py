"""Monta o mundo de teste (modo metroidvania, D100) a partir de salas da campanha.

    python3 tools/world/build_world.py

Escreve levels/world/mundo.json e levels/world/rooms/<id>.json. Depois disso o mundo é do editor
(janela "Mundo…"): rodar de novo sobrescreve as salas com a versão daqui.

Mapa (coluna, linha):

    passos(0,0) ── degraus(1,0) ── setas(2,0)
                       │              │
                   comporta(1,1) ── giro(2,1) ── toca(3,1)  [porta: fim]

X = saída livre, Z = saída trancada (abre quando a sala é resolvida: a caixa no buraco "S").
As saídas de cima são chegadas por queda (o buraco no chão da sala de cima).
"""
import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
CAMP = os.path.join(ROOT, "levels", "campaign")
OUT = os.path.join(ROOT, "levels", "world")


def load(name):
    with open(os.path.join(CAMP, name + ".json")) as f:
        return json.load(f)


def grid(d):
    return [list(r) for r in d["rows"]]


def put(g, r, c, ch):
    g[r][c] = ch


def no_door(g):
    for row in g:
        for c, ch in enumerate(row):
            if ch == "D":
                row[c] = "."


def room(d, g, notes):
    out = {
        "name": d["name"],
        "notes": notes,
        "rotate": d.get("rotate", True),
        "rows": ["".join(r) for r in g],
        "start_rot": 0,
        "theme": d.get("theme", "caverna"),
        "version": 1,
    }
    for k in ("hint", "hint_touch", "limiter", "reload"):
        if k in d:
            out[k] = d[k]
    return out


rooms = {}

d = load("passos"); g = grid(d)
no_door(g)
for r in (5, 6): put(g, r, 19, "Z")
rooms["passos"] = (room(d, g, "início do mundo. A caixa no buraco abre a saída da direita."), (0, 0))

d = load("degraus"); g = grid(d)
no_door(g)
for r in (9, 10): put(g, r, 0, "X"); put(g, r, 28, "Z")
for c in (15, 16): put(g, 13, c, "X")
rooms["degraus"] = (room(d, g, "o vão no chão vira atalho para baixo (Comporta). A caixa no buraco abre a direita (Setas)."), (1, 0))

d = load("setas"); g = grid(d)
no_door(g)
for r in (13, 14): put(g, r, 0, "X")
for c in (8, 9): put(g, 15, c, "Z")
rooms["setas"] = (room(d, g, "a caixa no nicho abre o buraco do chão (queda para o Giro)."), (2, 0))

d = load("comporta"); g = grid(d)
no_door(g)
for c in (3, 4): put(g, 0, c, "X"); put(g, 1, c, ".")
for r in (7, 8): put(g, r, 29, "Z")
rooms["comporta"] = (room(d, g, "chega-se caindo do vão dos Degraus. A segunda caixa abre a direita (Giro)."), (1, 1))

d = load("giro"); g = grid(d)
no_door(g)
for c in (8, 9): put(g, 0, c, "X")
for r in (10, 11): put(g, r, 0, "X"); put(g, r, 17, "Z")
rooms["giro"] = (room(d, g, "chega-se pela esquerda (Comporta) ou caindo do buraco das Setas. A caixa abre a direita (Toca)."), (2, 1))

d = load("toca"); g = grid(d)
for r in (9, 10): put(g, r, 0, "X")
rooms["toca"] = (room(d, g, "a última: a porta encerra o teste."), (3, 1))

os.makedirs(os.path.join(OUT, "rooms"), exist_ok=True)
world = {"start": "passos", "rooms": []}
for rid, (data, pos) in rooms.items():
    with open(os.path.join(OUT, "rooms", rid + ".json"), "w") as f:
        f.write(json.dumps(data, indent="\t", ensure_ascii=False, sort_keys=True) + "\n")
    world["rooms"].append({"id": rid, "pos": list(pos)})
with open(os.path.join(OUT, "mundo.json"), "w") as f:
    f.write(json.dumps(world, indent="\t", ensure_ascii=False) + "\n")
print("mundo:", ", ".join(rooms))

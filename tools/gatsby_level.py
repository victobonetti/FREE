#!/usr/bin/env python3
"""Gera a fase do Gatsby (levels/wip/gatsby.json).

A fase é grande demais para desenhar à mão no JSON, e o editor ainda não edita placas,
conectores, chapas soltas nem o roteiro. Então ela é descrita aqui, trecho a trecho, e este
script escreve o arquivo. Depois de mudar a fase, refaça a rota do robô:

    python3 tools/gatsby_level.py
    godot --headless --path . -s tools/gatsby_robot.gd

Coordenadas em tiles: (coluna, linha), linha 0 em cima. Canais (cores dos conectores):
0 verde (estampadores), 1 rosa (varredor), 2 ciano (catapulta 2), 3 laranja (catapulta 1).
"""
import json
import os

W, H = 186, 107
SHAFT_R = 30          # última coluna livre do poço
FLOOR = 97            # linha do chão do poço
CORR = 15             # linha do chão do corredor (o corredor ocupa as linhas 1..14)

rows = [["#"] * W for _ in range(H)]


def carve(c0, r0, c1, r1):
    for r in range(r0, r1 + 1):
        for c in range(c0, c1 + 1):
            rows[r][c] = "."


def put(c, r, text):
    for i, ch in enumerate(text):
        rows[r][c + i] = ch


def ledge(c0, c1, r):
    for c in range(c0, c1 + 1):
        rows[r][c] = "#"


crumbles = []
movers = []


def plates(c0, c1, r, size=2):
    """Chapas soltas lado a lado, de `size` tiles cada."""
    c = c0
    while c <= c1:
        w = min(size, c1 - c + 1)
        crumbles.append([c, r, w, 1])
        c += w


# ------------------------------------------------------------------ o vazio
carve(1, 1, SHAFT_R, FLOOR - 1)          # poço
carve(SHAFT_R + 1, 1, W - 2, CORR - 1)   # corredor

# ------------------------------------------------------------------ poço
put(3, FLOOR - 2, "PP")
put(3, FLOOR - 1, "PP")

# S0  aquecimento: três patamares em zigue-zague
ledge(8, 12, 94)
ledge(16, 20, 91)
ledge(24, 29, 88)

# S1  chapas soltas: a escada desaba atrás de você
plates(18, 20, 85, 3)
plates(12, 14, 82, 3)
plates(6, 8, 79, 3)
ledge(11, 17, 76)

# S2  catapulta 1 (laranja): a pressa dele vira carona
movers.append({"ch": 3, "off": [20, 76, 4, 1], "on": [20, 70], "speed": 240, "launch": 300})
ledge(25, 28, 67)                         # não encosta na parede: a pista (colunas 29-30) fica livre

# S3  pista da direita: girar no sentido horário e correr pela parede
for r in (63, 59, 55, 51):
    put(29, r, "==")                      # só são chão com a sala em pé: seguram a volta do giro
ledge(21, 26, 51)

# S3b travessia sobre chapas soltas, até a pista da esquerda
plates(15, 17, 51, 3)
plates(9, 11, 51, 3)
ledge(4, 6, 51)
for r in (47, 43, 39, 35):
    put(1, r, "==")
ledge(4, 8, 35)

# S4  varredor (rosa): espinhos que correm pelo patamar
ledge(12, 18, 32)
movers.append({"ch": 1, "off": [12, 31, 2, 1], "on": [17, 31], "speed": 70, "spikes": 0})

# S5  catapulta 2 (ciano), para dentro do corredor
ledge(20, 21, 29)
movers.append({"ch": 2, "off": [22, 29, 4, 1], "on": [22, 18], "speed": 240, "launch": 300})
ledge(27, SHAFT_R, CORR)                  # a beirada do corredor

# ------------------------------------------------------------------ corredor
# C1  ponte de chapas soltas sobre um fosso de espinhos, com dois vãos
carve(45, CORR, 70, 19)
put(45, 19, "^" * 26)
plates(45, 52, CORR)
plates(56, 61, CORR)
plates(65, 70, CORR)

# C2  estampadores (verde): três, com o do meio ao contrário
for i, c in enumerate((78, 86, 94)):
    up, down = [c, 5, 3, 2], [c, 11]
    if i == 1:
        movers.append({"ch": 0, "off": [c, 11, 3, 2], "on": [c, 5], "speed": 120, "spikes": 2})
    else:
        movers.append({"ch": 0, "off": up, "on": down, "speed": 120, "spikes": 2})

# C3  a queda: o Gatsby gira a sala e o corredor vira um poço. Espinhos só no teto (que vira a
#     parede da direita): quem cai rente ao chão antigo pousa no degrau.
for c in range(108, 132, 6):
    put(c, 1, "vvv")
ledge(136, 137, 12)
ledge(136, 137, 13)
ledge(136, 137, 14)

# C4  reta final: mais uma ponte que desaba, e a porta
carve(143, CORR, 158, 19)
put(143, 19, "^" * 16)
plates(143, 158, CORR)
for r in (12, 13, 14):
    put(176, r, "DD")

# ------------------------------------------------------------------ placas
crushers = [
    {"rect": [1, 1, SHAFT_R, H - 2], "dir": 0, "speed": 10.0, "delay": -1, "start": 0, "leash": 88, "face": "happy"},
    {"rect": [1, 1, W - 2, CORR - 1], "dir": 1, "speed": 28.0, "delay": -1, "leash": 112, "face": "sad"},
]

# ------------------------------------------------------------------ roteiro do Gatsby
script = [
    {"cut": True, "mood": "bored", "wait": 1.0},
    {"cut": True, "mood": "smug", "lever": True, "crusher": 0, "wait": 0.3},
    {"when": [14, 82, 17, 6], "mood": "amused"},
    {"when": [20, 73, 4, 3], "mood": "annoyed", "lever": True, "toggle": 3},
    {"when": [25, 62, 6, 5], "mood": "smug"},
    {"when": [19, 46, 12, 5], "mood": "annoyed", "speed": [0, 8.0]},   # travessia no plano: a placa dá um respiro
    {"when": [1, 30, 9, 5], "mood": "furious", "lever": True, "toggle": 1, "repeat": 40, "wait": 1.5, "speed": [0, 12.0]},
    {"when": [22, 26, 4, 3], "mood": "furious", "lever": True, "toggle": 2},
    {"when": [31, 1, 8, 14], "mood": "furious", "lever": True, "crusher": 1, "wait": 0.2},
    {"when": [66, 1, 4, 14], "mood": "nervous", "lever": True, "toggle": 0, "repeat": 40, "wait": 1.4},
    {"when": [100, 1, 3, 14], "mood": "nervous", "lever": True, "rotate": 1, "wait": 0.2},
    {"when": [131, 9, 5, 6], "mood": "nervous", "lever": True, "rotate": -1},
    {"when": [139, 1, 3, 14], "mood": "panic"},
    {"when": [150, 1, 3, 14], "mood": "smirk", "wait": 0.3, "flee": True},
]

level = {
    "name": "Gatsby",
    "notes": "Fuga do Gatsby (GDD 8c). Poço: patamares, chapas soltas, catapulta, duas corridas pela "
             "parede com o limitador (direita e esquerda), varredor, catapulta para o corredor. Corredor: "
             "ponte de chapas sobre espinhos, estampadores, a queda (giro do Gatsby) e a ponte final. "
             "Gerada por tools/gatsby_level.py; a rota do robô (gatsby-route.json) prova que tem solução.",
    "hint": "Q e E giram a sala por um instante: a parede vira chão",
    "hint_touch": "As setas giram a sala por um instante: a parede vira chão",
    "rotate": True,
    "limiter": True,
    "door_open": True,
    "theme": "industrial",
    "start_rot": 0,
    "version": 1,
    "actors": ["res://scripts/boss_gatsby.gd"],
    "crushers": crushers,
    "movers": movers,
    "crumbles": crumbles,
    "gatsby": {"start": [14, 90], "script": script},
    "rows": ["".join(r) for r in rows],
}

out = os.path.join(os.path.dirname(__file__), "..", "levels", "wip", "gatsby.json")
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "w", encoding="utf-8") as f:
    json.dump(level, f, ensure_ascii=False, indent="\t")
    f.write("\n")
print("fase %dx%d: %d conectores, %d chapas soltas, %d passos de roteiro" % (W, H, len(movers), len(crumbles), len(script)))

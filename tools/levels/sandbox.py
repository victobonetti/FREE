"""Sandbox (sala -1 da build de teste): todos os componentes numa sala só, para os beta testers
mexerem à vontade. Não é fase da campanha e não tem rota de robô.

REGRA (D99): sempre que um componente novo for criado, ele entra aqui. O teste test_sandbox
(tests/run_tests.gd) falha se algum símbolo de LevelData.GLYPHS ou tipo de objeto de
scripts/editor/objects.gd faltar nesta sala. Exceção: o ácido (%), porque uma sala só aceita um
fluido (a sandbox usa água).

Da esquerda para a direita, no chão: o botão por tempo que chama o elevador; a comporta e a
inversa (no alto, ligadas ao compartimento "a"); espinhos; barras sólidas e de passagem; a corda;
o poço de água (com o ralo no alto); bateria, alavanca e calha; esteira, mola, ventilador e jato
de vapor; a caixa da porta. Na parede da direita, um broto (ato 3). Nas paredes, as saídas do modo mundo: a livre (esquerda) e a trancada (direita). No alto: plataforma em ciclo, estampador, catapulta, chapas soltas e a
placa de espinhos (num corredor fechado, começa depois de 6 s).
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from levelkit import Level

lv = Level("sandbox", "Sandbox", 104, 40, theme="transicao", limiter=False,
           hint="Sandbox: todos os componentes. Esc volta ao início",
           notes="Sala -1 da build de teste (D99): todos os componentes, para os beta testers. "
                 "Gerada por tools/levels/sandbox.py; o teste test_sandbox confere que nada falta.")
F = lv.floor_row  # 37

lv.block(2, F - 2, "P")

# --- botão por tempo + elevador (canal 5)
lv.add("plates", {"rect": [6, F - 1, 2, 1], "ch": 5, "mode": "timed", "time": 5.0})
lv.add("movers", {"ch": 5, "off": [9, F - 1, 3, 1], "on": [9, F - 14], "speed": 120.0, "delay": 1.0})
lv.ledge(12, 16, F - 14)

# --- comporta "1", a inversa e o compartimento "a" (com uma caixa ao lado)
lv.block(18, F, "a")
lv.block(21, F - 2, "B")
for r in range(F - 12, F - 8):
    lv.put(15, r, "1")
    lv.put(17, r, "¹")

# --- espinhos (chão, parede e teto)
lv.spikes(25, 27, F - 1, "^")
lv.solid(29, F - 4, 29, F - 1)
lv.spikes(28, 28, F - 3, "<")
lv.spikes(30, 30, F - 3, ">")
lv.spikes(25, 28, 1, "v")

# --- barras: sólidas (= } _ {) e de passagem (↑ → ↓ ←)
lv.put(33, F - 4, "====")
lv.put(39, F - 4, "↑↑↑↑")
lv.put(33, F - 9, "}_{")
lv.put(39, F - 9, "→↓←")

# --- corda pendurada do teto
for r in range(1, 12):
    lv.put(46, r, "|")
lv.put(50, 6, "------")     # e uma esticada (horizontal), presa na parede de cima? não: presa no bloco
lv.solid(49, 5, 49, 7)

# --- poço de água, com o ralo no alto (só engole se a sala girar)
lv.clear(53, F, 61, F + 1)
for r in (F, F + 1):
    lv.put(53, r, "~" * 9)
lv.put(56, F - 1, "~~~")
lv.put(54, 2, "o")

# --- bateria, alavanca e calha (a calha solta uma caixa quando todas as baterias forem pegas)
lv.put(64, F - 1, "+")
lv.block(66, 2, "L")
lv.block(68, 2, "H")

# --- esteira, mola, ventilador, jato de vapor
lv.add("conveyors", {"rect": [71, F, 6, 1], "dir": 1, "speed": 40.0})
lv.add("springs", {"rect": [79, F - 1, 2, 1], "power": 320.0})
lv.add("fans", {"rect": [83, F - 12, 2, 12], "dir": 0, "accel": 1500.0, "cap": 70.0})
lv.add("vents", {"rect": [88, F - 6, 2, 6], "dir": 0, "period": 3.0, "on": 1.2, "phase": 0.0})

# --- a caixa da porta e a porta
lv.block(93, F - 2, "B")
lv.block(96, F, "S")
for r in (F - 3, F - 2, F - 1):
    lv.put(100, r, "DD")

# --- saídas na parede (modo mundo, D100): a livre na esquerda, a trancada (abre com a caixa) na
# direita. Fora do mundo, sair por uma delas vale como chegar à porta.
for r in (F - 2, F - 1):
    lv.put(0, r, "X")
    lv.put(103, r, "Z")

# --- no alto: plataforma em ciclo, estampador, catapulta, chapas soltas
lv.ledge(20, 24, F - 14)
lv.add("movers", {"ch": 3, "off": [26, F - 14, 3, 1], "on": [34, F - 14], "speed": 80.0, "cycle": 2.5})
lv.ledge(38, 44, F - 14)
lv.add("movers", {"ch": 1, "off": [40, F - 20, 2, 2], "on": [40, F - 16], "speed": 140.0, "spikes": 2, "cycle": 2.4})
lv.add("movers", {"ch": 2, "off": [62, F - 15, 3, 1], "on": [62, F - 22], "speed": 240.0, "launch": 300.0, "cycle": 3.0})
lv.ledge(58, 61, F - 15)
for c in (66, 69, 72):
    lv.add("crumbles", [c, F - 15, 3, 1])
lv.ledge(75, 78, F - 15)

# --- a placa de espinhos, num corredor fechado no alto à direita (começa depois de 6 s)
lv.solid(80, 8, 101, 8)
lv.solid(80, 14, 101, 14)
lv.solid(80, 9, 80, 13)
lv.add("crushers", {"rect": [81, 9, 20, 5], "dir": 1, "speed": 14.0, "delay": 6.0, "face": "happy"})

# --- broto (ato 3): nasce na parede da direita, recolhido; girando para a direita, cresce
lv.add("sprouts", {"rect": [101, F - 6, 2, 2], "dir": 3, "len": 6, "speed": 80.0, "back": 16.0})

# --- cogumelo-mola (ato 3), no chão perto da caixa da porta
lv.add("bouncers", {"rect": [90, F - 1, 2, 1], "power": 300.0, "dir": 0})

lv.save()

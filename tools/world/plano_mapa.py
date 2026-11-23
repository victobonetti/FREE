"""O plano do mapa metroidvania (D118, só planejamento): as salas, onde ficam (em telas), de que mundo
são, a dificuldade, o que pedem para entrar, de onde vêm e as ligações. Gera a imagem do mapa e as
tabelas do documento docs/PLANO_METROIDVANIA.md, para os dois saírem dos mesmos dados.

    python3 tools/world/plano_mapa.py      ->  docs/plano-mapa.png  e  as tabelas na saída padrão

Uma "tela" é 40x22 tiles (320x176 px, uma tela do jogo). x cresce para a direita, y para baixo.
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")

# mundo -> (nome, cor)
WORLDS = {
    "C": ("Campo", (150, 190, 120)),
    "P": ("O Poço", (200, 200, 210)),
    "1": ("Subsolo", (176, 132, 92)),
    "T": ("Passagem", (160, 150, 140)),
    "2": ("Fábrica", (110, 150, 190)),
    "3": ("Fungário", (155, 107, 196)),
    "L": ("Laboratório", (220, 90, 100)),
}

# id, nome, mundo, x, y, w, h, dificuldade (0-10), pede (habilidade/itens), dá, origem, mecânicas, marca
# marca: S = toca de salvar, B = chefe, ♥ = coração, ? = pista
R = [
    ("C1", "Campo", "C", 9, 0, 5, 1, 0, "", "", "abertura (nova versão)", "andar, cair no buraco", ""),
    ("P1", "Poço: raízes", "P", 12, 1, 1, 4, 1, "", "", "nova", "queda; o fundo é um cristal", "S"),
    ("P2", "Poço: despensa", "P", 12, 5, 1, 5, 5, "A6 (vindo de cima)", "", "nova", "giro do poço inteiro", "S"),
    ("P3", "Poço: fungário", "P", 12, 10, 1, 4, 6, "A6 (vindo de cima)", "", "nova", "giro do poço inteiro", "S"),
    ("P4", "Poço: fundo", "P", 12, 14, 1, 3, 7, "A7 (vindo de cima)", "", "nova", "porta das três luzes", "S"),
    # mundo 1: subsolo
    ("r1", "Primeiros passos", "1", 11, 1, 1, 1, 1, "", "", "passos", "andar, pular, caixa", ""),
    ("r2", "Degraus", "1", 9, 1, 2, 1, 1, "", "", "degraus (maior)", "caixa como degrau", ""),
    ("r3", "Raiz torta", "1", 7, 1, 2, 1, 2, "", "", "nova", "empurrar, cair, sem giro", ""),
    ("r4", "Toca do susto", "1", 6, 1, 1, 2, 2, "", "A1 batida de pata", "giro", "o primeiro giro", ""),
    ("c1", "Comporta", "1", 7, 2, 2, 1, 2, "A1", "", "comporta", "comporta, espinho", ""),
    ("c2", "Derrame", "1", 9, 2, 2, 2, 3, "A1", "", "derrame (maior)", "comportas em cadeia", ""),
    ("c3", "Setas", "1", 11, 2, 1, 2, 3, "A1", "atalho para o Poço", "setas", "plataforma por orientação", ""),
    ("c4", "Toca longa", "1", 3, 2, 3, 1, 3, "A1", "", "toca", "caixa longe do compartimento", ""),
    ("c5", "Ninho", "1", 7, 3, 1, 1, 0, "", "", "nova", "", "S"),
    ("c6", "Espinhos", "1", 7, 4, 2, 1, 4, "A1", "", "espinhos", "espinho + plataforma", ""),
    ("c7", "Prumo", "1", 5, 3, 2, 2, 4, "A1", "", "prumo (refeita)", "corda", ""),
    ("c8", "Vertigem", "1", 2, 3, 3, 2, 5, "A1", "A2 giro no ar", "vertigem (maior)", "tudo do subsolo seco", ""),
    ("c9", "Galeria", "1", 9, 4, 2, 2, 4, "A2", "", "nova", "subir com giro no ar", ""),
    ("cx", "Fresta", "1", 0, 3, 2, 1, 5, "A2", "coração 1", "nova", "segredo", "♥"),
    ("a1", "Água", "1", 4, 5, 2, 1, 3, "A2", "", "agua", "água, ralo", ""),
    ("a2", "Maré", "1", 3, 5, 1, 3, 5, "A2", "", "mare", "água + limitador", ""),
    ("a3", "Represa", "1", 4, 6, 3, 1, 5, "A2", "", "represa", "água + espinho", ""),
    ("a4", "Naufrágio", "1", 4, 7, 3, 1, 6, "A2", "", "naufragio", "água + caixa", ""),
    ("a5", "Mergulho", "1", 7, 6, 1, 3, 6, "A2", "A3 mergulho", "mergulho", "água funda, corda", ""),
    ("a6", "Fonte", "1", 2, 7, 1, 1, 0, "", "", "nova", "", "S"),
    ("a7", "Lagoa funda", "1", 0, 8, 3, 2, 7, "A3 + A7 (no fim)", "atalho para o Fungário", "nova", "água funda, gosma", "?"),
    ("ax", "Poço d'água", "1", 0, 6, 2, 2, 6, "A3", "coração 2", "nova", "segredo", "♥"),
    ("d1", "Despensa", "1", 8, 6, 2, 1, 0, "A3", "", "nova", "nozes, pista", "S?"),
    ("d2", "Covil do Jeffrey", "1", 8, 7, 2, 2, 6, "", "A4 puxar caixas, chave 1", "jeffrey", "chefe", "B"),
    ("d3", "Fuga", "1", 10, 6, 2, 3, 6, "A4", "", "fuga (maior)", "limitador, fuga", ""),
    # passagem
    ("t1", "Passagem", "T", 13, 7, 3, 1, 4, "", "", "passagem", "plataformas móveis, esteira", ""),
    # mundo 2: fábrica
    ("f1", "Portaria", "2", 16, 7, 1, 1, 0, "", "", "nova", "", "S"),
    ("f2", "Linha de montagem", "2", 17, 7, 2, 1, 4, "", "", "linha-de-montagem", "bateria, alavanca, calha", ""),
    ("f3", "Esteiras", "2", 19, 7, 2, 1, 5, "", "", "esteiras", "esteira", ""),
    ("f4", "Almoxarifado", "2", 16, 8, 2, 1, 5, "", "atalho para a Portaria", "nova", "caixas + baterias", ""),
    ("f5", "Prensas e vapor", "2", 18, 8, 3, 1, 6, "", "", "prensas-e-vapor", "prensa, vapor, placa", ""),
    ("f6", "Dutos", "2", 21, 6, 1, 3, 6, "", "A5 meia-volta", "dutos", "ventilador", ""),
    ("f7", "Caldeira", "2", 18, 9, 2, 1, 6, "A5", "", "nova", "ácido (introdução)", ""),
    ("f8", "Tanques", "2", 20, 9, 2, 2, 7, "A5", "", "nova", "ácido + giro", ""),
    ("f9", "Casa de força", "2", 16, 9, 2, 2, 7, "A5", "", "casa-de-forca", "tudo da fábrica; Gatsby provoca", ""),
    ("fa", "Escritório do Gatsby", "2", 16, 6, 1, 1, 0, "", "", "nova", "pista", "S?"),
    ("fb", "Corrida do Gatsby", "2", 13, 1, 5, 5, 8, "A5", "", "gatsby", "a corrida (chefe)", "B"),
    ("fc", "A mecha", "2", 18, 1, 2, 2, 7, "", "A6 pata firme, chave 2", "a-mecha", "chefe", "B"),
    ("fd", "Telhado", "2", 20, 2, 3, 2, 7, "A6", "coração 3", "nova", "segredo (estabilizadores)", "♥"),
    ("fp", "Plataforma", "2", 20, 1, 3, 1, 0, "", "", "plataforma", "a saída da mecha (cena)", ""),
    ("fe", "Elevador", "2", 23, 1, 1, 10, 0, "A6", "", "elevador", "descida (cena); estabilizadores", ""),
    # mundo 3: fungário
    ("g1", "Câmara do elevador", "3", 22, 11, 2, 1, 0, "", "", "nova", "", "S"),
    ("g2", "Broto", "3", 20, 11, 2, 1, 6, "", "", "broto", "broto", ""),
    ("g3", "Chapéus", "3", 18, 11, 2, 2, 6, "", "", "chapeus", "cogumelo-mola", ""),
    ("g4", "Murchos", "3", 16, 12, 2, 1, 7, "", "", "murchos", "cogumelo murcho", ""),
    ("g5", "Esporos", "3", 18, 13, 2, 1, 7, "", "", "esporos", "bufa-esporos", ""),
    ("g6", "Micélio", "3", 14, 12, 2, 2, 8, "A5", "", "nova", "fungos + meia-volta", ""),
    ("g7", "Caramujário", "3", 16, 13, 2, 1, 0, "", "", "nova", "pista", "S?"),
    ("g8", "Colônia", "3", 14, 14, 4, 1, 8, "", "", "colonia (maior)", "todos os fungos; o presságio", ""),
    ("g9", "Arena do Senzi", "3", 13, 15, 2, 1, 9, "", "A7 seringa, chave 3", "senzi", "chefe", "B"),
    ("ga", "Túnel dos caramujos", "3", 10, 12, 2, 1, 6, "A6", "", "nova", "liga o Poço ao oeste", ""),
    ("gb", "Esporal", "3", 6, 12, 4, 2, 8, "A6", "", "nova", "esporos + água", ""),
    ("gc", "Raízes podres", "3", 3, 11, 3, 2, 8, "A7", "coração 4", "nova", "segredo (gosma)", "♥"),
    ("gd", "Margem", "3", 0, 10, 3, 2, 7, "A7", "", "nova", "chega a Lagoa funda", ""),
    # laboratório
    ("L1", "Antecâmara", "L", 12, 17, 1, 2, 0, "chaves 1, 2 e 3", "", "nova", "a verdade começa", "S?"),
    ("L2", "Teste: subsolo", "L", 9, 17, 3, 1, 8, "", "", "remix do subsolo", "cristais: tudo do mundo 1", "?"),
    ("L3", "Teste: fábrica", "L", 13, 17, 3, 1, 9, "", "", "remix da fábrica", "tudo do mundo 2", "?"),
    ("L4", "Teste: fungário", "L", 9, 18, 3, 1, 9, "", "", "remix do fungário", "tudo do mundo 3", "?"),
    ("L5", "Sala de controle", "L", 13, 18, 3, 1, 9, "", "", "nova", "desligar os amortecedores", "?"),
    ("L6", "Biotério", "L", 16, 17, 2, 2, 7, "", "", "nova", "soltar os animais", ""),
    ("L7", "O amortecedor-mor", "L", 18, 17, 2, 2, 10, "todas", "", "nova", "a fuga final pelo Poço", "B"),
]

# ligações: (a, b, tipo) — tipo: "" livre, "Z" resolver a sala, "A1".."A7" habilidade, "1" mão única (a -> b),
# "chaves" a porta das três luzes
LINKS = [
    ("C1", "P1", "1"), ("P1", "r1", ""), ("r1", "r2", ""), ("r2", "r3", ""), ("r3", "r4", ""), ("r4", "c1", "A1"),
    ("c1", "c2", "Z"), ("c2", "c3", "Z"), ("c3", "P1", "1"), ("r4", "c4", "A1"), ("c1", "c5", ""), ("c5", "c6", ""),
    ("c5", "c7", ""), ("c7", "c8", "Z"), ("c4", "c8", "Z"), ("c8", "cx", "A2"), ("c6", "c9", "A2"), ("c2", "c9", "A2"),
    ("c7", "a1", "A2"), ("a1", "a2", ""), ("a2", "a6", ""), ("a1", "a3", "Z"), ("a3", "a4", "Z"), ("a4", "a5", ""),
    ("a6", "ax", "A3"), ("a6", "a7", "A3"), ("a5", "d1", "A3"), ("d1", "d2", ""), ("d2", "d3", "A4"), ("d3", "P2", "1"),
    ("c9", "d1", "A4"), ("P2", "t1", ""), ("t1", "f1", ""), ("f1", "f2", ""), ("f2", "f3", "Z"), ("f1", "f4", ""),
    ("f4", "f5", "Z"), ("f3", "f6", ""), ("f5", "f6", "Z"), ("f6", "f8", "A5"), ("f5", "f7", "A5"), ("f7", "f8", "Z"),
    ("f7", "f9", "Z"), ("f9", "f4", "Z"), ("f1", "fa", ""), ("fa", "fb", "A5"), ("fb", "fc", ""), ("fc", "fp", ""),
    ("fp", "fd", "A6"), ("fp", "fe", "A6"),
    ("fb", "P1", "1"), ("fe", "g1", "1"), ("g1", "g2", ""), ("g2", "g3", "Z"), ("g3", "g4", "Z"), ("g3", "g5", ""),
    ("g4", "g6", "A5"), ("g5", "g7", "Z"), ("g4", "g7", ""), ("g6", "g8", "Z"), ("g7", "g8", ""), ("g8", "g9", "Z"),
    ("g9", "P4", "1"),
    ("P1", "P2", "A6"), ("P2", "P3", "A6"), ("P3", "P4", "A7"), ("P3", "ga", ""), ("ga", "gb", ""), ("gb", "gc", "A7"),
    ("gc", "gd", ""), ("gd", "a7", "A7"), ("P4", "L1", "chaves"), ("L1", "L2", ""), ("L2", "L4", "Z"), ("L4", "L1", "Z"),
    ("L1", "L3", "Z"), ("L3", "L5", "Z"), ("L5", "L6", "Z"), ("L3", "L6", ""), ("L6", "L7", ""),
]

CRITICAL = ["C1", "P1", "r1", "r2", "r3", "r4", "c1", "c2", "c5", "c7", "c8", "c9", "a1", "a3", "a4", "a5", "d1",
            "d2", "d3", "P2", "t1", "f1", "f2", "f3", "f6", "f5", "f7", "f9", "f4", "fa", "fb", "fc", "fp", "fe",
            "g1", "g2", "g3", "g4", "g6", "g8", "g9", "P4", "L1", "L2", "L4", "L3", "L5", "L6", "L7"]

U = 46          # px por tela no desenho
PAD = 30


def main():
    byid = {r[0]: r for r in R}
    W = 24 * U + PAD * 2 + 330
    H = 19 * U + PAD * 2 + 170
    img = Image.new("RGB", (W, H), (14, 14, 20))
    d = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("DejaVuSans.ttf", 11)
        bold = ImageFont.truetype("DejaVuSans-Bold.ttf", 12)
        big = ImageFont.truetype("DejaVuSans-Bold.ttf", 17)
    except OSError:
        font = bold = big = ImageFont.load_default()
    # grade
    for gx in range(25):
        d.line([(PAD + gx * U, PAD), (PAD + gx * U, PAD + 19 * U)], fill=(28, 28, 36))
    for gy in range(20):
        d.line([(PAD, PAD + gy * U), (PAD + 24 * U, PAD + gy * U)], fill=(28, 28, 36))

    def rect(r):
        _, _, _, x, y, w, h = r[:7]
        return (PAD + x * U + 2, PAD + y * U + 2, PAD + (x + w) * U - 2, PAD + (y + h) * U - 2)

    def center(r):
        a = rect(r)
        return ((a[0] + a[2]) / 2, (a[1] + a[3]) / 2)
    # salas
    for r in R:
        rid, name, wd, x, y, w, h, diff, req, give, src, mech, mark = r
        a = rect(r)
        base = WORLDS[wd][1]
        k = 0.35 + 0.065 * diff
        fill = tuple(int(c * k) for c in base)
        d.rectangle(a, fill=fill, outline=base, width=3 if rid in CRITICAL else 1)
        d.text((a[0] + 4, a[1] + 2), rid, fill=(255, 255, 255), font=bold)
        d.text((a[0] + 4, a[1] + 16), str(diff), fill=(255, 230, 150), font=font)
        tags = ""
        if "S" in mark:
            tags += "S"
        if "B" in mark:
            tags += "★"
        if "♥" in mark:
            tags += "♥"
        if "?" in mark:
            tags += "?"
        if give.startswith("A"):
            tags += " " + give[:2]
        if tags:
            d.text((a[0] + 22, a[1] + 2), tags, fill=(255, 200, 80), font=bold)
    # ligações: uma porta na parede que as duas salas dividem
    for a_id, b_id, k in LINKS:
        ra, rb = byid[a_id], byid[b_id]
        ax, ay, aw, ah = ra[3:7]
        bx, by_, bw, bh = rb[3:7]
        col = {"": (150, 150, 160), "Z": (243, 207, 59), "1": (120, 200, 255), "chaves": (255, 90, 110)}.get(k, (255, 140, 60))
        if ax + aw == bx or bx + bw == ax:
            ex = PAD + (ax + aw if ax + aw == bx else ax) * U
            y0s, y1s = max(ay, by_), min(ay + ah, by_ + bh)
            ey = PAD + (y0s + y1s) / 2.0 * U
            d.rectangle([ex - 4, ey - 9, ex + 4, ey + 9], fill=col)
            lab_at = (ex + 6, ey + 3)
        else:
            ey = PAD + (ay + ah if ay + ah == by_ else ay) * U
            x0s, x1s = max(ax, bx), min(ax + aw, bx + bw)
            ex = PAD + (x0s + x1s) / 2.0 * U
            d.rectangle([ex - 9, ey - 4, ex + 9, ey + 4], fill=col)
            lab_at = (ex + 11, ey - 7)
        if k.startswith("A") or k in ("chaves", "1"):
            horiz = ax + aw == bx or bx + bw == ax
            arrow = ("→" if bx > ax else "←") if horiz else ("↓" if by_ > ay else "↑")
            lab = {"chaves": "3 chaves", "1": arrow}.get(k, k)
            tw = d.textlength(lab, font=bold)
            d.rectangle([lab_at[0] - 2, lab_at[1] - 1, lab_at[0] + tw + 2, lab_at[1] + 14], fill=(20, 12, 6))
            d.text(lab_at, lab, fill=col, font=bold)
    # legenda
    lx = PAD + 24 * U + 20
    y0 = PAD
    d.text((lx, y0), "FREE — plano do mapa", fill=(255, 255, 255), font=big)
    y0 += 28
    for wd, (nm, col) in WORLDS.items():
        d.rectangle([lx, y0, lx + 14, y0 + 14], fill=tuple(int(c * 0.6) for c in col), outline=col)
        d.text((lx + 20, y0), nm, fill=(230, 230, 230), font=font)
        y0 += 19
    y0 += 8
    for col, txt in [((150, 150, 160), "passagem livre"), ((243, 207, 59), "abre ao resolver a sala (Z)"),
                     ((120, 200, 255), "mão única (queda, fuga)"), ((255, 140, 60), "pede habilidade (A1–A7)"),
                     ((255, 90, 110), "as três chaves")]:
        d.line([(lx, y0 + 7), (lx + 18, y0 + 7)], fill=col, width=3)
        d.text((lx + 24, y0), txt, fill=(230, 230, 230), font=font)
        y0 += 18
    y0 += 8
    for txt in ["número: dificuldade (0–10)", "borda grossa: caminho principal", "S toca de salvar   ★ chefe",
                "♥ coração   ? pista do laboratório", "A1–A7: onde se ganha a habilidade", "1 quadrado = 1 tela (40×22 tiles)"]:
        d.text((lx, y0), txt, fill=(200, 200, 200), font=font)
        y0 += 17
    y0 += 10
    d.text((lx, y0), "Habilidades", fill=(255, 255, 255), font=bold)
    y0 += 18
    for txt in ["A1 batida de pata (girar)", "A2 giro no ar", "A3 mergulho", "A4 puxar caixas",
                "A5 meia-volta (180°)", "A6 pata firme (amortecedor)", "A7 seringa (coelhão)"]:
        d.text((lx, y0), txt, fill=(255, 170, 90), font=font)
        y0 += 16
    # curva de dificuldade do caminho principal
    cy = PAD + 19 * U + 30
    ch = 110
    cw = 24 * U
    d.text((PAD, cy - 22), "Curva de dificuldade no caminho principal (salas na ordem)", fill=(255, 255, 255), font=bold)
    d.rectangle([PAD, cy, PAD + cw, cy + ch], outline=(60, 60, 70))
    pts = []
    crit = [rid for rid in CRITICAL if byid[rid][7] > 0]   # sem as tocas e as cenas (dificuldade 0)
    for i, rid in enumerate(crit):
        r = byid[rid]
        px = PAD + 8 + i * (cw - 16) / (len(crit) - 1)
        py = cy + ch - 6 - r[7] * (ch - 12) / 10.0
        pts.append((px, py, r))
    d.line([(p[0], p[1]) for p in pts], fill=(255, 230, 150), width=2)
    for px, py, r in pts:
        col = WORLDS[r[2]][1]
        rad = 5 if "B" in r[12] else 3
        d.ellipse([px - rad, py - rad, px + rad, py + rad], fill=col)
    img.save(os.path.join(ROOT, "docs", "plano-mapa.png"))

    # tabelas
    for wd, (nm, _) in WORLDS.items():
        rows = [r for r in R if r[2] == wd]
        print("\n#### %s\n" % nm)
        print("| Sala | Nome | Telas | Dif. | Pede | Dá | Origem | Mecânicas |")
        print("|---|---|---|---|---|---|---|---|")
        for r in rows:
            rid, name, _, x, y, w, h, diff, req, give, src, mech, mark = r
            extra = {"S": " (salvar)", "B": " (chefe)"}
            nm2 = name + "".join(v for k, v in extra.items() if k in mark)
            print("| %s | %s | %dx%d | %d | %s | %s | %s | %s |" % (rid, nm2, w, h, diff, req or "—", give or "—", src, mech or "—"))
    print("\nsalas:", len(R), " telas:", sum(r[5] * r[6] for r in R), " caminho principal:", len(CRITICAL))
    progressao()


def progressao():
    """Simula a progressão em ondas: começa no Campo sem nada; em cada onda, abre todas as ligações
    possíveis com o que já tem (as de mão única, só no sentido delas) e, depois, recolhe o que as
    salas alcançadas dão. Imprime o que cada onda destrava e confere que todas as salas ficam
    alcançáveis (sem beco sem saída no plano)."""
    byid = {r[0]: r for r in R}
    have = set()
    seen = {"C1"}
    wave = 0
    while True:
        grew = True
        while grew:
            grew = False
            for a, b, k in LINKS:
                ok = k in ("", "Z", "1") or k in have or (k == "chaves" and {"chave 1", "chave 2", "chave 3"} <= have)
                if not ok:
                    continue
                for x, y in ((a, b), (b, a)) if k != "1" else ((a, b),):
                    if x in seen and y not in seen:
                        seen.add(y)
                        grew = True
        new = []
        for r in R:
            if r[0] not in seen:
                continue
            for g in [t.strip() for t in r[9].split(",")]:
                key = g[:2] if g.startswith("A") else g
                if (g.startswith("A") or g.startswith("chave")) and key not in have:
                    new.append((key, "%s (%s)" % (g, r[1])))
        if not new:
            break
        wave += 1
        for key, _ in new:
            have.add(key)
        print("onda %d: %d salas abertas; ganha %s" % (wave, len(seen), "; ".join(t for _, t in new)))
    falta = [r[0] for r in R if r[0] not in seen]
    print("salas alcançáveis: %d de %d%s" % (len(seen), len(R), ("; faltam " + ", ".join(falta)) if falta else ""))


if __name__ == "__main__":
    main()

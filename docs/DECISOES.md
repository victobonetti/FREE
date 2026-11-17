# Registro de decisões

Cada entrada diz o que foi decidido, por quê, e o que foi descartado. "Autor" indica quem decidiu: **Victor** (dono do projeto) ou **Claude** (decisão de implementação, aberta a revisão).

Quando uma decisão for revertida, não apague a entrada: marque como substituída e aponte para a nova.

---

## Conceito

### D01 — Mecânica central: girar a sala de 90 em 90 graus
- **Autor:** Victor (conceito original, `concept.png`).
- **Decisão:** o jogador gira a sala inteira; tudo que está solto cai. A gravidade aponta sempre para baixo na tela.
- **Consequência:** os controles nunca mudam, o que mantém o jogo legível mesmo com a sala de lado.

### D02 — Porta abre com caixa no compartimento, e fecha se a caixa sair
- **Autor:** Victor.
- **Decisão:** a porta só fica aberta enquanto todos os compartimentos estão ocupados.
- **Consequência:** o puzzle de cada sala é chegar à porta em uma orientação em que a caixa continue encaixada.

### D03 — Estética quase monocromática, cor só no que é interativo
- **Autor:** Victor (monocromático e suave); Claude (regra "cor = interativo").
- **Decisão:** fundo escuro, linhas off-white. Cores reservadas: caixa azul, porta amarela (aberta) e azul-acinzentada (trancada), compartimento cinza, espinhos coral, olho vermelho do coelho.

### D04 — Piloto com 5 salas
- **Autor:** Victor.
- **Decisão:** escopo fechado em 5 salas para validar a ideia antes de expandir.

### D05 — Referência de controle: Celeste e Super Meat Boy
- **Autor:** Victor.
- **Decisão:** o controle tem de ser fluido; respawn instantâneo, sem vidas.

---

## Regras de jogo

### D06 — Giro no ar: um por pulo
- **Autor:** Claude (recomendação), aceita por Victor ao aprovar o plano.
- **Decisão:** o coelho pode girar a sala uma vez enquanto está no ar; recarrega ao tocar o chão.
- **Motivo:** cria teto de habilidade, como o dash de Celeste. As salas 4 e 5 dependem disso.
- **Descartado:** girar só no chão (puzzle mais puro, menos precisão).

### D07 — Caixa que cai sobre o coelho o esmaga
- **Autor:** Claude (recomendação), aceita por Victor.
- **Motivo:** dá tensão a cada giro.
- **Descartado:** caixa inofensiva.

### D08 — Porta trancada é sólida *(substituída por D34)*
- **Autor:** Claude (recomendação), aceita por Victor.
- **Motivo:** pode servir de parede ou plataforma, e rende puzzles sem custo.
- **Estado:** revertida por Victor em 15/11/2026. A porta fechada não é mais sólida.

### D09 — Recarga do giro com barra e som
- **Autor:** Victor (retorno do primeiro teste, 15/11/2026).
- **Decisão:** depois de cada giro, girar de novo fica bloqueado por um período curto. Uma barra branca no canto inferior direito enche durante a recarga, com um som que fica mais agudo até o giro voltar.
- **Valores atuais (Claude):** 16 quadros de animação + 36 de espera = 52 quadros (0,87 s). Apertar até 6 quadros antes do fim ainda vale. Um "plim" toca quando fica pronto.
- **Efeito colateral bom:** antes era possível dar dois giros seguidos e passar por uma orientação perigosa sem a caixa cair. Com a recarga, a caixa sempre tem tempo de cair, então o sentido do giro passa a importar de verdade (sala 3).

### D10 — Velocidade zera ao fim do giro
- **Autor:** Claude.
- **Decisão:** coelho e caixas partem do repouso depois de girar.
- **Motivo:** previsível. Preservar o momento fica como expansão.

### D11 — Sem dano de queda; morte só por espinho ou esmagamento
- **Autor:** Claude.

---

## Tecnologia e implementação

### D12 — Godot 4 com GDScript
- **Autor:** Claude (recomendação), aceita por Victor.
- **Motivo:** pixel-perfect nativo, arquivos em texto, gratuito, exporta para várias plataformas.
- **Descartado:** Unity (pesado), MonoGame/FNA (sem editor), web com TypeScript (pior em controle e distribuição), GameMaker (pago).

### D13 — A sala gira nos dados, não na câmera
- **Autor:** Claude. Substitui o plano original (girar câmera e vetor de gravidade).
- **Decisão:** ao girar, tiles, caixas, coelho, porta, compartimentos e espinhos são rotacionados 90° de verdade em aritmética inteira. Só o desenho anima o giro.
- **Motivo:** a física roda sempre com gravidade para baixo e nunca precisa saber de orientação. Sem erro de arredondamento.
- **Consequência:** a hitbox do coelho tem de ser quadrada (12×12) para não mudar de forma ao girar. Salas não quadradas trocam largura por altura ao girar (ver D20).

### D14 — Física própria em pixels inteiros, sem `CharacterBody2D`
- **Autor:** Claude. Substitui o plano original.
- **Decisão:** posições inteiras, movimento pixel a pixel, colisão por retângulos, como Celeste.
- **Motivo:** determinístico, sem tremor de subpixel, e o empurrar de caixas fica sob controle total.

### D15 — Salas em texto (`levels.gd`), não em cenas
- **Autor:** Claude.
- **Decisão:** cada sala é uma grade de caracteres. O campo `start_rot` permite desenhar a sala na orientação em que é resolvida e começar girada.
- **Motivo:** editável e revisável como código; os testes carregam qualquer sala sem abrir o editor.
- **Em aberto:** se as salas ficarem grandes ou cheias de elementos, vale reconsiderar um editor (TileMap do Godot ou LDtk). *(Resolvido: editor próprio, D61; a campanha virou dados, D71.)*

### D16 — Regras das caixas
- **Autor:** Claude.
- Só a faixa central da base apoia a caixa: ela cai no buraco quando o centro passa da borda, e é alinhada sozinha (até 4 px). Sem isso, um buraco do tamanho exato da caixa exigiria precisão de pixel.
- Espinhos não são sólidos para caixas.
- Caixa só conta como encaixada se estiver parada e a até 3 px do centro do compartimento.

### D17 — Entrada registrada em código
- **Autor:** Claude.
- **Motivo:** evita editar à mão o formato serializado de `project.godot`.

### D18 — Testes com bots
- **Autor:** Claude.
- **Decisão:** `tests/run_tests.gd` roda sem janela e resolve cada sala com uma sequência de entradas.
- **Motivo:** garante que toda sala tem solução depois de qualquer mudança na física. Não mede se a sala é divertida.

---

## Ajustes depois do primeiro teste (15/11/2026)

### D19 — Pulo no modelo de Celeste
- **Autor:** Victor pediu ("ainda meio duro"); Claude escolheu o modelo.
- **Antes:** impulso único de 232 px/s, gravidade 950, corte brusco ao soltar. Subida em 0,24 s.
- **Agora:** velocidade de subida de 110 px/s mantida por até 12 quadros enquanto o botão está apertado, gravidade 900, metade da gravidade perto do ápice, queda máxima de 160 px/s. Pulo longo de 30 px, curto de 8 px, cerca de 0,7 s no ar.
- **Motivo:** mais tempo no ar e ápice mais longo dão a sensação macia. A escala do jogo (tiles de 8 px, 320×180) é a mesma de Celeste, então os números de lá servem de ponto de partida.
- **Também:** poeira ao pular e pousar; squash proporcional à força do pouso; caixas caem na mesma velocidade máxima do coelho (160).

### D20 — Sprite do coelho: orelhas maiores, corpo menor, animado
- **Autor:** Victor pediu; Claude desenhou.
- **Decisão:** sprite de 12×16 montado por partes (orelhas, corpo, pés) em `room.gd`. Quadros: parado (com piscada e orelha mexendo), corrida em dois tempos, subindo (orelhas para trás), caindo (orelhas para cima).
- **Nota:** é arte provisória desenhada em código. A hitbox continua 12×12; as orelhas passam 4 px acima dela.

### D21 — Porta aberta é um vão, com animação de entrada
- **Autor:** Victor pediu; Claude desenhou.
- **Decisão:** a porta aberta deixa de ser um bloco amarelo: moldura amarela, interior escuro, luz pulsando e faíscas subindo. Ao tocar, o coelho é puxado para dentro encolhendo, há um clarão e faíscas, e a porta se fecha em uma linha antes da transição (44 quadros).

### D22 — Salas de tamanho variado
- **Autor:** Victor (15/11/2026): as salas estão monótonas e não precisam ser 1:1.
- **Estado:** direção aceita, implementação pendente. O código hoje assume grade 20×20. Detalhado em D23 a D26.

---

## Segunda rodada de ajustes (15/11/2026)

### D27 — Pulo e morte ganham som e efeito, como a recarga do giro
- **Autor:** Victor pediu; Claude desenhou.
- **Pulo:** som de varredura curta de grave para agudo (330 a 760 Hz, 0,14 s), com variação aleatória de altura a cada pulo para não cansar; poeira e um anel que se expande nos pés.
- **Morte:** som de varredura descendente (520 a 70 Hz, 0,38 s) com estalo de ruído; anel branco, explosão de partículas, tremor de tela de 4 px que decai e clarão branco sobre a sala.
- **Como funciona:** a sala emite o sinal `sfx("jump" | "death")` e `main.gd` toca o som. Assim a sala continua testável sem áudio.
- **Sons gerados em código**, como os da recarga; nenhum arquivo de áudio ainda. A troca por sons finais é do M5.

### D28 — Animação segue o movimento real, não a velocidade
- **Autor:** Claude, ao corrigir um bug relatado por Victor.
- **Bug:** andando contra a parede, o sprite piscava a cada quadro. A causa: a velocidade subia no quadro (acima do limiar de "correndo") e era zerada pela colisão no mesmo quadro, então a animação alternava entre corrida e parado.
- **Correção:** o quadro é escolhido pelos pixels realmente andados, com 5 quadros de tolerância (`run_t`, `push_t`). Contra a parede o coelho fica parado.

### D29 — Animação de empurrar
- **Autor:** Victor pediu; Claude desenhou.
- **Decisão:** ao empurrar uma caixa, o coelho joga as orelhas para trás, abre as pernas em dois quadros de passo lento, inclina o corpo para a frente (1 px e leve achatamento) e levanta uma poeirinha atrás.
- **Só vale** quando a caixa realmente se move: contra uma caixa travada o coelho fica parado.

### D30 — Efeito de entrada no portal
- **Autor:** Victor pediu; Claude desenhou.
- **Som:** o primeiro som era um arpejo ascendente, e foi **substituído** por D33. O que segue vale para a parte visual.
- **Visual** (soma-se à animação de D21, de 44 quadros): três ondas de luz que saem da porta, uma a cada 8 quadros; 26 faíscas em todas as direções e 10 subindo; feixe de luz vertical da porta até o teto, que cresce e some; véu dourado sobre a sala no fim; tremor leve de 1,5 px na entrada.
- **Ligação:** a sala emite `sfx("win")`; `main.gd` toca. *(O feixe atravessava a borda da sala; foi cortado em D36.)*

---

## Salas longas: implementação (15/11/2026)

### D37 — Etapas bloqueadas por comportas
- **Autor:** Victor escolheu entre três opções propostas por Claude (comporta, porta-portal, sem bloqueio). Substitui as "portas intermediárias" de D25, que não funcionariam depois de D34 (a porta não é sólida).
- **Decisão:** comporta é um trecho de parede ligado a um ou mais compartimentos. Fechada, é sólida para o coelho e as caixas. Abre enquanto todos os seus compartimentos têm caixa parada e volta a fechar se a caixa sair.
- **Nunca esmaga:** se deveria fechar com o coelho ou uma caixa dentro, espera o caminho ficar livre. *(Decisão de Claude: segue o espírito de D34, de a porta nunca prender ninguém.)*
- **Formato:** tiles `1`–`9`; o compartimento que abre a comporta `n` é um bloco 2×2 da letra correspondente (`a` abre `1`, `b` abre `2`...). `S` continua sendo o compartimento da porta.
- **Visual e som (Claude):** bloco escuro com barras verde-água, que encolhem ao abrir; os compartimentos de comporta têm a moldura na mesma cor. Som de deslizar mecânico com batida no fim, diferente ao abrir e ao fechar.
- **Consequência boa:** a regra de "a caixa só fica pela gravidade" passa a valer no meio da sala também. Se um giro derrama a caixa de uma comporta, ela fecha (sala 3).

### D38 — Plataformas por orientação: sólidas só com a seta para cima
- **Autor:** Claude definiu a regra; o elemento foi aprovado em D25.
- **Decisão:** tile com uma seta. Só é sólido quando a seta aponta para cima na tela. A seta gira com a sala, como os espinhos. Fora disso, é desenhado tracejado e é atravessável.
- **Formato:** `=` seta para cima, `}` para a direita, `_` para baixo, `{` para a esquerda.
- **Nunca esmaga:** igual à comporta, só vira sólido quando está livre.
- **Visual e som:** sólido é lilás com a borda de cima clara; atravessável é contorno tracejado com a seta. "Tic" de vidro ao mudar.
- **Como as salas usam:** uma coluna de plataformas que, girada, vira ponte (sala 2); pousos que só existem depois do giro, na frente de espinhos (sala 4); uma escadaria que só existe na orientação normal e por isso não atrapalha os voos girados (sala 5).
- **Ponto aprendido ao desenhar:** uma plataforma não pode "sumir debaixo de uma caixa" e fazê-la cair na mesma gravidade, porque ela só deixa de ser sólida quando a sala gira, e aí a gravidade já é outra. O uso natural é como ponte, pouso ou parede que aparece e some com o giro.

### D39 — Salas de qualquer tamanho e câmera
- **Autor:** Claude, seguindo D22 e D23.
- **Tamanho:** a sala é lida das linhas de texto (largura e altura livres). A cada giro, largura e altura trocam: girar uma sala larga a transforma em um poço.
- **Câmera:** fica centralizada no eixo em que a sala cabe na tela (320×180); no outro, segue o coelho com suavização (`CAM_SMOOTH` = 0,12 por quadro) e para nas bordas da sala. Ao reiniciar, vai direto ao coelho.
- **Câmera no giro:** a câmera é rotacionada junto com a sala, e o desenho gira em volta do centro da tela. Assim o primeiro quadro da animação é idêntico ao último antes do giro, sem salto. Depois do giro, a câmera desliza até o coelho.
- **Desempenho:** fora da animação de giro, só as paredes visíveis são desenhadas.

### D40 — Testes de mecânica com salas próprias
- **Autor:** Claude.
- **Decisão:** os testes de mecânica (pulo, animação, sons, impacto, porta, câmera, comporta, plataforma, recarga) usam salas de teste definidas no próprio arquivo de testes, não as salas do jogo.
- **Motivo:** ao redesenhar as salas, metade dos testes quebrou só porque dependia do desenho antigo. Agora redesenhar uma sala só afeta o bot dela.

### D41 — As 5 salas longas
- **Autor:** Claude desenhou, a partir do plano aprovado por Victor (D24 a D26). Descritas no GDD, seção 6.
- **Método:** cada sala reaproveita mecânicas já provadas nas salas antigas (o puzzle do esboço, o nicho e a virada de 180°, a travessia pelo ar) e as encadeia com comportas, trechos de pulo e plataformas por orientação. Cada uma tem um bot que a resolve.
- **Cuidado de desenho registrado:** cada giro afeta a sala inteira. Uma caixa de uma etapa tem de estar segura (num buraco ou nicho) em todas as orientações que as etapas seguintes usam, ou o giro estraga o que já foi resolvido.
- **Ajustes feitos por causa dos bots:** na sala 1, o trecho depois dos espinhos ficou com 4 tiles (com 2, o coelho caía em cima da caixa); na sala 3, a segunda caixa foi afastada da descida (o coelho caía em cima dela); na sala 5, a escadaria foi refeita em três colunas (em zigue-zague de duas, o coelho ficava preso embaixo de um degrau) e os espinhos finais foram afastados um tile.
- **Desvio do plano:** a sala 5 tem uma comporta e um compartimento na saída, não duas e dois.
- **Pendente:** tudo isso foi validado por bots e capturas, não por alguém jogando. Dificuldade, ritmo e clareza de cada sala dependem do teste de Victor.

### D42 — 10 níveis, uma ideia nova por vez
- **Autor:** Victor pediu (15/11/2026): as salas 1 e 2 estavam bem mais difíceis que a 3; passar para 10 níveis com complexidade crescente, e o primeiro bem mais simples. Claude montou a sequência. Substitui D24.
- **Regra da curva:** cada nível apresenta uma ideia nova (em sala pequena e sem distrações), e os seguintes a combinam com as anteriores. A ordem das ideias: caixa no buraco → pular → comporta e espinhos → combinação → girar → nichos e sentido do giro → plataformas por orientação → combinação → girar no ar → síntese.
- **Reaproveitamento:** as 5 salas da versão anterior foram mantidas sem mudança e reposicionadas: Toca (4), Derrame (6), Vertigem (8), Espinhos (9), Fuga (10). Vertigem, que era a 2ª, virou a 8ª: ela pede giro, um truque de posicionamento e plataformas, e estava cedo demais.
- **Salas novas (Claude):** Primeiros passos (1), Degraus (2), Comporta (3), Giro (5), Setas (7). Cada uma é pequena e tem um só ponto a aprender. Em "Giro", a porta fica deitada na parede, inalcançável, para que girar seja a resposta óbvia. Em "Setas", reaproveita a virada de Derrame, já conhecida, para que a única novidade seja a ponte.
- **Formato:** em `levels.gd`, cada sala é uma constante com nome, e `ROOMS` é só a lista na ordem dos níveis. Os bots procuram a sala pelo nome, então mudar a ordem não quebra os testes.
- **A conferir no teste:** os níveis 1 a 4 não têm giro, e a mecânica principal só aparece no 5. Se a espera parecer longa, a alternativa é trazer "Giro" para antes de "Toca".

### D43 — Dicas de texto nos níveis que apresentam controles
- **Autor:** Victor pediu (15/11/2026) texto sobre os movimentos no nível 1 e sobre o giro na sala do giro. Claude escreveu os textos e definiu onde aparecem.
- **Decisão:** cada sala pode ter um campo `hint`. O texto aparece centralizado na parte de baixo da tela, surgindo aos poucos ao entrar na sala, e fica visível enquanto o jogador está nela.
- **Textos:**
  - Nível 1 (Primeiros passos): "Ande com A/D ou as setas · Pule com W, seta para cima ou Espaço" e "Empurre a caixa até o buraco para abrir a porta".
  - Nível 5 (Giro): "Q e E giram a sala (no controle, LB e RB)" e "Tudo o que está solto cai para o novo chão".
- **Posição:** embaixo, porque no topo a primeira linha do nível 1 encostava no título "1 · Primeiros passos".
- **Fonte:** a fonte padrão do Godot, em tamanho 8. Fica legível, mas destoa do pixel art; uma fonte pixelada é trabalho do M5.

### D44 — Trilha sonora
- **Autor:** Victor compôs a primeira faixa, `music/first-levels-theme.mp3` (39,6 s, feita para repetir em loop). Claude a ligou ao jogo.
- **Como toca:** um tocador de música separado dos efeitos, em `main.gd`. Entra com fade de 1,5 s. Se a sala seguinte usa a mesma faixa, ela continua sem reiniciar; se usa outra, a atual some em 0,8 s e a nova entra.
- **Qual faixa:** cada sala pode ter um campo `music`; sem ele, toca `DEFAULT_MUSIC` (em `levels.gd`). Por enquanto, como há uma faixa só, ela toca em **todos os 10 níveis**, embora o nome indique os primeiros. Quando houver outras, basta pôr `music` nas salas a partir de onde a faixa nova começa.
- **Loop:** ligado na importação do Godot (`loop=true` em `first-levels-theme.mp3.import`) e reforçado no código.
- **Volume:** −9 dB (`MUSIC_DB`), abaixo dos efeitos, para pulo, giro e caixa continuarem audíveis. Valor de partida; ajustar ouvindo.
- **Observação sobre MP3:** o formato pode deixar um pequeno silêncio no ponto de repetição. Se for audível, exportar a faixa em OGG Vorbis resolve.
- **Na versão web:** o navegador só libera o som depois do primeiro clique ou tecla; a música começa aí.

### D46 — Nome do jogo, tela de início e cutscene de abertura
- **Autor:** Victor, com o esboço `start-screen.jpeg` (6 quadros) e a descrição. Claude implementou e tomou as decisões de detalhe abaixo.
- **Nome:** o jogo se chama **Free** (título da tela de início; também é o nome do projeto no Godot).
- **Tela de início:** fundo preto, "FREE" em letras brancas de blocos, "PRESS ENTER" piscando, e uma janela com o coelho num campo colorido e ensolarado (céu, sol, nuvens, colinas, árvores, flores). É o único lugar colorido do jogo, em contraste com as salas.
- **Cutscene (10,3 s), ao apertar Enter:**
  1. O texto some; abre-se um buraco sob o coelho; ele dá um sobressalto, aparece um "!" e ele olha para baixo.
  2. Ele cai no buraco e some; a janela fica vazia e depois some em fade.
  3. Corte: o coelho cai girando no vazio preto, com riscos de velocidade.
  4. Ele pousa numa pequena plataforma branca, com impacto.
  5. A plataforma se alonga, sobe pelos lados e fecha em cima, formando um quadrado; a porta surge.
- **Decisões de Claude:**
  - O quadrado final é uma **sala jogável** (`Levels.START`): o jogador anda até a porta, já aberta, para começar o nível 1. A cutscene desenha o quadrado e a porta exatamente onde a sala fica, para a troca não dar salto (há teste).
  - Apertar Enter de novo durante a cutscene **pula** direto para essa sala.
  - Enter, Espaço, Start ou A (controle) começam.
  - Depois da tela final do jogo, volta-se à tela de início.
  - Novo campo de sala `door_open`: porta sempre aberta, sem compartimento.
- **Som (pedido de Victor: só efeitos; a música da abertura ele fará depois):** a abertura e a sala de início não têm música; a trilha atual começa no nível 1. Efeitos, reaproveitando os que existem: baque quando o chão cede, som de pulo no sobressalto, baque forte no pouso, bipe do sensor quando a porta surge.
- **Tudo desenhado em código** (`scripts/intro.gd`), como o resto do jogo. Arte final é do M5.
- **Pendente:** música da abertura (Victor); talvez um som próprio para a queda no vazio.

### D45 — Distribuição para testes: web no itch.io e .exe
- **Autor:** Victor pediu um jeito de os amigos testarem; Claude recomendou e configurou.
- **Web (principal):** exportação HTML5 **sem threads** (`variant/thread_support=false`), que roda no itch.io sem precisar de configuração especial do servidor. Publicar como página **restrita** ou rascunho com link secreto.
- **Windows (alternativa):** `.exe` com os dados embutidos (um arquivo só). Não é assinado, então o Windows mostra um aviso na primeira execução.
- **Fora da exportação:** `concept.png`, `tests/` e `docs/`.
- **Pasta `build/`:** saída da exportação, com um `.gdignore` para o Godot não tratar os arquivos gerados como parte do projeto. Pode ser apagada e gerada de novo.
- **Templates de exportação:** Godot 4.7.2 oficiais, baixados do GitHub do Godot e instalados em `%APPDATA%\Godot\export_templates\4.7.2.stable`. O arquivo baixado (1,28 GB) ficou em `Downloads\godot-templates-4.7.2` e pode ser apagado.
- **Passo a passo:** [COMPARTILHAR.md](COMPARTILHAR.md).

### D31 — Pouso forte da caixa: efeito e solavanco na direção da gravidade
- **Autor:** Victor pediu; Claude desenhou.
- **Quando:** a caixa toca o chão depois de cair. Vale para qualquer queda, não só depois de girar. *(O critério original era a velocidade da queda; foi trocado por distância em D35.)*
- **Efeito:** poeira nos dois lados da base (mais poeira quanto mais forte o impacto), um anel azul e um baque grave curto com ruído, com altura levemente variável.
- **Solavanco:** a sala inteira desce na tela e volta, oscilando e amortecendo. A amplitude depende da força do impacto (D35). O deslocamento é em pixels inteiros e sempre para baixo da tela, que é a direção da gravidade, porque a simulação nunca roda com a sala girada.
- **Não confundir** com o tremor aleatório da morte (D27), que é outro mecanismo.
- **Não pedido:** o pouso do coelho continua só com poeira e squash.

**Revisado por D35:** o impacto agora cresce com a altura e com o número de caixas. O limiar por velocidade de queda (70 px/s) foi trocado por distância de queda.

### D35 — Impacto da caixa proporcional à altura e à quantidade
- **Autor:** Victor pediu ("quanto mais caixas, e mais altura, mais impacto"); Claude implementou.
- **Problema anterior:** a força vinha da velocidade da queda, que chega ao máximo depois de cerca de 14 px. Uma queda de 100 px batia igual a uma de 20.
- **Altura:** cada caixa conta os pixels da queda (`fall_dist`). Força própria `e` vai de 0 a 1, chegando a 1 com 128 px. Quedas menores que 8 px não geram efeito.
- **Quantidade:** pousos em sequência se somam. Cada pouso soma a própria força a 60% da força recente (que decai 10% por quadro, cerca de 20 quadros até sumir). Duas caixas caindo juntas dão perto de 1,6 vezes a força de uma; o teto é 2,5.
- **O que escala com a força `s`:**
  - solavanco da sala: `0,6 + 2,4·s` px (de cerca de 0,7 a 6,6 px);
  - poeira: `4 + 8·s` partículas, mais rápidas e mais altas;
  - anel azul maior e mais duradouro;
  - acima de `s = 1`: segundo anel, lascas azuis da caixa saltando e um tremor aleatório leve além do solavanco;
  - som: mais alto e mais grave; acima de 1,3, um segundo baque sobreposto, uma oitava abaixo.
- **Como sai da sala:** sinal `impact(strength)`, no lugar do antigo `sfx("thud")`.
- **Ponto de atenção:** o solavanco vai de bem leve (queda curta) a forte (várias caixas de muito alto). Se o forte incomodar, o teto é `0,6 + 2,4·s` em `_box_impact`.

### D36 — A porta nunca é desenhada por cima das paredes
- **Autor:** Victor relatou o defeito; Claude corrigiu.
- **Problema:** o brilho da porta aberta, a moldura translúcida da porta fechada e o feixe de luz da vitória eram desenhados depois das paredes e pintavam por cima da linha branca da borda.
- **Correção:** a ordem de desenho passou a ser fundo, compartimentos, porta e feixe, e só então as paredes. Qualquer excesso da porta fica coberto pela parede e pela linha de borda.
- **Regra para elementos novos:** brilhos e feixes de luz entram antes das paredes. Só coisas que precisam passar por cima de tudo (partículas, véus de tela inteira, o coelho) ficam depois.
- **Revisa D30:** o feixe da vitória não atravessa mais o teto; é cortado pela parede.
- **Não coberto:** as faíscas da vitória são partículas e ainda podem cruzar uma parede por um instante, porque saem em todas as direções. Se incomodar, dá para limitá-las ao espaço livre.

### D32 — Efeito de sensor ao encaixar a caixa
- **Autor:** Victor pediu um efeito minimalista, "como um sensor ativando"; Claude desenhou.
- **Visual:** um contorno fino em volta do compartimento que se expande e some, e uma linha de varredura que cruza o compartimento de cima para baixo (16 quadros). Ao tirar a caixa, a linha cruza para cima e o contorno é cinza, em vez de dourado.
- **Som:** dois bipes secos de onda quadrada suavizada; sobem ao ativar (880 e 1320 Hz) e descem ao desativar (1180 e 700 Hz). O volume é baixo de propósito.
- **Só dispara** com a sala em jogo e quando o estado do compartimento muda, nunca ao carregar a sala.

### D33 — Som do portal: distorcido, sem melodia
- **Autor:** Victor pediu "algo mais distorcido, não uma música de sucesso"; Claude desenhou. Substitui o arpejo de D30.
- **Som (0,85 s):** varredura grave que sobe de 70 Hz a cerca de 1,3 kHz com modulação de frequência; ruído filtrado com tremolo que acelera, como algo girando; distorção forte e quantização grosseira (som "sujo"); termina em um golpe grave no momento em que a porta se fecha.
- **A resolver ouvindo:** se o resultado soa como portal ou como ruído. Os parâmetros estão em `_make_win_sound` (`main.gd`) e mudam bastante o caráter.

### D34 — A porta fechada não é sólida
- **Autor:** Victor. Substitui D08.
- **Decisão:** a porta nunca bloqueia nada, nem o coelho nem as caixas. Fechada, só deixa de funcionar: encostar nela não faz nada. Só a porta aberta conclui a sala.
- **Visual:** como deixou de ser parede, a porta fechada passou a ser translúcida, com contorno fino, para não parecer um bloco.
- **Consequências no código:** `solid_static` considera só as paredes; some a regra que matava o coelho se a porta fechasse sobre ele (agora não há como ser esmagado).
- **Consequências no design:** a porta não serve mais de parede nem de plataforma, e o coelho pode ficar dentro dela enquanto está fechada. Nenhuma das 5 salas atuais dependia disso. Nas salas redesenhadas, trancar uma passagem terá de ser feito com parede. Para as portas intermediárias (D25), isso significa que a porta fechada não segura ninguém: se uma etapa tiver de ser bloqueada, a passagem precisa de outra solução.

---

## Corda, água e ralo (15/11/2026)

### D47 — Corda como pêndulo
- **Autor:** Victor (a mecânica e o esboço `componente-corda.jpeg`); Claude propôs a forma de implementar e os detalhes, que Victor não contestou.
- **Decisão:** a corda só é ativa pendendo do teto; fora disso é desenho. Pendurado, o coelho é um pêndulo de raio fixo em torno da âncora. O giro da sala gira âncora e coelho, a corda fica horizontal e a gravidade faz o arco: a "propulsão" não é um impulso inventado, é a energia da queda.
- **Detalhes (padrões de Claude):** agarrar é automático no ar; pulo solta em qualquer ponto do arco; bater em parede solta; pendurado antes do giro o coelho fica parado; o giro pendurado é livre e respeita a recarga; espinhos matam no arco; cada corda tem seu comprimento, desenhado na sala.
- **Descartado:** impulso fixo ao girar (previsível, mas sem balanço nem controle pelo momento de soltar); corda de segmentos com física (instável para puzzles e bots).
- **Consequência física a lembrar ao desenhar salas:** o coelho nunca sobe acima da altura em que o arco começou. Uma âncora numa parede lisa faz o arco terminar batendo nessa mesma parede; para o coelho passar do ponto mais baixo e subir do outro lado, a âncora precisa estar na ponta de uma saliência.

### D48 — Água em grade de células, com nivelamento por corpo d'água
- **Autor:** Victor (a mecânica e o esboço `water-mechanics.png`); Claude escolheu a implementação.
- **Decisão:** células de 4 px que caem e escorrem, mais um passo de nivelamento por corpo d'água ligado.
- **Motivo do nivelamento:** só com a regra de cair e escorrer, a água formava um monte inclinado como areia e alimentava o ralo a menos de 10 células por segundo. O nivelamento a deixa plana em menos de um segundo e ainda dá vasos comunicantes.
- **Descartado:** calcular só o nível final de cada poça (a água "teleportaria" depois do giro).
- **Respostas do Victor:** o ralo fica sempre ligado e a água chega nele depois do giro (um jeito de ativá-lo pode vir depois); a água engolida volta ao reiniciar; o coelho boia e pula a partir da superfície; a água nunca mata; a caixa afunda mais devagar; a porta alagada soma-se à regra dos compartimentos; espinhos submersos matam.
- **Limite conhecido:** coelho e caixas não deslocam a água.

### D49 — A porta alagada demora meio segundo para destravar
- **Autor:** Claude, ao testar a sala Água.
- **Problema:** parado dentro da porta alagada, bastava girar a sala. A água caía, a porta abria no quadro seguinte e o coelho, que ainda estava em cima dela, vencia sem usar o ralo.
- **Decisão:** a porta só destrava depois de 30 quadros com menos de 30% de água.

### D51 — Água por colunas, com ondas; corda com física; subir e descer *(substitui a implementação de D48 e ajusta D47)*
- **Autor:** Victor, depois de jogar: a água em células de 4 px ficava irregular e, com pouca água, viam-se bloquinhos andando sozinhos; a corda "se transportava" de uma posição para outra depois do giro; o coelho devia poder subir e descer.
- **Água:** modelo de colunas de 1 px com altura fracionária, nivelamento por trocas entre colunas em várias distâncias, e uma camada de ondas só de desenho (ver ARQUITETURA).
- **Tentado e descartado:** vazão com inércia entre colunas (o modelo clássico de "canos"). Com um paredão de água ao lado de colunas secas, que é o que acontece depois de cada giro, a conta ficava caótica; limitada para ficar estável, a água escorria como mel.
- **Corda:** a forma passa a ser simulada (Verlet). Como ela agora balança depois do giro, só agarra quem **pulou**: sem isso, o coelho caindo depois do giro era fisgado pela corda no meio do caminho.
- **Subir e descer:** W/S ou setas. Por isso, na corda, W e a seta para cima deixam de ser pulo; quem solta é Espaço, K ou A.
- **Limite:** presa no chão, a corda desaba num montinho pequeno, pouco visível.

### D52 — Na corda só se desce; dá para agarrar a corda durante um giro no ar
- **Autor:** Victor.
- **Decisão:** não dá para subir pela corda, só descer (S ou seta para baixo). A tecla de cima continua sendo pulo, e o pulo solta a corda. Isso desfaz a parte de D51 que trocava W e seta para cima por "subir" e criava uma ação separada para soltar.
- **Agarrar durante o giro:** quem pula e gira a sala no ar pode agarrar a corda que o giro acabou de pôr no teto. Quem gira do chão continua passando pela corda ao cair (interpretação de Claude: o agarrão vem de um pulo, como em D51; falta o Victor confirmar).

### D53 — Ato introdutório de 20 fases; sem texto por cima das fases
- **Autor:** Victor pediu a proposta e aprovou; disse que as 20 fases são só o ato introdutório do jogo, pediu mais capricho nas partes de plataforma, e que não haja texto por cima das fases além das instruções necessárias. Claude desenhou as fases.
- **Texto:** o título no canto ("11 · Corda") foi removido. As dicas restantes foram reduzidas depois, em D54.
- **Fluxo:** cinco blocos (o básico; girar com intenção; corda; água; tudo junto). Cada bloco apresenta um elemento numa fase curta e depois o usa. O giro subiu da fase 5 para a 3; o giro no ar ganhou uma fase própria e sem perigo (Salto no vazio) antes de Espinhos.
- **Estado:** 19 das 20 estão feitas, cada uma com bot. Fases novas: Salto no vazio, Prumo, Laço, Maré, Represa, Naufrágio, Mergulho; Toca foi refeita como fase de plataforma. **Faltam:** a fase 20 (Livre), refazer Vertigem com uma corda e ajustar Fuga com corda e água; as duas últimas continuam como eram.
- **Decisões de desenho que valem lembrar:**
  - *Salto no vazio:* a diferença entre girar do chão e no ar é a distância até a parede que vira lateral; um vão de 2 tiles junto a ela separa os dois casos.
  - *Prumo e Laço:* a porta fica onde o arco de raio máximo passa, então "descer até a ponta" é a regra, sem precisar de marcação.
  - *Represa:* o ralo fica na câmara seca, senão esvaziaria o reservatório antes de a comporta abrir; um degrau no canto impede a caixa de ficar presa contra a parede.
  - *Mergulho:* quase todo arco termina na parede oposta, então o poço fundo fica ao pé dela.
- **Ajuste na água:** as trocas a distância passaram a alcançar 128 px, com 3 subpassos. Em salas largas com ralo (Represa), a superfície ficava inclinada uns 20 px em direção a ele.

### D54 — Só há texto para os controles básicos
- **Autor:** Victor: "quero que o player descubra as mecânicas".
- **Decisão:** as dicas de tela só ensinam andar, pular e girar (fases 1, 3 e a sala de início). Foram removidas as dicas da corda, de descer pela corda, da água e do giro no ar, e as frases que explicavam as regras (empurrar a caixa, "tudo o que está solto cai").

### D55 — Número do nível no canto, só em desenvolvimento
- **Autor:** Victor, para saber em que nível está ao testar.
- **Decisão:** o número do nível (só o número) aparece no canto superior esquerdo quando `OS.is_debug_build()` é verdadeiro (rodando pelo editor ou por `run.ps1`). Nas versões exportadas, que são de release, não aparece. A sala de início não tem número.

### D56 — A recarga do giro passa a ser de 5 s
- **Autor:** Victor ("aumente o tempo do flip para 5s"), para todas as fases.
- **Decisão:** `ROT_COOLDOWN` de 36 para 284 quadros; com a animação, 300 (5 s). Substitui os 0,87 s de D09. A barra e o som de carga acompanham sozinhos.
- **Consequência:** as fases com dois giros pedem pelo menos 5 s entre eles, e o coelho tem de esperar ou fazer outra coisa nesse tempo. Os testes esperam até 400 quadros pela recarga.

### D57 — Limitador
- **Autor:** Victor, nome e regra; Claude, os detalhes.
- **Regra:** em salas com `limiter: true`, o giro feito pelo jogador é desfeito sozinho quando a recarga de 5 s termina. Uma barra vermelha paralela à branca mostra o tempo que falta. Ao desfazer, toca um som distorcido.
- **Detalhes de Claude:** o saldo de giros é contado a partir do estado inicial da sala (o `start_rot` não conta); o giro desfeito reinicia a recarga; um giro pedido nos últimos quadros é descartado.
- **Uso:** só na Maré (fase 13).

### D58 — Ajustes de fases pedidos por Victor (15/11/2026)
- **Comporta (4) e Toca (6):** passam a permitir o giro, com espinhos no teto e logo acima da porta: girar do chão é cair neles.
- **Salto no vazio (8):** a plataforma ao lado da porta foi retirada, a porta virou 1:1 (2×2 tiles) e flutua, e há espinhos nas paredes da esquerda, da direita e no teto. Só se acerta a porta girando no ar perto do ápice do pulo.
- **Corda e Laço (10 e 12):** removidas. O Prumo (agora 10) é a primeira fase da corda.
- **Prumo:** espinhos também em cima e à direita, plataforma flutuante retirada, e o coelho começa em pé na parede que era a da esquerda (`start_rot` −1). A corda está deitada; é preciso pular, girar no ar e agarrá-la enquanto cai.
- **Maré (13):** ganha o limitador; metade das plataformas sai (as de baixo); a água sobe até a primeira que sobrou. A solução cabe em 2,8 s dos 5.
- **Mergulho (16):** a porta ganha um compartimento e o coelho começa num palco com a caixa, antes da corda.

### D59 — Represa e Naufrágio refeitas
- **Autor:** Victor: não havia desafio, só esperar a água escoar; manter o giro. Claude redesenhou.
- **Princípio:** nada de ralo para esperar. A água é movida pelo giro: quem a derrama é o coelho.
- **Represa (14):** a porta está no fundo de uma cuia alagada. Girar no sentido horário derrama a água, que corre para a parede da direita; voltar a faz cair na cuia da direita, e a porta fica seca. O fundo da cuia da porta tem espinhos.
- **Naufrágio (15):** duas caixas têm de ir para compartimentos do outro lado de um poço de espinhos cheio d'água. Empurrá-las é perdê-las. Girando no sentido horário, o coelho e as caixas caem rente à parede, passam do poço e se empilham; ao voltar, as caixas caem nos compartimentos. A porta fica do lado de lá, e a volta é a nado.
- **Detalhe que custou caro:** a água que cai nos compartimentos fica lá, então o poço perde uns 10% e quem cai nele afunda uns 20 px abaixo da superfície; por isso o fundo do poço é fundo e há um degrau para sair.

### D60 — Recarga e limitador de 2,5 s; sem Salto no vazio; limitador na Fuga; espinhos sobre plataforma
- **Autor:** Victor.
- **Tempo:** `ROT_COOLDOWN` de 284 para 134 quadros; com a animação, 150 (2,5 s). Vale para a recarga e para o limitador (substitui D56 e o tempo de D57).
- **Salto no vazio:** removida. As fases passam a ser 16 (a Fuga é a 16).
- **Maré:** a água sobe em 1,1 s, então só cabem duas plataformas e a sala é mais baixa (25 linhas, porta no alto, à esquerda, sobre a segunda plataforma). O bot resolve em 1,7 s dos 2,5.
- **Fuga:** ganha o limitador, e a etapa de cima foi refeita porque um giro de 180° (a caixa jogada no teto) é impossível com o giro desfeito sozinho a cada 2,5 s. Agora a porta está na parede da direita, alta demais; o coelho vai até o pé dela e gira no sentido horário: a parede vira chão por 2,5 s e ele sobe por ela, pulando espinhos, até a porta (0,9 s no bot). A segunda caixa e o compartimento do teto saíram. As etapas de baixo continuam, e o limitador faz o papel do giro de volta: a caixa cai no buraco "a" quando o giro é desfeito.
- **Espinhos acima das portas:** estavam como `v` soltos no ar, apontando para a porta. Agora são uma plataforma pequena e suspensa exatamente acima da porta, com espinhos para cima (Comporta, Toca e Fuga). Os espinhos presos ao teto continuam apontando para baixo.

### D61 — Editor de fases dentro do jogo
- **Autor:** Victor ("crie um editor de fases; ele será o core do jogo"). Plano aprovado em 16/11/2026.
- **Decisões:** o editor é parte do jogo, não plugin do Godot; fases em JSON e em código de texto; uma fase só é compartilhável depois de o autor vencê-la; primeira versão já com desfazer, copiar/colar e girar a sala.
- **Escolha de Claude:** a fase do editor é o mesmo dicionário de `levels.gd` (grade de texto + campos), então o editor não tem formato próprio: `room.setup()` lê as duas igual.

### D62 — O editor desenha esquemático e não roda a simulação
- A grade usa ícones simples com as cores do jogo, em vez de instanciar `Room` a cada traço. Motivo: a sala assenta a água e a corda ao carregar (centenas de passos), o que seria lento a cada clique. Para ver de verdade, há o botão Jogar.

### D63 — Verificação por hash
- "Vencer uma vez" guarda o hash do que muda a jogabilidade. Mudar o nome ou a dica não tira a marca; mudar a grade, o giro, o limitador, a rotação inicial ou a porta aberta tira. Desfazer até o estado vencido devolve a marca, porque o hash volta a bater.
- **Limite:** vencer prova que há solução, não que a fase é boa nem que o caminho é o pretendido (pode haver atalho).

### D64 — A janela do editor é 960×540 e a do jogo continua 320×180
- O jogo é pixel art em 320×180 com escala inteira; o editor precisa de texto legível e de mais espaço. Por isso a janela troca o modo de escala ao entrar e ao sair do editor (`canvas_items` e fracionária lá, `viewport` e inteira cá).
- **Campanha editável:** só em build de depuração o editor grava por cima das fases da campanha (`res://levels/campaign/NN.json`); `levels.gd` continua sendo a origem e o que os bots testam. Num build de lançamento, `res://` é só leitura, então as fases do jogador vão para `user://levels`.

### D65 — Comporta inversa
- **Autor:** Victor ("componentes que funcionam ao contrário das comportas: só são ativos quando determinada comporta é ativada; usam a mesma comporta do já presente"). Entra também no editor.
- **Decisão:** a inversa de número N reage ao mesmo compartimento que abre a comporta N e faz o contrário: está aberta com o compartimento vazio e fecha quando ele enche. Não tem compartimento próprio.
- **Símbolo:** `¹ ² ³ ⁴ ⁵ ⁶ ⁷ ⁸ ⁹` (um para cada número). Escolhi os algarismos sobrescritos porque lembram a comporta comum e não colidem com nenhum outro caractere do formato; custa digitar à mão, mas o editor desenha e insere.
- **Aparência:** âmbar com hachura em X (a comum é verde-água com barras), para ninguém confundir as duas.
- **Regras iguais às da comum:** não fecha sobre o coelho nem sobre caixa; sólida só enquanto fechada; segura a água; gira com a sala.
- **No editor:** nove botões na paleta; a validação trata a inversa como uma comporta (erro se o compartimento do número não existe).
- **Ainda sem fase da campanha que a use.**

### D66 — Recarga do giro e tempo do limitador por fase
- **Autor:** Victor ("parametrizar o limite e o timeout do flip no editor").
- **Interpretação de Claude:** "timeout do flip" é a recarga do giro; "limite" é o tempo do limitador (depois do qual o giro é desfeito). Cada um passa a ser um campo da fase (`reload_time`, `limiter_time`, em segundos, de 0,5 a 30), com 2,5 s como padrão, então nada muda nas fases existentes. No editor são dois campos numéricos no painel da fase; o do limitador só vale com o limitador ligado.
- **Valores diferentes:** com o limitador mais curto que a recarga, o giro é desfeito e a recarga cheia recomeça. Com o limitador mais longo, dá para girar de novo antes de ele desfazer (o saldo de giros continua sendo desfeito um por vez); a validação só avisa.
- **Não feito:** um limite de **quantidade** de giros por fase. Se era isso que "limite" queria dizer, é um campo a mais e um contador na tela; me diga.

### D50 — As salas Corda e Água
- **Autor:** Claude, a partir dos dois esboços.
- **Corda:** segue o esboço (porta no meio, espinhos dos dois lados dela, duas cordas, sala começando com as cordas no chão). A sala é larga (36×22) porque só assim uma corda presa perto do canto, agarrada pela ponta, faz um arco que passa pela porta central; em sala quadrada não fecha. O arco chega pela lateral da porta, que é o lado sem espinhos. Sem compartimento (`door_open`).
- **Água:** segue os três quadros do esboço, com uma diferença: o ralo fica num nicho cavado na parede, que vira um poço no chão depois do giro, em vez de numa prateleira com mureta. Com a mureta do esboço, a água parava de escoar ao chegar na altura dela e sobrava demais para destravar a porta. Sem compartimento (`door_open`).
- **Ainda não validado por quem joga:** a sensação do arco, a velocidade da água e do ralo (a sala seca em 12 s; bastam uns 5 s para a porta destravar), e a posição dos dois níveis depois da "Fuga".

## Redesenho das salas (decidido em 15/11/2026, ainda não implementado)

Diagnóstico que motivou estas decisões: as salas atuais são todas uma caixa vazia de 20×20, cada uma se resolve com um ou dois giros, e o coelho quase não usa o pulo.

### D23 — Em salas maiores que a tela, a câmera segue o coelho
- **Autor:** Victor (escolha entre duas opções propostas por Claude).
- **Decisão:** a sala pode passar da tela; a câmera acompanha o coelho.
- **Motivo:** o pixel art mantém o mesmo tamanho em todas as salas.
- **Descartado:** reduzir o zoom para a sala inteira caber na tela.
- **A resolver na implementação:** como a câmera se comporta durante a animação do giro, e o que ela mostra logo depois, quando o coelho cai para longe.

### D24 — O piloto continua com 5 salas, mais longas *(substituída por D42: 10 níveis)*
- **Autor:** Victor.
- **Decisão:** manter 5 salas e alongar cada uma, em vez de subir para 8 a 10 salas curtas.
- **Consequência:** cada sala passa a encadear várias ideias, o que combina com D26.

### D25 — Elementos novos que entram agora: só dois *(as "portas intermediárias" viraram comportas, D37)*
- **Autor:** Claude (recomendação), aceita por Victor.
- **Entram:**
  - **Plataformas por orientação:** só são sólidas em certa orientação da sala.
  - **Portas intermediárias:** portas dentro da mesma sala, que dividem a sala em etapas.
- **Ficam para depois:** botões de peso, segunda cor de caixa, zonas onde o giro é proibido.
- **Motivo:** poucos elementos novos por vez, para dar para testar cada um.
- **A resolver na implementação:** o que abre cada porta intermediária (um compartimento próprio é o caminho mais simples, já que botões e cores de caixa ficaram de fora), e como mostrar na tela em que orientação uma plataforma fica sólida.

### D26 — Diretrizes de desenho das novas salas
- **Autor:** Claude (proposta), aceita por Victor junto com D23 a D25.
- **Tamanhos variados:** corredores largos (por exemplo 40×12), poços altos (12×30) e salas maiores que a tela. Uma sala 40×12 girada vira um poço 12×40, então o próprio giro muda o tipo de desafio.
- **Mais plataforma dentro da sala:** trechos de pulo entre os momentos de puzzle, com espinhos em paredes e tetos que viram chão ao girar.
- **Salas em etapas:** três ou quatro ideias encadeadas por sala, separadas por portas intermediárias.

**Estado (15/11/2026):** D23 a D26 implementadas na rodada 11. O que mudou ao implementar está em D37 a D41.

### Impacto no código (levantado antes de implementar)
- `room.gd` usa `GRID` e `SIZE` como constantes; precisa aceitar largura e altura por sala.
- A rotação de retângulos (`_rot_rect`) e da grade assume sala quadrada; em sala W×H, o giro troca as dimensões.
- O desenho gira em torno do centro da sala; com câmera seguindo o coelho, o centro do giro e o enquadramento precisam ser repensados.
- O formato de `levels.gd` precisa de símbolos para plataformas por orientação e para portas intermediárias com seus compartimentos.
- Os testes de formato (20×20) e os bots de cada sala terão de ser refeitos.

### D61 — Controles de toque: joystick, pulo e dois giros
- **Autor:** Victor (joystick + dois botões de giro); Claude (botão de pulo e layout), aceito por Victor.
- **O quê:** joystick flutuante à esquerda (só o eixo horizontal anda; puxar para baixo desce a corda); à direita, botão grande de pulo com os dois giros logo acima; reiniciar pequeno no canto de cima. Qualquer toque confirma a tela de início.
- **Por que um botão de pulo:** o pulo tem altura variável, buffer e coyote time; "joystick para cima" não dá esse controle.
- **Onde ficam:** celular deitado é mais largo que 16:9. No modo toque a tela do jogo é alargada para o formato do aparelho (até 432×180), a sala continua 320×180 no centro e os controles vão para as faixas laterais, opacas. Assim nada da sala fica coberto. Em telas quase 16:9 (tablets) as faixas não cabem os botões, e eles ficam por cima do jogo, translúcidos.
- **Implementação:** `scripts/touch_controls.gd` só aperta as ações do InputMap (`Input.action_press`); o resto do jogo não sabe que existe toque. Os controles só aparecem depois do primeiro toque (ou desde o início em navegador de celular), então no PC nada muda.
- **Olhar a sala:** fora do joystick (terço esquerdo) e dos botões, arrastar o dedo move a vista, 1:1 com o dedo, sem passar das bordas da sala. Ao soltar, volta suave para o coelho; girar a sala também zera. Dá para andar e olhar ao mesmo tempo. Pensado para salas maiores no futuro; em sala que cabe na tela, não faz nada.
- **Descartado:** controles em HTML fora do canvas (mais trabalho, dois sistemas de entrada); controles sempre por cima da sala (cobriam porta, compartimento e o coelho em várias salas).

### D62 — Versão web publicada no GitHub Pages
- **Autor:** Claude (proposta), aceita por Victor.
- **O quê:** `.github/workflows/deploy-web.yml` exporta a versão web com o Godot 4.7.2 e publica no GitHub Pages a cada push na `main`.
- **Por que funciona:** a exportação é sem threads, então não precisa dos cabeçalhos COOP/COEP que o Pages não permite configurar.
- **Layout dos controles (pedido do Victor depois do teste no iPhone):** sempre o mesmo, medido a partir das bordas da tela: joystick grande à esquerda; pulo grande no canto direito; os dois giros em diagonal acima dele; reiniciar no canto de cima. É o layout que ele testou e aprovou. O layout compacto, com tudo empilhado dentro das faixas laterais, foi descartado.
- **Tamanho da tela (corrigido depois do primeiro teste no iPhone):** o Safari informava uma área mais alta que a visível, e o fundo da sala ficava cortado. A política de redimensionamento do canvas passou a "nenhuma" (`canvas_resize_policy=0`) e o `head_include` dimensiona o canvas pela área visível de verdade (`visualViewport`), de novo a cada giro do aparelho e quando as barras do navegador aparecem ou somem. Depois, outro corte até o primeiro toque no topo: na partida o canvas ainda estava no fluxo da página, grande, e o foco nele fazia o Safari rolar a página para baixo. A página e o canvas passaram a ser fixos desde o CSS, e a rolagem volta a zero a cada ajuste.
- **HTML:** o `head_include` da exportação web põe o jogo em tela cheia no primeiro toque, tenta travar em paisagem e mostra "Gire o celular" quando o aparelho está em pé. No iPhone o Safari não deixa a página entrar em tela cheia; lá o jeito é "Adicionar à Tela de Início".

### D63 — Boss 1: Jeffrey, o esquilo (conceito)
- **Autor:** Victor (conceito e esboço); Claude (análise), regras confirmadas por Victor.
- **O quê:** sala que não gira; Q/E giram só um bloco quadrado com espinhos no centro. O esquilo salta entre as paredes jogando nozes e só é ferido se o bloco girar os espinhos para a face em que ele vai ricochetear, no último instante. Detalhes no GDD, seção 8b.
- **Decidido:** o esquilo só mira faces vizinhas à dos espinhos (um giro sempre basta) e nunca salta numa face com espinhos; o coelho morre num toque; o esquilo tem 3 corações; o jogo não pausa durante o giro do bloco (prova de reflexo).
- **Em aberto:** quando os espinhos da face nova passam a valer, o tamanho da janela de reação por coração, se os corações voltam ao morrer, as regras das nozes, o tamanho do esquilo.

### D64 — Boss 1 implementado como protótipo
- **Autor:** Claude, a partir de D63; pedido de Victor: encurtar o giro do bloco.
- **Giro do bloco:** 9 quadros (0,15 s), sem pausar o jogo; os espinhos passam para a face nova no fim. Recarga de 45 quadros (0,75 s), em vez dos 2,5 s da sala, porque a luta pede um giro por ataque.
- **Motor:** dois campos de sala, genéricos para os próximos bosses: `spin_block` e `actors`. Um ator recebe `step(room)` e `on_reset(room)` e pode abrir a porta (`door_unlocked`).
- **Garantia de que o esquilo não se mata:** as rotas só usam trechos que passam longe do bloco; o único trecho perto dele é o salto de ataque, que só sai para uma face vizinha à dos espinhos (contando um giro em andamento). Teste: girando à toa fora do salto, em 6000 quadros, o esquilo nunca se fere. Outro teste: um bot que gira no último instante vence e chega à porta.
- **Escolha de Claude, aberta a revisão:** os corações perdidos continuam perdidos quando o coelho morre.

### D65 — O esquilo não machuca ao encostar
- **Autor:** Victor, depois do primeiro teste no celular.
- **O quê:** só as nozes matam o coelho. O esquilo pode passar por ele no chão e nos saltos sem dano.

### D66 — Música do boss
- **Autor:** Victor (faixa); Claude (ligação).
- **O quê:** `Boss Rush Groove.mp3`, que estava na raiz, foi para `music/boss-rush-groove.mp3`, importada em loop, e toca na sala do Jeffrey (campo `"music"`).

### D67 — Jeffrey: animação, noz que se degrada, bomba e balanceamento
- **Autor:** Victor (esboço `jeffrey-concept.jpeg`, regras da noz e da bomba, uma noz já no 1º coração); Claude (desenho em código e números).
- **Balanceamento (chefe de capítulo 1):** a janela para girar era 0,85 / 0,55 / 0,35 s; passou a 0,95 / 0,75 / 0,6 s. Nozes na tela: 1 / 1 / 2 (eram 0 / 2 / 3). Bomba: 0 / 1 / 1. Nada é arremessado a caminho do ataque.
- **Noz e bomba:** ver GDD 8b.
- **Por que em código:** o esquilo continua desenhado em `_draw`, com poses por estado; trocar por quadros desenhados à mão depois não muda a luta.
- **Não feito:** fintas na terceira fase (sugeridas por Claude); sons próprios (a explosão reaproveita o som de comporta).
- **Nota:** depois do merge há duas séries D61 a D66 neste arquivo (editor e celular/boss); falta renumerar.

### D68 — Vidas do coelho na sala do boss, retratos e nozes maiores
- **Autor:** Victor.
- **Vidas:** só na sala do chefão o coelho tem 3 vidas. Dano tira uma vida e dá 40 quadros (0,67 s) de imunidade, piscando; perder as 3 reinicia o chefão (os dois voltam a 3). Substitui a escolha de D64 (corações do esquilo persistiam entre mortes).
- **Como:** `room.kill()` consulta os atores (`absorb_kill`); o boss transforma a morte em dano. Vale para qualquer fonte: noz, bomba e espinhos do bloco. `room.invuln` faz o coelho piscar.
- **Retratos:** no alto, coelho e vidas à esquerda do centro, vidas e Jeffrey à direita. O retrato pisca em vermelho no dano; o do Jeffrey ri quando o coelho morre e fica tonto quando é atingido.
- **Nozes:** colisão de 7 para 10 px; arco de 1,15 para 1,5 s (gravidade de 190 para 140).
- **Escolhas de Claude:** a duração da imunidade (40 quadros) e o R reiniciar a luta inteira.

### D69 — Abertura do boss: 3 giros antes de o Jeffrey aparecer
- **Autor:** Victor.
- **O quê:** na primeira vez na sala, ela está vazia. O esquilo só aparece depois que o jogador gira o bloco 3 vezes: assim ele descobre sozinho que aqui Q/E giram o bloco, não a sala. Meio segundo depois do terceiro giro, o Jeffrey cai do céu girando. Sem dica na tela.
- **Não repete:** morrer, reiniciar com R ou voltar à sala não traz a espera de volta.
- **Escolha de Claude, aberta a revisão:** "primeira vez" vale por sessão de jogo (`intro_seen`, estático em `boss_squirrel.gd`); fechar e abrir o jogo mostra a abertura de novo, porque o jogo ainda não salva progresso do boss.
- **Também:** o retrato e os corações do Jeffrey só aparecem quando ele entra; a entrada passou a ser sempre de cima.

### D70 — Música e barras de vida do boss só quando o Jeffrey aparece
- **Autor:** Victor.
- **O quê:** durante a abertura (3 giros), toca a música normal dos níveis e não há retratos nem vidas no alto. Quando o Jeffrey entra, o tema do boss começa (com fade) e as barras aparecem. Nas tentativas seguintes, o tema já toca desde o início.
- **Como:** o campo da sala passou de `music` para `boss_music`; o esquilo pede a faixa por `room.music_request` (e deixa em `room.music_override` para quem conecta depois).

### D71 — Campanha canônica feita no editor
- **Autor:** Victor (objetivo: criar salas e canonizá-las no modo história usando só o editor; replays gravados por ele no lugar dos bots; tirar as fases de `levels.gd`); Claude (formato e fluxo).
- **Dados:** as 17 fases saíram de `levels.gd` para `levels/campaign/<id>.json` (os comentários de projeto foram para o campo `notes`), com a ordem em `ordem.json`. `levels.gd` ficou só com o carregador, a sala de início (presa à cutscene) e a legenda. Substitui o "ajuste por cima" de D64 (`NN.json`).
- **Canonizar:** no editor, **Campanha…** (só em build de depuração). Exige a fase verificada e um replay da mesma versão; o replay vai junto (`<id>.replay.json`). Dá para inserir numa posição, subir, descer e tirar da história (vira rascunho).
- **Prova:** os testes rodam o replay de cada fase da campanha e conferem que ele é da versão atual e chega à porta. As 17 fases antigas continuam provadas pelos bots até ganharem replay (`BOT_IDS` em `tests/run_tests.gd`); fase nova só entra com replay. Quando uma fase ganhar replay, o bot dela pode sair.
- **Determinismo:** o Jeffrey ganhou sorteio próprio com semente fixa, e o replay guarda o estado de partida dos atores (se a abertura do boss já foi vista).
- **Corrigido junto:** o editor apagava campos que não conhecia (`spin_block`, `actors`, `hint_touch`): editar a sala do Jeffrey destruía o boss. Agora ficam em `extra`, e o editor edita a dica no celular, o boss e o bloco giratório.
- **Atenção:** o replay é gravado no Windows e rodado pelos testes onde eles rodarem. Contas com seno e cosseno (corda, água) podem, em tese, diferir entre sistemas; se um replay passar num e falhar noutro, é isso.

### D72 — Boss 2: Gatsby, o texugo (conceito) e fim do limite de tamanho das fases
- **Autor:** Victor (personagem, esboço, fuga pura, alavancas dentro da nave, placas como cenário, sala gigante com a virada na fase 2, Gatsby gira a sala); Claude (giro com limitador como corrida pela parede, componentes).
- **O quê:** a fase do Gatsby é uma perseguição, não uma luta: ele nunca é alcançado e foge no final. Detalhes no GDD, seção 8c.
- **Descartado:** alavancas que o coelho usa; dano ao Gatsby em três trechos; bloco em trilho que cai com o giro; dividir a fuga em salas ligadas por porta.
- **Tamanho das fases:** o limite de 64×48 saiu. `MAX_W` e `MAX_H` em `level_data.gd` são agora 512, um teto técnico (contra erro de digitação), não de design.

### D73 — Placa de espinhos como componente da sala; fuga sem checkpoint
- **Autor:** Victor (a placa do esboço, que destrói os blocos no caminho; sem checkpoint por enquanto); Claude (formato e regras).
- **O quê:** a placa é um campo da sala (`crushers`), não parte do Gatsby: serve para qualquer fase de fuga. Ela varre uma faixa retangular, o que permite duas placas na mesma sala (a que sobe o poço e a que vem pelo corredor).
- **Gira com a sala,** como todo o resto: é o que faz o giro com limitador virar corrida pela parede com a placa vindo de lado.
- **Não é sólida:** só mata e destrói. Assim nada fica "em cima" dela e não há caso de esmagamento a resolver.
- **Guia (`leash`):** opcional; sem ela, quem sobe rápido deixa a placa fora da tela e a pressão some.
- **Cordas não são destruídas:** o coelho pode estar pendurado numa; fica para quando uma fase precisar.
- **Checkpoint:** nenhum por enquanto; morrer recomeça a fase. Rever depois de jogar a fase inteira.

### D74 — Gatsby como ator com roteiro; visual industrial; carinha pichada e fixa
- **Autor:** Victor (visual industrial com chapas remendadas em tudo o que é do Gatsby; carinha pichada e fixa; o Gatsby é do ato 2 e o visual muda); Claude (roteiro, ganchos na sala, desenho).
- **Roteiro como dado:** o comportamento dele está no campo `gatsby` da fase, não no código, para a fase poder ser redesenhada sem programar. Avança pelo avanço do coelho, para ser justo com quem joga devagar ou rápido.
- **O giro dele fica** e é independente do limitador: o giro do coelho continua sendo desfeito aos 2,5 s; o do Gatsby, não.
- **A carinha gira com a sala** (é tinta na placa), ao contrário da primeira versão, que ficava em pé e seguia o coelho.
- **Ele atravessa paredes** ao voar em linha reta entre os pontos do roteiro; quem desenha a fase escolhe pontos que evitem isso.

### D75 — Gatsby: a fuga vira corrida (fase refeita, componentes, sons, movimento)
- **Autor:** Victor (fase mais frenética, senso de urgência na escalada, corrida dinâmica, refazer o design inteiro, efeitos sonoros, movimento melhor, o Gatsby nunca encosta no coelho, conectores coloridos reaproveitáveis); Claude (o desenho e as escolhas abaixo).
- **Princípio do desenho:** o que o Gatsby faz para atrapalhar é o que leva o coelho adiante (o pistão que esmagaria vira catapulta; o giro dele vira uma queda de 34 tiles). Cada trecho usa uma mecânica, é curto, e a seguinte chega antes de dar tempo de respirar. Tabela no GDD, 8c.
- **O giro com limitador entra de verdade:** dois trechos do poço não têm onde pular; só se passa correndo pela parede. As plataformas por orientação (`=`) seguram o coelho quando o giro se desfaz: é a combinação de duas mecânicas que o jogo já ensinou.
- **Componentes novos, da sala e não do Gatsby:** chapas soltas (`crumbles`), catapulta (`launch` no conector), aviso dos conectores (`MOVER_WARN`), medidor de perigo (`danger`). Servem a qualquer fase.
- **Conectores:** o aviso (encaixes piscando + bipes) vale para todos, sempre. Sem ele, peças acionadas fora da tela ou no meio de uma corrida matam sem deixa. O raio na cor do canal mostra quem acionou o quê.
- **Urgência sem injustiça:** guia curta (a placa nunca sai da tela) com velocidade base baixa. Na travessia plana do poço a placa desacelera (8 px/s), porque ali o coelho não ganha altura.
- **Movimento do Gatsby:** à frente, não em volta. Em volta, ele cruzava o caminho do coelho e encostava nele. A distância mínima é garantia por código (50 px entre os centros), não por ajuste de mola.
- **Fase em `levels/wip/`:** ainda não é da campanha (falta a música e o replay do Victor), mas precisa ser jogável no celular; daí `?play=gatsby`.
- **Escolhas minhas, abertas a revisão:** os saltos de 3 tiles com vão de 3 (exigem pular da beirada); 0,43 s para a chapa cair; a queda do corredor não tem perigo no caminho de quem cai rente ao chão (é espetáculo e respiro); sem checkpoint (D73).
- **Descartado:** esteiras; uma balsa lenta (parar numa corrida é o contrário do que se quer); espinhos na pista da parede (ficam para uma segunda versão, se a pista se mostrar fácil).

### D76 — Ato 2: cinco fases industriais com baterias, alavanca e ácido
- **Autor:** Victor (a ordem, o loop de baterias, o tema, o ácido e as respostas abaixo); Claude (a proposta das fases e dos componentes).
- **Decidido:** as cinco fases entram imediatamente depois do Jeffrey; com todas as baterias (de 1 a X) a alavanca se ativa sozinha e solta a caixa; morrer volta ao início por ora; o editor ganha as peças novas antes de as fases serem feitas; o Gatsby só aparece na fase 5, rápido, ativando a placa de espinhos.
- **Ácido:** componente novo do Victor, água verde que mata ao toque.
- **Em aberto:** a campanha tem 16 fases antes do Jeffrey, e o Victor falou em 15; ficam as 16 até ele dizer qual sai.
- **Descartado por ora:** a bateria como checkpoint (a proposta de Claude); o Gatsby em todas as cinco fases.

### D77 — As cinco fases industriais: rascunhos provados por robô, editor com objetos
- **Autor:** Claude, seguindo D76.
- **Entregue:** o ácido, o tema industrial, bateria/alavanca/calha, os gatilhos dos conectores (ciclo, bateria, botão, atraso), esteira, mola, ventilador e vapor; o editor com a janela de objetos (tudo desfazível, girando com a sala); as cinco fases em `levels/wip/`, cada uma com uma rota do robô nos testes.
- **Ácido:** um fluido só por sala. Misturar com água exigiria duas simulações que se sobrepõem quando as salas giram; fica para quando houver uma fase que peça.
- **O botão de pressão não podia chamar o elevador sozinho:** ele partia antes de o coelho subir. Daí o campo `delay` dos conectores (espera, com aviso), que serve a qualquer fase.
- **O robô pegou três erros de desenho** que um olhar nas capturas não pegaria: um salto de 3 tiles com vão de 1 (bate na lateral), um pouso na plataforma errada na mesma coluna (agora confere a altura) e uma parede que fechava a saída de um elevador.
- **Sem giro nas cinco fases:** o foco é plataforming e as fases iniciais do jogo também começam sem giro. Se quiser uma corrida pela parede com o limitador (a ideia da fase 4 da proposta), é uma fase nova ou uma mudança.
- **Em aberto:** os números (velocidades, ritmos, folga da parede) são palpites; as fases são curtas para um humano? O robô as vence em 16 a 33 s; um jogador deve levar de 2 a 5 vezes isso. Falta música, o replay do Victor, e a ligação delas depois do Jeffrey na história.
- **Ideia deixada de lado:** a caixa subir por uma coluna de ar até o compartimento (o ventilador já levanta caixas e elas pairam no alto da coluna; falta um jeito de a caixa sair dela para o compartimento sem o coelho entrar na corrente).

### D78 — Ato 2 mais difícil, com giro; canonizado depois do Jeffrey; vapor granular
- **Giro liberado nas cinco fases, com o limitador (2,5 s).** Nenhuma depende do giro (o robô as vence sem ele), mas ele não é proibido. Para tornar o giro arriscado em vez de gratuito, todas têm **espinhos no teto** (`Level.ceiling()`, a alavanca e a calha ficam de fora).
- **Fase 1 refeita, mais dura:** degraus estreitos, plataforma em ciclo sobre espinhos, ponte de chapas, elevador em ciclo, estampador e subida de saltos de 3 tiles. O robô ensinou: o elevador em ciclo precisa de tempo de subir antes do pulo, e posições de conector são o canto do coelho (`pos` é o canto superior esquerdo).
- **Fase 5:** o Gatsby e a parede só aparecem no último trecho (gatilho a 2 tiles do fim do corredor, parede a ~10 tiles da porta, carinha feliz). A esteira da caixa ficou mais rápida (60 px/s) para a porta abrir antes.
- **Canonizadas** logo depois do `jeffrey` (ids `linha-de-montagem`, `esteiras`, `prensas-e-vapor`, `dutos`, `casa-de-forca`), com a rota do robô como replay (`tools/canonize_levels.gd`). A campanha tem 22 fases.
- **Vapor:** partículas finas (pontos brancos que sobem, alargam e somem, com o jato aberto crescendo da boca) no lugar dos quadrados cinzas.

### D79 — Boss 3: a mecha do Gatsby (só o plano)
- **Ideia do Victor** (esboço com mira, teleguiados e investida), discutida e fechada em 8e do GDD. Fica depois da fuga do Gatsby.
- **Escolhas:** sem espinhos; a mecha leva dano só dos próprios mísseis e da investida na parede (atordoada); cada terço da barra tira um coração do Gatsby (3), com explosão e deterioração; coelho com 3 corações como no Jeffrey; flip com o limitador de ~2,5 s; a abertura não permite flip.
- **Prioridade da implementação:** a investida primeiro, porque a sensação do flip como esquiva é o maior risco do desenho.

### D80 — A mecha: primeira versão jogável
- **A esquiva da investida** vem de uma regra só: a velocidade da investida (e dos teleguiados) é de tela, não gira com a sala. Um giro move o coelho e a mecha junto com a sala, mas a investida segue para o mesmo lado da tela: perde o alvo e bate na parede. Não precisou de nenhum caso especial.
- **A mira travada** (os 14 quadros finais do aviso) existe porque, sem ela, a janela era de ~0,2 s, só no começo da investida. Com ela, ~0,45 s, e o jogador vê quando pode girar (a linha fica sólida). Girar antes da trava é cedo demais: ela mira de novo.
- **A mecha mantém distância** (56 a 96 px) para a investida ter caminho; se ficasse colada no coelho, não haveria tempo de reagir.
- **A cápsula do Gatsby é o próprio `boss_gatsby.gd`**, usado só para o desenho (um "boneco" dentro da mecha, desenhado atrás do corpo: só a cúpula aparece). As expressões dele já existem e acompanham a luta.
- **Prova:** sem replay ainda (está em `levels/wip`). Os testes provam a abertura, a esquiva em quatro momentos, girar cedo demais, os teleguiados (inclusive acertando a mecha), os terços, a derrota e um bot que vence só girando na investida (em ~2,6 min de jogo).

### D81 — A mecha, segunda passada: maior, uma peça só, com movimento
- **Câmera rolando** (escolha do Victor) em vez de zoom: a sala de 30×30 é mais alta que a tela; o que está fora da vista (miras, teleguiados) ganha uma seta na borda.
- **Sem limitador** nesta sala (pedido do Victor): o giro fica, só com a recarga normal.
- **Corpo e cúpula numa caixa só** (40×52): antes, o míssil que passava pela cúpula não contava.
- **Motores laterais:** a cápsula ganhou `fused` (sem balanço e sem o propulsor próprio) e `tilt` (inclina junto com o corpo). Quem empurra a mecha são os motores embaixo dos braços; o fogo aponta para trás do movimento.
- **Movimento:** a pose é só desenho (`_pose()`), calculada do estado a cada quadro; nada disso muda a colisão, então os testes da luta não dependem da arte.
- **Paleta:** as chapas da mecha são um pouco mais claras que as da cápsula, para ler no fundo escuro.

### D82 — O subsolo do ato 1, a batida de pata e o amortecedor
- **Ato 1 com alma:** o subsolo embaixo do campo da abertura, em quatro trechos (raízes, caverna, lençol d'água, despensa). Escolhido entre "subsolo" e "limbo abstrato" porque liga a abertura, o Jeffrey e a fábrica do Gatsby.
- **Tema e despertar fora do hash** (`TEXT_KEYS` de `level_data.gd`): são só aparência. Os replays do ato 2 tinham o tema no hash; o hash deles foi refeito por `tools/rehash_campaign.gd`, que só aceita se o replay continuar vencendo (venceram nos mesmos quadros).
- **O poder é do coelho** (pedido do Victor): a batida de pata, comportamento real de coelho assustado. Ele desperta na fase 3, encurralado. Na história completa (`docs/HISTORIA.md`), o poder foi implantado no laboratório (caminho 1).
- **A barra vermelha ganhou corpo:** o amortecedor (cristal no subsolo, estabilizador na fábrica). É só desenho; a regra do limitador não mudou.
- **História como registro:** o plot das cobaias e a fuga final ficam em `docs/HISTORIA.md`, sem nada no jogo por enquanto.

### D83 — Passagem: o corredor da terra ao metal
- **Pedido do Victor:** um grande corredor entre o Jeffrey e o ato 2, fazendo a transição. É a fase 18 (`passagem`), canonizada com a rota do robô; as fases do ato 2 passam a ser 19 a 23.
- **Tema `transicao`:** a cada tile, sorteio (por hash) entre terra e aço, com a chance de aço crescendo ao longo da fase. `_metal_frac()` mede esse "ao longo" na direção da fase como foi desenhada, então a mistura não se embaralha com o giro.
- **Respiro, mas com as peças do ato 2:** depois do boss, nada de quebra-cabeça; o jogador vê chapas soltas, esteira e estampador antes de precisar delas.
- **Correções:** os pingos do lençol d'água caíam de lado depois de um giro (saíam do "teto original"); agora saem do teto de agora e caem para baixo da tela. O bloco do Jeffrey perdia a textura enquanto girava (era desenhado liso); agora gira tile a tile, com o tema.

### D84 — Sombras, profundidade, reação ao giro, passos e líquidos
- **Pedido do Victor:** "mais sombras, mais profundidade, detalhes", elementos reagindo à gravidade e passos por superfície; depois, mais detalhe na água e bolhas no ácido.
- **Sem luzes do motor:** o jogo roda no renderizador de compatibilidade (web/celular); tudo é desenho direto (retângulos, polígonos, uma textura de gradiente para a vinheta). Barato e igual em todo lugar.
- **Sombra de célula, não de tile:** a sombra é calculada para cada célula vazia (faixas de cima, da esquerda e do canto que não se sobrepõem), senão as sombras de tiles vizinhos somavam e faziam listras.
- **Um balanço só para tudo que pende** (`_sway()`): como tudo pendia reto antes do giro, a diferença é sempre os 90° do giro; uma oscilação amortecida global basta, sem estado por objeto.
- **Paralaxe com limite:** o fundo deslocado não pode vazar para fora da sala; as faixas visíveis são cortadas pelo deslocamento.
- **Passos pela distância andada** (`rabbit.anim`), não pelo tempo: andar devagar ou contra a parede não faz barulho à toa.

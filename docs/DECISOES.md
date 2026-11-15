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
- **Em aberto:** se as salas ficarem grandes ou cheias de elementos, vale reconsiderar um editor (TileMap do Godot ou LDtk).

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

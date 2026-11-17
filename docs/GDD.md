# Documento de design — piloto

> Nome do jogo: **Free**.
> Estado: **M0 a M4 implementados** e primeira rodada de retorno aplicada. Pendente: redesenho das salas e M5 (arte, áudio, polimento).
> Referência visual: `concept.png` (raiz do projeto).
> Este arquivo é o design. Decisões e motivos: [DECISOES.md](DECISOES.md). Código: [ARQUITETURA.md](ARQUITETURA.md). O que foi feito e o que falta: [HISTORICO.md](HISTORICO.md). Como rodar: [README.md](README.md).

## 1. Visão

Um coelho em pixel art precisa fugir atravessando salas cada vez mais difíceis. O ambiente é quase monocromático, mas suave. O jogador pode **girar a sala inteira de 90 em 90 graus**; tudo que está solto cai. Para abrir a porta de cada sala, é preciso encaixar uma caixa em um compartimento e mantê-la lá.

Referências de sensação de controle: Celeste e Super Meat Boy.

**Escopo do piloto:** 10 níveis com dificuldade crescente, jogáveis do início ao fim, com controle polido. *(Eram 5; ver D42.)*

## 2. Pilares

1. **A gravidade sempre aponta para baixo na tela.** Quem gira é a sala; os controles nunca mudam.
2. **Tudo que está solto cai** depois de um giro: coelho e caixas.
3. **A caixa só fica no compartimento pela gravidade.** Um compartimento fechado em três lados derrama a caixa em exatamente uma das quatro orientações. Se a caixa sai, a porta fecha.
4. **Cor significa interatividade.** O cenário é preto e branco; só o que importa para o puzzle tem cor.

## 3. Requisitos

### 3.1 Coelho

| Item | Definição |
|---|---|
| Ações | Andar, pular, empurrar caixas, girar a sala |
| Pulo | Altura variável conforme o tempo do botão pressionado |
| Tolerâncias | Coyote time (~6 frames), buffer de pulo (~6 frames), correção de quina |
| Curva | Aceleração e desaceleração curtas; gravidade reduzida no ápice do pulo |
| Morte | Espinhos ou esmagamento por caixa. Sem dano de queda |
| Respawn | Instantâneo (menos de 0,5 s), sem vidas |
| Reinício | Botão dedicado para reiniciar a sala |

### 3.2 Rotação

- Giro de 90° para cada lado, em torno do centro da sala.
- Salas sempre quadradas, para qualquer orientação caber na tela.
- Animação de ~0,25 s com easing. A simulação pausa durante o giro.
- O coelho "faz" o giro: dá uma cambalhota encolhida no mesmo sentido (0,4 s, terminando já na queda) e solta faíscas azuis com um anel. O giro desfeito pelo limitador não tem esse efeito.
- Ao fim do giro, a velocidade do coelho e das caixas zera, e tudo cai a partir do repouso.
- **Giro no ar:** um por pulo, recarrega ao tocar o chão.
- **Recarga do giro:** depois de cada giro, um novo giro fica bloqueado por 2,5 s (animação incluída; D60). Uma barra branca no canto inferior direito enche durante a recarga, com um som que fica mais agudo; um "plim" avisa quando está pronto.

### 3.3 Caixas

- Movimento cinemático com colisão por caixas alinhadas aos eixos. Sem motor de física: a caixa não tomba nem quica, só desliza e cai reta.
- O coelho empurra andando contra a caixa, mais devagar que a caminhada normal.
- A caixa serve de degrau e de plataforma segura sobre espinhos.
- Caixa que cai sobre o coelho o esmaga.

### 3.4 Compartimento e porta

- O compartimento é um sensor. Caixa dentro: porta aberta. Caixa fora: porta fechada.
- A mudança de estado tem feedback imediato de cor e som.
- Salas com mais de um compartimento só abrem a porta com todos ocupados.
- A porta fechada **não é sólida**: não bloqueia o coelho nem as caixas, e encostar nela não faz nada. Só a porta aberta conclui a sala.
- A porta aberta é um vão iluminado. Ao tocá-la, o coelho é puxado para dentro e a porta se fecha antes da transição.
- Tocar a porta aberta conclui a sala.

### 3.4b Comportas e plataformas por orientação

- **Comporta:** trecho de parede, em verde-água com barras, que divide a sala em etapas. Abre enquanto os compartimentos ligados a ela têm caixa parada e volta a fechar se a caixa sair. Os compartimentos de comporta têm a moldura na mesma cor dela. Nunca fecha em cima do coelho ou de uma caixa: espera o caminho ficar livre.
- **Plataforma por orientação:** tile lilás com uma seta. Só é sólido quando a seta aponta para cima na tela; nas outras orientações aparece tracejado e é atravessável. Também espera ficar livre antes de virar sólido.
- Os dois têm som e um brilho curto ao mudar de estado.

### 3.4c Corda

- Presa por uma ponta a uma parede. **Só serve quando presa no teto**; nas outras orientações fica frouxa (amontoada no chão ou caída junto à parede) e não faz nada.
- A corda tem física: depois de um giro ela cai e balança até repousar.
- O coelho a agarra sozinho ao encostar nela **durante um pulo**. Andando no chão, ou caindo depois de um giro, passa por ela.
- Pendurado, fica parado. Pode descer pela corda (S ou seta para baixo), mas não subir.
- Quem pula e gira a sala no ar pode agarrar a corda que o giro acabou de pôr no teto. Pode girar a sala sem gastar o giro do ar: a corda fica de lado e o coelho faz um arco de pêndulo, ganhando velocidade.
- Pulo solta, com a velocidade do arco. Bater em parede também solta. Espinhos matam normalmente no arco.
- Onde o coelho agarra define o raio do arco; quem pula de baixo agarra a ponta.

### 3.4e Limitador

- Em salas com limitador, o giro feito é desfeito sozinho quando os 2,5 s de recarga terminam, com um som distorcido. Uma barra vermelha, paralela à branca, esvazia nesse tempo.
- Quem quer ficar na orientação nova tem de chegar à porta antes do tempo acabar.

### 3.4d Água e ralo

- A água escorre com a gravidade, se nivela e conserva o volume. Ao girar a sala, ela cai para o novo chão. A superfície é contínua, pixel a pixel, e faz ondas quando algo cai nela ou quando ela corre.
- O coelho boia com a cabeça para fora; ao cair, afunda por um momento. Na água ele anda mais devagar, pula a partir da superfície e pode girar a sala. A água não mata.
- Espinhos submersos continuam matando: quem cai de alto em água rasa afunda até eles.
- Caixa na água continua afundando, mais devagar.
- **Porta com 30% ou mais coberta de água fica bloqueada**, somando-se à regra dos compartimentos. Ela só destrava depois de meio segundo seca.
- **Ralo:** engole aos poucos a água que chega até ele. Está sempre ligado. A água engolida só volta ao reiniciar a sala.

### 3.4f Comporta inversa

- Trecho de parede âmbar com hachura em X, que faz o **contrário** da comporta comum de mesmo número: usa o mesmo compartimento, mas fica **aberta enquanto ele está vazio e fecha quando a caixa chega**. Com a caixa no compartimento "a", a comporta `1` abre e a inversa `1` fecha.
- Aberta, aparece só um contorno tênue. Nunca fecha em cima do coelho ou de uma caixa.
- Serve para fases em que encaixar a caixa liberta um caminho e tranca outro.

### 3.5 Controles

| Ação | Teclado | Controle | Toque (D61) |
|---|---|---|---|
| Andar | A/D ou setas | Analógico ou direcional | Joystick à esquerda |
| Pular | Espaço | A | Botão grande, embaixo à direita |
| Descer a corda | S ou seta para baixo | Analógico ou direcional para baixo | Joystick para baixo |
| Girar anti-horário / horário | Q / E | LB / RB | Os dois botões de seta acima do pulo |
| Reiniciar sala | R | Y | Botão pequeno no canto de cima |
| Olhar a sala (salas maiores que a tela) | — | — | Arrastar o dedo pela tela; ao soltar, a câmera volta para o coelho |

### 3.6 Estética

- Resolução interna de 320×180, escala inteira.
- Tiles de 8 px; salas de qualquer tamanho; coelho e caixa com cerca de 16×16 px.
- Salas maiores que a tela: a câmera segue o coelho, com suavização, e para nas bordas da sala. No eixo em que a sala cabe, ela fica centralizada.
- Fundo preto, linhas off-white.
- Cores reservadas: caixa azul, porta amarela (aberta) e azul-acinzentada (trancada), compartimento cinza, comporta verde-água, plataforma por orientação lilás, espinhos coral, corda laranja (apagada quando frouxa), água azul translúcida, ralo cinza, olho vermelho do coelho.
- O aspecto suave vem de brilho leve, easing na câmera, squash & stretch, partículas discretas e áudio lo-fi.

## 4. Tecnologia

**Godot 4 (versão estável atual, 4.3 ou superior) com GDScript.**

- Controlador do coelho escrito à mão sobre `CharacterBody2D`. Nada de corpos rígidos.
- Física em passo fixo de 60 Hz, com interpolação de física ligada.
- Viewport de baixa resolução com escala inteira para pixel-perfect.
- Exportação para Windows no piloto; Web, Linux, Mac e Steam Deck ficam disponíveis depois.

### Como a rotação é implementada (revisado na implementação)

O plano original era girar câmera e vetor de gravidade. Na prática ficou mais simples e mais robusto:

1. A simulação **sempre** roda com a gravidade para baixo.
2. Ao girar, os dados da sala (tiles, caixas, compartimentos, porta, espinhos e coelho) são **rotacionados 90° de verdade**, em aritmética inteira, sem erro de arredondamento.
3. Só o desenho anima o giro (de -90° até 0° com easing cúbico, 16 quadros). A simulação fica pausada nesse tempo.

Consequências: o controle nunca muda, a colisão nunca precisa saber de orientação, e a hitbox do coelho é quadrada (12×12) para não mudar de forma ao girar.

### Controlador (revisado)

Em vez de `CharacterBody2D`, o coelho e as caixas usam **posição em pixels inteiros** e colisão por retângulos, no estilo de Celeste. Os valores de ajuste estão no topo de `scripts/rabbit.gd` e tabelados em [ARQUITETURA.md](ARQUITETURA.md). Medido nos testes: pulo longo 30 px, pulo curto 8 px, cerca de 0,7 s no ar.

Detalhes que existem por causa da sensação de controle: coyote time de 6 quadros, buffer de pulo de 6 quadros, correção de quina (até 4 px), ajuda de degrau (até 3 px), subida sustentada enquanto o botão está apertado, gravidade pela metade no ápice, squash & stretch, poeira ao pular e pousar.

### Comportamento das caixas (decidido na implementação)

- Uma caixa só é "apoiada" pela faixa central da base. Quando o centro passa da borda de um buraco, ela cai, e é alinhada sozinha (até 4 px) para encaixar em buracos do tamanho exato dela.
- Espinhos não são sólidos para caixas: uma caixa cai por cima deles e atravessa.
- Uma caixa só conta como encaixada se estiver **parada** e a até 3 px do centro do compartimento. Se estiver caindo ou escorregando, a porta fecha.
- Com a recarga do giro, não dá mais para passar por uma orientação perigosa sem consequência: a caixa sempre tem tempo de cair antes do giro seguinte. O sentido do giro importa de verdade.

## 5. Estrutura do projeto (como ficou)

```
project.godot
docs/GDD.md
scenes/main.tscn       # só carrega scripts/main.gd
scripts/
  main.gd              # progressão entre salas, entrada, transições
  room.gd              # tiles, rotação, caixas, compartimentos, porta, espinhos, desenho
  rabbit.gd            # movimento e pulo
  box.gd
  levels.gd            # carrega a campanha de levels/campaign (as fases são dados, feitos no editor)
  input_setup.gd       # teclas e controle registrados em código
  touch_controls.gd    # controles de toque (celular), apertam as mesmas ações
  boss_squirrel.gd     # boss 1, Jeffrey, o esquilo (ator da sala 17)
tests/
  run_tests.gd         # formato das salas, pulo e bots que resolvem cada sala
  shot.gd              # capturas de tela de cada sala
assets/                # (M5) sprites e áudio
```

As salas são texto (hoje em `levels/campaign/*.json`, feitas no editor; D71) em vez de cenas `.tscn`: dá para editar e revisar como código, e os testes conseguem carregar qualquer sala sem abrir o editor. Há um campo `start_rot` para desenhar a sala na orientação em que ela é resolvida e começar girada.

## 5b. Abertura

Esboço em `start-screen.jpeg`; detalhes em D46.

- **Tela de início:** fundo preto, título "FREE", "PRESS ENTER" piscando e uma janela com o coelho num campo verde e ensolarado, o único cenário colorido do jogo.
- **Cutscene:** um buraco se abre sob o coelho, ele se assusta ("!"), cai e some; a janela se apaga; ele cai girando no vazio até pousar numa pequena plataforma branca, que se expande até virar um quadrado com uma porta.
- **Sala de início:** esse quadrado é jogável. O jogador anda até a porta e começa o nível 1.
- Enter de novo pula a cutscene. A tela de início toca `music/free-title.mp3` em loop; a música para na hora em que o jogador aperta Enter, e a cutscene tem só efeitos.

## 6. As 5 salas

Cada sala introduz uma ideia. A dificuldade cresce porque as ideias se combinam.

Vocabulário: um **buraco** é um compartimento aberto para cima (a caixa cai nele); um **nicho** é um compartimento aberto para o lado, com teto (a caixa entra empurrada ou por gravidade lateral). Um buraco só derrama a caixa com a gravidade para cima; um nicho só derrama com a gravidade para o lado da abertura.

Terceira versão (15/11/2026): **10 níveis** com dificuldade crescente (D42). No teste da segunda versão, as salas 1 e 2 estavam bem mais difíceis que a 3. Agora cada nível apresenta **uma ideia nova** e os seguintes a combinam com as anteriores; as salas longas da versão anterior foram mantidas e reposicionadas onde sua dificuldade cabe.

| # | Nome | Tamanho | Ideia nova | Como funciona |
|---|---|---|---|---|
| 1 | Primeiros passos | 20×10 | Caixa no buraco abre a porta | Andar, empurrar a única caixa no buraco, entrar na porta. Sem pulo obrigatório, sem perigo. |
| 2 | Degraus | 29×14 | Pular | Um degrau de 2 tiles, um bloco de 3 e um vão no chão (cair nele não mata; dá para sair). Depois, a caixa no buraco. |
| 3 | Comporta | 30×12 | Comporta; espinhos | Caixa no buraco "a" abre a comporta. Depois, só dois espinhos para pular e a segunda caixa no buraco da porta. |
| 4 | Toca | 46×14 | (combinação, sem girar) | Bloco, comporta, pulos entre dois pilares sobre espinhos, segunda caixa. |
| 5 | Giro | 18×15 | Girar a sala | A caixa vai fácil para o buraco, mas a porta está deitada na parede da direita, alta demais. Girando no sentido horário, essa parede vira chão e a porta fica ao alcance. |
| 6 | Derrame | 36×16 | Nichos; o sentido do giro; virar de cabeça para baixo | Dois nichos abertos para a esquerda; girar no sentido horário até virar a sala mantém as caixas, no anti-horário elas caem e a comporta fecha. A porta está pendurada no teto. |
| 7 | Setas | 20×16 | Plataformas por orientação | Caixa no nicho e virar a sala, como em Derrame. O teto vira chão cheio de espinhos, e a fileira de setas que apontava para baixo passa a apontar para cima e vira a ponte até a porta. |
| 8 | Vertigem | 38×20, começa girada | (combinação) | O puzzle do esboço abre a comporta; depois, derrubar a segunda caixa num poço, girar, e a coluna de setas vira ponte sobre os espinhos. |
| 9 | Espinhos | 28×20 | Girar no ar | Cruzar 14 tiles de espinhos pulando e girando no ar, com pousos que só existem depois do giro; voltar pelo ar até a porta. Girar do chão mata. |
| 10 | Fuga | 32×36, alta | (síntese) | A travessia pelo ar abre a comporta do teto; escadaria de plataformas; virar a sala para jogar a segunda caixa no compartimento do teto e atravessar o antigo teto até a porta. |

**Ato introdutório (D53):** a ordem atual das fases é a de `levels/campaign/ordem.json` (D71); as notas de projeto de cada fase estão no campo `notes` do arquivo dela. São 16 hoje: Primeiros passos, Degraus, Giro, Comporta, Derrame, Toca, Setas, Espinhos, Prumo, Vertigem, Água, Maré, Represa, Naufrágio, Mergulho, Fuga (Corda, Laço e Salto no vazio foram removidas, D58 e D60). As tabelas desta seção são anteriores a essa ordem.

Depois do piloto, dois níveis que apresentam mecânicas novas (15/11/2026, D47 a D50):

| # | Nome | Tamanho | Ideia nova | Como funciona |
|---|---|---|---|---|
| 11 | Corda | 36×22, começa de cabeça para baixo | Corda | A porta flutua no meio da sala com espinhos em cima e embaixo, fora do alcance em qualquer orientação. Virar a sala para as cordas penderem do teto, pular e agarrar a ponta de uma, girar pendurado: o arco passa pela lateral da porta. |
| 12 | Água | 24×22 | Água e ralo | A água cobre boa parte da porta e a tranca. O ralo está num nicho alto da parede, seco. Girando, essa parede vira chão, o nicho vira um poço e a água escoa. Girar de volta com a porta livre. |

Todos os níveis são resolvidos por bots em `tests/run_tests.gd` e foram conferidos em captura de tela. Os bots provam que há solução, não que a curva está boa: isso depende do teste de quem joga.

**Ponto de atenção da curva:** os níveis 1 a 4 não têm giro; o giro só aparece no 5. Se a espera parecer longa, dá para trazer "Giro" para antes de "Toca".

**Pendente da versão anterior:** a sala Fuga continua com uma comporta e um compartimento na saída, em vez de duas e dois (D41).

## 7. Etapas de implementação

| Etapa | Entrega | Critério de pronto | Estado |
|---|---|---|---|
| M0 | Projeto Godot configurado | Janela abre em 320×180 com escala inteira | feito |
| M1 | Controlador do coelho | Andar e pular em uma sala de teste, com todas as tolerâncias da seção 3.1 | feito (falta ajuste por quem joga) |
| M2 | Rotação | Giro para os dois lados, coelho cai para o novo chão, giro no ar funciona | feito |
| M3 | Caixa, compartimento, porta, espinhos | Sala 2 jogável do início ao fim | feito |
| M4 | As 5 salas em graybox | Sequência completa jogável, com morte e reinício | feito; 2ª versão (salas longas) feita, aguardando teste |
| M5 | Arte, áudio e polimento | Sprites, partículas, sons e transições entre salas | pendente |

A sensação de controle é ajustada em M1 e M2, antes de qualquer fase ou arte. O coelho já tem um sprite provisório de 14×14 desenhado em código.

### Atalhos de desenvolvimento

PageDown e PageUp pulam entre salas. R reinicia a sala.

Abrir direto num nível, pulando a abertura: `./run.ps1 -Level 17` no PC, ou `?level=17` no link da versão web (`https://victobonetti.github.io/FREE/?level=17`), que também serve no celular.

## 8. Expansões (fora do piloto)

- **Tipos de caixa:** pesada (esmaga espinhos), de vidro (quebra na queda), magnética (gruda na parede), balão (cai para cima).
- **Regras de rotação:** giros limitados por sala, giro de 180°, setores que giram separados, zonas que bloqueiam o giro, momento preservado após o giro.
- **Cenário:** botões de peso, segunda cor de caixa, zonas onde o giro é proibido, inimigos que também caem. (Plataformas por orientação e comportas já entraram no piloto; corda e água entraram depois dele.)
- **Rejogabilidade:** cronômetro de speedrun, cenouras colecionáveis em rotas arriscadas, versões difíceis das salas.
- **Narrativa:** coelho de laboratório fugindo de câmaras de teste, o que justifica o visual estéril e as salas que giram.

## 8b. Boss 1 — Jeffrey, o esquilo (D63, D64)

**Protótipo jogável (rodada 24):** sala 17, depois da Fuga (`./run.ps1 -Level 17`). Esboço do Victor em três quadros: o bloco com espinhos no centro, o esquilo subindo as paredes, o giro no último instante.

**A sala:** o coelho cai numa sala que não gira. Q/E giram só um **bloco quadrado com espinhos numa das faces**, no centro da sala. Por ser quadrado, girar não muda a colisão, só qual face tem espinhos. A gravidade e o resto da sala não mudam.

**Abertura (D69):** na primeira vez, a sala está vazia; depois de 3 giros do bloco, o esquilo cai do céu girando. Não se repete ao morrer.

**O esquilo:** entra girando, caindo de cima. Anda no chão e ataca saltando algumas vezes entre as paredes, girando no ar e jogando nozes. Só as nozes matam o coelho; encostar no esquilo não machuca (pedido do Victor depois do primeiro teste). As nozes caem com a gravidade e quebram depois de 3 toques.

**Como vencer:** o esquilo **nunca salta numa face com espinhos**, e depois que um salto começa ele não muda. Ele só mira faces **vizinhas** à dos espinhos, então um giro sempre basta. Girar cedo não adianta (ele escolhe outro alvo), girar tarde também não (ele já ricocheteou): o acerto vem de girar no último instante, no meio do salto dele.

**Regras decididas:**
- **Só nesta sala o coelho tem 3 vidas** (D68). Levar dano (noz, bomba, espinhos do bloco) tira uma vida e ele pisca, imune, por 0,67 s, sem sair do lugar. Na terceira, morre e a luta recomeça inteira, os dois com 3. O esquilo tem 3 corações. Depois do terceiro acerto, abre-se a porta.
- No alto da tela: retrato do coelho com as vidas dele, e as do Jeffrey com o retrato dele.
- O jogo **não pausa** durante o giro do bloco: tudo continua se movendo. É uma prova de reflexo.

- O giro do bloco é mais curto que o da sala: 0,15 s (9 quadros). Os espinhos passam para a face nova no fim dele. Recarga de 0,75 s.

**Como ficou no protótipo (valores no topo de `scripts/boss_squirrel.gd`, por fase = corações perdidos):**

| | 1º coração | 2º | 3º |
|---|---|---|---|
| Andando no chão | 1,7 s, devagar | 1,25 s | 0,9 s, mais rápido |
| Saltos de zigue-zague antes do ataque | 1 | 2 | 3 |
| Aviso antes do salto (a face mirada ganha uma linha amarela) | 0,67 s | 0,57 s | 0,47 s |
| Salto de ataque (janela para girar = salto menos 0,15 s do giro) | 1,1 s | 0,9 s | 0,75 s |
| Nozes na tela, no máximo | 1 | 1 | 2 |
| Bombas na tela, no máximo | 0 | 1 | 1 |

- O esquilo pula entre apoios (chão, paredes, teto) e só usa trechos que passam longe do bloco. O ataque sai do apoio em frente à face, em linha reta: cai do teto na face de cima, sai das paredes para as laterais, sobe do chão para a de baixo.
- Se o jogador gira durante o aviso e a face mirada ganha espinhos, ele troca de alvo.
- Atingido, perde um coração, é arremessado e fica tonto no chão (1,25 s, sem machucar). Sem corações, some e a porta abre.
- As nozes (10 px, lentas: arco de ~1,5 s) saem no meio dos saltos, em direção ao coelho; quicam e quebram no terceiro toque ou ao encostar nos espinhos do bloco.

**Rodada 28 (D67): vida e balanceamento.**
- **Noz ("3 hits"):** gira no ar; a cada batida perde força e giro e muda de cara (calma, irritada, rachada e furiosa); quebra na terceira.
- **Bomba ("1 hit blow"):** a partir do segundo coração, alterna com a noz. Vai em linha reta (85 px/s) até onde o coelho estava e explode no primeiro contato; fere num raio de 14 px. Tem óculos escuros e sorriso, como o Jeffrey. Ele não joga bomba a menos de 50 px do coelho.
- **Arremessos:** só nos saltos de zigue-zague, nunca a caminho do ataque.
- **Jeffrey:** desenhado com ~20 px (colisão de 12), óculos escuros e sorriso de dentes. Rabo que segue o corpo com atraso; corridinha de esquilo (dispara e para); vira bola girando no ar, com rastro; amassa ao pousar; pés viram para a parede ou o teto; treme, agacha e arrepia o rabo ao mirar; tonto com óculos tortos e estrelinhas; ri quando o coelho morre; mais descabelado a cada coração perdido.

**Em aberto:**
- Tudo isto precisa ser sentido jogando: janelas, velocidade no chão, quantidade de nozes.
- Noz parada no chão: hoje ela quica até quebrar; não fica parada servindo de apoio.
- A entrada: o coelho ainda começa no chão; a queda na sala e a entrada do esquilo podem virar uma pequena cena.
- Arte e efeitos sonoros próprios (hoje: desenho em código e efeitos reaproveitados). A música é a do Victor: `music/boss-rush-groove.mp3`, em loop.
- Opcional, para trazer de volta o "tudo que está solto cai": nozes presas nas faces do bloco caem quando ele gira.

**Implementação:** a grade é uma sala comum (`levels/campaign/jeffrey.json`) com dois campos novos: `spin_block` (o giro mira o bloco, não a sala) e `actors` (scripts que a sala cria e chama a cada quadro). O esquilo, as nozes e os corações ficam em `scripts/boss_squirrel.gd`; a sala só oferece o bloco, `kill()` e `door_unlocked`.

## 8c. Boss 2 — Gatsby, o texugo (conceito; D72)

**Estado: fase jogável (D75).** A fase está em `levels/wip/gatsby.json` (gerada por `tools/gatsby_level.py`) e se joga com `./run.ps1 -Play gatsby` ou, na web, `?play=gatsby`. Um robô (`tools/gatsby_robot.gd`) a vence em 40,6 s, e os testes rodam a rota dele. **Ninguém jogou ainda.** Falta a música (Victor) e o editor editar placas, conectores, chapas e roteiro.

**A corrida, trecho a trecho (D75).** A ideia de design: cada trecho usa uma mecânica de um jeito só, curto, e o que o Gatsby faz para atrapalhar é o que leva o coelho para cima.

| Trecho | O que acontece | Mecânica |
|---|---|---|
| Cena | O Gatsby puxa a alavanca; a placa feliz acorda sob o chão e o come em uns 6 s | placa |
| Poço 1 | Três patamares em zigue-zague | pulo |
| Poço 2 | Escada de chapas soltas: cada uma desaba 0,4 s depois de pisada | chapas soltas |
| Poço 3 | O Gatsby dispara um pistão para esmagar o coelho; o pistão o arremessa 12 tiles | catapulta (conector laranja) |
| Poço 4 | Nada para pular: girar no sentido horário e correr pela parede da direita; ao desfazer, o coelho cai numa plataforma que só é chão com a sala em pé | giro com limitador + plataforma por orientação |
| Poço 5 | Travessia no plano sobre chapas soltas (a placa desacelera aqui) | chapas soltas |
| Poço 6 | A mesma corrida, na parede da esquerda (giro anti-horário) | giro com limitador |
| Poço 7 | Um varredor de espinhos corre pelo patamar: pular por cima | conector rosa, em ritmo |
| Poço 8 | Segunda catapulta, para dentro do corredor | conector ciano |
| Corredor 1 | A placa triste acorda. Ponte de chapas soltas sobre espinhos, com dois vãos | chapas soltas |
| Corredor 2 | Três estampadores alternados | conectores verdes, em ritmo |
| Corredor 3 | O Gatsby gira a sala: o corredor vira um poço e o coelho cai 34 tiles até um degrau; ele desgira | giro do Gatsby |
| Corredor 4 | Ponte final que desaba; o Gatsby entra em pânico e foge; a porta | chapas soltas |

**Urgência (D75):**
- A placa tem a guia curta (88 px no poço): quem sobe rápido não a deixa para trás; ela fica sempre na borda da tela. A velocidade base é baixa (8 a 12 px/s), para a pressão vir de vê-la, não de ser impossível.
- **Perigo** (`room.danger`, 0 a 1): com a placa perto, a borda da tela de onde ela vem pulsa em vermelho, o ronco dela cresce e sobe de tom, e um alarme toca cada vez mais depressa.
- A placa faz barulho ao mastigar a sala e ruge ao acordar.
- As chapas soltas não deixam parar; os conectores avisam antes de se mexer (os encaixes piscam e bipam por 0,27 s), o que deixa o ritmo legível mesmo correndo.

**O Gatsby (D75):** voa **à frente** do coelho, no rumo da próxima área do roteiro, com um balanço de lado, e prefere o ar livre a ficar dentro das paredes. **Nunca encosta no coelho:** a distância entre os centros nunca fica abaixo de 50 px (a cápsula inteira, com a chama, cabe em 35), em qualquer fase do roteiro; se o coelho vem para cima, ele dá um arranque. Ao puxar a alavanca, a antena e o punho acendem na cor do canal e um raio dessa cor liga a nave às peças acionadas. Ri quando o coelho morre.

**Quem é:** um texugo extremamente inteligente, que opera engenhocas de dentro de uma cápsula voadora. O propulsor fica embaixo da cápsula e se inclina no sentido oposto ao do movimento. As alavancas ficam **dentro da nave**; só ele as usa. É a estrela da fase e um chefe para o futuro: aqui o jogador **nunca o alcança**.

**A fase é uma fuga pura,** sem dano ao Gatsby e sem desfecho de luta. Uma sala só, gigante, em forma de L:

1. **Cutscene:** o coelho entra pela porta; Gatsby aparece na cápsula e puxa a alavanca que acorda a placa de espinhos sob o chão.
2. **Fase 1, a subida:** um poço alto. A placa (carinha feliz) sobe e destrói tudo o que alcança. Gatsby voa à frente, puxando alavancas que mudam plataformas de lugar.
3. **Fase 2, a virada:** no topo, o caminho dobra para a direita e vira um corredor. Outra placa (carinha triste) vem da esquerda.
4. **Final:** o coelho quase alcança o Gatsby, que sai voando.

**O giro nesta fase:**
- **Giro do coelho, com limitador:** dura 2,5 s e a sala volta sozinha. No poço, a parede vira chão por um instante: dá para correr por ela (correr é bem mais rápido que subir pulando) ou cruzar um trecho sem plataformas. As placas giram junto com a sala.
- **Giro do Gatsby:** ele também gira a sala, contra o jogador, e esse giro fica. O mesmo trecho pode virar subida, corrida ou queda.

**Humor do Gatsby,** que muda conforme a fase avança: entediado e arrogante (tomando chá) → divertido → irritado → furioso e descabelado → nervoso, olhando para trás → pânico → um sorrisinho ao fugir. A cápsula fica sempre em pé; a cada giro ele é jogado lá dentro.

**As placas** são engenhocas dele, só cenário: não têm nome nem personalidade além da carinha.

**Visual do ato 2 (Victor):** tudo o que é do Gatsby tem cara industrial: aço em chapas remendadas, rebites, remendos enferrujados. A carinha da placa é **pichada** com tinta clara (escorrida, com respingos) e é **fixa**: pintada no meio da placa, não acompanha o coelho e gira com a sala. O Gatsby é do ato 2 do jogo, e o visual das coisas muda com ele.

**Componentes novos (reutilizáveis):**

| Componente | O que é |
|---|---|
| Placa de espinhos | Avança a partir de um lado, numa faixa da sala, com velocidade própria; mata e destrói tiles, caixas e o que mais alcançar. Gira com a sala. Serve para fases de fuga sem boss. |
| Bloco motorizado | Bloco sólido (pode ter espinhos numa face) que vai de uma posição a outra quando o canal dele é acionado. Quem aciona é um ator, não uma peça da sala. |
| Giro forçado por ator | Um ator pede o giro da sala; não gasta nem respeita a recarga do coelho. |
| Ator com roteiro | Ações disparadas pelo avanço do coelho (não pelo relógio): voar até um ponto, acionar um canal, girar a sala, mudar de expressão. |
| Cutscene curta | Trava a entrada, move a câmera e os atores, toca sons. Serve também para a entrada do Jeffrey. |

**Sem checkpoint por enquanto** (Victor): morrer recomeça a fase inteira.

**Em aberto:**
- Velocidade das placas. Ponto de partida: 8 a 10 px/s na subida (o coelho sobe uns 25 a 30 px/s numa escada ideal), sem deixar a placa sair da tela.
- Quantos giros do Gatsby, e onde.
- Tamanho da sala e como o editor se comporta com ela.

## 8d. Ato 2: as 5 fases industriais (D76, D77)

**Estado: cinco rascunhos jogáveis**, em `levels/wip/` (fora da história), cada um provado por um robô (`tools/robot.gd`) e testado. Ninguém jogou ainda. Para jogar: `./run.ps1 -Play montagem` (ou `esteiras`, `prensas`, `dutos`, `forca`) ou, na web, `?play=montagem`. Para colocá-las na história depois do Jeffrey: abrir no editor, jogar e vencer, e canonizar (Campanha…).

| Fase | Tamanho | Baterias | Tempo do robô | Como é |
|---|---|---|---|---|
| `montagem` · Linha de montagem | 80×40 | 1 | 26 s | Degraus até uma plataforma em ciclo sobre espinhos, um elevador e uma subida de 5 saltos de 3 tiles até a bateria. A caixa cai da calha no compartimento ao lado da porta. |
| `esteiras` · Esteiras | 100×44 | 2 | 17 s | Três esteiras (contra, a favor, contra) e uma ponte de chapas soltas sobre um lago de ácido; uma bateria em cada trecho. A caixa viaja por uma esteira e cai entre duas paredes no compartimento. |
| `prensas` · Prensas e vapor | 110×50 | 2 | 29 s | Três prensas em ritmo; um botão chama o elevador (parte depois de 1 s, com aviso); no alto, um corredor com quatro jatos de vapor defasados. |
| `dutos` · Dutos | 80×70 | 3 | 16 s | Subida de 57 tiles em três ramais sobre espinhos: molas, uma coluna de ar, um elevador e outra coluna de ar. |
| `forca` · Casa de força | 130×50 | 3 | 33 s | Mistura de tudo, em ziguezague até o alto. No corredor final o Gatsby aparece rápido, puxa uma alavanca e liga a parede de espinhos (36 px/s; o robô nunca chega a menos de 83 px dela). |

**Decididas por Claude, abertas a revisão:** nenhuma das cinco usa o giro (`rotate: false`), como as fases iniciais do jogo: o foco é plataforming; o tema `industrial` está ligado em todas; o ácido só aparece na fase 2 (um fluido por sala); a caixa só viaja de verdade na 2 (esteira) e na 5 (esteira, com a parede atrás), nas outras cai direto da calha; os valores de velocidade e de ritmo são palpites a ajustar jogando.

**Ordem:** as 15 iniciais, o Jeffrey, **estas cinco**, e então o Gatsby (a fuga). As cinco entram **imediatamente depois do Jeffrey**. Tema industrial do Gatsby (aço remendado, rebites, ferrugem).

**O loop:** o coelho pega de 1 a X **baterias** (X vale 1, 2, 2, 3 e 3 nas cinco fases). Com todas, a **alavanca se ativa sozinha** (a câmera vai até ela e volta), e a **calha** solta uma **caixa**. A caixa vai ao compartimento, e a porta abre. **Sem checkpoint:** morrer volta ao início da fase (D73 continua valendo).

**Foco:** plataforming pesado em fases grandes (de 80×40 a 130×50, de duas a quatro telas de largura), com seções dinâmicas.

| Fase | Tamanho | Baterias | Peças novas | Plataforming | A caixa |
|---|---|---|---|---|---|
| 1 Linha de montagem | 80×40 | 1 | bateria, alavanca, calha, plataforma em ciclo | saltos de 3 a 4 tiles, plataformas em vai-e-vem | cai perto do compartimento; ensina o ciclo |
| 2 Esteiras | 100×44 | 2 | esteira | pular contra e a favor das esteiras, chapas soltas | calha distante; viaja por esteiras e pontes |
| 3 Prensas e vapor | 110×50 | 2 | jato de vapor, botão de pressão | estampadores e vapor em ritmo, elevador por botão, catapulta | calha no alto; o giro derruba a caixa pelo poço |
| 4 Dutos | 80×70 | 3 | ventilador, mola | subida vertical em três ramais, uma bateria por ramal, corrida pela parede | sobe por uma corrente de ar até a porta |
| 5 Casa de força | 130×50 | 3 | (mistura) | todas as mecânicas | ao pegar a 3ª bateria a placa acorda e o jogador corre com a caixa |

**Ácido (Victor):** água verde que **mata o coelho ao toque**. Mesma física da água (escorre, nivela, gira com a sala), mas não se nada nela. Entra como componente de sala e é usado nas fases a partir da 2.

**Gatsby nas cinco fases:** aparece **só na fase 5, bem rápido**, ativando a placa de espinhos (ensaio da fuga).

**Régua de plataforma (medida no jogo):** salto máximo de 30 px de altura (3,75 tiles) e 52 px de alcance (6,5 tiles). Degrau máximo: 3 tiles. Vão confortável: 4 a 5 tiles; 6 tiles só a partir da fase 4, com pouso de 2 tiles. Catapulta: de 9 a 15 tiles.

**Componentes novos (todos de sala, reutilizáveis, com sons e suporte no editor):**

| Componente | O que é |
|---|---|
| Tema `industrial` | Campo da fase: paredes de chapa rebitada, dutos e lâmpadas ao fundo, listras de aviso nos perigos |
| Bateria | Coletável; acende uma vaga da alavanca |
| Alavanca e calha | Mostra as vagas; com todas cheias, puxa sozinha e solta a caixa |
| Ácido | Fluido verde que mata ao toque |
| Gatilhos dos conectores | Ciclo automático, botão de pressão (coelho ou caixa), acionamento por bateria |
| Esteira | Carrega coelho e caixa, com direção e velocidade |
| Jato de vapor | Perigo periódico, com chiado de aviso |
| Ventilador | Corrente de ar para cima; leva coelho e caixa |
| Mola | Trampolim fixo, sem conector |

**Ordem de trabalho (Victor: editor primeiro):** peças na sala → editor com todas elas → as fases (rascunhos provados por robô; o Victor refina no editor, grava os replays e canoniza). **Feito (D77).**

## 9. Decisões

O registro completo, com motivos e alternativas, está em [DECISOES.md](DECISOES.md). Resumo do que afeta o design:

| Decisão | Estado |
|---|---|
| Giro no ar, um por pulo | adotado |
| Caixa esmaga o coelho | adotado |
| Porta fechada é sólida | revertido: ela não é sólida (D34) |
| Recarga do giro com barra e som | adotado (pedido no primeiro teste) |
| Salas de tamanho variado, não só 1:1 | implementado (D39) |
| Câmera segue o coelho em salas grandes | implementado (D39) |
| Piloto com 5 salas longas | substituído: 10 níveis com dificuldade crescente (D42) |
| Etapas bloqueadas por comportas | implementado (D37) |
| Plataformas por orientação | implementado (D38) |
| Tema de laboratório | em aberto |

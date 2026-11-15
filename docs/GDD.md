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
- Ao fim do giro, a velocidade do coelho e das caixas zera, e tudo cai a partir do repouso.
- **Giro no ar:** um por pulo, recarrega ao tocar o chão.
- **Recarga do giro:** depois de cada giro, um novo giro fica bloqueado por 0,87 s (animação incluída). Uma barra branca no canto inferior direito enche durante a recarga, com um som que fica mais agudo; um "plim" avisa quando está pronto.

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

### 3.5 Controles

| Ação | Teclado | Controle |
|---|---|---|
| Andar | A/D ou setas | Analógico ou direcional |
| Pular | Espaço | A |
| Girar anti-horário / horário | Q / E | LB / RB |
| Reiniciar sala | R | Y |

### 3.6 Estética

- Resolução interna de 320×180, escala inteira.
- Tiles de 8 px; salas de qualquer tamanho; coelho e caixa com cerca de 16×16 px.
- Salas maiores que a tela: a câmera segue o coelho, com suavização, e para nas bordas da sala. No eixo em que a sala cabe, ela fica centralizada.
- Fundo preto, linhas off-white.
- Cores reservadas: caixa azul, porta amarela (aberta) e azul-acinzentada (trancada), compartimento cinza, comporta verde-água, plataforma por orientação lilás, espinhos coral, olho vermelho do coelho.
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
  levels.gd            # as salas, desenhadas em texto (qualquer tamanho)
  input_setup.gd       # teclas e controle registrados em código
tests/
  run_tests.gd         # formato das salas, pulo e bots que resolvem cada sala
  shot.gd              # capturas de tela de cada sala
assets/                # (M5) sprites e áudio
```

As salas são texto em `levels.gd` em vez de cenas `.tscn`: dá para editar e revisar como código, e os testes conseguem carregar qualquer sala sem abrir o editor. Há um campo `start_rot` para desenhar a sala na orientação em que ela é resolvida e começar girada.

## 5b. Abertura

Esboço em `start-screen.jpeg`; detalhes em D46.

- **Tela de início:** fundo preto, título "FREE", "PRESS ENTER" piscando e uma janela com o coelho num campo verde e ensolarado, o único cenário colorido do jogo.
- **Cutscene:** um buraco se abre sob o coelho, ele se assusta ("!"), cai e some; a janela se apaga; ele cai girando no vazio até pousar numa pequena plataforma branca, que se expande até virar um quadrado com uma porta.
- **Sala de início:** esse quadrado é jogável. O jogador anda até a porta e começa o nível 1.
- Enter de novo pula a cutscene. A abertura não tem música, só efeitos (a música virá depois).

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

## 8. Expansões (fora do piloto)

- **Tipos de caixa:** pesada (esmaga espinhos), de vidro (quebra na queda), magnética (gruda na parede), balão (cai para cima).
- **Regras de rotação:** giros limitados por sala, giro de 180°, setores que giram separados, zonas que bloqueiam o giro, momento preservado após o giro.
- **Cenário:** água que escorre com a gravidade, botões de peso, segunda cor de caixa, zonas onde o giro é proibido, inimigos que também caem. (Plataformas por orientação e comportas já entraram no piloto.)
- **Rejogabilidade:** cronômetro de speedrun, cenouras colecionáveis em rotas arriscadas, versões difíceis das salas.
- **Narrativa:** coelho de laboratório fugindo de câmaras de teste, o que justifica o visual estéril e as salas que giram.

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

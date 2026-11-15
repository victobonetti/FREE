# Documento de design — piloto

> Nome do jogo: a definir.
> Estado: **M0 a M4 implementados** e primeira rodada de retorno aplicada. Pendente: redesenho das salas e M5 (arte, áudio, polimento).
> Referência visual: `concept.png` (raiz do projeto).
> Este arquivo é o design. Decisões e motivos: [DECISOES.md](DECISOES.md). Código: [ARQUITETURA.md](ARQUITETURA.md). O que foi feito e o que falta: [HISTORICO.md](HISTORICO.md). Como rodar: [README.md](README.md).

## 1. Visão

Um coelho em pixel art precisa fugir atravessando salas cada vez mais difíceis. O ambiente é quase monocromático, mas suave. O jogador pode **girar a sala inteira de 90 em 90 graus**; tudo que está solto cai. Para abrir a porta de cada sala, é preciso encaixar uma caixa em um compartimento e mantê-la lá.

Referências de sensação de controle: Celeste e Super Meat Boy.

**Escopo do piloto:** 5 salas, jogáveis do início ao fim, com controle polido.

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

### 3.5 Controles

| Ação | Teclado | Controle |
|---|---|---|
| Andar | A/D ou setas | Analógico ou direcional |
| Pular | Espaço | A |
| Girar anti-horário / horário | Q / E | LB / RB |
| Reiniciar sala | R | Y |

### 3.6 Estética

- Resolução interna de 320×180, escala inteira.
- Tiles de 8 px; sala de 20×20 tiles (160×160 px); coelho e caixa com cerca de 16×16 px.
- Fundo preto, linhas off-white.
- Cores reservadas: caixa azul, porta amarela (aberta) e azul-acinzentada (trancada), compartimento cinza, olho vermelho do coelho.
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
  levels.gd            # as salas, desenhadas em texto (20x20)
  input_setup.gd       # teclas e controle registrados em código
tests/
  run_tests.gd         # formato das salas, pulo e bots que resolvem cada sala
  shot.gd              # capturas de tela de cada sala
assets/                # (M5) sprites e áudio
```

As salas são texto em `levels.gd` em vez de cenas `.tscn`: dá para editar e revisar como código, e os testes conseguem carregar qualquer sala sem abrir o editor. Há um campo `start_rot` para desenhar a sala na orientação em que ela é resolvida e começar girada.

## 6. As 5 salas

Cada sala introduz uma ideia. A dificuldade cresce porque as ideias se combinam.

Vocabulário: um **buraco** é um compartimento aberto para cima (a caixa cai nele); um **nicho** é um compartimento aberto para o lado, com teto (a caixa entra empurrada ou por gravidade lateral). Um buraco só derrama a caixa com a gravidade para cima; um nicho só derrama com a gravidade para o lado da abertura.

| # | Nome | Ensina | Como funciona (implementado) |
|---|---|---|---|
| 1 | Toca | Andar, pular, empurrar; compartimento abre a porta | Sem rotação. A caixa é empurrada para um buraco no chão; a porta fica em um degrau logo depois. |
| 2 | Vertigem | Girar; tudo que está solto cai | A sala de `concept.png`: começa girada, com o compartimento no canto superior direito. Um giro horário coloca o coelho e a caixa em queda; ele precisa passar para o lado esquerdo da caixa, empurrá-la até o nicho e subir na plataforma da porta. |
| 3 | Derrame | A porta fecha de novo; o sentido do giro importa | Encaixada a caixa, a porta está pendurada no teto e pede 180°. Girar duas vezes no sentido horário mantém tudo; girar no sentido anti-horário derrama a caixa e fecha a porta. |
| 4 | Espinhos | Morte e giro no ar | Um campo de espinhos de 6 tiles separa o coelho do buraco. Pular e girar no ar cruza por cima, e a caixa atravessa pelo chão e cai no buraco. A porta fica do lado de onde o coelho veio, então a volta é outro pulo com giro no sentido oposto. Girar do chão mata. |
| 5 | Fuga | Síntese | A sala 4 com uma segunda caixa e um segundo buraco ao lado da porta. A caixa da esquerda tem de ser encaixada antes de cruzar. As duas abrem a porta. |

Todas as salas foram resolvidas por bots em `tests/run_tests.gd`. A sala 5 está pouco diferente da 4; ela é o ponto mais fraco do piloto e o primeiro candidato a redesenho (ideias: espinhos na parede para forçar a altura do pulo, a segunda caixa só alcançável depois do cruzamento).

### Redesenho previsto (decidido, ainda não implementado)

As salas acima foram consideradas monótonas no primeiro teste. O piloto continua com 5 salas, mas elas serão refeitas com estas regras (motivos em [DECISOES.md](DECISOES.md), D23 a D26):

- **Mais longas e em etapas:** cada sala encadeia três ou quatro ideias, separadas por portas intermediárias.
- **Tamanhos variados:** corredores largos, poços altos e salas maiores que a tela. Girar uma sala larga a transforma em um poço.
- **Câmera segue o coelho** quando a sala passa da tela; o pixel art não muda de tamanho.
- **Mais plataforma:** trechos de pulo entre os momentos de puzzle, com espinhos em paredes e tetos que viram chão ao girar.
- **Dois elementos novos:** plataformas que só são sólidas em certa orientação, e portas intermediárias.
- **Fora por enquanto:** botões de peso, segunda cor de caixa, zonas onde o giro é proibido.

O desenho sala por sala ainda será detalhado.

## 7. Etapas de implementação

| Etapa | Entrega | Critério de pronto | Estado |
|---|---|---|---|
| M0 | Projeto Godot configurado | Janela abre em 320×180 com escala inteira | feito |
| M1 | Controlador do coelho | Andar e pular em uma sala de teste, com todas as tolerâncias da seção 3.1 | feito (falta ajuste por quem joga) |
| M2 | Rotação | Giro para os dois lados, coelho cai para o novo chão, giro no ar funciona | feito |
| M3 | Caixa, compartimento, porta, espinhos | Sala 2 jogável do início ao fim | feito |
| M4 | As 5 salas em graybox | Sequência completa jogável, com morte e reinício | feito (resolvidas por bots; ninguém jogou ainda) |
| M5 | Arte, áudio e polimento | Sprites, partículas, sons e transições entre salas | pendente |

A sensação de controle é ajustada em M1 e M2, antes de qualquer fase ou arte. O coelho já tem um sprite provisório de 14×14 desenhado em código.

### Atalhos de desenvolvimento

PageDown e PageUp pulam entre salas. R reinicia a sala.

## 8. Expansões (fora do piloto)

- **Tipos de caixa:** pesada (esmaga espinhos), de vidro (quebra na queda), magnética (gruda na parede), balão (cai para cima).
- **Regras de rotação:** giros limitados por sala, giro de 180°, setores que giram separados, zonas que bloqueiam o giro, momento preservado após o giro.
- **Cenário:** água que escorre com a gravidade, botões de peso, plataformas que só existem em certa orientação, inimigos que também caem.
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
| Salas de tamanho variado, não só 1:1 | decidido; implementação pendente |
| Câmera segue o coelho em salas grandes | decidido; implementação pendente |
| Piloto com 5 salas longas | decidido; implementação pendente |
| Novos elementos: plataformas por orientação e portas intermediárias | decidido; implementação pendente |
| Tema de laboratório | em aberto |

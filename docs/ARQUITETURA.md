# Arquitetura

Como o código funciona hoje. Os motivos de cada escolha estão em [DECISOES.md](DECISOES.md).

## Arquivos

```
project.godot            320×180, escala inteira, filtro "nearest", 60 Hz
scenes/main.tscn         só instancia scripts/main.gd
scripts/
  main.gd                sequência de salas, leitura de entrada, transições, barra e som do giro
  room.gd                uma sala: tiles, rotação, câmera, caixas, compartimentos, porta, espinhos,
                         comportas, plataformas por orientação, desenho
  rabbit.gd              controlador do coelho
  box.gd                 dados de uma caixa
  levels.gd              as salas em texto
  input_setup.gd         teclas e botões
tests/
  run_tests.gd           testes sem janela
  shot.gd                capturas de tela
music/                   trilha sonora (MP3/OGG); importada pelo Godot com loop
docs/                    esta documentação
```

Nenhum script usa `class_name`; tudo é carregado com `preload`. A árvore de nós é montada em código: `Main` cria a `Room` (um `Node2D`) e uma `CanvasLayer` com título, barra do giro, tela final e fade.

## Ciclo de um quadro

`main.gd` roda em `_physics_process` (60 Hz):

1. Lê a entrada e monta um dicionário: `move` (-1 a 1), `jump_pressed`, `jump_held`, `rotate` (-1, 0 ou 1).
2. Chama `room.step(inp)`.
3. Atualiza a barra e o som do giro a partir de `room.rot_lock`.

`room.step` é a única porta de entrada da simulação. Os testes chamam a mesma função com entradas fabricadas, por isso a sala não lê o teclado diretamente.

Ordem dentro de `step`:

1. Partículas e contadores visuais.
2. Estados `won` e `dead`: só contam o tempo (animação da porta, respawn).
3. Recarga do giro (`rot_lock`), pedido de giro, animação do giro. Durante a animação a simulação não roda.
4. Comportas e plataformas mudam de estado (`_update_mechanisms`).
5. Coelho (`rabbit.update`).
6. Caixas, de baixo para cima.
7. Compartimentos e estado da porta (`_update_sockets`).
8. Câmera.
9. Espinhos.
10. Vitória (coelho encosta na porta aberta).

## Rotação

- A simulação **sempre** tem gravidade para baixo.
- `_rotate_logic(dir)` rotaciona todos os dados: a grade de tiles, e cada retângulo (caixas, compartimentos, porta, espinhos, comportas, plataformas, coelho) com `_rot_rect`; a câmera e as partículas com `_rot_point`.
  - Com a sala de `W×H` pixels: horário `(x, y) → (H − y, x)`; anti-horário `(x, y) → (y, W − x)`. Depois, largura e altura trocam (`gw`/`gh`, `pw`/`ph`).
  - A direção (`facing`) de espinhos e plataformas soma +1 no horário e −1 no anti-horário.
  - Tudo em inteiros. Quatro giros voltam exatamente ao estado inicial (há teste).
- `_begin_rotate` faz a rotação lógica na hora e põe `view_angle = ∓90°`. O desenho usa esse ângulo e o leva até 0 em 16 quadros, com easing cúbico. Na tela parece que a sala girou; nos dados ela já estava girada desde o primeiro quadro.
- O sprite do coelho é desenhado com a rotação contrária, para ficar sempre em pé.
- Um giro é aceito se `rot_lock == 0`, a sala permite (`rotate` na definição) e o coelho está no chão ou ainda tem o giro do ar.
- `rot_lock` começa em 52 (16 + 36) e desce 1 por quadro. `rot_ratio()` devolve de 0 a 1 para a barra.

## Câmera

- `cam` é o ponto da sala (em pixels lógicos) que fica no centro da tela. A `Room` está no centro da tela (160, 90) e o desenho usa `Rot(view_angle) * Translate(−cam)`.
- `_cam_target()`: no eixo em que a sala cabe em 320×180, o centro da sala; no outro, o coelho, limitado para não mostrar além da borda.
- `_update_camera()` aproxima `cam` do alvo em 12% por quadro. Durante a animação do giro a câmera não anda; ela foi rotacionada junto com a sala, o que mantém a imagem contínua.
- Ao reiniciar a sala, `cam` vai direto para o alvo.

## Coelho (`rabbit.gd`)

- Hitbox 12×12, posição inteira (`pos`), frações acumuladas em `rem`.
- Move primeiro em X, depois em Y, um pixel por vez, testando colisão a cada passo.
- Ao andar contra uma caixa, chama `room.push_box`; a caixa anda 1 px junto. No chão, a velocidade cai para `PUSH_SPEED`.
- Todas as constantes de sensação estão no topo do arquivo:

| Constante | Valor | Efeito |
|---|---|---|
| `MAX_SPEED` | 72 px/s | velocidade andando |
| `PUSH_SPEED` | 36 px/s | velocidade empurrando |
| `GROUND_ACCEL` / `GROUND_DECEL` | 800 / 650 | arrancada e parada no chão |
| `AIR_ACCEL` / `AIR_DECEL` | 520 / 260 | controle no ar |
| `JUMP_SPEED` | 110 px/s | velocidade de subida |
| `VAR_JUMP_FRAMES` | 12 | por quanto tempo segurar o botão mantém a subida |
| `GRAVITY` | 900 px/s² | |
| `APEX_MULT` / `APEX_THRESHOLD` | 0,5 / 40 | gravidade reduzida perto do ápice |
| `MAX_FALL` | 160 px/s | queda máxima |
| `COYOTE_FRAMES` / `BUFFER_FRAMES` | 6 / 6 | tolerâncias do pulo |
| `CORNER_CORRECT` / `LEDGE_ASSIST` | 4 / 3 px | desvio de quina e ajuda de degrau |

Medido pelos testes: pulo longo 30 px, pulo curto 8 px. Degraus de até 3 tiles (24 px) são alcançáveis.

## Caixas

- 16×16, posição inteira. Só se movem empurradas (horizontal) ou caindo (vertical).
- Apoio: só a faixa central de 10 px da base conta. Sem apoio, a caixa cai; se esbarrar em uma borda, é deslocada até 4 px para o lado para encaixar (`_box_nudge`).
- Sólidos para a caixa: paredes e outras caixas. Porta, espinhos e o coelho não.
- Se a caixa desce sobre o coelho, empurra-o para baixo; se ele não tem para onde ir, morre.
- `settled` fica verdadeiro quando a caixa está apoiada. Só caixa parada ativa compartimento.

## Compartimentos, porta, comportas, plataformas e espinhos

- Compartimento: retângulo 16×16 com um grupo (`socket_group`): 0 é a porta, 1–9 é a comporta de mesmo número. Ocupado quando uma caixa parada está a até 3 px da posição dele. `group_filled(n)` diz se todos os compartimentos do grupo estão ocupados.
- Porta: retângulo de qualquer tamanho. Aberta quando o grupo 0 está completo. Nunca é sólida; fechada, é só desenhada translúcida e não faz nada.
- Comporta: dicionário com `id`, `rects` (tiles), `closed`, `anim` (0 fechada, 1 aberta, só visual) e `fx`. Fechada, entra em `solid_static`. Quer fechar quando o grupo dela não está completo; só fecha se nenhum tile estiver ocupado (`_occupied`).
- Plataforma por orientação: dicionário com `rect`, `facing`, `solid` e `fx`. Quer ser sólida quando `facing == 0`; só fica sólida se o tile estiver livre. Sólida, entra em `solid_static`.
- `solid_static(r)`: paredes, comportas fechadas e plataformas sólidas.
- Espinho: um tile com direção. A área que mata é a metade do lado da base.
- Estados da sala: `play`, `dead` (20 quadros, depois reinicia), `won` (44 quadros de animação), `done` (emite `completed`).

## Formato das salas (`levels.gd`)

Grade de tiles de 8 px, de qualquer tamanho: todas as linhas com o mesmo comprimento, cercadas de parede (o teste de formato verifica).

| Símbolo | Significado |
|---|---|
| `#` | parede |
| `.` | vazio |
| `P` | coelho, em bloco 2×2 |
| `B` | caixa, em bloco 2×2 |
| `S` | compartimento da porta, em bloco 2×2 |
| `D` | porta; todas as células `D` formam um retângulo |
| `1`–`9` | comporta |
| `a`–`i` | compartimento de comporta, em bloco 2×2 (`a` abre `1`, `b` abre `2`...) |
| `=` `}` `_` `{` | plataforma por orientação, seta para cima, direita, baixo, esquerda |
| `^` `>` `v` `<` | espinho apontando para esse lado |

Campos por sala: `name`, `rotate` (permite girar), `start_rot` (giros de 90° aplicados ao carregar; positivo é horário), `rows`, e `hint` (opcional: texto de ajuda que `main.gd` mostra embaixo da tela durante a sala).

Cada sala é uma constante com nome (`PASSOS`, `TOCA`...), e `ROOMS` é a lista na ordem dos níveis. Para mudar a ordem, basta reordenar `ROOMS`; os bots procuram as salas pelo nome (`load_named`).

**Cuidado ao desenhar com `start_rot`:** o que está solto precisa estar apoiado na orientação inicial, não na desenhada. O teste "estado inicial estável" verifica isso.

**Cuidado ao desenhar com giros:** cada giro afeta a sala inteira. Uma caixa já encaixada tem de continuar segura em todas as orientações que as etapas seguintes usam (D41). Um buraco só derrama com a gravidade para cima; um nicho, com a gravidade para o lado da abertura.

**Medidas que limitam o desenho:** o coelho pula 30 px (sobe degraus de até 3 tiles) e alcança uns 5 tiles na horizontal; tem 12 px de largura e precisa de 2 tiles de vão para passar; precisa de pelo menos 2 tiles livres entre um pouso e espinhos.

## Desenho

Tudo é desenhado em `room.gd` com `_draw`, a cada quadro. A ordem importa: fundo, compartimentos, porta e feixe, **paredes**, comportas, plataformas, espinhos, caixas, molduras dos compartimentos, coelho, partículas, véus da sala inteira. A porta vem antes das paredes de propósito (D36). Fora da animação de giro, só as paredes visíveis são desenhadas.

- Paredes: preenchimento escuro, com linha off-white de 1 px em cada face exposta.
- Coelho: texturas 12×16 geradas em código a partir de três partes (`EARS`, `BODY`, `FEET`) e guardadas em cache. `_rabbit_frame` escolhe o quadro pelo estado.
- Porta aberta, partículas (poeira, morte, faíscas) e molduras dos compartimentos também são desenhadas ali.

Não há arquivos de imagem nem de som ainda. Os onze sons (tom da recarga, "plim", pulo, morte, portal, baque da caixa, dois de sensor, abrir e fechar comporta, plataforma; o baque é tocado até duas vezes, em alturas diferentes) são gerados em código em `main.gd`.

### Música

- Arquivos em `music/`. `main.gd` tem um `AudioStreamPlayer` só para música (`music`) e a função `_play_music(path)`, chamada a cada sala com o campo `music` da sala ou `Levels.DEFAULT_MUSIC`.
- Mesma faixa: continua tocando. Faixa diferente: fade de saída (0,8 s) e de entrada (1,5 s) até `MUSIC_DB` (−9 dB).
- O loop vem da importação (`loop=true` no `.import` do arquivo) e é reforçado no código.
- `tests/music_check.gd` roda o jogo sem janela e confirma que a faixa carrega, toca em loop e continua ao trocar de sala.

### Efeitos e sons

- A sala não toca áudio. Ela emite `sfx` com `jump`, `death`, `win`, `sensor_on`, `sensor_off`, `gate_open`, `gate_close` e `platform`, e o sinal `impact(strength)` para pousos de caixa; `main.gd` escuta e toca.
- Impacto da caixa: cada caixa soma `fall_dist` (pixels caídos). Ao pousar, `_box_impact` calcula a força (altura mais 60% da força recente, teto 2,5; constantes `IMPACT_*` no topo de `room.gd`) e dela derivam o solavanco (`jolt_amp`, `jolt_phase`, deslocamento vertical fixo na tela), as partículas, o tremor e o som.
- Sensor dos compartimentos: `socket_fx[i]` conta quadros do efeito; `_draw_sensor_fx` desenha o contorno e a linha de varredura. Isso mantém a sala testável sem som.
- Partículas são dicionários em `room.particles`. Com a chave `ring` viram um anel que se expande (pulo, morte).
- Tremor da morte: `shake` (px) é aplicado como deslocamento aleatório ao desenhar e decai por quadro.
- Animação do coelho: `_rabbit_frame()` escolhe o quadro. Corrida e empurrar usam `run_t` e `push_t` (tolerância de 5 quadros após o último pixel andado), para não piscar quando o coelho está bloqueado.

## Testes (`tests/run_tests.gd`)

Rodam sem janela e saem com código 1 se algo falhar. Os testes de mecânica usam salas de teste definidas no próprio arquivo (`FLAT`, `DROP`, `WIDE`, `GATE_ROOM`, `PLATFORM_ROOM`), não as salas do jogo (D40).

- Formato: cada sala é retangular, cercada de parede, tem porta, compartimento da porta, caixas suficientes, e cada comporta tem compartimento.
- Pulo: altura do pulo longo (28 a 34 px) e do curto (6 a 16 px).
- Estado inicial estável: nada se mexe sozinho ao carregar.
- Recarga do giro: bloqueia, a barra avança, libera.
- Animação: sem piscar contra a parede, empurrar alterna dois quadros.
- Sinais de som: pular, morrer e entrar no portal emitem `sfx`.
- Caixa: impacto cresce com a altura e com a quantidade de caixas, solavanco com teto e que termina, sensor liga ao encaixar.
- Rotação de sala não quadrada: troca largura e altura; quatro giros, ou ida e volta, restauram tudo.
- Câmera: não mostra além da borda, segue o coelho, respeita as bordas depois de girar, centraliza sala pequena.
- Comporta: abre e fecha com a caixa, emite som, não fecha em cima do coelho.
- Plataforma: sólida só com a seta para cima, segura caixa, não fica sólida em cima do coelho.
- Uma solução por sala, executada por bot. A sala 3 também testa o sentido errado; a sala 4 testa que girar do chão mata. Em caso de falha, a mensagem mostra onde estão o coelho e as caixas.

Ao mudar a física ou uma sala, rode os testes. Se um bot falhar, a sala pode ter ficado sem solução ou só o roteiro do bot ficou desatualizado; é preciso olhar.

Utilitários dos bots: `walk_to`, `walk_until`, `walk_jump_until` (pula sozinho ao encontrar parede), `jump`, `hop_to` (pula e se dirige no ar até um x), `rot`, `air_rot` (pula e gira no ar), `wait_ground`, `where` (descrição do estado para mensagens de erro).

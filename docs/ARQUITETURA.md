# Arquitetura

Como o código funciona hoje. Os motivos de cada escolha estão em [DECISOES.md](DECISOES.md).

## Arquivos

```
project.godot            320×180, escala inteira, filtro "nearest", 60 Hz
scenes/main.tscn         só instancia scripts/main.gd
scripts/
  main.gd                sequência de salas, leitura de entrada, transições, barra e som do giro
  room.gd                uma sala: tiles, rotação, caixas, compartimentos, porta, espinhos, desenho
  rabbit.gd              controlador do coelho
  box.gd                 dados de uma caixa
  levels.gd              as salas em texto
  input_setup.gd         teclas e botões
tests/
  run_tests.gd           testes sem janela
  shot.gd                capturas de tela
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
4. Coelho (`rabbit.update`).
5. Caixas, de baixo para cima.
6. Compartimentos e estado da porta.
7. Espinhos.
8. Vitória (coelho encosta na porta aberta).

## Rotação

- A simulação **sempre** tem gravidade para baixo.
- `_rotate_logic(dir)` rotaciona todos os dados: a grade de tiles, e cada retângulo (caixas, compartimentos, porta, espinhos, coelho) com `_rot_rect`.
  - Horário: `(x, y) → (SIZE − y, x)`. Anti-horário: `(x, y) → (y, SIZE − x)`.
  - Tudo em inteiros.
- `_begin_rotate` faz a rotação lógica na hora e põe `view_angle = ∓90°`. O desenho usa esse ângulo e o leva até 0 em 16 quadros, com easing cúbico. Na tela parece que a sala girou; nos dados ela já estava girada desde o primeiro quadro.
- O sprite do coelho é desenhado com a rotação contrária, para ficar sempre em pé.
- Um giro é aceito se `rot_lock == 0`, a sala permite (`rotate` na definição) e o coelho está no chão ou ainda tem o giro do ar.
- `rot_lock` começa em 52 (16 + 36) e desce 1 por quadro. `rot_ratio()` devolve de 0 a 1 para a barra.

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

## Compartimentos, porta e espinhos

- Compartimento: retângulo 16×16. Ocupado quando uma caixa parada está a até 3 px da posição dele.
- Porta: retângulo de qualquer tamanho. Aberta quando todos os compartimentos estão ocupados. Nunca é sólida; fechada, é só desenhada translúcida e não faz nada.
- Espinho: um tile com direção. A área que mata é a metade do lado da base.
- Estados da sala: `play`, `dead` (20 quadros, depois reinicia), `won` (44 quadros de animação), `done` (emite `completed`).

## Formato das salas (`levels.gd`)

Grade de 20 linhas por 20 colunas, tiles de 8 px.

| Símbolo | Significado |
|---|---|
| `#` | parede |
| `.` | vazio |
| `P` | coelho, em bloco 2×2 |
| `B` | caixa, em bloco 2×2 |
| `S` | compartimento, em bloco 2×2 |
| `D` | porta; todas as células `D` formam um retângulo |
| `^` `>` `v` `<` | espinho apontando para esse lado |

Campos por sala: `name`, `rotate` (permite girar), `start_rot` (giros de 90° aplicados ao carregar; positivo é horário), `rows`.

**Cuidado ao desenhar com `start_rot`:** o que está solto precisa estar apoiado na orientação inicial, não na desenhada. O teste "estado inicial estável" verifica isso.

**Limitação atual:** `GRID` e `SIZE` são constantes; todas as salas são 20×20. Salas de tamanho variado exigem mudar `room.gd` (ver D22).

## Desenho

Tudo é desenhado em `room.gd` com `_draw`, a cada quadro. A ordem importa: fundo, compartimentos, porta e feixe, **paredes**, espinhos, caixas, molduras dos compartimentos, coelho, partículas, véus de tela inteira. A porta vem antes das paredes de propósito (D36).

- Paredes: preenchimento escuro, com linha off-white de 1 px em cada face exposta.
- Coelho: texturas 12×16 geradas em código a partir de três partes (`EARS`, `BODY`, `FEET`) e guardadas em cache. `_rabbit_frame` escolhe o quadro pelo estado.
- Porta aberta, partículas (poeira, morte, faíscas) e molduras dos compartimentos também são desenhadas ali.

Não há arquivos de imagem nem de som ainda. Os oito sons (tom da recarga, "plim", pulo, morte, portal, baque da caixa e dois de sensor; o baque é tocado até duas vezes, em alturas diferentes) são gerados em código em `main.gd`.

### Efeitos e sons

- A sala não toca áudio. Ela emite `sfx` com `jump`, `death`, `win`, `sensor_on` e `sensor_off`, e o sinal `impact(strength)` para pousos de caixa; `main.gd` escuta e toca.
- Impacto da caixa: cada caixa soma `fall_dist` (pixels caídos). Ao pousar, `_box_impact` calcula a força (altura mais 60% da força recente, teto 2,5; constantes `IMPACT_*` no topo de `room.gd`) e dela derivam o solavanco (`jolt_amp`, `jolt_phase`, deslocamento vertical fixo na tela), as partículas, o tremor e o som.
- Sensor dos compartimentos: `socket_fx[i]` conta quadros do efeito; `_draw_sensor_fx` desenha o contorno e a linha de varredura. Isso mantém a sala testável sem som.
- Partículas são dicionários em `room.particles`. Com a chave `ring` viram um anel que se expande (pulo, morte).
- Tremor da morte: `shake` (px) é aplicado como deslocamento aleatório ao desenhar e decai por quadro.
- Animação do coelho: `_rabbit_frame()` escolhe o quadro. Corrida e empurrar usam `run_t` e `push_t` (tolerância de 5 quadros após o último pixel andado), para não piscar quando o coelho está bloqueado.

## Testes (`tests/run_tests.gd`)

Rodam sem janela e saem com código 1 se algo falhar.

- Formato: cada sala tem 20×20, porta, compartimento e caixas suficientes.
- Pulo: altura do pulo longo (28 a 34 px) e do curto (6 a 16 px).
- Estado inicial estável: nada se mexe sozinho ao carregar.
- Recarga do giro: bloqueia, a barra avança, libera.
- Animação: sem piscar contra a parede, empurrar alterna dois quadros.
- Sinais de som: pular, morrer e entrar no portal emitem `sfx`.
- Caixa: impacto cresce com a altura e com a quantidade de caixas, solavanco com teto e que termina, sensor liga ao encaixar.
- Uma solução por sala, executada por bot. A sala 3 também testa o sentido errado; a sala 4 testa que girar do chão mata.

Ao mudar a física ou uma sala, rode os testes. Se um bot falhar, a sala pode ter ficado sem solução ou só o roteiro do bot ficou desatualizado; é preciso olhar.

# Arquitetura

Como o código funciona hoje. Os motivos de cada escolha estão em [DECISOES.md](DECISOES.md).

## Arquivos

```
project.godot            320×180, escala inteira, filtro "nearest", 60 Hz
export_presets.cfg       exportação Web (sem threads) e Windows (D45)
build/                   saída da exportação; ignorada pelo Godot (.gdignore) e pelo git
.gitignore               ignora .godot/ (cache) e build/; os arquivos .import ficam no git
                         porque guardam configurações de importação (ex.: loop da música)
scenes/main.tscn         só instancia scripts/main.gd
scripts/
  main.gd                sequência de salas, leitura de entrada, transições, barra e som do giro
  room.gd                uma sala: tiles, rotação, câmera, caixas, compartimentos, porta, espinhos,
                         comportas, plataformas por orientação, cordas, água, ralos, desenho
  intro.gd               tela de início e cutscene de abertura (D46)
  rabbit.gd              controlador do coelho
  box.gd                 dados de uma caixa
  levels.gd              as salas em texto
  input_setup.gd         teclas e botões
  touch_controls.gd      joystick e botões de toque (D61)
  boss_squirrel.gd       boss 1, Jeffrey: ator da sala 17 (D64)
tests/
  run_tests.gd           testes sem janela
  shot.gd                capturas de tela
music/                   trilha sonora (MP3/OGG); importada pelo Godot com loop
docs/                    esta documentação
```

Nenhum script usa `class_name`; tudo é carregado com `preload`. A árvore de nós é montada em código: `Main` cria a `Room` (um `Node2D`) e uma `CanvasLayer` com título, barra do giro, tela final e fade.

## Editor de fases

Fica dentro do jogo (funciona no `.exe`). Abre com **E** na tela de início (`--editor` na linha de comando também). Plano e motivos em D61 a D64.

```
scripts/level_data.gd        a fase como dado: grade + campos, validação, JSON, código "FREE1:..."
scripts/level_store.gd       user://levels/*.json: salvar, listar, apagar, importar código, área de transferência
scripts/editor/edit_model.gd operações sobre a grade, todas desfazíveis (histórico de traços)
scripts/editor/edit_tools.gd gestos do mouse -> operações (lápis, retângulo, linha, balde, porta, corda, seleção, colar)
scripts/editor/glyph_draw.gd desenho esquemático de cada peça (usa as cores de room.gd)
scripts/editor/editor_canvas.gd  a grade: zoom, rolagem, fantasmas, problemas
scripts/editor/editor.gd     a tela: barra, ferramentas, peças, propriedades, problemas, arquivos, atalhos
tests/editor_tests.gd        testes do editor, sem janela
```

- **Dado:** `LevelData` guarda `rows` (strings, um caractere por tile, a legenda de `levels.gd`) e os campos `name`, `hint`, `music`, `door_open`, `rotate`, `limiter`, `start_rot`. `to_def()` devolve o dicionário que `room.setup()` já consome; ou seja, uma fase do editor e uma fase de `levels.gd` são a mesma coisa. Tamanho de 6×6 a 64×48.
- **Validação (`validate()`):** erros (impedem jogar): grade retangular e cercada de parede, peças conhecidas, peças de 2×2 inteiras, um e só um coelho, porta retangular, comporta sem compartimento, compartimentos sem caixa suficiente, porta sem compartimento e sem "porta aberta", corda sem ponta numa parede. Avisos: compartimento que não abre nada, mais caixas que compartimentos, limitador sem giro, "porta aberta" com compartimento `S`. As 16 fases da campanha passam sem erros (teste).
- **Verificação:** `mark_verified()` guarda o hash do que muda a jogabilidade (grade, giro, limitador, rotação inicial, porta aberta; nome e dica não contam). `is_verified()` só vale enquanto o hash bate: qualquer edição tira a marca. Só fases verificadas aparecem em "Minhas fases" e geram código de compartilhamento.
- **Código de texto:** `FREE1:<tamanho>:<base64 do JSON comprimido>`; uma fase pequena tem uns 230 caracteres. A marca de verificada vai junto.
- **Modelo (`EditModel`):** a borda nunca muda; peças de 2×2 e a porta são donas das suas células (pintar ou apagar uma célula limpa a peça inteira); coelho e porta são únicos; um traço (arrastar do lápis, um retângulo, uma colagem) é uma entrada de desfazer. Girar a sala, espelhar e redimensionar guardam a grade inteira. `rotate_room` é exatamente a rotação do jogo (teste: a sala girada no editor e a girada por `room._rotate_logic` têm as mesmas paredes, espinhos, porta e coelho). Redimensionar mantém o canto inferior esquerdo (o chão).
- **Ferramentas (`EditTools`):** lápis (arrasta sem pular tiles), borracha, retângulo, moldura, linha (Bresenham), balde, seleção com copiar/recortar/colar (o vazio do recorte não apaga; R gira e F espelha o recorte antes de colar), porta (arrastar um retângulo), corda (arrastar uma reta; para antes das paredes). Botão direito apaga.
- **Janela:** ao abrir o editor, `main.gd` troca a janela para 960×540 em modo `canvas_items` (a resolução do jogo, 320×180, é pequena demais para editar); ao sair ou jogar, volta a 320×180 em modo `viewport`, escala inteira. O editor fica vivo e escondido enquanto se testa a fase.
- **Teste e tela de início:** `main.gd` tem `custom` ("editor" ou "list"): uma fase avulsa usa o mesmo `_spawn_room`, e `_end_custom(won)` volta ao editor (que marca a fase como verificada se venceu) ou à lista. Esc sai da fase avulsa. Na tela de início, E abre o editor e L abre "Minhas fases" (só verificadas; Enter joga, E edita).
- **Campanha:** `Levels.campaign_def(i)` devolve o ajuste `res://levels/campaign/NN.json` se existir e for jogável, senão a fase de `levels.gd`. Em build de depuração o editor tem "→ Campanha" (grava por cima da fase aberta) e "Restaurar original". Os testes e os bots continuam usando `levels.gd`. Os JSON entram no pacote exportado pelo `include_filter` do preset.

## Fluxo do jogo

`main.gd` começa em `_show_intro()` → cutscene (`intro.gd`) → `_load_start_room()` (sala `Levels.START`, `index = -1`) → níveis `Levels.ROOMS[0..9]` → tela final → de volta à abertura.

- `intro.gd` é um `Node2D` com `step(pressed)`, chamado por `main.gd` a cada quadro de física, e os sinais `started`, `finished`, `sfx` e `impact` (os dois últimos ligados aos mesmos tocadores das salas). As fases e durações estão no topo do arquivo (`DURATION`).
- O quadrado e a porta da cutscene (`SQ_OUT`, `SQ_IN`, `DOOR_RECT`, `FLOOR_Y`) têm de coincidir com a sala `START`; um teste verifica. Se mudar um, mude o outro.
- Para os quadros do coelho, `intro.gd` cria uma `Room` fora da árvore só para usar `_rabbit_tex`.
- `tests/intro_shot.gd` tira capturas de cada etapa da abertura.

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
5. Coelho (`rabbit.update`): andar, pular, boiar, ou o pêndulo se estiver na corda.
6. Caixas, de baixo para cima.
7. Água e ralos (`_update_water`).
8. Compartimentos e estado da porta (`_update_sockets`), incluindo a porta alagada.
9. Câmera.
10. Espinhos.
11. Vitória (coelho encosta na porta aberta).

Exceção: quando o coelho está rápido (na corda, ou arremessado acima de `MAX_SPEED`/`MAX_FALL`), ele chama `room.touch_check()` a cada pixel andado, que confere porta e espinhos na hora. A 300 px/s ele anda 5 px por quadro, e conferir só no fim do quadro deixava atravessar espinhos ou tocar porta e espinho "ao mesmo tempo".

## Rotação

- A simulação **sempre** tem gravidade para baixo.
- `_rotate_logic(dir)` rotaciona todos os dados: a grade de tiles, e cada retângulo (caixas, compartimentos, porta, espinhos, comportas, plataformas, coelho) com `_rot_rect`; a câmera e as partículas com `_rot_point`.
  - Com a sala de `W×H` pixels: horário `(x, y) → (H − y, x)`; anti-horário `(x, y) → (y, W − x)`. Depois, largura e altura trocam (`gw`/`gh`, `pw`/`ph`).
  - A direção (`facing`) de espinhos e plataformas soma +1 no horário e −1 no anti-horário.
  - Tudo em inteiros. Quatro giros voltam exatamente ao estado inicial (há teste).
- `_begin_rotate` faz a rotação lógica na hora e põe `view_angle = ∓90°`. O desenho usa esse ângulo e o leva até 0 em 16 quadros, com easing cúbico. Na tela parece que a sala girou; nos dados ela já estava girada desde o primeiro quadro.
- O sprite do coelho é desenhado com a rotação contrária, para ficar sempre em pé.
- Um giro é aceito se `rot_lock == 0`, a sala permite (`rotate` na definição) e o coelho está no chão ou ainda tem o giro do ar.
- `rot_lock` começa em `reload_frames` (padrão 150: 16 de animação + 134 de espera, 2,5 s; D60). Cada fase pode mudar isso com `reload_time` (segundos); ver D66 e desce 1 por quadro. `rot_ratio()` devolve de 0 a 1 para a barra. Morrer reinicia a sala e zera a recarga.

### Limitador

- Campo `limiter: true` da sala (D57). Cada giro soma em `limit_net`; quando o saldo não é zero, `limit_t` conta `limiter_frames` quadros (padrão 150, os mesmos da recarga; campo `limiter_time` em segundos). Ao zerar, `room.step` chama `_begin_rotate(-sinal(limit_net), forced=true)` e emite `sfx("limiter")`. O giro desfeito reinicia a recarga, e o saldo volta a zero.
- Como a recarga e o limitador têm o mesmo tamanho, o jogador nunca consegue fazer um segundo giro antes do desfeito.
- `main.gd` desenha uma barra vermelha (`limit_fill`) logo acima da barra branca, que esvazia durante os 2,5 s. O som `_make_limiter_sound` é uma varredura que despenca, com amostragem reduzida e saturação.

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
| `ROPE_GRAVITY` | 900 px/s² | gravidade do pêndulo |
| `ROPE_DAMP` / `ROPE_REST_DAMP` | 0,997 / 0,9 | amortecimento no arco / com a corda no teto |
| `ROPE_HOP` / `ROPE_REGRAB` | 40 px/s / 18 quadros | impulso ao soltar / espera para agarrar de novo |
| `ROPE_CLIMB` | 44 px/s | descer pela corda |
| `LAUNCH_DRAG` / `FALL_DECEL` | 90 / 300 | perda de velocidade do arremesso |
| `FLOAT_FRAC` / `WATER_DRAG` | 0,6 / 0,08 | quanto do corpo fica submerso / arrasto |
| `SWIM_SPEED` / `SWIM_JUMP` | 0,6 / 100 px/s | velocidade e pulo na água |

Medido pelos testes: pulo longo 30 px, pulo curto 8 px. Degraus de até 3 tiles (24 px) são alcançáveis.

## Corda

- Na sala: `ropes`, lista de `{anchor, facing, len, pts, old}`. `anchor` é um ponto na face de uma parede; `facing` é para onde a corda aponta saindo dela (2 = para baixo, ou seja, presa no teto). Âncora, `facing` e pontos giram com a sala.
- **A forma da corda é simulada** (`_update_ropes`, Verlet): um ponto a cada 4 px, gravidade, distância fixa entre vizinhos, e os pontos não entram em sólidos. Depois de um giro ela mantém a forma que tinha e cai com a nova gravidade; presa no chão, desaba num montinho. Um sopro lateral mínimo evita que uma corda apontando reta para cima fique em pé.
- **Só a corda presa no teto (`facing == 2`) dá para agarrar** (`rope_at`, que testa os pontos reais: logo depois do giro ela ainda está balançando). Nas outras orientações ela é desenhada mais apagada.
- Agarrar (`rabbit._grab`): automático, mas só para quem **pulou** (`rabbit.jumping`) ou acabou de soltar outra corda. Caindo depois de um giro, o coelho passa por ela; andando no chão também. O raio do pêndulo (`rope_r`) é a distância da âncora ao centro do coelho nesse momento, limitada ao comprimento da corda.
- Pendurado (`rabbit._update_rope`): pêndulo com ângulo `rope_a` e velocidade angular `rope_w`. O jogador não controla o balanço. Com a corda no teto o amortecimento é forte (`ROPE_REST_DAMP`) e o coelho fica parado; depois de um giro é fraco (`ROPE_DAMP`). O ponto da corda que ele segura acompanha a mão; a sobra balança solta.
- Descer: a entrada `climb` (ação `climb_down`: S, seta para baixo) aumenta `rope_r` a `ROPE_CLIMB` px/s até o comprimento da corda. Não dá para subir (D52). No meio de um arco, aumentar o raio desacelera o giro (momento angular conservado).
- Giro pendurado: é livre (não gasta o giro do ar; `rabbit.can_rotate`/`free_rotate`). `_rotate_logic` gira âncora e coelho, e `on_rotate` só recalcula o ângulo: a corda fica de lado e a gravidade faz o arco.
- Soltar: qualquer tecla de pulo (sai com a velocidade do arco, mais `ROPE_HOP` para cima), ou bater em algo. A mesma corda só pode ser agarrada de novo depois de pousar.
- Arremesso: no ar, acima de `MAX_SPEED`, a velocidade horizontal cai devagar (`LAUNCH_DRAG`) em vez de ser cortada; idem para a queda acima de `MAX_FALL` (`FALL_DECEL`).
- Agarrar a corda recarrega o giro do ar.
- `rabbit.jumping` sobrevive ao giro: quem pulou e girou no ar pode agarrar a corda que o giro pôs no teto.

## Água e ralo

- **Modelo de colunas** (D51). Cada coluna de 1 px tem "vãos": trechos verticais livres entre sólidos (`wt_top`, `wt_bot`). Cada vão guarda uma altura de água fracionária (`wt_h`) apoiada no fundo dele. `_water_build` monta os vãos a partir dos tiles, comportas fechadas e plataformas sólidas.
- **Nivelamento** (`_water_sim`): vãos ligados trocam, a cada subpasso, uma parcela do desnível entre eles; só passa a água acima da soleira (o fundo mais alto no caminho). Há ligações entre colunas vizinhas e a 2, 4, 8, 16, 32, 64 e 128 px (`WATER_REACH`), que só existem se há passagem livre entre as duas. As de longa distância fazem a água correr e nivelar em cerca de 1,5 s; as vizinhas alisam. Cada troca só aproxima dois níveis, então a conta é estável por construção. Vasos comunicantes funcionam.
- **Ondas** (`_ripple_sim`): por cima do nível, cada coluna tem um deslocamento de superfície (`wt_o`, `wt_v`) que se comporta como mola puxada pelas vizinhas. Quem as excita: o coelho caindo ou nadando, a água correndo, um bloco de água batendo no fundo. Só afetam o desenho, não o volume nem a física.
- **Giro:** `_water_slivers` transforma a água em faixas horizontais já giradas, e `_water_deposit` as distribui pelas colunas novas, conservando o volume exato. Água que fica sem nada embaixo cai como bloco (`wt_air`, `wt_vy`) até o fundo do vão.
- Quando as trocas ficam abaixo de `WATER_CALM_Q` por 20 quadros, `water_calm` fica verdadeiro e a simulação descansa. Lâminas mais finas que `WATER_FILM` secam sozinhas quando a água está quase parada. Ao carregar a sala, `_settle_water` roda até assentar.
- Caixas e coelho não deslocam a água (só fazem ondas).
- `water_frac(rect)`: fração de um retângulo dentro da água, contínua. Usada pelo coelho, pelas caixas e pela porta.
- **Coelho** (`rabbit.gd`, `wet`): empuxo proporcional à fração submersa, que equilibra a gravidade com `FLOAT_FRAC` (60%) do corpo dentro da água; arrasto `WATER_DRAG`. Caindo, afunda uns 8 px além da superfície e volta. Na água anda mais devagar (`SWIM_SPEED`), pula a partir da superfície (`SWIM_JUMP`, 19 px medidos) e pode girar a sala. A água nunca mata.
- **Caixa:** com 25% ou mais dentro da água, desce a no máximo `BOX_WATER_FALL` (45 px/s) e pousa sem impacto.
- **Porta:** com `DOOR_FLOOD` (30%) ou mais da área coberta de água, fica bloqueada, mesmo com os compartimentos cheios. Só destrava depois de `DOOR_DRY_FRAMES` (0,5 s) seca (D49).
- **Ralo** (`drains`): um tile, não sólido. Em cada uma das 8 colunas dele, engole `DRAIN_RATE` (1 px de altura) por quadro da água que o alcança. A água engolida só volta ao reiniciar a sala.
- Custo: proporcional ao número de ligações (cerca de 3 por coluna da sala), não ao volume de água.
- Desenho (`_draw_water`): uma faixa por coluna, da superfície ao fundo; colunas vizinhas iguais viram um retângulo só. Cascatas são um fio da soleira até a água de baixo.

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
- **Comporta inversa** (D65): entrada de `gates` com `inverse: true`, lida dos caracteres `¹²³⁴⁵⁶⁷⁸⁹`. Usa o mesmo grupo de compartimentos da comporta comum de mesmo número (`g["id"]`), mas quer fechar quando o grupo está **cheio** e abrir quando está vazio. Começa aberta. Nunca fecha em cima do coelho ou de uma caixa (mesma regra da comum), bloqueia a água quando fechada e gira com a sala. Quando a comum e a inversa mudam juntas, os dois sons tocam.
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
| `¹²³⁴⁵⁶⁷⁸⁹` | comporta inversa 1 a 9: usa o mesmo compartimento da comporta de mesmo número e faz o contrário |
| `=` `}` `_` `{` | plataforma por orientação, seta para cima, direita, baixo, esquerda |
| `^` `>` `v` `<` | espinho apontando para esse lado |
| `\|` `-` | corda: uma sequência reta é uma corda esticada; a ponta encostada numa parede é a âncora |
| `~` | água (o tile começa cheio; ao carregar, ela escorre até assentar) |
| `o` | ralo |

Campos por sala: `reload_time` e `limiter_time` (opcionais, segundos, 0,5 a 30; padrão 2,5; D66), `name`, `rotate` (permite girar), `start_rot` (giros de 90° aplicados ao carregar; positivo é horário), `rows`, `door_open` (opcional: porta sem compartimento, sempre aberta, a não ser que esteja alagada), e `hint` (opcional: texto de ajuda que `main.gd` mostra embaixo da tela durante a sala; em salas com mais de 150 px de altura ele some depois de 8 s, porque fica por cima do chão).

Cada sala é uma constante com nome (`PASSOS`, `TOCA`...), e `ROOMS` é a lista na ordem dos níveis. Para mudar a ordem, basta reordenar `ROOMS`; os bots procuram as salas pelo nome (`load_named`).

**Cuidado ao desenhar com `start_rot`:** o que está solto precisa estar apoiado na orientação inicial, não na desenhada. O teste "estado inicial estável" verifica isso.

**Cuidado ao desenhar com giros:** cada giro afeta a sala inteira. Uma caixa já encaixada tem de continuar segura em todas as orientações que as etapas seguintes usam (D41). Um buraco só derrama com a gravidade para cima; um nicho, com a gravidade para o lado da abertura.

**Medidas que limitam o desenho:** o coelho pula 30 px (sobe degraus de até 3 tiles) e alcança uns 5 tiles na horizontal; tem 12 px de largura e precisa de 2 tiles de vão para passar; precisa de pelo menos 2 tiles livres entre um pouso e espinhos.

## Desenho

Tudo é desenhado em `room.gd` com `_draw`, a cada quadro. A ordem importa: fundo, compartimentos, porta e feixe, **paredes**, comportas, plataformas, espinhos, caixas, molduras dos compartimentos, coelho, partículas, véus da sala inteira. A porta vem antes das paredes de propósito (D36). Fora da animação de giro, só as paredes visíveis são desenhadas.

- Paredes: preenchimento escuro, com linha off-white de 1 px em cada face exposta.
- Coelho: texturas 12×16 geradas em código a partir de três partes (`EARS`, `BODY`, `FEET`) e guardadas em cache. `_rabbit_frame` escolhe o quadro pelo estado.
- Porta aberta, partículas (poeira, morte, faíscas) e molduras dos compartimentos também são desenhadas ali.

Não há arquivos de imagem ainda, e os efeitos sonoros são gerados em código. Os treze sons (tom da recarga, "plim", pulo, morte, portal, baque da caixa, dois de sensor, abrir e fechar comporta, plataforma, corda, água; o baque é tocado até duas vezes, em alturas diferentes) são gerados em código em `main.gd`.

### Música

- Arquivos em `music/`. `main.gd` tem um `AudioStreamPlayer` só para música (`music`) e a função `_play_music(path)`, chamada a cada sala com o campo `music` da sala ou `Levels.DEFAULT_MUSIC`.
- Mesma faixa: continua tocando. Faixa diferente: fade de saída (0,8 s) e de entrada (1,5 s) até `MUSIC_DB` (−4 dB).
- Tela de início: `music/free-title.mp3` em loop; `_stop_music()` a corta na hora em que o jogador aperta Enter (sinal `started` da abertura).
- Queda da abertura: quando o coelho cai no buraco (fase `DROP`), `intro.gd` emite `sfx("falling")` e `main.gd` começa `music/fallinggg.mp3` na hora, sem fade (`_start_music_now`). Ela some com o fade normal quando a sala de início carrega (ou se a cutscene for pulada).
- Não há mais título por cima das fases; o único texto é a dica (`hint`), só com os controles de andar, pular e girar (D54).
- O loop vem da importação (`loop=true` no `.import` do arquivo) e é reforçado no código.
- `tests/music_check.gd` roda o jogo sem janela e confirma que a faixa carrega, toca em loop e continua ao trocar de sala.

### Efeitos e sons

- A sala não toca áudio. Ela emite `sfx` com `jump`, `death`, `win`, `sensor_on`, `sensor_off`, `gate_open`, `gate_close`, `platform`, `rope` (agarrou a corda) e `splash` (caiu na água), e o sinal `impact(strength)` para pousos de caixa; `main.gd` escuta e toca.
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
- Limitador (`FLAT` com `limiter`): liga ao girar, a barra desce, não dá para desfazer à mão, desfaz sozinho aos 2,5 s com som, e sem o campo o giro fica.
- Corda (sala `ROPE_ROOM`): leitura da sala, quatro giros restauram, não agarra andando nem caindo, agarra pulando, fica parado, giro livre pendurado, o arco acelera, bater na parede e o pulo soltam, só desce (parando na ponta), agarra em pleno voo depois de um giro no ar, a corda solta cai aos poucos sem esticar nem entrar na parede, corda fora do teto não agarra.
- Água (salas `WATER_ROOM` e `WATER_SPIKES`): começa plana, volume conservado e superfície nivelada (menos de 1 px de desnível) depois do giro, quatro giros restauram, o coelho afunda e depois boia parado, nada, pula da superfície e gira boiando, a caixa desce devagar, espinhos submersos matam quem cai de alto.
- Uma solução por sala, executada por bot. O bot do Prumo repete a solução com alturas de pulo diferentes e testa o arco curto (morre) e o sentido errado; o da Água também testa a porta alagada, o atalho de girar de dentro da porta e voltar cedo demais; o da Maré roda a solução em menos de 5 s; Represa, Naufrágio e Mergulho testam também os caminhos que falham (esperar, empurrar a caixa para dentro do poço, girar sem a corda). A sala 3 também testa o sentido errado; a sala 4 testa que girar do chão mata. Em caso de falha, a mensagem mostra onde estão o coelho e as caixas.

Ao mudar a física ou uma sala, rode os testes. Se um bot falhar, a sala pode ter ficado sem solução ou só o roteiro do bot ficou desatualizado; é preciso olhar.

Utilitários dos bots: `walk_to`, `walk_until`, `walk_jump_until` (pula sozinho ao encontrar parede), `jump`, `hop_to` (pula e se dirige no ar até um x), `rot`, `air_rot` (pula e gira no ar), `wait_ground`, `where` (descrição do estado para mensagens de erro).

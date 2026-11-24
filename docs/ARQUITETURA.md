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
  levels.gd              carregador da campanha (levels/campaign), sala de início e legenda do formato
  campaign_store.gd      canonizar, ordem e tirar da história (o editor chama)
  replay.gd              grava, compacta e roda os comandos de uma partida
  input_setup.gd         teclas e botões
  touch_controls.gd      joystick e botões de toque (D61)
  boss_squirrel.gd       boss 1, Jeffrey: ator da sala 17 (D64)
  world.gd               o mundo (D100, D120): salas em tiles, saídas, rosas, ligações, problemas do mapa
  world_state.gd         o progresso do mundo (habilidades, itens, rosas, toca), salvo em user://
  world_check.gd         o modelo do coelho na grade: a regra do giro (D121) e a progressão
  world_map.gd           o mapinho do alto e o mapa inteiro (M, Tab)
tools/world/
  plano_mapa.py          o plano (salas, ligações, mundos): a fonte da disposição
  build_world.py         monta levels/world/ (disposição, saídas das ligações, barreiras)
  salas.py, wkit.py      as receitas das 73 salas e o kit (escavar, embutir fases, rosas)
  check_world.gd         confere o mundo: o mapa, o giro e a progressão (também: reach, trace)
  check_levels.gd        a regra do giro nas fases da campanha
tests/
  run_tests.gd           testes sem janela
  shot.gd                capturas de tela
music/                   trilha sonora (MP3/OGG); importada pelo Godot com loop
docs/                    esta documentação
```

Nenhum script usa `class_name`; tudo é carregado com `preload`. A árvore de nós é montada em código: `Main` cria a `Room` (um `Node2D`) e uma `CanvasLayer` com título, barra do giro, tela final e fade.

## O mundo (D120, D121)

- `levels/world/mundo.json` (versão 2): `start`, `start_exit` e as salas com `pos` (o canto, em tiles).
  As salas em `levels/world/rooms/<id>.json`, no formato de fase de sempre, mais: `rose`, `entry_only`,
  `entry_only_until`, `barriers`, `items`, `tocas`, `dark`, `win_exit`, `ending`, `boss_on_solve`, `puzzle`
  (o validador vale a sala como resolvida) e `flip_exempt` (fora da regra do giro, com o motivo).
- `main.world_def` monta a sala com o progresso: `_entry_exit`, `_toca`, `_abilities`, `_items`, `_opened`,
  `_taken`, `_solved`, `_rose_open` (giro → saídas que encaixam) e `_dead_exits`. A sala avisa o mundo por
  `world_event` ("item", "opened", "toca", "boss"); `exited` leva à vizinha por `World.link`.
- Mudou uma sala ou a disposição? `python3 tools/world/build_world.py` e
  `godot --headless --path . -s tools/world/check_world.gd` (0 problemas). O teste `test_world` confere o
  mesmo e entra em cada sala por cada saída.

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

- **Dado:** `LevelData` guarda `rows` (strings, um caractere por tile, a legenda de `levels.gd`) e os campos `name`, `hint`, `music`, `door_open`, `rotate`, `limiter`, `start_rot`. `to_def()` devolve o dicionário que `room.setup()` já consome; ou seja, uma fase do editor e uma fase de `levels.gd` são a mesma coisa. Tamanho de 6×6 a 512×512 (teto técnico; D72).
- **Validação (`validate()`):** erros (impedem jogar): grade retangular e cercada de parede, peças conhecidas, peças de 2×2 inteiras, um e só um coelho, porta retangular, comporta sem compartimento, compartimentos sem caixa suficiente, porta sem compartimento e sem "porta aberta", corda sem ponta numa parede. Avisos: compartimento que não abre nada, mais caixas que compartimentos, limitador sem giro, "porta aberta" com compartimento `S`. As 16 fases da campanha passam sem erros (teste).
- **Verificação:** `mark_verified()` guarda o hash do que muda a jogabilidade (grade, giro, limitador, rotação inicial, porta aberta; nome e dica não contam). `is_verified()` só vale enquanto o hash bate: qualquer edição tira a marca. Só fases verificadas aparecem em "Minhas fases" e geram código de compartilhamento.
- **Código de texto:** `FREE1:<tamanho>:<base64 do JSON comprimido>`; uma fase pequena tem uns 230 caracteres. A marca de verificada vai junto.
- **Modelo (`EditModel`):** a borda nunca muda; peças de 2×2 e a porta são donas das suas células (pintar ou apagar uma célula limpa a peça inteira); coelho e porta são únicos; um traço (arrastar do lápis, um retângulo, uma colagem) é uma entrada de desfazer. Girar a sala, espelhar e redimensionar guardam a grade inteira. `rotate_room` é exatamente a rotação do jogo (teste: a sala girada no editor e a girada por `room._rotate_logic` têm as mesmas paredes, espinhos, porta e coelho). Redimensionar mantém o canto inferior esquerdo (o chão).
- **Ferramentas (`EditTools`):** lápis (arrasta sem pular tiles), borracha, retângulo, moldura, linha (Bresenham), balde, seleção com copiar/recortar/colar (o vazio do recorte não apaga; R gira e F espelha o recorte antes de colar), porta (arrastar um retângulo), corda (arrastar uma reta; para antes das paredes). Botão direito apaga.
- **Janela:** ao abrir o editor, `main.gd` troca a janela para 960×540 em modo `canvas_items` (a resolução do jogo, 320×180, é pequena demais para editar); ao sair ou jogar, volta a 320×180 em modo `viewport`, escala inteira. O editor fica vivo e escondido enquanto se testa a fase.
- **Teste e tela de início:** `main.gd` tem `custom` ("editor" ou "list"): uma fase avulsa usa o mesmo `_spawn_room`, e `_end_custom(won)` volta ao editor (que marca a fase como verificada se venceu) ou à lista. Esc sai da fase avulsa. Na tela de início, E abre o editor e L abre "Minhas fases" (só verificadas; Enter joga, E edita).
- **Campanha (D71):** a história são dados em `res://levels/campaign/`: um `<id>.json` por fase (o mesmo JSON do editor, com `notes` de projeto), a ordem em `ordem.json` e a prova em `<id>.replay.json`. `Levels` carrega (`ids()`, `rooms()`, `def_at(i)`, `by_id(id)`, `refresh()`); jogo, testes e editor leem o mesmo lugar. No editor (build de depuração), **Campanha…** mostra a história em ordem: abrir, subir, descer, tirar da história (vira rascunho em Minhas fases) e **canonizar a fase aberta** (grava por cima, se ela veio da história; senão entra depois da selecionada). Canonizar exige a fase verificada e o replay da mesma versão (`CampaignStore.why_not`). Para ir ao ar: commit e deploy.
- **Replay:** quando o autor vence no teste do editor, `main.gd` entrega os comandos de cada quadro (e os R) gravados por `Replay.record`; o editor guarda `Replay.pack(...)` com o `content_hash` da versão vencida e o estado de partida dos atores (o Jeffrey lembra se a abertura já foi vista). `Replay.run` roda numa sala sem janela. A simulação é determinística (pixels inteiros, 60 quadros fixos, o boss com sorteio próprio de semente fixa); os testes conferem isso refazendo a luta do boss quadro a quadro.
- **Campos que o editor não edita** ficam em `LevelData.extra` e voltam intactos em `to_def()`. Os de jogo (`spin_block`, `actors`, `spin_cooldown`, `boss_music`) entram no hash da verificação; os de texto (`hint_touch`, `notes`) não. O editor edita a dica no celular, o boss (catálogo `BOSSES` em `editor.gd`) e o bloco giratório (a partir de uma seleção quadrada).
- **Antes (substituído):** `Levels.campaign_def(i)` devolvia o ajuste `res://levels/campaign/NN.json` se existisse, senão a fase de `levels.gd`. Em build de depuração o editor tem "→ Campanha" (grava por cima da fase aberta) e "Restaurar original". Os testes e os bots continuam usando `levels.gd`. Os JSON entram no pacote exportado pelo `include_filter` do preset.

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

## Placa de espinhos (D73)

- Campo `crushers` da sala: lista de `{rect, dir, speed, delay, start, leash, face}`. `rect` é a faixa que a placa varre, em tiles (`[coluna, linha, largura, altura]`); `dir` é para onde ela avança (0 cima, 1 direita, 2 baixo, 3 esquerda); `speed` em px/s (padrão 9); `delay` em segundos até começar (negativo: espera um ator chamar `room.crusher_start(i)`); `start` são os px já avançados ao carregar (para ela aparecer sob o chão desde o início); `leash` é a distância em px a partir da qual ela anda 5 vezes mais rápido (`CRUSH_CATCHUP`) até reencostar no coelho (0 = desligado); `face` é `"happy"` ou `"sad"`.
- Na sala: `crushers`, com `lane` (a faixa, em px), `dir`, `adv` (avanço em px, fracionário), `speed`, `wait`, `leash`, `face`. O corpo da placa é o trecho da faixa de 0 a `adv` (`_crusher_rect`); os dentes passam 6 px disso (`CRUSH_SPIKE`).
- `_update_crushers` roda depois dos atores e antes da água. Ela não anda durante a animação do giro nem com o coelho morto (como o resto da simulação).
- **Destrói** (`_crusher_eat`) o que os dentes alcançam: paredes (o tile vira vazio), espinhos, plataformas, tiles de comporta, ralos, compartimentos e caixas. Cordas ficam. Fora da faixa nada é tocado. Como `reset()` relê a grade, morrer devolve tudo.
- **Mata** em `_check_hazards`: o corpo mais os dentes, com 2 px de folga na ponta. A placa não é sólida.
- **Gira com a sala:** `_rotate_logic` gira a faixa e soma o giro em `dir`; o avanço não muda. A placa que vinha de baixo passa a vir do lado.
- Desenho (`_draw_crushers`): por cima do coelho e por baixo da água. Chapas de aço de 32×16 em fiadas desencontradas, com rebites e, em algumas, um remendo (cor e posição saem de um hash da posição da chapa, então não mudam de um quadro para outro); uma viga na frente com os dentes. Só as chapas na tela são desenhadas. A carinha (`_draw_graffiti_face`) é pichada no meio da placa, a 26 px da frente: fixa, gira com a sala (`turn`) e só aparece com 44 px ou mais de avanço.
- O campo fica em `LevelData.extra` (entra no hash da verificação). **O editor ainda não mostra nem edita a placa**: ela é escrita à mão no JSON.
- `_draw_walls` passou a recortar as paredes à tela também durante a animação do giro (um círculo com a meia diagonal da tela em volta da câmera), para salas gigantes.

## Componentes do ato 2 (D76, D77)

Todos são campos da fase (JSON) lidos por `room.gd`, giram com a sala e são destruídos pela placa de espinhos. Os que têm lista (`conveyors`, `springs`...) são objetos; os de glifo estão na grade.

- **Tema** `"theme": "industrial"`: só desenho. Paredes viram chapas de 2×2 tiles com emendas, rebites e remendos de ferrugem (`_draw_steel_tile`, cor e remendo por hash da chapa); o fundo ganha tubulações, dutos e manchas de luz apagadas (`_draw_industrial_back`), com pouco contraste para não atrapalhar as plataformas.
- **Ácido** `%`: o mesmo fluido da água (a mesma simulação), em verde; `fluid_acid` na sala. Mata ao toque (`ACID_TOUCH` = 2% do coelho dentro). Uma sala tem um fluido só: o validador recusa `~` e `%` juntos.
- **Bateria** `+`, **alavanca** `L` (2×2) e **calha** `H` (2×2): 1 a `MAX_BATTERIES` (3) baterias, uma alavanca, uma calha. Com todas coletadas, `_lever_fire` trava a entrada e a câmera vai à alavanca (`LEVER_PAN`), ela vira sozinha (`LEVER_PULL`, com raio âmbar até a calha), a calha abre e solta uma `Box` (`LEVER_WATCH`). A calha conta como a caixa do compartimento na validação. Marcador de baterias no alto da tela.
- **Gatilhos dos conectores** (`movers`): `cycle`/`phase` (relógio `cycle_t`, zerado ao morrer), `bat` (liga com N baterias), botões de pressão (`plates`: `hold` ou `once`; coelho ou caixa apertam) e `delay` (espera depois do gatilho, com aviso). O aviso é um piscar dos encaixes e um bipe nos últimos `MOVER_WARN` quadros.
- **Esteira** (`conveyors`): `_update_conveyors` carrega o coelho e as caixas que estão apoiados em cima (resto fracionário em `belt_acc`); `ch` inverte o sentido, `cycle` inverte sozinha. De lado (a sala girou), não carrega.
- **Mola** (`springs`): lança no sentido de `dir` ao toque (`power` em px/s; 280 sobe ~44 px).
- **Ventilador** (`fans`): `rabbit.ext` (força externa, aplicada em `Rabbit.update`) sobe o coelho até `cap`; caixas só sobem em ventilador para cima (`box_fan_lift`) e pairam com a base na borda de cima da coluna.
- **Jato de vapor** (`vents`): período, tempo aberto (no fim do período) e defasagem; avisa 30 quadros antes (luz e chiado); aberto, mata.
- **Chapas soltas** e **perigo**: ver D75.
- **Sons:** `sfx_factory.gd` ganhou `battery`, `charge`, `hatch`, `plate_on/off`, `spring`, `steam_warn/burst`, `acid_burn/splash` e os loops `fan_loop` e `belt_loop` (volume por proximidade, `room.fan_gain`/`belt_gain`).

### Editor: objetos (D77)

- `scripts/editor/objects.gd` descreve cada tipo (campos, valores padrão, cor) e sabe girar, espelhar e redimensionar os objetos junto com a sala (um teste confere que o editor gira como o jogo). `EditModel` guarda os objetos em `LevelData.extra` com desfazer e refazer (`set_objects`, `add_object`, `remove_object`, `set_object_field`).
- `scripts/editor/objects_panel.gd` é a janela **Objetos…** (não bloqueia a grade): lista, cria (na seleção da grade, se houver), duplica, edita e apaga; **Usar a seleção** define o retângulo. A grade desenha o contorno de cada objeto, com sigla e seta de sentido. No painel da fase há o seletor de **Tema**; o roteiro do Gatsby é um texto JSON.
- Glifos `+`, `L`, `H`, `%` na paleta; alavanca e calha são únicas (colocar outra move a anterior).

### Ferramentas para fazer fases grandes (D77)

- `tools/levelkit.py` descreve uma fase (geometria e objetos) e, junto, o roteiro de um robô que a joga (`hop`, `jump_from`, `drop`, `step`...); `tools/levels/<id>.py` escrevem `levels/wip/<id>.json` e `tools/plans/<id>.json`.
- `tools/robot.gd` executa o roteiro (corre, pula da beirada, dirige no ar, espera conectores e jatos, empurra a caixa, entra na porta), confere onde pousa (coluna e altura) e, se vencer sem morrer, grava `tests/fixtures/route-<id>.json`, que os testes rodam (`test_industrial_levels`). Rodar: `python3 tools/levels/<id>.py` e `godot --headless --path . -s tools/robot.gd -- <id>`.

## Componentes da corrida (D75)

- **Conectores** (os blocos motorizados, campo `movers`): `mover_toggle(ch)` agora avisa antes: os dois encaixes piscam por `MOVER_WARN` (16) quadros, com o som `mover_warn`, e só então o canal muda (`_mover_flip`). `mover_toggle(ch, true)` muda na hora. `mover_warning(ch)` diz se o canal está no aviso. Sons: `mover_go` ao partir, `mover_dock` ao encaixar.
- **Catapulta:** campo `launch` (px/s) num conector. Se a peça chega ao encaixe subindo com o coelho em cima, ele sai com essa velocidade para cima (`_mover_launch`). Só para cima (na orientação atual). A peça ganha duas setas pintadas.
- **Chapas soltas** (campo `crumbles`: lista de `[coluna, linha, largura, altura]`): sólidas; `CRUMBLE_FRAMES` (26) quadros depois de o coelho pisar, desabam e não voltam até reiniciar. Giram com a sala e são destruídas pela placa. Entram em `solid_static` e `_body_can_move`.
- **Perigo:** `room.danger` (0 a 1, suavizado) e `room.danger_dir` saem da placa ligada mais próxima (`DANGER_FAR` 150 px → 0, `DANGER_NEAR` 30 px → 1). A sala desenha o brilho vermelho na borda; `main._update_danger_audio` ajusta o ronco em loop e o alarme.
- **Sons** (`scripts/sfx_factory.gd`): todos gerados em código. `ONE_SHOTS` lista nome, volume e variação de tom; `main.gd` cria um tocador para cada um e toca quando a sala emite `sfx` com o nome. `rumble()` é o loop do ronco. Nomes: `lever`, `mover_warn`, `mover_go`, `mover_dock`, `launch`, `crumble_warn`, `crumble`, `crunch`, `crusher_wake`, `alarm`, `gatsby_dash`, `gatsby_laugh`.
- **Fase e prova:** `tools/gatsby_level.py` escreve `levels/wip/gatsby.json`; `tools/gatsby_robot.gd` joga a fase com um plano de comandos (correr até x, pular, esperar, girar) e grava `tests/fixtures/gatsby-route.json`, que `test_gatsby_route` roda. Mudou a fase: rode os dois, nessa ordem. `levels/wip/` entra no pacote exportado; `--play=<id>` e `?play=<id>` jogam um rascunho do jogador ou, se não houver, a fase de `levels/wip`.

## Subsolo, amortecedor e despertar (`room.gd`, D82)
- `theme` em `SUBSOIL` troca a parede (`_draw_soil_tile`), o fundo (`_draw_subsoil_back`) e os enfeites das faces (`_draw_soil_decor`). `_orig_up()` dá o "cima" da fase como foi desenhada, na sala de agora: a grama nasce ali.
- `anchors` (`_find_anchors`, só com `limiter`): giram em `_rotate_logic` como os espinhos (`facing`); `_draw_anchors` usa `limit_t` (pulso) e `anchor_fx` (onda ao desfazer).
- `awaken` (campo da sala) + `static var awakened`: `awaken_t` conta o susto; `_flip_fx` faz a batida (som `thump`) e, na primeira vez, o clarão.
- `level_data.gd`: `theme` e `awaken` estão em `TEXT_KEYS` (fora do hash). `tools/rehash_campaign.gd` refaz o hash dos replays quando o cálculo muda sem mudar a jogabilidade.

## A mecha (`boss_mecha.gd`, D80)
- Ator da sala (`actors`), como o Jeffrey: `step`, `on_reset`, `on_rotate`, `absorb_kill` (3 corações do coelho), `replay_state` (a abertura vista).
- `pos` é o centro da caixa (24×30), sempre em pé na tela. Em `on_rotate`, as posições giram com a sala, mas as velocidades da investida e dos teleguiados não (são de tela): é o que faz o giro desviar.
- A cápsula do Gatsby é um `boss_gatsby.gd` filho, só para o desenho (`phase = "puppet"`, `show_behind_parent`); `anim_draw()` a põe no alto da mecha também durante a animação do giro.
- Projéteis: `markers` (miras no contorno), `shots` (mísseis da mira, 12 px por quadro), `homers` (teleguiados), `blasts` (só desenho; o dano é no quadro da explosão).
- A abertura desliga `room.allow_rotate` e o religa quando o Gatsby pluga.

## Gatsby (`boss_gatsby.gd`, D74)

- **Movimento (D75, substitui a órbita):** `_orbit` puxa a cápsula por uma mola para um ponto à frente do coelho no rumo da corrida (`_race_dir`: do coelho para a próxima área `when` do roteiro), numa elipse mais larga que alta, com balanço lateral por humor (`LEAD`). Se o ponto cai dentro de uma parede (`_in_wall`), tenta ângulos ao lado. `_keep_clear` roda em toda fase menos `gone`: abaixo de `KEEP_AWAY` (66 px) ele é empurrado e pode dar um arranque; abaixo de `KEEP_MIN` (50 px) a posição é corrigida na hora. `min_gap` guarda a menor distância desde o reset (os testes conferem).
- **Sinal do canal:** `_pull` guarda `sig_ch`/`sig_t`; o desenho acende a antena e o punho na cor do canal e traça um raio até cada peça dele.
- **Cutscene com vários passos:** a cena só termina quando o passo seguinte não é `cut` (antes, o segundo passo de cena acontecia na hora, sem a animação da alavanca).

- Ator da sala, como o Jeffrey. Não tem colisão e não machuca. Segue o roteiro do campo `gatsby` da sala: `{"start": [coluna, linha], "script": [passos]}`. O formato dos passos está no topo do arquivo (`when`, `mood`, `fly`, `lever`, `crusher`, `speed`, `rotate`, `wait`, `flee`, `cut`).
- O roteiro avança pelo **avanço do coelho** (`when` é uma área em tiles), não pelo relógio. Fases: `when` → `fly` → `lever` → `wait` → passo seguinte; `flee` no fim.
- O que a sala ganhou para ele (serve a qualquer ator): `actor_rotate(dir)` (giro que fica: não mexe na recarga nem no limitador, toca o som do limitador), `input_lock` (entrada travada), `cam_focus` (câmera presa num ponto), `crusher_start(i)`, e a chamada `on_rotate(room, dir)` em cada ator quando a sala gira.
- **Giro:** ele e o roteiro inteiro (áreas e pontos de voo) giram com a sala em `on_rotate`. No desenho a cápsula fica em pé (rotação contrária a `view_angle`, como o coelho) e ele é jogado lá dentro por 45 quadros.
- **Cutscene** (`cut`): trava a entrada e leva a câmera para ele. Só na primeira vez (`intro_seen`, estático, como no Jeffrey; entra no estado do replay); depois o passo acontece na hora.
- **Propulsor:** o bocal gira contra a velocidade horizontal (`nozzle`), com chama e fumaça.
- **Expressões** (`_draw_badger`): `bored` (chá), `smug`, `amused`, `annoyed`, `furious`, `nervous`, `panic`, `smirk`. Ri quando o coelho morre.
- `start_rot` não é considerado no roteiro: as posições valem para a fase como foi desenhada.
- No editor, "Gatsby, o texugo" está na lista de bosses, mas o roteiro e as placas ainda são escritos à mão no JSON.

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

## Formato das salas (`levels/campaign/*.json`; legenda em `levels.gd`)

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
- Placa de espinhos (sala `CRUSH_ROOM`): espera o atraso, avança, destrói paredes, caixa e espinho só dentro da faixa, mata, morrer devolve tudo, espera por `crusher_start`, gira com a sala (quatro giros restauram), `start` e `leash`.
- Gatsby (sala `GATSBY_ROOM`): a cutscene trava a entrada e leva a câmera, ele puxa a alavanca e liga a placa, gira a sala quando o coelho chega à área (sem ligar o limitador; a placa gira junto), foge no fim, e na segunda vez não há cutscene.
- Limitador (`FLAT` com `limiter`): liga ao girar, a barra desce, não dá para desfazer à mão, desfaz sozinho aos 2,5 s com som, e sem o campo o giro fica.
- Corda (sala `ROPE_ROOM`): leitura da sala, quatro giros restauram, não agarra andando nem caindo, agarra pulando, fica parado, giro livre pendurado, o arco acelera, bater na parede e o pulo soltam, só desce (parando na ponta), agarra em pleno voo depois de um giro no ar, a corda solta cai aos poucos sem esticar nem entrar na parede, corda fora do teto não agarra.
- Água (salas `WATER_ROOM` e `WATER_SPIKES`): começa plana, volume conservado e superfície nivelada (menos de 1 px de desnível) depois do giro, quatro giros restauram, o coelho afunda e depois boia parado, nada, pula da superfície e gira boiando, a caixa desce devagar, espinhos submersos matam quem cai de alto.
- Uma solução por sala, executada por bot. O bot do Prumo repete a solução com alturas de pulo diferentes e testa o arco curto (morre) e o sentido errado; o da Água também testa a porta alagada, o atalho de girar de dentro da porta e voltar cedo demais; o da Maré roda a solução em menos de 5 s; Represa, Naufrágio e Mergulho testam também os caminhos que falham (esperar, empurrar a caixa para dentro do poço, girar sem a corda). A sala 3 também testa o sentido errado; a sala 4 testa que girar do chão mata. Em caso de falha, a mensagem mostra onde estão o coelho e as caixas.

Ao mudar a física ou uma sala, rode os testes. Se um bot falhar, a sala pode ter ficado sem solução ou só o roteiro do bot ficou desatualizado; é preciso olhar.

Utilitários dos bots: `walk_to`, `walk_until`, `walk_jump_until` (pula sozinho ao encontrar parede), `jump`, `hop_to` (pula e se dirige no ar até um x), `rot`, `air_rot` (pula e gira no ar), `wait_ground`, `where` (descrição do estado para mensagens de erro).

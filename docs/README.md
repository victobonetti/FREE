# Documentação do projeto

Jogo de plataforma e puzzle em que um coelho foge por salas que podem ser giradas de 90 em 90 graus. Feito em Godot 4.7 com GDScript. Nome ainda a definir.

| Arquivo | Para que serve |
|---|---|
| [GDD.md](GDD.md) | O design do jogo: visão, pilares, requisitos, salas, expansões. É o "o quê". |
| [DECISOES.md](DECISOES.md) | Registro de cada decisão tomada, com o motivo e as alternativas descartadas. Ler antes de mudar algo que parece estranho. |
| [ARQUITETURA.md](ARQUITETURA.md) | Como o código funciona: arquivos, rotação, física, formato das salas, testes, onde ajustar cada coisa. É o "como". |
| [HISTORICO.md](HISTORICO.md) | O que foi feito em cada rodada, o retorno de quem jogou e o que está pendente. |
| [COMPARTILHAR.md](COMPARTILHAR.md) | Como gerar as versões web e Windows e mandar para os amigos testarem. |

## Estado atual (15/11/2026)

- Etapas M0 a M4 prontas: 5 salas jogáveis em graybox.
- Primeira rodada de retorno de jogo aplicada: sprite do coelho, pulo, porta, recarga do giro.
- 10 níveis com dificuldade crescente (D42), de tamanhos variados, com câmera seguindo o coelho, comportas e plataformas por orientação. Resolvidos por bots; aguardando teste de quem joga.
- Depois do piloto: corda, água e ralo, com um nível de apresentação para cada (níveis 11 e 12, D47 a D50); aguardando teste.
- Ato introdutório em andamento (D53, D58): 16 fases feitas, cada uma resolvida por bot; recarga do giro de 2,5 s e o limitador na Maré e na Fuga.
- Pendente: fase 20, Vertigem e Fuga revistas; ajustes depois do teste; arte e áudio finais (M5).

## Como rodar

- Jogar: `.\run.ps1` na raiz do projeto (ou abrir a pasta no Godot 4.7 e apertar F5). O executável está em `Desktop\GODOT`.
- Testes: `Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/run_tests.gd`
- Capturas de tela: `Godot_v4.7.2-stable_win64_console.exe --path . -s tests/shot.gd -- <pasta>`

## Controles

| Ação | Teclado | Controle |
|---|---|---|
| Andar | A/D ou setas | Analógico ou direcional |
| Pular | Espaço, W, ↑ ou K | A |
| Na corda: descer | S ou ↓ | Analógico ou direcional para baixo |
| Na corda: soltar | as teclas de pulo | A |
| Girar anti-horário / horário | Q / E | LB / RB |
| Reiniciar sala | R | Y |
| Sala seguinte / anterior (desenvolvimento) | PageDown / PageUp | — |

Para abrir direto num nível: `.\run.ps1 -Level 11`.

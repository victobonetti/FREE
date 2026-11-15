# Documentação do projeto

Jogo de plataforma e puzzle em que um coelho foge por salas que podem ser giradas de 90 em 90 graus. Feito em Godot 4.7 com GDScript. Nome ainda a definir.

| Arquivo | Para que serve |
|---|---|
| [GDD.md](GDD.md) | O design do jogo: visão, pilares, requisitos, salas, expansões. É o "o quê". |
| [DECISOES.md](DECISOES.md) | Registro de cada decisão tomada, com o motivo e as alternativas descartadas. Ler antes de mudar algo que parece estranho. |
| [ARQUITETURA.md](ARQUITETURA.md) | Como o código funciona: arquivos, rotação, física, formato das salas, testes, onde ajustar cada coisa. É o "como". |
| [HISTORICO.md](HISTORICO.md) | O que foi feito em cada rodada, o retorno de quem jogou e o que está pendente. |

## Estado atual (15/11/2026)

- Etapas M0 a M4 prontas: 5 salas jogáveis em graybox.
- Primeira rodada de retorno de jogo aplicada: sprite do coelho, pulo, porta, recarga do giro.
- Direção do redesenho das salas decidida (5 salas longas, tamanhos variados, câmera seguindo o coelho, plataformas por orientação e portas intermediárias). Nada disso está implementado.
- Pendente: detalhar e implementar o redesenho; arte e áudio finais (M5).

## Como rodar

- Jogar: abrir a pasta do projeto no Godot 4.7 e apertar F5. O executável está em `Desktop\GODOT`.
- Testes: `Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/run_tests.gd`
- Capturas de tela: `Godot_v4.7.2-stable_win64_console.exe --path . -s tests/shot.gd -- <pasta>`

## Controles

| Ação | Teclado | Controle |
|---|---|---|
| Andar | A/D ou setas | Analógico ou direcional |
| Pular | Espaço, W, ↑ ou K | A |
| Girar anti-horário / horário | Q / E | LB / RB |
| Reiniciar sala | R | Y |
| Sala seguinte / anterior (desenvolvimento) | PageDown / PageUp | — |

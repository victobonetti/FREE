# Documentação do projeto

Jogo de plataforma e puzzle em que um coelho foge por salas que podem ser giradas de 90 em 90 graus. Feito em Godot 4.7 com GDScript. Nome ainda a definir.

| Arquivo | Para que serve |
|---|---|
| [GDD.md](GDD.md) | O design do jogo: visão, pilares, requisitos, salas, expansões. É o "o quê". |
| [DECISOES.md](DECISOES.md) | Registro de cada decisão tomada, com o motivo e as alternativas descartadas. Ler antes de mudar algo que parece estranho. |
| [ARQUITETURA.md](ARQUITETURA.md) | Como o código funciona: arquivos, rotação, física, formato das salas, testes, onde ajustar cada coisa. É o "como". |
| [HISTORICO.md](HISTORICO.md) | O que foi feito em cada rodada, o retorno de quem jogou e o que está pendente. |
| [COMPARTILHAR.md](COMPARTILHAR.md) | Como gerar as versões web e Windows e mandar para os amigos testarem. |
| [PLANO_METROIDVANIA.md](PLANO_METROIDVANIA.md) | Só planejamento (D118): a análise das fases e o plano do jogo como um mundo contínuo (metroidvania), com o mapa ([plano-mapa.png](plano-mapa.png)). |

## Estado atual (15/11/2026)

- Etapas M0 a M4 prontas: 5 salas jogáveis em graybox.
- Primeira rodada de retorno de jogo aplicada: sprite do coelho, pulo, porta, recarga do giro.
- 10 níveis com dificuldade crescente (D42), de tamanhos variados, com câmera seguindo o coelho, comportas e plataformas por orientação. Resolvidos por bots; aguardando teste de quem joga.
- Depois do piloto: corda, água e ralo, com um nível de apresentação para cada (níveis 11 e 12, D47 a D50); aguardando teste.
- Ato introdutório em andamento (D53, D58): 16 fases feitas, cada uma resolvida por bot; recarga do giro de 2,5 s e o limitador na Maré e na Fuga.
- Pendente: fase 20, Vertigem e Fuga revistas; ajustes depois do teste; arte e áudio finais (M5).

## Editor de fases

Na tela de início: **E** abre o editor; **L** abre "Minhas fases" (as que você venceu e salvou). No editor: pinte com o mouse (botão direito apaga), escolha a peça à esquerda, ajuste as propriedades à direita, **P** ou "▶ Jogar" testa. Vencer uma vez marca a fase como verificada; só então ela vira código de compartilhamento ("Exportar código") e entra em "Minhas fases". Atalhos: Ctrl+Z/Y desfaz/refaz, Ctrl+S salva, Ctrl+C/X/V copia/recorta/cola (R gira e F espelha a colagem), roda do mouse dá zoom, botão do meio ou Espaço+arrastar move, Home enquadra. Detalhes: [ARQUITETURA.md](ARQUITETURA.md).

## Como rodar

- Jogar: `.\run.ps1` na raiz do projeto (ou abrir a pasta no Godot 4.7 e apertar F5). O executável está em `Desktop\GODOT`.
- Testes: `Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/run_tests.gd` (jogo) e `... -s tests/editor_tests.gd` (editor)
- Abrir direto no editor: `.\run.ps1 -Editor`... não: `Godot --path . -- --editor`
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

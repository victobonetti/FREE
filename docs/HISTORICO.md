# Histórico

O que foi feito em cada rodada, o retorno recebido e o que ficou pendente. Entradas mais novas no fim.

---

## Rodada 1 — Conceito e plano (15/11/2026)

**Entrada:** esboço `concept.png` com três quadros (sala inicial, sala girada com coelho e caixa caindo, caixa no compartimento com a porta aberta) e a descrição da ideia.

**Feito:**
- Leitura do esboço e definição dos pilares (gravidade sempre para baixo, tudo que está solto cai, a caixa só fica no compartimento pela gravidade).
- Requisitos do piloto, escolha do Godot 4, desenho inicial das 5 salas, lista de expansões.
- Tudo registrado em `GDD.md`.

**Decisões deixadas em aberto e depois aceitas:** giro no ar, caixa que esmaga, porta trancada sólida. Tema de laboratório segue em aberto.

---

## Rodada 2 — Implementação de M0 a M4 (15/11/2026)

**Feito:**
- Projeto Godot 4.7.2 configurado (320×180, escala inteira).
- Controlador do coelho, rotação, caixas, compartimentos, porta, espinhos, morte e respawn.
- 5 salas em graybox, transições e tela final.
- Testes sem janela com bots que resolvem cada sala.

**Mudanças em relação ao plano:**
- Rotação feita nos dados em vez da câmera (D13).
- Física própria em pixels inteiros em vez de `CharacterBody2D` (D14).
- Salas em texto em vez de cenas (D15).
- Sala 2 ganhou uma saliência na parede: sem ela a caixa ficava colada na parede depois do giro e não dava para empurrá-la.
- Salas 4 e 5 redesenhadas em volta do giro no ar: cruzar um campo de espinhos pulando e girando, com a caixa atravessando pelo chão até um buraco.

**Problemas conhecidos ao fim da rodada:**
- Sala 5 quase igual à 4.
- Ninguém tinha jogado ainda; só bots.

---

## Rodada 3 — Primeiro teste de jogo e correções (15/11/2026)

**Retorno do Victor depois de jogar:**
1. Coelho gordinho e sem movimento; quer orelhas maiores e corpo menor.
2. Pulo "não está ruim, mas ainda meio duro".
3. Porta amarela parece um bloco sólido; quer animação ao tocar nela.
4. Depois de cada giro, bloquear novo giro por um período curto, com barra branca no canto inferior direito e som que fica mais agudo.
5. Salas monótonas; quer um plano para deixá-las mais interessantes e dinâmicas, sem se prender ao formato 1:1.

**Feito (itens 1 a 4):**
- Sprite novo de 12×16, montado por partes, com animação de parado, corrida, subida e queda (D20).
- Pulo refeito no modelo de Celeste: mais tempo no ar, ápice mais longo, queda mais lenta. Poeira ao pular e pousar (D19).
- Porta aberta virou um vão iluminado; ao tocar, o coelho é puxado para dentro e a porta se fecha (D21).
- Recarga do giro de 0,87 s com barra e som gerado em código (D09).
- Novo teste para a recarga. Todos os testes passam.
- Documentação reorganizada nesta pasta.

**Ainda não validado por quem joga:** se o pulo novo resolveu o "duro", se a recarga está curta ou longa demais, se o som agrada.

**Pendente (item 5):** plano de redesenho das salas, a ser combinado antes de implementar.

---

## Rodada 4 — Direção do redesenho das salas (15/11/2026)

**Proposta de Claude** para o item 5 da rodada anterior: tamanhos variados, mais plataforma dentro da sala, poucos elementos novos, salas em etapas.

**Respostas do Victor:**
1. Em salas grandes, a câmera segue o coelho (D23).
2. O piloto fica com 5 salas, mais longas (D24).
3. Entram agora só plataformas por orientação e portas intermediárias (D25).

**Feito:** apenas documentação, a pedido. Nenhum código foi alterado nesta rodada.

**Próximo passo combinado:** detalhar o plano sala por sala antes de implementar. As correções da rodada 3 (pulo, recarga, som) ainda aguardam o retorno de quem joga.

---

## Rodada 5 — Som e efeitos de pulo e morte, bug da parede, empurrar (15/11/2026)

**Pedido do Victor:**
1. Efeitos como os da recarga do giro, para o pulo e para a morte.
2. Corrigir o bug em que, andando contra a parede, o sprite pisca sem parar.
3. Variação na animação ao empurrar uma caixa.

**Feito (D27 a D29):**
- Sons de pulo e de morte gerados em código; anel e poeira no pulo; tremor, clarão e anel na morte.
- Bug da parede corrigido: a animação passou a seguir o movimento real.
- Quadros novos de empurrar, com inclinação e poeira.
- Testes novos: sem piscar contra a parede, empurrar alterna dois quadros, e os sinais de som saem ao pular e ao morrer. Todos passam.

**Ainda não validado por quem joga:** o volume e o timbre dos sons novos (só foram verificados por teste, ninguém os ouviu), a intensidade do tremor da morte e se a animação de empurrar lê bem em tamanho real.

---

## Rodada 6 — Efeito de entrada no portal (15/11/2026)

**Pedido do Victor:** adicionar um efeito ao entrar no portal para a próxima fase.

**Feito (D30):** som de arpejo, ondas de luz, faíscas, feixe vertical, véu dourado e tremor leve. Teste novo confirma que o som de vitória é emitido. Todos os testes passam; o efeito foi conferido em captura de tela.

**Ainda não validado por quem joga:** o som (só verificado por teste) e se o conjunto de efeitos não está exagerado para uma transição que se repete a cada sala.

---

## Rodada 7 — Impacto da caixa, sensor do compartimento, som de portal (15/11/2026)

**Pedido do Victor:**
1. Efeito quando uma caixa cai forte no chão, depois de girar, com a tela tremendo levemente na direção da gravidade.
2. Efeito minimalista ao pôr a caixa em um buraco, como um sensor ativando.
3. Som de portal, distorcido, no lugar do som de sucesso ao entrar na porta.

**Feito (D31 a D33):**
- Impacto da caixa com poeira, anel, baque e solavanco de até 2,5 px para baixo.
- Sensor com contorno expansivo, linha de varredura e dois bipes (um som para ativar, outro para desativar).
- Som de portal novo, gerado por síntese: varredura com FM, ruído girando, distorção e golpe grave no fim.
- Um bug do primeiro teste foi corrigido no caminho: os efeitos dos compartimentos começavam vazios e travavam a sala.
- Testes novos: baque na queda, solavanco limitado e que termina, sensor ligando. Todos passam. O sensor foi conferido em captura de tela.

**Ainda não validado por quem joga:** os três sons (verificados só por teste), a força do solavanco e se o portal soa como portal.

---

## Rodada 8 — Porta fechada deixa de ser sólida (15/11/2026)

**Pedido do Victor:** a porta não deve ser objeto sólido quando fechada.

**Feito (D34):** a colisão da porta foi removida para o coelho e para as caixas. A porta fechada ficou translúcida e vazada. Teste novo confirma que o coelho e uma caixa ficam dentro dela sem efeito, e que as 5 salas continuam solucionáveis.

**Impacto a considerar no redesenho:** a porta não segura ninguém, então as portas intermediárias (D25) não podem trancar uma passagem por conta própria.

---

## Rodada 9 — Impacto das caixas proporcional (15/11/2026)

**Pedido do Victor:** melhorar o impacto das caixas no chão; quanto mais caixas e mais altura, mais impacto.

**Feito (D35):** a força passou a vir da distância da queda e soma pousos em sequência. Escala o solavanco, a poeira, o anel, as lascas, o tremor e o som (volume, grave e segundo baque). Testes novos para altura, quantidade e teto do solavanco; passam.

**Ainda não validado por quem joga:** a escala (quando o impacto passa de "leve" para "forte") e o teto do solavanco.

---

## Rodada 10 — Porta vazando para dentro da parede (15/11/2026)

**Relato do Victor:** o sprite da porta atravessa a parede branca da borda.

**Feito (D36):** a porta, seus brilhos e o feixe da vitória passaram a ser desenhados antes das paredes. Conferido em captura de tela nas salas 1 e 3 (porta presa ao teto). Testes passam.

---

## Rodada 11 — Salas longas, comportas e plataformas por orientação (15/11/2026)

**Pedido do Victor:** começar as alterações evolutivas nas salas, conforme o plano combinado.

**Decidido nesta rodada:** as etapas são bloqueadas por comportas (D37), escolhidas entre três opções, porque a porta deixou de ser sólida.

**Feito:**
- Motor: salas de qualquer tamanho, rotação de salas não quadradas, câmera seguindo o coelho (D39); comportas (D37); plataformas por orientação (D38); sons novos de comporta e plataforma.
- As 5 salas refeitas, longas e em etapas (D41, GDD seção 6).
- Testes reorganizados: mecânica com salas de teste próprias (D40); testes novos de rotação não quadrada, câmera, comporta e plataforma; um bot por sala nova. Todos passam.
- Conferido em captura de tela: corredor largo com câmera, sala alta girada, comporta aberta e fechada, plataformas sólidas e tracejadas.

**Desvio do plano:** a sala 5 ficou com uma comporta e um compartimento na saída, em vez de duas e dois.

**Ainda não validado por quem joga:** dificuldade e clareza das salas novas, a suavização da câmera, os sons de comporta e plataforma, e se a seta das plataformas é legível.

---

## Rodada 12 — 10 níveis com dificuldade crescente (15/11/2026)

**Retorno do Victor:** os níveis 1 e 2 estavam bem mais difíceis que o 3. Pedido: 10 níveis, com complexidade crescente, e o primeiro bem mais simples.

**Feito (D42):**
- 5 salas novas, pequenas, cada uma com uma ideia: Primeiros passos, Degraus, Comporta, Giro, Setas.
- As 5 salas anteriores reposicionadas sem mudança: Toca 4, Derrame 6, Vertigem 8 (era a 2ª), Espinhos 9, Fuga 10.
- `levels.gd` reorganizado: uma constante por sala e a lista `ROOMS` com a ordem.
- Bots para as salas novas; os bots passaram a procurar a sala pelo nome. Todos os testes passam.
- Salas novas conferidas em captura de tela.

**A conferir no teste:** se a curva sobe bem, e se esperar até o nível 5 pelo primeiro giro é demais.

---

## Rodada 13 — Dicas de controle (15/11/2026)

**Pedido do Victor:** texto sobre os movimentos (WASD ou setas) no primeiro nível, e texto explicando o giro na sala do giro.

**Feito (D43):** campo `hint` nas salas, mostrado embaixo da tela; dicas no nível 1 e no nível 5. Conferido em captura de tela. Testes passam.

**Conversado, sem decisão ainda:** como distribuir o jogo para amigos testarem. A recomendação é uma versão web no itch.io (página restrita, por link), com um `.exe` para Windows como alternativa. Falta instalar os templates de exportação do Godot 4.7.2 (cerca de 1 GB), o que depende de autorização do Victor.

---

## Rodada 14 — Trilha sonora (15/11/2026)

**Entrada do Victor:** a faixa `music/first-levels-theme.mp3`, feita para tocar em loop.

**Feito (D44):** tocador de música com fade e troca suave entre faixas; campo `music` por sala e `DEFAULT_MUSIC`; loop ligado na importação. Conferido por `tests/music_check.gd`: a faixa carrega, toca em loop e continua ao trocar de sala. Testes passam.

**Ainda não validado ouvindo:** o volume da música contra os efeitos, e se o ponto de repetição do MP3 tem algum silêncio.

---

## Rodada 15 — Exportação para amigos testarem (15/11/2026)

**Pedido do Victor:** como exportar o projeto para os amigos analisarem.

**Feito (D45):**
- Templates de exportação do Godot 4.7.2 baixados e instalados.
- `export_presets.cfg` com as versões Web (sem threads) e Windows.
- Gerados `build/coelho-web.zip` (11,2 MB) e `build/coelho-windows.zip` (37,8 MB).
- Testado: o `.exe` abre e roda; a versão web foi servida localmente, os arquivos carregam com os tipos certos e o jogo foi aberto no navegador do Victor.
- Passo a passo de publicação no itch.io e de envio do `.exe` em [COMPARTILHAR.md](COMPARTILHAR.md).

**Falta (com o Victor):** criar a página no itch.io e enviar o zip; mandar o link aos amigos.

---

## Rodada 16 — Tela de início e cutscene de abertura (15/11/2026)

**Entrada do Victor:** esboço `start-screen.jpeg` e a descrição da abertura; o jogo se chama "Free". No meio do trabalho, pediu que a abertura tenha só efeitos sonoros, pois a música ele adiciona depois.

**Feito (D46):**
- `scripts/intro.gd`: tela de título e cutscene em 11 fases, desenhada em código.
- Sala de início (`Levels.START`) onde a cutscene termina; campo `door_open`.
- `main.gd` começa pela abertura; depois do fim do jogo, volta a ela. Ação de entrada `start`.
- Sem música na abertura e na sala de início; efeitos reaproveitados.
- Testes: a cutscene não começa sozinha, começa com Enter, termina sozinha, pode ser pulada, emite os efeitos, e a sala de início coincide com o quadrado da cutscene. Capturas das 10 etapas conferidas (`tests/intro_shot.gd`).
- Corrigido no caminho: uma colina do cenário gerava um polígono inválido; e as linhas da cutscene estavam 1 px fora das linhas da sala.

**Ainda não validado por quem joga:** o ritmo da cutscene (10,3 s) e os efeitos sonoros escolhidos.

**Atenção:** as versões em `build/` são anteriores a esta rodada; é preciso exportar de novo antes de mandar aos amigos.

---

## Rodada 17 — Volume, bug da tela de início, música do título (15/11/2026)

**Entrada do Victor:** música mais alta e efeitos mais baixos (principalmente o portal); o coelho aparecia fora da janela na tela de início (`bug-start-screen.png`); `free-title.mp3` para a tela de título, em loop, parando ao apertar Enter; um script para rodar o jogo.

**Feito:**
- Música de −9 para −4 dB; portal de −11 para −19 dB; carga, "plim", pulo, morte e comportas 3 dB mais baixos.
- `intro.gd`: o coelho que cai no buraco é recortado na borda de baixo da janela.
- `music/free-title.mp3` toca em loop na tela de início e é cortada na hora do Enter (`_stop_music`).
- `run.ps1` na raiz: roda o jogo (`-Console` mostra o console, `-Editor` abre o editor).

**Ainda não validado por quem joga:** o novo equilíbrio de volumes.

---

## Rodada 18 — Corda, água e ralo (15/11/2026)

**Entrada do Victor:** as duas mecânicas, os esboços `componente-corda.jpeg` e `water-mechanics.png`, e as respostas às perguntas sobre a água. As perguntas sobre a corda ficaram sem resposta; valeram os padrões propostos (D47).

**Feito (D47 a D50):**
- Corda: pêndulo em `rabbit.gd`, leitura e desenho em `room.gd`, símbolos `|` e `-`.
- Água: grade de células com nivelamento, empuxo no coelho, caixa mais lenta, porta alagada, ralo; símbolos `~` e `o`.
- Níveis 11 (Corda) e 12 (Água), com dica de texto. Sons novos: agarrar a corda e cair na água.
- Conferência de porta e espinhos a cada pixel quando o coelho está rápido.
- A dica de texto some depois de 8 s nas salas altas, onde ficava por cima do chão.
- Testes de mecânica para corda e água, e um bot para cada sala nova. Capturas de tela conferidas.

**Achado no caminho:** a água sem nivelamento se comportava como areia (D48); o atalho de girar de dentro da porta alagada (D49).

**Ainda não validado por quem joga:** tudo desta rodada.

**Atenção:** as versões em `build/` são anteriores a esta rodada.

---

## Rodada 19 — Água fluida, corda com física, subir e descer (15/11/2026)

**Entrada do Victor, depois de jogar:** o coelho deve subir e descer na corda; a água estava irregular e em bloquinhos, ele a quer fluida e pixel a pixel; a corda não devia "se transportar" depois do giro; como pular direto para os últimos níveis; os níveis 11 e 12 ficam onde estão por enquanto.

**Feito (D51):**
- Água reescrita: colunas de 1 px, nivelamento estável, ondas na superfície, cascatas.
- Corda com física (Verlet); só agarra quem pulou; subir e descer com W/S ou setas; Espaço solta.
- `.\run.ps1 -Level 11` abre direto num nível (argumento `--level=N` do jogo).
- Testes novos para subir e descer, corda caindo, e superfície da água plana. Capturas conferidas.

**Ainda não validado por quem joga:** a nova água, a queda da corda e a subida.

---

## Rodada 20 — Ato introdutório: 19 de 20 fases; música da queda (15/11/2026)

**Entrada do Victor:** só descer na corda e a tecla de cima continua pulando; agarrar a corda durante o giro; proposta de 20 fases, depois aprovada com o pedido de mais plataforma e nenhum texto por cima das fases; `fallinggg.mp3` no momento em que o coelho cai, na abertura.

**Feito (D52, D53):**
- Corda: só desce; pulo solta; quem pula e gira no ar agarra a corda que o giro pôs no teto.
- Título das fases removido; nova ordem das fases.
- Fases novas: Salto no vazio (8), Prumo (11), Laço (12), Maré (15), Represa (16), Naufrágio (17), Mergulho (18). Toca (6) refeita.
- Música da queda na abertura.
- Um bot por fase nova, e a água nivelando mais depressa em salas largas.

**Falta:** fase 20 (Livre); Vertigem com corda; Fuga com corda e água.

**Ainda não validado por quem joga:** todas as fases novas e a nova ordem.

---

## Rodada 21 — Recarga de 5 s, limitador e fases revistas (15/11/2026)

**Entrada do Victor:** recarga do giro de 5 s em todo o jogo; Comporta e Toca com giro e espinhos; Salto no vazio sem a plataforma, porta 1:1 e espinhos em três paredes; remover Corda e Laço; Prumo com espinhos, sem a plataforma e começando na parede da esquerda; a mecânica nova "limitador" na Maré, com metade das plataformas e uma barra vermelha; Represa e Naufrágio sem a espera do ralo; Mergulho mais complexo.

**Feito (D56 a D59):**
- Recarga de 5 s; limitador (barra vermelha, som distorcido).
- Fases 4, 6, 8, 10 (Prumo) e 13 (Maré) ajustadas; Corda e Laço removidas; numeração: 17 fases.
- Represa e Naufrágio redesenhadas em torno de despejar a água e carregar caixas pela gravidade; Mergulho ganha caixa e compartimento.
- Um bot por fase, com os caminhos errados também testados (283 verificações).

**Ainda não validado por quem joga:** o ritmo com 5 s de recarga, a Maré em 5 s, e a leitura da Represa (despejar a água) e do Naufrágio (carregar caixas girando).

**Falta (da proposta de 20 fases):** fase 20 (Livre), Vertigem com corda, Fuga com corda e água.

---

## Rodada 22 — 2,5 s, Fuga com limitador, espinhos acima das portas (15/11/2026)

**Entrada do Victor:** recarga e limitador de 5 s para 2,5 s; limitador também na última fase; remover a fase 8; os espinhos acima das portas estavam soltos no ar, apontando para a porta: pôr uma plataforma pequena suspensa com espinhos para cima.

**Feito (D60):** 2,5 s; Salto no vazio removida (16 fases); Maré e Fuga refeitas para caber no tempo; plataformas de espinhos acima das portas da Comporta, da Toca e da Fuga. Todos os bots passam.

**Ainda não validado por quem joga:** tudo isto, em especial a Maré e a subida da Fuga em 2,5 s.

---

## Rodada 23 — Editor de fases (16/11/2026)

**Entrada do Victor:** "com os componentes que temos, crie um editor de fases. Ele será o core do jogo", por interface, para personalizar qualquer nível; planejamento primeiro.

**Feito (D61 a D64):** plano aprovado e implementado inteiro: dados e validação (`level_data.gd`), armazenamento e código de compartilhamento (`level_store.gd`), modelo de edição com desfazer, ferramentas, grade e tela do editor (`scripts/editor/`), testar dentro do editor com verificação por vitória, "Minhas fases" na tela de início, e ajuste da campanha em JSON (só em desenvolvimento). Testes em `tests/editor_tests.gd` (sem janela, inclusive o fluxo editor → jogar → vencer → salvar → lista).

**Ainda não validado por quem joga:** a usabilidade da interface com o mouse (testei por script e capturas, não com as mãos). Em especial: o tamanho da grade ao abrir, o zoom, e se as ferramentas se explicam sozinhas.

**Não feito:** música por fase no painel (o campo existe, sem interface); gravação de solução; navegador de fases de outras pessoas (só importação por código).

---

## Rodada 24 — Comporta inversa (16/11/2026)

**Entrada do Victor:** componentes que funcionam ao contrário das comportas, ativos só quando a comporta de mesmo número é ativada, usando a mesma comporta; também no editor.

**Feito (D65):** comporta inversa em `room.gd` (leitura, estado, desenho, som), em `level_data.gd` (símbolo e validação) e no editor (paleta com nove botões, desenho próprio). Testes: estados opostos, sólida só uma de cada vez, sons das duas, não esmaga, giro, e ida e volta por JSON e código. Todos passam.

**Falta:** usar a inversa em alguma fase da campanha; hoje ela só existe nas fases do editor.

---

## Rodada 25 — Recarga e limitador por fase (16/11/2026)

**Entrada do Victor:** parametrizar o limite e o timeout do flip no editor.

**Feito (D66):** `reload_time` e `limiter_time` na fase (`room.gd`, `level_data.gd`), com validação, hash de verificação e dois campos no painel do editor. Testes novos nos dois conjuntos; todos passam.

**Dúvida aberta:** se "limite" era a quantidade máxima de giros (não feita).

---

## Rodada 26 — Celular e GitHub Pages (16/11/2026)

**Entrada do Victor:** publicar na web e jogar no celular, com um joystick e dois botões para girar.

**Feito (D61, D62):** controles de toque (joystick, pulo, dois giros, reiniciar) nas faixas laterais da tela; dicas de controle e "TAP TO START" próprios para toque; tela cheia e aviso para deitar o celular; workflow que publica no GitHub Pages. Conferido em navegador com celular emulado: andar, empurrar, pular andando (dois dedos) e girar. Os testes continuam passando.

Depois: cambalhota encolhida do coelho e faíscas azuis a cada giro (pedido do Victor). Arrastar o dedo pela tela olha a sala (pedido do Victor, pensando em salas maiores), com testes na suíte.

**Ainda não validado por quem joga:** tudo isto num celular de verdade, em especial o tamanho dos botões e o joystick.

---

## Rodada 27 — Boss 1, Jeffrey, o esquilo (16/11/2026)

**Entrada do Victor:** esboço do boss (D63); respostas: só faces vizinhas, coelho morre num toque, esquilo com 3 corações, sem pausa; encurtar o giro do bloco; começar a implementação.

**Feito (D64):** sala 17 com o bloco que gira (0,15 s, sem pausa) e o esquilo: entra girando, anda, zigue-zague pelas paredes, mira com aviso e ataca em linha reta; nozes a partir do segundo coração; tonto ao ser atingido; porta abre no fim. Testes: o bloco gira sem pausar, o esquilo nunca se acerta sozinho, e um bot vence girando no último instante.

**Ainda não validado por quem joga:** tudo. Em especial as janelas de reação (1,0 / 0,7 / 0,5 s) e se o esquilo andando no chão é justo.

---

## Rodada 25 — Campanha canônica no editor (16/11/2026)

**Entrada do Victor:** criar salas e canonizá-las no modo história usando só o editor; replays gravados por ele; tirar as fases de `levels.gd`.

**Feito (D71):** fases em `levels/campaign/*.json` com `ordem.json`; painel **Campanha…** no editor (abrir, subir, descer, tirar, canonizar); canonizar exige vitória e replay da mesma versão; replay gravado no teste do editor e rodado pelos testes; sorteio próprio do Jeffrey; o editor não apaga mais os campos do boss e ganhou dica no celular, boss e bloco giratório. Testes novos nos dois conjuntos.

**Próximo passo do Victor:** gravar o replay de cada fase (abrir na Campanha…, ▶ Jogar, vencer, Canonizar) e fazer commit. Cada fase com replay pode perder o bot.

---

## Pendências gerais

| Item | Estado |
|---|---|
| Retorno sobre as rodadas 3 a 11 (pulo, recarga do giro, sons, efeitos, salas novas, câmera) | aguardando teste |
| 10 níveis com dificuldade crescente | feitos (rodada 12); aguardando teste |
| Sala 5 com duas comportas e dois compartimentos na saída | adiado (D41) |
| Arte final (sprites, tiles) | não iniciado; hoje tudo é desenhado em código |
| Áudio | efeitos gerados em código; primeira faixa de música do Victor ligada a todos os níveis (D44); faltam faixas para os níveis seguintes |
| Dicas de controle | feitas nos níveis 1 e 5 (rodada 13) |
| Exportar para amigos testarem | versões geradas (rodada 15); web publicada pelo GitHub Pages (rodada 23, D62) |
| Tema e narrativa (laboratório?) | em aberto |
| Nome do jogo | "Free" (D46) |
| Música da abertura | feita (rodada 17): `free-title.mp3` na tela de início |
| Corda e água | feitas (rodada 18); aguardando teste. Em aberto: respostas do Victor sobre a corda (D47) e um jeito de ativar o ralo |
| Exportar de novo para `build/` | pendente desde a rodada 16 |
| Controle de versão (git) | a pasta não é um repositório |

---

## Rodada 28 — Jeffrey com mais vida (16/11/2026)

**Entrada do Victor:** esboço `jeffrey-concept.jpeg`; Jeffrey "extremamente animado", movimentos mais naturais, maior; noz que gira e perde força a cada batida; bomba de um toque com óculos e sorriso; uma noz já no primeiro coração; balancear para chefe de capítulo 1.

**Feito (D67):** tudo em `scripts/boss_squirrel.gd`. Os testes do boss continuam passando (o bot vence; girar à toa nunca fere o esquilo).

**Ainda não validado por quem joga:** tudo. Conferido só por capturas: andando, na parede, mirando, bola no ar, explosão, noz nas três caras. Não vi em captura: a bomba em voo, o tonto e a risada.

---

## Rodada 29 — Vidas e retratos no boss (16/11/2026)

**Entrada do Victor (depois de jogar):** retrato do Jeffrey e do coelho no alto, os dois com 3 vidas só nesta sala; nozes maiores e um pouco mais lentas; ao levar dano o coelho pisca imortal por um período curtíssimo; perder as 3 vidas reinicia o chefão.

**Feito (D68):** `boss_squirrel.gd`, `room.gd` (`invuln`, `absorb_kill`) e teste novo das vidas. Todos os testes passam.

**Ainda não validado por quem joga:** a duração da imunidade e o tamanho novo das nozes.

---

## Rodada 30 — Abertura do boss (16/11/2026)

**Entrada do Victor:** na primeira vez, o jogador faz 3 giros antes de o Jeffrey aparecer, para entender a mecânica na prática; ele aparece rodando do céu; se o jogador morrer, a cena não se repete.

**Feito (D69):** estado `wait` em `boss_squirrel.gd` e teste da abertura. Todos os testes passam.

---

## Rodada 31 — Música e barras só com o Jeffrey (16/11/2026)

**Entrada do Victor:** o tema do boss só começa quando o Jeffrey aparece (até lá, o tema normal dos níveis); sem barra de vida do coelho até ele aparecer.

**Feito (D70):** `boss_music` na sala, `music_request` em `room.gd`, barras escondidas durante a espera. Testes cobrem o pedido da faixa. Não conferido ouvindo.

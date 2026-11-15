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

## Pendências gerais

| Item | Estado |
|---|---|
| Retorno sobre as rodadas 3, 5, 6 e 7 (pulo, recarga do giro, sons, empurrar, efeitos do portal, caixa e sensor) | aguardando teste |
| Plano das 5 salas longas, sala por sala | direção decidida (D23 a D26); detalhamento pendente |
| Suporte a salas não quadradas e maiores que a tela, com câmera seguindo o coelho | não iniciado |
| Plataformas por orientação e portas intermediárias | não iniciado |
| Arte final (sprites, tiles) | não iniciado; hoje tudo é desenhado em código |
| Áudio (pulo, pouso, giro, caixa, porta, morte, música) | só existem o tom da recarga e o "plim" |
| Dicas de controle na primeira sala | não iniciado |
| Tema e narrativa (laboratório?) | em aberto |
| Nome do jogo | em aberto |
| Controle de versão (git) | a pasta não é um repositório |

# Como mandar o jogo para os amigos testarem

Há duas versões, geradas na pasta `build/` do projeto (ela não faz parte do código; pode ser apagada e gerada de novo).

| Versão | Arquivo | Para quem |
|---|---|---|
| Web | `build/coelho-web.zip` | Qualquer pessoa com Chrome, Firefox ou Edge, pelo link do itch.io |
| Windows | `build/free-windows.zip` | Quem prefere baixar e rodar; só Windows |

## Link fixo: GitHub Pages (versão web, também no celular)

Cada push na `main` exporta e publica a versão web sozinho (`.github/workflows/deploy-web.yml`). O link fica em `https://victobonetti.github.io/FREE/`.

Configuração, uma vez só: no GitHub, **Settings → Pages → Source: GitHub Actions**. No plano grátis o repositório precisa ser público. Para publicar de novo sem mudar nada: aba **Actions → Deploy web → Run workflow**.

Para jogar a fase do Gatsby (em obras, fora da história): `https://victobonetti.github.io/FREE/?play=gatsby`; no PC, `./run.ps1 -Play gatsby`.

Para testar um nível direto, sem passar pelos anteriores: acrescente `?level=N` ao link, por exemplo `https://victobonetti.github.io/FREE/?level=17` (o boss).

No celular: abra o link, deite o aparelho e toque na tela. O jogo entra em tela cheia e os controles aparecem nas laterais. No iPhone, o Safari não deixa entrar em tela cheia; use **Compartilhar → Adicionar à Tela de Início** e abra pelo ícone.

## Gerar de novo (depois de mudar o jogo)

Na pasta do projeto, no PowerShell:

```
$g = "C:\Users\victo\Desktop\GODOT\Godot_v4.7.2-stable_win64_console.exe"
& $g --headless --path . --export-release "Web" build/web/index.html
& $g --headless --path . --export-release "Windows Desktop" build/windows/Coelho.exe
Compress-Archive -Force build/web/* build/coelho-web.zip
Compress-Archive -Force build/windows/* build/coelho-windows.zip
```

Para o Windows há um atalho na raiz do projeto: `.uild.ps1` gera `build\windows\Free.exe`; com `-Zip` gera também `buildree-windows.zip`; `-Test` roda os testes antes; `-Run` abre o jogo no fim. O executável é de um arquivo só (o pacote de dados vai embutido).

Ou peça ao Claude para exportar de novo.

## Publicar no itch.io (versão web)

1. Crie uma conta grátis em itch.io.
2. No painel, **Create new project**.
3. Preencha:
   - **Title:** o nome que quiser (o jogo ainda não tem nome oficial).
   - **Kind of project:** **HTML**.
   - **Uploads:** envie `build/coelho-web.zip` e marque **This file will be played in the browser**.
   - **Embed options:** tamanho **1280 × 720**; marque **Fullscreen button**. A opção **SharedArrayBuffer support** pode ficar desmarcada (a exportação é sem threads justamente para não precisar dela).
   - **Visibility & access:** **Restricted** (só quem você autorizar) ou **Draft** com o link secreto. Não deixe **Public** se não quiser que apareça para todo mundo.
4. Salve. Em **Restricted**, a página dá um link secreto para mandar aos amigos.

Ao abrir, o jogo pede um clique para começar: o navegador só libera som depois de alguma interação.

## Mandar o .exe (versão Windows)

1. Mande `build/free-windows.zip` por Drive, Discord ou WeTransfer.
2. Seu amigo extrai o zip e abre `Free.exe`.
3. O Windows vai mostrar **"O Windows protegeu o computador"**, porque o executável não tem assinatura digital. Clique em **Mais informações → Executar assim mesmo**. É normal em jogos independentes não assinados.

## O que pedir para os amigos observarem

- Em que nível travaram, e se entenderam o que fazer sem ajuda.
- Se algum nível pareceu fácil ou difícil demais em relação ao anterior.
- Como sentiram o pulo e o giro.
- Se a música ou algum efeito incomodou.

Controles no celular: joystick à esquerda para andar (para baixo desce a corda); à direita, o botão grande pula e as duas setas giram a sala; o botão pequeno no canto de cima reinicia. Arrastar o dedo pelo meio da tela mostra o resto da sala, quando ela é maior que a tela.

Controles: A/D ou setas para andar; W, seta para cima ou Espaço para pular; Q e E para girar; R para reiniciar a sala. Controle de videogame também funciona (analógico, A, LB, RB, Y).

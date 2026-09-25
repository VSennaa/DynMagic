# Brief — site do DynMagic (Codex)

Status: não iniciado (2026-09-25).

## Objetivo
Página pública do jogo, estática, servida pelo nginx da VPS em um subdomínio DuckDNS próprio (ex.: `dynmagic.duckdns.org`). Tom: entre o **minecraft.net antigo (2010–2013)** e o **site do Hytale**: simples, indie, com cara de blog de dev. Nada de framework, nada de build step.

## Referências de estilo
- minecraft.net antigo: coluna central estreita (~900 px), cabeçalho com logo em pixel/pedra, caixa de "Baixar agora" em destaque, lista de posts do blog com data, rodapé simples.
- Hytale: fundo pintado, painéis com moldura, títulos serifados épicos.
- Identidade do jogo: grimório à noite. Tinta `#11161F`, creme `#F2E8D5`, ouro `#E8C170`, violeta `#C98BFF`; elementos Fogo `#FF5A1F`, Gelo `#6FD3FF`, Raio `#C98BFF`, Vento `#7CF2B0`. Fontes Cinzel (títulos) e Alegreya Sans (texto) — copie os `.ttf` de `ui/fonts/` (OFL) para `web/fonts/`.
- Reaproveite a arte: `assets/ui/menu_backdrop.png` (fundo), `rune_corner_*.png` (cantos dos painéis), `button_*.png` (botões), `parchment_panel.png`. Otimize cópias em `web/img/` (WebP ou PNG reduzido, alvo < 400 KB cada).

## Páginas (`web/`)
1. `index.html` — logo/título "DynMagic", frase curta ("Duelos de magia 1v1 em primeira pessoa. Componha feitiços, escolha seu elemento, vença a melhor de 7."), botão **Baixar para Windows** + link para o servidor Linux, 3 pontos de destaque (Composição de magias, Draft de elementos, Arenas), bloco "Últimas notícias" com os 3 posts mais recentes, bloco "Status dos servidores" (ver abaixo).
2. `blog/` — índice + um post por arquivo HTML. Posts iniciais: "Alfa 1.0 a caminho" (resumo de `docs/reviews/SYNTHESIS.md` em linguagem de jogador) e "Como jogar" (Q/E/R forma, Q/E/R efeito, LMB confirma, RMB repete, draft).
3. `como-jogar.html` — regras curtas, teclas, os 9 símbolos de magia (redesenhe em SVG inline a partir de `scenes/ui/spell_glyph.gd`).
4. `changelog.html` — gerado à mão a partir de `docs/release-notes.md`.

## Download (direto do GitHub, nada passa pela VPS)
- Repositório: `https://github.com/VSennaa/DynMagic`.
- Os nomes dos arquivos têm a versão (`DynMagic-v0.3.1-windows-x64.zip`), então use JS: `fetch('https://api.github.com/repos/VSennaa/DynMagic/releases/latest')`, ache o asset `*-windows-x64.zip` e o `*-linux-x64.tar.gz`, preencha os links e a versão. Sem JS ou em erro: link para `https://github.com/VSennaa/DynMagic/releases/latest`.
- Pré-lançamentos (`-alpha`) não entram em `/latest`: se `/latest` der 404, use `/releases?per_page=1`.

## Status dos servidores
- Bloco que lê `/status.json` (mesmo host) a cada 30 s: `{ "updated": ISO, "rooms": [{ "name", "port", "players", "max", "state": "lobby|match" }], "queue": N }`. Se o arquivo não existir, mostrar "Status indisponível" sem quebrar o layout. O gerador do `status.json` fica para o servidor de fila (fora deste brief).
- Mostrar IP/host para "Entrar por IP" (texto configurável no topo do JS).

## Regras
- Só HTML/CSS/JS puros. Sem CDN, sem tracking, sem cookies. Funciona abrindo `web/index.html` localmente.
- Responsivo (celular 375 px sem scroll horizontal), `prefers-color-scheme` não é necessário (o site é sempre noturno).
- Crie `web/.gdignore` (vazio) para o Godot não importar o site.
- Crie `web/README.md` com como publicar: copiar `web/` para `/var/www/dynmagic/` na VPS e o bloco nginx (`server_name dynmagic.duckdns.org; root /var/www/dynmagic;` + `location = /status.json` com `Cache-Control: no-cache`), certbot para HTTPS.
- Edite **somente** `web/` e este arquivo (atualize o Status no topo ao terminar). Não mexa em `docs/HANDOFF.md`, no jogo, nem na rede. Não faça commit.

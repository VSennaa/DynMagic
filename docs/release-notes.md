# DynMagic v1.0.0-alpha — alfa 1.0

A primeira alfa pública do DynMagic: o jogo se explica sozinho, o placar é confiável e o servidor aguenta três salas.

## Regras mais justas

- **Escolha com confirmação**: depois de escolher o elemento (e a runa, para quem perdeu), clique em **Confirmar** (ou Enter). O round só começa quando os dois confirmam; o primeiro round dá **15 s** para o primeiro jogador.
- **Primeira escolha sorteada**: quem abre o draft é sorteado no início da partida, e os lados trocam a cada round.
- **Morte simultânea**: se os dois caírem no mesmo instante, vence quem tinha mais vida antes do golpe.
- **Seta com 3 cargas** (1 a cada 1,2 s), em vez de recarga por tiro. O **botão direito** agora repete apenas magias confirmadas — as rápidas saem no próprio atalho.
- **Elementos achatados**: Fogo 1,05 · Gelo 0,95 · Raio 1,00 · Vento 0,95. A identidade fica nos status e nas variantes.
- **Prorrogação padrão: Colapso**. No lobby o anfitrião pode fixar Colapso, Morte Súbita, Maré de Mana ou Aleatório.
- Sem **tiro na cabeça**: todo acerto no corpo causa o dano da magia.

## Combate legível

- **Hitmarker e número de dano** confirmam cada acerto; som de impacto próprio.
- **Banners** de vitória, derrota e fim de round com o motivo (abate, Núcleo, mais vida, empate...), e **cartão de dano** ao morrer.
- **Glossário único**: nomes em português em todo lugar (Raio, Leque, Prorrogação, Escolha, Round), com descrição de runas e elementos. Fim dos ids crus na tela.
- **Roda de magias** em arco Q-E-R, com marca de **rápida** (ponto) e **confirmada** (anel).
- **Painel da escolha** atualizado no lugar: os cliques nunca são engolidos.
- Tela **Como jogar**, dica no treino e cartão 3×3 no Tab.
- As **barras de vida dos dois** ficam no topo; o nome do oponente some atrás das paredes.

## Rede e servidor

- Reconexão por **token de sessão** (não mais pelo nome) e o jogador é remapeado no cliente que ficou.
- O servidor valida alvo, números finitos, recarga e lockout; snapshots levam status, cooldowns e morte; a destruição da muralha é autoritativa.
- **Servidor dedicado enxuto**: sem HUD, modelo, animação e áudio, física fixa em 60 Hz.
- **Entrar por IP:porta**, IP do anfitrião visível no lobby e motivo da queda ao voltar ao menu.
- **Telemetria local** (JSON em `user://telemetry`), avisada no lobby, sem envio para a internet.
- Template `dynmagic@.service` com `MemoryMax` para **três salas** (UDP 7777/7779/7780) na VPS de 2 GB.

---

# DynMagic v0.3.1 — símbolos de magia

## Novidades na 0.3.1

- **Símbolos** para forma e efeito na roda da mira e na HUD: Projétil ↗, Pessoal (figura), Área (anel no chão); Direto (losango), Explosivo (estrela), Contínuo (anel pontilhado).
- **Configurações → Roda de magias**: alterne entre **Significado** (símbolos) e **Atalhos** (suas teclas).
- **Grade de recarga** gráfica: célula na cor do elemento quando pronta, relógio esvaziando e segundos restantes em recarga.
- "Persistente" agora se chama **Contínuo**.

## Da 0.3.0

- **Cajado em primeira pessoa**: uma mão só segurando um cajado que muda com o elemento do round (Fogo, Gelo, Tempestade, Vento). O mago em 3ª pessoa também carrega o cajado.
- **Modo canhoto** em Configurações: espelha o cajado para o lado esquerdo.
- **Todos os menus estilizados** como um grimório: fundo pintado com círculo arcano animado, painéis com cantos rúnicos, botões com moldura dourada, fontes Cinzel e Alegreya Sans.

## Novidades na 0.2.1

- **Modo espectador**: em Jogar LAN marque **Entrar como espectador** (ou `--spectate`). Não ocupa vaga, pode entrar com a partida em andamento. Teclas **1/2** seguem cada jogador em 3ª pessoa, **0** câmera livre (WASD, Espaço/Ctrl, Shift).
- **Braços em primeira pessoa** com FOV próprio (60, como o padrão do CS2; ajustável de 54 a 68 em Configurações → FOV das mãos), menores e nos cantos inferiores.
- Build do servidor Linux corrigido (a 0.2.0 não chegou a ser publicada).

## Novidades da 0.2.0

- **Servidor dedicado** (Windows ou Linux): `DynMagic.exe --headless -- --server --name "Minha Arena"`. Os jogadores entram pela lista de salas (LAN) ou por IP (VPS), clicam em Pronto e a partida começa sozinha; depois do resultado todos voltam ao lobby. Pacote Linux separado nesta release com `README` e unidade systemd.
- **Texturas pintadas à mão** em todos os modelos (geradas proceduralmente no Blender).
- **Mago animado** (parado, andando, conjurando, dash, morte) e **braços em primeira pessoa** que mudam de pose com a composição da magia.
- **Som**: cliques de menu, passos na pedra, impactos, sino de fim de round, pano no dash, pedra na muralha (Kenney, CC0), magias sintetizadas com variação e reverb, música ambiente provisória.

## Da 0.1.1

- Menu do Esc, círculo de composição na mira (P/S/A, D/X/P), bonecos de treino.

---
Arena 1v1 de magia dinâmica em primeira pessoa, multiplayer por LAN.

## Como jogar

1. Extraia o zip e abra `DynMagic.exe`. O Windows pode mostrar o aviso do SmartScreen porque o executável não é assinado: clique em **Mais informações → Executar assim mesmo**.
2. **Jogar LAN**
   - Um jogador clica em **Criar sala** (porta UDP 7777; descoberta na LAN pela porta UDP 7778).
   - O outro escolhe a sala na lista ou digita o IP do host e clica em **Entrar**.
   - Os dois clicam em **Pronto**; o host clica em **Iniciar partida**.
   - O firewall do Windows pode pedir permissão na primeira vez: permita em redes privadas.
3. **Treino**: arena com boneco e alvo; teclas 1–4 trocam o elemento.

## Controles

| Ação | Tecla |
|---|---|
| Mover / pular / agachar / correr | WASD / Espaço / Ctrl / Shift |
| Compor magia (forma, depois efeito) | Q / E / R |
| Confirmar magia de mira | Botão esquerdo |
| Repetir última magia / cancelar mira | Botão direito |
| Cancelar composição | F |
| Placar | Tab |
| Overlay de rede | F3 |
| Pausa | Esc |

Na Escolha (draft) selecione o elemento pelas cartas (ou teclas 1–4) e, se perdeu o round anterior, uma runa (teclas 5–7); confirme com **Enter**. O round só começa quando os dois confirmam.

## O que tem nesta versão

- 4 elementos × 9 magias (36 combinações) com variações por elemento e status.
- Partida melhor de 7 com escolha de elemento (com confirmação), runas, Núcleo Arcano, Prorrogação com Colapso no padrão (ou Morte Súbita, Maré de Mana e Aleatório no lobby) e round decisivo.
- 3 arenas (Claustro, Pátio Partido, Espinha) em rotação.
- Menus, lobby, configurações (vídeo, áudio, teclas, acessibilidade), grimório, resultados.
- Visual toon com contorno de tinta; modelos estilizados gerados no Blender.

## Limitações conhecidas

- A câmera de morte é a última visão congelada (sem replay); o cartão de dano está presente.
- Música provisória (loop sintetizado), sem trilha licenciada.
- Conexão por LAN ou IP direto; sem relay/matchmaking pela internet.
- O servidor de três salas na VPS ainda não passou pelo teste de carga de 1 h; a fila de espera e o site público ficam para a próxima rodada.

## Linha de comando (testes)

`DynMagic.exe -- --host` ou `DynMagic.exe -- --join 192.168.x.x` entram direto na partida; `--lobby` entra no lobby; `--sim-latency 40 --sim-loss 0.02` simula rede ruim.

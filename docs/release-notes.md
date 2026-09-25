# DynMagic v0.3.0 — cajados e menus de grimório

## Novidades na 0.3.0

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

No draft (0:00) escolha o elemento pelas cartas (ou teclas 1–4) e, se perdeu o round anterior, uma runa (teclas 5–7).

## O que tem nesta versão

- 4 elementos × 9 magias (36 combinações) com variações por elemento e status.
- Partida melhor de 7 com draft alternado, runas, Núcleo Arcano, overtime aleatório (Colapso, Morte Súbita, Maré de Mana) e round decisivo.
- 3 arenas (Claustro, Pátio Partido, Espinha) em rotação.
- Menus, lobby, configurações (vídeo, áudio, teclas, acessibilidade), grimório, resultados.
- Visual toon com contorno de tinta; modelos estilizados gerados no Blender.

## Limitações conhecidas

- Personagens sem animação; braços em primeira pessoa ainda não aparecem.
- Som sintetizado provisório, sem música.
- Apenas LAN (sem internet/relay).

## Linha de comando (testes)

`DynMagic.exe -- --host` ou `DynMagic.exe -- --join 192.168.x.x` entram direto na partida; `--lobby` entra no lobby; `--sim-latency 40 --sim-loss 0.02` simula rede ruim.

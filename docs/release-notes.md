# DynMagic v0.1.1 — correções da primeira build (Windows x64)

## Novidades na 0.1.1

- **Menu do Esc** funcionando no treino e na partida: Voltar ao jogo, Configurações (abre por cima do jogo) e Sair/Desistir com confirmação.
- **Círculo de composição na mira**: três setores seguindo as teclas (Q em cima, E à esquerda, R à direita). Primeira tecla escolhe a forma — **P** Projétil, **S** Pessoal, **A** Área; a segunda escolhe o efeito — **D** Direto, **X** Explosivo, **P** Persistente. A cor segue o elemento, setores em recarga ficam apagados e, na mira, a combinação aparece no centro.
- **Modo treino** com 6 bonecos de treino (modelo novo): perto, meia distância, atrás de cobertura, na varanda, longe e dois que se movem de lado. Balançam ao receber dano e mostram DPS só quando atingidos.
- Removidos os placeholders do treino (cilindro e personagem).

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

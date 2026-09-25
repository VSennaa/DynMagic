# Spec 06 — UI, menus e configurações

## 1. Telas

| Tela | Conteúdo |
|---|---|
| **Menu principal** | Fundo 3D animado (arena em órbita lenta). Botões: Jogar LAN, Treino, Grimório, Configurações, Sair |
| **Jogar LAN** | Abas "Hospedar" e "Entrar". Hospedar: nome do lobby, porta, arenas (Fixa/Rotação/Aleatória), overtime (Aleatório/Colapso/Morte Súbita/Maré de Mana). Entrar: lista de lobbies descobertos + campo de IP manual |
| **Lobby** | 2 cartões de jogador (nome, pronto), regras escolhidas, botão Pronto, botão Sair. O host tem botão Iniciar |
| **Treino** | Arena escolhida + boneco com HP infinito e contador de DPS. Sem rede |
| **Grimório** | Referência interativa das 36 magias: escolhe elemento, forma e efeito e vê descrição, números e vídeo curto/prévia |
| **Draft** | Relógio 0:00 grande. Indicador "Lado A escolhendo / Lado B escolhendo". 4 cartões de elemento; o elemento já escolhido pelo oponente aparece travado. Runas para o perdedor em painel lateral. Placar no topo |
| **HUD** | Ver seção 2 |
| **Pausa (`Esc`)** | Não pausa a partida online. Mostra: Voltar, Configurações, Desistir (confirmação) |
| **Resultados** | Vencedor, placar por round, estatísticas (spec 02 §7), Revanche, Voltar ao lobby |

## 2. HUD

```
┌──────────────────────────────────────────────────────────────┐
│            [P1 ●●●○]   1:12   [○○●● P2]    OVERTIME: COLAPSO │
│                                                              │
│                                                              │
│                      ◯  ← mira                               │
│                  ┌────────┐                                  │
│                  │🔥▸◆▸ _ │ ← trilha de composição           │
│                  └────────┘                                  │
│                                                              │
│ HP ███████████░░ 78         CD: [Seta][Orbe][...9 ícones]    │
│ MN ██████░░░░░░ 52          Runa: Pressa   Sobrecarga 2/3    │
└──────────────────────────────────────────────────────────────┘
```

- **Trilha de composição** logo abaixo da mira: 3 caixas (elemento fixo, forma, efeito). A caixa atual pulsa. Mostra os ícones Q/E/R da próxima escolha. Na escolha de efeito, cada opção mostra um marcador de rápida (raio) ou confirmada (alvo).
- Em modo de mira: texto curto "LMB confirmar · RMB cancelar" e a prévia no mundo.
- Grade de cooldown 3 × 3 (forma × efeito) no canto inferior direito.
- Indicador de dano direcional nas bordas da tela.
- Números de dano flutuantes (opcional em configurações).
- Barra de captura do Núcleo aparece quando o jogador está no raio.

## 3. Configurações

Salvas em `user://settings.cfg` (`ConfigFile`). Aplicadas na hora. Botão "Restaurar padrão" por aba.

| Aba | Opções |
|---|---|
| Vídeo | Modo de janela (janela/borderless/tela cheia), resolução, escala de render (50–100%), VSync, limite de FPS (60/120/144/240/sem limite), FOV (80–110), qualidade de sombra, antialiasing (off/FXAA/MSAA 2×/4×), outline on/off, brilho |
| Áudio | Master, música, efeitos, UI, voz (sliders 0–100) |
| Controles | Sensibilidade do mouse, inverter Y, remapear todas as ações, modo de composição (**Sequencial** padrão / **Segurar**: segura a forma e aperta o efeito), forçar confirmação em todas as magias (desligado por padrão) |
| Jogo | Nome do jogador, números de dano, cor do círculo aliado/inimigo (acessibilidade), mostrar FPS, overlay de rede |
| Acessibilidade | Paleta para daltonismo (padrão, deuteranopia, protanopia, tritanopia), reduzir tremor de câmera, legenda de sons de magia |

Ações de input (`InputMap`): `move_forward`, `move_back`, `move_left`, `move_right`, `jump`, `crouch`, `sprint`, `slot_1` (Q), `slot_2` (E), `slot_3` (R), `compose_cancel` (F), `cast` (LMB), `recast` (RMB), `scoreboard` (Tab), `pause` (Esc), `net_overlay` (F3).

Implementação de vídeo: resoluções 1280×720, 1600×900, 1920×1080 (padrão), 2560×1440 e 3840×2160; escala 50–100%. Em janela, a resolução altera o tamanho da janela; em tela cheia, mantém o modo do desktop e define a resolução-base 3D, combinada com a escala (limites do viewport: 0,25–2×). Sombras baixa/média/alta usam atlas de 1024/2048/4096 e filtragem correspondente. FXAA e MSAA são mutuamente exclusivos. As opções são aplicadas imediatamente e persistidas por Salvar/Voltar em `user://settings.cfg`.

## 4. Diretrizes visuais da UI

- Tipografia: título em fonte com pincel/serifa (clima de grimório); números em sans condensada.
- Molduras com cantos de runa, como pergaminho sobre tinta escura.
- Cores de elemento da spec 01. UI neutra em preto azulado `#11161F` e creme `#F2E8D5`.
- Transições de tela: pincelada de tinta de 0,3 s.

## 5. Critérios de aceite

- [ ] Tudo navegável por teclado e mouse.
- [ ] Configurações persistem entre sessões e são aplicadas no boot.
- [ ] Remapeamento detecta conflito e pergunta se quer trocar.
- [ ] HUD legível em 1280×720 e 3840×2160 (UI com âncoras + escala por resolução).
- [ ] Nenhuma tela trava a thread principal por mais de 100 ms ao abrir.

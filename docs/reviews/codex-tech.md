# Auditoria técnica — alpha fechada 1.0

Data: 2026-09-25. Papel: liderança técnica de rede, servidor dedicado e robustez. Base: workspace em `eb2ed56`, incluindo arquivos presentes durante a leitura. Escopo: amigos, 1v1, três duelos simultâneos em Linux com 1 vCPU e aproximadamente 900 MB de RAM compartilhados com outros serviços.

**Parecer: não liberar a alpha 1.0 neste estado.** Há falhas demonstráveis pelo fluxo do código em validação de RPC, sincronização de objetos, reconexão e ciclo de vida da partida. A capacidade de três duelos no VPS ainda não está demonstrada; não há medição nesta auditoria que permita afirmar que cabe ou que não cabe.

Foram lidos `AGENTS.md`, `docs/HANDOFF.md`, `docs/SDD.md`, as oito specs, `docs/ROADMAP.md`, código de rede, partida, jogador, magias, testes e configuração de distribuição. Revisão estática: não executei Godot, exportação, testes de rede nem benchmark Linux, para não gerar arquivos além deste relatório. As reproduções abaixo são procedimentos propostos, não resultados de testes executados. O registro histórico de 73 testes aprovados não foi revalidado. Houve alteração concorrente em `scenes/ui/lobby_screen.gd`; não a modifiquei. `HANDOFF.md` foi preservado pela restrição explícita desta tarefa.

Prioridades: **P0 bloqueador**, **P1 importante**, **P2 desejável**. Esforço relativo: **S** mudança localizada; **M** vários pontos com teste de integração; **L** mudança de protocolo/arquitetura e validação abrangente. As referências são `arquivo:linha` do estado inspecionado.

## P0 — Bloqueadores

### T01 — Cliente decide onde colocar Marca e Muralha; entrada numérica não é saneada

- **Problema:** `_request_cast` encaminha `target` e `direction` sem verificar alcance, superfície, linha de visão ou valores finitos. A distância da origem é a única validação geométrica. Um cliente pode colocar Marca sobre o adversário do outro lado da arena ou Muralha em qualquer posição. Inputs também aceitam yaw/pitch não finitos.
- **Evidência:** `scenes/net/net_match.gd:232`, `scenes/net/net_match.gd:253`; a validação de alcance está apenas no cliente em `scenes/player/spell_caster.gd:28` e `scenes/player/spell_caster.gd:68`. O destino é usado diretamente em `scenes/spells/area_spell.gd:69` e `scenes/spells/area_spell.gd:100`. `autoload/net_codec.gd:26` lê floats sem saneamento; `scenes/player/player.gd:135` aplica a rotação recebida.
- **Impacto:** dano/obstrução fora das regras; NaN/INF podem contaminar transformações, consultas físicas e snapshots. Não afirmo crash nativo, mas o caminho até a simulação está aberto.
- **Correção concreta:** validar finitude de todos os componentes antes de qualquer cálculo; validar IDs, direção não nula e limites; reconstruir origem e posicionamento com raycasts do servidor, usando mira recebida e posição autoritativa. Aplicar alcance de Marca e distância de Muralha no host. Verificar obstrução entre origem autorizada e origem tolerada. Testar destino a 1 km, atrás de cobertura, dentro de collider, vetor zero e NaN/INF.
- **Esforço:** M.

### T02 — Muralhas destruídas continuam sólidas no cliente; projéteis e zonas divergem

- **Problema:** só o spawn inicial é replicado. Colisão, impacto, criação de zonas derivadas e expiração são recalculados em cada máquina, sem ID de objeto nem evento autoritativo de despawn. Dano é corretamente restrito ao host, mas isso impede o cliente de destruir sua cópia de uma muralha antes do tempo de vida.
- **Evidência:** `scenes/net/net_match.gd:267`–`282`; `scenes/spells/spell_node.gd:31`–`38`; `scenes/spells/wall.gd:63`–`77`; `scenes/spells/projectile.gd:40`–`64`; `scenes/spells/lingering_projectile.gd:16`–`20`; `scenes/spells/burst_projectile.gd:62`–`74`. `_spawn_spell` não recebe `spell_id` nem `server_tick`.
- **Impacto:** após quebrar uma muralha, o servidor deixa passar o jogador/projétil e o cliente ainda colide. Sementes podem desenhar a zona em outro ponto; hits e desvios de Vento não correspondem ao que se vê. É desync de gameplay, inclusive em cliente honesto.
- **Correção concreta:** servidor atribui ID e tick a cada objeto; replica impacto, criação de zona, alteração/destruição de barreira e despawn. Clientes usam colisão local de projétil apenas como previsão visual, corrigida pelo evento. Muralhas precisam da mesma existência/colisão em todos os peers. Teste: quebrar gelo antes de 5 s e atravessar imediatamente; semente acertando jogador móvel sob latência.
- **Esforço:** L.

### T03 — Reconexão no dedicado não atualiza o jogador no cliente sobrevivente

- **Problema:** o host renomeia o nó do jogador para o novo peer; o cliente que ficou na partida só recebe outro dicionário de nomes. `_rpc_welcome` não emite atualização de roster para conexões já estabelecidas. O bootstrap é enviado exclusivamente ao reconectado.
- **Evidência:** `autoload/net.gd:171`–`189`, `autoload/net.gd:211`; `scenes/net/net_match.gd:37`–`40`, `scenes/net/net_match.gd:146`–`163`. Snapshots de ID desconhecido são descartados em `scenes/net/net_match.gd:208`–`210`; spawn de magia também depende de encontrar esse jogador, linha 274.
- **Impacto:** no dedicado, o oponente pode desaparecer ou permanecer sob ID antigo no outro cliente; snapshots e magias posteriores do reconectado deixam de ser aplicados. O smoke histórico com listen server não prova este cenário de três processos.
- **Correção concreta:** usar um ID de participante estável separado do peer ENet. Como correção inicial, transmitir remapeamento old→new a todos, preservar o nó e referências a magias, atualizar transportes e confirmar aplicação antes de retomar. Publicar sinal de roster atualizado também em welcomes subsequentes. Testar servidor + A + B, queda/reentrada de B, verificando ambos os clientes, sem reiniciar A.
- **Esforço:** M.

### T04 — RPC de pronto pode reiniciar a cena durante combate; carregamento pode esperar para sempre

- **Problema:** `Lobby.can_start()` verifica apenas quantidade/pronto. Os flags permanecem verdadeiros depois de iniciar. Um `_request_ready(true)` durante combate, inclusive de espectador, dispara `_push` e pode agendar outro `_begin`. Além disso, o cliente envia loaded uma vez; se o servidor ainda não criou a FSM, a confirmação é descartada, sem retry nem prazo para LOADING.
- **Evidência:** `autoload/lobby.gd:49`–`87`, `autoload/lobby.gd:103`; `autoload/match_state.gd:115`–`124`; `scenes/net/net_match.gd:130`–`135`; `scenes/match/match_fsm.gd:70`, `scenes/match/match_fsm.gd:218`–`247`. `SceneRouter.go_to()` descarta pedidos enquanto ocupado em `autoload/scene_router.gd:27`–`34`.
- **Impacto:** recarregar `NetMatch` mantendo uma FSM ativa recria corpos e perde efeitos no meio da partida. Uma diferença normal de tempo de carregamento também pode deixar a sala indisponível indefinidamente.
- **Correção concreta:** aceitar pronto só de participante admitido, na geração atual do lobby; consumir/zerar flags na transição e impedir starts duplicados. Cancelar timer de autostart quando muda sessão/fase. Handshake explícito `load(match_id)` → `loaded(match_id)` → confirmação, com retry idempotente e timeout que retorna a sala a um estado utilizável. Testar loaded antecipado, cliente lento, spam de pronto em combate e saída durante o delay.
- **Esforço:** M.

### T05 — Interface por IP não permite entrar nas outras duas portas do VPS

- **Problema:** a entrada manual sempre usa 7777; não existe campo de porta nem interpretação de `IP:porta`. A descoberta não atravessa internet. Três servidores no mesmo IP precisam de três portas de jogo distintas.
- **Evidência:** `scenes/ui/play_lan.gd:39`–`40`, `scenes/ui/play_lan.gd:68`–`69`; `server/README.md:23`–`30`. `Net.join` suporta porta (`autoload/net.gd:102`), mas a UI não a expõe; CLI possui `--port` em `autoload/net.gd:350`.
- **Impacto:** amigos usando o fluxo documentado só acessam uma das três salas. Existe contorno por CLI, mas ele precisa incluir `--lobby` para seguir o fluxo de pronto do dedicado.
- **Correção concreta:** campo de porta validado (1–65535) ou parser de endereço, persistência do último destino e instruções por sala. Proposta: UDP 7777, 7779 e 7780, reservando 7778 para descoberta LAN. Contorno temporário documentado: `DynMagic.exe -- --join <IP> --port 7779 --lobby`.
- **Esforço:** S.

## P1 — Importantes

### T06 — Snapshot não restaura os estados que determinam gameplay e previsão

- **Problema:** snapshot contém máscara de status, mas o receptor a ignora; também não traz cooldowns, duração/intensidade de slow, knockback, estado de dash e morte. Só HP/mana/escudo são escritos diretamente. Rejeição de cast apenas gera warning, apesar de o cliente já ter gasto mana e iniciado cooldown.
- **Evidência:** `scenes/player/net_sync.gd:212`–`226`; `scenes/net/net_match.gd:204`–`218`, `scenes/net/net_match.gd:285`–`287`; `scenes/player/player.gd:385`–`390`; `scenes/player/stats.gd:117`–`135` concentra o sinal de morte, que atribuir `hp` diretamente não emite. O bootstrap completo existe apenas para reconexão em `scenes/player/stats.gd:51`–`70`.
- **Impacto:** gelo prende/retarda no host enquanto o cliente continua prevendo velocidade normal; cooldown rejeitado continua bloqueando input; eventos de dano/morte e estado mostrado não têm correspondência completa. O servidor continua decidindo dano, porém a interação fica inconsistente.
- **Correção concreta:** definir estado autoritativo compacto com os modificadores necessários à previsão; aplicar transições por uma função de importação que emita eventos uma vez. Identificar casts por sequência; resposta aceita/rejeitada reconcilia custo, cooldown e VFX. Testar slow/root, knockback, morte por DoT e cast rejeitado durante troca de fase.
- **Esforço:** L.

### T07 — Reconciliação reaplica inputs sobre temporizadores e estado físico do presente

- **Problema:** rollback restaura só posição/velocidade. O replay chama `Player.simulate`, que altera dash, invulnerabilidade, glide, coyote, altura, knockback e estados de salto. Esses valores não são restaurados ao ack. Erros menores que 5 cm são ignorados; não há a correção suave descrita na spec.
- **Evidência:** `scenes/player/net_sync.gd:110`–`131`; `scenes/player/player.gd:156`–`219`, `scenes/player/player.gd:245`; histórico armazena somente frame/posição, `scenes/player/net_sync.gd:99`. `_start_round` tampouco limpa histórico/buffer de transporte (`scenes/net/net_match.gd:389`–`401`).
- **Impacto:** correções durante dash, pulo e efeitos usam uma simulação diferente da original; cada replay pode consumir novamente tempo de buffs. Snapshots anteriores ao respawn também podem corrigir para a arena/round anterior, pois não existe geração de round no pacote.
- **Correção concreta:** capturar/restaurar um `MovementState` completo no tick reconhecido, separar efeitos/eventos irreversíveis do replay e invalidar históricos em teleporte/respawn/mudança de geração. Corrigir o corpo autoritativamente e suavizar apenas o visual/câmera. Testar dash, crouch sob teto, salto duplo e round novo com snapshots atrasados.
- **Esforço:** L.

### T08 — Regras de cast diferem entre jogador do host e cliente

- **Problema:** o host aceita `is_recast` sem compará-lo à última magia, não aplica o lockout global de 150 ms e não consome as três cargas de Sobrecarga no caminho remoto. A composição recebida só muda o círculo; não bloqueia sprint na simulação remota.
- **Evidência:** `scenes/net/net_match.gd:242`–`250`; desconto Eco em `scenes/player/player.gd:456`–`459`; consumo de Sobrecarga só em `scenes/player/player.gd:388`–`389`; lockout em `scenes/player/spell_composer.gd:21`, `scenes/player/spell_composer.gd:208`; `scenes/player/net_sync.gd:203`–`209` versus `scenes/player/player.gd:90`, `scenes/player/player.gd:198`.
- **Impacto:** cliente modificado obtém desconto Eco em qualquer magia e conjura combinações diferentes no mesmo instante. No dedicado, casts remotos mantêm gratuidade durante os 10 s, ultrapassando três magias. Cliente honesto que segura sprint ao compor sofre divergência de velocidade.
- **Correção concreta:** concentrar aceitação/custo/cooldown/lockout/consumo de buff numa função autoritativa comum ao listen host e remoto; validar recast contra `last_spell`. Definir composição/sprint no estado autorizado. Testar quarta magia de Sobrecarga, Eco com magia diferente e dois casts de chaves distintas no mesmo tick.
- **Esforço:** M.

### T09 — Decodificação e admissão permitem amplificação e ocupação indefinida

- **Problema:** decoder não verifica tamanho: lê um count arbitrário até 255, mesmo de pacote truncado; a fila só é limitada depois de decodificar/ordenar. Não há limite de frequência dos RPCs nem prazo de hello. Cinco conexões ENet sem handshake podem ocupar todas as vagas. Um espectador pode repetir hello, causando welcome broadcast, e tentar depois papel de jogador sem remoção do mapa de espectadores.
- **Evidência:** `autoload/net_codec.gd:26`–`40`; `scenes/player/net_sync.gd:136`–`145`; `autoload/net.gd:19`, `autoload/net.gd:135`–`168`, `autoload/net.gd:211`–`224`; `autoload/lobby.gd:65`–`77` aceita pronto sem filtrar participante.
- **Impacto:** consumo de CPU/banda/logs num VPS compartilhado, indisponibilidade sem precisar ganhar uma partida; identidade simultânea nos dois mapas pode desviar a limpeza de disconnect.
- **Correção concreta:** exigir `1 + count * 16` bytes e count entre 1 e 3 no formato atual; rejeitar lixo/truncamento, bits inválidos, saltos de sequência e entradas não finitas. Limitar bytes/RPCs por peer antes do trabalho caro; expirar peers sem hello; fixar papel uma vez admitido. Reduzir/desabilitar espectadores na alpha. Não ampliar `MAX_CLIENTS` para simular três duelos.
- **Esforço:** M.

### T10 — Nome público funciona como credencial de reconexão; duas quedas sobrescrevem a reserva

- **Problema:** qualquer peer com o mesmo nome recupera o slot. Nomes não são únicos. Só existem `disconnected_id` e `reconnecting_id`; outra queda durante PAUSED sobrescreve o primeiro, embora a FSM ignore a segunda chamada de pausa.
- **Evidência:** `autoload/match_state.gd:49`–`74`; `autoload/net.gd:156`–`168`; `scenes/match/match_fsm.gd:176`–`187`. O nome normalizado como identidade é explicitamente previsto em `docs/specs/04-networking.md`, seção 10.
- **Impacto:** sequestro do personagem/placar e perda de recuperação do primeiro jogador quando ambos caem. A partida pode retomar sem todos os participantes ou atribuir W.O. ao slot errado.
- **Correção concreta:** token de retomada imprevisível vinculado à sessão e slot estável, nome apenas visual; reservas por participante com deadline, bootstrap e confirmação individuais. Retomar só com todos os slots necessários sincronizados. Definir abandono dos dois como encerramento sem vencedor e retorno ao lobby. Para sala fechada, adicionar segredo de convite ou restrição de rede; isso complementa, não substitui, validação de RPC.
- **Esforço:** M.

### T11 — Reconexão no overtime reaplica efeitos de entrada sobre o bootstrap

- **Problema:** bootstrap de reconexão aplica Stats/runtime, mas não carrega `_overtime_applied`. Retomar sudden death executa novamente a inicialização do overtime no cliente reconectado, apagando escudos concedidos depois de seu início. Também faltam campos de postura/altura necessários à restauração física completa.
- **Evidência:** `scenes/net/net_match.gd:167`–`186`, `scenes/net/net_match.gd:503`–`513`; lista de campos em `scenes/net/reconnect_state.gd:5`; postura em `scenes/player/player.gd:245`–`265`.
- **Impacto:** bootstrap aparentemente bem-sucedido pode ser sobrescrito imediatamente por efeitos de entrada de fase. O caso mais direto é escudo adquirido durante Morte Súbita desaparecer só para quem reconectou.
- **Correção concreta:** separar efeitos autoritativos de entrada de fase de atualização de apresentação; bootstrap informa fase/geração e flags já aplicados, sem reaplicar regras. Restaurar também postura/altura e limpar buffers. Testar reconexão em DRAFT, COUNTDOWN, cada overtime, com escudo e enquanto agachado.
- **Esforço:** M.

### T12 — Morte simultânea e fronteira de round não são resolvidas atomicamente

- **Problema:** o primeiro `Stats.died` encerra o round; `both_died()` só é chamado pelo teste unitário. Colapso aplica dano sequencialmente. A transição para DRAFT reseta jogadores, mas não remove magias nem zera todo o runtime, e `frozen` não impede dano nem dash já iniciado.
- **Evidência:** `scenes/net/net_match.gd:126`, `autoload/match_state.gd:140`–`142`; `scenes/match/collapse_zone.gd:53`–`57`; `scenes/match/match_fsm.gd:141`–`154`; `tests/test_match_fsm.gd:169`–`173`; `scenes/net/net_match.gd:389`–`401`; `scenes/player/player.gd:156`–`174`, `scenes/spells/zone.gd:32`–`49`.
- **Impacto:** vencedor depende da ordem dos nós em morte dupla. Zona/muralha remanescente pode atingir jogador recém-resetado durante draft; morte nessa fase é ignorada pela FSM e pode deixar alguém morto ao começar combate. Buffs e deslocamento podem atravessar a fronteira de round.
- **Correção concreta:** acumular mortes do tick, resolver uma vez com HP pré-tick; centralizar `reset_round` para transporte, runtime e objetos. Persistência do morto vale até fim daquele round, nunca para o seguinte. Fazer dano elegível por fase/geração. Testar dois jogadores com 5 HP fora do colapso e zona ativa junto ao spawn na troca de round.
- **Esforço:** M.

### T13 — Lag compensation e previsão visual não cobrem o caminho WAN real

- **Problema:** cast reliable não leva tick/seq/horário; rewind usa RTT/2 + 100 ms fixos. Histórico guarda só posição, sem interpolação, e busca candidatos pela posição atual com margem `rewind * 12`, insuficiente para dash/teleporte. O RPC de spawn não adianta projétil pelo atraso. O simulador só atrasa inputs e snapshots, deixando casts imediatos no teste local.
- **Evidência:** `scenes/net/net_match.gd:228`, `scenes/net/net_match.gd:279`–`282`; `scenes/player/net_sync.gd:74`–`79`; `scenes/spells/area_spell.gd:53`–`60`, `scenes/spells/area_spell.gd:119`; `autoload/net.gd:241`; `scenes/player/spell_caster.gd:84`–`106`.
- **Impacto:** teste de movimento com 80 ms não valida conjuração com 80 ms reais. Leque pode deixar de atingir alvo cuja posição histórica era válida; magia local aguarda ida e volta para nascer, apesar da previsão prometida pela spec. Dash usa input/mira do momento do spawn, que pode diferir entre peers.
- **Correção concreta:** pedido identificado e vinculado a tick de input, relógio estimado com limite de rewind imposto pelo servidor; testar diretamente os dois hurtboxes históricos do duelo, sem broadphase pela posição atual. Definir tratamento de teleporte e cobertura dinâmica. VFX imediato identificado por cast; spawn contém estado/tick autoritativo. Validar latência/jitter/perda nos dois sentidos, incluindo reliable, com teste de rede externo ao jogo.
- **Esforço:** L.

### T14 — Headless ainda executa apresentação e síntese; frequência de gameplay depende de `_process`

- **Problema:** dedicado cria HUD/menus, magos animados, efeitos e materiais. AudioBus carrega samples e sintetiza som de cada combinação na primeira conjuração; apenas música tem guarda headless. Settings aplica limite de FPS de cliente, padrão 144. Marca, vida/contato de muralha e evolução do colapso usam `_process`, enquanto movimento/zonas usam física.
- **Evidência:** `scenes/net/net_match.gd:44`–`68`, `scenes/net/net_match.gd:327`; `scenes/player/player.gd:99`, `scenes/player/player.gd:421`–`433`; `autoload/audio_bus.gd:46`–`63`, `autoload/audio_bus.gd:166`–`200`; `autoload/settings.gd:45`–`48`, `autoload/settings.gd:196`; `scenes/spells/area_spell.gd:36`, `scenes/spells/wall.gd:63`, `scenes/match/collapse_zone.gd:40`.
- **Impacto:** trabalho sem benefício no servidor, picos de primeira conjuração e timings dependentes da frequência do loop. Stripping de assets não elimina GDScript nem nós criados em runtime.
- **Correção concreta:** caminho dedicado sem UI, animação, nameplates, partículas, luzes e áudio; preservar câmera/transform de mira usado pelo gameplay, formas/colliders e dados de magias. Separar apresentação antes de remover recursos referenciados. Migrar temporizadores de gameplay para física. Manter inicialmente **60 Hz físicos / 30 Hz snapshots**, configurar loop headless independentemente do Settings do usuário, e medir antes de baixar para 30/20. Preferir colliders primitivos pré-construídos ao rebuild de CSG (`scenes/arena/arena_builder.gd:201`).
- **Esforço:** M.

O preset já sinaliza dedicado (`export_presets.cfg:51`), o que é positivo. A documentação oficial explica que Strip Visuals substitui texturas/materiais e que remover recursos ainda referenciados quebra carregamento; áudio exige tratamento separado. A afirmação ampla de “recursos visuais removidos” em `server/README.md:45` não comprova a ausência do trabalho de apresentação acima. [Godot: exportação dedicada](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html).

### T15 — Três duelos: arquitetura permite três processos, mas não há orçamento medido

- **Problema:** `Net`, `Lobby`, `MatchState`, `current_scene` e grupos globais representam uma única partida. Colocar três arenas no processo atual misturaria busca de jogadores/zonas, FSM e RPCs. O benchmark de GPU registrado no handoff não mede servidor Linux nem recursos compartilhados.
- **Evidência:** `autoload/match_state.gd:9`, `autoload/match_state.gd:223`; `autoload/net.gd:39`–`40`; `scenes/player/spell_caster.gd:105`; `scenes/spells/projectile.gd:103`; serviço único em `server/dynmagic.service:10`; teste CI em `.github/workflows/release.yml:46`–`52` apenas abre a sala.
- **Impacto:** não se pode aprovar o requisito de três duelos por contagem de polígonos ou sucesso de um servidor ocioso. CPU saturada atrasa ticks; pressão de memória pode afetar os outros serviços.
- **Correção concreta:** para 1.0, três processos do mesmo export release, um duelo por porta, unidades `dynmagic@.service` e configuração/estado por instância. Isolam crash e exigem menos mudança. Compartilhar binário pode compartilhar páginas de código, mas heaps/simulações continuam separados: medir memória agregada do cgroup/PSS, não supor custo igual a um processo. Só considerar várias partidas no processo se medições exigirem: `MatchContext`, mundos físicos e RPCs por sala, identidades estáveis, remoção das consultas globais. Isso é esforço L adicional e amplia o domínio de falha.
- **Esforço:** M para três serviços + benchmark; L para multi-match no processo.

**Gate de capacidade proposto:** medir baseline real de SO/outros serviços; orçamento do jogo = memória total menos baseline menos margem acordada. Rodar três servidores release e seis clientes fora do VPS durante pelo menos uma hora, incluindo todos os elementos, primeiras conjurações, Maré de Mana, reconexões, rotações de arena e rematches. Coletar pico/estabilidade de memória, CPU total, p95/p99 de tick, atraso de snapshots, throttling/steal e swap/OOM. A 60 Hz há 16,67 ms de prazo e, num único core, o trabalho dos três precisa caber junto com os outros serviços. Aprovar apenas com folga, sem crescimento entre partidas, sem OOM/swap recorrente e sem estourar o prazo sustentadamente. Esses são critérios propostos, não números já alcançados.

### T16 — Falha ao abrir porta deixa processo vivo; serviço não detecta travamento lógico

- **Problema:** `host()` retorna erro, mas o ramo `--server` não encerra o processo. A cena principal de menu pode continuar viva sem servidor. `Restart=on-failure` não ajuda enquanto o processo continua. Serviço não possui configuração por instância, orçamento agregado nem health check de progresso.
- **Evidência:** `autoload/net.gd:85`–`89`, `autoload/net.gd:376`–`379`; `project.godot:16`; `server/dynmagic.service:7`–`18`. Troca de cena ignora `Error` em `autoload/scene_router.gd:34`.
- **Impacto:** systemd pode mostrar serviço ativo que não aceita ninguém; conflito de porta durante deploy torna a sala indisponível sem recuperação. Crash reinicia, mas não restaura a partida, o que precisa ser uma decisão operacional explícita.
- **Correção concreta:** validar flags/porta no boot; falha de bind/carregamento encerra com código não zero e mensagem clara. Template por instância, restart/backoff e limite de tentativas; heartbeat de tick/fase para detectar travamento. Agrupar as três unidades numa slice com accounting e limites calculados pelo T15; `MemoryHigh`/`MemoryMax`, `TasksMax` e política de CPU devem proteger os demais serviços sem induzir throttling constante. Firewall permite apenas portas de jogo necessárias; broadcast 7778 é LAN e pode ser desligado no VPS. Registrar que crash cancela o duelo e permite nova partida, sem prometer persistência.
- **Esforço:** M.

Os controles de memória/CPU são mecanismos disponíveis no systemd; os valores devem vir da medição, não de dividir 900 MB por três. [Fonte oficial: systemd resource control](https://cgit.freedesktop.org/systemd/systemd/tree/man/systemd.resource-control.xml).

### T17 — Build compatível é definido só pelo número 2; deploy e rollback não têm contrato

- **Problema:** versão de aplicativo e de protocolo estão separadas, mas hello não inclui versão de conteúdo/regras. Builds com mesmos RPCs e dados de magia diferentes passam no handshake, embora o cliente simule projéteis e buffs a partir dos próprios Resources.
- **Evidência:** `autoload/net.gd:12`, `autoload/net.gd:131`–`142`; `project.godot:15`; `scenes/net/net_match.gd:275`; `scenes/spells/projectile.gd:22`–`32`; empacotamento/publicação em `.github/workflows/release.yml:54`–`66`; instalação em `server/README.md:34`.
- **Impacto:** amigos com executável antigo podem entrar e obter outra trajetória/cooldown. Atualizar binário em uso sem política por instância pode interromper os três duelos; rollback operacional não está descrito.
- **Correção concreta:** hello com protocolo + hash/versionamento de conteúdo de gameplay; mensagem amigável com release esperada. Manifesto com tag/commit/hash do artefato, diretórios imutáveis por release e ponteiro para versão ativa. Drenar ou encerrar duelos explicitamente, atualizar instâncias, validar conexão, conservar versão anterior para rollback. Não exigir hash de arte se ela não muda regras.
- **Esforço:** M.

### T18 — CI pode publicar servidor que só imprimiu a mensagem inicial

- **Problema:** import ignora erro; smoke tolera timeout/exit inválido e considera sucesso achar uma linha de log. Não joga partida nem roda suites. Testes existentes validam estruturas/FSM isoladas e deixam escapar integração de dano, transporte e dedicado.
- **Evidência:** `.github/workflows/release.yml:38`, `.github/workflows/release.yml:50`–`52`; `tests/test_net_serialization.gd:10`, `tests/test_net_serialization.gd:32`; `tests/test_reconnect_stats.gd:8`; `tests/test_match_fsm.gd:169`. O bot só compõe Seta em `scenes/net/net_match.gd:307`–`309`.
- **Impacto:** export quebrado depois do boot ainda é distribuído. “73 testes” não mede as garantias necessárias à alpha dedicada.
- **Correção concreta:** gate de exit code, ausência de erros de script/RPC e timeout como falha; runner versionado de testes puros e integração real de três processos. Exigir partida → resultados → lobby → segunda partida, reconexão validada nos dois clientes, W.O., duas quedas, loading lento, porta ocupada, incompatibilidade, RPCs inválidos, dano/expiração de muralha e reset de round. Executar WAN com reliable afetado e carga de três duelos separadamente. Arquivar logs, versão e métricas no CI; não depender de harnesses ignorados em `build/`.
- **Esforço:** M, além do gate de capacidade T15.

## P2 — Desejáveis

### T19 — Overlay e logs não permitem diagnosticar atraso real de simulação

- **Problema:** cliente exibe `_tick` local que só é incrementado no host; “perda” é configuração do simulador, não perda observada. Log de posição a cada 2 s é permanente e faltam IDs de sessão/round nas operações críticas.
- **Evidência:** `scenes/net/net_match.gd:92`, `scenes/net/net_match.gd:205`, `scenes/net/net_match.gd:312`–`320`, `scenes/net/net_match.gd:340`–`343`; `autoload/net.gd:241`.
- **Impacto:** difícil distinguir gargalo do VPS, perda de pacotes, reconciliação e incompatibilidade. Spam amplifica custo de logs sem oferecer diagnóstico proporcional.
- **Correção concreta:** nível de log configurável, tick recebido/idade do snapshot, jitter, gaps de sequência, backlog, correções por segundo, p95/p99 do tick, entidades ativas e memória. Incluir match/round/build/peer nos eventos de admissão, desconexão e transição. Não registrar tokens de reconexão.
- **Esforço:** S–M.

### T20 — Espectador que entra no meio da partida não recebe bootstrap completo

- **Problema:** welcome envia espectador para a arena, mas não chama `restore_client`; snapshot regular não traz objetos ativos. `_last_round=0` só dispara inicialização de arena em DRAFT. Em combate de B/C, o espectador pode continuar com a arena A da cena inicial.
- **Evidência:** `autoload/net.gd:181`–`185`; `scenes/net/net_match.gd:134`–`135`, `scenes/net/net_match.gd:155`, `scenes/net/net_match.gd:357`–`363`; `scenes/net/net_match.tscn:4`.
- **Impacto:** observação enganosa e recursos extras sem cumprir a função; não bloqueia duelos se o recurso for desligado.
- **Correção concreta:** desabilitar espectadores na alpha ou reutilizar bootstrap completo com barreira de carregamento, sem conceder autoridade/slot. Testar entrada em cada arena e overtime com objetos ativos. Só reabrir quando houver orçamento medido.
- **Esforço:** S para desabilitar; M para suportar corretamente.

## Discordancias provaveis com design

- **LAN não define mais o limite de confiança.** O SDD classifica trapaça como risco baixo porque o projeto era LAN; IP público e amigos não tornam pacote confiável. Sanear números, limitar RPC e autenticar retomada são requisitos de robustez, sem exigir anticheat invasivo ou contas.
- **Reconexão por nome precisa mudar.** É decisão explícita da spec 04, mas conflita com posse de slot em servidor público. Token de sessão preserva o fluxo amigável sem transformar nome em senha.
- **Três duelos não exigem seis jogadores na mesma partida.** Manter 1v1 por processo para 1.0 é a opção de menor mudança. Multi-match no mesmo processo exige isolamento real; só se justifica por medição de custo, não pela suposição de que sempre consome menos.
- **60/30 Hz deve ser baseline validado, não promessa incondicional.** Se três duelos não couberem após remover apresentação e medir, escolher entre aumentar VPS, reduzir simultaneidade ou testar novo tick rate. Baixar frequência silenciosamente altera previsão, timers e sensação de jogo.
- **Simulação “determinística nos dois lados” não substitui eventos autoritativos.** Mundos com oponentes interpolados, atraso e barreiras diferentes não produzem impactos iguais. Servidor precisa publicar resultado e existência dos objetos; cliente prevê apresentação.
- **Previsão não significa só guardar posição.** Dash, slow, knockback, cooldown e transições precisam de contrato de rollback/ack. A spec promete VFX imediato e correção suave que o caminho atual não entrega integralmente.
- **Persistência das magias do morto termina na fronteira do round.** Manter até expirar pode valer durante ROUND_END, mas levar dano para o próximo draft compromete o reset. Morte simultânea deve ser resolvida no fim do tick, não pela ordem dos sinais.
- **Draft de 20 s e escolha de runa estão inconsistentes.** `scenes/match/match_fsm.gd:112` encerra assim que B escolhe, enquanto spec 02 concede 20 s à runa. Decidir entre duração fixa e conclusão antecipada com confirmação explícita da runa; não deixar a escolha do adversário encerrar involuntariamente essa janela.
- **Espectadores e recuperação após crash são escopos separados.** Recomendo espectadores desligados na primeira alpha e crash cancelando somente o duelo afetado, com serviço voltando ao lobby. Persistência de partida após reiniciar processo não é necessária para uma alpha entre amigos, mas a limitação precisa ser comunicada.
- **Critério de pronto precisa incluir o dedicado e a WAN.** Revisão visual, benchmark de GPU e soak de Seta em listen server não substituem os gates T15/T18. Liberação requer resolver P0, tratar os P1 que afetam integridade da partida e provar três duelos sob o orçamento real.

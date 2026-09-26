# DynMagic — revisão de game design e level design, rodada 2

26/09/2026 · Base: workspace v1.1.0-alpha · Revisão estática de código e documentação.

**Direção recomendada: um duelo de autoria espacial.** Compor magia deve servir para induzir uma resposta, conquistar um ângulo e punir uma decisão. Hoje existem ferramentas para isso, mas a matriz de nove magias, os bônus elementais e as arenas ainda não organizam essas ferramentas em planos de combate suficientemente distintos.

Foram lidos `AGENTS.md`, `docs/HANDOFF.md`, `docs/SDD.md`, as oito specs, `docs/reviews/SYNTHESIS.md`, os arquivos de `scenes/arena/`, `scenes/player/`, `scenes/spells/`, `scenes/match/` e `data/`. Também foram consultados os pontos de integração em `net_match.gd`, `SpellDB` e o teste de layout. Não houve playtest humano, execução do jogo ou medição de win rate nesta revisão. As consequências de balanceamento abaixo são hipóteses fundamentadas; dimensões propostas são parâmetros de protótipo, não resultados já validados.

O status concluído da rodada 8 no HANDOFF e o código atual prevalecem, para descrever a implementação, sobre trechos históricos: cargas, intervalo de 0,3 s, melee V, pré-cast G e anéis de persistência **já existem**. A spec 01 ainda descreve multiplicadores antigos e recast de rápidas; não os trato como comportamento atual. As referências estéticas são interpretadas conforme `docs/specs/07-art-pipeline.md:5`; nenhuma medida aqui é atribuída a mapas oficiais de Valorant.

Somente este relatório foi escrito. A instrução específica de não modificar outros arquivos prevalece sobre a atualização habitual do HANDOFF.

## Prioridades e fronteiras

S = dados/assets ou trabalho localizado; M = um subsistema ou greybox com validação; L = vários subsistemas e integração multiplayer. **CRITICAL** exige engenharia cuidadosa de autoridade, colisão, estado ou sincronização. **SIMPLE** é composição de geometria, dados ou assets com comportamento já suportado; não significa dispensar playtest.

| ID | Prioridade | Refactor | Esforço | Natureza |
|---|---|---|---|---|
| R1 | P0 | Contrato único entre cobertura, área de efeito e Núcleo | L | CRITICAL |
| R2 | P0 | Quatro planos elementais e nove funções com propósito | L | CRITICAL |
| R3 | P0 | ArenaBuilder orientado a espaços e métricas | M | CRITICAL |
| R4 | P1 | G como preparação legível; V como compromisso de curta distância | M | CRITICAL |
| R5 | P1 | A: Claustro como circuito de aproximação e reposicionamento | M | SIMPLE, após R3 |
| R6 | P1 | B: Pátio Partido como disputa de altura descontínua | M | SIMPLE, após R3 |
| R7 | P1 | C: Espinha como dois salões conectados, sem frestas obrigatórias | M | SIMPLE, após R3 |
| R8 | P1 | Round em três atos e Núcleo que exige converter vantagem | M | CRITICAL |
| R9 | P1 | Arco MD7 com revanche espacial e runas de adaptação | M | CRITICAL |
| R10 | P2 | Arquitetura e magia com vocabulário visual compartilhado | M | SIMPLE |

Preservar como base: primeira pessoa, um mago, quatro elementos, um elemento por round, dois inputs de composição, MD7, escolha alternada sem elementos iguais, três arenas e simetria rotacional. Preservar também as decisões D1/D2: três cargas de Seta, recast apenas de confirmadas e multiplicadores 1,05/0,95/1/0,95. Não proponho um segundo elemento, árvore de talentos ou mais magias.

As mudanças de status/variantes em R2, operação de G em R4, captura/recompensa/cronograma em R8 e rotação/runas em R9 são **propostas de revisão de decisões**, não decisões já aprovadas. R5–R7 preservam a família visual e o envelope das arenas, mas substituem sua geometria interna. Nada foi implementado.

## R1 — P0: cobertura precisa significar a mesma coisa em todo o duelo

**Problema.** O jogador não pode planejar uma aproximação se um bloco protege de Leque, mas não necessariamente de uma explosão, ou se o pedestal visual não define o lugar de captura. Esses contratos afetam todo o desenho de mapas; não se resolvem adicionando mais caixas.

**Evidência.** Leque verifica linha de visão em `scenes/spells/area_spell.gd:48` e `:120`. Marca usa sobreposição sem a mesma filtragem em `:81`; Orbe faz isso em `scenes/spells/burst_projectile.gd:21`. A consulta comum em `scenes/spells/spell_node.gd:46` retorna damageables sobrepostos, sem oclusão. Zonas consultam uma esfera em `scenes/spells/zone.gd:51`. Melee elimina a distância vertical e não consulta obstrução em `scenes/player/player.gd:655`. Núcleo fica sempre em `(0,3,0)` em `scenes/net/net_match.gd:604`, enquanto a captura zera Y em `scenes/match/arcane_core.gd:64`. O pilar A tem 3 m e o builder só cria rampas laterais (`scenes/arena/arena_builder.gd:23`, `:138`), embora a spec prometa uma rampa até o Núcleo (`docs/specs/03-arenas.md:68`).

**Proposta.** Definir três contratos espaciais reutilizáveis:

1. **Impacto:** Seta e melee exigem percurso desobstruído até o corpo; melee usa volume tridimensional, não disco infinito em altura. Leque mantém seu cone com oclusão.
2. **Explosão:** Orbe e Marca propagam a partir do centro de detonação e testam exposição do corpo. Um sólido alto protege; uma quina parcialmente exposta pode receber dano proporcional por poucas amostras fixas do corpo. Semente pode ser lobada sobre a cobertura para colocar a origem do efeito atrás dela. Sem dano atravessando pedra por proximidade radial.
3. **Território:** zona define uma superfície/piso e altura útil explícita; não afeta automaticamente alguém no andar superior. Núcleo recebe `CoreAnchor` e volume capturável do mapa, com piso acessível, raio de 2 m e tolerância vertical inicial de 0,5 m. Os três layouts propostos colocam a captura no solo, com círculo inteiro fora de sólidos.

Para barreiras, declarar separadamente `blocks_movement`, `blocks_projectiles` e `blocks_blast`. Transparência visual não decide colisão. Gelo bloqueia os três; Vento bloqueia projéteis e propagação de explosão, mas permite pessoas; Raio permite atravessar e pune a travessia; Fogo passa a ser uma cortina atravessável de dano em R2. Cada comportamento terá aparência própria.

**Efeito esperado.** Coberturas passam a sustentar leitura, contrajogo e testes reproduzíveis. Marca ameaça uma posição exposta; Semente conquista o lado protegido pelo arco. Altura deixa de ser uma exceção invisível da captura e do dano.

**Esforço: L · CRITICAL.** Centralizar consultas e filtros, decidir comportamento em quinas/pisos, validar no host e sincronizar resultados. Gate: dois jogadores separados por parede não se acertam com melee/explosão bloqueada; um Semente que aterrissa do outro lado funciona; andar superior não captura nem recebe zona do térreo. Não iniciar balanceamento comparativo dos mapas antes desse contrato.

## R2 — P0: trocar uma coleção de bônus por quatro planos de combate

**Problema.** Muitos diferenciais são aumentos passivos ou efeitos que duplicam outra célula. A mesma sequência de disparar, proteger-se e esperar pode servir a todos. Nove botões úteis não equivalem a nove decisões distintas.

**Evidência.** Variantes e números estão em `data/elements/fire.tres:14`, `frost.tres:14`, `storm.tres:14` e `wind.tres:14`. Fogo acumula dano direto, queimadura e Aura de dano; o status soma duração até 2× (`scenes/player/stats.gd:171`). Gelo tem slow em Seta, Leque e Semente, root na Marca e dois pessoais defensivos. A Aura de Gelo atualmente concede escudo uma vez (`scenes/spells/self_spell.gd:37`), não uma regeneração contínua de 15/s. Raio tem velocidade, redução de recarga e Marca mais rápida; o encadeamento do Orbe procura outro alvo fora dos já atingidos (`scenes/spells/burst_projectile.gd:46`). Num 1v1 ele não cria uma segunda vítima após acertar o único oponente; pode alcançar esse oponente fora da explosão ou interagir com outros damageables. Vento tem três defesas antiprojetil: Guarda, Semente e Muralha (`scenes/player/player.gd:331`, `scenes/spells/projectile.gd:101`, `scenes/spells/wall.gd:45`).

**Proposta.** Manter a matriz 3×3 e os multiplicadores, mas atribuir uma pergunta exclusiva a cada célula. Criar uma interação de preparação/conversão por elemento, sem empilhar novos medidores.

| Elemento | Plano e distância desejada | Preparação → conversão | Fraqueza e resposta adversária |
|---|---|---|---|
| Fogo | Expulsar de cobertura, sustentar pressão a 6–14 m | Incendiar uma saída com Semente; Seta aplica queimadura; Leque consome a queimadura para antecipar parte do dano restante, sem criar dano total extra | Sem escudo refletor passivo; adversário muda de saída e força Fogo a atravessar uma linha aberta |
| Gelo | Escolher onde a luta acontece, 5–12 m | Semente restringe uma rota; Marca captura a saída prevista com root curto; Seta pune a trajetória sem renovar slow continuamente | Quem troca de rota antes da Marca evita o controle; destruir/contornar Muralha custa menos que alimentar uma sequência de controle |
| Raio | Criar e converter uma abertura breve, 10–22 m | Semente ou Guarda quebrada aplica Choque; o próximo impacto direto o consome; Impulso muda o ângulo para buscar esse impacto | Choque expira se Raio não expuser o corpo; cobertura e pressão na saída do teleporte negam a conversão |
| Vento | Alterar distâncias e ângulos, 4–12 m | Semente move corpos numa direção; Leque empurra para fora do anel; Impulso/Aura reposiciona o próprio jogador | Sem dano residual gratuito; um rival com cobertura lateral e segunda rota não precisa disputar a mesma borda |

São faixas de projeto, não restrições de dano nem números medidos. Não adicionar bônus por estar nessas faixas.

### Função de cada forma/efeito depois de 1.1

| Célula | Manter / refatorar | Cortar ou fundir |
|---|---|---|
| Projétil × Direto — Seta | Precisão e pressão com três cargas. Mantém 0,3 s e 1/1,2 s. Fogo aplica burn; Raio mantém velocidade; Vento mantém curva manual limitada | Retirar slow da Seta de Gelo: slow fica na preparação de território. Cortar crescimento de duração de burn por repetição; reaplicação renova até 3 s |
| Projétil × Explosivo — Orbe | Explosão de impacto para uma quina exposta; antecipável pelo voo. Fogo pode usar apenas impacto; Gelo, slow breve de impacto; Raio, descarga de precisão; Vento, atração curta | Fundir chão de Fogo/Gelo com a função da Semente: Orbe deixa de criar uma segunda zona. Cortar chain automático de Raio; usar consumo de Choque no alvo atingido |
| Projétil × Contínuo — Semente | Única entrega parabólica de território persistente: queimar, desacelerar, aplicar Choque ou corrente direcional | Retirar desvio de projéteis de Vento; sua corrente empurra corpos, deixando defesa balística para Muralha. Mesma zona não acumula intensidade com outra do dono |
| Pessoal × Direto — Guarda | Defesa reativa curta, com leitura clara de abertura e término; Gelo continua com maior escudo e custo de mobilidade; Raio conserva Choque ao quebrar | Cortar reflexão automática de Fogo. Conservar deflexão de Vento apenas numa janela inicial curta: depois resta o escudo comum |
| Pessoal × Explosivo — Impulso | Reposicionamento comprometido; Gelo percorre mais, Raio teleporta com destino anunciado, Vento usa altura, Fogo deixa rastro de retirada | Não acrescentar dano ao dash nem ampliar i-frames. Rastro só no percurso efetivamente percorrido; deixa de funcionar como Semente lançada à frente |
| Pessoal × Contínuo — Aura | Postura de seis segundos: Fogo melhora a colocação de sua próxima Semente; Gelo conserva imunidade a slow; Raio conserva velocidade de projétil; Vento conserva mobilidade/pulo duplo | Cortar +20% dano de Fogo, CDR genérico de Raio e segundo pacote de escudo de Gelo. Fundir defesa numérica com Guarda; Aura deve mudar uma ação, não iniciar automaticamente toda luta |
| Área × Direto — Leque | Ferramenta de curta distância: Fogo converte burn, Gelo aplica slow forte breve, Raio mantém arco estreito de maior alcance, Vento desloca | Não fundir com V: os 6–9 m do Leque são uma faixa de decisão diferente dos 1,8 m do cajado. Evitar que ambos sejam só finishers intercambiáveis |
| Área × Explosivo — Marca | Compromisso visível: dano atrasado numa posição prevista; Gelo root curto, Vento lançamento, Fogo impacto/ignição, Raio conversão de Choque | Unificar o telegraph básico inicialmente em 0,9 s; cortar vantagem temporal passiva de Raio de 0,6 s. Sua rapidez vem da preparação e troca de ângulo |
| Área × Contínuo — Muralha | Ferramenta linear de corte: Fogo pune travessia, Gelo bloqueia, Raio arma Choque na travessia, Vento corta tiros | Remover colisão corporal da cortina de Fogo para separar negação por dano de bloqueio de Gelo. Não dar dano adicional à barreira de Vento |

Detalhe de Aura de Fogo para o primeiro protótipo: uma Semente durante a postura pode virar uma faixa de 6×2 m por 4 s, orientada pela mira, em vez do disco de 7 m de diâmetro. Mesmo DPS; troca cobertura radial por corte de saída. Gelo inicialmente fica somente com imunidade e mobilidade normal: testar esse recorte antes de inventar outro bônus. A postura expira pelo tempo mesmo sem conversão. Raio só consome Choque em Seta/Leque/impacto de Orbe/Marca; ticks de zona e V não o gastam. Gelo recebe recuperação de controle: depois do root, 1 s sem reaplicação de root/slow forte, ainda vulnerável a dano. Esses são contratos novos, a calibrar, não alterações apenas de tooltip.

**Corte deliberado:** não reduzir a matriz para seis magias nesta rodada. Isso mudaria o pilar de composição sem evidência de que o problema é o número de células. Primeiro remover redundâncias dentro das 36 combinações. Se Aura continuar sendo um botão obrigatório ou irrelevante após o recorte, testar numa versão separada sua fusão com Guarda, explicitamente revendo a gramática; não preencher a célula vazia com outro buff genérico.

**Efeito esperado.** Fogo vence uma saída, Gelo prevê uma rota, Raio converte uma janela e Vento muda a geometria do confronto. O adversário pode explicar como perdeu e o que faria diferente.

**Esforço: L · CRITICAL.** Inclui consumo de status, imunidade temporária a controle, posturas e colisão de barreiras. Implementar um elemento por vez, mantendo os demais como controles. Critério: em review de clipes, reconhecer pelo comportamento o plano elemental e sua resposta possível; não exigir uso artificialmente igual das nove células.

### O que as cargas resolveram — e o que não resolveram

`scenes/player/player.gd:20` e `:493` já limitam a Seta. Três disparos mais rápidos possíveis ocupam 0,6 s entre primeiro e terceiro e gastam 36 mana; causam 50,4/45,6/48/45,6 de dano direto por elemento, antes de escudo/status. Não é mais correto discutir Seta como recast ilimitado a cada 0,35 s. O valor 0,35 ainda em `data/spells/projectile_direct.tres:15` não determina sua cadência efetiva, pois o jogador consome cargas no lugar da recarga comum (`scenes/player/player.gd:459`).

A pausa de regeneração de 0,5 s (`scenes/player/stats.gd:20`) dá aproximadamente 8,4 mana regenerada entre tiros espaçados de 1,2 s, contra custo 12, em regime ideal sem outras ações. Portanto cargas **não tornam pressão infinita gratuita**. Ainda há incentivo a esperar recargas atrás de cobertura; os mapas precisam permitir trocar ângulo durante essa pausa. Não nerfar a Seta de novo antes de medir ciclos completos com G, Guarda e Núcleo.

## R3 — P0: gerar espaços jogáveis, não apenas espelhar caixas

**Problema.** A infraestrutura garante simetria nominal, mas não expressa rotas, áreas de captura, segurança de saída e campo de visão. As três variantes herdam varandas contínuas de 18 m, independentemente de sua intenção tática.

**Evidência.** `scenes/arena/arena_builder.gd:18` guarda apenas posição, tamanho e rotação; `:82` constrói o mesmo shell e as mesmas varandas; `:138` fixa altura/largura/acessos; `:189` fixa spawns. A/B/C só selecionam esse gerador (`scenes/arena/arena_a.tscn:28`, `arena_b.tscn:28`, `arena_c.tscn:28`). `tests/test_arena_layout.gd:45` testa uma única reta entre centros dos spawns em 2D; `:37` testa centros de peças, não toda a extensão rotacionada. Isso não demonstra segurança de todos os pontos do spawn nem qualidade das rotas.

**Proposta.** Manter o espelhamento, mas introduzir uma descrição de arena com sólidos, plataformas, rampas, `SpawnRegion`, saídas, `CoreAnchor`, rotas nomeadas e volumes de bloqueio visual. Separar geometria jogável de decoração. O builder gera colisões simples e marcadores; um validador consulta essas mesmas definições e a física. Não criar um gerador procedural aleatório de mapas.

### Regras curtas a codificar

| Regra | Métrica inicial | Motivo / prova necessária |
|---|---|---|
| Passagens | Mínimo 2,5 m livres; rotas principais 3–4 m; salões C ≈5,25 m. Sem fresta obrigatória de 1 m | Cápsula tem 0,7 m de diâmetro (`data/player_tuning.tres:7`); sobra para strafe e Impulso. Medir vão depois de rotação e decoração |
| Duas rotas | Dois caminhos sem salto obrigatório de cada spawn ao anel; não compartilhar a mesma última porta | Uma Muralha de 6 m pode fechar uma rota; não pode isolar o Núcleo inteiro. Simular barreiras em posições críticas |
| Cobertura baixa | 1,0 m = obstáculo/degrau, não proteção total agachado; 1,3–1,4 m = abrigo de crouch no mesmo piso | Câmera agachada ≈1,068 m, cápsula 1,2 m; caixa atual de 1 m não oculta todo o corpo. `data/player_tuning.tres:8` |
| Cobertura alta | 2,2 m no mesmo piso; 3,5 m para bloquear olhos em varanda +1,5 m | Olhos de pé ≈1,602 m; sobre varanda ≈3,102 m. Testar também cabeça/cápsula, não só câmera |
| Ritmo de exposição | Abrigos a cada 5–8 m de percurso principal; travessia descoberta desejada 3–6 m | A 5,5 m/s, 6 m ≈1,09 s. Não permitir atravessar 15 m de vazio como única opção |
| Linhas de visão | Alvo: até 18 m em A, 22 m em B, 14 m em C entre posições de combate relevantes | Raycasts numa grade de 0,5 m, olhos em pé/crouch/varandas; incluir diagonais. Segmentar linhas maiores com baffles, sem multiplicar portas |
| Spawns | Zero LOS entre regiões internas de spawn; primeiras bifurcações protegidas por anteparo de 3,5 m | Amostrar região 7×7 m, bordas das saídas e altura de pulo. Segurança inicial, não invulnerabilidade permanente contra invasão |
| Pulos e degraus | Salto opcional normal ≤1,0 m; degrau ≤0,3 m; nenhum caminho essencial depende do limite 1,2 m | Reserva sobre `jump_height=1.2` e `step_height=0.35`. Validar com cápsula, não apenas raycast |
| Altura | Plataformas +1,5 m; rampas 3 m largas ×4 m de projeção horizontal; duas saídas | Inclinação ≈20,6°. Sem piso sobre o Núcleo; Vento ganha atalhos, não propriedade exclusiva do objetivo |
| Núcleo/colapso | Disco capturável livre de raio 2 m; área central navegável de pelo menos 10×10 m, com coberturas apenas nas bordas | O Colapso termina em raio 5 m (`scenes/match/collapse_zone.gd:7`); duas conexões terrestres devem sobreviver ao fechamento |

Os tetos de sightline são **gates propostos**. Os desenhos abaixo ainda precisam passar por raycasts e percurso com cápsula; não afirmo que já cumprem os máximos. Cobertura interrompe a visão horizontal, não torna o pulo de espiada impossível. O validador deve relatar a exceção e a duração aproximada da exposição.

**Efeito esperado.** Cada alteração geométrica passa a ter um propósito e uma prova. Regressões de salto, dash e captura deixam de depender de inspeção casual.

**Esforço: M · CRITICAL.** Refactor do gerador e validação física/editor. Depois dele, as mudanças de layout R5–R7 são dados/greybox e ficam SIMPLE. Critério: conectividade e simetria aprovadas com todas as peças, rampas e barreiras temporárias, não somente a tabela de caixas.

## R4 — P1: preparação G e melee V devem ter oportunidade e compromisso

**Problema.** G funciona como atalho de composição sem uma linguagem adversária equivalente; V oferece dano sem compartilhar compromisso com conjuração. Juntos podem aumentar execução oculta e explosão de dano, em vez de leitura do duelo.

**Evidência.** Para uma rápida, G arma armazenamento **entre forma e efeito**, não depois de ela já ter disparado (`scenes/player/spell_composer.gd:165`, `:216`). Para confirmada, G armazena durante AIMING; G em IDLE recupera e `_begin` abre mira novamente (`:176`). Reserva subtrai mana disponível (`scenes/player/player.gd:679`; `scenes/player/stats.gd:157`). Círculo some em IDLE e não lê `stored` (`scenes/player/rune_circle.gd:26`). `can_melee` verifica apenas morte, congelamento e CD (`scenes/player/player.gd:636`); animação dura 0,28 s (`scenes/player/first_person_arms.gd:7`), mas o dano é imediato.

**Proposta.** G em IDLE vazio arma “preparar próxima magia”; então Q/E/R compõe normalmente e o resultado é armazenado. G em AIMING continua armazenando. Um slot, mesma reserva, mesmo custo e mesmas recargas ao disparar; G nunca oferece uma Seta adicional nem ignora o intervalo de 0,3 s. Ao recuperar confirmada, continuar exigindo posicionamento e LMB. Cancelar devolve a reserva, sem bônus. Tornar o armazenamento uma pequena inscrição persistente no cajado remoto, visível apenas quando há LOS: revelar a forma, manter o efeito incerto. Isso permite blefe sem ataque inteiramente opaco.

Para V, manter 12 dano/0,8 s/sem mana/1,8 m, mas definir um golpe com antecipação curta de 0,12 s e recuperação inicial de 0,25 s, ajustável por playtest. Não iniciar conjuração nem outro golpe durante a recuperação; Guarda e Impulso continuam disponíveis fora dela. O dano acontece no instante visual do contato e respeita R1. Sem stun, sem árvore de combos e sem bônus elemental próprio. Melee é a decisão de encurtar demais a distância quando falta recurso, não dano gratuito anexado à Seta.

**Efeito esperado.** G torna o jogador preparado identificável e permite uma resposta; V cria uma vulnerabilidade quando erra. Leque continua valendo seu custo por alcance e função elemental.

**Esforço: M · CRITICAL.** Estados de preparar/armazenar/recuperar, reserva e janela de golpe precisam existir no host e sobreviver à reconciliação. Critério: guardar/cancelar durante latência nunca duplica recursos; V não acerta durante o windup e não intercala cast na recuperação; oponente identifica uma preparação em clipes sem ler o HUD alheio.

## Geometria comum às três propostas

Plantas ASCII são esquemas topológicos, não desenhos em escala por caractere. As cotas e tabelas são a definição dimensional do protótipo. Coordenadas `(x,z)` em metros; norte é Z negativo; solo Y=0. Tamanhos nas tabelas são **X×Z×altura**. Todas as peças têm yaw 0° salvo indicação. “+R” manda criar a rotação de 180°: `(x,z) → (-x,-z)`; não duplicar peças centrais. Peças listadas como “todas” não recebem espelhamento adicional.

Envelope preservado: arena principal `x=-14…14`, `z=-19…19` (**28×38 m**), salas de spawn 7×7 m até `z=±26`, centros `(0,±22,5)`. Teto a 8 m. Paredes externas seguem o shell atual. Todos os layouts substituem as coberturas e varandas atuais integralmente, sem somar as novas peças às antigas.

Anteparo comum: bloco `(0,-16)` de `6×2×3,5` +R. A sala abre para um pequeno vestíbulo, e a rota se divide ao redor desse bloco; manter pelo menos 3 m entre sua face norte e o limite interno Z=-19. O bloco protege a saída axial; laterais e saltos ainda precisam do gate de spawn de R3. Não prometer proteção só com esse anteparo.

## R5 — P1: Arena A, Claustro — circuito de leitura e reentrada

**Problema.** O pilar central cria órbita em torno do objetivo, enquanto pequenos pares rotacionados funcionam mais como objetos isolados do que como uma sequência clara de posições. As varandas longitudinais repetem uma solução de altura pouco específica para a arena de aprendizado.

**Evidência.** Pilar 3×3×3 em `scenes/arena/arena_builder.gd:23`; caixas baixas em X=±6,5 (`:25`); pares em quadrantes (`:27`) e varandas comuns (`:138`). O Núcleo acima do pilar com captura plana reforça uma disputa ao redor de uma obstrução, não sobre a plataforma prometida.

**Diagnóstico atual.** Seta/Raio aproveitam os espaços entre objetos; Fogo/Gelo podem preparar os lados do pilar; Vento acessa ângulos das varandas, mas o centro vertical não lhe dá uma função de captura consistente. O bloqueio spawn-spawn axial existe; os tiros diagonais das saídas não estão cobertos pelo teste. Essas são possibilidades geométricas, não frequências medidas.

**Proposta: “anel quebrado”.** Núcleo no solo, quatro aproximações legíveis e dois terraços curtos para mirar, sem passarela lateral contínua.

```text
                          N: spawn 7 x 7
                          +--- SN ---+
                 -14      |         |      +14
                  +-------+         +-------+  z=-19
                  |           H0            |
                  |    H1          l1       |
                  | r                       |
                  | TT       H2             |
                  | TT          K       TT  |  z=0
                  |             H2'     TT  |
                  |                       r |
                  |    l1'         H1'      |
                  |           H0'           |
                  +-------+         +-------+  z=+19
                          |         |
                          +--- SS ---+
                       principal: 28 x 38 m
```

`H` sólido alto; `l` abrigo baixo; `TT` terraço +1,5 m; `r` rampa; `K` Núcleo no solo. Primos são as peças espelhadas.

| Peça | Centro / região | Dimensões / regra |
|---|---|---|
| H0 | `(0,-16)` +R | Anteparo comum 6×2×3,5 |
| H1 | `(-6,-10)` +R | 4×2×2,2; abrigo intermediário |
| l1 | `(6,-10)` +R | 4×1,5×1,4; alternativa com maior exposição |
| H2 | `(-4,-3)` +R | 2×4×3,5; antecâmara lateral, fora do disco de captura |
| TT | `(-12,-2)` +R | Plataforma 4×6, topo +1,5; X=-14…-10 |
| Rampas TT | `(-12,-7)` e `(-12,3)` +R | Cada uma 3×4, solo até +1,5; entradas nos extremos Z=-5/+1 do terraço |
| K | `(0,0)` | Captura no piso; reservar disco R=2 livre |

**Rotas/altura/ritmo.** Do norte, esquerda via H1 alcança a face oeste de H2 e o anel; direita via l1 alcança o lado leste do Núcleo. O vestíbulo permite trocar de decisão antes da exposição. H2 impede ver todas as aproximações do centro de uma vez; não fecha a praça. Terraços criam flanco de tiro e lançamento, com duas rampas e saída por queda, sem dominar o círculo completo. Rotas diretas esperadas na ordem de 25–30 m de percurso spawn–K, a medir no greybox; a diferença norte/sul deve ser ≤0,2 s com o mesmo movimento.

**Elementos no novo A.** Fogo pressiona uma face de H2 e converte no avanço; Gelo controla a conexão curta, mas o rival pode trocar de lado; Raio dispõe de trocas de 10–18 m e precisa se expor para finalizar; Vento troca de terraço/solo e tira o rival do anel, sem acesso exclusivo. A é o mapa para aprender a distinção entre Seta, Orbe de quina e Semente por cima de cobertura.

**Efeito esperado.** Menos perseguição circular em torno do pilar; mais sequência abrigo → informação → travessia → novo ângulo. O centro vira um lugar legível de disputa.

**Esforço: M · SIMPLE após R3/R1.** Risco de projeto: H2 pode produzir uma defesa excessiva do anel. Gate: de cada metade deve haver ao menos um ângulo que ataque uma parte capturável do círculo, sem enxergar as duas saídas inimigas simultaneamente.

## R6 — P1: Arena B, Pátio Partido — altura que cobra posicionamento

**Problema.** Barras baixas e grupos diagonais sugerem deslocamento, mas toda a elevação relevante continua nas mesmas bordas de A/C. “Diagonais longas” não basta como identidade quando Raio tem projétil de 70 m/s e Marca chega a 25 m.

**Evidência.** Barra frontal de altura 1,4 m e L diagonal em `scenes/arena/arena_builder.gd:39`; caixa central de 2,2 m em `:37`; alcance de Marca em `data/spells/area_burst.tres:16`; velocidade de Raio em `data/elements/storm.tres:19`. A barra frontal não cobre os olhos em pé de ≈1,60 m. A caixa central interrompe a reta entre spawns, não todas as diagonais das varandas.

**Diagnóstico atual.** Raio tende a obter valor dos espaços longos; Marca/Semente podem mirar a partir de varandas comuns. Gelo usa a barra para agachar, mas ela oferece pouca proteção contra altura. Fogo deixa dano residual nas transições; Vento muda de piso, porém encontra uma faixa longa em vez de pontos de pouso com compromissos distintos.

**Proposta: “dois terraços, praça baixa”.** Duas plataformas diagonais descontínuas, sem ponte sobre o objetivo, e massa central lateral que segmenta o tiro alto–alto.

```text
                          +--- SN ---+
                  +-------+         +-------+  -19
                  |           H0            |
                  |     l          r        |
                  |                TTTT     |
                  |       H1       TTTT     |
                  |                r        |
                  |  H2       K       H2'   |    0
                  |        r                |
                  |     TTTT       H1'      |
                  |     TTTT                |
                  |        r          l'    |
                  |           H0'           |
                  +-------+         +-------+  +19
                          +--- SS ---+
                       principal: 28 x 38 m
```

| Peça | Centro / região | Dimensões / regra |
|---|---|---|
| H0 | `(0,-16)` +R | 6×2×3,5 |
| TT | `(8,-7)` +R | 6×6; topo +1,5, X=5…11, Z=-10…-4 |
| Rampas | `(8,-12)` e `(8,-2)` +R | 3×4; ambos os extremos da plataforma acessíveis do solo |
| H1 | `(-2,-7)` +R | 2×4×3,5; corta diagonal alta, permite contorno |
| H2 | `x=-12,5; z=0` +R | 3×3×3,5; X=-14…-11 e11…14; interrompe corredor externo no meio |
| l | `(-6,-12)` +R | 3×1,5×1,4 |
| K | `(0,0)` | Solo, praça central livre de 10×10 m; rampas ficam fora dela |

**Rotas/altura/ritmo.** Norte pode usar a rampa traseira e atravessar o terraço até a rampa frontal, ou seguir pelo solo via l/H1. A rota alta paga subida e exposição; a baixa troca visão por proximidade. A plataforma não vê o percurso inteiro do rival porque H1/H2 têm 3,5 m. Não há ligação aérea segura entre terraços. O contorno externo entre X=11 e14 tem 3 m e perde continuidade no H2: exige retornar ao interior, criando uma nova decisão. O anel central permanece baixo e vulnerável a ângulos diferentes, mas cada ângulo deve expor seu atacante a uma rota terrestre.

**Elementos no novo B.** Fogo força uma descida sem cobrir as duas rampas com uma Semente; Gelo escolhe uma rampa para atrasar e precisa ler a outra; Raio disputa as diagonais segmentadas, sem tiro de uma varanda por toda a arena; Vento ganha atalho de subida/queda e tiro em movimento, com destino visível e possibilidade de punição. Marca/Semente encontram superfícies úteis; V/melee não vira modo de atingir alguém um piso acima graças a R1.

**Efeito esperado.** Altura oferece informação e lançamento, enquanto o solo oferece acesso mais direto ao objetivo. O mapa recompensa reposicionamento em vez de permanência numa varanda.

**Esforço: M · SIMPLE após R3/R1.** Gate: nenhuma plataforma controla simultaneamente ambas as rampas inimigas e todo o círculo; rotas de solo conseguem contestar ocupante sem gastar obrigatoriamente Impulso. Ajustar baffles se a amostragem exceder 22 m de sightline relevante.

## R7 — P1: Arena C, Espinha — combater por portas alternativas, não por frestas

**Problema.** Duas frestas de 1 m reduzem strafe e tornam controle de passagem binário. O mapa anuncia combate fechado, mas deixa grande parte da largura externa aberta e conserva as mesmas varandas. O centro sólido conflita com a ideia de um Núcleo numa fresta.

**Evidência.** Espinha: sólido Z=-2…2 e segmentos Z=-6…-3 / 3…6 (`scenes/arena/arena_builder.gd:49`). As frestas ficam entre esses segmentos, não em `(0,0)`. Cápsula de 0,7 m deixa apenas 0,3 m de folga total numa abertura de 1 m (`data/player_tuning.tres:7`). Leque tem 6 m, Semente diâmetro 7 m e Muralha largura 6 m (`data/spells/area_direct.tres:16`, `projectile_lingering.tres:16`, `area_lingering.tres:16`).

**Diagnóstico atual.** Gelo/Fogo podem negar frestas; Vento empurra contra sólidos sem sempre criar alternativa espacial; Raio mantém linhas longas pelos flancos e seu teleporte para na colisão (`scenes/player/player.gd:387`), portanto não é uma travessia livre da espinha. Mobilidade não deve ser vendida como solução para uma parede que ela não atravessa.

**Proposta: “espinha interrompida”.** Dois salões longitudinais, crossover central de 6 m e retorno pelas extremidades. Remover varandas contínuas; altura fica em nichos baixos de espiada, todos opcionais.

```text
                          +--- SN ---+
                  +-------+         +-------+  -19
                  |           H0            |
                  |      retorno norte      |  -11
                  | MMMMM   |S|   MMMMM     |
                  | MMMMM   |S|   MMMMM     |   -6
                  | MMMMM   |S|   MMMMM     |
                  |                         |
                  |    l       K       l'   |    0
                  |                         |
                  | MMMMM   |S|   MMMMM     |
                  | MMMMM   |S|   MMMMM     |   +6
                  | MMMMM   |S|   MMMMM     |
                  |       retorno sul       |  +11
                  |           H0'           |
                  +-------+         +-------+  +19
                          +--- SS ---+
                       principal: 28 x 38 m
```

`M` massa arquitetônica sólida, não corredor; `S` espinha. Os espaços entre M e S são os salões jogáveis.

| Peça | Centro / região | Dimensões / regra |
|---|---|---|
| H0 | `(0,-16)` +R | 6×2×3,5 |
| S | `(0,-6)` +R | 1,5×6×3,5; deixa crossover Z=-3…3 |
| M | `(-10,-6)` e `(10,-6)` +R | 8×6×3,5; massas X=-14…-6 e6…14, Z=-9…-3 e3…9 |
| l | `(-7,0)` +R | 2×2×1,4; abrigo na lateral do crossover |
| Degrau opcional | `(-9,0)` +R | 2×2×1,0; não conecta ao topo de M; serve de espiada |
| K | `(0,0)` | Solo; centro livre entre espinhas, anel R=2 |

**Rotas/altura/ritmo.** Os salões têm 5,25 m livres entre X=±0,75 e±6. O norte bifurca depois do anteparo, pode entrar pelo salão esquerdo ou direito e trocar no crossover central de 6 m; também pode recuar ao retorno norte. O sul recebe a mesma topologia. Uma Muralha fecha um salão, mas o outro continua sendo acesso distinto ao Núcleo. As massas impedem o tiro pelas antigas bordas e tornam o espaço central reconhecível. O corredor é largo o bastante para strafe, porém uma Semente exige contornar/recuar: por isso a bifurcação deve acontecer antes da entrada e permanecer legível.

No primeiro greybox, medir as retas dos salões: se ultrapassarem 14 m entre posições de combate, adicionar um par de baffles de `1×2×2,2` em `(-2,-10)` +R, fora da praça, deslocando a entrada sem estreitar o vão abaixo de 2,5 m. Essa é a primeira variável de iteração, não uma alegação de visibilidade já validada. O retorno precisa permanecer funcional depois do ajuste.

**Elementos no novo C.** Fogo ganha pressão territorial, mas precisa escolher qual salão incendiar; Gelo faz o rival mudar de porta, sem prendê-lo numa fresta; Raio converte Choque no crossover e não domina por velocidade balística a arena inteira; Vento muda a ordem das aproximações e desloca do anel. Sua verticalidade permite espiar, não saltar para um telhado invulnerável: os topos de M/S devem ser volumes sem acesso útil ou ter saída e exposição equivalentes testadas. V e Leque encontram distâncias distintas; G abre oportunidades de emboscada com aviso de preparação.

**Efeito esperado.** Combate próximo com opção de recuo e reentrada. Decisões de rota sobrevivem ao controle de área, e o Núcleo não fica dentro de uma parede.

**Esforço: M · SIMPLE após R3/R1.** Risco: salão mais Semente pode produzir espera passiva de quatro segundos. Gate: o retorno à segunda entrada deve custar menos que simplesmente esperar repetidamente a zona expirar, ou deve oferecer informação/ângulo compensatório. Medir ambos com jogadores, sem impor só uma meta de distância.

## R8 — P1: round em três atos, com vantagem que precisa ser convertida

**Problema.** O round tem combate livre, um evento único aos 30 s e depois espera potencialmente longa até o Colapso. O Núcleo dá simultaneamente economia e dano, incentivando gastar suas cargas nas magias caras. O fim da captura não garante que a luta avance.

**Evidência.** 90 s de combate, Núcleo aos 30 s e overtime máximo de 60 s em `scenes/match/match_fsm.gd:14`; recompensa de três conjurações/10 s em `scenes/player/player.gd:578`; custo zero em `:572` e +20% dano em `:513`. Captura mantém progresso ao sair e não tem estado contestado para dois ocupantes (`scenes/match/arcane_core.gd:53`). Colapso chega a R=5 em 20 s, depois para de encolher (`scenes/match/collapse_zone.gd:36`), então ainda pode sobrar tempo até desempate por HP.

**Proposta.** Primeiro preservar os 90 s para comparar o refactor, estruturados assim:

| Tempo decorrido | Ato | Comportamento proposto |
|---|---|---|
| 0–20 s | Sondagem | Pedestal já visível e inativo; rotas permitem informação e preparação G. Sem captura |
| 20–30 s | Anúncio | Núcleo desenha seu anel e anuncia ativação; jogadores têm tempo de reposicionar |
| 30–60 s | Disputa/conversão | Captura disponível uma vez. Dois inimigos dentro pausam progresso de ambos. Dano reseta; sair inicia perda de progresso após 1 s, em vez de preservação eterna |
| 60–90 s | Convergência | Aviso claro de quais rotas ficarão fora do Colapso. Sem segundo Núcleo nem buff acumulável |
| 90–110 s | Colapso | Fechamento conhecido até R=5; desenho central garante duas aproximações |
| 110–125 s | Resolução | Testar fechamento final R=5→2 em 15 s, mantendo DPS; reduzir a permanência em bolsões seguros |

Manter as variantes de overtime como opções do lobby. O cronograma final acima aplica-se ao Colapso padrão; Morte Súbita/Maré mantêm seus modos até um experimento específico, sem fingir que todas as variantes já têm a mesma duração. Reduzir o limite absoluto apenas após testar sobrevivência com Guarda/Impulso; não alterar silenciosamente a regra de empate.

Recompensa proposta para o primeiro experimento: manter 3 conjurações em 10 s com mana grátis e **retirar o +20% de dano**. Sem reset de cooldown ou recarga de Setas. O capturador ganha opções para tomar território; ainda precisa acertar. Durante esse teste, reserva G mantém seu custo-base comprometido, com liberação/desconto resolvido atomicamente no disparo, evitando mudança invisível de reserva ao ativar/expirar Sobrecarga. Avaliar dano separado somente se o objetivo ficar pouco disputado.

**Efeito esperado.** Um round tem preparação, contestação e encerramento compreensíveis; capturar ajuda a executar um plano sem comprimir automaticamente o TTK. Retirar o multiplicador também reduz o empilhamento com Aura/Cold Blood, embora R2 já corte a Aura de dano.

**Esforço: M · CRITICAL.** Estados de contestação/decaimento, reserva durante buffs e cronograma autoritativo. Gate de playtest: medir parcela de rounds com disputa real, tempo da captura ao próximo confronto e conversão captura→vitória; não presumir que uma taxa alta significa objetivo saudável. Se a maioria termina antes de 30 s, testar ativação aos 20 s em experiência separada, em vez de alterar mapa, dano e relógio juntos.

## R9 — P1: dar à MD7 uma memória espacial

**Problema.** A rotação atual muda mapa a cada round, além de elemento, lado, primeira escolha e runa. É muita mudança simultânea para aprender com a derrota. O decisivo introduz novo sorteio justamente no momento de maior pressão.

**Evidência.** Rotação A/B/C em `scenes/match/match_fsm.gd:269`, troca de lado em `:281`, ofertas de três entre sete runas em `:298`. Draft tem 30 s no primeiro round e 20 s nos seguintes (`:307`), com saída antecipada quando ambos confirmam (`:118`). Runas atuais são sobretudo números (`scenes/player/player.gd:563`, `:572`, `:587`; velocidade/precisão em `scenes/spells/projectile.gd:23`).

**Proposta.** Modo de rotação revisado: **A,A,B,B,C,C,A**, anunciado inteiro no lobby. Cada par permite revanchar o mesmo problema espacial com lados e primeira escolha trocados. O decisivo retorna ao mapa de leitura mais simples. Preservar opções de arena fixa e aleatória; a sequência proposta substitui o sorteio do decisivo somente neste modo e requer aprovação dessa mudança de regra.

Manter as janelas de escolha e a confirmação dupla; usar o intervalo para exibir “mesmo mapa, lados trocados” e a principal diferença do último confronto, não criar outra tela obrigatória. Quatro rounds com janelas completas já somam 90 s de draft, além de contagens e finais; por isso não acrescentar banimento, loja ou escolha de deck.

Para runas, manter o benefício do perdedor e a escolha entre três, mas sortear uma oferta de cada categoria: **recurso** (Fôlego/Eco), **deslocamento/execução** (Passo Leve/Foco) e **defesa** (Casca). Retirar Pressa e Sangue Frio do primeiro pool experimental: CDR/dano globais sobrepõem o plano do elemento e a Sobrecarga. Eco mantém recast apenas de confirmadas. No decisivo, ambos recebem as mesmas três ofertas e escolhem em segredo; revelar ao encerrar o draft. Não acumular runas entre rounds.

**Efeito esperado.** A derrota produz uma resposta testável na mesma geometria. O decisivo testa aprendizado; a runa corrige um problema escolhido sem transformar vitória/derrota anterior em uma build permanente.

**Esforço: M · CRITICAL.** Mudança de política de arena, oferta/semente de runas e informação no draft. Gate: comparar partidas pareadas com a rotação atual, registrar se o jogador consegue enunciar e tentar uma adaptação no round seguinte. O mapa repetido também pode favorecer especialização excessiva; se aparecer, experimentar pares em ordem sorteada e anunciada, preservando a revanche.

## R10 — P2: a academia arcana deve ensinar suas regras pela forma

**Problema.** O tema está presente em paleta, cajados e materiais, mas as arenas continuam uma mesma caixa com objetos de combate. Há oportunidade de fazer espaço e magia pertencerem à mesma linguagem sem adicionar ruído visual.

**Evidência.** As três cenas repetem céu/luz (`scenes/arena/arena_a.tscn:5`, `arena_b.tscn:5`, `arena_c.tscn:5`); o builder só troca visual de dimensões exatas (`scenes/arena/arena_builder.gd:168`). O código de magia já distingue anel pontilhado persistente e flash único (`scenes/spells/zone.gd:26`, `explosion_fx.gd:34`), mas o círculo de composição é um quad de 0,3 m (`scenes/player/player.tscn:19`). A direção de “grimório vivo” já está em `docs/specs/07-art-pipeline.md:11`.

**Proposta.** Aplicar as inspirações como regras funcionais:

- **Bleach:** silhuetas incisivas e contraste temporal: preparação legível, corte de energia breve, impacto branco curto. Reservar picos de brilho para contato; evitar esfera opaca grande ocultando a reação do alvo.
- **Witch Hat Atelier:** as fórmulas aparecem como construção: pontilhado prepara, traço completo ativa, quebra do traço encerra. O cajado armazena uma inscrição no G; o Núcleo desenha o espaço disputável. Espessura suficiente para leitura a 15–20 m, sem exigir leitura de símbolos minúsculos.
- **Sea of Thieves:** massas grandes, assimetria visual de desgaste, materiais pintados e valores simples. Colisão continua simples e simétrica; rachaduras e ornamentos ficam dentro do volume visual, sem criar frestas falsas.

A vira claustro de estudo com arcos e mesas de pedra; B, observatório partido com dois terraços de instrumentos; C, arquivo com duas alas e um salão de inscrição. Mudar landmark e perfil arquitetônico, não só a cor da luz. Pedra/solo ficam neutros; cores elementais são reservadas aos feitiços. Coberturas baixas têm topo legível; sólidos altos não parecem saltáveis; rampas são reconhecíveis pelo perfil, sem setas de interface no chão. H1/H2/M são arquitetura, não caixas decoradas depois.

**Efeito esperado.** Jogador identifica arena, altura, rota e categoria de ameaça rapidamente. O estilo passa a sustentar combate e navegação, além da apresentação.

**Esforço: M · SIMPLE.** Modelos, materiais, silhuetas e VFX reaproveitam o pipeline. Dependências de estado do G ficam em R4, não escondidas como trabalho de arte. Gate: capturas em escala de cinza e clipes de curta duração devem permitir identificar altura, cobertura sólida, zona ativa e preparação; testar também com duas magias sobrepostas.

## Ordem de protótipo e critérios de decisão

1. **R1 + R3 e A em greybox.** Validar colisão, anel e dois caminhos. Guardar a arena atual como controle de teste, sem trocar simultaneamente os quatro elementos.
2. **R2 por elemento, depois R4.** Para cada alteração, testar as seis duplas elementais sem espelho obrigatório, alternando jogador e lado. Registrar uso por célula, mana antes da morte, duração de controle e cadeia de dano; não usar apenas precisão por forma.
3. **B e C.** Comparar pelo menos as mesmas seis duplas em cada mapa e os dois lados. Medir primeiro contato, percurso até K, tempo em altura, exposição nas travessias e recuperação após bloqueio de uma rota. Usar jogadores de níveis diferentes; bots de Seta não avaliam contrajogo de território.
4. **R8 e R9 separadamente.** Primeiro round, depois série. Hipótese inicial: confrontos relevantes antes de 10 s sem dano inevitável de spawn; disputa do Núcleo com oportunidade de reentrada; menos rounds decididos por espera até o limite absoluto. Não converter esses alvos em números de balanceamento sem observar partidas.
5. **R10 após estabilizar colisão.** Produzir arte a partir da geometria aprovada, mantendo silhueta/colisão e a leitura das saídas. Não investir no kit completo de três arenas antes de provar a circulação.

Critérios de interrupção: se uma única zona/barreira anula as duas rotas, revisar geometria antes de reduzir sua duração; se um elemento só funciona por dano bruto, revisar a interação principal antes de subir o multiplicador; se o novo mapa exige tutoria verbal para explicar onde captura, revisar o espaço antes de acrescentar tooltip. A meta é um duelo em que composição, movimento e arquitetura formem a mesma decisão.

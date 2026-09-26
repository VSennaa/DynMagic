# Rodada 2 — decisões (2026-09-26)

Fontes: `r2-codex-design.md` (R1–R10), `r2-deepseek-art.md` (A01–A10).

## Do usuário
- **Aprovadas todas** as propostas que revisam decisões: R2 (quatro planos elementais, nove funções), R4 (G preparação / V compromisso), R8 (round em três atos, Núcleo exige conversão), R9 (MD7 com revanche espacial e runas de adaptação).
- **Referência do gauntlet: B** — level design contra os mapas de Skirmish do Valorant; visual contra Sea of Thieves.
- **Modos novos:** arenas pequenas estilo Skirmish mantidas para 1v1 e **2v2**; **3v3** em arena expandida; **5v5** captura de ponto estilo Overwatch/Paladins.
- Demais decisões: o agente decide, usando o classificador **Jev** (`typesafe/jev-router` via OpenRouter, `tools/ai/openrouter.py`).

## Decididas pelo Jev (2026-09-26)
1. Draft em times: 2v2/3v3 sem elemento repetido **no time** (inimigos podem repetir); 5v5 no máximo 2 do mesmo elemento por time.
2. Elemento: um por round, como no 1v1.
3. 2v2/3v3: rounds de eliminação sem respawn, melhor de 7.
4. 5v5: Controle estilo Overwatch — um ponto, captura até 100%, melhor de 3 rounds.
5. 5v5 respawn em ondas a cada 10 s.
6. Runa do perdedor + Núcleo mantidos em 2v2/3v3; no 5v5 sai a runa e o Núcleo vira o ponto.
7. Fogo amigo desligado.
8. Modos em time só em LAN/listen server por enquanto; a VPS continua com 1v1/2v2.
9. Ordem: 2v2 → 3v3 → 5v5.
10. Arena 3v3: arenas pequenas ×1,5 com rotas de flanco extras.

## Divisão de trabalho
- **Codex** (crítico): R1, R2, R3, R4, R8, R9 e os modos em time (rede, FSM, draft em time).
- **DeepSeek** (mecânico): R5–R7 depois de R3, A03/A06/A07 (ligar arte sem uso, docs), dados.
- **Gemini Pro via OpenRouter**: crítico visual cego do gauntlet (enxerga imagem).
- **Jev**: desempate de decisões pequenas.
- **Claude**: líder do gauntlet, screenshots, juiz final, commits. Para em 85% da cota de 5 h.

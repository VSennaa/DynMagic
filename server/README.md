# DynMagic — servidor dedicado (Linux x86_64)

Servidor headless: hospeda uma sala sem jogador local. Dois jogadores entram por IP (ou pela lista de salas na LAN), clicam em **Pronto** e a partida começa sozinha. Depois dos resultados, todos voltam ao lobby e o servidor continua disponível.

## Rodar

```bash
chmod +x DynMagic-server.x86_64
./DynMagic-server.x86_64 --headless -- --server --name "Arena do Vini" --port 7777
```

Opções depois de `--`:

| Opção | Padrão | Uso |
|---|---|---|
| `--server` | — | Obrigatório: modo servidor dedicado |
| `--name "Sala"` | `Sala de Mago` | Nome mostrado na lista de salas |
| `--port N` | `7777` | Porta UDP do jogo |
| `--overtime X` | `collapse` | `collapse` \| `sudden_death` \| `mana_surge` \| `random` |
| `--arena X` | `rotation` | `rotation` \| `random` \| `A` \| `B` \| `C` |
| `--sim-latency ms` / `--sim-loss 0.02` | 0 | Simulador de rede (testes) |

## Rede e firewall

- Jogo: **UDP 7777** (ou a porta de `--port`). Descoberta na LAN: **UDP 7778** (broadcast; não passa pela internet).
- VPS: libere a porta UDP no firewall da VPS e no painel do provedor. Exemplo com ufw:

```bash
sudo ufw allow 7777/udp
```

- Os jogadores entram por **Jogar LAN → Entrar por IP** com o IP público da VPS.

## Rodar como serviço (systemd)

1. Copie o binário para `/opt/dynmagic/` e crie um usuário sem login: `sudo useradd -r -s /usr/sbin/nologin dynmagic`.
2. Copie `dynmagic.service` para `/etc/systemd/system/`, ajuste `--name`/`--port` e ative:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now dynmagic
journalctl -u dynmagic -f   # logs: [server], [lobby], [match], [net]
```

## Três salas na VPS (D13)

A VPS de 2 GB roda **três instâncias independentes** do servidor, cada uma com seu processo, porta e diretório de dados. O template `dynmagic@.service` usa `MemoryMax=450M` e `CPUQuota=70%` por sala, de modo que três salas caibam com folga para o SO e os outros serviços.

1. Copie o template e o exemplo de ambiente:
   ```bash
   sudo cp server/dynmagic@.service /etc/systemd/system/
   sudo mkdir -p /etc/dynmagic
   sudo cp server/dynmagic@.env.example /etc/dynmagic/room1.env
   sudo cp /etc/dynmagic/room1.env /etc/dynmagic/room2.env   # ajuste a porta/nome
   sudo cp /etc/dynmagic/room1.env /etc/dynmagic/room3.env
   ```
2. Portas de jogo **UDP 7777 / 7779 / 7780** (a descoberta LAN continua em 7778 e é uma só por máquina):
   | Instância | Porta | `--name` |
   |---|---|---|
   | `dynmagic@room1` | 7777 | Arena 1 |
   | `dynmagic@room2` | 7779 | Arena 2 |
   | `dynmagic@room3` | 7780 | Arena 3 |
3. Ative as três:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now dynmagic@room1 dynmagic@room2 dynmagic@room3
   systemctl status 'dynmagic@*'
   systemctl show -p MemoryCurrent dynmagic@room1   # RSS por sala
   ```
4. UFW: libere as três portas UDP (`sudo ufw allow 7777:7780/udp`) ou somente as usadas.

**Ainda pendente (sem acesso à VPS nesta rodada):** o teste de carga de 1 h com 3 partidas simultâneas e a escrita do `status.json` (`/var/www/dynmagic/status.json`) para o site. Medir RSS agregado, CPU, tick p99 < 16,67 ms e crescimento de memória antes de considerar a capacidade provada. Enquanto isso, o gate documentado é: grupo DynMagic ≤ 600 MB e ≤ 70% de um núcleo, sem swap.

## Requisitos

Linux x86_64 com glibc recente (Ubuntu 22.04+ / Debian 12+). Sem GPU: o binário exportado é o modo servidor dedicado do Godot (recursos visuais removidos).

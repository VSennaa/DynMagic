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

## Requisitos

Linux x86_64 com glibc recente (Ubuntu 22.04+ / Debian 12+). Sem GPU: o binário exportado é o modo servidor dedicado do Godot (recursos visuais removidos).

# iHF02T-6 — VLESS + Tor privacy gateway

Статус: активная архитектура — `iHF02T-6` как persistent MicroVM на
`Cr01MS-32`. Исторические физические iMac-проверки ниже считаются подтверждением
backend/protocol, но не описанием текущего interface/runtime layout.

## Текущая topology

Registry (`modules/registry/network.nix`) задаёт:

- iHF LAN: `192.168.3.254/24`, guest interface `eth0`;
- gateway: `192.168.3.1`;
- Cr01<->iHF host-only telemetry link: `10.254.0.1/30 <-> 10.254.0.2/30`,
  guest interface `eth1`.

Service listener ports Xray/Tor/Squid/Prometheus берутся из
`modules/registry/ports.nix`; их не следует дублировать числовыми литералами в
host modules.

## Privacy backend

Актуальный backend — Xray/VLESS (`REALITY + XHTTP`). Persistent secret source:

```text
/var/lib/fbl-secrets/vless.uri
```

Файл root-only и не должен попадать в Nix source/Git/Drive. Runtime config
создаётся в `/run/secrets/xray.json`.

При `fbl.vpnGateway.transit.enable = false` management plane и LAN routing не
перехватываются. Xray/Tor дают локальные test endpoints. Transparent
VPN/VPN+Tor transit включается только отдельным флагом и только после выбора
конкретного тестового client IP.

## Целевая цепочка

```text
VPN:
client -> MikroTik -> iHF02T-6 -> Xray/VLESS -> Internet

VPN + Tor:
client -> MikroTik -> iHF02T-6 -> Tor -> Xray/VLESS -> Internet
```

Tor — TCP-oriented. VPN+Tor policy должен блокировать public UDP, который Tor
не умеет транспортировать произвольно; DNS обрабатывается отдельно.

## Fail-closed принцип

- нет direct/freedom fallback в Xray path;
- Tor использует Xray SOCKS как underlay;
- transit rules не должны давать managed client прямой public fallback;
- IPv6 policy на MikroTik обязана исключить обход iHF для managed clients.

## Исторически подтверждено до миграции в MicroVM

На физическом iHF ранее был проверен Xray `26.3.27`, config test и реальный
SOCKS egress для `VLESS + REALITY + XHTTP`. Это не означает, что текущий
MicroVM runtime автоматически проверен после каждого rebuild.

## Safe validation текущей MicroVM

Standalone evaluation/build:

```bash
cd ~/FBl-2core
nix build --no-link \
  .#nixosConfigurations.iHF02T-6-VM.config.system.build.toplevel
```

Production definition принадлежит Cr01:

```bash
sudo nixos-rebuild build --flake .#Cr01MS-32
sudo nixos-rebuild dry-activate --flake .#Cr01MS-32
```

После guest restart:

```bash
systemctl status fbl-xray tor --no-pager
ss -lntup
sysctl net.ipv4.ip_forward
```

До включения transit `ip_forward`/transparent listeners должны соответствовать
выключенному режиму. После включения одного test client дополнительно проверить
nftables, policy routing, external IP, DNS и IPv6 leak.

## Rollback

Без смены generation:

```bash
sudo systemctl stop fbl-privacy-router 2>/dev/null || true
sudo systemctl stop tor
sudo systemctl stop fbl-xray
```

Полный rollback production-конфигурации делается откатом Cr01 generation.

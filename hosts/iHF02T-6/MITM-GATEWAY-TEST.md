# iHF02T-6 — transparent gateway / MITM test layer

Это opt-in лабораторный слой. Он не активируется, пока
`fbl.ihfGatewayTest.enable = false`.

## Текущая topology

`iHF02T-6` сейчас MicroVM:

- LAN address/interface берутся из `modules/registry/network.nix`
  (`192.168.3.254/24`, `eth0` в текущем registry);
- FBL client CIDR также берётся из network registry;
- explicit Squid и transparent listener ports берутся из
  `modules/registry/ports.nix`.

Старые указания на physical `enp0s10`/`192.168.2.21` больше не относятся к
активной конфигурации.

## Stage 1 — HTTP routing/cache

При включении test layer:

- IPv4 forwarding включается только в рамках test policy;
- HTTP test traffic перенаправляется на transparent Squid HTTP listener;
- explicit Squid остаётся отдельным listener;
- правила живут в собственной nftables table;
- rollout начинать с одного test client, не со всей FBL LAN.

## Stage 2 — HTTPS MITM

`httpsMitm = false` остаётся безопасным default. При явном включении создаётся
локальная CA, HTTPS traffic на `fbl.ports.tcp.https` перенаправляется на HTTPS
intercept listener, а QUIC на `fbl.ports.udp.quic` блокируется для тестового
traffic, чтобы браузер использовал TCP/TLS.

CA устанавливать только на lab-owned test clients. Private CA key не копировать
с iHF. Certificate pinning может ломать отдельные приложения — такие targets
надо splice/exclude, а не обходить pinning.

## Safe activation

1. Проверить standalone build `iHF02T-6-VM`.
2. Проверить текущие registry address/interface/ports.
3. Выбрать один test client IP.
4. Включить `enable = true`, оставить `httpsMitm = false`.
5. Проверить nftables, HTTP cache, DNS и обычный HTTPS forwarding.
6. Только затем, если это требуется для лабораторной задачи, включать MITM.

Useful checks:

```bash
systemctl status squid ihf02-gateway-test --no-pager
sudo nft list table inet ihf_gateway_test
sudo journalctl -u squid -u ihf02-gateway-test -f
```

Immediate stop:

```bash
sudo systemctl stop ihf02-gateway-test
```

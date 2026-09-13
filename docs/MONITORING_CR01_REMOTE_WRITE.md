# Cr01 -> iHF02 monitoring via remote_write

Дата исходной схемы: 2026-08-30. Актуализировано под registry architecture
2026-09-05.

## Схема

```text
Cr01 exporters (loopback)
  -> Prometheus Agent on Cr01
  -> private host-only link
  -> Prometheus receiver on iHF02
  -> Grafana on iHF02
```

Адреса host-only link и service ports не дублируются в этом модуле как source
of truth: они находятся в `modules/registry/network.nix` и
`modules/registry/ports.nix`.

Текущие registry values:

- Cr01 side: `10.254.0.1/30`;
- iHF guest side: `10.254.0.2/30`, `eth1`;
- Prometheus receiver: TCP/5002;
- iHF LAN: `192.168.3.254/24`, `eth0`.

## Причина private link

Основной LAN NIC iHF — macvtap. Он даёт guest presence в FBL LAN, но не является
надёжным прямым host<->guest каналом. Поэтому Cr01 remote_write не зависит от
macvtap path.

## Service ownership

- `hosts/Cr01MS-32/ihf02-vm-host.nix` — host-side TAP address;
- `hosts/iHF02T-6/vm.nix` — guest host-only interface + firewall;
- `modules/services/cr-monitoring-exporters.nix` — Cr exporters + agent;
- `modules/services/prometheus.nix` — receiver and central scrape config;
- `modules/services/grafana.nix` — dashboards/datasource.

## Runtime verification

```bash
# Cr01
ip addr show vm-ihf02-host
ping -c 3 10.254.0.2
systemctl status prometheus microvm@iHF02T-6 --no-pager

# iHF02
systemctl status prometheus grafana --no-pager
ss -lntup
```

После архитектурного audit 2026-09-05 конфигурация Drive обновляется, но
фактический receiver/metric flow должен быть проверен после следующего rollout.

---

GPT-5.6 Sol изменил в 18:15 05.09.2026 (МСК).

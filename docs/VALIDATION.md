# FBl-2core — безопасная проверка и применение

Проверка относится к активным outputs текущего `flake.nix`. Inputs закреплены в
`flake.lock`; `--upgrade` при обычном rollout не использовать.

## 1. Точка возврата

На хосте, который будет переключаться:

```bash
readlink -f /run/current-system
sudo nix-env --profile /nix/var/nix/profiles/system --list-generations
```

До успешной проверки новой генерации не запускать aggressive GC.

## 2. Evaluation всего flake

```bash
cd ~/FBl-2core
nix flake check --no-build --show-trace
```

После архитектурного изменения registry/import graph это обязательный первый
барьер. Если evaluation падает — `switch` не выполнять.

## 3. Сборка всех активных outputs

```bash
nix build --no-link --print-build-logs \
  .#nixosConfigurations.Cr01MS-32.config.system.build.toplevel

nix build --no-link --print-build-logs \
  .#nixosConfigurations.iHF02T-6-VM.config.system.build.toplevel

nix build --no-link --print-build-logs \
  .#nixosConfigurations.iVN01T-2-VM.config.system.build.toplevel

nix build --no-link --print-build-logs \
  .#nixosConfigurations.iAF01T-8-VM.config.system.build.toplevel

nix build --no-link --print-build-logs \
  .#nixosConfigurations.GF01WS-16.config.system.build.toplevel
```

`iHF02T-6-VM`, `iVN01T-2-VM`, `iAF01T-8-VM` — standalone validation outputs.
Production autostart этих MicroVM принадлежит `Cr01MS-32`.

## 4. Cr01 dry-activate и rollout

```bash
sudo nixos-rebuild build --flake .#Cr01MS-32 --show-trace
sudo nixos-rebuild dry-activate --flake .#Cr01MS-32 --show-trace
```

Перед `switch` проверить:

- SSH key login из второго терминала;
- наличие `FBL_CLOUD01` и `FBL_CLOUD02`;
- отсутствие неожиданных removals/port changes в dry-activate.

Только после этого:

```bash
sudo nixos-rebuild switch --flake .#Cr01MS-32 --show-trace
```

Сразу после:

```bash
systemctl --failed
systemctl status sshd gitea nextcloud-setup jellyfin qbittorrent podman-metube searx --no-pager
sudo ss -lntup
findmnt /srv/fbl-cloud /srv/fbl-cloud-02
```

Проверить WebUI согласно `modules/registry/ports.nix`.

Для Gitea дополнительно проверить:

- HTTP listener находится на LAN-адресе Cr01 и registry key `fbl.ports.tcp.gitea`;
- отдельного built-in SSH listener Gitea нет, SSH clone использует системный `sshd`;
- self-registration закрыта; первый admin создаётся локально только после успешной runtime-проверки;
- `/var/lib/gitea` присутствует на persistent root filesystem и попадает в следующий успешный Cr01 mirror.

## 5. MicroVM runtime

После обновления Cr01/restart соответствующих guests:

```bash
# iHF02
systemctl status prometheus grafana squid --no-pager
ss -lntup

# iVN01
systemctl status wg-quick-wg0 --no-pager
ss -lnup

# iAF01
systemctl status sshd --no-pager
ss -lntp
```

Для iHF ожидается Prometheus receiver на registry port через LAN + private
host-link, а локальные node/squid exporters не должны быть открыты в LAN.

## 6. GF01

```bash
sudo nixos-rebuild build --flake .#GF01WS-16 --show-trace
sudo nixos-rebuild dry-activate --flake .#GF01WS-16 --show-trace
```

В этом выпуске удалены старые inbound firewall ports без активного service
owner. Если dry-activate показывает неожиданное влияние на реально используемый
локальный сервис — остановить rollout и сначала назначить этому порту владельца
в конфигурации/registry.

После проверки:

```bash
sudo nixos-rebuild switch --flake .#GF01WS-16 --show-trace
systemctl --failed
sudo ss -lntup
```

## 7. Rollback

При проблеме не менять flake/secret files вслепую. Использовать предыдущую
NixOS generation или:

```bash
sudo nixos-rebuild switch --rollback
```

Для MicroVM production owner сначала откатывается Cr01 generation; mutable data
на persistent `/var` не удалять.

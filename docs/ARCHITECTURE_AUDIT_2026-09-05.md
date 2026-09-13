# FBl-2core — architecture audit 2026-09-05

Scope: активный `flake.nix`, host/service modules, registry, deployment docs и
явные legacy remnants внутри `FBl-2core`.

## Результат

Главный дефект был системным: `ports.nix` существовал как registry, но часть
новых и старых модулей продолжала хранить service ports, FBL addresses,
interfaces и storage paths локально. Это создавало несколько источников истины
и позволяло firewall/bind/runtime расходиться.

В выпуске 0.8.0 принят единый принцип SSOT:

- service/listener ports -> `modules/registry/ports.nix`;
- host/network/interface topology -> `modules/registry/network.nix`;
- canonical storage identifiers -> `modules/registry/storage.nix`;
- shared Nix cache -> `modules/registry/cache.nix`;
- FBL-wide SSH authentication policy -> `modules/services/ssh.nix`.

## Исправлено

### Ports/bind/firewall

- qBittorrent web + peer TCP/UDP, MeTube, SearXNG, Jellyfin exposure,
  Squid/Privoxy, monitoring, WireGuard и privacy listeners используют registry.
- MeTube получил отсутствовавшее interface-specific firewall rule.
- Ollama остаётся loopback-only и больше не требует LAN firewall opening.
- Nix cache/Open WebUI/Grafana bind ограничены нужным FBL address/interface,
  вместо избыточного all-interface exposure там, где это не требуется.
- iHF node/squid exporters, которые читает локальный Prometheus, переведены на
  loopback; LAN firewall для них убран.
- GF01 legacy firewall openings без активного service owner удалены. Если один
  из них реально нужен для ручного/внешнего workload, его надо вернуть вместе с
  declarative service owner и registry entry, а не как «просто открытый порт».

### Network/storage SSOT

- Cr01/iHF/iVN/iAF addresses, gateways, interfaces, host-only links и WG subnet
  вынесены в network registry.
- Cloud01/Cloud02 UUID + mountpoints и Cr mirror label/path вынесены в storage
  registry.
- qBittorrent/MeTube/Jellyfin не создают каталоги под отсутствующим external
  mountpoint через boot-time tmpfiles. Storage prepare units требуют mount.

### Service boundaries

- Nextcloud больше не имеет systemd dependency на Jellyfin media preparation.
  Его FBL_CLOUD02 external storage ограничен `nextcloud-external/`.
- iHF central Prometheus больше не пытается собирать SMART старых физических
  дисков iMac: текущий iHF — MicroVM и не владеет ими.
- Suricata и gateway-test defaults больше не ссылаются на physical `enp0s10`.

### Flake/repository hygiene

- dangling `GF01WS-16-test` output удалён: target ссылался на отсутствующий
  `hosts/GF01WS-16-test/configuration.nix`.
- physical-host remnants iHF помечены как legacy и переносятся в `_archive`,
  не удаляются.
- root README, validation, iHF/iVN/iAF docs синхронизированы с MicroVM layout.

## Что не следует «чинить» без runtime данных

1. **Grafana secret migration.** В текущем source есть legacy secret. Простое
   удаление/ротация может сделать ранее зашифрованное Grafana state нечитаемым.
   Нужен staged перенос существующего значения в root-only local EnvironmentFile,
   проверка старого state, затем удаление literal из Drive/Nix.
2. **Console password hashes.** Некоторые MicroVM users всё ещё имеют hashes в
   declarative source. Перенести на `hashedPasswordFile`/secret manager после
   подтверждения recovery + authorized keys.
3. **Root serial autologin.** Это не SSH и сейчас остаётся recovery path.
   Убирать только после отдельного решения по out-of-band recovery.
4. **Cr SMART `/dev/sdX`.** Нужен фактический mapping `/dev/disk/by-id`; guessing
   stable disk IDs опаснее текущего технического долга.
5. **MeTube OCI image.** `:latest` необходимо заменить immutable tag/digest,
   но digest выбирается только после подтверждённого успешного runtime image.
6. **Nextcloud Redis eviction.** `allkeys-lru` требует отдельной проверки для
   transactional file locking; в этом audit не менялось.

## Runtime drift, известный на 05.09.2026

GF01 -> Cr01 SSH key был добавлен пользователем вручную в
`~homefox/.ssh/authorized_keys`, после чего key-only login и Cr01 switch
успешно прошли. Сам public key ещё не перенесён в declarative Cr01 user config,
потому что audit не располагает безопасно подтверждённой строкой public key.
Private key в Drive/Nix помещать нельзя.

## Validation gate

В текущей среде audit нет Nix evaluator/build runtime, поэтому source-level
refactor нельзя объявлять build-verified. Перед следующим `switch` выполнить
`docs/VALIDATION.md` полностью. Массовый switch всех узлов запрещён как rollout
стратегия: build all -> dry-activate owner -> switch one owner/host -> runtime
checks -> следующий узел.

---

GPT-5.6 Sol создал в 18:15 05.09.2026 (МСК).

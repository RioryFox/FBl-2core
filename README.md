# FBl-2core

Текущая версия: **0.9.0**.

Единый NixOS flake Fox Byte Lab для `Cr01MS-32`, `GF01WS-16` и MicroVM
`iHF02T-6`, `iVN01T-2`, `iAF01T-8` на `Cr01MS-32`.

История изменений ведётся в `CHANGELOG.md`, номер текущего выпуска — в
`VERSION`. Перед применением конфигурации использовать `docs/VALIDATION.md`.

## Политика редактирования

- ИИ и другие автоматизированные инструменты не оставляют в файлах подписи о чтении, изменении, создании, времени работы или исполнителе.
- ИИ и другие автоматизированные инструменты не создают Google Drive-комментарии в FBl-2core.
- Технические комментарии в коде допустимы только когда они объясняют поведение, ограничения или эксплуатационные требования конфигурации.
- История изменений ведётся через Git и `CHANGELOG.md`, а не через служебные пометки в файлах.

## Архитектурные правила

Активная конфигурация FBL использует общие реестры как single source of truth:

- `modules/registry/ports.nix` — FBL service/listener ports;
- `modules/registry/network.nix` — адреса узлов, интерфейсы, LAN и host-only links;
- `modules/registry/storage.nix` — постоянные mountpoints/UUID/labels;
- `modules/registry/cache.nix` — общий Nix binary cache.

В активной конфигурации числовые TCP/UDP-порты разрешены только в
`modules/registry/ports.nix`. Это правило распространяется на host/listener,
container-internal, backend, proxy, exporter, protocol destination и другие
вспомогательные порты. Сервисные и host-модули используют только семантические
`config.fbl.ports.*` ключи. Значение `0`, когда upstream использует его как
непортовый sentinel (например, disabled Squid ICP), портом реестра не считается.


### Критический инвариант firewall: service enable -> port exposure

Для любого сервиса FBl регистрация порта и его сетевое открытие — две разные
операции. Сначала все TCP/UDP-порты сервиса фиксируются в
`modules/registry/ports.nix` как в едином реестре. Затем сервисный модуль берет
порт только через `config.fbl.ports.*`. Если этому сервису требуется входящий
доступ через firewall, правило открытия порта ОБЯЗАНО быть связано с фактическим
`enable` этого сервиса.

Fail-closed правило FBl: **disabled service => его inbound-порт отсутствует в
firewall**. Недопустима конструкция `allowedTCPPorts = [ port ];` или
`allowedUDPPorts = [ port ];`, если она оставляет порт открытым независимо от
состояния сервиса. Нормальный шаблон:

```nix
networking.firewall.interfaces.${lanInterface}.allowedTCPPorts =
  if config.services.example.enable
  then [ port ]
  else [ ];
```

Для нескольких TCP/UDP-портов условие применяется к каждому соответствующему
списку. Для OCI-контейнеров, у которых upstream-модуль не имеет `enable`,
эквивалентом enable-state является наличие контейнера в
`virtualisation.oci-containers.containers`. Сам факт регистрации порта в
`ports.nix` НЕ означает, что порт должен быть доступен из LAN: loopback-only и
internal-only сервисы (например, локальный Ollama backend) могут вообще не иметь
inbound firewall rule.

Это правило является обязательным архитектурным инвариантом FBl-2core и должно
проверяться при создании и ревью каждого сетевого сервиса.

Общая SSH-политика находится в `modules/services/ssh.nix`: SSH включён,
парольная и keyboard-interactive аутентификация отключены, root SSH запрещён.
Публичные ключи конкретных пользователей остаются host/user-level данными.

## Роли сегментов

- `CR` — вычисления и прикладные сервисы: Gitea, Ollama, Open WebUI, Nix cache,
  Nextcloud, Jellyfin, qBittorrent, MeTube, SearXNG и тяжёлые нагрузки.
- `HF` — наблюдение и privacy/network services: Grafana, Prometheus,
  Blackbox, Squid/Privoxy, Xray/VLESS, Tor и Suricata.
- `VN` — отдельная remote-access/VPN MicroVM; WireGuard сейчас является
  существующим endpoint, Tailscale обсуждается отдельно.
- `AF` — Azure Fox workstation MicroVM с cyber student profile.
- `GF` — графическая рабочая станция и пользовательское окружение.

## Активные узлы

- `Cr01MS-32`: `192.168.3.253/24`.
- `iHF02T-6`: MicroVM, `192.168.3.254/24`, host-only telemetry link
  `10.254.0.1/30 <-> 10.254.0.2/30`.
- `iVN01T-2`: MicroVM, `192.168.3.9/24`, 2 vCPU / 4 GiB RAM.
- `iAF01T-8`: MicroVM, `192.168.3.8/24`, 2 vCPU / 8 GiB RAM, host-only link
  `10.253.8.1/30 <-> 10.253.8.2/30`.
- `GF01WS-16`: физическая workstation; адрес управляется NetworkManager.

Адреса выше — декларативная конфигурация FBl-2core. Фактический runtime после
каждого rollout проверяется отдельно.

## Основные сервисы и registry keys

Числовые значения здесь намеренно не дублируются: актуальные назначения живут
только в `modules/registry/ports.nix`. Основные ключи:

| Узел | Сервис | Registry key |
|---|---|---|
| Cr01 | SSH | `fbl.ports.tcp.ssh` |
| Cr01 | Gitea | `fbl.ports.tcp.gitea` |
| Cr01 | Nextcloud | `fbl.ports.tcp.nextcloud` |
| Cr01 | Open WebUI | `fbl.ports.tcp.open-webui` |
| Cr01 | Nix cache | `fbl.ports.tcp.nix-serve` |
| Cr01 | Ollama | `fbl.ports.tcp.ollama` |
| Cr01 | qBittorrent WebUI | `fbl.ports.tcp.qbittorrentWeb` |
| Cr01 | MeTube | `fbl.ports.tcp.metube` |
| Cr01 | MeTube container | `fbl.ports.tcp.metubeContainer` |
| Cr01 | Jellyfin | `fbl.ports.tcp.jellyfin` |
| Cr01 | Jellyfin runtime | `fbl.ports.tcp.jellyfinRuntime` |
| Cr01 | SearXNG | `fbl.ports.tcp.searxng` |
| Cr01 | qBittorrent peer | `fbl.ports.tcp.qbittorrentPeer` / `fbl.ports.udp.qbittorrentPeer` |
| iHF | Grafana | `fbl.ports.tcp.grafana` |
| iHF | Squid | `fbl.ports.tcp.squid` |
| iHF | Prometheus receiver | `fbl.ports.tcp.prometheus` |
| iVN | WireGuard | `fbl.ports.udp.wireguard` |

Стандартные протокольные назначения (`dns`, `http`, `https`, `quic`) также
принадлежат registry и используются ACL/probe/gateway-модулями через ключи.

## Gitea / internal Git forge

На `Cr01MS-32` Gitea является внутренним writable Git forge и базой для следующего
этапа FBL CI/CD. Модуль подключён только к output `Cr01MS-32` в `flake.nix`. HTTP
listener берёт адрес Cr01 из network registry, а порт — только
из `fbl.ports.tcp.gitea`. Inbound firewall rule существует только при
`services.gitea.enable = true`.

Встроенный SSH server Gitea отключён; SSH clone использует системный OpenSSH и
registry key `fbl.ports.tcp.ssh`. Саморегистрация пользователей выключена, поэтому
первый admin создаётся локально через Gitea CLI после rollout. GitHub/Codeberg push
mirrors относятся к следующему этапу и этим изменением ещё не настраиваются.

Подробности: `docs/GITEA_CR01.md`.

## Storage

Канонические значения находятся в `modules/registry/storage.nix`:

- `FBL_CLOUD01` -> `/srv/fbl-cloud`;
- `FBL_CLOUD02` -> `/srv/fbl-cloud-02`;
- `CR01_MIRROR` -> `/mnt/cr01-mirror`.

Сервисы, пишущие на `FBL_CLOUD02`, не должны создавать fallback-каталоги под
mountpoint до фактического монтирования диска. qBittorrent, Jellyfin и MeTube
используют `RequiresMountsFor`/storage-prepare units.

## Monitoring

Центральные Grafana и Prometheus находятся на `iHF02T-6`. Cr01, GF01, iVN01 и
iAF01 отправляют/предоставляют метрики через выделенные exporter/agent-модули.
Cr01 remote_write использует private TAP вместо зависимости от macvtap
host<->guest communication.

Provisioned dashboards находятся в
`modules/services/monitoring/dashboards/`.

## Проверка выпуска

Сначала выполнить проверку из `docs/VALIDATION.md`. Минимальный порядок:

```bash
cd ~/FBl-2core
nix flake check --no-build --show-trace
nix build --no-link .#nixosConfigurations.Cr01MS-32.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.iHF02T-6-VM.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.iVN01T-2-VM.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.iAF01T-8-VM.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.GF01WS-16.config.system.build.toplevel
```

Не использовать `--upgrade`: inputs проекта фиксируются `flake.lock`.

## Известный технический долг

Текущий audit фиксирует, но намеренно не ломает runtime ради «красивой»
конфигурации:

- Grafana secret необходимо staged-мигрировать из Nix/Drive в root-only local
  EnvironmentFile с сохранением текущего значения до переключения;
- существующие password hashes некоторых console users надо перевести на
  `hashedPasswordFile`/секрет-хранилище после проверки SSH key coverage;
- root serial-console autologin в MicroVM остаётся recovery-механизмом до
  отдельного решения;
- Cr01 SMART device selectors нужно заменить `/dev/sdX` на подтверждённые
  `/dev/disk/by-id`, но только после runtime-инвентаризации;
- MeTube image `:latest` требуется pin к immutable tag/digest после успешной
  runtime-проверки.

Подробности: `docs/ARCHITECTURE_AUDIT_2026-09-05.md`.

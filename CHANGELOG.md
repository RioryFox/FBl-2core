# Changelog

Формат версий: `MAJOR.MINOR.PATCH`.

- `MAJOR` — несовместимая перестройка архитектуры или конфигурации.
- `MINOR` — новая роль, хост или крупная возможность с сохранением общей архитектуры.
- `PATCH` — исправление без изменения назначения сегментов.

## 0.9.0 — 2026-09-13

### Cr01 internal Git forge / Gitea

- На `Cr01MS-32` добавлен декларативный `modules/services/gitea.nix`; модуль подключён только к output `Cr01MS-32` через его flake module wrapper.
- WebUI использует уже существующий canonical registry key `fbl.ports.tcp.gitea`; числовой listener не дублируется вне `modules/registry/ports.nix`.
- Gitea bind ограничен LAN-адресом Cr01 из `fbl.network.hosts.cr01`. Firewall открывает Gitea WebUI только при `config.services.gitea.enable`; disabled service не оставляет inbound port.
- Встроенный SSH server Gitea явно отключён. SSH clone использует системный OpenSSH и общий registry key `fbl.ports.tcp.ssh`, поэтому отдельный SSH listener/port не создаётся.
- Используется локальная SQLite database и стандартный persistent state Gitea в `/var/lib/gitea`; этот state лежит на persistent root и входит в file-level Cr01 mirror, который исключает `/nix`, но не `/var`.
- Self-registration закрыта; первый admin должен быть создан локально через Gitea CLI после успешного rollout.
- Архитектурная модель `Gitea -> GitHub + Codeberg` зафиксирована как следующий этап: внешние push mirrors и CI/CD этим релизом ещё не включены.
- Добавлен `docs/GITEA_CR01.md` с ownership, bootstrap и validation границами.

### Проверка после синхронизации

- `nix flake check --no-build --show-trace`;
- `nix build --no-link .#nixosConfigurations.Cr01MS-32.config.system.build.toplevel`;
- перед switch выполнить `nixos-rebuild dry-activate` и проверить отсутствие неожиданных firewall changes;
- после switch проверить `systemctl status gitea`, `systemctl --failed` и listener по `fbl.ports.tcp.gitea`;
- проверить WebUI с FBL LAN и убедиться, что built-in Gitea SSH listener отсутствует;
- только после runtime validation создать первого admin локально и затем переходить к push mirrors.


## 0.8.4 — 2026-09-08

### Port registry invariant / literal audit

- `modules/registry/ports.nix` закреплён как единственное место активной FBl-2core, где разрешены числовые TCP/UDP-порты: правило теперь включает host/listener, container-internal, backend, proxy/exporter, protocol destination и вспомогательные порты.
- В registry добавлены семантические protocol/helper keys для DNS, HTTP, HTTPS, QUIC, внутреннего MeTube и текущего Jellyfin runtime listener.
- MeTube container mapping больше не содержит локальный numeric port; host и container стороны берутся из registry.
- iHF Squid / transparent gateway / VPN-Tor policy переведены с literal HTTP/HTTPS/DNS/QUIC ports на registry keys; TCP и UDP DNS paths разделены там, где это нужно для независимого переназначения; Tor DNS зарегистрирован как UDP, а Xray TPROXY имеет согласованные TCP/UDP registry keys.
- Monitoring registry больше не дублирует HTTPS port в каждом target; network diagnostics не имеет локального fallback-port, Prometheus DNS probe targets получают DNS port из registry.
- Jellyfin numeric runtime constraint удалён из service module: временное ограничение выражено сравнением registry keys до отдельного declarative управления `network.xml`.
- Активные README/Cr01 service docs перестали дублировать числовые FBL service ports и ссылаются на semantic registry keys.

### Проверка после синхронизации

- `nix flake check --no-build --show-trace`;
- `nix build --no-link .#nixosConfigurations.Cr01MS-32.config.system.build.toplevel`;
- собрать `.#nixosConfigurations.iHF02T-6-VM.config.system.build.toplevel`;
- перед `switch`/MicroVM rollout проверить diff generated nftables/Squid/Xray configuration;
- после rollout проверить MeTube, Jellyfin, Prometheus network diagnostics и iHF privacy/gateway services.


## 0.8.3 — 2026-09-06

### FBL Network Analysis / layout polish

- Матрица доступности переразложена в две группы сайтов на строку: каждый сайт остаётся единым блоком `URL / IP:443 / DNS`.
- Для каждой группы используются ширины `3 / 4 / 3` grid units; между двумя сайтами оставлен отдельный визуальный зазор, чтобы соседние сайты не сливались в одну шестипанельную строку.
- Верхняя подсказка расширена и разбита на отдельные строки `URL`, `IP:443`, `DNS` и три диагностические комбинации отказов.
- Логика метрик, Prometheus queries и resolver/IP probes не менялась; изменение только визуальное.


## 0.8.2 — 2026-09-05

### FBL Network Analysis / DNS vs route diagnostics

- Добавлен registry `fbl.monitoring.externalSites`: список внешних web-targets теперь является единым источником истины для Prometheus HTTP probes и локальной DNS/IP диагностики.
- На Cr01 добавлен `fbl-network-diagnostics`: раз в 30 секунд он резолвит каждый hostname через системный resolver Cr01, фиксирует primary IPv4 и без повторного DNS выполняет прямой TCP connect к этому IP на registry port (для текущих HTTPS targets — 443). Последний успешно разрешённый IPv4 сохраняется локально и используется для IP-проверки при последующем DNS outage, поэтому сценарий `DNS DOWN + IP UP` остаётся наблюдаемым.
- Диагностические метрики экспортируются через существующий loopback-only `node_exporter` textfile collector; новый сетевой listener не добавляется.
- Добавлены метрики `fbl_dns_resolution_success`, `fbl_dns_resolution_duration_seconds`, `fbl_dns_resolved_ip_info`, `fbl_ip_tcp_success`, `fbl_ip_tcp_duration_seconds`.
- Добавлен provisioned Grafana dashboard `FBL Network Analysis`: для каждого сайта три соседних traffic-light stat-панели `URL / IP:443 / DNS`, зелёные при успехе и красные при отказе. IP-панель показывает фактический primary IPv4 в имени серии.
- Матрица позволяет быстро различить уровни сбоя: DNS down при живом IP path, IP path down при успешном DNS, либо HTTP/TLS/application failure при живых DNS и TCP.
- Внизу dashboard добавлена detail-table с текущими resolved IPv4 и временем DNS lookup.

### Проверка после синхронизации

- сначала сохранить локальный свежий `flake.lock` Cr01 и не затирать его старой Drive-копией;
- `nix flake check --no-build --show-trace`;
- `nix build --no-link .#nixosConfigurations.Cr01MS-32.config.system.build.toplevel`;
- после switch проверить `systemctl status fbl-network-diagnostics.timer fbl-network-diagnostics.service prometheus grafana`;
- проверить `/var/lib/prometheus-node-exporter-text-files/fbl-network-diagnostics.prom` и наличие метрик `fbl_dns_*` / `fbl_ip_tcp_*` в Prometheus;
- открыть `FBL Network Analysis` и проверить три состояния на нескольких RU/global/infra targets.


## 0.8.1 — 2026-09-05

### Monitoring backend -> Cr01MS-32

- Grafana и центральный Prometheus/blackbox backend перенесены с iHF02T-6 на Cr01MS-32; адреса WebUI после применения: Grafana `192.168.3.253:3002`, Prometheus `192.168.3.253:5002`.
- Cr01 больше не запускает Prometheus Agent для собственных метрик: node/NVIDIA/SMART exporters остаются loopback-only и собираются локальным центральным Prometheus.
- GF01WS-16 продолжает использовать локальный Prometheus Agent, но remote_write теперь направлен на Cr01 по FBL LAN.
- iHF02T-6 и iAF01T-8 отправляют remote_write на Cr01 по существующим host-only TAP; для iVN01T-2 добавлен отдельный `10.252.0.1/30 <-> 10.252.0.2/30` host-only TAP, чтобы не зависеть от macvtap host<->guest ограничений.
- На iHF02T-6 удалены центральные Grafana/Prometheus imports; оставлен только лёгкий monitoring agent, который собирает локальные `ihf02-node` и `ihf02-squid`.
- Центральный Prometheus ограничен retention `14d` и `5GB`, чтобы monitoring не раздувал root filesystem Cr01 после недавнего ENOSPC.
- iHF02T-6 остаётся `autostart = true`; прежняя оперативная пометка OFFLINE отменена решением владельца проекта.
- Историческая TSDB/Grafana state на iHF `var.img` автоматически не переносится: runtime data migration остаётся отдельной задачей.

### Следующий этап iHF02T-6 (proposal, не включён этим релизом)

- Роль: reverse proxy + cache + IDS/IPS + TLS termination для внутренних FBL сервисов.
- Squid/Privoxy, Suricata и ClamAV уже присутствуют в текущем iHF proxy module; отдельно требуется спроектировать reverse proxy, private PKI/certificate lifecycle и решить, переводить ли Suricata из passive IDS в inline IPS.

### Проверка после синхронизации

- сначала освободить место на Cr01 и выполнить `nix flake check --no-build --show-trace`;
- собрать `Cr01MS-32`, `iHF02T-6-VM`, `iVN01T-2-VM`, `iAF01T-8-VM`, `GF01WS-16`;
- после Cr01 switch проверить `prometheus`, `grafana` и `ss -lntp` на портах 5002/3002;
- после запуска MicroVM проверить remote_write jobs `ihf02-node`, `ivn01-node`, `iaf01-node`; после GF01 rebuild — `gf01-node`.


## 0.8.0 — 2026-09-05

### Архитектурный audit / registry SSOT

- `modules/registry/ports.nix` расширен до единого реестра активных FBL listener ports; qBittorrent, Jellyfin, MeTube, SearXNG, Squid/Privoxy, WireGuard и privacy ports переведены с локальных литералов на registry.
- Добавлены `modules/registry/network.nix` и `modules/registry/storage.nix`: адреса узлов, интерфейсы, host-only links, LAN, storage mountpoints/UUID/labels вынесены из host/service modules.
- Общая key-only SSH policy вынесена в `modules/services/ssh.nix`; host firewalls открывают только registry SSH port.
- qBittorrent/MeTube/Jellyfin storage preparation переведена на mount-aware systemd units (`RequiresMountsFor`), чтобы отсутствие FBL_CLOUD02 не создавало fallback data tree на root filesystem.
- MeTube получил явное LAN firewall rule для registry host port.
- Nextcloud окончательно развязан с Jellyfin: registration FBL_CLOUD02 больше не зависит от `jellyfin-media-prepare.service`.
- Ollama оставлен loopback-only; Nix cache, Open WebUI, Grafana и LAN WebUI bind ограничены нужными FBL addresses/interfaces.
- iHF exporters, потребляемые локальным Prometheus, переведены на loopback; лишние LAN openings убраны.
- Suricata и iHF gateway defaults переведены со старого physical `enp0s10` на текущий MicroVM LAN interface из registry.
- Из центрального Prometheus удалён устаревший iHF SMART scrape физического iMac: нынешний iHF является MicroVM и не владеет теми дисками.
- Из flake удалён dangling target `GF01WS-16-test`, для которого в `hosts/` нет конфигурации.
- На GF01 закрыты исторические inbound firewall ports без активного service owner; SSH остаётся единственным явно открытым общесистемным портом.
- Документация и validation targets актуализированы под MicroVM-архитектуру и текущие host names.
- Physical-host remnants старого iHF перемещаются в `_archive`, без удаления.

### Не исправлено автоматически, требует staged/runtime решения

- Grafana secret пока нельзя безопасно удалить из текущей конфигурации без предварительного переноса существующего значения в root-only local secret file; простая ротация может сломать уже зашифрованное состояние.
- Password hashes console users и root serial-console autologin требуют отдельного hardening после проверки recovery/key coverage.
- Cr01 SMART `/dev/sdX` selectors требуют фактического `/dev/disk/by-id` mapping.
- MeTube OCI image `:latest` требует immutable pin после runtime validation.
- Redis eviction policy Nextcloud оставлена без изменения до отдельной проверки.

### Проверка после синхронизации

- `nix flake check --no-build --show-trace`;
- собрать `Cr01MS-32`, `iHF02T-6-VM`, `iVN01T-2-VM`, `iAF01T-8-VM`, `GF01WS-16`;
- не делать массовый `switch`: сначала build/dry-activate, затем по одному production owner/host;
- после Cr01 switch проверить mount dependencies, WebUI ports и `systemctl --failed`;
- после iHF guest restart проверить Grafana/Prometheus/Squid, remote_write и exporter loopback bindings.


## 0.7.0 - 2026-08-30

### GF01 monitoring -> iHF02

- Added `modules/services/gf-monitoring-exporters.nix` and imported it into `GF01WS-16`.
- GF01 now runs a localhost-only node_exporter plus Prometheus Agent and remote_writes host metrics to `http://192.168.3.254:5002/api/v1/write`.
- Series are labeled with `fbl_host=GF01WS-16` and use the dedicated `gf01-node` job.
- iHF02 now permits the Prometheus receiver on its trusted FBL LAN interface for GF01; Cr01 continues to use the private TAP receiver path.
- Added provisioned Grafana dashboard `GF01WS-16 - Host Overview` with CPU/RAM, AMD CPU and Radeon hwmon temperatures, uptime, filesystem usage, NVMe throughput, and network RX/TX.

### Verify after sync

- `nix flake check`;
- build both `GF01WS-16` and `Cr01MS-32`;
- rebuild/restart GF01 and iHF02;
- on GF01 check `systemctl status prometheus prometheus-node-exporter`;
- on iHF02 check `up{job="gf01-node"}` and the provisioned `GF01WS-16 - Host Overview` dashboard.


## 0.6.0 — 2026-08-30

### Архитектура iHF02

- `iHF02T-6` зафиксирован как persistent QEMU MicroVM на `Cr01MS-32`: 4 vCPU, 8 ГБ RAM и persistent `/var` 10 ГБ.
- Основной LAN-интерфейс iHF02 остаётся `macvtap` с адресом `192.168.3.254/24`.
- Добавлен отдельный host-only TAP `10.254.0.1/30 ↔ 10.254.0.2/30` для прямого и предсказуемого Cr01↔iHF02 обмена без зависимости от ограничений macvtap host↔guest; адрес host-side TAP задаётся декларативно через `networking.interfaces`.

### Мониторинг Cr01 → iHF02

- Схема мониторинга Cr01 переведена с pull со стороны iHF02 на push-подобный Prometheus `remote_write`: локальный Prometheus Agent на Cr01 собирает node/NVIDIA/SMART exporters и отправляет временные ряды на iHF02.
- Exporters Cr01 теперь слушают только `127.0.0.1`; их порты больше не требуется открывать в LAN.
- Prometheus на iHF02 включает `--web.enable-remote-write-receiver`; порт Prometheus разрешён только на приватном `eth1`, а не на LAN `eth0`.
- Старые direct-scrape jobs `cr01-node`, `cr01-nvidia-gpu`, `cr01-smartctl` на iHF02 удалены, чтобы исключить дублирование временных рядов. Имена jobs сохраняются на Cr01 Agent, поэтому существующий `FBL Overview` продолжает видеть Cr01.
- Добавлен отдельный provisioned Grafana dashboard `Cr01MS-32 — Host Overview` (`modules/services/monitoring/dashboards/cr01-overview.json`) с CPU/RAM/GPU, дисками, SMART и RX/TX.

### Требует проверки после синхронизации

- `nix flake check`;
- `nix build .#nixosConfigurations.Cr01MS-32.config.system.build.toplevel`;
- после `nixos-rebuild` проверить `systemctl status microvm@iHF02T-6 fbl-ihf02-hostlink prometheus`;
- на Cr01 проверить `curl http://10.254.0.2:5002/-/ready`;
- на iHF02 проверить появление `up{job="cr01-node"}` и нового Grafana dashboard.


## 0.5.0 — 2026-08-24

### Изменено

- Актуальный VPN backend `iHF02T-6` переведён на фактически протестированный Xray/VLESS (`REALITY + XHTTP`); экспериментальная AmneziaWG-ветка удалена из активного модуля.
- Persistent credential source вынесен в root-only `/var/lib/fbl-secrets/vless.uri`; runtime Xray JSON генерируется в `/run/secrets` и не попадает в Nix store/Drive.
- Tor настроен как второй privacy layer поверх Xray: его OR-соединения используют локальный Xray SOCKS и не имеют public direct fallback; loopback-only Tor SOCKS `127.0.0.1:9050` оставлен для безопасной проверки Tor exit до включения transit.
- Добавлена подготовленная, но по умолчанию выключенная, transparent transit-схема с отдельными списками VPN-only и VPN+Tor клиентов.
- Для transit режима добавлены nftables TPROXY, policy routing, DNS interception и независимый fail-closed forward barrier.
- Tor-класс явно блокирует public UDP кроме Tor DNS, поскольку Tor не является произвольным UDP-транспортом.
- Активный адрес общего Nix cache обновлён `192.168.2.51 → 192.168.3.253` (текущий DHCP lease Cr01MS-32).
- Новые зеркальные backup paths iHF используют каноническое имя `iHF02T-6`.
- Актуальная topology note переведена на `iHF02T-6` и дополнена подтверждённым default gateway `192.168.3.1`.

### Безопасность внедрения

- Transit остаётся `enable = false` до ручного выбора одного тестового клиента.
- Management plane iHF не перехватывается.
- IPv6 transit не включается; MikroTik должен отдельно исключить direct IPv6 fallback для privacy clients.
- Перед постоянным MikroTik policy routing DHCP lease iHF `.254` должен быть закреплён.

### Проверено на физическом узле до выпуска

- Xray `26.3.27` принимает профиль VLESS/REALITY/XHTTP.
- Локальный SOCKS `127.0.0.1:10808` дал подтверждённый VPN exit IP.
- `fbl-xray` штатно остановился с `status=0/SUCCESS` после теста.

### Требует ручной проверки после синхронизации

- `nix flake check`, build и dry-activate на фактическом FBl-2core;
- новый Xray `tunnel`/TPROXY inbound;
- nftables/rpfilter rules на текущем ядре;
- Tor-over-VLESS bootstrap;
- один policy-routed test client через MikroTik.


## 0.4.0 — 2026-08-23

### Изменено

- На HF-узле установлено дополнительно 2 ГБ ОЗУ: 4 ГБ → 6 ГБ.
- По схеме именования FBL каноническое имя узла изменено с `iHF02T-4` на `iHF02T-6`.
- Активные пути, flake selector и текущая документация переведены на `iHF02T-6`; исторические записи со старым именем сохранены как история.

### Добавлено

- Headless-модуль `hosts/iHF02T-6/vpn-gateway.nix`.
- Подготовлен автозапуск AmneziaWG через `awg-quick` и Xray/VLESS через отдельный systemd-unit.
- VPN-сервисы используют только runtime-конфиги `/run/secrets/awg0.conf` и `/run/secrets/xray.json`; при отсутствии секретов systemd пропускает запуск без поломки загрузки хоста.

### Не реализовано в этом выпуске

- Автоматический failover и policy routing `direct → AmneziaWG → VLESS → Tor` требуют рабочих провайдерских конфигов и отдельного теста маршрутизации.

## 0.3.0 — 2026-08-17

### Добавлено

- Декларативный datasource `FBL Prometheus` и provisioned-dashboard
  `FBL Overview`.
- Панели температуры и нагрузки CPU/GPU, занятой RAM/VRAM, заполнения
  файловых систем, SMART-состояния и температуры дисков.
- График RX/TX физических сетевых интерфейсов CR и HF.
- HTTP-проверки российских, глобальных, инфраструктурных и локальных целей.
- Независимые ICMP- и DNS-проверки для диагностики причины недоступности.
- Эвристический индикатор возможного режима белых списков: RU-группа доступна,
  глобальная группа массово недоступна.

### Примечания

- Полный WAN-трафик роутера пока не отображается: текущая панель показывает
  интерфейсы хостов. Для общего WAN потребуется SNMP exporter на роутере.
- Дашборд управляется Nix и не предназначен для постоянного редактирования в UI.
  Изменения следует вносить в
  `modules/services/monitoring/dashboards/fbl-overview.json`.

## 0.2.0 — 2026-08-17

### Изменено

- Центральное наблюдение перенесено из сегмента CR в HF.
- `iHF02T-4` теперь запускает Grafana, Prometheus и blackbox exporter.
- Prometheus на HF собирает локальные метрики iHF02, Squid и удалённые метрики Cr01.
- `Cr01MS-32` больше не хранит временные ряды и не запускает Grafana.
- На Cr01 оставлены только экспортёры оборудования: node, NVIDIA GPU и SMART.
- Сохранён существующий `security.secret_key` Grafana.
- Добавлены правила ведения версий проекта и инструкция переноса runtime-данных.

### Требует действия

- Проверить, что имя `Cr01MS-32` разрешается с iHF02T-4.
- Перенести `/var/lib/grafana` и `/var/lib/prometheus2` по инструкции
  `docs/MONITORING_MIGRATION.md`, если нужна старая история и дашборды.
- Сначала проверить `build` и `dry-activate` обоих хостов.

## 0.1.0 — 2026-08-14

- Создана независимая миграционная копия FBL-Core.
- Добавлен хост `GF01WS-16` с Hyprland и Home Manager.
- Сохранены исходные конфигурации `Cr01MS-32` и `iHF02T-4`.

# Перенос мониторинга CR -> HF

Целевая схема версии `0.2.0`:

- `iHF02T-4`: Grafana, Prometheus, blackbox exporter, хранение метрик;
- `Cr01MS-32`: node exporter, NVIDIA GPU exporter, SMART exporter;
- `iHF02T-4/hf-proxy.nix`: локальный node exporter и Squid exporter.

## 1. Проверка разрешения имени

На iHF02T-4:

```bash
getent hosts Cr01MS-32
```

Если имя не разрешается, укажите стабильный адрес CR в
`hosts/iHF02T-4/configuration.nix`:

```nix
fbl.monitoring.cr01Host = "192.168.1.X";
```

## 2. Безопасная проверка конфигураций

На каждой машине сначала синхронизировать один и тот же выпуск `0.2.0`.

На Cr01MS-32:

```bash
cd ~/FBl-2core
sudo nixos-rebuild build --flake .#Cr01MS-32
sudo nixos-rebuild dry-activate --flake .#Cr01MS-32
```

На iHF02T-4:

```bash
cd ~/FBl-2core
sudo nixos-rebuild build --flake .#iHF02T-4
sudo nixos-rebuild dry-activate --flake .#iHF02T-4
```

## 3. Перенос истории и дашбордов

Этот этап нужен только для сохранения существующей базы Grafana и истории
Prometheus. Перед копированием сервисы на CR должны быть остановлены, чтобы
получить согласованный снимок.

На Cr01MS-32:

```bash
sudo systemctl stop grafana prometheus
sudo tar --xattrs --acls -C /var/lib \
  -cpf /tmp/fbl-monitoring-state.tar grafana prometheus2
scp /tmp/fbl-monitoring-state.tar imac@iHF02T-4:/tmp/
```

На iHF02T-4 после первой сборки, но до окончательного запуска:

```bash
sudo systemctl stop grafana prometheus
sudo tar --xattrs --acls -C /var/lib \
  -xpf /tmp/fbl-monitoring-state.tar
sudo chown -R grafana:grafana /var/lib/grafana
sudo chown -R prometheus:prometheus /var/lib/prometheus2
```

Существующий `security.secret_key` сохранён в модуле Grafana, поэтому
зашифрованные значения datasource должны остаться читаемыми.

## 4. Переключение

Сначала включить центральный мониторинг на HF:

```bash
cd ~/FBl-2core
sudo nixos-rebuild switch --flake .#iHF02T-4
```

Затем переключить CR в режим экспортёров:

```bash
cd ~/FBl-2core
sudo nixos-rebuild switch --flake .#Cr01MS-32
```

## 5. Проверка

На HF:

```bash
systemctl status grafana prometheus --no-pager
curl -fsS http://Cr01MS-32:9001/metrics >/dev/null
curl -fsS http://Cr01MS-32:9002/metrics >/dev/null
curl -fsS http://Cr01MS-32:9004/metrics >/dev/null
curl -fsS http://127.0.0.1:9100/metrics >/dev/null
curl -fsS http://127.0.0.1:9301/metrics >/dev/null
```

Grafana после переключения доступна на `http://iHF02T-4:3002`.

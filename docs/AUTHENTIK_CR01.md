# Cr01 Authentik / ComfyUI authentication

Статус: конфигурация подготовлена в FBl-2core; runtime rollout ещё не подтверждён.
Owner: `Cr01MS-32`.

## Назначение

Authentik становится локальным identity/authentication layer для FBL WebUI. Первый защищаемый сервис — ComfyUI.

Архитектура первого этапа:

`FBL LAN -> nginx -> Authentik Forward Auth -> ComfyUI loopback backend`

ComfyUI больше не должен быть доступен напрямую из LAN. Его backend использует `fbl.ports.tcp.comfyui` и слушает только `127.0.0.1`. Browser-facing endpoint принадлежит nginx и использует `fbl.ports.tcp.comfyuiProtected`. Authentik WebUI принадлежит nginx и использует `fbl.ports.tcp.authentik`.

## Security invariants

- Числовые listener ports задаются только в `modules/registry/ports.nix`.
- `fbl.ports.tcp.comfyui` не открывается в LAN firewall.
- Authentik backend HTTPS, metrics и worker listeners остаются loopback-only.
- В LAN firewall открываются только Authentik nginx entrypoint и protected ComfyUI entrypoint, причём только при включённых владельцах сервисов.
- Authentik принимает proxy headers только от loopback reverse proxy.
- Authentik secrets не хранятся в Git, Nix expressions или Google Drive.
- ComfyUI Manager остаётся отключён.

## До build/switch: создать secret на Cr01

`services.authentik.environmentFile` указывает на локальный root-only файл:

```text
/var/lib/fbl-secrets/authentik.env
```

Перед первым build/switch создать его на Cr01:

```bash
sudo install -d -m 0700 -o root -g root /var/lib/fbl-secrets
secret="$(head -c 60 /dev/urandom | base64 -w0)"
printf 'AUTHENTIK_SECRET_KEY=%s\n' "$secret" | sudo tee /var/lib/fbl-secrets/authentik.env >/dev/null
unset secret
sudo chown root:root /var/lib/fbl-secrets/authentik.env
sudo chmod 0600 /var/lib/fbl-secrets/authentik.env
```

Проверить только metadata, не печатая secret:

```bash
sudo stat -c '%U:%G %a %n' /var/lib/fbl-secrets/authentik.env
```

Ожидается `root:root 600`.

## Flake lock

Drive-копия `flake.lock` на момент изменения была явно старее текущего `flake.nix`, поэтому она намеренно не перезаписывалась. На Cr01 сохранить локальный актуальный lock и добавить новый pinned input `authentik-nix` к нему:

```bash
cd ~/FBl-2core
cp flake.lock flake.lock.pre-authentik
nix flake lock
```

После этого проверить diff. Существующие inputs не должны неожиданно сменить rev:

```bash
git diff -- flake.lock
```

Не использовать общий `nix flake update`/`--upgrade` для этого rollout.

## Pre-switch validation

```bash
cd ~/FBl-2core
nix flake check --no-build --show-trace
nix build --no-link .#nixosConfigurations.Cr01MS-32.config.system.build.toplevel
readlink -f /run/current-system
sudo nix-env --profile /nix/var/nix/profiles/system --list-generations
sudo nixos-rebuild dry-activate --flake .#Cr01MS-32
```

До `switch` сохранить текущую generation как rollback target.

## Switch

После успешных evaluation/build/dry-activate:

```bash
sudo nixos-rebuild switch --flake .#Cr01MS-32
```

Проверить:

```bash
systemctl status authentik authentik-worker authentik-migrate postgresql nginx comfyui --no-pager
systemctl --failed
ss -lntp
```

Ожидается:
- ComfyUI backend слушает только loopback;
- Authentik core/worker/metrics listeners не выставлены напрямую в LAN;
- browser-facing Authentik и protected ComfyUI принадлежат nginx.

## Первый вход в Authentik

Открыть Authentik на LAN-адресе Cr01 и порту `fbl.ports.tcp.authentik`, затем initial setup flow:

```text
http://<Cr01>:<fbl.ports.tcp.authentik>/if/flow/initial-setup/
```

Важно: trailing slash `/` обязателен.

Создать пароль стандартного администратора `akadmin`. Сам пароль в FBl-2core/Drive не сохранять.

## Подключить ComfyUI к Forward Auth

В Authentik Admin:

1. `Applications -> Providers -> Create`.
2. Выбрать `Proxy Provider`.
3. Режим: `Forward auth (single application)`.
4. External host: browser-facing URL Cr01 на `fbl.ports.tcp.comfyuiProtected`.
5. Authorization flow: стандартный provider authorization flow.
6. Создать `Application`, например `FBL ComfyUI`, и выбрать созданный provider.
7. В `Applications -> Outposts` открыть embedded outpost и убедиться, что ComfyUI provider назначен ему.

После этого запрос к protected ComfyUI endpoint без сессии должен перенаправляться в Authentik login flow. После успешного входа должны работать UI и WebSocket ComfyUI.

## Runtime validation

С другого узла FBL LAN проверить:

- прямой `fbl.ports.tcp.comfyui` недоступен;
- `fbl.ports.tcp.comfyuiProtected` без сессии не отдаёт ComfyUI напрямую;
- после login открывается ComfyUI;
- WebSocket/queue updates работают;
- logout Authentik снова закрывает protected endpoint.

Дополнительно на Cr01 проверить, что firewall не содержит прямого LAN opening backend ComfyUI.

## Rollback

Если Authentik/nginx не стартуют или protected frontend не работает:

1. Не открывать ComfyUI backend напрямую как временный обход.
2. Вернуться к сохранённой предыдущей NixOS generation.
3. Зафиксировать failure отдельно до повторного rollout.

## Следующие этапы

После стабилизации можно отдельно подключить к Authentik Gitea, Grafana и другие FBL WebUI. Это не входит в текущий rollout и не должно автоматически менять их существующую аутентификацию.

[GPT-5.6 Sol] изменил в 18:51 13.09.2026 (МСК).

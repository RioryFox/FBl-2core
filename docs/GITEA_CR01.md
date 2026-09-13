# Cr01 Gitea — internal Git forge

Статус: декларативный сервис FBl-2core версии `0.9.0`; owner — `Cr01MS-32`.
Модуль подключён только к output `Cr01MS-32` в `flake.nix`.

## Назначение

Gitea — внутренний writable Git forge FBL и будущая точка запуска CI/CD. Канонический
workflow предполагает, что изменения принимаются Gitea, а GitHub и Codeberg позже
подключаются как внешние push mirrors. В релизе `0.9.0` зеркала и runner ещё не
настроены.

## Network / firewall invariants

- HTTP address берётся из `fbl.network.hosts.cr01`.
- HTTP port берётся только из `fbl.ports.tcp.gitea`.
- `networking.firewall.interfaces.${lanInterface}.allowedTCPPorts` содержит этот port
  только когда `config.services.gitea.enable = true`.
- Built-in SSH server Gitea отключён. SSH clone/push использует системный OpenSSH и
  `fbl.ports.tcp.ssh`; отдельный SSH listener Gitea не создаётся.

Таким образом выполняется FBL fail-closed invariant: `disabled service => no inbound
service port`.

## State / backup

Первый этап использует SQLite. Стандартный state NixOS Gitea находится в
`/var/lib/gitea`; repository root по умолчанию также находится внутри этого state.
`mirror-backup.nix` зеркалирует root filesystem с исключением `/nix`, но не `/var`,
поэтому Gitea state входит в file-level Cr01 mirror. Внешние GitHub/Codeberg mirrors
позже дадут дополнительную копию Git history, но не заменят backup forge metadata.

## Account bootstrap

Self-registration отключена. После первого успешного rollout и проверки
`gitea.service` создать первого admin локально:

```bash
sudo -u gitea gitea --work-path /var/lib/gitea \
  --config /var/lib/gitea/custom/conf/app.ini \
  admin user create \
  --username <admin> \
  --email <email> \
  --admin \
  --random-password
```

Пароль/токен не хранить в Nix или Drive. Временный случайный пароль после первого
входа заменить.

## Runtime validation

1. Выполнить `docs/VALIDATION.md` до `switch`.
2. После `switch` проверить `systemctl status gitea --no-pager` и `systemctl --failed`.
3. Проверить HTTP listener на LAN-адресе Cr01 и `fbl.ports.tcp.gitea`.
4. Убедиться, что отдельный built-in SSH listener Gitea отсутствует и системный SSH
   продолжает работать по существующей key-only policy.
5. Проверить WebUI из FBL LAN.
6. Только после этого создать admin и переходить к настройке push mirrors.

## Следующий этап

Планируемая репликация: `Gitea -> GitHub` и `Gitea -> Codeberg`, только outbound push
mirror. GitHub/Codeberg не должны автоматически писать обратно в Gitea. CI/CD owner
также должен оставаться локальным; внешние forge не получают authority на production
`switch` Cr01.

---

[GPT-5.6 Sol] изменил в 17:40 13.09.2026 (МСК).

[GPT-5.6 Sol] прочитал в 18:44 13.09.2026 (МСК).

## Target replication architecture: Gitea -> GitHub + Codeberg

### Authority model

- `Gitea/Cr01` is the only authoritative writable forge for FBL repositories.
- Developer clones use Gitea as `origin`; normal development never depends on GitHub or Codeberg availability.
- GitHub and Codeberg are outbound mirrors/distribution copies. No automatic pull mirror, webhook or CI path may write changes back into Gitea.
- Production CI/CD authority remains local to FBL. External forge state must never authorize `nixos-rebuild switch` or another production activation.

### Replication path

For every mirrored repository:

```text
Developer / AI
      |
      v
 Gitea on Cr01   (authoritative)
    /      \
   v        v
GitHub    Codeberg
mirror     mirror
```

Gitea push mirrors should use HTTPS credentials, with `sync_on_commit` enabled and a periodic retry interval kept as a fallback. Failure of either external mirror must not reject or roll back a successful push to Gitea.

### Destination policy

- Create the destination repository before enabling the mirror.
- Do not initialize destination repositories with independent commits such as README/LICENSE when creating them.
- Treat destination refs as disposable derivatives of Gitea refs. Direct pushes to GitHub/Codeberg are prohibited by policy.
- Do not configure destination branch rules that block the Gitea mirror's required force-update behavior unless the mirror identity is explicitly permitted to bypass those rules.
- External issues, pull requests, Actions/CI and releases are not authoritative. Initially they should be disabled where practical or clearly marked as non-canonical. A future contribution bridge, if desired, must be a separate reviewed workflow rather than bidirectional synchronization.

### Credentials

- Mirror credentials must not be committed to Git, Nix expressions or Google Drive.
- GitHub: prefer a dedicated mirror identity and repository-scoped fine-grained credential with only permissions required to push repository contents/refs.
- Codeberg: prefer a dedicated mirror account. Codeberg access tokens can grant broad account access, so the account itself should contain only mirror repositories and no unrelated authority.
- Store credentials in a root-only secret mechanism on Cr01 (target: age/sops-nix/agenix class of solution) and rotate independently for GitHub and Codeberg.

### Failure and recovery semantics

- Gitea remains available and writable when GitHub or Codeberg is unavailable.
- Mirror failures are asynchronous replication failures, not source-control failures.
- Monitor each push mirror's `last_update` and `last_error`; alert when a mirror remains stale or errored beyond the chosen SLO.
- Recovery is always source -> destination. Never repair Gitea by automatically pulling from an external mirror.
- If Gitea is lost, restore its forge state from the Cr01 backup first. GitHub/Codeberg may be used as emergency Git-history sources, but they do not contain all Gitea metadata.

### Git metadata scope

Push mirroring replicates Git refs/history (branches, tags, commits). Forge metadata such as users, permissions, issues, pull requests, comments, webhooks, secrets and CI state is not part of the Git mirror and therefore remains covered by the Gitea state backup policy.

Git LFS requires a separate validation before enabling it for mirrored FBL repositories; plain Git ref mirroring must not be assumed to replicate all LFS objects correctly across both destinations.

### Recommended rollout

1. Select one non-critical FBL repository as a canary.
2. Create empty GitHub and Codeberg destination repositories.
3. Create dedicated mirror credentials and store them outside Git/Nix/Drive.
4. Add both destinations as Gitea push mirrors with sync-on-commit plus periodic retry.
5. Push a test branch and tag to Gitea; verify both mirrors.
6. Test rewrite/force-update and branch/tag deletion behavior before declaring the mirrors authoritative copies.
7. Simulate GitHub outage and Codeberg outage independently; verify that pushes to Gitea remain successful and failed mirrors later recover.
8. Add mirror health monitoring from the Gitea API.
9. Roll the pattern out to the remaining repositories.

### Decision status

Proposed architecture: **ACCEPT for implementation**, subject to canary validation of ref deletion, force-update behavior and chosen secret-storage mechanism.

[GPT-5.6 Sol] изменил в 19:15 13.09.2026 (МСК).

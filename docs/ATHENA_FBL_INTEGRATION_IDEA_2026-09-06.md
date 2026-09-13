# Athena OS Nix -> FBl-2core: идея интеграции

Статус: **PAUSED / TO THINK**
Дата фиксации: 06.09.2026

## Идея

Интегрировать Athena OS Nix в FBl-2core не как отдельный чужой дистрибутив поверх FBL, а как ещё один FBL-host/profile, который сохраняет характер Athena, но подчиняется инфраструктурной философии FBl-2core.

Ключевой принцип:

- **FBl-2core владеет инфраструктурой**: host identity, сеть, registry, SSH, cache chain, monitoring, storage policy, secrets policy, rebuild/validation workflow и общими правилами проекта.
- **Athena сохраняет свою сущность**: cybersecurity-oriented workstation, наборы pentest/red-team инструментов, Athena UX/desktop/theme/workflow и специфические пакеты/модули там, где это не ломает FBL-границы.

## Что обнаружено при первичном сравнении

Текущий `FBl-2core/modules/cyber` уже архитектурно очень близок к Athena Nix:

- одинаковый интерфейс `cyber.enable` + `cyber.role`;
- совпадает набор ролей: `blue`, `bugbounty`, `cracker`, `dos`, `forensic`, `malware`, `mobile`, `network`, `osint`, `red`, `student`, `web`;
- package sets явно родственны Athena, хотя актуальный upstream Athena уже немного отличается.

Следствие: **прямой импорт Athena целиком поверх FBl-2core нежелателен**. Вероятны коллизии `options.cyber`, а Athena также пытается управлять частью base system: user/Home Manager, bootloader, desktop/display manager, os-release, Nix settings, stateVersion и другими host-level параметрами.

## Предварительная архитектурная гипотеза

Предпочтительный вариант для дальнейшего проектирования:

**Athena-FBL как reusable personality/profile + обычный `hosts/<host>/configuration.nix` как конкретная машина.**

Это позволит отделить:

1. Athena-specific personality/tooling/UX;
2. FBL infrastructure contracts;
3. hardware/network/storage конкретного хоста.

Такой профиль потенциально можно будет использовать как на bare metal, так и в VM/MicroVM, не смешивая Athena identity с конкретным железом.

## Не решено

Нужно отдельно подумать и затем утвердить:

- первый Athena host будет bare metal, MicroVM или профиль сначала делаем hardware-agnostic;
- насколько близко сохранять Athena desktop/theme/Home Manager;
- использовать upstream Athena как pinned flake input или аккуратно перенести нужные части в FBl-2core;
- как развести существующий FBL `modules/cyber` и Athena upstream без дублирования/коллизий;
- какие Athena modules считать identity, а какие заменить FBL-equivalent модулями;
- стратегия обновления upstream Athena и контроль регрессий.

До отдельного решения пользователя реализацию **не начинать**.

[GPT-5.6 Sol] изменил в 23:26 06.09.2026 (МСК).

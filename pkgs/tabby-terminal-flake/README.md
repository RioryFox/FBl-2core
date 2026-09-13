# Tabby Terminal для NixOS

Готовый standalone-flake для официального Tabby Terminal AppImage `v1.0.235`.
Не путать с пакетом `nixpkgs#tabby`: это TabbyML, другой проект.

## Проверить без установки

```bash
cd tabby-terminal-flake
nix run
```

## Установить в профиль

```bash
nix profile install .
```

Удалить установленный пакет:

```bash
nix profile remove tabby-terminal
```

## Подключить к системному flake

Добавить input:

```nix
inputs.tabby-terminal.url = "path:./pkgs/tabby-terminal-flake";
```

Передать `tabby-terminal` в `specialArgs` или использовать input прямо в
`outputs`, затем добавить пакет для нужной системы:

```nix
environment.systemPackages = [
  inputs.tabby-terminal.packages.${pkgs.system}.default
];
```

После переноса папки внутрь репозитория выполните:

```bash
nix flake lock
sudo nixos-rebuild switch --flake .#GF01WS-16
```

## Обновление

При выходе новой версии нужно одновременно изменить `version` и `hash` в
`flake.nix`. SHA-256 следует брать со страницы официального релиза Tabby.

Источник: https://github.com/Eugeny/tabby/releases

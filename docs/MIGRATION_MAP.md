# Карта переноса GF01WS-16 в FBl-2core

Карта зафиксирована до записи новой структуры. Источники: актуальный `FBL-Core`
на Google Drive, дерево `GF01WS-16/NixOS-Hyprland`, инвентарная карточка
GF01WS-16 и установочные сценарии старой конфигурации.

## Инварианты

- Старый `FBL-Core` не изменяется и не удаляется.
- Файлы `hosts/Cr01MS-32`, `hosts/iHF02T-4` и их существующие импорты
  переносятся побайтово.
- Cr01MS-32 и iHF02T-4 продолжают собираться из `nixos-26.05`.
- GF01WS-16 продолжает использовать revision `nixos-unstable` из своего старого
  `flake.lock` и свой `system.stateVersion = "26.05"`.
- Закрытые ключи, runtime-базы и идентификаторы машины не переносятся.

## Соответствия

| Старый источник | Новый путь | Решение |
|---|---|---|
| `FBL-Core/hosts/Cr01MS-32` | `hosts/Cr01MS-32` | без изменений |
| `FBL-Core/hosts/iHF02T-4` | `hosts/iHF02T-4` | без изменений |
| `FBL-Core/modules/*` | `modules/*` | существующие файлы без изменений |
| `hosts/default/config.nix` | `hosts/GF01WS-16/configuration.nix` | имя хоста и поведение сохранены; импорты разложены по FBL-архитектуре |
| `hosts/default/hardware.nix` | `hosts/GF01WS-16/hardware-configuration.nix` | UUID, swap, boot и AMD-параметры сохранены |
| `hosts/default/users.nix` | `hosts/GF01WS-16/users.nix` | пользователь, группы, приложения, n8n и zsh сохранены |
| `hosts/default/packages-fonts.nix` | `hosts/GF01WS-16/packages.nix` | host-only приложения и сервисы сохранены |
| `hosts/default/pkgs/*` | `hosts/GF01WS-16/pkgs/*` | The Dude и WireGuard остаются специфичными для GF01 |
| старый `hosts/default/cyber` | общий `modules/cyber` + Wine delta в `users.nix` | роль `student` совпадает; старый Wine-набор добавлен как GF01-only delta |
| `modules/{packages,fonts,portals,theme,ly,quickshell,nh}.nix` | `modules/desktop/hyprland/*` | общий Hyprland desktop stack |
| `modules/{amd,intel,nvidia,nvidia-prime,vm-guest,local-hardware-clock}*` | `modules/hardware/*` | переиспользуемые аппаратные модули |
| `modules/overlays.nix` | `modules/overlays.nix` | общая совместимость пакетов/CMake |
| `modules/home/*` | `hosts/GF01WS-16/home/*` | личные CLI, Ghostty, tmux, Nixvim, Yazi и QuickShell overview |
| `pkgs/waybar-weather.nix` | `pkgs/waybar-weather.nix` | пакет сохранён |
| `pkgs/tabby-terminal-flake` | `pkgs/tabby-terminal-flake` | подключён как flake input/package; больше не импортируется как NixOS module |
| старые installer assets/scripts | `hosts/GF01WS-16/legacy-installer` | сохранены для аудита, но не запускаются новой конфигурацией |
| старый inline cache GF01 | `modules/registry/{ports,cache}.nix` | используется актуальный адрес/публичный ключ FBL-Core; Hyprland Cachix сохранён |
| `~/NixOS-Hyprland` в `update`, `rebuild`, `nh` | `/home/rioryfox/FBl-2core` | команды переведены на новый путь и selector `GF01WS-16` |

## Граница полноты: внешние dotfiles

Старый flake прямо указывает, что Hyprland dotfiles в нём отсутствуют.
Инсталлятор клонировал `JaKooLit/Hyprland-Dots` и копировал конфиги в `$HOME`.
Поэтому текущие `~/.config/hypr`, Waybar, Rofi, wlogout и swaync невозможно
восстановить только из Google Drive без снимка самой рабочей станции.

В `hosts/GF01WS-16/dotfiles` добавлен безопасный сценарий снимка: он только
копирует существующие файлы и ничего не удаляет. До выполнения этого сценария
сохранены все доступные на Drive hotkeys (Ghostty, tmux, Nixvim, Yazi) и
QuickShell-механики, но полнота именно Hyprland-hotkeys остаётся проверяемым
внешним условием.

# Проверка полноты GF01WS-16

## Результат статической сверки

- Список `modules/packages.nix` сверен с новым Hyprland package-модулем:
  старых уникальных package references, отсутствующих в новом, нет.
- Пользовательский список `users.nix` сверен: потерянных приложений нет.
- Старые `cyber/student` и `cyber/common` сверены с общим FBL cyber-модулем
  и GF-only Wine delta: потерянных package references нет.
- Host-only `packages-fonts.nix`, hardware-конфигурация, переменные, The Dude
  и WireGuard перенесены неизменёнными (с переименованием файлов по архитектуре).
- Все активные Home Manager файлы и QuickShell QML/assets скопированы
  неизменёнными.
- Cr01MS-32 и iHF02T-4 скопированы средствами Google Drive из актуального
  `FBL-Core`, а не переписаны вручную.

## Матрица возможностей

| Возможность | Статус | Новый источник |
|---|---|---|
| Zen kernel, boot, Plymouth, AppImage binfmt, v4l2loopback | сохранено | `hosts/GF01WS-16/configuration.nix` |
| AMD/Intel GPU toggles и аппаратные модули | сохранено | `modules/hardware/*` |
| Hyprland/XWayland, Wayland portals, Waybar, Rofi, уведомления | сохранено | `modules/desktop/hyprland/*` |
| Ly matrix login, Catppuccin, GTK/Qt/cursor defaults, fonts | сохранено | `modules/desktop/hyprland/*` |
| Firefox/Chromium/LibreWolf/VSCodium/DBeaver/Figma/Telegram и остальной app stack | сохранено | system + user package modules |
| Steam/Proton, OBS/virtual camera, Shotcut/VLC, Stable Diffusion Vulkan | сохранено | host/system package modules |
| Amnezia, v2rayA/Xray, WireGuard/OpenVPN, The Dude | сохранено | `hosts/GF01WS-16/*` |
| n8n, Flatpak/Flathub, NFS, SSH, Bluetooth, PipeWire, fprint Goodix | сохранено | host modules |
| Cyber role `student`, payloads/wordlists, Wireshark | сохранено | общий `modules/cyber` + GF Wine delta |
| Ghostty и `ghostty-bg`, tmux popup/keymaps, Nixvim keymaps, Yazi keymap/theme | сохранено | `hosts/GF01WS-16/home/*` |
| QuickShell overview и `SUPER+TAB`-механика | QML сохранён; bind зависит от live dotfiles | `hosts/GF01WS-16/home/overview*` |
| Tabby Terminal AppImage v1.0.235 | сохранено и исправлено подключение | `pkgs/tabby-terminal-flake`, flake input/package |
| `update`, `rebuild`, `ncg`, `nh` | сохранено; путь изменён на `~/FBl-2core` | Hyprland modules |
| Актуальный подписанный cache Cr01 | сохранено из FBL-Core | `modules/registry/*` |
| Текущие Hyprland/Waybar/Rofi/wlogout/swaync hotkeys | требуется снимок GF01 | `hosts/GF01WS-16/dotfiles/capture-live-dotfiles.sh` |

## Намеренно не активировано

- Старые installer scripts и assets сохранены в `legacy-installer`, но не
  выполняются: они клонируют внешние репозитории, перемещают конфиги и могут
  перезаписать `$HOME`.
- `db/` не переносился: это runtime-state с hashes/users/keypair/interface data,
  а не Nix-конфигурация. Публичный ключ cache взят из актуального FBL-Core;
  закрытые ключи в flake/Drive не добавлялись.
- Примерные upstream-хосты `jak-hl`, `nixos-test`, `nixos` не являются GF01 и
  не подключались к новой конфигурации.

## Открытый контроль полноты

До снимка live dotfiles статус общей миграции: **полный для доступного Drive
source, условный для пользовательских Hyprland hotkeys/dotfiles**. Это не ошибка
переноса: соответствующих файлов в старом Drive source нет.

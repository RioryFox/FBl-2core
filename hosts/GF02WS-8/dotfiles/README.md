# Live dotfiles boundary

The old Drive repository does not contain Hyprland dotfiles. Its installer
downloaded them separately and copied them into the user's home directory.

Run `./capture-live-dotfiles.sh` on GF01WS-16 before considering the migration
feature-complete. The script creates a timestamped snapshot below `snapshots/`,
does not use `--delete`, and never edits the live configuration.

Expected sources, when present:

- `~/.config/hypr`
- `~/.config/waybar`
- `~/.config/rofi`
- `~/.config/wlogout`
- `~/.config/swaync`
- `~/.config/quickshell`
- `~/.config/kitty`
- `~/.config/wezterm`

After capture, review secrets and machine identifiers before committing or
uploading the snapshot. Do not copy credentials, tokens, SSH private keys, or
browser profiles into this flake.

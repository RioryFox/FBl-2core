#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
destination="$repo_root/hosts/GF01WS-16/dotfiles/snapshots/$stamp"

mkdir -p "$destination"

for name in hypr waybar rofi wlogout swaync quickshell kitty wezterm; do
  source_path="$HOME/.config/$name"
  if [[ -e "$source_path" ]]; then
    mkdir -p "$destination/.config"
    rsync -a --protect-args "$source_path" "$destination/.config/"
  fi
done

if [[ -e "$HOME/.zshrc" ]]; then
  rsync -a --protect-args "$HOME/.zshrc" "$destination/"
fi

printf 'Snapshot created: %s\n' "$destination"
printf 'Review it for secrets before committing or uploading.\n'

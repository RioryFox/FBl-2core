{
  lib,
  pkgs,
  ...
}: let
  # Tabby is packaged through an AppImage/FHS wrapper on NixOS. That wrapper sets
  # no_new_privs, so a shell started directly by it cannot use setuid sudo.
  # A transient user service is launched by the user systemd manager instead and
  # therefore starts outside Tabby's FHS sandbox while remaining the same user.
  tabbyHostShell = pkgs.writeShellScriptBin "tabby-host-shell" ''
    exec ${pkgs.systemd}/bin/systemd-run \
      --user \
      --pty \
      --wait \
      --collect \
      --same-dir \
      ${pkgs.zsh}/bin/zsh -l
  '';

  # Keep a separate launcher so Hyprland's $term remains a single executable
  # (the dropdown-terminal script also expects that).
  tabbyHostTerminal = pkgs.writeShellScriptBin "tabby-host-terminal" ''
    export SHELL="${tabbyHostShell}/bin/tabby-host-shell"
    exec /run/current-system/sw/bin/tabby-terminal "$@"
  '';

  # WinBox 4 is 64-bit. The old GF01 ~/.wine prefix is 32-bit, so the unwrapped
  # package exits before showing a window. Keep that prefix untouched and give
  # WinBox its own 64-bit prefix instead.
  winboxGF01 = pkgs.writeShellScriptBin "winbox" ''
    export WINEPREFIX="$HOME/.local/share/winbox/wineprefix"
    export WINEARCH=win64
    ${pkgs.coreutils}/bin/mkdir -p "$WINEPREFIX"
    exec ${pkgs.winbox}/bin/winbox "$@"
  '';
in {
  imports = [
    ./terminals/tmux.nix
    ./terminals/ghostty.nix
    ./editors/nixvim.nix
    ./cli/bat.nix
    ./cli/btop.nix
    ./cli/bottom.nix
    ./cli/eza.nix
    ./cli/fzf.nix
    ./cli/git.nix
    ./cli/htop.nix
    ./cli/tealdeer.nix
    ./yazi
    ./overview.nix
  ];

  home.packages = [
    tabbyHostShell
    tabbyHostTerminal
    winboxGF01
  ];

  # Prefer this user-level desktop entry over the one from the raw package, so
  # launchers also use the isolated 64-bit prefix.
  xdg.desktopEntries.winbox = {
    name = "WinBox";
    genericName = "MikroTik Router Management";
    comment = "Manage MikroTik RouterOS devices";
    exec = "${winboxGF01}/bin/winbox";
    icon = "winbox";
    terminal = false;
    categories = ["Network" "RemoteAccess"];
  };

  # This is the single GF01 user-default file consumed by the existing
  # Hyprland Keybinds.conf. SUPER+Return expands $term from here.
  home.file.".config/hypr/UserConfigs/01-UserDefaults.conf".text = ''
    # /* ---- 💫 https://github.com/JaKooLit 💫 ---- */

    # Define preferred text editor for the KooL Quick Settings Menu (SUPER SHIFT E)
    $edit = ''${EDITOR:-nano}

    # Default applications used by Hyprland keybindings and Waybar modules
    $term = tabby-host-terminal
    $files = thunar

    # GF01 override: remove any earlier SUPER+Return binding (including Kitty)
    # and install the host-specific Tabby launcher as the final binding.
    unbind = SUPER, Return
    bindd = SUPER, Return, Open Tabby terminal, exec, tabby-host-terminal

    # Default Search Engine for ROFI Search (SUPER S)
    $Search_Engine = "https://www.google.com/search?q={}"
  '';

  # Keep the mutable JaKooLit files mutable. Home Manager only repairs them if
  # they are absent/broken and makes sure the left Waybar is started. This avoids
  # the dangling Home Manager symlinks that previously broke Hyprland sources.
  home.activation.gf01HyprlandRecovery = lib.hm.dag.entryAfter ["writeBoundary"] ''
    hypr_dir="$HOME/.config/hypr"
    startup="$hypr_dir/configs/Startup_Apps.conf"
    settings="$hypr_dir/UserConfigs/UserSettings.conf"

    ${pkgs.coreutils}/bin/mkdir -p \
      "$hypr_dir/configs" \
      "$hypr_dir/UserConfigs"

    if [ ! -e "$startup" ]; then
      if [ -L "$startup" ]; then
        ${pkgs.coreutils}/bin/rm -f "$startup"
      fi
      ${pkgs.coreutils}/bin/printf '%s\n' \
        '$scriptsDir = $HOME/.config/hypr/scripts' \
        'exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP' \
        'exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP' \
        'exec-once = swww-daemon --format xrgb' \
        'exec-once = $scriptsDir/Polkit-NixOS.sh' \
        'exec-once = nm-applet --indicator' \
        'exec-once = swaync' \
        'exec-once = waybar' \
        'exec-once = qs -c overview' \
        'exec-once = hypridle' \
        'exec-once = $scriptsDir/Hyprsunset.sh init' \
        'exec-once = $scriptsDir/KeybindsLayoutInit.sh' \
        'exec-once = wl-paste --type text --watch cliphist store' \
        'exec-once = wl-paste --type image --watch cliphist store' \
        > "$startup"
    elif ! ${pkgs.gnugrep}/bin/grep -Eq \
      '^[[:space:]]*exec-once[[:space:]]*=[[:space:]]*waybar([[:space:]#]|$)' \
      "$startup"; then
      ${pkgs.coreutils}/bin/printf '%s\n' 'exec-once = waybar' >> "$startup"
    fi

    if [ ! -e "$settings" ]; then
      if [ -L "$settings" ]; then
        ${pkgs.coreutils}/bin/rm -f "$settings"
      fi
      ${pkgs.coreutils}/bin/printf '%s\n' \
        'input {' \
        '  kb_layout = us, ru' \
        '  kb_options = grp:alt_shift_toggle' \
        '}' \
        > "$settings"
    fi

    ${pkgs.coreutils}/bin/chmod u+rw "$startup" "$settings"
  '';
}
